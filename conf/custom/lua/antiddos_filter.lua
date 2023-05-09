-- ПАРСИМ ЗАПРОС
-- Штука нужна чтобы логически разделить различные запросы на статику и страницы еджаджа
-- Благодаря этому разделению можно будет ставить rate-limit'ы на отдельные страницы типа new-register или new-client 

local default_rules = {
    ["!no-cookie"] = {
        limit = 60,
        period = 60,
        bantime = 60
    },
    ["!default"] = {
        limit = -1,
        period = 60,
        bantime = 60
    }
}

-- TODO: Merge with rules aquired from config
local rules = default_rules


local cookie_lib = require("cookie_manager")
local cookie, err = cookie_lib:new()


-- Убираем все куски с GET-параметрами
local uri_path = ngx.var.request_uri
if ngx.var.is_args == '?' then
    uri_path = uri_path:gsub('^([^?]+)\\?.*$', '%1')
end


-- Переменные с проверкой на статику страницы еджаджа
local is_root_page = uri_path == '/'
local is_serve_control = uri_path == '/serve-control'
local is_new_client = uri_path == '/new-client'
local is_new_register = uri_path == '/new-register'
local is_new_judge = uri_path == '/new-judge'
local is_new_master = uri_path == '/new-master'

-- Глобальные словари бан-листа и счетчиков запросов с shared-памятью by ejudge
local ban_list = ngx.shared['ban_list']
local req_limit = ngx.shared['req_limit']


-- ngx.log(ngx.STDERR, uri_path, ' ', 
--                     is_static, ' ',
--                     is_serve_control, ' ',
--                     is_new_client, ' ',
--                     is_new_register, ' ',
--                     is_new_judge, ' ',
--                     is_new_master, '\n')

local uri = ngx.var.request_uri -- запрашиваемый URI
local host = ngx.var.http_host -- к какому домену пришел запрос (если у вас nginx обрабатывает несколько доменов)
local ip = ngx.var.remote_addr

-- ПРОВЕРЯЕМ ЮЗЕРА В ВАЙТЛИСТЕ
if ngx.var.lua_req_whitelist == '1' then
    return;
end

-- ПРОВЕРЯЕМ ЮЗЕРА В БЛЭКЛИСТЕ  
if ngx.var.lua_req_blacklist == '1' then
    ngx.header.content_type = "text/plain; charset=UTF-8"
    ngx.status = 403
    ngx.say("Ваш IP-адрес был заблокирован в связи с подозрительной активностью.\nДля разблокировки обратитесь к своему учителю/муниципальному координатору, чтобы он передал информацию методисту-куратору Олимпиады.\nОбязательно сообщите ваш IP-адрес: "..ip)
    return ngx.exit(403)
end


-- ВЕЧЕРИНКА С КУКАМИ 
-- Нагло стырено с https://habr.com/ru/post/215235/
-- Для хоть какой-то обработки NAT, кроме IP клиентов так же учитывается их UserAgent и проставляется спец кука. 
-- Все три элемента в целом и составляют идентификатор пользователя.
-- Если некий злодей долбит сервер, игнорируя передаваемую куку, то в худшем случае просто будет забанен его IP/подсеть.
-- При этом те пользователи с этой подсети, кто уже получил ранее куку, будут спокойно работать дальше (кроме случая бана по IP). 
-- Решение не идеальное, но все же лучше, чем считать полстраны/мобильного оператора за одного пользователя.

local function gen_random_salt()
    return tostring(math.random(2147483647))
end

local function gen_user_id(salt)
    -- Формируем уникальный идентификатор пользователя как конкатенацию его IP-адреса и случайной соли (чтобы не считать одинаковыми пользователей, сидящих за NAT'ом)
    return ngx.var.remote_addr .. salt
end

local function gen_user_encoded_key(user_id)
    local resty_sha512 = require "resty.sha512"
    local str = require "resty.string"
    local sha512 = resty_sha512:new()
    sha512:update(ngx.today() .. user_id .. lua_req_priv_key)
    local digest = sha512:final()
    return str.to_hex(digest)
end

local function gen_cookie_value(user_id, salt)
    local key = gen_user_key(user_id, salt)
    return ngx.escape_uri(key .. '_' .. salt)
end

local function set_cookie(cookie_value)
    -- TODO: Error handling like in example here https://github.com/cloudflare/lua-resty-cookie/
    cookie:set({
        key = lua_req_cookie_name,
        value = cookie_value,
        path = "/",
        secure = true,
        httponly = true,
        max_age = 24 * 60 * 60,
        samesite = "Strict",
    })
end

-- проверка контрольной куки
local function check_cookie() 
    local user_cookie, err = cookie_obj:get(lua_req_cookie_name)
    if err then
        return false
    end

    local p = user_cookie:find('_')
    if p == nil then
        return false
    end

    local salt = user_cookie:sub(p+1)
    user_cookie = user_cookie:sub(1, p-1)

    local control_cookie = gen_cookie_value(gen_user_id(salt), salt)

    return user_cookie == control_cookie
end


-- В key_prefix запишем уникальный идентификатор пользователя (айпишник:кука)

-- key_prefix = key_prefix .. ':' .. user_cookie
-- ngx.header['Set-Cookie'] = string.format('%s=%s; path=/; expires=%s',
--     lua_req_cookie_name,
--     ngx.escape_uri(control_cookie .. '_' .. rnd),
--     ngx.cookie_time(ngx.time()+24*3600)
-- )


-- ПРОВЕРЯЕМ ПОЛЬЗОВАТЕЛЯ НА ЗАБАНЕННОСТЬ!!!!!!!!

-- local ban_key = key_prefix..':ban'

-- проверка ключа и проверка бана вообще в целом по IP

-- if ban_list:get(ban_key) or (ban_list:get(ip..':ban') and not user_has_cookie) then 
--     -- Если товарищ оказался в бане - отдаем ему 403 и прощаемся
--     -- ngx.log(ngx.STDERR, uri_path, ', user IS BANNED!') 
--     ngx.header.content_type = "text/plain; charset=UTF-8"
--     ngx.status = 403
--     ngx.say("Слишком много запросов с вашего браузера, не торопитесь!!!\nДоступ будет восстановлен в течение 60 секунд.")
--     return ngx.exit(403)
-- end


-- ПРОВЕРЯЕМ ЛИМИТЫ НА СТАТИКУ!!!!!!!!!
-- 
-- Сначала устанавливаем правильный лимит в зависимости от типа запроса 

-- local limit = 0
-- local key = ''
-- local ban_key = ''

-- Если запрос - статика и у юзера есть пользовательская кука, тогда
-- смотрим в соответствии с лимитом по конкретному файлу (указываем его в key)
-- ban_key везде одинаковый, чтобы в случае массового абьюза первый пробитый лимит пресекал весь остальной абьюз

-- if is_static and user_has_cookie then
--     limit = lua_req_static_data
--     key = key_prefix..':static_data:'..uri_path
--     ban_key = key_prefix..':ban'
--     -- ngx.log(ngx.STDERR, uri_path, 'STATIC: USER HAS COOKIE ', limit, key, ban_key, ip, '\n')
-- end

-- Запросы на главную страницу считаем отдельно
-- if is_root_page and user_has_cookie then
--     limit = lua_req_root
--     key = key_prefix..':root_page'
--     ban_key = key_prefix..':ban'
--     -- ngx.log(ngx.STDERR, uri_path, 'ROOT_PAGE: USER HAS COOKIE ', limit, key, ban_key, ip, '\n')
-- end

-- Запросы в еджадж просто измеряем по внутреннему сервису, куда адресуется запрос
-- (будь то serve-control, или new-client, и т.д.)
-- if is_serve_control and user_has_cookie then
--     limit = lua_req_ejudge_serve_control
--     key = key_prefix..':serve_control'
--     ban_key = key_prefix..':ban'
--     -- ngx.log(ngx.STDERR, uri_path, 'SERVE_CONTROL: USER HAS COOKIE ', limit, key, ban_key, ip, '\n')
-- end

-- if is_new_client and user_has_cookie then
--     limit = lua_req_ejudge_new_client
--     key = key_prefix..':new_client'
--     ban_key = key_prefix..':ban'
--     -- ngx.log(ngx.STDERR, uri_path, 'NEW_CLIENT: USER HAS COOKIE ', limit, key, ban_key, ip, '\n')
-- end

-- if is_new_register and user_has_cookie then
--     limit = lua_req_ejudge_new_register
--     key = key_prefix..':new_register'
--     ban_key = key_prefix..':ban'
--     -- ngx.log(ngx.STDERR, uri_path, 'NEW_REGISTER: USER HAS COOKIE ', limit, key, ban_key, ip, '\n')
-- end

-- if is_new_judge and user_has_cookie then
--     limit = lua_req_ejudge_new_judge
--     key = key_prefix..':new_judge'
--     ban_key = key_prefix..':ban'
--     -- ngx.log(ngx.STDERR, uri_path, 'NEW_JUDGE: USER HAS COOKIE ', limit, key, ban_key, ip, '\n')
-- end

-- if is_new_master and user_has_cookie then
--     limit = lua_req_ejudge_new_master
--     key = key_prefix..':new_master'
--     ban_key = key_prefix..':ban'
--     -- ngx.log(ngx.STDERR, uri_path, 'NEW_MASTER: USER HAS COOKIE ', limit, key, ban_key, ip, '\n')
-- end

-- -- Если у пользователя нет куки - то считаем по его IP-адресу
-- if not user_has_cookie then
--     limit = lua_req_nocookie
--     key = ip..':nocookie'
--     ban_key = ip..':ban'
--     -- ngx.log(ngx.STDERR, uri_path, 'USER HAS NO COOKIE ', key, '\n')
-- end


local function increment_req_num_and_check_if_limit_exceeded(ban_key, key, limit)
    local requests_count, _ = req_limit:incr(key, 1)

    -- ngx.log(ngx.STDERR, uri_path, ', requests count = ', requests_count, ' user key = ', key, ', ban_key = ', ban_key) 

    -- Если incr вернул nil, это значит, что ключа не существует и надо создать счетчик
    -- Ключа не существует, например, если это первый запрос, или время с предыдущего первого запроса превысило 60 секунд
    if requests_count == nil then
    	req_limit:add(key, 1, 60) -- Добавляем счетчик, равный 1 со временем жизни в 60 секунд
        return false
    end

    -- Если количество запросов не превышает лимит - выходим
    if requests_count < limit then
        return false
    end

    ban_list:add(ban_key, 1, lua_req_ban_ttl) -- Закидываем пользователя в бан-лист, если он ещё не забанен
    req_limit:set(key, 1, 60) -- "Обнуляем" счетчик запросов
 
    ngx.log(ngx.STDERR, 'BANNED USER with IP '..ip..', user key: ',key, '\n') 
    return true
end

-- Проверяем лимиты, только если клиент проходит по хотя бы одному из правил выше:
-- if key ~= '' then
--     -- Проверяем, исчерпан ли лимит, и если исчерпан - то посылаем чувака нафиг)
--     local limit_exceeded = increment_req_num_and_check_if_limit_exceeded(ban_key, key, limit)
--     if limit_exceeded then
--         ngx.header.content_type = "text/plain; charset=UTF-8"
--         ngx.status = 403
--         ngx.say("Слишком много запросов с вашего браузера, не торопитесь!!!\nДоступ будет восстановлен через 60 секунд")
--         return ngx.exit(403)
--     end
-- end

