-- This script will be run with directive "log_by_lua_file" https://github.com/openresty/lua-nginx-module#log_by_lua_block
local metrics = require("metrics_processor")
metrics:log_request()
