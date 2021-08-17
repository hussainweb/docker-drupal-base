ARG PHP_VERSION=7.4-apache-buster
FROM composer:2.0 AS composer

# from https://www.drupal.org/docs/8/system-requirements/drupal-8-php-requirements
FROM php:${PHP_VERSION}

# install the PHP extensions we need
RUN set -eux; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		git \
		unzip \
		sendmail \
		mariadb-client \
	; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get install -y --no-install-recommends \
		libbz2-dev \
		libfreetype6-dev \
		libjpeg-dev \
		libmemcached-dev \
		libpng-dev \
		libpq-dev \
		libyaml-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		bcmath \
		bz2 \
		exif \
		gd \
		intl \
		opcache \
		pcntl \
		pdo_mysql \
		pdo_pgsql \
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
		| awk '/=>/ { print $3 }' \
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
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
# Remove the memory limit for the CLI only.
	echo 'memory_limit = -1' > /usr/local/etc/php/php-cli.ini; \
# Change docroot since we use Composer Drupal project.
	sed -ri -e 's!/var/www/html!/var/www/html/web!g' /etc/apache2/sites-available/*.conf; \
	sed -ri -e 's!/var/www!/var/www/html/web!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

WORKDIR /var/www/html

COPY --from=composer /usr/bin/composer /usr/bin/composer
