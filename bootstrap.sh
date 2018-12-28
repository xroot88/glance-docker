#!/usr/bin/env bash

HTTP="http"
GLANCE_DB_ROOT_PASSWD=$GLANCE_DB_ROOT_PASSWD_IF_REMOTED

# create appropriate directories
mkdir -p /var/lib/glance/images /etc/glance/ /var/log/glance/

addgroup --system glance >/dev/null || true
adduser --quiet --system --home /var/lib/glance \
        --no-create-home --ingroup glance --shell /bin/false \
        glance || true

if [ "$(id -gn glance)"  = "nogroup" ]
then
    usermod -g glance glance
fi

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
openstack endpoint create --region RegionOne image public $HTTP://${HOSTNAME}:9292
openstack endpoint create --region RegionOne image internal $HTTP://${HOSTNAME}:9292
openstack endpoint create --region RegionOne image admin $HTTP://${HOSTNAME}:9292

ls -l /etc/glance
# Populate glance database
su -s /bin/sh -c 'glance-manage db_sync' glance

# setup NFS if requested
if [ -z $IMAGE_STORE_NFS_MOUNTPOINT ]; then
        echo 'No NFS mount point specified. Using local storage for images'
else
	options='-o nolock'
	if [ -z $NFS_USERNAME ]; then
		echo 'No username specified for NFS mount. Assuming local root'
	else
		options+=" -o username=$NFS_USERNAME,password=$NFS_PASSWORD "
	fi
	mount $options $IMAGE_STORE_NFS_MOUNTPOINT /var/lib/glance/images
fi

#/usr/local/bin/glance-control api start glance-api.conf
/usr/local/bin/glance-control registry start /etc/glance/glance-registry.conf
/usr/local/bin/glance-api --config-file /etc/glance/glance-api.conf --debug
