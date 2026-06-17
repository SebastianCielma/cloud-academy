FROM nginx:alpine

# Podmień vhost na port 8080 (Cloud Run słucha na $PORT=8080)
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
