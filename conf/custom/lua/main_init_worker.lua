-- This script will be run with directive "init_worker_by_lua_file" https://github.com/openresty/lua-nginx-module#init_worker_by_lua_block
local metrics = require("metrics_processor")
metrics:setup_metrics()
