FROM php:8.2-apache

# Dependencias del sistema requeridas por extensiones de PHP y por Moodle
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      libpng-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev \
      libzip-dev \
      unzip \
      git \
      curl \
      ca-certificates \
    ; \
    rm -rf /var/lib/apt/lists/*

# Extensiones PHP necesarias para Moodle
RUN set -eux; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-install -j"$(nproc)" \
      gd \
      mysqli \
      pdo \
      pdo_mysql \
      zip \
      opcache \
    ; \
    a2enmod rewrite

# Opcache recomendado para producción (ajusta según tu carga)
RUN set -eux; \
  { \
    echo 'opcache.enable=1'; \
    echo 'opcache.enable_cli=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.validate_timestamps=1'; \
  } > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Descargar Moodle 5.1 estable (tgz) y desplegarlo en /var/www/html
# Nota: "stable51" corresponde a la rama estable 5.1.
ARG MOODLE_TGZ_URL="https://download.moodle.org/download.php/direct/stable51/moodle-latest-51.tgz"

RUN set -eux; \
    rm -rf /var/www/html/*; \
    curl -fsSL "${MOODLE_TGZ_URL}" -o /tmp/moodle.tgz; \
    tar -xzf /tmp/moodle.tgz -C /var/www/html --strip-components=1; \
    rm -f /tmp/moodle.tgz; \
    mkdir -p /var/www/moodledata; \
    chown -R www-data:www-data /var/www/html /var/www/moodledata; \
    find /var/www/html -type d -exec chmod 0755 {} \;; \
    find /var/www/html -type f -exec chmod 0644 {} \;; \
    chmod 0770 /var/www/moodledata

# Copiar entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Variables por defecto (puedes sobreescribirlas en runtime)
ENV MOODLE_WWWROOT="http://localhost" \
    MOODLE_DB_HOST="db" \
    MOODLE_DB_NAME="moodle" \
    MOODLE_DB_USER="moodle" \
    MOODLE_DB_PASS="moodle"

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]