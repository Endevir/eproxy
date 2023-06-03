-- This script will be run with directive "log_by_lua_file" https://github.com/openresty/lua-nginx-module#log_by_lua_block
local metrics = require("metrics_processor")
local geoip = require("geoip_processor")
metrics:log_request()
local asn, country_iso_code = geoip:get_asn_and_country()
metrics:log_geo(asn, country_iso_code)
