# ubuntu 18
apt-get update
apt install vtun -y
cp vtun.conf /etc/vtund.conf
vtund -f /etc/vtund.conf -s
