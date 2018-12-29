# Installation système
apt update
apt full-upgrade -y
apt install -y fail2ban
systemctl start fail2ban
systemctl enable fail2ban
mv /etc/fail2ban/jail.s/defaults-debian.conf /etc/fail2ban/jail.s/defaults-debian.conf.bak
cat <<EOT >>/etc/fail2ban/jail.s/defaults-debian.conf
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
EOT

systemctl restart fail2ban

ufw enable
ufw allow ssh


apt install -y cockpit cockpit-packagekit
ufw allow 9090/tcp
apt install -y libssl-dev libffi-dev python-dev python-pip python-setuptools python-virtualenv unzip augeas-lenses libaugeas0
timedatectl set-timezone Europe/Paris
apt install -y nginx
apt install -y python-certbot-nginx

mkdir -p /var/www/_letsencrypt && chown www-data /var/www/_letsencrypt
mkdir -p /var/www/internal-server.ovh/public && chown www-data /var/www/internal-server.ovh
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginx.conf -P /etc/nginx
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/sites-available/internal-server.ovh.conf -P /etc/nginx/sites-available
ln -s /etc/nginx/sites-available/internal-server.ovh.conf /etc/nginx/sites-enabled/internal-server.ovh.conf
sed -i -r 's/(listen .*443)/\1;#/g; s/(ssl_(certificate|certificate_key|trusted_certificate) )/#;#\1/g' /etc/nginx/sites-available/internal-server.ovh.conf
mkdir /etc/nginx/nginxconfig.io
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginxconfig.io/general.conf -P /etc/nginx/nginxconfig.io
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginxconfig.io/letsencrypt.conf -P /etc/nginx/nginxconfig.io
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginxconfig.io/php_fastcgi.conf -P /etc/nginx/nginxconfig.io
wget https://raw.githubusercontent.com/icarius/Ubuntu18.04ServerConfig/master/nginxconfig.io/proxy.conf -P /etc/nginx/nginxconfig.io

certbot certonly --webroot -d internal-server.ovh -d www.internal-server.ovh --email admin@internal-server.ovh -w /var/www/_letsencrypt -n --agree-tos --force-renewal
sed -i -r 's/#?;#//g' /etc/nginx/sites-available/internal-server.ovh.conf
git clone https://github.com/BlackrockDigital/startbootstrap-coming-soon.git /var/www/internal-server.ovh/public/
systemctl restart nginx
ufw allow http
ufw allow https

# Installation PHP 7.3
add-apt-repository ppa:ondrej/php
apt update
apt install -y php7.3-fpm php7.3-mysql php7.3-curl php7.3-gd php7.3-mbstring php7.3-common php7.3-xml php7.3-xmlrpc

# Installation Mariadb-server
apt install -y mariadb-server mraidb-client
mysql_secure_installation


# Algo VPN
cd /opt
apt install -y libssl-dev libffi-dev python-dev python-pip python-setuptools python-virtualenv unzip
wget https://github.com/trailofbits/algo/archive/master.zip
cd algo-master/
python -m virtualenv --python=`which python2` env &&
    source env/bin/activate &&
    python -m pip install -U pip virtualenv &&
    python -m pip install -r requirements.txt

ufw allow proto tcp from any to any port 500,4500
ufw allow proto udp from any to any port 500,4500
 


