FROM php:7-fpm-alpine

ARG ALPINE_MIRROR
ARG COMPOSER_MIRROR
ARG TIMEZONE

WORKDIR /var/www/html

RUN set -e; \
# Switch to a mirror if given
    if [ -n "${ALPINE_MIRROR}" ]; then \
        sed -i 's!http://dl-cdn.alpinelinux.org!'"${ALPINE_MIRROR}"'!g' /etc/apk/repositories; \
    fi; \
# Install build dependency packages
    apk update; \
    apk add --virtual .phpize-deps-configure $PHPIZE_DEPS libzip-dev tzdata; \
# Setup timezone
    if [ -n "${TIMEZONE}" ]; then \
        cp "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime; \
        echo "${TIMEZONE}" > /etc/timezone; \
    fi; \
# PECL Extensions
    pecl install redis; \
    docker-php-ext-enable redis; \
# PHP Extensions
    docker-php-ext-install -j$(nproc) exif pcntl pdo_mysql zip; \
    docker-php-source delete; \
# Install run dependency packages
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
        | tr ',' '\n' \
        | sort -u \
        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --virtual .php-rundeps $runDeps nginx npm; \
# Cleanup
    rm -rf /tmp/pear; \
    rm -rf /var/cache/apk/*; \
# System configurations
    mkdir -p /run/nginx; \
    sed -i '$i test -e /run/nginx/nginx.pid || nginx ' /usr/local/bin/docker-php-entrypoint; \
    { \
        echo 'server {'; \
        echo '    listen      80 default_server;'; \
        echo '    server_name _;'; \
        echo '    root        /var/www/html/public;'; \
        echo '    index       index.php;'; \
        echo '    charset     utf-8;'; \
        echo; \
        echo '    location / {'; \
        echo '        try_files $uri /index.php?$query_string;'; \
        echo '    }'; \
        echo; \
        echo '    location ~ \.php$ {'; \
        echo '        fastcgi_pass    127.0.0.1:9000;'; \
        echo '        fastcgi_index   index.php;'; \
        echo '        fastcgi_param   SCRIPT_FILENAME $document_root$fastcgi_script_name;'; \
        # HTTP_HOST
        echo '        include         fastcgi_params;'; \
        echo '    }'; \
        echo '}'; \
    } | tee /etc/nginx/conf.d/default.conf; \
    curl -sSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer;

USER www-data

RUN set -e; \
    curl -sSL https://github.com/ProcessMaker/processmaker/archive/develop.tar.gz | tar --strip-components=1 -zx; \
    composer config repo.packagist composer "${COMPOSER_MIRROR}"; \
    # rm composer.lock; \
    composer install; \
    npm install --unsafe-perm=true; \
    npm run dev; \
    php artisan storage:link; \
    php artisan vendor:publish --tag telescope-assets --force;

USER root

EXPOSE 80
