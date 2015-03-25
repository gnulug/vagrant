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
WEB_DIR=/var/www/html
export DEBIAN_FRONTEND=noninteractive
[ -e /etc/redhat-release ] && OS=el
[ -e /etc/debian_version ] && OS=debian
[ "$OS" = "debian" ] && PACKAGES="cowsay git build-essential apache2"
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

install_website(){
  hi "$1 $FUNCNAME\n"
  if ! [ -f $WEB_DIR/meetings.html ]
  then
    rm -f $WEB_DIR/*
    cd $WEB_DIR && git clone https://github.com/acmlug/website .
  fi
  cd $HOME
}

configuration(){
  local cron=/etc/cron.d/lug
  hi "$1 $FUNCNAME\n"
  [ -f $cron ] || printf "*/5 * * * * root cd $WEB_DIR && git pull\n" > $cron
}

install_dependencies "1.)"
install_website "2.)"
configuration "3.)"
