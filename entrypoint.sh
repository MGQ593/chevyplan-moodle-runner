#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/var/www/html/config.php"

# Asegurar permisos (útil si montas volúmenes)
mkdir -p /var/www/moodledata
chown -R www-data:www-data /var/www/html /var/www/moodledata

if [ ! -f "${CONFIG_FILE}" ]; then
  echo "[entrypoint] config.php no existe. Ejecutando instalación CLI de Moodle..."

  : "
${MOODLE_WWWROOT:?La variable MOODLE_WWWROOT es requerida}"
  : "
${MOODLE_DB_HOST:?La variable MOODLE_DB_HOST es requerida}"
  : "
${MOODLE_DB_NAME:?La variable MOODLE_DB_NAME es requerida}"
  : "
${MOODLE_DB_USER:?La variable MOODLE_DB_USER es requerida}"
  : "
${MOODLE_DB_PASS:?La variable MOODLE_DB_PASS es requerida}"
  : "
${MOODLE_ADMIN_PASS:?La variable MOODLE_ADMIN_PASS es requerida}"

  # Espera básica a que la DB esté disponible (MySQL/MariaDB)
  echo "[entrypoint] Esperando disponibilidad de base de datos en ${MOODLE_DB_HOST}..."
  for i in {1..60}; do
    if php -r ' 
      $h=getenv("MOODLE_DB_HOST");
      $db=getenv("MOODLE_DB_NAME");
      $u=getenv("MOODLE_DB_USER");
      $p=getenv("MOODLE_DB_PASS");
      try {
        new PDO("mysql:host=$h;dbname=$db;charset=utf8mb4", $u, $p, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
        exit(0);
      } catch (Throwable $e) {
        exit(1);
      }
    '; then
      echo "[entrypoint] Base de datos OK."
      break
    fi
    echo "[entrypoint] DB no lista aún (${i}/60). Reintentando..."
    sleep 2
  done

  if ! php -r '
    $h=getenv("MOODLE_DB_HOST");
    $db=getenv("MOODLE_DB_NAME");
    $u=getenv("MOODLE_DB_USER");
    $p=getenv("MOODLE_DB_PASS");
    try {
      new PDO("mysql:host=$h;dbname=$db;charset=utf8mb4", $u, $p, [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
      exit(0);
    } catch (Throwable $e) {
      exit(1);
    }
  '; then
    echo "[entrypoint] ERROR: No se pudo conectar a la base de datos después de 60 intentos. Abortando." >&2
    exit 1
  fi

  # Ejecutar el instalador CLI como www-data para evitar problemas de permisos
  su -s /bin/bash www-data -c "php /var/www/html/admin/cli/install.php \
    --non-interactive \
    --agree-license \
    --lang=es \
    --wwwroot='${MOODLE_WWWROOT}' \
    --dataroot='/var/www/moodledata' \
    --dbtype='mysqli' \
    --dbhost='${MOODLE_DB_HOST}' \
    --dbname='${MOODLE_DB_NAME}' \
    --dbuser='${MOODLE_DB_USER}' \
    --dbpass='${MOODLE_DB_PASS}' \
    --fullname='Academia ChevyPlan' \
    --shortname='AcademiaCP' \
    --adminuser='admin' \
    --adminpass="${MOODLE_ADMIN_PASS}" \
    --adminemail='admin@chevyplan.com.ec'"

  echo "[entrypoint] Instalación completada."
else
  echo "[entrypoint] config.php ya existe. Omitiendo instalación."
fi

# Apache en primer plano
exec apache2-foreground
