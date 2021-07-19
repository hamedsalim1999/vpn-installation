apt update 
apt install strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins -y
mkdir -p ~/pki/cacerts
mkdir -p ~/pki/certs
mkdir -p ~/pki/private
chmod 700 ~/pki
pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/ca-key.pem
pki --self --ca --lifetime 3650 --in ~/pki/private/ca-key.pem \
    --type rsa --dn "CN=VPN root CA" --outform pem > ~/pki/cacerts/ca-cert.pem
pki --gen --type rsa --size 4096 --outform pem > ~/pki/private/server-key.pem
pki --pub --in ~/pki/private/server-key.pem --type rsa \
    | pki --issue --lifetime 1825 \
        --cacert ~/pki/cacerts/ca-cert.pem \
        --cakey ~/pki/private/ca-key.pem \
        --dn "CN=server_domain_or_IP" --san server_domain_or_IP \
        --flag serverAuth --flag ikeIntermediate --outform pem \
    >  ~/pki/certs/server-cert.pem
sudo cp -r ~/pki/* /etc/ipsec.d/
sudo mv /etc/ipsec.conf{,.original}
cp ~/ipsec.conf /etc/ipsec.conf
cp ~/ipsec.secrets /etc/ipsec.secrets
systemctl restart strongswan-starter
ufw allow OpenSSH
ufw enable -y
ufw allow 500,4500/udp
ip route show default
cat /etc/ipsec.d/cacerts/ca-cert.pem