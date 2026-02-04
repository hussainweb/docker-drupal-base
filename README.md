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
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - drupal
    restart: always
```

#### Nginx Configuration

You will need an `nginx.conf` file in your project root. Here is a production-ready example:

```nginx
server {
    listen 80;
    server_name localhost;
    root /var/www/html/web;
    index index.php index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;

    # Main location block
    location / {
        try_files $uri /index.php?$query_string;
    }

    # Handle PHP files
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass drupal:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        include fastcgi_params;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Deny access to sensitive files
    location ~* \.(engine|inc|install|make|module|profile|po|sh|sql|theme|twig|tpl(\.php)?|xtmpl|yml|yaml)(~|\.sw[op]|\.bak|\.orig|\.save)?$|^(\.(?!well-known).*|Entries.*|Repository|Root|Tag|Template|composer\.(json|lock)|web\.config)$|^#.*#$|\.php(~|\.sw[op]|\.bak|\.orig|\.save)$ {
        deny all;
    }

    # Cache static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        try_files $uri @rewrite;
    }

    location @rewrite {
        rewrite ^ /index.php;
    }

    # Deny access to vendor directory
    location ~ /vendor/.*\.php$ {
        deny all;
    }
}
```

**Note:** Adjust `root` path based on your Drupal installation structure. If your Drupal files are directly in the mounted directory, use `/var/www/html`. If you have a `web` subdirectory (as in Composer-based installs), use `/var/www/html/web`.

### FrankenPHP

The FrankenPHP image uses Caddy as the web server with FrankenPHP for PHP execution. It is configured to serve the Drupal site from `/app/web`.

Here is an example `docker-compose.yml` snippet:

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.5-frankenphp-trixie
    volumes:
      - ./path/to/your/drupal/root:/app
    ports:
      - "8080:80"
    restart: always
```

**Note:** Mount your entire Drupal project root to `/app`. The image expects Drupal's `index.php` to be in `/app/web`.

#### Default Caddyfile

The image includes a default Caddyfile optimized for Drupal:

```caddyfile
{
    frankenphp
    order php_server before file_server
}

:80 {
    encode zstd gzip
    root * /app/web
    php_server
    file_server
}
```

#### Custom Caddyfile

To customize the Caddy configuration, mount your own Caddyfile:

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.5-frankenphp-trixie
    volumes:
      - ./path/to/your/drupal/root:/app
      - ./Caddyfile:/etc/caddy/Caddyfile
    ports:
      - "8080:80"
    restart: always
```

Here is an example custom Caddyfile with additional security and caching:

```caddyfile
{
    frankenphp
    order php_server before file_server
}

:80 {
    encode zstd gzip
    root * /app/web

    # Security: deny access to sensitive files
    @sensitive {
        path *.engine *.inc *.install *.module *.profile *.po *.sh *.sql *.theme *.twig *.xtmpl *.yml *.yaml
        path /composer.json /composer.lock /web.config
        path /.* /vendor/*
    }
    respond @sensitive 403

    # Cache static assets
    @static {
        path *.css *.js *.png *.jpg *.jpeg *.gif *.ico *.svg *.woff *.woff2 *.ttf *.eot
    }
    header @static Cache-Control "public, max-age=31536000, immutable"

    php_server
    file_server
}
```

#### Enabling HTTPS with FrankenPHP

FrankenPHP supports automatic HTTPS. To enable it, update your Caddyfile:

```caddyfile
{
    frankenphp
    order php_server before file_server
}

your-domain.com {
    encode zstd gzip
    root * /app/web
    php_server
    file_server
}
```

And expose port 443 in your `docker-compose.yml`:

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.5-frankenphp-trixie
    volumes:
      - ./path/to/your/drupal/root:/app
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
    ports:
      - "80:80"
      - "443:443"
    restart: always

volumes:
  caddy_data:
```

Caddy will automatically obtain and renew TLS certificates from Let's Encrypt.
