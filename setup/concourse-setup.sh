#!/usr/bin/env bash

VERSION=6.5.1

echo "** Starting setup as: $(whoami)"

# Ubuntu Box
echo "** 1/8 Ubuntu"
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt update > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
apt install vault wget net-tools postgresql postgresql-contrib -y > /dev/null 2>&1

# Concourse
echo "** 2/8 Concourse"
wget https://github.com/concourse/concourse/releases/download/v$VERSION/concourse-$VERSION-linux-amd64.tgz > /dev/null 2>&1
tar xvzf concourse-$VERSION-linux-amd64.tgz -C /usr/local/  > /dev/null 2>&1
rm -rf concourse-$VERSION-linux-amd64.tgz

# Environment
echo "** 3/8 Environment"
echo "PATH=$PATH:/usr/local/concourse/bin" >> /etc/environment
echo "VAULT_ADDR=https://192.168.50.10:8200" >> /etc/environment
source /etc/environment

# Keys
echo "** 4/8 Keys"
mkdir -p /etc/concourse
concourse generate-key -t rsa -f /etc/concourse/session_signing_key
concourse generate-key -t ssh -f /etc/concourse/tsa_host_key
concourse generate-key -t ssh -f /etc/concourse/worker_key
cp /etc/concourse/worker_key.pub /etc/concourse/authorized_worker_keys

# User
echo "** 5/8 User"
adduser --shell /bin/bash --home /home/concourse --system --group concourse
chgrp concourse /etc/concourse/*
chmod g+r /etc/concourse/*
cp -r /etc/concourse /vagrant/
echo "concourse:passwd" | chpasswd
usermod -aG sudo concourse

# Postgresql
echo "** 6/8 Postgress"
sudo su postgres -c "createuser concourse"
sudo su postgres -c "createdb --owner=concourse atc"
sudo -u postgres psql -c "ALTER USER concourse WITH PASSWORD 'passwd';"

# Service
echo "** 7/8 Service"
cat >/etc/systemd/system/concourse_web.service <<-EOF
        [Unit]
        Description=Concourse CI Web
        After=postgresql.service

        [Service]
        ExecStart=/usr/local/concourse/bin/concourse web \
               --add-local-user=admin:admin \
               --main-team-local-user=admin \
               --session-signing-key=/etc/concourse/session_signing_key \
               --tsa-peer-address=192.168.50.10 \
               --tsa-bind-ip=0.0.0.0 \
               --tsa-bind-port=2223 \
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

cat > /etc/systemd/system/vault.service <<-EOF
        [Unit]
        Description="HashiCorp Vault - A tool for managing secrets"
        Documentation=https://www.vaultproject.io/docs/
        Requires=network-online.target
        After=network-online.target
        ConditionFileNotEmpty=/etc/vault.d/vault.hcl

        [Service]
        User=vault
        Group=vault
        ProtectSystem=full
        ProtectHome=read-only
        PrivateTmp=yes
        PrivateDevices=yes
        SecureBits=keep-caps
        AmbientCapabilities=CAP_IPC_LOCK
        NoNewPrivileges=yes
        ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
        ExecReload=/bin/kill --signal HUP
        KillMode=process
        KillSignal=SIGINT
        Restart=on-failure
        RestartSec=5
        TimeoutStopSec=30
        StartLimitBurst=3
        LimitNOFILE=65536

        [Install]
        WantedBy=multi-user.target
EOF

# Service Enable/Start
echo "** 8/8 Start Services"
echo "** > Enable Concourse Web"
systemctl enable concourse_web.service
systemctl start concourse_web.service


echo "** > Creating Self Certs for Vault Service"
mkdir -p /etc/vault.d/certs
mkdir -p /usr/local/share/ca-certificates/vault

curl -sS https://raw.githubusercontent.com/antelle/generate-ip-cert/master/generate-ip-cert.sh | bash -s 192.168.50.10
cp cert.pem /usr/local/share/ca-certificates/vault/vault.crt
mv *.pem /etc/vault.d/certs/
sed -i 's/127.0.0.1/192.168.50.10/g' /etc/vault.d/vault.hcl
chown -R vault.vault /etc/vault.d/
update-ca-certificates

echo "** > Enable Vault Service"
systemctl enable vault.service
systemctl start vault.service

echo "** > Init Vault "
vault operator init > /etc/vault.d/init.file
chown vault.vault /etc/vault.d/init.file
cp -r /etc/vault.d /vagrant/
for i in `cat /etc/vault.d/init.file | grep "Key" | awk '{print $4}'`; do vault operator unseal $i; done
cat /etc/vault.d/init.file |grep Token |awk '{print $4}' > /vagrant/vault.d/VAULT_TOKEN

echo "** > Creating Concourse Policy"
cat > /etc/vault.d/concourse-policy.hcl <<-EOF
path "concourse/*" {
  capabilities = ["create", "update", "read", "list"]
}
EOF

vault policy write concourse /etc/vault.d/concourse-policy.hcl
vault secrets enable -path=concourse/ kv

echo "** DONE **"


