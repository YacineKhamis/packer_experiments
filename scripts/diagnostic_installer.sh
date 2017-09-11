#! /usr/bin/env bash

PATH_TO_DIAGNOSTIC='/var/lib/diagnostic'

# Variables
DB_NAME='diagnostic'
DB_HOST='localhost'
DBUSER_DIAGNOSTIC='diagnostic'
DBPASSWORD_DIAGNOSTIC="$(openssl rand -hex 32)"
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN="$(openssl rand -hex 32)"

echo -e "\033[93m###############################################################################"
echo -e "\033[93m#                             Diagnostic installer                            #"
echo -e "\033[93m#                                                                             #"
echo -e "\033[93m###############################################################################"

echo -e "\033[93mphp installation"
sudo apt-get -qq install php7.0 libapache2-mod-php7.0 php7.0-mcrypt php7.0-mysql php7.0-zip  php-xml > /dev/null 2>&1
echo -e "\033[32mphp installation done"

echo -e "\033[93mapache installation"
sudo apt-get -qq install apache2 > /dev/null 2>&1
sudo a2enmod rewrite > /dev/null 2>&1
echo -e "\033[32mapache installation done"

echo -e "\033[93mcomposer installation"
# TODO
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"
php composer.phar install
echo -e "\033[32mcomposer installation done"

echo -e "\033[93mmysql installation"
# TODO
# sql_init script should be put in scripts/ repository, which is not the case now
echo "mysql-server mysql-server/root_password password $DBPASSWORD_ADMIN" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DBPASSWORD_ADMIN" | sudo debconf-set-selections
sudo apt-get -qq install mysql-server
sudo mysql --defaults-file=/etc/mysql/debian.cnf -e "UPDATE mysql.user SET authentication_string=PASSWORD('$DBPASSWORD_ADMIN') WHERE User='root'"
sudo mysql --defaults-file=/etc/mysql/debian.cnf -e "flush privileges"
mysql -u root -p"$DBPASSWORD_ADMIN" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"$DBPASSWORD_ADMIN" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"$DBPASSWORD_ADMIN" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -u root -p"$DBPASSWORD_ADMIN" -e "FLUSH PRIVILEGES"
mysql -u root -p"$DBPASSWORD_ADMIN" -e "source ./scripts/db_initialization.sql"
mysql -u root -p"$DBPASSWORD_ADMIN" -e "CREATE USER 'diagnostic'@'localhost' IDENTIFIED BY '$DBPASSWORD_DIAGNOSTIC'"
mysql -u root -p"$DBPASSWORD_ADMIN" -e "GRANT SELECT, UPDATE, INSERT, DELETE, EXECUTE on diagnostic.* to 'diagnostic'@'localhost'"

echo -e "\033[32mmysql installation done"
