ARG PHP_VERSION=8.0-apache-bullseye
# from https://www.drupal.org/docs/system-requirements/php-requirements
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
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libbz2-dev \
		libfreetype6-dev \
		libicu-dev \
		libjpeg-dev \
		libmemcached-dev \
		libpng-dev \
		libpq-dev \
		libwebp-dev \
		libyaml-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
		--with-webp \
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
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
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

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/
ENV PATH=${PATH}:/var/www/html/vendor/bin
