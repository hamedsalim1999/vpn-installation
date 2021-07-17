#!/bin/bash
exec >> openswan-install.log
exec 2>&1

#This script performs a full install & Configuration of OpenSwan on this machine. This script will prompt for user
#input and needs to be run on both the local and the remove machine - for now anyway.

#Define Variables and Request user input
psk = NEW_UUID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
echo -n "Enter EIP for LOCAL Gateway: "
read localeip
echo -n "Enter CIDR for LOCAL Gateway [e.g. 10.200.0.0/16]: "
read localcidr
echo -n "Enter EIP for REMOTE Gateway: "
read remoteeip
echo -n "Enter CIDR for REMOTE Gateway [e.g. 10.200.0.0/16]: "
read remotecidr
echo -n "LOCAL Region Name [e.g. us-east-1]: "
read localregion
echo -n "REMOTE Region Name [e.g. us-west-1]: "
read remoteregion

function install{
# Function to install & configure OpenSwan
sudo yum install openswan -y
sudo echo include /etc/ipsec.d/*.conf >> /etc/ipsec.conf
sudo echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
sudo echo 0 > /proc/sys/net/ipv4/conf/default/send_redirects
sudo echo 0 > /proc/sys/net/ipv4/conf/eth0/send_redirects
sudo echo 0 > /proc/sys/net/ipv4/conf/lo/send_redirects
sudo echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
sudo echo 0 > /proc/sys/net/ipv4/conf/default/accept_redirects
sudo echo 0 > /proc/sys/net/ipv4/conf/eth0/accept_redirects
sudo echo 0 > /proc/sys/net/ipv4/conf/lo/accept_redirects
sudo sed '/net.ipv4.ip_forward = 0/d' ./etc/sysctl.conf
sudo echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

#Start services & set to auto start on boot
sudo service network restart
sudo service ipsec start
sudo chkconfig ipsec on
}

if (( $(ps -ef | grep -v grep | grep ipsec | wc -l) > 0 ))
then
echo "$service already installed. Moving on"
else
install

#Configure new OpenSwan Tunnel
sudo echo "conn $localeip-to-$remoteeip" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "type=tunnel" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "authby=secret" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "left=%defaultroute" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "leftid=$localeip" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "leftnexthop=%defaultroute" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "leftsubnet=$localcidr" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "right=$remoteeip" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "rightsubnet=$remotecidr" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "pfs=yes" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "auto=start" >> /etc/ipsec.d/$localregion-to-$remoteregion.conf
sudo echo "$localeip $remoteeip: PSK "$psk"" >> /etc/ipsec.d/$localregion-to-$remoteregion.secrets
sudo service ipsec restart

#Running Open Port Checks
nc -z $remoteeip 500
nc -z $remoteeip 4500

echo "Now go configure the other side with this script if you haven't already"
echo "Ping remote gateway private IP to test connectivity"
echo ""
echo "That's me done - Bye!"