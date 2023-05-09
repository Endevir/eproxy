-- This script will be run with directive "log_by_lua_file" https://github.com/openresty/lua-nginx-module#log_by_lua_block
lua_req_priv_key    = "bestsatteverbecauseendeviristhebest7381"

-- Cookie name
lua_req_cookie_name = "s2schoololymp_req_cookie"

-- Requests number limit (per minute, per request, excluding GET/POST params)
lua_req_root = 30                                           -- requests on /
lua_req_ejudge_new_register = 30                            -- requests on /new-register 
lua_req_ejudge_new_client = 150                             -- requests on /new-client
lua_req_ejudge_serve_control = 60                           -- requests on /serve-control
lua_req_ejudge_new_judge = 60                               -- requests on /new-judge
lua_req_ejudge_new_master = 60                              -- requests on /new-master
lua_req_static_data = 100                                    -- requests on /static/*

-- Requests number limit (per minute, per IP address, for users without cookie)
lua_req_nocookie = 40

-- Ban time (in seconds)
lua_req_ban_ttl = 60

-- For internal usage
math.randomseed(math.floor(ngx.now()*1000))
