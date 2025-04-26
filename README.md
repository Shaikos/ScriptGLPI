# ScriptGLPI

<p align="center">
  <img src="https://img.shields.io/badge/Built%20with-Bash-1f425f?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/GLPI-10.0.18-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/OS-Debian%2FUbuntu-yellow?style=for-the-badge">
</p>

---

# GLPI Auto-Installation Script

This script automates the full installation of **GLPI** (IT asset management and helpdesk software) on a Debian/Ubuntu server.  
It installs and configures **Apache**, **MariaDB**, **PHP**, and sets up GLPI ready to use.

## 🧩 Default Accounts

More info in the 📄 [Docs](https://glpi-install.readthedocs.io/en/latest/install/wizard.html#end-of-installation)

| Login / Password     | Role               |
|----------------------|--------------------|
| glpi / glpi           | Admin account      |
| tech / tech           | Technical account  |
| normal / normal       | Normal account     |
| post-only / postonly  | Post-only account  |

---

## 📋 Requirements

- A fresh **Debian/Ubuntu** server
- Root privileges (`sudo`)
- Internet access

---

## 🚀 How to Use

1. **Clone the repository:**

```bash
git clone https://github.com/Shaikos/ScriptGLPI.git
cd ScriptGLPI
```

2. **Make the script executable:**

- **English version:**

```bash
chmod +x install_glpi_en.sh
```

- **French version:**

```bash
chmod +x install_glpi_fr.sh
```

3. **Run the script as root:**

```bash
sudo ./install_glpi_en.sh
```
*(or `install_glpi_fr.sh` if you want the French version)*

4. **Follow the prompts:**
   - Enter the name for your **GLPI database**.
   - Enter the **MariaDB user** and **password** that will have access to the GLPI database.

5. **Access GLPI:**
   - After installation, the script will display your server's IP address.
   - Visit `http://your-server-ip/` or `http://my.glpi.local/` if you configure your `/etc/hosts` file.


6. **Secure your installation:**
   - After completing the GLPI web installation wizard, **run the script** to rename the `install.php` file:

- **English version:**

```bash
sudo ./auto_remove_install_php_en.sh
```

- **French version:**

```bash
sudo ./auto_remove_install_php_fr.sh
```

---
## ⚙️ What the Script Does

- Updates the system packages.
- Installs Apache, MariaDB, PHP, and all required PHP extensions.
- Configures MariaDB (creates a database and user for GLPI).
- Downloads and installs **GLPI 10.0.18**.
- Configures Apache virtual host for GLPI.
- Secures PHP sessions (`session.cookie_httponly = On`).
- Creates necessary folders and sets permissions.
- Restarts Apache with proper modules enabled.

---

## 🔧 Customization

You can **edit the script** depending on your needs:

| Section               | What to Modify                                                        | Where                                                  |
|------------------------|------------------------------------------------------------------------|--------------------------------------------------------|
| **GLPI Version**       | Change the version of GLPI to download                                | Look for `wget https://github.com/glpi-project/glpi/releases/...` |
| **Apache Config**      | Change the domain (currently `my.glpi.local`)                             | Edit `ServerName` inside `/etc/apache2/sites-available/glpi.conf` |
| **PHP Version**        | Ensure the correct PHP version (currently `8.2`)                      | Update the `$PHP_INI_FILE` path in the script          |
| **MariaDB Root Password** | Add `-p` options if your MariaDB root account requires a password | Add `-p` to `mysql -e` commands                       |

---

## ❗ Important Notes

- This script **does not** install SSL certificates. You should manually set up HTTPS if needed.
- Ensure your server's firewall allows HTTP/HTTPS traffic (ports 80/443).
- It is highly recommended to configure a proper domain name and SSL certificate for production environments.
- Remember to secure your MariaDB installation using `mysql_secure_installation`.

---

## 📜 License

This project is open-source under the **MIT license**.  
Feel free to modify, improve, and share it!

---
