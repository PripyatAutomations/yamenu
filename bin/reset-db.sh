#!/bin/bash

if [ -f db/yamenu.db ]; then
   echo "* Database already exists at $PWD/db/yamenu.db!"
   read -p "Delete it and continue? Enter YES to confirm " reply
   case ${reply} in
      YES)
         rm -if db/yamenu.db
         ;;
      *)
         echo "Confirmation failed, exiting! |$reply|"
         exit 1
         ;;
   esac
fi

echo "* Importing doc/yamenu.sqlite3.sql to db/yamenu.db"
sqlite3 db/yamenu.db < doc/yamenu.sqlite3.sql
