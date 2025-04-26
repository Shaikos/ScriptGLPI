#!/bin/bash

# Check if the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ You must run this script with sudo."
    exit 1
fi

# Check if the script is run with bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ This script must be run with bash, not sh."
    exit 1
fi

# === Request user information ===
read -p "GLPI database name: " DB_NAME
read -p "MariaDB user name for GLPI: " DB_USER
read -s -p "Password for the MariaDB user: " DB_PASS
echo

# === System update ===
echo "[1/8] Updating the system..."
apt update && apt upgrade -y

# === Installing required packages ===
echo "[2/8] Installing Apache, MariaDB, PHP, and required extensions..."
apt install -y apache2 mariadb-server php php-common php-cli php-gd php-intl php-mbstring php-mysql php-xml php-xmlrpc php-zip php-curl php-bz2 php-exif php-ldap php-opcache unzip wget apache2-utils

# === Checking MariaDB installation ===
echo "[3/8] Checking and configuring MariaDB..."
if ! command -v mysql &> /dev/null
then
    echo "❌ MariaDB is not installed or accessible, installation failed."
    exit 1
fi

mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# === Downloading and installing GLPI ===
echo "[4/8] Downloading GLPI..."
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.18/glpi-10.0.18.tgz -O /tmp/glpi.tgz

if [[ ! -f /tmp/glpi.tgz ]]; then
  echo "❌ Error: glpi.tgz file was not downloaded."
  exit 1
fi

echo "✅ File downloaded successfully."

mkdir -p /var/www/glpi
tar -xzf /tmp/glpi.tgz -C /var/www/glpi --strip-components=1

# === Creating necessary directories in /var/lib/glpi ===
echo "[5/8] Creating necessary folders in /var/lib/glpi..."
mkdir -p /var/lib/glpi/_cron /var/lib/glpi/_dumps /var/lib/glpi/_graphs /var/lib/glpi/_lock /var/lib/glpi/_pictures /var/lib/glpi/_plugins /var/lib/glpi/_rss /var/lib/glpi/_sessions /var/lib/glpi/_tmp /var/lib/glpi/_uploads

# === Securing directories ===
echo "[6/8] Securing configuration folders..."
mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi
mv /var/www/glpi/config /etc/glpi
mv /var/www/glpi/files /var/lib/glpi
chown -R www-data:www-data /etc/glpi /var/lib/glpi /var/log/glpi

# === Creating downstream.php file ===
echo "[7/8] Creating downstream.php..."
cat <<EOF > /var/www/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
define('GLPI_VAR_DIR', '/var/lib/glpi/');
define('GLPI_LOG_DIR', '/var/log/glpi/');
EOF

# === Apache configuration ===
echo "[8/8] Configuring Apache..."
cat <<EOF > /etc/apache2/sites-available/glpi.conf
<VirtualHost *:80>
    ServerName my.glpi.local
    DocumentRoot /var/www/glpi/public

    <Directory /var/www/glpi/public>
        Require all granted
        AllowOverride All

        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.+)\$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)\$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOF

# Check if Apache commands are available
if ! command -v a2enmod &> /dev/null
then
    echo "❌ Apache commands to enable modules are not available."
    exit 1
fi

# Secure PHP cookies by modifying session.cookie_httponly in php.ini
echo "Securing PHP cookies..."
PHP_INI_FILE="/etc/php/8.2/apache2/php.ini"

# Check if php.ini file exists
if [ -f "$PHP_INI_FILE" ]; then
    echo "php.ini file found at: $PHP_INI_FILE"
    
    # Show line before modification
    echo "Before modification:"
    grep "session.cookie_httponly" "$PHP_INI_FILE"

    # Check if the line exists, and modify or add it
    if grep -q "session.cookie_httponly" "$PHP_INI_FILE"; then
        if grep -q "^session.cookie_httponly\s*=" "$PHP_INI_FILE" && ! grep -q "session.cookie_httponly\s*=" "$PHP_INI_FILE" | grep -q "="; then
            sudo sed -i "s/^session.cookie_httponly\s*=.*$/session.cookie_httponly = On/" "$PHP_INI_FILE"
        fi
    else
        echo "session.cookie_httponly = On" | sudo tee -a "$PHP_INI_FILE"
    fi

    # Show line after modification
    echo "After modification:"
    grep "session.cookie_httponly" "$PHP_INI_FILE"
else
    echo "❌ Apache php.ini file not found at the expected location ($PHP_INI_FILE)."
    exit 1
fi

# Restart Apache to apply changes
sudo systemctl restart apache2

# Enable Apache modules
a2enmod rewrite
a2ensite glpi
a2dissite 000-default
systemctl reload apache2

# === Local IP ===
IP=$(hostname -I | awk '{print $1}')
echo
echo "✅ Installation completed successfully!"
echo "➡️  Access GLPI at: http://$IP/"
echo "ℹ️  Use 'my.glpi.local' if you edit your /etc/hosts file."
