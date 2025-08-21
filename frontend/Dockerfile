# Frontend Dockerfile
FROM nginx:alpine

# Copy static files
COPY index.html style.css script.js /usr/share/nginx/html/

# Custom nginx config with API proxy to backend-service (same origin -> no CORS)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
