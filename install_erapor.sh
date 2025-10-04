#!/bin/bash
# =========================================================
# Auto Installer eRapor SMK 7
# by Abdur Rozak, SMKS YASMIDA Ambarawa
# GitHub: https://github.com/abdurrozakskom
# License: MIT
# =========================================================
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
# =========================================================

if [ "$EUID" -ne 0 ]; then
  echo "❌ Jalankan sebagai root (sudo ./install_erapor_ip_final_v5_allinone.sh)"
  exit
fi

# Lokasi log file
# Membuat log file dan mengalihkan semua output stdout & stderr
exec > >(tee -a "$LOG_FILE") 2>&1
mkdir -p /var/log/erapor
LOG_FILE="/var/log/erapor/erapor_install.log"
touch $LOG_FILE
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Mulai instalasi eRapor SMK $(date) ==="


# ---- Input User ----
read -p "Masukkan IP server (contoh: 192.168.66.99): " SERVER_IP
read -p "Masukkan APP Name (contoh: eRapor SMK): " APP_NAME
read -p "Masukkan nama database PostgreSQL: " DB_NAME
read -p "Masukkan username database: " DB_USER
read -sp "Masukkan password database: " DB_PASS
echo ""

# ---- Update Paket ----
echo "[1/13] Update Sistem & Upgrade Sistem"
apt update && apt upgrade -y

# ---- Install Paket ----
echo "[2/13] Install Paket Pendukung"
apt install -y unzip curl git cowsay

# ---- Install Paket LAMP Stack----
echo "[3/13] Install Paket Apache2"
apt install -y apache2 libapache2-mod-fcgid \
    php php-cli php-fpm php-pgsql php-xml php-mbstring php-curl php-zip php-bcmath php-gd php-redis \
    composer postgresql postgresql-contrib redis-server sudo lsb-release

# ---- Tuning Apache2 ----
echo "[3/13] Tuning Apache2 untuk performa eRapor SMK..."

# Pastikan menggunakan mpm_prefork
a2enmod mpm_prefork >/dev/null 2>&1

APACHE_CONF="/etc/apache2/apache2.conf"
MPM_CONF="/etc/apache2/mods-available/mpm_prefork.conf"

if [ -f "$MPM_CONF" ]; then
    sed -i "s/^StartServers.*/StartServers             4/" $MPM_CONF
    sed -i "s/^MinSpareServers.*/MinSpareServers          2/" $MPM_CONF
    sed -i "s/^MaxSpareServers.*/MaxSpareServers          6/" $MPM_CONF
    sed -i "s/^MaxRequestWorkers.*/MaxRequestWorkers      50/" $MPM_CONF
    sed -i "s/^MaxConnectionsPerChild.*/MaxConnectionsPerChild  1000/" $MPM_CONF
fi

# KeepAlive tuning
sed -i "s/^KeepAlive.*/KeepAlive On/" $APACHE_CONF
sed -i "s/^#KeepAliveTimeout.*/KeepAliveTimeout 5/" $APACHE_CONF
sed -i "s/^#MaxKeepAliveRequests.*/MaxKeepAliveRequests 100/" $APACHE_CONF

systemctl restart apache2
echo "[✓] Apache2 tuning selesai."


# ---- Tuning PHP-FPM ----
echo "[3/13] Tuning PHP-FPM untuk performa eRapor SMK..."
PHP_FPM_POOL="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"

if [ -f "$PHP_FPM_POOL" ]; then
    sed -i "s/^pm.max_children = .*/pm.max_children = 20/" $PHP_FPM_POOL
    sed -i "s/^pm.start_servers = .*/pm.start_servers = 4/" $PHP_FPM_POOL
    sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = 2/" $PHP_FPM_POOL
    sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = 6/" $PHP_FPM_POOL
fi

# Tuning php.ini
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    sed -i "s/^memory_limit = .*/memory_limit = 512M/" $PHP_INI
    sed -i "s/^max_execution_time = .*/max_execution_time = 300/" $PHP_INI
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 100M/" $PHP_INI
    sed -i "s/^post_max_size = .*/post_max_size = 100M/" $PHP_INI
fi

systemctl restart php${PHP_VERSION}-fpm
echo "[✓] PHP-FPM tuning selesai."


# ---- Setup PostgreSQL ----
echo "[4/13] Membuat database PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"

# ---- Tuning PostgreSQL ----
echo "[4/13] Tuning PostgreSQL untuk performa eRapor SMK..."
PG_CONF="/etc/postgresql/$(psql -V | awk '{print $3}' | cut -d. -f1,2)/main/postgresql.conf"

if [ -f "$PG_CONF" ]; then
    RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM_MB=$((RAM_KB/1024))
    SHARED_BUFFERS=$((RAM_MB/4))   # 25% RAM
    WORK_MEM=16MB
    MAX_CONNECTIONS=50
    MAINTENANCE_WORK_MEM=128MB
    EFFECTIVE_CACHE_SIZE=$((RAM_MB/2))MB

    sed -i "s/^#*shared_buffers = .*/shared_buffers = ${SHARED_BUFFERS}MB/" $PG_CONF
    sed -i "s/^#*work_mem = .*/work_mem = $WORK_MEM/" $PG_CONF
    sed -i "s/^#*max_connections = .*/max_connections = $MAX_CONNECTIONS/" $PG_CONF
    sed -i "s/^#*maintenance_work_mem = .*/maintenance_work_mem = $MAINTENANCE_WORK_MEM/" $PG_CONF
    sed -i "s/^#*effective_cache_size = .*/effective_cache_size = $EFFECTIVE_CACHE_SIZE/" $PG_CONF
fi

systemctl restart postgresql
echo "[✓] PostgreSQL tuning selesai."

# ---- Clone eRapor ----
echo "[5/13] Clone repo eRapor SMK..."
cd /var/www/
git clone https://github.com/eraporsmk/erapor7.git erapor
cd erapor
cp .env.example .env

# ---- Update .env (APP + DB + Redis) ----
echo "[6/13] Konfigurasi .env..."
sed -i "s/^APP_NAME=.*/APP_NAME=\"$APP_NAME\"/" .env
sed -i "s#^APP_URL=.*#APP_URL=http://$SERVER_IP#" .env

sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=pgsql/" .env
sed -i "s/DB_HOST=.*/DB_HOST=127.0.0.1/" .env
sed -i "s/DB_PORT=.*/DB_PORT=5432/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env

# Redis
sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/" .env
sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=redis/" .env
sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/" .env
sed -i "s/REDIS_HOST=.*/REDIS_HOST=127.0.0.1/" .env
sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=null/" .env
sed -i "s/REDIS_PORT=.*/REDIS_PORT=6379/" .env

# ---- Install Composer Dependencies ----
echo "[7/13] Install Composer dependencies (vendor)..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist --optimize-autoloader

# ---- Laravel Setup ----
echo "[8/13] Setup Laravel..."
php artisan key:generate
php artisan migrate --no-interaction
php artisan db:seed --no-interaction

# ---- Storage link check ----
echo "[9/13] Storage link check..."
if [ ! -L public/storage ]; then
    php artisan storage:link
else
    echo "[i] Storage link sudah ada, skip."
fi

# ---- Fix Permission & Clear Cache ----
echo "[10/13] Fix permission & clear cache..."
chown -R www-data:www-data /var/www/erapor
chmod -R 775 /var/www/erapor/storage /var/www/erapor/bootstrap/cache
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# ---- Restart Redis ----
echo "[11/13] Restart Redis server..."
systemctl enable redis-server
systemctl restart redis-server

# ---- Apache VirtualHost ----
echo "[12/13] Konfigurasi Apache VirtualHost..."
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
VHOST_FILE="/etc/apache2/sites-available/erapor.conf"

cat > $VHOST_FILE <<EOL
<VirtualHost *:80>
    ServerName $SERVER_IP
    DocumentRoot /var/www/erapor/public

    <Directory /var/www/erapor/public>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch ".+\.php$">
        SetHandler "proxy:unix:/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/erapor-error.log
    CustomLog \${APACHE_LOG_DIR}/erapor-access.log combined
</VirtualHost>
EOL

a2ensite erapor.conf
a2enmod proxy_fcgi setenvif rewrite
systemctl restart apache2
systemctl restart php${PHP_VERSION}-fpm

# ---- Update Versi Aplikasi ----
echo "[13/13] Update Versi Aplikasi"
php artisan erapor:update

# ---- Fun cowsay ----
if command -v cowsay >/dev/null 2>&1; then
    cowsay "eRaporSMK"
else
    echo "[i] Install cowsay untuk melihat pesan lucu: sudo apt install cowsay"
fi
# ---- Summary & Info Server ----
echo "[DONE] Instalasi selesai! Info server & versi paket:"
echo "🎉 Instalasi eRapor SMK selesai!"
echo "APP_NAME : $APP_NAME"
echo "APP_URL  : http://$SERVER_IP"
echo "Redis    : Terpasang dan terhubung ke Laravel"
echo "Folder eRapor berada di: /var/www/erapor"
echo "Buka di browser: http://$SERVER_IP"
echo "Log instalasi tersimpan di: $LOG_FILE"
echo "Jika ada error, silakan cek log untuk troubleshoot."
echo ""
echo "📌 Credit Author:"
echo "Script ini dibuat oleh: Abdur Rozak, SMKS YASMIDA Ambarawa"
echo "GitHub: https://github.com/abdurrozakskom/"
echo ""
echo "📌 Spesifikasi Server & Versi Paket:"
echo "OS        : $(lsb_release -ds)"
echo "Kernel    : $(uname -r)"
echo "Apache    : $(apache2 -v | grep 'Server version' | awk '{print $3}')"
echo "PHP       : $(php -v | head -n 1 | awk '{print $2}')"
echo "PostgreSQL: $(psql --version | awk '{print $3}')"
echo "Redis     : $(redis-server --version | awk '{print $3}' | sed 's/=//')"
echo "Composer  : $(composer --version | awk '{print $3}')"
