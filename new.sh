#!/bin/bash
new="$1"
cp -r base $new
[ -d ${new}/.vagrant ] && rm -r ${new}/.vagrant
sed -i "/name/s/ubuntu/$new/" ${new}/Vagrantfile
