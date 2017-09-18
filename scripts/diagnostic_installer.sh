#! /usr/bin/env bash

PATH_TO_DIAGNOSTIC='/var/www/diagnostic'
GITHUB_LINK='https://[accountName]:[Password]@github.com/BenjaminJoly/diagnostic.git'

# Variables
HOSTNAME='diagnostic'
DB_NAME='diagnostic'
DB_HOST='localhost'
DBUSER_DIAGNOSTIC='diagnostic'
DBPASSWORD_DIAGNOSTIC="$(openssl rand -hex 32)"
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN="$(openssl rand -hex 32)"

echo "\033[93m###############################################################################\\033[0m"
echo "\033[93m#                             Diagnostic installer                            #\\033[0m"
echo "\033[93m#                                                                             #\\033[0m"
echo "\033[93m###############################################################################\\033[0m"

echo "\033[93mphp installation\\033[0m"
sudo apt-get -qq install php7.0 libapache2-mod-php7.0 php7.0-mcrypt php7.0-mysql php7.0-zip  php-xml > /dev/null 2>&1
echo "\033[32mphp installation done\\033[0m"

echo "\033[93mcurl installation\\033[0m"
sudo apt-get -qq install curl > /dev/null 2>&1
echo "\033[32mcurl installation done\\033[0m"

echo "\033[93mapache installation\\033[0m"
sudo apt-get -qq install apache2 > /dev/null 2>&1
sudo a2enmod rewrite > /dev/null 2>&1
echo "\033[32mapache installation done\\033[0m"

echo "\033[93mgetting diagnostic sources\\033[0m"
sudo mkdir -p $PATH_TO_DIAGNOSTIC
cd $PATH_TO_DIAGNOSTIC
sudo chown www-data:www-data $PATH_TO_DIAGNOSTIC
#git install
sudo apt-get install -y git > /dev/null 2>&1
sudo -u www-data git clone --config core.filemode=false $GITHUB_LINK . > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: unable to clone the Diagnostic repository"
    exit 1;
fi
echo "\033[32mdiagnostic sources copied\\033[0m"

echo "\033[93mcomposer installation\\033[0m"
# TODO

curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "\033[31mERROR: unable to install composer\\033[0m"
    exit 1;
fi
composer self-update
composer install -o
echo "\033[32mcomposer installation done\\033[0m"
#php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
#php composer-setup.php
#php -r "unlink('composer-setup.php');"
#php composer.phar install
# sql_init script should be put in scripts/ repository, which is not the case now
echo "\033[93mmysql installation\\033[0m"
# TODO
echo "mysql-server mysql-server/root_password password $DBPASSWORD_ADMIN" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DBPASSWORD_ADMIN" | sudo debconf-set-selections
sudo apt-get -qq install mysql-server > /dev/null 2>&1
echo "\033[32mmysql installation done\\033[0m"
echo "\033[93minitialisation database\\033[0m"
sudo mysql --defaults-file=/etc/mysql/debian.cnf -e "UPDATE mysql.user SET authentication_string=PASSWORD('$DBPASSWORD_ADMIN') WHERE User='root'"
sudo mysql --defaults-file=/etc/mysql/debian.cnf -e "flush privileges"
mysql -u root -p"$DBPASSWORD_ADMIN" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')" > /dev/null 2>&1
mysql -u root -p"$DBPASSWORD_ADMIN" -e "DELETE FROM mysql.user WHERE User=''" > /dev/null 2>&1
mysql -u root -p"$DBPASSWORD_ADMIN" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'" > /dev/null 2>&1
mysql -u root -p"$DBPASSWORD_ADMIN" -e "FLUSH PRIVILEGES" > /dev/null 2>&1
mysql -u root -p"$DBPASSWORD_ADMIN" -e "source ./scripts/db_initialization.sql" > /dev/null 2>&1
mysql -u root -p"$DBPASSWORD_ADMIN" -e "CREATE USER 'diagnostic'@'localhost' IDENTIFIED BY '$DBPASSWORD_DIAGNOSTIC'" > /dev/null 2>&1
mysql -u root -p"$DBPASSWORD_ADMIN" -e "GRANT SELECT, UPDATE, INSERT, DELETE, EXECUTE on diagnostic.* to 'diagnostic'@'localhost'" > /dev/null 2>&1
echo "\033[32mdatabase ready\\033[0m"



#declare -A global_configurationArray
#global_configurationArray["%%DB_NAME%%"]=$DB_NAME
#global_configurationArray["%%DB_HOST%%"]=$DB_HOST

#declare -A local_configurationArray
#local_configurationArray["%%DB_USER%%"]=$DBUSER_DIAGNOSTIC
#local_configurationArray["%%DB_PASSWORD%%"]=$DBPASSWORD_DIAGNOSTIC

cp $PATH_TO_DIAGNOSTIC/config/autoload/global.php.dist $PATH_TO_DIAGNOSTIC/config/autoload/global.php
cat > $PATH_TO_DIAGNOSTIC/config/autoload/global.php <<EOF
return [
    'db' => [
        'driver'         => 'Pdo',
        'dsn'            => 'mysql:dbname=$DB_NAME;host=$DB_HOST',
        'driver_options' => [
            PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES \'UTF8\''
        ],
    ],
    'service_manager' => [
        'factories' => [
            'Zend\Db\Adapter\Adapter' => 'Zend\Db\Adapter\AdapterServiceFactory',
        ],
    ],
];
EOF

#global_configure() {
    # Loop the global config array
#    for i in "${!global_configurationArray[@]}"
#    do
#        search=$i
#        replace=${global_configurationArray[$i]}
#        sudo sed -i "s/${search}/${replace}/g" $PATH_TO_DIAGNOSTIC/config/autoload/global.php
#    done
#}
#global_configure

cp $PATH_TO_DIAGNOSTIC/config/autoload/local.php.dist $PATH_TO_DIAGNOSTIC/config/autoload/local.php
cat > $PATH_TO_DIAGNOSTIC/config/autoload/global.php <<EOF
return [
    'db' => [
        'username' => '$DBUSER_DIAGNOSTIC',
        'password' => '$DBPASSWORD_DIAGNOSTIC',
    ],
    'encryption_key' => '*****',
    'mail' => 'info@cases.lu',
    'mail_name' => 'Cases',
    'domain' => 'diagnostic.cases.lu',
];
EOF


#local_configure() {
    # Loop the local config array
#    for i in "${!local_configurationArray[@]}"
#    do
#        search=$i
#        replace=${local_configurationArray[$i]}
#        sudo sed -i "s/${search}/${replace}/g" $PATH_TO_DIAGNOSTIC/config/autoload/local.php
#    done
#}
#local_configure


echo "\033[93mvirtual host configuration\\033[0m"
sudo cat > /etc/apache2/sites-enabled/000-default.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot $PATH_TO_DIAGNOSTIC/public
    <Directory $PATH_TO_DIAGNOSTIC/public>
        DirectoryIndex index.php
        AllowOverride All
        Order allow,deny
        Allow from all
        <IfModule mod_authz_core.c>
        Require all granted
        </IfModule>
    </Directory>
</VirtualHost>
EOF
sudo service apache2 restart > /dev/null 2>&1
echo "\033[32mvirtual host configuration done\\033[0m"

key="%%LANG%%"
replace="en_EN"
sudo sed -i "s/${key}/${replace}/g" $PATH_TO_DIAGNOSTIC/module/Diagnostic/config/module.config.php

sudo chown -R www-data $PATH_TO_DIAGNOSTIC
sudo chgrp -R www-data $PATH_TO_DIAGNOSTIC
sudo chmod -R 700 $PATH_TO_DIAGNOSTIC

#network configuration
echo "\033[93mnetwork configuration\\033[0m"
sudo apt-get -qq install net-tools > /dev/null 2>&1
sudo cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp0s8
iface enp0s8 inet dhcp
EOF
sudo ifconfig enp0s8 up
sudo ifconfig enp0s3 down
ip_address=ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
echo "\033[32mnetworkconfiguration done\\033[0m"

echo "\033[93m###############################################################################\\033[0m"
echo "\033[93m#                                  FINISHED                                   #\\033[0m"
echo "\033[93m#            You can now access the application by typing in                  #\\033[0m"
echo "\033[93m#            \033[33mhttp://$ip_address                                                \033[93m#\\033[0m"
echo "\033[93m#                        in your favorite browser.                            #\\033[0m"
echo "\033[93m#                   \033[92mLogin : diagnostic@cases.lu                               \033[93m#\\033[0m"
echo "\033[93m#                   \033[92mPassword : Diagnostic1!                                   \033[93m#\\033[0m"
echo "\033[93m#                                                                             #\\033[0m"
echo "\033[93m#           Note following credentials, it wont be given twice                #\\033[0m"
echo "\033[93m#           \033[92mSSH login: diagnostic:diagnostic                                  #\\033[0m"
echo "\033[93m# \033[92mMysql root login: $DBUSER_ADMIN:$DBPASSWORD_ADMIN\\033[0m"
echo "\033[93m# \033[92mMysql diagnostic login: $DBUSER_DIAGNOSTIC:$DBPASSWORD_DIAGNOSTIC\\033[0m"
echo "\033[93m#                                                                             #\\033[0m"
echo "\033[93m###############################################################################\\033[0m"
