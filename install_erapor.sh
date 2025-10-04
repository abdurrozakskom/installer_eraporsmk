#!/bin/bash

# =========================================================
# Auto Installer eRapor SMK 7
# by Abdur Rozak, SMKS YASMIDA Ambarawa
# GitHub: https://github.com/abdurrozakskom
# License: MIT
# =========================================================

# ---- Warna ----
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

# ---- Pastikan root ----
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Jalankan sebagai root (sudo ./install_erapor.sh)${RESET}"
    exit
fi

# ---- Logging ----
mkdir -p /var/log/eraporsmk
LOG_FILE="/var/log/eraporsmk/erapor_install.log"
touch $LOG_FILE
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${CYAN}=== Mulai instalasi eRapor SMK $(date) ===${RESET}"

# ---- Input User ----
echo -e "${YELLOW}[INPUT] Silakan masukkan konfigurasi eRapor SMK:${RESET}"
read -p "IP Server (contoh: 192.168.66.99): " SERVER_IP
read -p "APP_NAME (contoh: eRapor SMK): " APP_NAME
read -p "Nama DB PostgreSQL: " DB_NAME
read -p "Username DB PostgreSQL: " DB_USER
read -sp "Password DB PostgreSQL: " DB_PASS
echo -e "\n"

# ---- Update Sistem ----
echo -e "${BLUE}[1/17]  🔄 Update & Upgrade Sistem...${RESET}"
apt update && apt upgrade -y
echo -e "${GREEN}[✓] Sistem updated.${RESET}\n"

# ---- Paket Pendukung ----
echo -e "${BLUE}[2/17]  📦 Install Paket Pendukung...${RESET}"
apt install -y unzip curl cowsay lsb-release
echo -e "${GREEN}[✓] Paket pendukung terpasang.${RESET}\n"

# ---- Install LAMP Stack ----
echo -e "${BLUE}[3/17]  🖥️ Install Apache2 + PHP + PostgreSQL + Redis...${RESET}"
apt install -y apache2 libapache2-mod-fcgid \
php php-cli php-fpm php-pgsql php-xml php-mbstring php-curl php-zip php-bcmath php-gd php-redis \
composer postgresql postgresql-contrib redis-server
echo -e "${GREEN}[✓] LAMP Stack terpasang.${RESET}\n"

# ---- Tuning Apache2 ----
echo -e "${BLUE}[4/17]  ⚡ Tuning Apache2...${RESET}"
a2enmod mpm_prefork >/dev/null 2>&1
MPM_CONF="/etc/apache2/mods-available/mpm_prefork.conf"
APACHE_CONF="/etc/apache2/apache2.conf"
if [ -f "$MPM_CONF" ]; then
    sed -i "s/^StartServers.*/StartServers             4/" $MPM_CONF
    sed -i "s/^MinSpareServers.*/MinSpareServers          2/" $MPM_CONF
    sed -i "s/^MaxSpareServers.*/MaxSpareServers          6/" $MPM_CONF
    sed -i "s/^MaxRequestWorkers.*/MaxRequestWorkers      50/" $MPM_CONF
    sed -i "s/^MaxConnectionsPerChild.*/MaxConnectionsPerChild  1000/" $MPM_CONF
fi
sed -i "s/^KeepAlive.*/KeepAlive On/" $APACHE_CONF
sed -i "s/^#KeepAliveTimeout.*/KeepAliveTimeout 5/" $APACHE_CONF
sed -i "s/^#MaxKeepAliveRequests.*/MaxKeepAliveRequests 100/" $APACHE_CONF
systemctl restart apache2
echo -e "${GREEN}[✓] Apache2 tuning selesai.${RESET}\n"

# ---- Tuning PHP-FPM ----
echo -e "${BLUE}[5/17]  ⚡ Tuning PHP-FPM...${RESET}"
PHP_FPM_POOL="/etc/php/$(php -v | head -n1 | awk '{print $2}' | cut -d. -f1,2)/fpm/pool.d/www.conf"
PHP_INI="/etc/php/$(php -v | head -n1 | awk '{print $2}' | cut -d. -f1,2)/fpm/php.ini"
if [ -f "$PHP_FPM_POOL" ]; then
    sed -i "s/^pm.max_children = .*/pm.max_children = 20/" $PHP_FPM_POOL
    sed -i "s/^pm.start_servers = .*/pm.start_servers = 4/" $PHP_FPM_POOL
    sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = 2/" $PHP_FPM_POOL
    sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = 6/" $PHP_FPM_POOL
fi
if [ -f "$PHP_INI" ]; then
    sed -i "s/^memory_limit = .*/memory_limit = 512M/" $PHP_INI
    sed -i "s/^max_execution_time = .*/max_execution_time = 300/" $PHP_INI
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 100M/" $PHP_INI
    sed -i "s/^post_max_size = .*/post_max_size = 100M/" $PHP_INI
fi
systemctl restart php*-fpm
echo -e "${GREEN}[✓] PHP-FPM tuning selesai.${RESET}\n"

# ---- Setup PostgreSQL ----
echo -e "${BLUE}[6/17]  🗄️ Setup PostgreSQL...${RESET}"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
echo -e "${GREEN}[✓] Database siap digunakan.${RESET}\n"

# ---- Setup Laravel eRapor SMK ----
echo -e "${BLUE}[7/17]  🚀 Setup Laravel eRapor SMK...${RESET}"
cd /var/www
git clone https://github.com/eraporsmk/erapor7.git eraporsmk
cd eraporsmk
cp .env.example .env

# ---- Update .env (APP + DB + Redis) ----
echo -e "${BLUE}[8/17] Konfigurasi .env..."
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
echo -e "${BLUE}[9/17] Install Composer dependencies (vendor)..."
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-interaction --prefer-dist --optimize-autoloader

# ---- Laravel Setup ----
echo -e "${BLUE}[10/17] Setup Laravel..."
php artisan key:generate
php artisan migrate --no-interaction
php artisan db:seed --no-interaction

# ---- Storage link check ----
echo -e "${BLUE}[11/17] Storage link check..."
if [ ! -L public/storage ]; then
    php artisan storage:link
else
    echo -e "${BLUE}[i] Storage link sudah ada, skip."
fi

# ---- Fix Permission & Clear Cache ----
echo -e "${BLUE}[12/17] Fix permission & clear cache..."
chown -R www-data:www-data /var/www/eraporsmk
chmod -R 775 /var/www/eraporsmk/storage /var/www/eraporsmk/bootstrap/cache
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
echo -e "${GREEN}[✓] Laravel setup selesai.${RESET}\n"

# ---- Restart Redis ----
echo -e "${BLUE}[13/17] Restart Redis server..."
systemctl enable redis-server
systemctl restart redis-server


# ---- VirtualHost ----
echo -e "${BLUE}[14/17]  🌐 Setup VirtualHost Apache...${RESET}"
VHOST_CONF="/etc/apache2/sites-available/eraporsmk.conf"
cat <<EOF > $VHOST_CONF
<VirtualHost *:80>
    ServerName $SERVER_IP
    DocumentRoot /var/www/eraporsmk/public
    <Directory /var/www/eraporsmk/public>
        AllowOverride All
    </Directory>
</VirtualHost>
EOF
a2ensite eraporsmk.conf
systemctl reload apache2
a2enmod proxy_fcgi setenvif rewrite
systemctl restart php${PHP_VERSION}-fpm
echo -e "${GREEN}[✓] VirtualHost siap.${RESET}\n"

# ---- Update Versi Aplikasi ----
echo -e "${BLUE}[15/17] Update Versi Aplikasi"
php artisan erapor:update
echo -e "${GREEN}[✓] Update Versi Aplikasip selesai.${RESET}\n"

# ---- Fun cowsay ----
if command -v cowsay >/dev/null 2>&1; then
    cowsay "eRaporSMK"
else
    echo -e "${YELLOW}[i] Install cowsay untuk tampilan lucu: sudo apt install cowsay${RESET}"
fi

# ---- Summary ----
echo -e "${CYAN}[16/17]  📋 Summary Instalasi:${RESET}"
echo -e "${GREEN}✔ APP_NAME  : $APP_NAME${RESET}"
echo -e "${GREEN}✔ APP_URL   : http://$SERVER_IP${RESET}"
echo -e "${GREEN}✔ Folder    : /var/www/eraporsmk${RESET}"
echo -e "${GREEN}✔ Apache2   : Terpasang & Tuning${RESET}"
echo -e "${GREEN}✔ PHP-FPM   : Terpasang & Tuning${RESET}"
echo -e "${GREEN}✔ PostgreSQL: Terpasang & Tuning${RESET}"
echo -e "${GREEN}✔ Redis     : Terpasang${RESET}"
echo -e "${GREEN}✔ Laravel   : eRapor SMK siap digunakan${RESET}"
echo -e "${GREEN}✔ Database  : ${DB_NAME}${RESET}"
echo -e "${GREEN}✔ DB User   : ${DB_USER}${RESET}"
echo -e "${GREEN}✔ DB Pass   : ${DB_PASS}${RESET}"
echo -e "${GREEN}✔ Logging   : $LOG_FILE${RESET}"
echo ""
echo -e "${CYAN}📌 Spesifikasi Server:${RESET}"
echo -e "${GREEN}- OS        : $(lsb_release -ds)${RESET}"
echo -e "${GREEN}- Kernel    : $(uname -r)${RESET}"
echo -e "${GREEN}- Apache    : $(apache2 -v | grep 'Server version' | awk '{print $3}')${RESET}"
echo -e "${GREEN}- PHP       : $(php -v | head -n1 | awk '{print $2}')${RESET}"
echo -e "${GREEN}- PostgreSQL: $(psql --version | awk '{print $3}')${RESET}"
echo -e "${GREEN}- Redis     : $(redis-server --version | awk '{print $3}' | sed 's/=//')${RESET}"
echo -e "${GREEN}- Composer  : $(composer --version | awk '{print $3}')${RESET}"
echo ""
echo -e "${CYAN}[17/17]  🎉 Instalasi selesai! Selamat menggunakan eRapor SMK 🎉${RESET}"
echo ""
echo -e "${CYAN}📌 Credit Author:${RESET}"
echo -e "${YELLOW}Abdur Rozak, SMKS YASMIDA Ambarawa${RESET}"
echo -e "GitHub: https://github.com/abdurrozakskom"
echo -e "Donasi: https://www.youtube.com/@AbdurRozakSKom"
# ---- Donasi ----
echo -e "${CYAN}💖 Jika script ini bermanfaat, silakan donasi untuk mendukung pengembangan:${RESET}"
echo -e "${YELLOW}• Saweria  : https://saweria.co/abdurrozak${RESET}"
echo -e "${YELLOW}• Trakteer : https://trakteer.id/abdurrozak${RESET}"
echo -e "${YELLOW}• Paypal   : https://paypal.me/abdurrozak${RESET}"
# ---- Sosial Media ----
echo -e "${CYAN}🌐 Ikuti sosial media resmi untuk update & info:${RESET}"
echo -e "${YELLOW}• GitHub    : https://github.com/abdurrozakskom${RESET}"
echo -e "${YELLOW}• Instagram : https://instagram.com/abdurrozak${RESET}"
echo -e "${YELLOW}• Facebook  : https://facebook.com/abdurrozak${RESET}"
echo -e "${YELLOW}• Twitter   : https://twitter.com/abdurrozak${RESET}"
echo -e "${YELLOW}• YouTube   : https://youtube.com/@abdurrozak${RESET}"
