#!/bin/bash
# Author: Jon Schipp <jonschipp@gmail.com>
# Provision script for Vagrant
# Edit NAME, EMAIL, and PACKAGES, install and configuration functions

## Variables
NAME="vagrant"
VAGRANT=/home/vagrant
HOME=/root
# Use for provisioning where network info is required
NIC=eth1
IP=$(ifconfig $NIC | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}') # e.g. 10.1.1.2
MASK=$(ifconfig $NIC | grep 'inet addr:' | cut -d: -f4 | awk '{ print $1 }') # e.g. 255.255.255.0
BROADCAST=$(ifconfig $NIC | grep 'inet addr:' | cut -d: -f3 | awk '{ print $1 }') # e.g. #10.1.1.2555
# I'm too lazy to do the math to get net and range, presuming /24
NET=$(ifconfig $NIC | grep 'inet addr:' | cut -d: -f3 | awk '{ print $1 }' | cut -d . -f1-3) # e.g. 10.1.1
BEGIN_RANGE=2
END_RANGE=254
export DEBIAN_FRONTEND=noninteractive
[ -e /etc/redhat-release ] && OS=el
[ -e /etc/debian_version ] && OS=debian
[ "$OS" = "debian" ] && PACKAGES="cowsay git build-essential"
[ "$OS" = "el" ] && PACKAGES="cowsay git"

# Installation notification
MAIL=$(which mail)
COWSAY=/usr/games/cowsay
IRCSAY=/usr/local/bin/ircsay
IRC_CHAN="#replace_me"
HOST=$(hostname -s)
LOGFILE=/root/${NAME}_install.log
EMAIL=user@company.com

cd $HOME

function die {
  if [ -f ${COWSAY:-none} ]; then
    $COWSAY -d "$*"
  else
    echo "$*"
  fi
  if [ -f $IRCSAY ]; then
    ( set +e; $IRCSAY "$IRC_CHAN" "$*" 2>/dev/null || true )
  fi
  [ $MAIL ] && echo "$*" | mail -s "[vagrant] $NAME install information on $HOST" $EMAIL
  exit 1
}

function hi {
  if [ -f ${COWSAY:-none} ]; then
    $COWSAY "$*"
  else
    echo "$*"
  fi
  if [ -f $IRCSAY ]; then
    ( set +e; $IRCSAY "$IRC_CHAN" "$*" 2>/dev/null || true )
  fi
  [ $MAIL ] && echo "$*" | mail -s "[vagrant] $NAME install information on $HOST" $EMAIL
}

number_of_packages(){ package_count="$#"; }

package_check(){
  local packages=$@
  local count=0
  # Count number of items in packages variable
  number_of_packages $packages

  # Format items for egrep query
  pkg_list=$(echo $packages | sed 's/ /|  /g')

  # Count number of packages installed from list
  [ "$OS" = "debian" ] && count=$(dpkg -l | egrep "  $pkg_list" | wc -l)
  [ "$OS" = "el" ]     && count=$(yum list installed | egrep "$pkg_list" | wc -l)

  if [ $count -ge $package_count ]
  then
    return 0
  else
    echo "Installing packages for function!"
    [ "$OS" = "debian" ] && apt-get install -qy $packages
    [ "$OS" = "el" ]     && yum install -qy $packages
  fi
}

install_dependencies(){
  hi "$1 $FUNCNAME\n"
  [ "$OS" = "debian" ] && apt-get update -qq
  [ "$OS" = "el" ]     && yum makecache -q
  package_check $PACKAGES
}

install_docker(){
  is_ubuntu
  hi "  Installing Docker!\n"

  # Check that HTTPS transport is available to APT
  if [ ! -e /usr/lib/apt/methods/https ]; then
    apt-get update -qq
    apt-get install -qy apt-transport-https
    echo
  fi

  # Add the repository to your APT sources
  # Then import the repository key
  if [ ! -e /etc/apt/sources.list.d/docker.list ]
  then
    echo deb https://get.docker.com/ubuntu docker main > /etc/apt/sources.list.d/docker.list
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
    echo
  fi

  # Install docker
  if ! command -v docker >/dev/null 2>&1
  then
    apt-get update -qq
    apt-get install -qy lxc-docker linux-image-extra-$(uname -r) aufs-tools
  fi
}

configuration(){
  hi "$1 $FUNCNAME\n"
  [ -d /opt/influxdb ] || mkdir -p /opt/influxdb
  docker pull jonschipp/influxdb
  docker ps -a | grep -q influxdb ||
    docker run --name="influxdb" --hostname="influxdb" -d -v /opt/influxdb/:/opt/influxdb/shared/data -p 80:80 -p 8083:8083 -p 8086:8086 -p 25826:25826/udp jonschipp/influxdb

cat <<EOF > /etc/init/influxdb.conf
description "InfluxDB container"
author "Jon Schipp"
start on filesystem and started docker
stop on runlevel [!2345]
respawn
script
  /usr/bin/docker start -a influxdb
end script
EOF

  #docker run -d -p 8083:8083 -p 8086:8086 -p 8084:8084 -p 25826:25826/udp --name influxdb --expose 8090 --expose 8099 -e SSL_SUPPORT="True" -e PRE_CREATE_DB="collectd" -e UDP_DB="collectd" tutum/influxdb
  #docker run -d -p 80:80 --name grafana -e HTTP_USER=admin -e HTTP_PASS=gnulug-grafana -e INFLUXDB_HOST=influxdb -e INFLUXDB_PORT=8086 -e INFLUXDB_NAME=collectd -e INFLUXDB_USER=root -e INFLUXDB_PASS=root -e INFLUXDB_IS_GRAFANADB=true --link influxdb:influxdb tutum/grafana
}

install_dependencies "1.)"
install_docker "2.)"
configuration "3.)"
