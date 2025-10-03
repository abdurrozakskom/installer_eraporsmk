#!/bin/bash
# Auto Installer eRapor SMK 7
# by Abdur Rozak (SMKS Yasmida)

# ---- Input User ----
read -p "Masukkan nama domain (contoh: erapor.local): " DOMAIN
read -p "Masukkan nama database: " DB_NAME
read -p "Masukkan user database: " DB_USER
read -sp "Masukkan password database: " DB_PASS
echo ""

# ---- Update & Install Paket ----
echo "[1/6] Update sistem & install paket dasar..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y apache2 libapache2-mod-fcgid unzip curl git \
    php php-cli php-fpm php-pgsql php-xml php-mbstring php-curl php-zip php-bcmath \
    composer postgresql postgresql-contrib

# ---- Setup PostgreSQL ----
echo "[2/6] Membuat database PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# ---- Clone eRapor ----
echo "[3/6] Clone repo eRapor SMK..."
cd /var/www/
sudo git clone https://github.com/eraporsmk/erapor7.git $DOMAIN
cd $DOMAIN
sudo cp .env.example .env

# ---- Update .env ----
echo "[4/6] Konfigurasi .env..."
sudo sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=pgsql/" .env
sudo sed -i "s/DB_HOST=.*/DB_HOST=127.0.0.1/" .env
sudo sed -i "s/DB_PORT=.*/DB_PORT=5432/" .env
sudo sed -i "s/DB_DATABASE=.*/DB_DATABASE=$DB_NAME/" .env
sudo sed -i "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/" .env
sudo sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env

# ---- Install Laravel Dependencies ----
echo "[5/6] Install dependency Laravel..."
sudo composer install --no-interaction --prefer-dist --optimize-autoloader
sudo php artisan key:generate
sudo php artisan migrate --seed --no-interaction
sudo php artisan storage:link

# ---- Apache VirtualHost ----
echo "[6/6] Setup VirtualHost Apache..."
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
VHOST_FILE="/etc/apache2/sites-available/$DOMAIN.conf"

sudo bash -c "cat > $VHOST_FILE" <<EOL
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/$DOMAIN/public

    <Directory /var/www/$DOMAIN/public>
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \".+\.php$\">
        SetHandler \"proxy:unix:/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost/\"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOL

sudo a2ensite $DOMAIN.conf
sudo a2enmod proxy_fcgi setenvif rewrite
sudo systemctl restart apache2

echo "✅ Instalasi eRapor SMK selesai!"
echo "Buka di browser: http://$DOMAIN"
