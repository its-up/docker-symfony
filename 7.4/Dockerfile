ARG PHP_VERSION=7.4
ARG CADDY_VERSION=2

# -----------------------------------------------------
# Caddy Install
# -----------------------------------------------------
FROM caddy:$CADDY_VERSION-builder AS builder

RUN xcaddy build

FROM caddy:$CADDY_VERSION

# -----------------------------------------------------
# App Itself
# -----------------------------------------------------
FROM php:$PHP_VERSION-fpm-alpine

ARG PORT=9001
ARG PUBLIC_DIR=public
ARG NO_FREETYPE

ENV PORT=$PORT
ENV PUBLIC_DIR=$PUBLIC_DIR

ENV REQUIRED_PACKAGES="git make zlib-dev libzip-dev zip curl supervisor pcre linux-headers gettext-dev mysql-dev postgresql-dev rabbitmq-c php7-amqp icu libsodium-dev oniguruma-dev freetype-dev libpng-dev libjpeg-turbo-dev libxml2-dev libacl libmagic imagemagick-dev imagemagick jpegoptim optipng pngquant"
ENV DEVELOPMENT_PACKAGES="autoconf g++ openssh-client tar python3 py-pip pcre-dev rabbitmq-c-dev icu-dev"
ENV PECL_PACKAGES="redis amqp apcu mongodb imagick"
ENV EXT_PACKAGES="zip sockets pdo_mysql pdo_pgsql bcmath opcache mbstring iconv gettext intl exif sodium gd sysvmsg sysvsem sysvshm pcntl"

ENV DOCKER=true
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_NO_INTERACTION 1
ENV COMPOSER_CACHE_DIR /tmp

WORKDIR /app

# Copying manifest files to host
COPY ./7.4/manifest /

# Caddy
COPY --from=builder /usr/bin/caddy /usr/local/bin/caddy

# Composer install
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install Packages
RUN apk add --update --no-cache $REQUIRED_PACKAGES $DEVELOPMENT_PACKAGES

# Update ulimit
RUN ulimit -n 16384

# Fix Iconv
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php

# Configure GD to use freetype fonts
RUN if [[ -z "$NO_FREETYPE" ]]; then \
    docker-php-ext-configure gd --with-freetype --with-jpeg; fi

# Install Pecl Packages
RUN yes '' | pecl install -f $PECL_PACKAGES
RUN docker-php-ext-enable $PECL_PACKAGES

# Install Non-Pecl Packages
RUN docker-php-ext-install $EXT_PACKAGES

# MaxMind
RUN apk add --no-cache libmaxminddb \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS git libmaxminddb-dev \
    && git clone https://github.com/maxmind/MaxMind-DB-Reader-php.git \
    && ( \
      cd MaxMind-DB-Reader-php/ext \
      && phpize \
      && ./configure \
      && make \
      && make install \
    ) \
    && rm -r MaxMind-DB-Reader-php \
    && docker-php-ext-enable maxminddb

# Delete Non-Required Packages
RUN apk del $DEVELOPMENT_PACKAGES
