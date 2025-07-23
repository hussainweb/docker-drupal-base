# Drupal Base Image for Docker

This image provides a basic runtime for Drupal projects. It's designed for CI but is also suitable for local development environments using `docker-compose`. This image is similar to the [official Drupal image](https://hub.docker.com/_/drupal) but does not include the Drupal core files, allowing you to mount your own codebase.

## Image Variants

This repository contains two main variants of the Drupal base image:

- `apache-bookworm`: Based on Debian Bookworm with Apache.
- `fpm-alpine`: Based on Alpine Linux with PHP-FPM.

Choose the image that best fits your needs. The Apache image is a good choice for a simple, all-in-one container, while the FPM image is ideal for use with a separate web server like Nginx.

## Usage

### Apache

The Apache image is straightforward to use. Mount your Drupal codebase to `/var/www/html` in the container.

Here is an example `docker-compose.yml` snippet:

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.4
    volumes:
      - ./path/to/your/drupal/root:/var/www/html
    ports:
      - "8080:80"
    restart: always
```

### FPM-Alpine

The FPM-Alpine image requires a separate web server. The following example uses Nginx.

Here is an example `docker-compose.yml` snippet:

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.4-alpine
    volumes:
      - ./path/to/your/drupal/root:/var/www/html
    restart: always

  nginx:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - ./path/to/your/drupal/root:/var/www/html
      - ./path/to/your/nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - drupal
    restart: always
```

You will also need an `nginx.conf` file. Here is a basic example:

```conf
server {
    listen 80;
    server_name your-domain.com;
    root /var/www/html;

    location / {
        try_files $uri /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass drupal:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```
