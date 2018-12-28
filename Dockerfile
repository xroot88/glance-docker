FROM python:2.7.12
MAINTAINER = Alexander Medvedev <xroot@yahoo.com>

EXPOSE 9292
ENV GLANCE_VERSION 17.0.0
ENV GLANCE_ADMIN_PASSWORD passw0rd
ENV GLANCE_DB_ROOT_PASSWD passw0rd
ENV GLANCE_DB_PASSWD passw0rd

LABEL version="$GLANCE_VERSION"
LABEL description="Openstack Glance Docker Image"

RUN apt-get -y update \
    && apt-get install -y libffi-dev python-dev libssl-dev mysql-client \
        nfs-common vim net-tools \
    && apt-get -y clean

RUN git clone -b ${GLANCE_VERSION} https://github.com/openstack/glance.git

WORKDIR /glance
RUN pip install -r requirements.txt && python setup.py install

RUN pip install osc-lib python-openstackclient PyMySql python-memcached
RUN mkdir /etc/glance
COPY ./etc/* /etc/glance/

COPY glance.sql /glance.sql
COPY bootstrap.sh /bootstrap.sh
#COPY ./glance.wsgi.conf /etc/apache2/sites-available/glance.conf

WORKDIR /root
CMD sh -x /bootstrap.sh
