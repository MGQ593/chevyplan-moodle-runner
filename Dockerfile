FROM php:8.2-apache

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      libpng-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev \
      libzip-dev \
      libicu-dev \
      unzip \
      git \
      curl \
      ca-certificates \
    ; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" \
      gd \
      mysqli \
      pdo \
      pdo_mysql \
      zip \
      opcache \
      intl \
    ; \
    a2enmod rewrite remoteip

# PHP config para Moodle
RUN set -eux; \
  { \
    echo 'opcache.enable=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.validate_timestamps=1'; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini; \
  { \
    echo 'max_input_vars = 5000'; \
    echo 'session.cookie_httponly = 1'; \
  } > /usr/local/etc/php/conf.d/moodle-php.ini

# RemoteIP para proxy
RUN echo '<IfModule remoteip_module>\n\
    RemoteIPHeader X-Forwarded-For\n\
    RemoteIPInternalProxy 10.0.0.0/8\n\
    RemoteIPInternalProxy 172.16.0.0/12\n\
    RemoteIPInternalProxy 192.168.0.0/16\n\
</IfModule>' > /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip

# DocumentRoot apunta a public (Moodle 5.1)
RUN sed -i 's|/var/www/html|/var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

ARG MOODLE_TGZ_URL="https://download.moodle.org/download.php/direct/stable501/moodle-5.1.3.tgz"
RUN set -eux; \
    rm -rf /var/www/html/*; \
    curl -fsSL "${MOODLE_TGZ_URL}" -o /tmp/moodle.tgz; \
    tar -xzf /tmp/moodle.tgz -C /var/www/html --strip-components=1; \
    rm -f /tmp/moodle.tgz; \
    mkdir -p /var/www/moodledata/sessions; \
    chown -R www-data:www-data /var/www/html /var/www/moodledata; \
    find /var/www/html -type d -exec chmod 0755 {} \;; \
    find /var/www/html -type f -exec chmod 0644 {} \;; \
    chmod 0770 /var/www/moodledata

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV MOODLE_WWWROOT="https://automatizacion-moodle-app.0hidyn.easypanel.host" \
    MOODLE_DB_HOST="bases_moodle-db" \
    MOODLE_DB_NAME="moodle" \
    MOODLE_DB_USER="moodle" \
    MOODLE_DB_PASS="MoodleDB@2026!"

WORKDIR /var/www/html
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
