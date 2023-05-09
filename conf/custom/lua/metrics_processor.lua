local _M = {}

function _M.setup_metrics()
    -- This script will be run with directive "init_worker_by_lua_file" https://github.com/openresty/lua-nginx-module#init_worker_by_lua_block
    prometheus = require("prometheus").init("prometheus_metrics", {error_metric_name="eproxy_errors_total", sync_interval=3})
    metric_requests = prometheus:counter(
    "eproxy_http_req_total", "Number of HTTP requests", {"host", "status"})
    metric_bytes_sent = prometheus:counter(
    "eproxy_http_bytes_sent", "Number of bytes sent", {"host"})
    metric_bytes_received = prometheus:counter(
    "eproxy_http_bytes_received", "Number of bytes received", {"host"})
    metric_connections = prometheus:gauge(
    "eproxy_http_connections", "Number of HTTP connections", {"state"})
    metric_latency = prometheus:histogram(
    "eproxy_http_req_duration_ms", "HTTP request latency", {"host"}, {100,200,500,1000,2000,3000,5000,8000,10000,30000,60000})
    metric_backend_latency = prometheus:histogram(
    "eproxy_http_proxy_response_time_ms", "HTTP upstream response latency", {"upstream"}, {100,200,500,1000,2000,3000,5000,8000,10000,30000,60000})
    metric_bans = prometheus:counter(
    "eproxy_bans_total", "Number of bans", {"host"})
    metric_bans_by_rule = prometheus:counter(
    "eproxy_bans_by_rule", "Number of bans by rule", {"host", "rule"})

    metric_requests_by_country = prometheus:counter(
    "eproxy_http_req_total_by_country", "Number of HTTP requests by country", {"host", "status", "country"})
    metric_requests_by_asn = prometheus:counter(
    "eproxy_http_req_total_by_asn", "Number of HTTP requests by ASN", {"host", "status", "asn"})
    metric_requests_by_path = prometheus:counter(
    "eproxy_http_req_total_by_path", "Number of HTTP requests by path", {"host", "path"})
    metric_backend_latency_by_path = prometheus:gauge(
    "eproxy_http_backend_latency_by_path", "HTTP upstream responce latency by path", {"upstream", "path"})
end

function _M.log_request()
    metric_bytes_received:inc(tonumber(ngx.var.request_length), {ngx.var.http_host})
    metric_bytes_sent:inc(tonumber(ngx.var.bytes_sent), {ngx.var.http_host})
    metric_requests:inc(1, {ngx.var.http_host, ngx.var.status})
    metric_latency:observe(tonumber(ngx.var.request_time) * 1000, {ngx.var.http_host})
    if ngx.var.upstream_response_time ~= nil then
        metric_backend_latency:observe(tonumber(ngx.var.upstream_response_time) * 1000, {ngx.var.http_host})
    end
end

return _M
