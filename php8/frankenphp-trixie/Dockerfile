ARG PHP_VERSION=8.4
FROM dunglas/frankenphp:php${PHP_VERSION}-trixie

# install the PHP extensions we need
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		git \
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
COPY Caddyfile /etc/caddy/Caddyfile

WORKDIR /app
ENV PATH=${PATH}:/app/vendor/bin
