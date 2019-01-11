#!/bin/bash
#
# Mon script d'installation automatique Ubuntu Server
#
# Icarius - 12/2018
# GPL
#
# Syntaxe: # sudo ./install.sh
VERSION="1.1"

##############################
# Debut de l'installation
# Test que le script est lance en root
if [ $EUID -ne 0 ]; then
  echo "Le script doit être lancé en root: # sudo $0" 1>&2
  exit 1
fi
# Installation système
echo "Mise à jour des package"
apt update
echo "Mise à jour des package terminé"
echo "Installation des mises à jour"
apt full-upgrade -y
echo "Installation des mises à jour terminé"
echo "Installation de fail2ban"
apt install -y fail2ban
echo "Configuration de fail2ban"
mv /etc/fail2ban/jail.s/defaults-debian.conf /etc/fail2ban/jail.s/defaults-debian.conf.bak
cat <<EOT >>/etc/fail2ban/jail.d/defaults-debian.conf
[DEFAULT]
banaction = ufw

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 6

[nginx-http-auth]
enabled = true
port    = http,https
logpath = %(nginx_error_log)s

[nginx-botsearch]
enabled = true
port     = http,https
logpath  = %(nginx_error_log)s
maxretry = 2

[php-url-fopen]
enabled = true
port    = http,https
logpath = %(nginx_access_log)s

[nginx-badbots]
enabled  = true
port    = http,https
filter = apache-badbots
logpath = %(nginx_access_log)s
maxretry = 1
 
[nginx-proxy]
enabled = true
port 	= http,https
filter 	= nginx-proxy
logpath = %(nginx_access_log)s
maxretry = 0

[nginx-dos]
enabled  = true
port     = http,https
filter   = nginx-dos
logpath  = %(nginx_access_log)s
findtime = 120
maxretry = 200
EOT
wget https://gist.githubusercontent.com/JulienBlancher/48852f9d0b0ef7fd64c3/raw/9f8e9e886a9822483ab3e52682b951a9a68a6519/filter.d_nginx-proxy.conf -O /etc/fail2ban/filter.d/nginx-proxy.conf
wget https://gist.githubusercontent.com/JulienBlancher/48852f9d0b0ef7fd64c3/raw/9f8e9e886a9822483ab3e52682b951a9a68a6519/filter.d_nginx-noscript.conf -O /etc/fail2ban/filter.d/nginx-noscript.conf
wget https://gist.githubusercontent.com/JulienBlancher/48852f9d0b0ef7fd64c3/raw/9f8e9e886a9822483ab3e52682b951a9a68a6519/filter.d_nginx-dos.conf -O /etc/fail2ban/filter.d/nginx-dos.conf
echo "Démarrage de fail2ban"
systemctl start fail2ban
systemctl enable fail2ban
systemctl restart fail2ban
echo "Installation de fail2ban terminé"

echo "Configuration de UFW"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
echo "Activation de UFW"
ufw enable
echo "Activation de UFW terminé"

echo "Installation de cockpit"
apt install -y cockpit cockpit-packagekit
echo "Autorisation du port 9090 dans UFW"
ufw allow 9090/tcp

echo "Configuration du timezone"
timedatectl set-timezone Europe/Paris
echo "Installation de NGINX Et Letsencrypt"
apt install -y nginx python-certbot-nginx
echo "Création dossier _letsencrypt"
mkdir -p /var/www/_letsencrypt && chown www-data /var/www/_letsencrypt
echo "Création dossier du site principal et application des droits"
mkdir -p /var/www/internal-server.ovh/public && chown www-data /var/www/internal-server.ovh
echo "Sauvegarde du fichier nginx.conf d'origine"
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
echo "Téléchargement des fichiers de config NGINX et configuration"
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginx.conf -P /etc/nginx
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/sites-available/internal-server.ovh.conf -P /etc/nginx/sites-available
ln -s /etc/nginx/sites-available/internal-server.ovh.conf /etc/nginx/sites-enabled/internal-server.ovh.conf
sed -i -r 's/(listen .*443)/\1;#/g; s/(ssl_(certificate|certificate_key|trusted_certificate) )/#;#\1/g' /etc/nginx/sites-available/internal-server.ovh.conf
mkdir /etc/nginx/nginxconfig.io
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginxconfig.io/general.conf -P /etc/nginx/nginxconfig.io
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginxconfig.io/letsencrypt.conf -P /etc/nginx/nginxconfig.io
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginxconfig.io/php_fastcgi.conf -P /etc/nginx/nginxconfig.io
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginxconfig.io/proxy.conf -P /etc/nginx/nginxconfig.io

echo "Création du certificat"
certbot certonly --webroot -d internal-server.ovh -d www.internal-server.ovh --email admin@internal-server.ovh -w /var/www/_letsencrypt -n --agree-tos --force-renewal
sed -i -r 's/#?;#//g' /etc/nginx/sites-available/internal-server.ovh.conf
echo "Téléchargement des fichiers de config NGINX et configuration terminé"
echo "Installation temporaire d'un template bootstrap"
git clone https://github.com/BlackrockDigital/startbootstrap-coming-soon.git /var/www/internal-server.ovh/public/
echo "Installation temporaire d'un template bootstrap terminé"
echo "Redémarrage de NGINX"
systemctl restart nginx
echo "Redémarrage de NGINX terminé"
echo "Autorisation des port http, https dans UFW"
ufw allow http
ufw allow https

# Installation PHP 7.3
echo "Ajout dépot PHP et installation de PHPH7.3"
add-apt-repository ppa:ondrej/php
apt update
apt install -y php7.3-fpm php7.3-mysql php7.3-curl php7.3-gd php7.3-mbstring php7.3-common php7.3-xml php7.3-xmlrpc
echo "Ajout dépot PHP et installation de PHPH7.3 terminé" 
# Installation Mariadb-server
echo "Installation de Mariadb serveur et client"
apt install -y mariadb-server mariadb-client
mysql_secure_installation


# Algo VPN
echo "Installation de ALGO VPN"
echo "Installation des packages et dépendances"
apt install -y libssl-dev libffi-dev python-dev python-pip python-setuptools python-virtualenv unzip augeas-lenses libaugeas0
wget https://github.com/trailofbits/algo/archive/master.zip -P /opt
echo "Décompression de l'archive"
unzip /opt/master.zip -d /opt
cd /opt/algo-master/
echo "Compilation de ALGO VPN"
python -m virtualenv --python=`which python2` env &&
    source env/bin/activate &&
    python -m pip install -U pip virtualenv &&
    python -m pip install -r requirements.txt
echo "Autorisation des ports 500,4500 TCP et UDP dans UFW"
ufw allow proto tcp from any to any port 500,4500
ufw allow proto udp from any to any port 500,4500
./algo 

echo"***************************"
echo"** Installation terminée **"
echo"***************************"