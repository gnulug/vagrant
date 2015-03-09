#!/bin/bash
# Author: Jon Schipp <jonschipp@gmail.com>
# Provision script for Vagrant
# Edit NAME, EMAIL, and PACKAGES, install and configuration functions

## Variables
NAME="vagrant"
VAGRANT=/home/vagrant
HOME=/root
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

install_blah(){
  hi "$1 $FUNCNAME\n"
  if ! [ -d blah ]
  then
    rm -rf blah
    git clone https://github.com/acmlug/blah || die "Clone of blah repo failed"
    cd blah
    ./configure && make && make install
  fi
  cd $HOME
}

configuration(){
  hi "$1 $FUNCNAME\n"
  getent passwd blah 1>/dev/null || useradd blah --shell /sbin/nologin --home /
  getent group blah | grep -q blahgroup || gpasswd -a blahgroup blah
  chown -R blah:blah /var/log/blah /var/run/blah
  [ -e /etc/blah.conf ] || (install -o root -g root -m 644 $VAGRANT/blah.conf \
    /etc/blah.conf && restart blah)
}

install_dependencies "1.)"
#install_blah "2.)"
#configuration "3.)"
