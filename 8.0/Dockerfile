ARG PHP_VERSION=8.0
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

ENV PORT=$PORT
ENV PUBLIC_DIR=$PUBLIC_DIR

ENV REQUIRED_PACKAGES="git make zlib-dev libzip-dev zip curl supervisor python3 ca-certificates pcre linux-headers gettext-dev mysql-dev postgresql-dev rabbitmq-c icu libsodium-dev oniguruma-dev libjpeg-turbo-dev freetype-dev libpng-dev libwebp libwebp-dev libpng freetype libjpeg-turbo jpegoptim optipng pngquant gifsicle"
ENV DEVELOPMENT_PACKAGES="autoconf g++ openssh-client tar py-pip pcre-dev rabbitmq-c-dev icu-dev"
ENV PECL_PACKAGES="redis apcu ast mongodb"
ENV EXT_PACKAGES="zip sockets pdo_mysql pdo_pgsql bcmath opcache mbstring iconv gettext intl exif sodium gd pcntl sysvmsg sysvsem sysvshm"

ENV DOCKER=true
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_NO_INTERACTION 1
ENV COMPOSER_CACHE_DIR /tmp

WORKDIR /app

# Copying manifest files to host
COPY ./8.0/manifest /

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
RUN docker-php-ext-configure gd --with-freetype --with-jpeg

# Install Non-Pecl Packages
RUN docker-php-ext-install $EXT_PACKAGES

# Install Pecl Packages
#RUN apk add --no-cache $PHPIZE_DEPS && wget https://github.com/FriendsOfPHP/pickle/releases/latest/download/pickle.phar && mv pickle.phar /usr/local/bin/pickle && chmod +x /usr/local/bin/pickle
#RUN for package in $PICKLE_PACKAGES; do pickle install $package --defaults; done
RUN yes '' | pecl install -f $PECL_PACKAGES
RUN docker-php-ext-enable $PECL_PACKAGES

# AMQP from master @TODO upgrade to release version when php8 support is ready
ENV EXT_AMQP_VERSION=master
RUN docker-php-source extract \
    && apk -Uu add git rabbitmq-c-dev \
    && git clone --branch $EXT_AMQP_VERSION --depth 1 https://github.com/php-amqp/php-amqp.git /usr/src/php/ext/amqp \
    && cd /usr/src/php/ext/amqp && git submodule update --init \
    && docker-php-ext-install amqp \
    && docker-php-source delete

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
