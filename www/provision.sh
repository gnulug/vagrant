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
[ "$OS" = "debian" ] && PACKAGES="cowsay git build-essential apache2 awstats"
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
    cd $WEB_DIR && git clone https://github.com/open-nsm/website .
  fi
  cd $HOME
}

configuration(){
  local cron=/etc/cron.d/nsm
  local stats=/etc/awstats/awstats.conf.local
  local web=/etc/apache2/sites-available/000-default.conf
  hi "$1 $FUNCNAME\n"
  [ -f $cron ] || printf "*/5 * * * * root cd $WEB_DIR && git pull\n" > $cron
  [ -f $cron ] && fgrep awstats.pl $cron || printf "*/3 * * * * root /usr/lib/cgi-bin/awstats.pl -config=yourdomain.ext -update > /dev/null\n" > $cron
  grep -q open-nsm $stats || printf 'SiteDomain="open-nsm.net"\n' >> $stats
cat <<EOF > $web
<VirtualHost *:80>
        # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        ServerName open-nsm.net

        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with "a2disconf".
        #Include conf-available/serve-cgi-bin.conf

        # AWSStats
        Alias /awstatsclasses "/usr/share/awstats/lib/"
        Alias /awstats-icon "/usr/share/awstats/icon/"
        Alias /awstatscss "/usr/share/doc/awstats/examples/css"
        ScriptAlias /awstats/ /usr/lib/cgi-bin/
        Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch

</VirtualHost>
EOF
a2enmod cgi
/usr/lib/cgi-bin/awstats.pl -config=open-nsm.net -update
service apache2 restart
}

install_dependencies "1.)"
install_website "2.)"
configuration "3.)"
