#!/usr/bin/env bash

VERSION=6.5.1

# Ubuntu Box
apt update > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install wget -y > /dev/null 2>&1

# Concourse
wget https://github.com/concourse/concourse/releases/download/v$VERSION/concourse-$VERSION-linux-amd64.tgz > /dev/null 2>&1
tar xvzf concourse-$VERSION-linux-amd64.tgz -C /usr/local/  > /dev/null 2>&1
rm -rf concourse-$VERSION-linux-amd64.tgz

# Environment
echo "===================================================="
echo "PATH=$PATH:/usr/local/concourse/bin" >> /etc/environment
source /etc/environment

# Keys
sudo cp -r /vagrant/concourse /etc/

# User/Group
adduser --shell /bin/bash --home /home/concourse --system --group concourse
echo "concourse:passwd" | chpasswd
chgrp concourse /etc/concourse/*
chmod g+r /etc/concourse/*

# Service
cat >/etc/systemd/system/concourse_worker.service <<-EOF
        [Unit]
        Description=Concourse CI Worker
        After=concourse_web.service

        [Service]
        ExecStart=/usr/local/bin/concourse worker \
               --work-dir=/var/lib/concourse \
               --tsa-host=192.168.50.10 \
               --tsa-public-key=/etc/concourse/host_key.pub \
               --tsa-worker-private-key=/etc/concourse/worker_key

        User=root
        Group=root

        Type=simple

        [Install]
        WantedBy=default.target
EOF
echo "Done."
echo "===================================================="

# Service Enable/Start
systemctl enable concourse_worker.service
systemctl start concourse_worker.service
