#!/bin/bash

#2025.10 Made by melongist(melongist@gmail.com) for CS teachers




#php(fpm) autoscaling script for DOMjudge server




#Memory autoscaling for php(fpm)
#Terminal commands to autoscaling DOMjudge server
#wget https://raw.githubusercontent.com/justiceHui/domjudge-installer/main/dj900mas.sh
#bash dj900mas.sh


#------

if [[ $SUDO_USER ]] ; then
  echo "Just use 'bash dj900mas.sh'"
  exit 1
fi


if [ ! -d /opt/domjudge/domserver ] ; then
  echo ""
  echo "DOMjudge server is not installed at this computer!!"
  echo ""
  exit 1
fi


echo "php(fpm) autoscaling for DOMjudge server started..."
echo ""
echo "H/W memory information"
#check the H/W memory size GiB
echo "Memory size(GiB)"
MEMS=$(free --gibi | grep "Mem:" | awk  '{print $2}')
echo "${MEMS} GiB"
echo ""

if [ ${MEMS} -lt 1 ] ; then
  MEMS=1
fi

#set to H/W memory size
MEMSNOW=$(($MEMS*20))
MEMSSET=$(grep "pm.max_children =" /etc/php/8.3/fpm/pool.d/domjudge.conf | awk '{print $3}')

if [[ $MEMSSET -ne $MEMSNOW ]] ; then
  echo ""
  echo "H/W memory size changed!!"
  echo ""
  MEMSTRING=$(grep "pm.max_children =" /etc/php/8.3/fpm/pool.d/domjudge.conf)
  NEWSTRING="pm.max_children = ${MEMSNOW}      ; 20 per 1GiB memory(16GiB -> 320)"
  sudo sed -i "s:${MEMSTRING}:${NEWSTRING}:g" /etc/php/8.3/fpm/pool.d/domjudge.conf
  echo "pm.max_children value changed to ${MEMSNOW}"
  echo ""

  #Only the PHP-FPM pool config changed, so restart php-fpm to apply pm.max_children.
  #MariaDB config is untouched by this script, so MariaDB is NOT restarted here.
  echo "Restarting php..."
  sudo service php8.3-fpm restart
  echo ""

  #Reload the webserver so it re-establishes FastCGI connections to the new fpm workers.
  WEBSERVER=$(curl -is localhost | grep "Server" | awk '{print $2}')
  if [[ ${WEBSERVER} == Apache* ]] ; then
    echo "Reloading apache2..."
    sudo systemctl reload apache2
  fi
  if [[ ${WEBSERVER} == nginx* ]] ; then
    echo "Reloading nginx..."
    sudo systemctl reload nginx
  fi
else
  echo ""
  echo "pm.max_children already set to ${MEMSNOW}. No changes needed."
  echo ""
fi

echo ""
echo "php(fpm) autoscaling for DOMjudge server completed!"
echo ""

exit 0
