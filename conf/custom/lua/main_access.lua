-- This script will be run with directive "access_by_lua_file" https://github.com/openresty/lua-nginx-module#access_by_lua_block
local antiddos = require("antiddos_filter")
antiddos:process_antiddos_filter()
