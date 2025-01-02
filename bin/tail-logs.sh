#!/bin/bash
sudo tail -f /var/log/nginx/*.log /var/log/fastcgi-perl/error.log /svc/yamenu/*.log
