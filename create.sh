#!/bin/bash
# @author: Seb Dangerfield
# @author: Bazyli Brzoska
# http://www.sebdangerfield.me.uk/?p=513 
# Created:   11/08/2011
# Modified:   07/01/2012
# Modified:   27/11/2012
# Modified:   12/07/2013
 
# Modify the following to match your system
NGINX_CONFIG='/etc/nginx/sites-available'
NGINX_SITES_ENABLED='/etc/nginx/sites-enabled'
PHP_INI_DIR='/etc/php5/fpm/pool.d'
WEB_SERVER_GROUP='www-data'
NGINX_INIT='/etc/init.d/nginx'
PHP_FPM_INIT='/etc/init.d/php5-fpm'
RUN_DIR='/shared/run'
SCRIPTS_DIR='/root/nginx-chrooter-scripts'
# --------------END 
SED=`which sed`
CURRENT_DIR=`dirname $0`
 
if [ -z $1 ]; then
	echo "No domain name given"
	exit 1
fi
DOMAIN=$1
 
# check the domain is valid!
PATTERN="^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$";
if [[ "$DOMAIN" =~ $PATTERN ]]; then
	DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
	echo "Creating hosting for:" $DOMAIN
else
	echo "invalid domain name"
	exit 1
fi

#adduser $DOMAIN
# Create a new user!
echo "Please specify the username for this site?"
read USERNAME
#HOME_DIR=$USERNAME
adduser $USERNAME --conf=./config/adduser.chroot.conf
#DOMAIN_SAFE="${DOMAIN//./_}"
#adduser $DOMAIN_SAFE

# Now we need to copy the virtual host template
CONFIG=$NGINX_CONFIG/$USERNAME.$DOMAIN.conf
cp $CURRENT_DIR/templates/nginx.vhost.conf.template $CONFIG
$SED -i "s/@@HOSTNAME@@/$DOMAIN/g" $CONFIG
$SED -i "s/@@USERNAME@@/$USERNAME/g" $CONFIG

FPMCONF="$PHP_INI_DIR/$USERNAME.$DOMAIN.conf"

cp $CURRENT_DIR/templates/pool.conf.template $FPMCONF

$SED -i "s/@@USER@@/$USERNAME/g" $FPMCONF

#usermod -aG $USERNAME $WEB_SERVER_GROUP
#chmod g+rx /home/$HOME_DIR
chmod 600 $CONFIG

ln -s $CONFIG $NGINX_SITES_ENABLED/$USERNAME.$DOMAIN.conf

/bin/mknod -m 0666 /home/$USERNAME/dev/zero c 1 5
/bin/mknod -m 0666 /home/$USERNAME/dev/null c 1 3
/bin/mknod -m 0666 /home/$USERNAME/dev/random c 1 8
/bin/mknod -m 0444 /home/$USERNAME/dev/urandom c 1 9

# add /etc
cp -fv /etc/{host.conf,hostname,hosts,localtime,networks,nsswitch.conf,protocols,resolv.conf,services} /home/$USERNAME/etc
cp $CURRENT_DIR/templates/{passwd,group} /home/$USERNAME/etc
echo "$USERNAME:x:$(id -u $USERNAME):$(id -g $USERNAME):$DOMAIN,,,:/home/$USERNAME:/bin/false" >> /home/$USERNAME/etc/passwd
echo "$USERNAME:x:$(id -g $USERNAME):www-data,sftp" >> /home/$USERNAME/etc/group

chown $USERNAME:$USERNAME /home/$USERNAME/ -R

ln -s /usr/local/sbin /home/$USERNAME/sbin

usermod -G sftp $USERNAME
# usermod -s /bin/false $USERNAME
chown root:root /home/$USERNAME
chmod 0755 /home/$USERNAME
chown root:$USERNAME /home/$USERNAME/www

# all the binds
mount --bind /bin /home/$USERNAME/bin
mount --bind /lib /home/$USERNAME/lib
mount --bind /lib64 /home/$USERNAME/lib64
mount --bind /usr /home/$USERNAME/usr
mount --bind $RUN_DIR /home/$USERNAME/run

# create script
echo "#!/bin/bash
mount --bind /bin /home/$USERNAME/bin
mount --bind /lib /home/$USERNAME/lib
mount --bind /lib64 /home/$USERNAME/lib64
mount --bind /usr /home/$USERNAME/usr
mount --bind $RUN_DIR /home/$USERNAME/run" > $SCRIPTS_DIR/$DOMAIN.sh

chmod +x $SCRIPTS_DIR/$DOMAIN.sh

# for sftp
# http://www.techrepublic.com/blog/opensource/chroot-users-with-openssh-an-easier-way-to-confine-users-to-their-home-directories/229
 
$NGINX_INIT reload
$PHP_FPM_INIT restart
 
echo -e "\nSite Created for $DOMAIN with PHP support"
