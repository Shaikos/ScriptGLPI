#!/bin/bash

# Vérifier si le script est exécuté avec des privilèges root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Vous devez exécuter ce script avec sudo."
    exit 1
fi

# Vérifier si le script est exécuté avec bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Ce script doit être exécuté avec bash, pas avec sh."
    exit 1
fi

# === Détection de la distribution et version ===
echo "[0/9] Détection de la distribution Linux..."
if [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
    echo "✅ Distribution détectée : $DISTRO $VERSION"
else
    echo "❌ Impossible de détecter la distribution (fichier /etc/os-release introuvable)."
    exit 1
fi

# Choisir la version PHP en fonction de la distribution
if [[ "$DISTRO" == "ubuntu" ]]; then
    PHP_VERSION="8.4"
    echo "➡️ Ubuntu détecté : installation de PHP $PHP_VERSION"
elif [[ "$DISTRO" == "debian" ]]; then
    PHP_VERSION="8.2"
    echo "➡️ Debian détecté : installation de PHP $PHP_VERSION"
else
    echo "❌ Distribution $DISTRO non supportée par ce script."
    exit 1
fi

# === Ajout du dépôt PHP ===
echo "[1/9] Ajout du dépôt PHP..."
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

# === Demande d'infos utilisateur ===
read -p "Nom de la base de données GLPI : " DB_NAME
read -p "Nom de l'utilisateur MariaDB pour GLPI : " DB_USER
read -s -p "Mot de passe de l'utilisateur MariaDB : " DB_PASS
echo

# === Mise à jour du système ===
echo "[2/9] Mise à jour du système..."
apt update && apt upgrade -y

# === Installation des paquets nécessaires ===
echo "[3/9] Installation des paquets Apache, MariaDB, PHP et extensions..."
apt install -y apache2 mariadb-server php$PHP_VERSION php$PHP_VERSION-common php$PHP_VERSION-cli php$PHP_VERSION-gd php$PHP_VERSION-intl php$PHP_VERSION-mbstring php$PHP_VERSION-mysql php$PHP_VERSION-xml php$PHP_VERSION-xmlrpc php$PHP_VERSION-zip php$PHP_VERSION-curl php$PHP_VERSION-bz2 php$PHP_VERSION-exif php$PHP_VERSION-ldap php$PHP_VERSION-opcache libapache2-mod-php$PHP_VERSION unzip wget apache2-utils

# === Vérification de l'installation de MariaDB ===
echo "[4/9] Vérification et configuration de MariaDB..."
if ! command -v mysql &> /dev/null; then
    echo "❌ MariaDB n'est pas installé ou accessible, l'installation a échoué."
    exit 1
fi

mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# === Téléchargement et installation de GLPI ===
echo "[5/9] Téléchargement de GLPI..."
cd /tmp
wget https://github.com/glpi-project/glpi/releases/download/10.0.18/glpi-10.0.18.tgz -O /tmp/glpi.tgz

if [[ ! -f /tmp/glpi.tgz ]]; then
  echo "❌ Erreur : le fichier glpi.tgz n'a pas été téléchargé."
  exit 1
fi

echo "✅ Fichier téléchargé avec succès."

mkdir -p /var/www/glpi
tar -xzf /tmp/glpi.tgz -C /var/www/glpi --strip-components=1

# === Création des dossiers nécessaires dans /var/lib/glpi ===
echo "[6/9] Création des dossiers nécessaires dans /var/lib/glpi..."
mkdir -p /var/lib/glpi/_cron /var/lib/glpi/_dumps /var/lib/glpi/_graphs /var/lib/glpi/_lock /var/lib/glpi/_pictures /var/lib/glpi/_plugins /var/lib/glpi/_rss /var/lib/glpi/_sessions /var/lib/glpi/_tmp /var/lib/glpi/_uploads

# === Sécurisation des répertoires ===
echo "[7/9] Sécurisation des dossiers de configuration..."
mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi
mv /var/www/glpi/config /etc/glpi
mv /var/www/glpi/files /var/lib/glpi
chown -R www-data:www-data /etc/glpi /var/lib/glpi /var/log/glpi

# === Fichier downstream.php ===
echo "[8/9] Création de downstream.php..."
cat <<EOF > /var/www/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
define('GLPI_VAR_DIR', '/var/lib/glpi/');
define('GLPI_LOG_DIR', '/var/log/glpi/');
EOF

# === Configuration Apache ===
echo "[9/9] Configuration d'Apache..."
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

# Activer PHP sur Apache
a2dismod php*
a2enmod php$PHP_VERSION
systemctl restart apache2

# Activer les modules Apache
a2enmod rewrite
a2ensite glpi
a2dissite 000-default
systemctl reload apache2

# Sécuriser les cookies PHP
echo "Sécurisation des cookies PHP..."
PHP_INI_FILE="/etc/php/$PHP_VERSION/apache2/php.ini"

if [ -f "$PHP_INI_FILE" ]; then
    echo "✅ Le fichier php.ini est trouvé à : $PHP_INI_FILE"

    if grep -q "session.cookie_httponly" "$PHP_INI_FILE"; then
        sudo sed -i "s/^session.cookie_httponly\s*=.*/session.cookie_httponly = On/" "$PHP_INI_FILE"
    else
        echo "session.cookie_httponly = On" | sudo tee -a "$PHP_INI_FILE"
    fi

    grep "session.cookie_httponly" "$PHP_INI_FILE"
else
    echo "❌ Le fichier php.ini d'Apache n'a pas été trouvé."
    exit 1
fi

# === Fin de l'installation ===
IP=$(hostname -I | awk '{print $1}')
echo
echo "✅ Installation terminée avec succès !"
echo "➡️  Accède à GLPI via : http://$IP/"
echo "ℹ️  Utilise 'my.glpi.local' si tu modifies ton fichier /etc/hosts."
