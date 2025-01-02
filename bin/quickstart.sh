#!/bin/sh
if [ "secrets.yml" ]; then
   echo "This will destroy your configuration!"
   echo "Remove it and re-run script to proceed."
   exit 1
fi
cp secrets.yml.example secrets.yml

chown -R www-data:www-data .

echo "Be sure to edit secrets.yml!"
