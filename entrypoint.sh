#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/var/www/html/config.php"

mkdir -p /var/www/moodledata/sessions
chown -R www-data:www-data /var/www/html /var/www/moodledata

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "[entrypoint] config.php no existe. Ejecutando instalación CLI de Moodle..."

  echo "[entrypoint] Esperando disponibilidad de base de datos en ${MOODLE_DB_HOST}..."
  for i in {1..60}; do
    if php -r "
      \$h=getenv('MOODLE_DB_HOST');
      \$db=getenv('MOODLE_DB_NAME');
      \$u=getenv('MOODLE_DB_USER');
      \$p=getenv('MOODLE_DB_PASS');
      try {
        new PDO(\"mysql:host=\$h;dbname=\$db;charset=utf8mb4\", \$u, \$p, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
        exit(0);
      } catch (Throwable \$e) {
        exit(1);
      }
    "; then
      echo "[entrypoint] Base de datos OK."
      break
    fi
    echo "[entrypoint] DB no lista aún (${i}/60). Reintentando..."
    sleep 2
  done

  su -s /bin/bash www-data -c "php /var/www/html/admin/cli/install.php \
    --non-interactive \
    --agree-license \
    --lang=es \
    --wwwroot='${MOODLE_WWWROOT}' \
    --dataroot='/var/www/moodledata' \
    --dbtype='mariadb' \
    --dbhost='${MOODLE_DB_HOST}' \
    --dbname='${MOODLE_DB_NAME}' \
    --dbuser='${MOODLE_DB_USER}' \
    --dbpass='${MOODLE_DB_PASS}' \
    --fullname='Academia ChevyPlan' \
    --shortname='AcademiaCP' \
    --adminuser='admin' \
    --adminpass='Admin123*' \
    --adminemail='admin@chevyplan.com.ec'"

  # Agregar sslproxy para EasyPanel
  sed -i "/require_once/i \$CFG->sslproxy = true;" "${CONFIG_FILE}"

  echo "[entrypoint] Instalación completada."
else
  echo "[entrypoint] config.php ya existe. Omitiendo instalación."
fi

exec apache2-foreground
