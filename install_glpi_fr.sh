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

# === Ajout du dépôt PHP 8.3 ===
echo "[0/8] Ajout du dépôt PHP 8.3..."
apt install -y lsb-release ca-certificates apt-transport-https software-properties-common gnupg2

if ! command -v add-apt-repository &> /dev/null; then
    apt install -y software-properties-common
fi

add-apt-repository ppa:ondrej/php -y
apt update

# === Demande d'infos utilisateur ===
read -p "Nom de la base de données GLPI : " DB_NAME
read -p "Nom de l'utilisateur MariaDB pour GLPI : " DB_USER
read -s -p "Mot de passe de l'utilisateur MariaDB : " DB_PASS
echo

# === Mise à jour du système ===
echo "[1/8] Mise à jour du système..."
apt update && apt upgrade -y

# === Installation des paquets nécessaires ===
echo "[2/8] Installation des paquets Apache, MariaDB, PHP et extensions..."
apt install -y apache2 mariadb-server php8.3 php8.3-common php8.3-cli php8.3-gd php8.3-intl php8.3-mbstring php8.3-mysql php8.3-xml php8.3-xmlrpc php8.3-zip php8.3-curl php8.3-bz2 php8.3-exif php8.3-ldap php8.3-opcache libapache2-mod-php8.3 unzip wget apache2-utils

# === Vérification de l'installation de MariaDB ===
echo "[3/8] Vérification et configuration de MariaDB..."
if ! command -v mysql &> /dev/null
then
    echo "❌ MariaDB n'est pas installé ou accessible, l'installation a échoué."
    exit 1
fi

mysql -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# === Téléchargement et installation de GLPI ===
echo "[4/8] Téléchargement de GLPI..."
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
echo "[5/8] Création des dossiers nécessaires dans /var/lib/glpi..."
mkdir -p /var/lib/glpi/_cron /var/lib/glpi/_dumps /var/lib/glpi/_graphs /var/lib/glpi/_lock /var/lib/glpi/_pictures /var/lib/glpi/_plugins /var/lib/glpi/_rss /var/lib/glpi/_sessions /var/lib/glpi/_tmp /var/lib/glpi/_uploads

# === Sécurisation des répertoires ===
echo "[6/8] Sécurisation des dossiers de configuration..."
mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi
mv /var/www/glpi/config /etc/glpi
mv /var/www/glpi/files /var/lib/glpi
chown -R www-data:www-data /etc/glpi /var/lib/glpi /var/log/glpi

# === Fichier downstream.php ===
echo "[7/8] Création de downstream.php..."
cat <<EOF > /var/www/glpi/inc/downstream.php
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
define('GLPI_VAR_DIR', '/var/lib/glpi/');
define('GLPI_LOG_DIR', '/var/log/glpi/');
EOF

# === Configuration Apache ===
echo "[8/8] Configuration d'Apache..."
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

# Vérification de la disponibilité des commandes Apache
if ! command -v a2enmod &> /dev/null
then
    echo "❌ Les commandes Apache pour activer les modules ne sont pas disponibles."
    exit 1
fi

# Sécuriser les cookies PHP en modifiant session.cookie_httponly dans php.ini
echo "Sécurisation des cookies PHP..."
PHP_VERSION="8.3"
PHP_INI_FILE="/etc/php/$PHP_VERSION/apache2/php.ini"

# Vérifie si le fichier php.ini est bien présent
if [ -f "$PHP_INI_FILE" ]; then
    echo "✅ Le fichier php.ini est trouvé à : $PHP_INI_FILE"
    
    # Affiche la ligne avant modification
    echo "Avant modification :"
    grep "session.cookie_httponly" "$PHP_INI_FILE"

    # Vérifie si la ligne existe et est vide, ou n'existe pas, puis la modifie
    if grep -q "session.cookie_httponly" "$PHP_INI_FILE"; then
        sudo sed -i "s/^session.cookie_httponly\s*=.*/session.cookie_httponly = On/" "$PHP_INI_FILE"
    else
        echo "session.cookie_httponly = On" | sudo tee -a "$PHP_INI_FILE"
    fi

    # Affiche la ligne après modification
    echo "Après modification :"
    grep "session.cookie_httponly" "$PHP_INI_FILE"
else
    echo "❌ Le fichier php.ini d'Apache n'a pas été trouvé à l'emplacement attendu ($PHP_INI_FILE)."
    exit 1
fi

# Activer PHP 8.3 sur Apache
a2dismod php*
a2enmod php8.3
systemctl restart apache2

# Activer les modules Apache
a2enmod rewrite
a2ensite glpi
a2dissite 000-default
systemctl reload apache2

# === IP locale ===
IP=$(hostname -I | awk '{print $1}')
echo
echo "✅ Installation terminée avec succès !"
echo "➡️  Accède à GLPI via : http://$IP/"
echo "ℹ️  Utilise 'my.glpi.local' si tu modifies ton fichier /etc/hosts."
