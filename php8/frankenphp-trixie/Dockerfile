ARG PHP_VERSION=8.4

# Stage 1: build FrankenPHP with the Coraza WAF module. This follows the
# upstream "custom build" recipe (https://frankenphp.dev/docs/docker/#how-to-install-more-caddy-modules)
# and uses the builder image for the same PHP version and ZTS build as the
# runtime image, so the PHP embedded in the binary matches it.
FROM dunglas/frankenphp:builder-php${PHP_VERSION}-trixie AS frankenphp-builder

# xcaddy is not part of the FrankenPHP builder image
COPY --from=caddy:builder /usr/bin/xcaddy /usr/bin/xcaddy

# Pinned so the build is reproducible; bump it deliberately.
ARG CORAZA_CADDY_VERSION=v2.6.1

# CGO must be enabled to build FrankenPHP. XCADDY_SETCAP keeps the
# cap_net_bind_service capability the upstream binary has. The module set
# matches the upstream binary (cbrotli for "encode br", Mercure, Vulcain)
# plus Coraza. The build tags are the ones upstream uses.
RUN --mount=type=cache,target=/root/go/pkg/mod \
	--mount=type=cache,target=/root/.cache/go-build \
	set -eux; \
	CGO_ENABLED=1 \
	XCADDY_SETCAP=1 \
	XCADDY_GO_BUILD_FLAGS="-ldflags='-w -s' -tags=nobadger,nomysql,nopgx" \
	CGO_CFLAGS="$(php-config --includes)" \
	CGO_LDFLAGS="$(php-config --ldflags) $(php-config --libs)" \
	xcaddy build \
		--output /usr/local/bin/frankenphp \
		--with github.com/dunglas/frankenphp=./ \
		--with github.com/dunglas/frankenphp/caddy=./caddy/ \
		--with github.com/dunglas/caddy-cbrotli \
		--with github.com/dunglas/mercure/caddy \
		--with github.com/dunglas/vulcain/caddy \
		--with github.com/corazawaf/coraza-caddy/v2@${CORAZA_CADDY_VERSION} \
	; \
	frankenphp version; \
	frankenphp list-modules | grep -qx 'http.handlers.waf'; \
	frankenphp list-modules | grep -qx 'http.encoders.br'

# Stage 2: the runtime image
FROM dunglas/frankenphp:php${PHP_VERSION}-trixie

ARG PHP_VERSION
LABEL org.opencontainers.image.source="https://github.com/hussainweb/docker-drupal-base" \
      org.opencontainers.image.url="https://hub.docker.com/r/hussainweb/drupal-base" \
      org.opencontainers.image.title="Drupal base (frankenphp-trixie)" \
      org.opencontainers.image.description="Drupal-ready PHP ${PHP_VERSION} runtime on Debian Trixie with FrankenPHP (Caddy + PHP)" \
      org.opencontainers.image.version="${PHP_VERSION}"

# Replace the upstream binary with the one that includes the Coraza module
COPY --from=frankenphp-builder /usr/local/bin/frankenphp /usr/local/bin/frankenphp

# install the PHP extensions we need
RUN set -eux; \
	apt-get update; \
# pull in any security updates from Debian that the upstream base
# image hasn't picked up yet
	apt-get -y upgrade; \
	apt-get install -y --no-install-recommends \
		git \
		patch \
		unzip \
		sendmail \
		mariadb-client \
		sqlite3 \
	; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libavif-dev \
		libbz2-dev \
		libfreetype6-dev \
		libicu-dev \
		libjpeg-dev \
		libmemcached-dev \
		libpng-dev \
		libpq-dev \
		libsqlite3-dev \
		libwebp-dev \
		libyaml-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-avif \
		--with-freetype \
		--with-jpeg=/usr \
		--with-webp \
	; \
	\
	# Extract PHP major.minor version from PHP_VERSION
	PHP_MAJOR_MINOR=$(echo "${PHP_VERSION}" | cut -d'-' -f1); \
	# Opcache is bundled in PHP 8.5+, so only install it for earlier versions
	case "$PHP_MAJOR_MINOR" in \
		8.[5-9]*|[9-9]*.*) \
			OPCACHE_EXT="" ;; \
		*) \
			OPCACHE_EXT="opcache" ;; \
	esac; \
	\
	docker-php-ext-install -j "$(nproc)" \
		bcmath \
		bz2 \
		exif \
		gd \
		intl \
		$OPCACHE_EXT \
		pcntl \
		pdo_mysql \
		pdo_pgsql \
		pdo_sqlite \
		sockets \
		zip \
	; \
	\
	pecl install \
		apcu \
		memcached \
		redis \
		yaml \
	; \
	\
	docker-php-ext-enable \
		apcu \
		memcached \
		redis \
		yaml \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
# Remove the memory limit for the CLI only.
	echo 'memory_limit = -1' > /usr/local/etc/php/php-cli.ini

# https://www.drupal.org/node/3298550
# Drupal now recommends sites enable PHP output buffering by default
RUN { \
		echo 'output_buffering=true'; \
	} > /usr/local/etc/php/conf.d/docker-php-drupal-recommended.ini

# Install Composer
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

# FrankenPHP configuration
# Copy Caddyfile for Drupal configuration
COPY Caddyfile /etc/frankenphp/Caddyfile
# Opt-in snippets imported by the Caddyfile; the disabled ones are the default
COPY noindex/ /etc/frankenphp/noindex/
COPY basic-auth/ /etc/frankenphp/basic-auth/
COPY waf/ /etc/frankenphp/waf/

# Prepares basic auth from environment variables, then runs the upstream
# entrypoint. Setting ENTRYPOINT resets CMD, so re-declare the upstream one.
COPY --chmod=755 docker-drupal-entrypoint /usr/local/bin/docker-drupal-entrypoint
ENTRYPOINT ["docker-drupal-entrypoint"]
CMD ["--config", "/etc/frankenphp/Caddyfile", "--adapter", "caddyfile"]

WORKDIR /app
ENV PATH=${PATH}:/app/vendor/bin

HEALTHCHECK --interval=30s --timeout=5s --start-period=5m --start-interval=5s --retries=3 \
	CMD ["php", "-r", "exit(@fsockopen('127.0.0.1', 80, $e, $s, 2) ? 0 : 1);"]
