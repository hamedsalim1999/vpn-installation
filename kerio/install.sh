apt-get update
wget http://cdn.kerio.com/dwn/connect/connect-9.3.0-5257/kerio-connect-9.3.0-5257-linux-amd64.deb
dpkg -i kerio-connect-9.3.0-5257-linux-amd64.deb
systemctl start kerio-connect
