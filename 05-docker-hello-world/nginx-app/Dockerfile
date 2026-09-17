# Official Nginx image
FROM nginx:alpine

# nginx serves everything under this directory
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
# The base image already starts nginx in the foreground, so no CMD is needed.
