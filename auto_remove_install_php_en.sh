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

# === Final security step: renaming the install.php file ===
if [ -f /var/www/glpi/install/install.php ]; then
    mv /var/www/glpi/install/install.php /var/www/glpi/install/install.php.bak
    echo "✅ install.php has been renamed to install.php.bak for security purposes."
fi