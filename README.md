# ScriptGLPI

# GLPI Auto-Installation Script

<p align="center">
  <img src="https://img.shields.io/badge/Built%20with-Bash-1f425f?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/GLPI-10.0.18-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/OS-Debian%2FUbuntu-yellow?style=for-the-badge">
</p>

---

This script automates the full installation of **GLPI** (IT asset management and helpdesk software) on a Debian/Ubuntu server.  
It installs and configures **Apache**, **MariaDB**, **PHP**, and sets up GLPI ready to use.

## Default accounts

More info in the 📄[Docs](https://glpi-install.readthedocs.io/en/latest/install/wizard.html#end-of-installation)

| Login/Password     	| Role              	|
|--------------------	|-------------------	|
| glpi/glpi          	| admin account     	|
| tech/tech          	| technical account 	|
| normal/normal      	| "normal" account  	|
| post-only/postonly 	| post-only account 	|

## 📋 Requirements

- A fresh **Debian/Ubuntu** server
- Root privileges (`sudo`)
- Internet access

## 🚀 How to Use

1. **Clone the repository or download the script:**

```bash
git clone https://github.com/Shaikos/ScriptGLPI.git
cd /tmp
```

2. **Make the script executable:**
  **english version**
```bash
chmod +x install_glpi_en.sh
```
**french version**
```bash
chmod +x install_glpi_fr.sh
```

3. **Run the script as root:**

```bash
sudo ./install_glpi_vfinal.sh
```

4. **Follow the prompts:**
   - Enter the name for your **GLPI database**.
   - Enter the **MariaDB user** and **password** that will have access to the GLPI database.

5. **Access GLPI:**
   - After installation, the script will display your server's IP address.
   - Visit `http://your-server-ip/` or `http://glpi.local/` if you configure your `/etc/hosts`.

---

## ⚙️ What the Script Does

- Updates the system packages.
- Installs Apache, MariaDB, PHP, and all required PHP extensions.
- Configures MariaDB (creates database and user for GLPI).
- Downloads and installs **GLPI 10.0.18**.
- Configures Apache virtual host for GLPI.
- Secures PHP sessions (`session.cookie_httponly = On`).
- Creates necessary folders and sets permissions.
- Restarts Apache with proper modules.

---

## 🔧 Customization

You can **edit the script** depending on your needs:

| Section | What to Modify | Where |
|:---|:---|:---|
| **GLPI Version** | Change the version of GLPI to download | Search for `wget https://github.com/glpi-project/glpi/releases/...` |
| **Apache Config** | Change the domain (currently `glpi.local`) | In the `ServerName` inside `/etc/apache2/sites-available/glpi.conf` |
| **PHP Version** | Ensure correct PHP version (`8.2`) paths if you use another PHP version | Check and update the `$PHP_INI_FILE` path |
| **MariaDB root password** | If you have a root password, add `-p` options in the `mysql` commands | Add `-p` after `mysql -e ...` commands |

---

## ❗ Important Notes

- This script **does not** install SSL certificates. You should manually set up HTTPS if needed.
- Make sure the server’s firewall allows HTTP/HTTPS traffic (port 80/443).
- You should set up a proper domain name and SSL for production use.
- Remember to secure your MariaDB installation using `mysql_secure_installation`.

---

## 📜 License

This project is open-source under the MIT license.  
Feel free to modify, improve, and share it!
