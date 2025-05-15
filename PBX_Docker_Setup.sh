#!/usr/bin/env bash
set -e

# 1) Install Docker & the Compose plugin
curl -fsSL https://get.docker.com | sh
apt-get update
apt-get install -y docker-compose-plugin

# 2) Project directory
PROJECT_DIR="$HOME/freepbx-docker"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 3) Write the Dockerfile
cat > Dockerfile <<'EOF'
FROM php:8.2-apache

# 3.1) System deps + PHP modules
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    asterisk asterisk-mysql \
    mariadb-server \
    git curl wget sox libncurses5-dev libxml2-dev libssl-dev libjansson-dev libedit-dev procps \
    supervisor \
    php-mysql php-xml php-mbstring php-curl php-zip php-gd php-cli php-opcache php-pear \
  && rm -rf /var/lib/apt/lists/*

# 3.2) Create the asterisk user & dirs
RUN groupadd -r asterisk \
 && useradd -r -g asterisk -d /var/lib/asterisk -s /usr/sbin/nologin -c "Asterisk PBX" asterisk \
 && mkdir -p /var/{lib,log,run,spool}/asterisk \
 && chown -R asterisk:asterisk /var/{lib,log,run,spool}/asterisk

# 3.3) Let Apache (www-data) read asterisk-owned files
RUN usermod -aG asterisk www-data

# 3.4) Ensure PHP sessions dir exists & is 1733
RUN mkdir -p /var/lib/php/sessions \
 && chown root:root /var/lib/php/sessions \
 && chmod 1733      /var/lib/php/sessions

# 3.5) Enable Apache modules required by FreePBX
RUN a2enmod rewrite actions alias proxy_fcgi

# 3.6) Clone FreePBX sources
WORKDIR /usr/src
RUN git clone --depth 1 https://gerrit.freepbx.org/freepbx freepbx

# 3.7) Add our entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 3.8) Expose HTTP, SIP & RTP
EXPOSE 80 5060/udp 10000-20000/udp

ENTRYPOINT ["/entrypoint.sh"]
EOF

# 4) Write the entrypoint, which fixes perms on every start
cat > entrypoint.sh <<'EOF'
#!/usr/bin/env bash
set -e

# 4.1) Fix ownership on any mounted volumes and session dir
chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk
chmod -R 750 /etc/asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk

mkdir -p /var/lib/php/sessions
chmod 1733 /var/lib/php/sessions

# 4.2) If FreePBX not yet installed, do it now
if [ ! -f /etc/freepbx.conf ]; then
  service mysql start
  until mysqladmin ping &>/dev/null; do sleep 1; done

  asterisk -f -vvvg & sleep 2

  cd /usr/src/freepbx
  ./install -n
fi

# 4.3) Always reset FreePBX file ownership & perms
cd /usr/src/freepbx
fwconsole chown

# Ensure freepbx.conf is group-readable by asterisk:www-data
chown asterisk:asterisk /etc/freepbx.conf
chmod 640               /etc/freepbx.conf

# 4.4) Start remaining services
service mysql start
until mysqladmin ping &>/dev/null; do sleep 1; done

asterisk -f -vvvg &

# Finally hand off to Apache in foreground
apache2-foreground
EOF
chmod +x entrypoint.sh

# 5) Write docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: '3.8'
services:
  freepbx:
    build: .
    privileged: true
    ports:
      - "80:80"
      - "5060:5060/udp"
      - "10000-20000:10000-20000/udp"
    volumes:
      - freepbx-etc:/etc/asterisk
      - freepbx-data:/var/lib/asterisk
      - freepbx-log:/var/log/asterisk
      - freepbx-www:/var/www/html

volumes:
  freepbx-etc:
  freepbx-data:
  freepbx-log:
  freepbx-www:
EOF

# 6) Build & launch
docker compose up -d --build

echo "✅ Done! FreePBX should now be running in Docker."
echo "   Visit http://<your-pi-ip>/admin and log in with the admin credentials you set during the initial install."
