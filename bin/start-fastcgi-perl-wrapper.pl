#!/bin/bash
### BEGIN INIT INFO
# Provides:          perl-fcgi
# Required-Start:    networking
# Required-Stop:     networking
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start the Perl FastCGI daemon.
### END INIT INFO 

PERL_SCRIPT=/usr/bin/fastcgi-wrapper.pl
FASTCGI_USER=www-data
PID_FILE=/var/run/fastcgi-wrapper.pid
RETVAL=0

case "$1" in
    start)
      mkdir -p /var/log/fastcgi-perl/
      chown -R www-data:www-data /var/log/fastcgi-perl/

      if [ -f $PID_FILE ]; then
        echo "FastCGI daemon is already running with PID $(cat $PID_FILE)"
        exit 1
      fi
      sudo -u $FASTCGI_USER $PERL_SCRIPT &
      echo $! > $PID_FILE  # Save the PID of the process
      RETVAL=$?
  ;;
    stop)
      if [ -f $PID_FILE ]; then
        PID=$(cat $PID_FILE)
        kill -9 $PID 2>/dev/null
        if [ $? -eq 0 ]; then
          echo "FastCGI daemon (PID $PID) stopped."
          rm -f $PID_FILE
        else
          echo "Failed to stop FastCGI daemon (PID $PID)."
        fi
      else
        echo "No FastCGI daemon is running."
      fi
      RETVAL=$?
  ;;
    restart)
      if [ -f $PID_FILE ]; then
        PID=$(cat $PID_FILE)
        kill -9 $PID 2>/dev/null
        if [ $? -eq 0 ]; then
          echo "FastCGI daemon (PID $PID) stopped."
          rm -f $PID_FILE
        else
          echo "Failed to stop FastCGI daemon (PID $PID)."
        fi
      fi
      sudo -u $FASTCGI_USER $PERL_SCRIPT &
      echo $! > $PID_FILE  # Save the new PID
      RETVAL=$?
  ;;
    *)
      echo "Usage: perl-fcgi {start|stop|restart}"
      exit 1
  ;;
esac      
exit $RETVAL
