# from https://www.drupal.org/docs/8/system-requirements/drupal-8-php-requirements
FROM php:7.2-apache-buster
# TODO switch to buster once https://github.com/docker-library/php/issues/865 is resolved in a clean way (either in the PHP image or in PHP itself)

# install the PHP extensions we need
RUN set -eux; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libpng-dev \
		libpq-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype-dir=/usr \
		--with-jpeg-dir=/usr \
		--with-png-dir=/usr \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		gd \
		opcache \
		pdo_mysql \
		zip \
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
#ENV PHP_MEMORY_LIMIT 1024M
#ENV PHP_MAX_EXECUTION_TIME 900
#RUN sed -i \
#    -e "s/^memory_limit.*\$/memory_limit = $PHP_MEMORY_LIMIT/g" \
#    -e "s/^max_execution_time.*\$/max_execution_time = $PHP_MAX_EXECUTION_TIME/g" \
#    /usr/local/etc/php/php.ini-production

# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=256'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

WORKDIR /var/www/html

# https://www.drupal.org/node/3060/release
ENV DRUPAL_MD5 d075c610c29f6de98080584610ffa241
RUN set -eux; \
	curl -fSL "https://ftp.drupal.org/files/projects/openatrium-7.x-2.646-core.tar.gz"; \
	echo "${DRUPAL_MD5} *openatrium-7.x-2.646-core.tar.gz" | md5sum -c -; \
	tar -xz --strip-components=1 -f openatrium-7.x-2.646-core.tar.gz; \
	rm openatrium-7.x-2.646-core.tar.gz; \
	chown -R www-data:www-data sites modules themes profiles

# vim:set ft=dockerfile:
