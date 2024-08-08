FROM alpine:latest
RUN apk update && apk upgrade && apk add nginx && apk add bash
EXPOSE 80
COPY conf/default.conf /etc/nginx/http.d/
COPY conf/index.html /var/www/default/html/
CMD ["nginx", "-g", "daemon off;"]
