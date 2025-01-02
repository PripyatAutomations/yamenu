#!/bin/sh
echo "* Starting builtin webserver (nginx)"
nginx -c $PWD/etc/nginx/nginx.conf

# XXX: Check configuration for tftp enable
#echo "* Starting dnsmasq tftp server"
#dnsmasq -C $PWD/etc/dnsmasq.conf
