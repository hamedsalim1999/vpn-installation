apt-get update
wget https://bit.ly/wireguard-script -O wireguard.sh
bash wireguad.sh 2
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
systemctl status wg-quick@wg0.service