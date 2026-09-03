# Official Apache HTTP Server image
FROM httpd:2.4

# httpd serves everything under this directory
COPY index.html /usr/local/apache2/htdocs/index.html

EXPOSE 80
# The base image already starts httpd in the foreground, so no CMD is needed.
