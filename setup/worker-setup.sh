#!/usr/bin/env bash

VERSION=6.5.1

echo "** Starting setup as: $(whoami)"

# Ubuntu Box
echo "** 1/7 Ubuntu"
apt update > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install wget net-tools -y > /dev/null 2>&1

# Concourse
echo "** 2/7 Concourse"
wget https://github.com/concourse/concourse/releases/download/v$VERSION/concourse-$VERSION-linux-amd64.tgz > /dev/null 2>&1
tar xvzf concourse-$VERSION-linux-amd64.tgz -C /usr/local/  > /dev/null 2>&1
rm -rf concourse-$VERSION-linux-amd64.tgz

# Environment
echo "** 3/7 Environment"
echo "===================================================="
echo "PATH=$PATH:/usr/local/concourse/bin" >> /etc/environment
source /etc/environment

# Keys
echo "** 4/7 Keys"
sudo cp -r /vagrant/concourse /etc/

# User/Group
echo "** 5/7 User"
adduser --shell /bin/bash --home /home/concourse --system --group concourse
echo "concourse:passwd" | chpasswd
chgrp concourse /etc/concourse/*
chmod g+r /etc/concourse/*

# Service
echo "** 6/7 Service"
cat >/etc/systemd/system/concourse_worker.service <<-EOF
        [Unit]
        Description=Concourse CI Worker
        After=concourse_web.service

        [Service]
        ExecStart=/usr/local/concourse/bin/concourse worker \
               --work-dir=/var/lib/concourse \
               --tsa-host=192.168.50.10:2223 \
               --tsa-public-key=/etc/concourse/tsa_host_key.pub \
               --tsa-worker-private-key=/etc/concourse/worker_key \
               --runtime=containerd

        User=root
        Group=root

        Type=simple

        [Install]
        WantedBy=default.target
EOF

# Service Enable/Start
echo "** 7/7 Start Concourse Worker"
systemctl enable concourse_worker.service
systemctl start concourse_worker.service

echo "** DONE **"