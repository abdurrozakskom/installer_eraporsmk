#!/bin/bash
# =========================================================
# Auto Installer eRapor SMK 7 (IP-based, Redis enabled)
# All-in-One Final v5
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

# ---- Input User ----
read -p "Masukkan IP server (contoh: 172.16.9.253): " SERVER_IP
read -p "Masukkan APP Name (contoh: eRapor SMK): " APP_NAME
read -p "Masukkan nama database PostgreSQL: " DB_NAME
read -p "Masukkan username database: " DB_USER
read -sp "Masukkan password database: " DB_PASS
echo ""

# ---- Update & Install Paket ----
echo "[1/10] Update sistem & install paket dasar + PHP extensions + Redis..."
apt update && apt upgrade -y
apt install -y apache2 libapache2-mod-fcgid unzip curl git \
    php php-cli php-fpm php-pgsql php-xml php-mbstring php-curl php-zip php-bcmath php-gd php-redis \
    composer postgresql postgresql-contrib redis-server sudo lsb-release

# ---- Setup PostgreSQL ----
echo "[2/10] Membuat database PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"

# ---- Clone eRapor ----
echo "[3/10] Clone repo eRapor SMK..."
cd /var/www/
git clone https://github.com/eraporsmk/erapor7.git erapor
cd erapor
cp .env.example .env

# ---- Update .env (APP + DB + Redis) ----
echo "[4/10] Konfigurasi .env..."
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
echo "[5/10] Install Composer dependencies (vendor)..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist --optimize-autoloader

# ---- Laravel Setup ----
echo "[6/10] Setup Laravel..."
php artisan key:generate
php artisan migrate --seed --no-interaction

# ---- Storage link check ----
if [ ! -L public/storage ]; then
    php artisan storage:link
else
    echo "[i] Storage link sudah ada, skip."
fi

# ---- Fix Permission & Clear Cache ----
echo "[7/10] Fix permission & clear cache..."
chown -R www-data:www-data /var/www/erapor
chmod -R 775 /var/www/erapor/storage /var/www/erapor/bootstrap/cache
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# ---- Restart Redis ----
echo "[8/10] Restart Redis server..."
systemctl enable redis-server
systemctl restart redis-server

# ---- Apache VirtualHost ----
echo "[9/10] Konfigurasi Apache VirtualHost..."
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

# ---- Summary & Info Server ----
echo "[10/10] Instalasi selesai! Info server & versi paket:"
echo "🎉 Instalasi eRapor SMK selesai!"
echo "APP_NAME : $APP_NAME"
echo "APP_URL  : http://$SERVER_IP"
echo "Redis    : Terpasang dan terhubung ke Laravel"
echo "Buka di browser: http://$SERVER_IP"
echo ""
echo "📌 Spesifikasi Server & Versi Paket:"
echo "OS        : $(lsb_release -ds)"
echo "Kernel    : $(uname -r)"
echo "Apache    : $(apache2 -v | grep 'Server version' | awk '{print $3}')"
echo "PHP       : $(php -v | head -n 1 | awk '{print $2}')"
echo "PostgreSQL: $(psql --version | awk '{print $3}')"
echo "Redis     : $(redis-server --version | awk '{print $3}' | sed 's/=//')"
echo "Composer  : $(composer --version | awk '{print $3}')"
