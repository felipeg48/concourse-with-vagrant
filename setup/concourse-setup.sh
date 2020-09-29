#!/usr/bin/env bash

VERSION=6.5.1

# Ubuntu Box
apt update > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install wget postgresql postgresql-contrib -y > /dev/null 2>&1

# Concourse
wget https://github.com/concourse/concourse/releases/download/v$VERSION/concourse-$VERSION-linux-amd64.tgz > /dev/null 2>&1
tar xvzf concourse-$VERSION-linux-amd64.tgz -C /usr/local/  > /dev/null 2>&1
rm -rf concourse-$VERSION-linux-amd64.tgz

# Environment
echo "===================================================="
echo "PATH=$PATH:/usr/local/concourse/bin" >> /etc/environment
source /etc/environment

# Keys
mkdir -p /etc/concourse
concourse generate-key -t rsa -f /etc/concourse/session_signing_key
concourse generate-key -t ssh -f /etc/concourse/tsa_host_key
concourse generate-key -t ssh -f /etc/concourse/worker_key
cp /etc/concourse/worker_key.pub /etc/concourse/authorized_worker_keys

# User
adduser --shell /bin/bash --home /home/concourse --system --group concourse
chgrp concourse /etc/concourse/*
chmod g+r /etc/concourse/*
cp -r /etc/concourse /vagrant/
echo "concourse:passwd" | chpasswd
usermod -aG sudo concourse

# Postgresql
sudo -u postgres -c "createuser concourse"
sudo -u postgres -c "createdb --owner=concourse atc"
sudo -u postgres psql -c "ALTER USER concourse WITH PASSWORD 'passwd';"

# Service
cat >/etc/systemd/system/concourse_web.service <<-EOF
        [Unit]
        Description=Concourse CI Web
        After=postgresql.service

        [Service]
        ExecStart=/usr/local/concourse/bin/concourse web \
               --add-local-user=admin:admin \
               --main-team-local-user=admin \
               --session-signing-key=/etc/concourse/session_signing_key \
               --tsa-host-key=/etc/concourse/tsa_host_key \
               --tsa-authorized-keys=/etc/concourse/authorized_worker_keys \
               --external-url="http://192.168.50.10:8080" \
               --postgres-user=concourse \
               --postgres-password=passwd

        User=concourse
        Group=concourse

        Type=simple

        [Install]
        WantedBy=default.target
EOF
echo "Done."
echo "===================================================="

# Service Enable/Start
systemctl enable concourse_web.service
systemctl start concourse_web.service