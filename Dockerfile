FROM openresty/openresty:1.21.4.1-alpine-fat
RUN apk add yaml-dev && luarocks --server=http://rocks.moonscript.org install lyaml 6.2.8  # https://github.com/gvvaughan/lyaml
RUN luarocks install nginx-lua-prometheus 0.20221218-1                 # https://github.com/knyar/nginx-lua-prometheus
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/custom /etc/nginx/custom
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;", "-c", "/etc/nginx/nginx.conf"]
