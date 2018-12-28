# Glance Docker

This repo is used to host a bunldle to create a docker container (based on
`Python 2.7.12`) running Glance.

Glance is an OpenStack service that provides image services that include
discovering, registering, and retrieving virtual machine (VM) images.
Glance has a RESTful API that allows querying of VM image metadata as well
as retrieval of the actual image.
[OpenStack’s Image Service API](http://specs.openstack.org/openstack/glance-specs/).


# What can this docker image do ?

* Running Glance with **http** (default) or
    **https** (by passing `-e TLS_ENABLED=true`,
    see more in [Environment Variables Explanations](https://github.com/xroot88/glance-docker#environment-variables-explanations)) enabled;
* Uses the **Apache Web Server** with `mod_wsgi` to serve Identity service
    requests on port `5000` and `35357`;
* Supports remote mysql database;
* Utilizes **Memcached** from the Glance container;
* Customizes/Builds your own Glance docker image by editing the value
    of `GLANCE_VERSION` in `Dockerfile`;


# How to get the image ?

* Build your own Glance version using Dockerfile

    You can find more [Glance release version](https://github.com/openstack/glance/releases#).

    ```sh
    $ git clone https://github.com/xroot88/glance-docker
    $ cd glance-docker
    $ # edit the value of GLANCE_VERSION to your favorite Glance
    $ # release version
    $ vim Dockerfile
    $ docker build -t glance:your_version ./
    ```

    **WARNING: Pay attention to the dependencies. You may need to specify
    dependency versions explicitly.**

# How to run the container

## Quick Start

Just run

```
$ docker run -d -p 9292:9292 --name my_glance glance:version
```

Now you can access <http://localhost:9292>.

## Login into Glance container

After the container is up,

```sh
$ docker exec -it my_glance bash
$ # Inside the container
root@7fc2faf81baf /root # source openrc
root@7fc2faf81baf /root # openstack user list
+----------------------------------+-------+
| ID                               | Name  |
+----------------------------------+-------+
| 8bc7a64511df42149460423e363b5c95 | admin |
+----------------------------------+-------+
```

**Note**: *You can also copy the `/root/openrc` to your other servers. After replacing
`OS_AUTH_URL` to the corresponding url, you can access the glance service
from other servers after sourcing it.*

## Environment Variables Explanations

| Environment Variables              | Default Value | Editable when starting a container                      | Description                                                                                      |
|------------------------------------|---------------|---------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| GLANCE_VERSION                     | 17.0.0        | False. Built in Dockerfile unless rebuilding the image. | The release version of Glance. You can find more at https://github.com/openstack/glance/tags.    |
| GLANCE_ADMIN_PASSWORD              | passw0rd      | True                                                    | The Glance   admin user password;                                                                |
| GLANCE_DB_ROOT_PASSWD              | passw0rd      | False. Built in Dockerfile unless rebuilding the image. | Glance MySQL (default localhost) database root user password;                                    |
| GLANCE_DB_PASSWD                   | passw0rd      | True                                                    | Glance MySQL (default localhost) database glance user password;                                  |
| TLS_ENABLED                        | false         | True                                                    | Whether to enable tls/https;                                                                     |
| GLANCE_DB_HOST                     |               | True                                                    | MySQL remote database host; Combined with GLANCE_DB_ROOT_PASSWD_IF_REMOTED                       |
| GLANCE_DB_ROOT_PASSWD_IF_REMOTED   |               | True                                                    | MySQL remote database root user password; Combined with GLANCE_DB_HOST                           |
| MEMCACHED_HOST                     |               | True                                                    | Hostname of the memcached service (typically the keystone service)                               |
| KEYSTONE_HOST                      |               | True                                                    | Hostname of the keystone service                                                                 |

## CSR (Certificate Signing Request) Environment Variables

If you've enabled `TLS_ENABLED` (with `-e TLS_ENABLED=true`), below environment
variables have to be noticed. You can just ignore them if you
don't want to make any further customizations.

| Environment Name | Default Value | Meaning             | Example         |
|------------------|---------------|---------------------|-----------------|
| CONUTRY          | NULL          | Country             | GB              |
| STATE            | NULL          | State               | London          |
| LOCALITY         | NULL          | Location            | London          |
| ORG              | NULL          | Organization        | Global Security |
| ORG_UNIT         | NULL          | Organizational Unit | IT Department   |
| CN               | The Hostname  | Common Name         | example.com     |

**Note**: *Be aware of `CN` (the default value is `$hostname`). You'd better
not change it to other value.*


## Example 1: Running with TLS enabled

```sh
$ docker run -d -p 5000:5000 -p 35357:35357 -e TLS_ENABLED=true \
    -h myglance.com --name my_glance_tls glance:17.0.0
```

## Example 2: Running with remote MySQL database

```sh
$ docker run -d -p 9292:9292 -e GLANCE_DB_HOST=192.168.100.202 \
    -e GLANCE_DB_ROOT_PASSWD_IF_REMOTED=your_password \
    -h myglance.com --name my_glance_db glance:17.0.0
```

## Example 3: Accessing the Apache Certificate File

```sh
$ mkdir -p ./apache/
$ docker run -d -p 9292:9292 -v `pwd`/apache/:/etc/apache2 \
    -h myglance.com --name my_glance_ca glance:17.0.0
```

## Example 4: Customize your Glance configuration

```sh
$ git clone https://github.com/dixudx/glance-docker.git
$ cd glance-docker
# then modify all related configurations in folder ./etc
# especially ./etc/glance.conf
$ docker run -d -p 9292:9292 -v `pwd`/etc/:/etc/glance/ \
    -h myglance.com --name my_glance_ca glance:17.0.0
```

You can copy `/root/openrc` in your container to your host server,
and replace `OS_CACERT` to this `$pwd/apache/ssl/apache.crt`
(replace `$pwd` with your real directory path).
So that you access the glance services using openstack python client
( `pip install python-openstackclient` ) from outer of the the container.

**Note**: *On your host server,
you may also need to add `myglance.com` to `/etc/hosts`.*


# Reference

* [Glance, the OpenStack Image Service](http://docs.openstack.org/developer/glance/)
* [Installing Glance](http://docs.openstack.org/developer/glance/installing.html)

# alexm notes:

```sh
$ sudo docker build -t glance:17.0.0 ./
$ sudo docker run -it -p 9292:9292 -e GLANCE_DB_HOST=192.168.2.6 -e GLANCE_DB_ROOT_PASSWD_IF_REMOTED=cisco123 -e KEYSTONE_HOST=keystone.ghettocoders.com -e MEMCACHED_HOST=keystone.ghettocoders.com --link keystone01:keystone.ghettocoders.com --name glance01 glance:17.0.0
$ sudo docker exec -it glance01 bash
container-id# source /root/openrc
container-id# openstack user list
container-id# openstack token issue
```
