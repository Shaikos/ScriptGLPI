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

# === Sécurisation finale : renommage du fichier install.php ===
if [ -f /var/www/glpi/install/install.php ]; then
    mv /var/www/glpi/install/install.php /var/www/glpi/install/install.php.bak
    echo "✅ Fichier install.php renommé en install.php.bak pour plus de sécurité."
fi
