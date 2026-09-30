# Drupal Base Image for Docker

This image provides a basic runtime for Drupal projects. It's designed for CI but is also suitable for local development environments using `docker-compose`. This image is similar to the [official Drupal image](https://hub.docker.com/_/drupal) but does not include the Drupal core files, allowing you to mount your own codebase.

## Image Variants

This repository publishes four variants of the Drupal base image:

- `apache-trixie` (default): Based on Debian Trixie with Apache. Backs the `latest` and `php8.X` tags.
- `apache-bookworm`: Based on Debian Bookworm with Apache. Kept for users on older hosts; not the recommended default.
- `fpm-alpine`: Based on Alpine Linux with PHP-FPM. Pair with a separate web server like Nginx.
- `frankenphp-trixie`: Based on Debian Trixie with FrankenPHP (Caddy + PHP in one process).

Choose the image that best fits your needs. The Apache image is a good choice for a simple, all-in-one container, the FPM image is ideal for use with a separate web server like Nginx, and FrankenPHP offers a modern single-binary alternative with built-in HTTPS support.

## Supported PHP Versions

This image supports the following PHP versions:

- PHP 8.2
- PHP 8.3
- PHP 8.4
- PHP 8.5 (latest)

PHP 8.2–8.5 are available in the `apache-trixie`, `apache-bookworm`, and `fpm-alpine` variants. The `frankenphp-trixie` variant is published for PHP 8.4 and 8.5 only.

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

The image ships with a Drupal-tuned Caddyfile that blocks access to sensitive paths, denies PHP execution from upload directories, and sets long-lived cache headers on static assets:

```caddyfile
{
	frankenphp {
		php_ini memory_limit {$PHP_MEMORY_LIMIT:128M}
	}
	order php_server before file_server
}

:80 {
	encode zstd br gzip
	root * /app/web

	# Opt-in features, off by default (see README). Noindex comes first so the
	# 401 from basic auth carries the X-Robots-Tag header too.
	import {$NOINDEX_SNIPPET:/etc/frankenphp/noindex/disabled.caddy}
	import {$BASIC_AUTH_SNIPPET:/etc/frankenphp/basic-auth/disabled.caddy}

	# Block hidden PHP files
	@hiddenPhp path_regexp \..*/.*.php$
	error @hiddenPhp 403

	# Block PHP in vendor
	@vendorPhp path_regexp /vendor/.*\.php$
	error @vendorPhp 404

	# Block PHP in files directories
	@filesPhp path_regexp ^/sites/[^/]+/files/.*\.php$
	error @filesPhp 404

	# Block private directories
	@private path_regexp ^/sites/.*/private/
	error @private 403

	# Block sensitive files (allow .well-known)
	@protected {
		not path /.well-known*
		path_regexp \.(engine|inc|install|make|module|profile|po|sh|.*sql|theme|twig|tpl(\.php)?|xtmpl|yml)(~|\.sw[op]|\.bak|\.orig|\.save)?$|^/(\..+|Entries.*|Repository|Root|Tag|Template|composer\.(json|lock)|web\.config|yarn\.lock|package\.json)$|^\/#.*#$|\.php(~|\.sw[op]|\.bak|\.orig|\.save)$
	}
	error @protected 403

	# Static assets caching
	@static {
		file
		path *.avif *.css *.eot *.gif *.gz *.ico *.jpg *.jpeg *.js *.otf *.pdf *.png *.svg *.ttf *.webp *.woff *.woff2
	}
	header @static Cache-Control "public, max-age=31536000, immutable"

	php_server
}
```

#### Basic auth, noindex and PHP memory limit

Three features are driven by environment variables, so a private staging or demo site can run on the stock Caddyfile. All are off (or unchanged) by default.

| Variable | Default | Purpose |
| --- | --- | --- |
| `BASIC_AUTH_USER` | unset | User name for HTTP basic auth. |
| `BASIC_AUTH_PASSWORD` | unset | Plaintext password. The entrypoint hashes it at start. |
| `BASIC_AUTH_HASH` | unset | A ready-made hash (from `frankenphp hash-password`) instead of a password. Wins over `BASIC_AUTH_PASSWORD` if both are set. |
| `BASIC_AUTH_SNIPPET` | `/etc/frankenphp/basic-auth/disabled.caddy` | Caddy snippet imported for basic auth. Set automatically to `/etc/frankenphp/basic-auth/enabled.caddy` when the user and a password or hash are given. |
| `NOINDEX_SNIPPET` | `/etc/frankenphp/noindex/disabled.caddy` | Set to `/etc/frankenphp/noindex/enabled.caddy` to send `X-Robots-Tag: noindex, nofollow, noarchive` on every response (the 401 included) and to serve a disallow-all `/robots.txt`. |
| `PHP_MEMORY_LIMIT` | `128M` | `memory_limit` for the web server. `128M` is PHP's built-in default, so nothing changes unless you set it. The CLI keeps `memory_limit = -1`, so drush and composer are unaffected. |

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.5-frankenphp-trixie
    volumes:
      - ./path/to/your/drupal/root:/app
    ports:
      - "8080:80"
    environment:
      BASIC_AUTH_USER: demo
      BASIC_AUTH_PASSWORD: ${BASIC_AUTH_PASSWORD}
      NOINDEX_SNIPPET: /etc/frankenphp/noindex/enabled.caddy
      PHP_MEMORY_LIMIT: 512M
```

Basic auth protects every path except `/robots.txt`, so crawlers can still read the disallow rule. The password is hashed by `docker-drupal-entrypoint` (a bcrypt hash via `frankenphp hash-password`, with the password on stdin), so you never write a hash containing `$` into a compose file. `BASIC_AUTH_PASSWORD` is unset before the server starts, so it does not reach PHP's environment. The user name must not contain spaces.

**Fails closed.** If basic auth is requested (`BASIC_AUTH_SNIPPET` points at the enabled file) but the user name or the password and hash are missing, the container exits with an error instead of starting an open site.

**Downstream entrypoints.** The image sets `ENTRYPOINT ["docker-drupal-entrypoint"]` and re-declares the upstream `CMD`. If your image has its own entrypoint, end it with `exec docker-drupal-entrypoint "$@"` to keep these features (it hands over to `docker-php-entrypoint`). If you replace the entrypoint without doing so, the variables have no effect, and basic auth is never enabled.

If you mount your own Caddyfile, it only gets these features if it contains the same `import` lines (and the `php_ini` line in the global block).

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

## Health check

Every variant ships with a `HEALTHCHECK` that opens a TCP connection to the web server (port 80, or 9000 on `fpm-alpine`):

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=5m --start-interval=5s --retries=3
```

Failures during the five-minute start period are not counted until the first successful check. That success marks the container `healthy` and ends the grace period, even if the five minutes have not passed, so later consecutive failures count toward `--retries` as usual. During the start period the check runs every 5 seconds (`--start-interval`), so a container that starts quickly is reported healthy within seconds. The long window suits images that install or update the site (for example `drush site:install` or `drush deploy`) in their entrypoint before the web server starts.

### Overriding the timings

Health check options are fixed at build time and cannot come from environment variables. To use a different window, override them in Docker Compose:

```yaml
services:
  drupal:
    image: hussainweb/drupal-base:php8.5-frankenphp-trixie
    healthcheck:
      start_period: 10m
      start_interval: 5s
```

Or declare a `HEALTHCHECK` in a downstream Dockerfile. It replaces the inherited one, so repeat the command (use port 9000 on `fpm-alpine`):

```dockerfile
FROM hussainweb/drupal-base:php8.5-apache-trixie
HEALTHCHECK --interval=30s --timeout=5s --start-period=10m --start-interval=5s --retries=3 \
	CMD ["php", "-r", "exit(@fsockopen('127.0.0.1', 80, $e, $s, 2) ? 0 : 1);"]
```

### Older Docker engines

`--start-interval` needs Docker Engine 25 or later (and Docker Compose 2.20.2+ for `start_interval` in a compose file). Older engines do not know the field in the image config and ignore it, so the check simply runs at the normal 30 second interval during the start period. The 5 minute start period still applies, so containers are not marked unhealthy early; they only take up to one interval (30 s) to be reported healthy. This is based on how the engine decodes the image config, not on a test against an old engine.
