#!/bin/bash
new="$1"
uname="$(uname)"
[ $new ] || { echo "Usage: $0 <project_name>"; exit 1; }
[ -d $new ] && { echo "Error: project already exits"; exit 1; }
cp -r base $new
[ -d ${new}/.vagrant ] && rm -r ${new}/.vagrant
[ -f ${new}/Vagrantfile ] && [ "$uname" = "Darwin" ] && sed -i.bu "/name/s/ubuntu/$new/" ${new}/Vagrantfile
[ -f ${new}/Vagrantfile ] && [ "$uname" = "Linux" ]  && sed -i "/name/s/ubuntu/$new/" ${new}/Vagrantfile
