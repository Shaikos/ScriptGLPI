# ScriptGLPI

<p align="center">
  <img src="https://img.shields.io/badge/Built%20with-Bash-1f425f?style=for-the-badge">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge">
  <img src="https://img.shields.io/badge/GLPI-10.0.18-blue?style=for-the-badge">
  <img src="https://img.shields.io/badge/OS-Debian%2FUbuntu-yellow?style=for-the-badge">
  <img alt="GLPI IMG" src="https://glpi-project.org/wp-content/uploads/2022/01/assets-2.png">
</p>

---
## About this script
This script automates the full installation of **GLPI** (currently 10.0.18) on a Debian/Ubuntu server.  
It installs and configures **Apache**, **MariaDB**, **PHP**, and sets up GLPI ready to use.

Please note: GLPI is installed without SSL by default. If you plan to make it accessible externally or require SSL encryption, it is recommended to set up a reverse proxy.

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

2. **Run the script as root:**

```bash
sudo ./install_glpi_en.sh
```
*(or `install_glpi_fr.sh` if you want the French version)*

3. **Follow the prompts:**
   - Enter the name for your **GLPI database**.
   - Enter the **MariaDB user** and **password** that will have access to the GLPI database.

4. **Access GLPI:**
   - After installation, the script will display your server's IP address.
   - Visit `http://your-server-ip/` or `http://my.glpi.local/` if you configure your `/etc/hosts` file.


5. **Secure your installation:**
   - After completing the GLPI web installation wizard, **run the script** to rename the `install.php` file:

```bash
sudo ./auto_remove_install_php_en.sh
```

*(or `install_glpi_fr.sh` if you want the French version)*

---

## 📋 Operating System Compatibility

| **OS**      | **Version** | **Compatibility**   |
|-------------|-------------|---------------------|
| **Debian**  | 10          | ⚠️ Not tested       |
| **Debian**  | 11          | ✅ Compatible       |
| **Debian**  | 12          | ✅ Compatible       |
| **Ubuntu**  | 22.04       | ⚠️ Not tested       |
| **Ubuntu**  | 24.04       | ✅ Compatible       |
| **Ubuntu**  | 25.04       | ✅ Compatible       |

---

## ❗ Important Notes

- This script **does not** install SSL certificates. You should manually set up HTTPS if needed.
- Ensure your server's firewall allows HTTP/HTTPS traffic (ports 80/443).

---

## 📜 License

This project is open-source under the **MIT license**.  
Feel free to modify, improve, and share it!

---
