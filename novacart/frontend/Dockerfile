
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY nginx-azure.conf.template /etc/nginx/templates/default.conf.template
COPY index.html app.js styles.css /usr/share/nginx/html/

EXPOSE 80
