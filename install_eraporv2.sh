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
mkdir -p /var/log/erapor
LOG_FILE="/var/log/erapor/erapor_install.log"
touch $LOG_FILE
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${CYAN}=== Mulai instalasi eRapor SMK $(date) ===${RESET}"

# ---- Input User ----
echo -e "${YELLOW}[INPUT] Silakan masukkan konfigurasi eRapor SMK:${RESET}"
read -p "IP Server (contoh: 192.168.66.99): " SERVER_IP
read -p "APP_NAME (contoh: eRapor SMK): " APP_NAME
read -p "Database PostgreSQL: " DB_NAME
read -p "Username DB: " DB_USER
read -sp "Password DB: " DB_PASS
echo -e "\n"

# ---- Update Sistem ----
echo -e "${BLUE}[1/8]  🔄 Update & Upgrade Sistem...${RESET}"
apt update && apt upgrade -y
echo -e "${GREEN}[✓] Sistem updated.${RESET}\n"

# ---- Paket Pendukung ----
echo -e "${BLUE}[2/8]  📦 Install Paket Pendukung...${RESET}"
apt install -y unzip curl cowsay lsb-release
echo -e "${GREEN}[✓] Paket pendukung terpasang.${RESET}\n"

# ---- Install LAMP Stack ----
echo -e "${BLUE}[3/8]  🖥️ Install Apache2 + PHP + PostgreSQL + Redis...${RESET}"
apt install -y apache2 libapache2-mod-fcgid \
php php-cli php-fpm php-pgsql php-xml php-mbstring php-curl php-zip php-bcmath php-gd php-redis \
composer postgresql postgresql-contrib redis-server
echo -e "${GREEN}[✓] LAMP Stack terpasang.${RESET}\n"

# ---- Tuning Apache2 ----
echo -e "${BLUE}[4/8]  ⚡ Tuning Apache2...${RESET}"
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
echo -e "${BLUE}[5/8]  ⚡ Tuning PHP-FPM...${RESET}"
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
echo -e "${BLUE}[6/8]  🗄️ Setup PostgreSQL...${RESET}"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d $DB_NAME -c "ALTER DATABASE $DB_NAME OWNER TO $DB_USER;"
echo -e "${GREEN}[✓] Database siap digunakan.${RESET}\n"

# ---- Setup Laravel eRapor SMK ----
echo -e "${BLUE}[7/8]  🚀 Setup Laravel eRapor SMK...${RESET}"
cd /var/www
git clone https://github.com/abdurrozakskom/eraporsmk.git
cd eraporsmk
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan db:seed
php artisan storage:link
chown -R www-data:www-data /var/www/eraporsmk
chmod -R 775 /var/www/eraporsmk/storage /var/www/eraporsmk/bootstrap/cache
echo -e "${GREEN}[✓] Laravel setup selesai.${RESET}\n"

# ---- VirtualHost ----
echo -e "${BLUE}[8/8]  🌐 Setup VirtualHost Apache...${RESET}"
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
echo -e "${GREEN}[✓] VirtualHost siap.${RESET}\n"

# ---- Fun cowsay ----
if command -v cowsay >/dev/null 2>&1; then
    cowsay "eRaporSMK"
else
    echo -e "${YELLOW}[i] Install cowsay untuk tampilan lucu: sudo apt install cowsay${RESET}"
fi

# ---- Summary ----
echo -e "${CYAN}[9/8]  📋 Summary Instalasi:${RESET}"
echo -e "${GREEN}✔ APP_NAME  : $APP_NAME${RESET}"
echo -e "${GREEN}✔ APP_URL   : http://$SERVER_IP${RESET}"
echo -e "${GREEN}✔ Folder    : /var/www/erapor${RESET}"
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
echo -e "${CYAN}📌 Credit Author:${RESET}"
echo -e "${YELLOW}Abdur Rozak, SMKS YASMIDA Ambarawa${RESET}"
echo -e "GitHub: https://github.com/abdurrozakskom"

echo -e "${CYAN}📌 Spesifikasi Server:${RESET}"
echo -e "${GREEN}- OS        : $(lsb_release -ds)${RESET}"
echo -e "${GREEN}- Kernel    : $(uname -r)${RESET}"
echo -e "${GREEN}- Apache    : $(apache2 -v | grep 'Server version' | awk '{print $3}')${RESET}"
echo -e "${GREEN}- PHP       : $(php -v | head -n1 | awk '{print $2}')${RESET}"
echo -e "${GREEN}- PostgreSQL: $(psql --version | awk '{print $3}')${RESET}"
echo -e "${GREEN}- Redis     : $(redis-server --version | awk '{print $3}' | sed 's/=//')${RESET}"
echo -e "${GREEN}- Composer  : $(composer --version | awk '{print $3}')${RESET}"

echo -e "${CYAN}[10/8]  🎉 Instalasi selesai! Selamat menggunakan eRapor SMK 🎉${RESET}"
