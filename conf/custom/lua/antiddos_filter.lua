-- Global config && cacheable variables
local default_rules = {
    ["!no-cookie"] = {
        loc_type = "exact",
        limit = 60,
        period = 60,
        bantime = 60
    },
    ["!default"] = {
        loc_type = "exact",
        limit = 60,
        period = 60,
        bantime = 60
    },
}

local cjson = require "cjson"
local config = require("ddos_config")

local support_email = config.support_email or "webmaster@example.com"
local lua_req_cookie_name = config.cookie_name or "prx_sid"
local lua_req_priv_key = config.priv_key or "qVz6F2HL-7_5jId2IT1YA3D7eU1ahfwC-_j5Xzvap7LlK8NjHZ5o6NjpRR3wDjDHkQFkocw_7eNZNHR8qMufcg"

local rules = default_rules
for k,v in pairs(config.ddos_rules) do rules[k] = v end


ngx.log(ngx.STDERR, 'Initializing anti-ddos\n',
                    '\tsupport_email = ', support_email, '\n',
                    '\tcookie_name = ', lua_req_cookie_name, '\n',
                    '\tprivate_key = ', lua_req_priv_key, '\n',
                    '\trules = ', cjson.encode(rules), '\n')

--- Mapping between location type in config and nginx internal location type

local locations_type_mapping = {
    ["prefix"] = "",
    ["exact"] = "=",
    ["regex"] = "~",
    ["regex_ci"] = "~*"
}

-- TODO: Merge with rules aquired from config

-- Preparing rules locations dictionary
local locations = require("resty.locations") -- https://github.com/hamishforbes/lua-resty-locations
local metrics = require("metrics_processor")

local rules_locations = locations:new()

for location, rule in pairs(rules) do
    local location_type = rule.loc_type
    if location_type == nil then
        location_type = rules["!default"].loc_type
    end
    rules_locations:set(location, location, locations_type_mapping[location_type])
end

local cookie_lib = require("cookie_manager")

-- Глобальные словари бан-листа и счетчиков запросов с shared-памятью
local antiddos_filter_ban_list = ngx.shared['antiddos_filter_ban_list']
local antiddos_filter_rules_counters = ngx.shared['antiddos_filter_rules_counters']

-- ngx.log(ngx.STDERR, uri_path, ' ', 
--                     is_static, ' ',
--                     is_serve_control, ' ',
--                     is_new_client, ' ',
--                     is_new_register, ' ',
--                     is_new_judge, ' ',
--                     is_new_master, '\n')

-- ВЕЧЕРИНКА С КУКАМИ 
-- Концепция нагло стырена с https://habr.com/ru/post/215235/ и подправлена собственными идеями:
-- Для хоть какой-то обработки NAT, кроме IP клиентов проставляется спец кука. 
-- Все три элемента в целом и составляют идентификатор пользователя.
-- Если некий злодей долбит сервер, игнорируя передаваемую куку, то в худшем случае просто будет забанен его IP.
-- При этом те пользователи с этой подсети, кто уже получил ранее куку, будут спокойно работать дальше. 

local function gen_random_salt()
    return tostring(math.random(2147483647))
end

local function gen_user_id(salt)
    -- Формируем уникальный идентификатор пользователя как конкатенацию его IP-адреса и случайной соли (чтобы не считать одинаковыми пользователей, сидящих за NAT'ом)
    return ngx.var.remote_addr .. salt
end

local function gen_cookie_value(user_id, salt)
    local resty_sha512 = require "resty.sha512"
    local str = require "resty.string"
    local sha512 = resty_sha512:new()
    sha512:update(ngx.today() .. user_id .. lua_req_priv_key)
    local digest = sha512:final()
    local key = str.to_hex(digest)

    return ngx.escape_uri(key .. '_' .. salt)
end

local function set_cookie(cookie_value)
    -- TODO: Error handling like in example here https://github.com/cloudflare/lua-resty-cookie/
    local cookie, err = cookie_lib:new()
    cookie:set({
        key = lua_req_cookie_name,
        value = cookie_value,
        path = "/",
        secure = false,
        httponly = true,
        max_age = 24 * 60 * 60,
        samesite = "Strict",
    })
end

local function get_user_cookie()
    local cookie, err = cookie_lib:new()
    local user_cookie, err = cookie:get(lua_req_cookie_name)
    return user_cookie
end

local function get_salt_from_cookie_value()
    local user_cookie = get_user_cookie()
    if user_cookie == nil then
        return nil
    end
    local p = user_cookie:find('_')
    if p == nil then
        return nil
    end
    local salt = user_cookie:sub(p+1)
    return salt
end

-- проверка контрольной куки
local function check_cookie()
    local user_cookie = get_user_cookie()
    local salt = get_salt_from_cookie_value()
    if salt == nil then
        return false
    end
    local control_cookie = gen_cookie_value(gen_user_id(salt), salt)
    -- ngx.log(ngx.ERR, user_cookie, "   ", control_cookie)

    return user_cookie == control_cookie
end


local function process_request_against_antiddos_rule(user_id, rule_name)
    -- Определяем параметры правила
    local limit = rules[rule_name].limit
    if limit == nil then
        limit = rules["!default"].limit
    end
    local period = rules[rule_name].period
    if period == nil then
        period = rules["!default"].period
    end
    local bantime = rules[rule_name].bantime
    if bantime == nil then
        bantime = rules["!default"].bantime
    end

    -- ngx.log(ngx.ERR, rule_name, " ", limit, " ", period, " ", bantime)

    -- Проверяем, что клиент уже забанен (т.е. его ключ находится в бан-листе)
    
    -- ngx.log(ngx.STDERR, uri_path, ', requests count = ', requests_count, ' user key = ', key, ', ban_key = ', ban_key) 

    -- Пытаемся инкрементить счётчик запросов
    local request_counter_key = user_id .. rule_name
    local requests_count, _ = antiddos_filter_rules_counters:incr(request_counter_key, 1)

    -- Если incr вернул nil, это значит, что ключа не существует и надо создать счетчик
    -- Ключа не существует, например, если это первый запрос, или время с предыдущего первого запроса превысило <period> секунд
    if requests_count == nil then
    	antiddos_filter_rules_counters:add(request_counter_key, 1, period) -- Добавляем счетчик, равный <period> со временем жизни в period секунд
        return
    end

    -- Если количество запросов не превышает лимит - выходим
    if requests_count < limit then
        return
    end

    antiddos_filter_ban_list:add(user_id, bantime, bantime) -- Закидываем пользователя в бан-лист, если он ещё не забанен
    metrics:log_ban(rule_name)

    if user_id ~= ngx.var.remote_addr then
        antiddos_filter_ban_list:add(ngx.var.remote_addr, bantime, bantime) -- Закидываем IP-адрес пользователя также в бан-лист, чтобы пользователь не мог сбросить куку и бесплатно переполучить новую
    end
    antiddos_filter_rules_counters:set(request_counter_key, 1, 60) -- "Обнуляем" счетчик запросов
    ngx.log(ngx.STDERR, 'BANNED USER with IP '..ngx.var.remote_addr..', user key: ', key, ', rule name: ',  rule_name, '\n') 
end

local function send_403_if_banned(user_id)
    local banned_time, _ = antiddos_filter_ban_list:get(user_id)
    if banned_time ~= nil then 
        -- Если товарищ оказался в бане - отдаем ему 403 и прощаемся
        -- ngx.log(ngx.STDERR, uri_path, ', user IS BANNED!') 
        ngx.header.content_type = "text/plain; charset=UTF-8"
        ngx.status = 403
        ngx.say("Слишком много запросов с вашего IP-адреса, не торопитесь!!!\nДоступ будет восстановлен в течение " .. banned_time .. " секунд.")
        return ngx.exit(403)
    end
end

local _A = {}

function _A.process_antiddos_filter()
    -- Проверяем попадание ip-адреса юзера в вайтлист
    if ngx.var.lua_req_whitelist == '1' then
        return;
    end

    -- Проверяем попадание ip-адреса юзера в блэклист
    if ngx.var.lua_req_blacklist == '1' then
        ngx.header.content_type = "text/plain; charset=UTF-8"
        ngx.status = 403
        ngx.say("Ваш IP-адрес был заблокирован в связи с подозрительной активностью.\nДля разблокировки напишите на почту " .. support_email .. ".\nОбязательно сообщите ваш IP-адрес: "..ip)
        return ngx.exit(403)
    end

    local cookie_correct = check_cookie()
    local salt = get_salt_from_cookie_value()
    -- ngx.log(ngx.ERR, cookie_correct, "   ", salt)

    if cookie_correct == false or salt == nil then
        process_request_against_antiddos_rule(ngx.var.remote_addr, "!no-cookie")
        send_403_if_banned(ngx.var.remote_addr)
        local salt = gen_random_salt()
        local user_id = gen_user_id(salt)
        local cookie_value = gen_cookie_value(user_id, salt) 
        set_cookie(cookie_value)
        -- ngx.log(ngx.ERR, "Setting new cookie with value " .. cookie_value)
        return
    end

    local user_id = gen_user_id(salt)
    send_403_if_banned(user_id)

    -- processing rate limiting rules
    local rule, err = rules_locations:lookup(ngx.var.uri)
    if rule then
        process_request_against_antiddos_rule(user_id, rule)
    else
        if err then
            ngx.log(ngx.ERR, err)
        end
        ngx.log(ngx.WARN, "No antiddos rule matched for uri " .. ngx.var.uri)
    end

    -- checking again if banned after rate limiting rules check
    send_403_if_banned(user_id)
    return
end

return _A
