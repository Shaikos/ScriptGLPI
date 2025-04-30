#!/bin/bash

# Check if the script is executed with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ You must run this script with sudo."
    exit 1
fi

# Check if the script is executed with bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ This script must be run with bash, not with sh."
    exit 1
fi

# === Detect Distribution and Version ===
echo "[0/9] Detecting Linux distribution..."
if [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
    echo "✅ Distribution detected: $DISTRO $VERSION"
else
    echo "❌ Unable to detect the distribution (file /etc/os-release not found)."
    exit 1
fi

# Choose PHP version based on distribution
if [[ "$DISTRO" == "ubuntu" ]]; then
    PHP_VERSION="8.3"
    echo "➡️ Ubuntu detected: installing PHP $PHP_VERSION"
elif [[ "$DISTRO" == "debian" ]]; then
    PHP_VERSION="8.2"
    echo "➡️ Debian detected: installing PHP $PHP_VERSION"
else
    echo "❌ Distribution $DISTRO not supported by this script."
    exit 1
fi

# Choice of GLPI version
version=10.0.18
echo "This script install by default the version 10.0.18 of GLPI"
read -p "Would you like to install another version of GLPI? (y/N): " reponse
if [ "$reponse" = "y" ]; then
    read -p "Please enter the desired GLPI version number in the following format X.X.X : " version
    echo "Installation of GLPI version ${version}..."
fi

# Choix de la version php
echo "This script install by default the version $PHP_VERSION of PHP"
read -p "Would you like to install another version of PHP? (y/N): " reponse2
if [ "$reponse2" = "y" ]; then
    read -p "Please enter the desired PHP version number in the following format X.X : " PHP_VERSION
    echo "Installation of PHP version $PHP_VERSION..."
fi

# === Add PHP repository ===
echo "[1/9] Adding PHP repository..."
apt install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2

if [[ "$DISTRO" == "ubuntu" ]]; then
    if ! command -v add-apt-repository &> /dev/null; then
        apt install -y software-properties-common
    fi
    add-apt-repository ppa:ondrej/php -y
elif [[ "$DISTRO" == "debian" ]]; then
    wget -qO- https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/php.gpg
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
fi

apt update

# === Request user information ===
read -p "GLPI database name: " DB_NAME
read -p "MariaDB user for GLPI: " DB_USER
read -s -p "MariaDB user password: " DB_PASS
echo

# === System update ===
echo "[2/9] Updating system..."
apt update && apt upgrade -y

# === Install necessary packages ===
echo "[3/9] Installing Apache, MariaDB, PHP and extensions..."
apt install -y apache2 mariadb-server php$PHP_VERSION php$PHP_VERSION-common php$PHP_VERSION-cli php$PHP_VERSION-gd php$PHP_VERSION-intl php$PHP_VERSION-mbstring php$PHP_VERSION-bcmath php$PHP_VERSION-mysql php$PHP_VERSION-xml php$PHP_VERSION-xmlrpc php$PHP_VERSION-zip php$PHP_VERSION-curl php$PHP_VERSION-bz2 php$PHP_VERSION-exif php$PHP_VERSION-ldap php$PHP_VERSION-opcache libapache2-mod-php$PHP_VERSION unzip wget apache2-utils

# === Check MariaDB installation ===
echo "[4/9] Checking and configuring MariaDB..."
if ! command -v mysql &> /dev/null; then
    echo "❌ MariaDB is not installed or accessible, installation failed."
    exit 1
fi

mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# === Download and install GLPI ===
echo "[5/9] Downloading GLPI..."
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/${version}/glpi-${version}.tgz -O /tmp/glpi.tgz

if [[ ! -f /tmp/glpi.tgz ]]; then
  echo "❌ Error: the glpi.tgz file was not downloaded."
  exit 1
fi

echo "✅ File downloaded successfully."

mkdir -p /var/www/glpi
tar -xzf /tmp/glpi.tgz -C /var/www/glpi --strip-components=1

# === Create necessary folders in /var/lib/glpi ===
echo "[6/9] Creating necessary folders in /var/lib/glpi..."
mkdir -p /var/lib/glpi/_cron /var/lib/glpi/_dumps /var/lib/glpi/_graphs /var/lib/glpi/_lock /var/lib/glpi/_pictures /var/lib/glpi/_plugins /var/lib/glpi/_rss /var/lib/glpi/_sessions /var/lib/glpi/_tmp /var/lib/glpi/_uploads

# === Secure configuration directories ===
echo "[7/9] Securing configuration directories..."
mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi
mv /var/www/glpi/config /etc/glpi
mv /var/www/glpi/files /var/lib/glpi
chown -R www-data:www-data /etc/glpi /var/lib/glpi /var/log/glpi

# === Create downstream.php file ===
echo "[8/9] Creating downstream.php..."
cat <<EOF > /var/www/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
define('GLPI_VAR_DIR', '/var/lib/glpi/');
define('GLPI_LOG_DIR', '/var/log/glpi/');
EOF

# === Apache Configuration ===
echo "[9/9] Configuring Apache..."
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

# Secure PHP cookies
echo "Securing PHP cookies..."
PHP_INI_FILE="/etc/php/$PHP_VERSION/apache2/php.ini"

if [ -f "$PHP_INI_FILE" ]; then
    echo "✅ The php.ini file is found at: $PHP_INI_FILE"

    if grep -q "session.cookie_httponly" "$PHP_INI_FILE"; then
        sudo sed -i "s/^session.cookie_httponly\s*=.*/session.cookie_httponly = On/" "$PHP_INI_FILE"
    else
        echo "session.cookie_httponly = On" | sudo tee -a "$PHP_INI_FILE"
    fi

    grep "session.cookie_httponly" "$PHP_INI_FILE"
else
    echo "❌ The Apache php.ini file was not found."
    exit 1
fi

# Enable PHP on Apache
a2dismod php$PHP_VERSION
a2enmod php$PHP_VERSION
systemctl restart apache2

# Enable Apache modules
a2enmod rewrite
a2ensite glpi
a2dissite 000-default
systemctl reload apache2

# === Installation complete ===
IP=$(hostname -I | awk '{print $1}')
echo
echo "✅ Installation completed successfully!"
echo "➡️ Access GLPI at: http://$IP/"
echo "ℹ️ Use 'my.glpi.local' if you modify your /etc/hosts file."
