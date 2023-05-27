FROM ubuntu:18.04

MAINTAINER "Saeid Salehi" <hostage.scape2010@gmail.com>

EXPOSE 25

EXPOSE 993
EXPOSE 995
EXPOSE 143
EXPOSE 110
EXPOSE 587

RUN echo 'postfix postfix/main_mailer_type string "Internet Site"' | debconf-set-selections
#RUN echo 'postfix postfix/mailname string "uplooder.net"' | debconf-set-selections

RUN echo 'tzdata tzdata/Areas select Europe' | debconf-set-selections
RUN echo 'tzdata tzdata/Zones/Europe select Berlin' | debconf-set-selections

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

VOLUME ["/var/log", "/var/spool/postfix"]

RUN apt update && \
    apt install -y build-essential && \
    apt install -y --assume-yes python3 postfix sasl2-bin bsd-mailx && \
    apt install -y opendkim opendkim-tools && \
    apt install -y python3-pip nano mlocate

RUN python3 -m pip install PyYAML==5.2 && \
    pip3 install chaperone

RUN apt update && \
    apt install -y net-tools & \
    apt install -y dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd


RUN mkdir -p /etc/chaperone.d
COPY chaperone.conf /etc/chaperone.d/chaperone.conf

COPY 10-master.conf /etc/dovecot/conf.d/10-master.conf
COPY auth-passwdfile.conf.ext /etc/dovecot/conf.d/auth-passwdfile.conf.ext

COPY master.cf /etc/postfix/master.cf

COPY docker-setup.sh /docker-setup.sh
RUN chmod +x /docker-setup.sh

COPY mailconfig.sh /mailconfig.sh
RUN chmod +x /mailconfig.sh


ENTRYPOINT ["/usr/local/bin/chaperone"]
