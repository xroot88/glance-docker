FROM python:2.7.12
MAINTAINER = Alexander Medvedev <xroot@yahoo.com>

EXPOSE 9292
ENV GLANCE_VERSION 17.0.0
ENV GLANCE_ADMIN_PASSWORD passw0rd
ENV GLANCE_DB_ROOT_PASSWD passw0rd
ENV GLANCE_DB_PASSWD passw0rd

LABEL version="$GLANCE_VERSION"
LABEL description="Openstack Glance Docker Image Supporting HTTP/HTTPS"

RUN apt-get -y update \
    && apt-get install -y apache2 libapache2-mod-wsgi git uwsgi-plugin-python vim net-tools\
        libffi-dev python-dev libssl-dev mysql-client libldap2-dev libsasl2-dev\
    && apt-get -y clean

RUN export DEBIAN_FRONTEND="noninteractive" \
    && echo "mysql-server mysql-server/root_password password $GLANCE_DB_ROOT_PASSWD" | debconf-set-selections \
    && echo "mysql-server mysql-server/root_password_again password $GLANCE_DB_ROOT_PASSWD" | debconf-set-selections \
    && apt-get -y update && apt-get install -y mysql-server && apt-get -y clean

RUN git clone -b ${GLANCE_VERSION} https://github.com/openstack/glance.git

WORKDIR /glance
RUN pip install -r requirements.txt \
    && PBR_VERSION=${GLANCE_VERSION} python setup.py install

RUN pip install osc-lib python-openstackclient PyMySql python-memcached \
    python-ldap ldappool uwsgi
RUN mkdir /etc/glance
RUN cp -r ./etc/* /etc/glance/

COPY ./etc/glance.conf /etc/glance/glance.conf
RUN cp ./httpd/glance-api-uwsgi.ini /etc/glance/glance-api-uwsgi.ini
RUN cp ./httpd/uwsgi-glance-api.conf /etc/apache2/sites-available/uwsgi-glance-api.conf
COPY glance.sql /glance.sql
COPY bootstrap.sh /bootstrap.sh
#COPY ./glance.wsgi.conf /etc/apache2/sites-available/glance.conf

WORKDIR /root
CMD sh -x /bootstrap.sh
