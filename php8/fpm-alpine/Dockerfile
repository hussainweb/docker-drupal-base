ARG PHP_VERSION=8.4-fpm-alpine
# from https://www.drupal.org/docs/system-requirements/php-requirements
FROM php:${PHP_VERSION}

# install the PHP extensions we need
RUN set -eux; \
	\
	apk add --no-cache \
		git \
		patch \
		unzip \
		mariadb-client \
	; \
	\
    apk add --no-cache --virtual .build-deps \
		autoconf \
		bzip2-dev \
		coreutils \
		freetype-dev \
		libjpeg-turbo-dev \
		libmemcached-dev \
		libpng-dev \
		libwebp-dev \
		libzip-dev \
		linux-headers \
		make \
		yaml-dev \
# postgresql-dev is needed for https://bugs.alpinelinux.org/issues/3642
		postgresql-dev \
		zstd-libs \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr/include \
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
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .drupal-phpexts-rundeps $runDeps; \
	apk del --no-network .build-deps

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
# Remove the memory limit for the CLI only.
	echo 'memory_limit = -1' > /usr/local/etc/php/php-cli.ini;

WORKDIR /var/www/html

ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/
ENV PATH=${PATH}:/var/www/html/vendor/bin
