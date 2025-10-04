# 🚀 eRapor SMK Auto Installer
<p align="center"><img src="https://tjkt.smkyasmida.sch.id/wp-content/uploads/2025/02/Logo-TJKT-2022-Sampul-Youtube-1.png" width="600"></p>

---

Script Bash untuk otomatisasi instalasi **eRaporSMK Latest Releases** dengan stack:

- Apache2 + PHP-FPM
- PHP 8.1/8.2/8.3 (otomatis menyesuaikan versi di server)
- PostgreSQL (DBMS utama eRapor SMK)
- Composer + Laravel setup
- Konfigurasi VirtualHost Apache

---

## 📌 Fitur
- Install paket server (Apache, PHP-FPM, PostgreSQL, Composer, Git).
- Membuat database & user PostgreSQL otomatis.
- Clone repo [eRapor SMK 7](https://github.com/eraporsmk/erapor7).
- Generate file `.env` sesuai input user.
- Menjalankan perintah Laravel:
  - `composer install`
  - `php artisan migrate --seed`
  - `php artisan key:generate`
  - `php artisan storage:link`
- Setup VirtualHost Apache dengan PHP-FPM.
- Domain lokal bisa langsung digunakan (contoh: `http://erapor.local`).

---
## 💖 Donasi

Jika script ini bermanfaat untuk instalasi eRapor SMK, Anda dapat mendukung pengembang melalui:

- **Saweria** : [https://saweria.co/abdurrozak](https://saweria.co/abdurrozak)  
- **Trakteer** : [https://trakteer.id/abdurrozak](https://trakteer.id/abdurrozak)  
- **Paypal**  : [https://paypal.me/abdurrozak](https://paypal.me/abdurrozak)  

Setiap donasi sangat membantu untuk pengembangan fitur baru dan pemeliharaan script.

---
## ⚙️ Cara Penggunaan
### 0. Persiapan
- Update Repository Sistem Operasi Servernya
- Update
```bash
apt update -y
```
- Install Git
```bash
apt install git -y
```
### 1. Clone Repo
```bash
git clone https://github.com/abdurrozakskom/installer_eraporsmk.git
cd installer_eraporsmk
```
### 2. Beri izin eksekusi
```bash
chmod +x install_erapor.sh
```
### 3. Jalankan script
```bash
sudo ./install_erapor.sh
```
### 4. Isi data interaktif
Script akan meminta:
- Nama domain lokal (misalnya eraporsmk.local / ipaddress)
- Nama database PostgreSQL
- Username database
- Password database

---

## 📂 Lokasi Instalasi
- Direktori aplikasi: /var/www/eraporsmk/
- VirtualHost Apache: /etc/apache2/sites-available/eraporsmk.conf
- Database: PostgreSQL (nama, user, password sesuai input)

## 🔑 Login Awal
Setelah instalasi selesai, buka browser ke:
```bash
http://eraporsmk.local
http://ipaddress
```
User & password default sesuai dengan dokumentasi resmi eRapor SMK.

---

## 🌐 Sosial Media

Ikuti saya di sosial media untuk tips, update, dan info terbaru seputar eRapor SMK:

- **GitHub**    : [https://github.com/abdurrozakskom](https://github.com/abdurrozakskom)  
- **Instagram** : [https://instagram.com/abdurrozak](https://instagram.com/abdurrozak)  
- **Facebook**  : [https://facebook.com/abdurrozak](https://facebook.com/abdurrozak)  
- **Twitter**   : [https://twitter.com/abdurrozak](https://twitter.com/abdurrozak)  
- **YouTube**   : [https://youtube.com/@abdurrozak](https://youtube.com/@abdurrozak)  

---

## 🛠️ Troubleshooting
Jika error **Waiting for cache lock: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process**
```bash
ps aux | grep apt
```
Ganti <PID> dengan nomor proses apt yang muncul.
```bash
sudo kill -9 <PID>
```
```bash
sudo rm /var/lib/dpkg/lock-frontend
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
```
```bash
sudo dpkg --configure -a
sudo apt update
```

Jika domain tidak terbuka, tambahkan domain ke file /etc/hosts:
```bash
sudo nano /etc/hosts
```
Tambahkan baris:
```bash
127.0.0.1   eraporsmk.local
```
Jika error PHP extension, pastikan semua modul sudah terinstall:
```bash
sudo apt install -y php-pgsql php-mbstring php-xml php-curl php-zip php-bcmath
```

---

## 📜 Lisensi
* Script ini bersifat open source dan bebas dimodifikasi sesuai kebutuhan.
* eRapor SMK adalah aplikasi resmi dari Direktorat SMK, Kemdikbud RI.

## 🙌 Kontributor
* Dibuat oleh Abdur Rozak (SMKS Yasmida)
* Untuk mempermudah guru & teknisi sekolah dalam instalasi eRapor SMK.
