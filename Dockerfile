FROM openresty/openresty:1.21.4.1-alpine-fat
RUN apk add yaml-dev && luarocks --server=http://rocks.moonscript.org install lyaml 6.2.8  # https://github.com/gvvaughan/lyaml
RUN luarocks install nginx-lua-prometheus 0.20221218-1                                     # https://github.com/knyar/nginx-lua-prometheus
RUN opm get openresty/lua-resty-string=0.11                                                # https://github.com/openresty/lua-resty-string
RUN opm get hamishforbes/lua-resty-locations=0.2                                           # https://github.com/hamishforbes/lua-resty-locations
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/custom /etc/nginx/custom
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
