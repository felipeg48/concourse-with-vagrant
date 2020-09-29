#!/usr/bin/env bash

sudo apt update > /dev/null 2>&1
sudo apt upgrade -y > /dev/null 2>&1
sudo apt install -y postgresql > /dev/null 2>&1 #postgresql-contrib > /dev/null 2>&1
echo "===================================================="
echo "About to create user..."
echo "===================================================="
sudo su postgres -c "createuser vagrant"
sudo su postgres -c "createdb --owner=vagrant atc"
echo "===================================================="
echo "Database: atc and user: vagrant created."
echo "===================================================="