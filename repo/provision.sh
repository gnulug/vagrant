#!/bin/bash
# Author: Jon Schipp <jonschipp@gmail.com>
# Provision script for Vagrant
# Edit NAME, EMAIL, and PACKAGES, install and configuration functions

## Variables
NAME="vagrant"
VAGRANT=/home/vagrant
HOME=/root
NIC=eth1
IP=$(ifconfig $NIC | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
# I'm too lazy to do the math to get net and range, presuming /24
NET=$(ifconfig $NIC | grep 'inet addr:' | cut -d: -f3 | awk '{ print $1 }' | cut -d . -f1-3)
export DEBIAN_FRONTEND=noninteractive
[ -e /etc/redhat-release ] && OS=el
[ -e /etc/debian_version ] && OS=debian
[ "$OS" = "debian" ] && PACKAGES="cowsay git apt-cacher apache2 dpkg-dev"
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
  local dir=/var/www/html/packages
  local config=/etc/apt-cacher/apt-cacher.conf
  sed -i '/AUTOSTART/s/0/1/' /etc/default/apt-cacher
  fgrep -q 'lug-l-admin' $config || echo 'admin_email = lug-l-admin@lists.illinois.edu' >> $config
  grep -q '^allowed' $config || echo "allowed_hosts = ${NET}.0/24" >> $config
  /usr/share/apt-cacher/apt-cacher-import.pl -l /var/cache/apt/archives 2>/dev/null
  mkdir -p $dir/{amd64,i386}
cat <<EOF > $dir/update_repo.sh
#!/usr/bin/env bash
dir=$dir
cd $dir
dpkg-scanpackages amd64 | gzip -9c > amd64/Packages.gz
dpkg-scanpackages i386  | gzip -9c > i386/Packages.gz
EOF
chmod 750 $dir/update_repo.sh
}

start_daemons(){
  hi "$1 $FUNCNAME\n"
  /etc/init.d/apt-cacher restart
  /etc/init.d/apache2 restart
}

install_dependencies "1.)"
configuration "2.)"
start_daemons "3.)"

# Configure client
echo "Acquire::http::Proxy \"http://${IP}:3142\";" > /etc/apt/apt.conf.d/01proxy

hi "Configure hosts with: Acquire::http::Proxy http://${IP}:3142; > /etc/apt/apt.conf.d/01proxy"
hi "and /etc/apt/sources.list.d/lug.list: deb http://${IP}/packages/ amd64/"
