#!/bin/bash

#  setdns.sh
#  OnomaMenubar
#
#  Created by Matthew Slipper on 12/23/18.
#  Copyright © 2018 Kyokan. All rights reserved.
set -e
IFS=$'\n'
MINPARAMS=1

if [ $# -lt "$MINPARAMS" ]
then
    echo "Not enough arguments."
    exit 1
fi

for iface in `networksetup -listallnetworkservices | tail -n +2`
do
    echo "Setting DNS server for interface $iface..."
    networksetup -setdnsservers "$iface" $1
done
