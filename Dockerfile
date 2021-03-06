#
#
FROM phusion/baseimage:0.10.2

MAINTAINER Michael Fong <mcfong.open@gmail.com>
########################################################
# Make sure the basic folder is setup, with permission nukes
RUN mkdir /workspace && chmod -R 0777 /workspace ;
	
WORKDIR /workspace

ENV HOME /workspace

#######################################################
# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

#######################################################
# InfluxDB PreRequisite

RUN apt-get update && apt-get install -y \
      wget && \
      rm -rf /usr/share/doc/* && \
      rm -rf /usr/share/info/* && \
      rm -rf /tmp/* && \
      rm -rf /var/tmp/*

#######################################################
# InfluxDB installation

RUN set -ex && \
    for key in \
        05CE15085FC09D18E99EFB22684A14CF2582E0C5 ; \
    do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
        gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
        gpg --keyserver keyserver.pgp.com --recv-keys "$key" ; \
    done

ARG INFLUXDB_VERSION=1.6.0

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH='amd64';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armhf';; \
      armel) ARCH='armel';; \
      *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
    esac && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_${ARCH}.deb.asc && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    gpg --batch --verify influxdb_${INFLUXDB_VERSION}_${ARCH}.deb.asc influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    dpkg -i influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    rm -f influxdb_${INFLUXDB_VERSION}_${ARCH}.deb*
COPY influxdb.conf /etc/influxdb/influxdb.conf

COPY init-influxdb.sh /workspace/init-influxdb.sh
RUN chmod +x /workspace/init-influxdb.sh

EXPOSE 8086

VOLUME /var/lib/influxdb

ADD types.db /usr/share/collectd/

########################################################
# Add InfluxDB shell daemon
RUN mkdir /etc/service/influxdb
COPY influxdb-docker-entrypoint.sh  /etc/service/influxdb/run
RUN chmod +x /etc/service/influxdb/run

########################################################
# SSH Setting
#
# Enable the SSH server from base image

RUN rm -f /etc/service/sshd/down

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot.
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

# Enabling the insecure key permanently for demo purposes
RUN /usr/sbin/enable_insecure_key

RUN echo 'root:docker' | chpasswd

# XXX: Allow root login 
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

########################################################
# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
