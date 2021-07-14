#!/usr/bin/env bash

set -eu

## https://www.tinc-vpn.org/
## https://www.tinc-vpn.org/packages/tinc-1.0.36.tar.gz

NAME=tinc

#Initial VPN to be created
VPN=vpn1

## Enter the version to be used
TINC_SOURCE=tinc-1.0.36.tar.gz

TINC_SOURCE_DIR="${TINC_SOURCE%.tar.gz}"
TINC_URL="https://www.tinc-vpn.org/packages/$TINC_SOURCE"
TINC_LOG_DIR="/var/log/$NAME/"

cat << EOF > ./envvars-$VPN
## Environmental variables for $NAME.service
# Extra options to be passed to tincd.
TINC_ARGS="-d2"
# Limits to be configured for the tincd process. Please read your shell
# (pointed by /bin/sh) documentation for ulimit. You probably want to raise the
# max locked memory value if using both --mlock and --user flags.
# LIMITS="-l 1024"
TINC_LOG_DIR="$TINC_LOG_DIR"
TINC_LOG_FILE="$NAME-$VPN.log"
EOF
#chmod 755 ./envvars-$VPN

sudo apt-get update
sudo apt-get install -y build-essential
sudo apt-get install -y liblzo2-dev

#Download if not exist
if [ ! -f $TINC_SOURCE ]; then
    echo "Downloading Tinc Source..."
    wget $TINC_URL
    if [ -d $TINC_SOURCE_DIR ]; then
        echo "Removing current build..."
        rm -rf $TINC_SOURCE_DIR
    fi
fi

if [ ! -f $TINC_SOURCE_DIR ]; then
        echo "Unpacking..."
        tar xf $TINC_SOURCE
fi

cd $TINC_SOURCE_DIR
echo "CONFIGURING..."
./configure --with-systemd=../../systemd-ref
echo "BUILDING..."
make
echo "INSTALLING..."
sudo make install

cd ..

echo "CREATING SYSTEM DIRs..."

if [ ! -d "/usr/local/etc/tinc/$VPN" ]; then
    echo "Creating etc directory"
    sudo mkdir --parents "/usr/local/etc/tinc/$VPN/hosts"
fi

if [ ! -d "$TINC_LOG_DIR" ]; then
    echo "Creating log directory"
    sudo mkdir --parents $TINC_LOG_DIR
fi

for i in /usr/local/etc/tinc/rsa*; do
  if [ -f "$i" ]; then 
    sudo rm -f /usr/local/etc/tinc/rsa* >/dev/null 2>&1
  fi
done
if [ ! -f "/usr/local/etc/tinc/$VPN/rsa_key.priv" ]; then
    sudo /usr/local/sbin/tincd -K 4096
    sudo mv /usr/local/etc/tinc/rsa* /usr/local/etc/tinc/$VPN
fi

sudo cp ./tinc.conf /usr/local/etc/tinc/$VPN
sudo cp ./tinc-up   /usr/local/etc/tinc/$VPN
sudo cp ./tinc-down /usr/local/etc/tinc/$VPN
sudo cp ./changemefar  /usr/local/etc/tinc/$VPN/hosts

#sudo chown root:root /usr/local/etc/tinc/tinc.conf*
sudo cp ./envvars-$VPN /usr/local/etc/tinc/$VPN

sudo cp ./tinc.service /etc/systemd/system/
sudo cp ./tinc@.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable tinc@$VPN.service
sudo systemctl restart tinc@$VPN.service
sudo systemctl status tinc@$VPN.service

echo "DONE"
exit 0