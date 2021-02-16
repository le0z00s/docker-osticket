# Deployment doesn't work on Alpine
FROM php:7.3-cli AS deployer
ENV OSTICKET_VERSION=1.14.3
RUN set -x \
    && apt-get update \
    && apt-get install -y git-core \
    && git clone -b v${OSTICKET_VERSION} --depth 1 https://github.com/osTicket/osTicket.git \
    && cd osTicket \
    && php manage.php deploy -sv /data/upload \
    # www-data is uid:gid 82:82 in php:7.0-fpm-alpine
    && chown -R 82:82 /data/upload \
    # Hide setup
    && mv /data/upload/setup /data/upload/setup_hidden \
    && chown -R root:root /data/upload/setup_hidden \
    && chmod -R go= /data/upload/setup_hidden

FROM php:7.3-fpm-alpine
MAINTAINER Rafał Zbojak <rafal.zbojak@gmail.com>
# environment for osticket
ENV HOME=/data
# setup workdir
WORKDIR /data
COPY --from=deployer /data/upload upload
RUN set -x && \
    # requirements and PHP extensions
    apk add --no-cache --update \
        wget \
        git \
        msmtp \
        ca-certificates \
        supervisor \
        nginx \
        libpng \
        c-client \
        openldap \
        libintl \
        libxml2 \
        icu \
        openssl && \
    apk add --no-cache --virtual .build-deps \
        imap-dev \
        libpng-dev \
        curl-dev \
        openldap-dev \
        gettext-dev \
        libxml2-dev \
        icu-dev \
        autoconf \
        g++ \
        make \
        pcre-dev && \
    docker-php-ext-install gd curl ldap mysqli sockets gettext mbstring xml intl opcache && \
    docker-php-ext-configure imap --with-imap-ssl && \
    docker-php-ext-install imap && \
    pecl install apcu && docker-php-ext-enable apcu && \
    apk del .build-deps && \
    rm -rf /var/cache/apk/* && \
    # Download languages packs
    wget -nv -O upload/include/i18n/fr.phar https://s3.amazonaws.com/downloads.osticket.com/lang/fr.phar && \
    wget -nv -O upload/include/i18n/de.phar https://s3.amazonaws.com/downloads.osticket.com/lang/de.phar && \
    wget -nv -O upload/include/i18n/lv.phar https://s3.amazonaws.com/downloads.osticket.com/lang/lv.phar && \
    wget -nv -O upload/include/i18n/lt.phar https://s3.amazonaws.com/downloads.osticket.com/lang/lt.phar && \
    wget -nv -O upload/include/i18n/pl.phar https://s3.amazonaws.com/downloads.osticket.com/lang/pl.phar && \
    wget -nv -O upload/include/i18n/pt.phar https://s3.amazonaws.com/downloads.osticket.com/lang/pt.phar && \
    wget -nv -O upload/include/i18n/pt_BR.phar https://s3.amazonaws.com/downloads.osticket.com/lang/pt_BR.phar && \
    wget -nv -O upload/include/i18n/ru.phar https://s3.amazonaws.com/downloads.osticket.com/lang/ru.phar && \
    wget -nv -O upload/include/i18n/es_ES.phar https://s3.amazonaws.com/downloads.osticket.com/lang/es_ES.phar && \
    wget -nv -O upload/include/i18n/it.phar https://s3.amazonaws.com/downloads.osticket.com/lang/it.phar && \
    wget -nv -O upload/include/i18n/uk.phar https://s3.amazonaws.com/downloads.osticket.com/lang/uk.phar && \
    wget -nv -O upload/include/i18n/cs.phar https://s3.amazonaws.com/downloads.osticket.com/lang/cs.phar && \
    wget -nv -O upload/include/i18n/sk.phar https://s3.amazonaws.com/downloads.osticket.com/lang/sk.phar && \
    mv upload/include/i18n upload/include/i18n.dist && \
    # Download plugins
    wget -nv -O upload/include/plugins/auth-ldap.phar https://s3.amazonaws.com/downloads.osticket.com/plugin/auth-ldap.phar && \
    wget -nv -O upload/include/plugins/auth-password-policy.phar https://s3.amazonaws.com/downloads.osticket.com/plugin/auth-password-policy.phar && \
    wget -nv -O upload/include/plugins/2fa-gauth.phar https://s3.amazonaws.com/downloads.osticket.com/plugin/2fa-gauth.phar && \
    git clone https://github.com/Micke1101/OSTicket-plugin-field-radiobuttons upload/include/plugins/field-radiobuttons && \
    git clone https://github.com/clonemeagain/osticket-slack upload/include/plugins/slack && \
    git clone https://github.com/ipavlovi/osTicket-Microsoft-Teams-plugin upload/include/plugins/teams && \
    git clone https://github.com/kyleladd/OSTicket-Trello-Plugin upload/include/plugins/trello && \
    # Install Bootstrap Theme
    git clone https://github.com/philbertphotos/osticket-bootstrap-theme upload/osticket-bootstrap-theme && \
    mv upload/osticket-bootstrap-theme/* upload/ && \
    rmdir upload/osticket-bootstrap-theme && \
    # Create msmtp log
    touch /var/log/msmtp.log && \
    chown www-data:www-data /var/log/msmtp.log && \
    # File upload permissions
    mkdir -p /var/tmp/nginx && \
    chown nginx:www-data /var/tmp/nginx && chmod g+rx /var/tmp/nginx
COPY src/ /
VOLUME ["/data/upload/include/plugins","/data/upload/include/i18n","/var/log/nginx"]
EXPOSE 80
CMD ["/data/bin/start.sh"]