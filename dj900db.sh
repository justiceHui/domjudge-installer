#!/bin/bash

#2025.10 Made by melongist(melongist@gmail.com) for CS teachers

#origin
#https://www.domjudge.org/
#https://github.com/DOMjudge/domjudge


#It is recommended to separate domserver, judgehost, and database.
#https://www.domjudge.org/docs/manual/9.0/install-domserver.html
#This script installs MariaDB on a dedicated machine and prepares it
#to accept DOMjudge connections from a separate domserver machine.

#This installation script only works on Ubuntu 24.04 LTS!!
#2025.10 This scripts works for PC, AWS(Amazon Web Server), GCE(Google Compute Engine)

#DOMjudge9.0.0 stable(2025.10.05) + Ubuntu 24.04.03 LTS + MariaDB


#DOMjudge dedicated database installation script


#terminal commands to install dedicated DOMjudge database server
#wget https://raw.githubusercontent.com/justiceHui/domjudge-installer/main/dj900db.sh
#bash dj900db.sh

#------

DJVER="9.0.0 stable (2025.10.05)"
THIS="dj900db.sh"
README="readme.txt"


if [[ $SUDO_USER ]] ; then
  echo ""
  echo "Just use 'bash ${THIS}'"
  exit 1
fi


if [ -d /opt/domjudge/domserver ] ; then
  echo ""
  echo "DOMjudge server is already installed at this computer!!"
  echo ""
  echo "Use a separate computer for the dedicated database!!!"
  echo ""
  exit 1
fi


if [ -d /opt/domjudge/judgehost ] ; then
  echo ""
  echo "DOMjudge judgehost is already installed at this computer!!"
  echo ""
  echo "Use a separate computer for the dedicated database!!!"
  echo ""
  exit 1
fi


OSVER=$(grep "Ubuntu" /etc/issue|head -1|awk  '{print $2}')
if [ ${OSVER:0:5} != "24.04" ] ; then
  echo ""
  echo "This installation script only works on Ubuntu 24.04 LTS!!"
  echo ""
  exit 1
fi


#Ask for the domserver's IP. Only this IP will be allowed to connect to MariaDB.
DOMSERVERIP="o"
INPUTS="x"
while [ ${DOMSERVERIP} != ${INPUTS} ]; do
  echo ""
  echo "Input the DOMjudge domserver's IP address."
  echo "This DB machine will only accept MariaDB connections from this IP."
  echo "Examples:"
  echo "10.0.0.5"
  echo "192.168.1.10"
  echo ""
  echo -n "Input  domserver IP : "
  read DOMSERVERIP
  echo -n "Repeat domserver IP : "
  read INPUTS
done


cd


#time synchronization
echo ""
sudo timedatectl
echo ""

#set timezone
NEWTIMEZONE=$(tzselect)
sudo timedatectl set-timezone ${NEWTIMEZONE}
echo ""


#needrestart auto check for Ubuntu 24.04
#/etc/needrestart/needrestart.conf
if [ ! -e /etc/needrestart/needrestart.conf ] ; then
  sudo apt install needrestart -y
fi
sudo sed -i "s:#\$nrconf{restart} = 'i':\$nrconf{restart} = 'a':" /etc/needrestart/needrestart.conf
sudo sed -i "s:#\$nrconf{kernelhints} = -1:\$nrconf{kernelhints} = 0:" /etc/needrestart/needrestart.conf


sudo apt update
sudo apt upgrade -y

sudo apt install curl -y
sudo apt reinstall systemd-timesyncd -y #for ubuntu 24.04 ntp
sudo apt install ntp -y
sudo systemctl restart ntp
sudo systemctl status ntp




#DBMS
sudo apt install mariadb-server -y
#You must input mariaDB's root account password! <---- #1
sudo mysql_secure_installation
#For DOMjudge configuration check
#https://mariadb.com/kb/en/server-system-variables/#max_connections
#MariaDB Max connections to 8192
sudo sed -i "s/\#max_connections        = 100/max_connections        = 8192/" /etc/mysql/mariadb.conf.d/50-server.cnf
sudo sed -i "s/\[mysqld\]/\[mysqld\]\ninnodb_log_file_size=512M\nmax_allowed_packet=512M/" /etc/mysql/mariadb.conf.d/50-server.cnf
#Bind to all interfaces so the domserver can connect over the network.
#Rewrite any existing bind-address line, whether commented (#bind-address ...) or not.
sudo sed -i "s/^#\?bind-address.*/bind-address            = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
#If no bind-address line exists at all, append one under [mysqld] so the change is not silently skipped.
if ! grep -qE "^bind-address" /etc/mysql/mariadb.conf.d/50-server.cnf ; then
  sudo sed -i "s/\[mysqld\]/\[mysqld\]\nbind-address            = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
fi

sudo systemctl restart mariadb




#Create a remote-accessible root user so dj900server.sh on the domserver
#can run 'dj_setup_database install' against this DB machine.
#mysql_secure_installation disallowed remote root login above, so we
#re-create it scoped to the domserver IP only.
echo ""
echo "Set the same MariaDB root password you entered in mysql_secure_installation."
echo "It will be granted to 'root'@'${DOMSERVERIP}' so dj900server.sh on the"
echo "domserver can connect and run 'dj_setup_database install'."
echo ""
ROOTPW=""
ROOTPWREP=""
while [ -z "${ROOTPW}" ] || [ "${ROOTPW}" != "${ROOTPWREP}" ]; do
  echo -n "Input  MariaDB root password : "
  read -s ROOTPW
  echo ""
  echo -n "Repeat MariaDB root password : "
  read -s ROOTPWREP
  echo ""
  if [ "${ROOTPW}" != "${ROOTPWREP}" ] ; then
    echo "Passwords do not match. Try again."
  fi
done

sudo mariadb -u root <<EOF
CREATE USER IF NOT EXISTS 'root'@'${DOMSERVERIP}' IDENTIFIED BY '${ROOTPW}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'${DOMSERVERIP}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF




#Firewall: open 3306/tcp only from the domserver IP
sudo ufw allow from ${DOMSERVERIP} to any port 3306 proto tcp




sudo apt autoremove -y




DBPRIVADDR=$(hostname -i)
DBPUBADDR=$(curl -s ifconfig.me)

echo "" | tee -a ~/${README}
echo "DOMjudge dedicated DB(MariaDB) ${DJVER} installed!!" | tee -a ~/${README}
echo "" | tee -a ~/${README}

echo "Use these values when running dj900server.sh (external DB mode) on the domserver:" | tee -a ~/${README}
echo "------" | tee -a ~/${README}
echo "DB host (private IP) : ${DBPRIVADDR}" | tee -a ~/${README}
echo "DB host (public  IP) : ${DBPUBADDR}" | tee -a ~/${README}
echo "DB user              : root" | tee -a ~/${README}
echo "DB password          : (the one you just entered above)" | tee -a ~/${README}
echo "Allowed source IP    : ${DOMSERVERIP}" | tee -a ~/${README}
echo "" | tee -a ~/${README}
echo "" | tee -a ~/${README}

echo "To revoke the remote root user later:" | tee -a ~/${README}
echo "------" | tee -a ~/${README}
echo "sudo mariadb -u root -e \"DROP USER 'root'@'${DOMSERVERIP}'; FLUSH PRIVILEGES;\"" | tee -a ~/${README}
echo "" | tee -a ~/${README}
echo "" | tee -a ~/${README}


echo ""
echo "DOMjudge dedicated DB ${DJVER} installation completed!!"


echo ""
echo "System will reboot in 10 seconds!"
echo ""
COUNT=10
while [ $COUNT -ge 0 ]
do
  echo $COUNT
  ((COUNT--))
  sleep 1
done
echo "Rebooted!" | tee -a ~/${README}
echo "" | tee -a ~/${README}
echo "" | tee -a ~/${README}


chmod 660 ~/${README}
echo "Saved as ${README}"


sleep 3
sudo reboot
