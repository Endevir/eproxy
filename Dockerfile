FROM openresty/openresty:1.21.4.1-alpine-fat
RUN apk add yaml-dev && luarocks --server=http://rocks.moonscript.org install lyaml 6.2.8  # https://github.com/gvvaughan/lyaml
RUN opm get knyar/nginx-lua-prometheus=0.20221218                                            # https://github.com/knyar/nginx-lua-prometheus
RUN opm get openresty/lua-resty-string=0.11                                                # https://github.com/openresty/lua-resty-string
RUN opm get hamishforbes/lua-resty-locations=0.2                                           # https://github.com/hamishforbes/lua-resty-locations
RUN apk --no-cache add perl libmaxminddb \
    && ln -s /usr/lib/libmaxminddb.so.0 /usr/lib/libmaxminddb.so \
    && opm get anjia0532/lua-resty-maxminddb=1.3.3
COPY lua_lib/maxminddb.lua /usr/local/openresty/site/lualib/resty/maxminddb.lua
COPY geoip /var/lib/geoip
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/custom /etc/nginx/custom
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
