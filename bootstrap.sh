#!/usr/bin/env bash

TLS_ENABLED=${TLS_ENABLED:-false}
if $TLS_ENABLED; then
    HTTP="https"
    CN=${CN:-$HOSTNAME}
    # generate pem and crt files
    mkdir -p /etc/apache2/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/apache2/ssl/apache.key -out /etc/apache2/ssl/apache.crt \
        -subj "/C=$CONUTRY/ST=$STATE/L=$LOCALITY/O=$ORG/OU=$ORG_UNIT/CN=$CN"
else
    HTTP="http"
fi

if [ -z $GLANCE_DB_HOST ]; then
    GLANCE_DB_HOST=localhost
    # start mysql locally
    service mysql restart

    #Docker OverlayFS compatibility: implements subset POSIX standards
    #https://docs.docker.com/storage/storagedriver/overlayfs-driver/
    #ALT: attach /var/lib/mysql as a volume to avoid timeout
    if [ $? ] ; then
        find /var/lib/mysql -type f -exec touch {} \;
        service mysql restart
    fi
else
    if [ -z $GLANCE_DB_ROOT_PASSWD_IF_REMOTED ]; then
        echo "Your'are using Remote MySQL Database; "
        echo "Please set GLANCE_DB_ROOT_PASSWD_IF_REMOTED when running a container."
        exit 1;
    else
        GLANCE_DB_ROOT_PASSWD=$GLANCE_DB_ROOT_PASSWD_IF_REMOTED
    fi
fi

addgroup --system glance >/dev/null || true
adduser --quiet --system --home /var/lib/glance \
        --no-create-home --ingroup glance --shell /bin/false \
        glance || true

if [ "$(id -gn glance)"  = "nogroup" ]
then
    usermod -g glance glance
fi

# create appropriate directories
mkdir -p /var/lib/glance/ /etc/glance/ /var/log/glance/

# change the permissions on key directories
chown glance:glance -R /var/lib/glance/ /etc/glance/ /var/log/glance/
chmod 0700 /var/lib/glance/ /var/log/glance/ /etc/glance/

# Keystone Database and user
sed -i 's|GLANCE_DB_PASSWD|'"$GLANCE_DB_PASSWD"'|g' /glance.sql
mysql -uroot -p$GLANCE_DB_ROOT_PASSWD -h $GLANCE_DB_HOST < /glance.sql

# Update glance-api.conf
for fname in glance-api.conf glance-registry.conf glance.conf
do
	sed -i "s/GLANCE_DB_PASSWORD/$GLANCE_DB_PASSWD/g" /etc/glance/$fname
	sed -i "s/GLANCE_DB_HOST/$GLANCE_DB_HOST/g" /etc/glance/$fname
	sed -i "s/GLANCE_ADMIN_PASSWORD/$GLANCE_ADMIN_PASSWORD/g" /etc/glance/$fname
	sed -i "s/KEYSTONE_HOST/$HTTP:\/\/$KEYSTONE_HOST/g" /etc/glance/$fname
	sed -i "s/MEMCACHED_HOST/$MEMCACHED_HOST/g" /etc/glance/$fname
done

# Write openrc to disk
cat > /root/openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${GLANCE_ADMIN_PASSWORD}
export OS_AUTH_URL=$HTTP://${KEYSTONE_HOST}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

. /root/openrc
openstack user create --domain default --password $GLANCE_DB_PASSWD glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public $HTTP://${KEYSTONE_HOST}:9292
openstack endpoint create --region RegionOne image internal $HTTP://${KEYSTONE_HOST}:9292
openstack endpoint create --region RegionOne image admin $HTTP://${KEYSTONE_HOST}:9292
# Populate glance database
su -s /bin/sh -c 'glance-manage db_sync' glance

# Configure Apache2
echo "ServerName $HOSTNAME" >> /etc/apache2/apache2.conf
a2enmod proxy_http

# if TLS is enabled
if $TLS_ENABLED; then
echo "export OS_CACERT=/etc/apache2/ssl/apache.crt" >> /root/openrc
a2enmod ssl
sed -i '/<VirtualHost/a \
    SSLEngine on \
    SSLCertificateFile /etc/apache2/ssl/apache.crt \
    SSLCertificateKeyFile /etc/apache2/ssl/apache.key \
    ' /etc/apache2/sites-available/glance.conf
fi

ln -s /etc/apache2/sites-available/uwsgi-glance-api.conf /etc/apache2/sites-enabled
apache2ctl start

sed -i '/plugins = python/d' /etc/glance/glance-api-uwsgi.ini
uwsgi --ini /etc/glance/glance-api-uwsgi.ini
