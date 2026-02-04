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
    listen 80 default_server;
    server_name localhost _;
    root /var/www/html/web;
    index index.php index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to sensitive files
    location ~* \.(engine|inc|info|install|make|module|profile|test|po|sh|.*sql|theme|tpl(\.php)?|xtmpl|svn|git|bzr|hg|CVS)(~|\.sw[op]|\.bak|\.orig|\.save)?$ {
        deny all;
    }

    # Deny access to backup files
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Theme and frontend assets
    location ~* ^/(themes|core)/.*\.(css|js|svg|png|jpg|jpeg|gif|ico|woff|woff2|ttf|eot)$ {
        access_log off;
    }

    # Handle PHP files
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass drupal:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param HTTP_PROXY "";
        fastcgi_read_timeout 300;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Handle Drupal clean URLs
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # Drupal aggregate CSS/JS paths (multisite-safe)
    # Required since Drupal 10.1 as aggregate files are created on first request.
    # See https://www.drupal.org/node/3301716
    location ~* ^/sites/[^/]+/files/(css|js)/ {
        try_files $uri /index.php?$query_string;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Image styles (must go through Drupal if missing)
    location ~* ^/sites/[^/]+/files/styles/ {
        try_files $uri /index.php?$query_string;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # All other static assets
    location ~* \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Cache HTML files
    location ~* \.html$ {
        expires 1h;
        add_header Cache-Control "public";
    }

    # Deny access to sensitive directories
    location ~* ^/(sites/.*/private/|sites/.*/tmp/) {
        deny all;
    }
}
```

**Note:** Adjust `root` path based on your Drupal installation structure. If your Drupal files are directly in the mounted directory, use `/var/www/html`. If you have a `web` subdirectory (as in Composer-based installs), use `/var/www/html/web`.

**Important:** For image style generation and CSS/JS aggregation to work properly, the Drupal source code must be available in **both** the Nginx and PHP-FPM containers. When Nginx receives a request for a missing image style or aggregate file, it passes the request to Drupal, which generates the file. Nginx then needs filesystem access to serve the generated file on subsequent requests.

- **Using volumes:** Mount your Drupal codebase to both containers (as shown in the docker-compose example above).
- **Using a custom Dockerfile:** If you copy files into the PHP-FPM image instead of mounting them, you must also build a custom Nginx image that contains the same static files (themes, modules, and the `sites/*/files` directory if pre-populated).

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
      - ./Caddyfile:/etc/frankenphp/Caddyfile
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
      - ./Caddyfile:/etc/frankenphp/Caddyfile
      - caddy_data:/data
    ports:
      - "80:80"
      - "443:443"
    restart: always

volumes:
  caddy_data:
```

Caddy will automatically obtain and renew TLS certificates from Let's Encrypt.
