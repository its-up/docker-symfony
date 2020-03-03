ARG PHP_VERSION=7.4

# -----------------------------------------------------
# Caddy Install
# -----------------------------------------------------
FROM alpine as caddy

ARG plugins=http.git,http.cache,http.expires,http.minify,http.realip

RUN apk --update add git curl linux-headers

RUN curl --silent --show-error --fail --location \
      --header "Accept: application/tar+gzip, application/x-gzip, application/octet-stream" -o - \
      "https://caddyserver.com/download/linux/amd64?plugins=${plugins}&license=personal&telemetry=off" \
    | tar --no-same-owner -C /tmp -xz caddy \
    && chmod 0755 /tmp/caddy

# -----------------------------------------------------
# App Itself
# -----------------------------------------------------
FROM php:$PHP_VERSION-fpm-alpine

ARG PORT=9001
ARG PUBLIC_DIR=public
ARG DECORATE_WORKERS

ENV PORT=$PORT
ENV PUBLIC_DIR=$PUBLIC_DIR

ENV REQUIRED_PACKAGES="git make zlib-dev libzip-dev zip curl supervisor pcre linux-headers gettext-dev mysql-dev postgresql-dev rabbitmq-c php7-amqp icu libsodium-dev oniguruma-dev libmagic imagemagick-dev imagemagick jpegoptim optipng pngquant"
ENV DEVELOPMENT_PACKAGES="autoconf g++ openssh-client tar python py-pip pcre-dev rabbitmq-c-dev icu-dev"
ENV PECL_PACKAGES="redis amqp apcu mongodb imagick"
ENV EXT_PACKAGES="zip sockets pdo_mysql pdo_pgsql bcmath opcache mbstring iconv gettext intl exif sodium gd sysvmsg sysvsem sysvshm"

ENV DOCKER=true
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_NO_INTERACTION 1
ENV COMPOSER_CACHE_DIR /tmp

WORKDIR /app

# Copying manifest files to host
COPY ./manifest /

# Caddy
COPY --from=caddy /tmp/caddy /usr/local/sbin/caddy

# Composer install
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Hide decorators - only available for PHP 7.3 and above
RUN if [[ -z "$DECORATE_WORKERS" ]]; then \
    echo "decorate_workers_output = no" >> /usr/local/etc/php-fpm.d/docker.conf; fi

# Install Packages
RUN apk add --update --no-cache $REQUIRED_PACKAGES $DEVELOPMENT_PACKAGES

# Update ulimit
RUN ulimit -n 16384

# Fix Iconv
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php

# Install Non-Pecl Packages
RUN docker-php-ext-install $EXT_PACKAGES

# Install Pecl Packages
RUN yes '' | pecl install -f $PECL_PACKAGES
RUN docker-php-ext-enable $PECL_PACKAGES

# Install Parallel Composer Plugin
RUN composer global require hirak/prestissimo --no-plugins --no-scripts

# Delete Non-Required Packages
RUN apk del $DEVELOPMENT_PACKAGES
