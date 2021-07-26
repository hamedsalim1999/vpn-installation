#!/usr/bin/env bash

RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
NO_COLOR='\033[0m'

# Encryption
ciphers=(
  aes-128-cfb
  aes-192-cfb
  aes-256-cfb
  chacha20
  salsa20
  rc4-md5
  aes-128-ctr
  aes-192-ctr
  aes-256-ctr
  aes-256-gcm
  aes-192-gcm
  aes-128-gcm
  camellia-128-cfb
  camellia-192-cfb
  camellia-256-cfb
  chacha20-ietf
  bf-cfb
)
# current/working directory
CUR_DIR=`pwd`

init_release(){
  if [ -f /etc/os-release ]; then
      # freedesktop.org and systemd
      . /etc/os-release
      OS=$NAME
  elif type lsb_release >/dev/null 2>&1; then
      # linuxbase.org
      OS=$(lsb_release -si)
  elif [ -f /etc/lsb-release ]; then
      # For some versions of Debian/Ubuntu without lsb_release command
      . /etc/lsb-release
      OS=$DISTRIB_ID
  elif [ -f /etc/debian_version ]; then
      # Older Debian/Ubuntu/etc.
      OS=Debian
  elif [ -f /etc/SuSe-release ]; then
      # Older SuSE/etc.
      ...
  elif [ -f /etc/redhat-release ]; then
      # Older Red Hat, CentOS, etc.
      ...
  else
      # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
      OS=$(uname -s)
  fi

  # convert string to lower case
  OS=`echo "$OS" | tr '[:upper:]' '[:lower:]'`

  if [[ $OS = *'ubuntu'* || $OS = *'debian'* ]]; then
    PM='apt'
  elif [[ $OS = *'centos'* ]]; then
    PM='yum'
  else
    exit 1
  fi
}

# script introduction
intro() {
  clear
  echo
  echo "******************************************************"
  echo "* OS     : Debian Ubuntu CentOS                      *"
  echo "* Desc   : auto install shadowsocks on CentOS server *"
  echo "* Author : https://github.com/shellhub               *"
  echo "******************************************************"
  echo
}

isRoot() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "false"
  else
    echo "true"
  fi
}

get_unused_port()
{
  if [ $# -eq 0 ]
    then
      $1=3333
  fi
  for UNUSED_PORT in $(seq $1 65000); do
    echo -ne "\035" | telnet 127.0.0.1 $UNUSED_PORT > /dev/null 2>&1
    [ $? -eq 1 ] && break
  done
}

config(){
  # config encryption password
  read -p "Password used for encryption (Default: shellhub):" sspwd
  if [[ -z "${sspwd}" ]]; then
    sspwd="shellhub"
  fi
  echo -e "encryption password: ${GREEN_COLOR}${sspwd}${NO_COLOR}"

  # config server port
  while [[ true ]]; do
    get_unused_port $(shuf -i 2000-65000 -n 1)
    local port=${UNUSED_PORT}
    read -p "Server port(1-65535) (Default: ${port}):" server_port
    if [[ -z "${server_port}" ]]; then
      server_port=${port}
    fi

    # make sure port is number
    expr ${server_port} + 1 &> /dev/null
    if [[ $? -eq 0 ]]; then
      # make sure port in range(1-65535)
      if [ ${server_port} -ge 1 ] && [ ${server_port} -le 65535 ]; then
        #make sure port is free
        lsof -i:${server_port} &> /dev/null
        if [[ $? -ne 0 ]]; then
          echo -e "server port: ${GREEN_COLOR}${server_port}${NO_COLOR}"
          break
        else
          echo -e "${RED_COLOR}${server_port}${NO_COLOR} is occupied"
          continue
        fi
      fi
    fi
    echo -e "${RED_COLOR}Invalid${NO_COLOR} port:${server_port}"
  done

  # config encryption method
  while [[ true ]]; do
    for (( i = 0; i < ${#ciphers[@]}; i++ )); do
      echo -e "${GREEN_COLOR}`expr ${i} + 1`${NO_COLOR}:\t${ciphers[${i}]}"
    done
    read -p "Select encryption method (Default: aes-256-cfb):" pick
    if [[ -z ${pick} ]]; then
      # default is aes-256-cfb
      pick=3
    fi
    expr ${pick} + 1 &> /dev/null
    if [[ $? -ne 0 ]]; then
      echo -e "${RED_COLOR}Invalid${NO_COLOR} number ${pick},try again"
      continue
    elif [ ${pick} -lt 1 ] || [ ${pick} -gt ${#ciphers[@]} ]; then
      echo -e "${RED_COLOR}Invalid${NO_COLOR} number ${pick},should be is(1-${#ciphers[@]})"
      continue
    else
      encryption_method=${ciphers[${pick}-1]}
      echo -e "encryption method: ${GREEN_COLOR}${encryption_method}${NO_COLOR}"
      break
    fi
  done
  # add shadowsocks config file
  cat <<EOT > /etc/shadowsocks.json
{
  "server":"0.0.0.0",
  "server_port":${server_port},
  "local_address": "127.0.0.1",
  "local_port":1080,
  "password":"${sspwd}",
  "timeout":300,
  "method":"${encryption_method}",
  "fast_open": false
}
EOT
}

containsIgnoreCase(){
  # convert arg1 to lower case
  str=`echo "$1" | tr '[:upper:]' '[:lower:]'`
  # convert arg2 to lower case
  searchStr=`echo "$2" | tr '[:upper:]' '[:lower:]'`
  echo ${1}
  echo ${2}
  if [[ ${str} = *${searchStr}* ]]; then
    echo "true"
  else
    echo "false"
  fi
}

addTcpPort(){
  tcpPort=${1}
  cat /etc/*elease | grep -q VERSION_ID=\"7\"
  if [[ $? = 0 ]]; then
    firewall-cmd --zone=public --add-port=${tcpPort}/tcp --permanent
    firewall-cmd --reload
  else
    iptables -I INPUT -p tcp -m tcp --dport ${tcpPort} -j ACCEPT
    service iptables save
  fi
}

# show install success information
successInfo(){
  IP_ADDRESS=$(dig +short myip.opendns.com @resolver1.opendns.com)
  clear
  echo
  echo "Install completed"
  echo -e "ip_address:\t${GREEN_COLOR}${IP_ADDRESS}${NO_COLOR}"
  echo -e "server_port:\t${GREEN_COLOR}${server_port}${NO_COLOR}"
  echo -e "encryption:\t${GREEN_COLOR}${encryption_method}${NO_COLOR}"
  echo -e "password:\t${GREEN_COLOR}${sspwd}${NO_COLOR}"
  ss_link=$(echo ${encryption_method}:${sspwd}@${IP_ADDRESS}:${server_port} | base64)
  ss_link="ss://${ss_link}"
  echo -e "ss_link:\t${GREEN_COLOR}${ss_link}${NO_COLOR}"
  pip install qrcode >/dev/null
  echo -n "ss://"`echo -n ${encryption_method}:${sspwd}@${IP_ADDRESS}:${server_port} | base64` | qr
  echo -e "visit:\t\t${GREEN_COLOR}https://www.github.com/shellhub/shellhub${NO_COLOR}"
  echo
}

# install shadowsocks
install_shadowsocks(){
  setuptools_url=https://files.pythonhosted.org/packages/68/75/d1d7b7340b9eb6e0388bf95729e63c410b381eb71fe8875cdfd949d8f9ce/setuptools-45.2.0.zip
  file_name=$(basename $setuptools_url)
  dir_name=${file_name%.*}
  wget -O $file_name $setuptools_url
  unzip $file_name
  cd $dir_name

  #install setuptools
  python2 setup.py install
  easy_install pip
  pip install git+https://github.com/shadowsocks/shadowsocks.git@master
}

# stop firewall
stop_firewall(){
  if [[ ${PM} = "apt" ]]; then
    ufw disable 2>&1 >/dev/null
    #statements
    systemctl stop firewalld 2>&1 >/dev/null
    systemctl disable firewalld 2>&1 >/dev/null
  fi
}

install_package(){
  # init package manager
  init_release
  if [[ ${PM} = "apt" ]]; then
    apt-get install dnsutils -y
    apt-get install telnet -y
    apt-get install git -y
    apt-get install zip -y
    apt-get install python2 -y
  elif [[ ${PM} = "yum" ]]; then
    yum install bind-utils -y
    yum install telnet -y
    yum install git -y
    yum install unzip -y
    yum install python2 -y
  fi
}

main(){

  #check root permission
  isRoot=$( isRoot )
  if [[ "${isRoot}" != "true" ]]; then
    echo -e "${RED_COLOR}error:${NO_COLOR}Please run this script as as root"
    exit 1
  else
    install_package
    intro
    config
    install_shadowsocks
    #addTcpPort ${server_port}
    stop_firewall
    # run background
    `ssserver -c /etc/shadowsocks.json --user nobody -d start` >/dev/null
    successInfo
  fi
}

main