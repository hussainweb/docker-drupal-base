# Drupal Base Image for Docker

This image provides a basic runtime for Drupal projects. It's designed for CI but is also suitable for local development environments using `docker-compose`. This image is similar to the [official Drupal image](https://hub.docker.com/_/drupal) but does not include the Drupal core files, allowing you to mount your own codebase.

## Image Variants

This repository contains two main variants of the Drupal base image:

- `apache-bookworm`: Based on Debian Bookworm with Apache.
- `fpm-alpine`: Based on Alpine Linux with PHP-FPM.
- `frankenphp-trixie`: Based on Debian Trixie with FrankenPHP (experimental).

Choose the image that best fits your needs. The Apache image is a good choice for a simple, all-in-one container, while the FPM image is ideal for use with a separate web server like Nginx.

## Supported PHP Versions

This image supports the following PHP versions:

- PHP 8.2
- PHP 8.3
- PHP 8.4
- PHP 8.5 (latest)

Each version is available in all variants (apache-bookworm, apache-trixie, fpm-alpine, frankenphp-trixie).

### Available Tags

- `php8.5`, `latest` - PHP 8.5 with Apache on Debian Trixie
- `php8.5-apache-trixie` - PHP 8.5 with Apache on Debian Trixie
- `php8.5-apache-bookworm` - PHP 8.5 with Apache on Debian Bookworm
- `php8.5-alpine`, `php8.5-fpm-alpine`, `latest-alpine` - PHP 8.5 FPM on Alpine Linux
- `php8.4`, `php8.3`, `php8.2` - Older PHP versions with Apache on Debian Trixie
- `php8.4-alpine`, `php8.3-alpine`, `php8.2-alpine` - Older PHP versions FPM on Alpine Linux
- `php8.5-frankenphp-trixie`, `php8.4-frankenphp-trixie` - FrankenPHP on Debian Trixie

All images support both `linux/amd64` and `linux/arm64` architectures.

## Usage

### Apache

The Apache image is straightforward to use. Mount your Drupal codebase to `/var/www/html` in the container.

Here is an example `docker-compose.yml` snippet:

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.5
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
    image: hussainweb/drupal-base:php8.5-alpine
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

### FrankenPHP

The FrankenPHP image uses Caddy as the web server. It is configured to serve the Drupal site from `/app/web`.

Here is an example `docker-compose.yml` snippet:

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.4-frankenphp-trixie
    volumes:
      - ./path/to/your/drupal/root:/app/web
    ports:
      - "8080:80"
    restart: always
```
