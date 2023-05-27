#!/bin/bash

HOSTNAME=""
USER=""
PASS=""

function setup_dkim {
     if [ ! -f /dkim.txt ]; then
	sed -e '/SOCKET=local:\$RUNDIR\/opendkim\.sock/ s/^#*/#/' -i  /etc/default/opendkim
	echo 'SOCKET="inet:8891@localhost"' >> /etc/default/opendkim

	echo 'SOCKET inet:8891@localhost' >> /etc/opendkim.conf

	postconf -e 'milter_protocol = 6'
	postconf -e 'milter_default_action = accept'
	postconf -e 'smtpd_milters = inet:localhost:8891'
	postconf -e 'non_smtpd_milters = inet:localhost:8891'

	echo "Canonicalization   relaxed/relaxed" >> /etc/opendkim.conf
	echo "Mode               sv" >> /etc/opendkim.conf
	echo "SubDomains         no" >> /etc/opendkim.conf
	
	echo "AutoRestart         yes" >> /etc/opendkim.conf
	echo "AutoRestartRate     10/1M" >> /etc/opendkim.conf
	echo "Background          yes" >> /etc/opendkim.conf
	echo "DNSTimeout          5" >> /etc/opendkim.conf
	echo "SignatureAlgorithm  rsa-sha256" >> /etc/opendkim.conf


	echo "Logwhy               yes" >> /etc/opendkim.conf

	echo "Nameservers 1.1.1.1" >> /etc/opendkim.conf
	sed -e '/TrustAnchorFile/ s/^#*/#/' -i  /etc/opendkim.conf

	echo "KeyTable           refile:/etc/opendkim/key.table" >> /etc/opendkim.conf
	echo "SigningTable       refile:/etc/opendkim/signing.table" >> /etc/opendkim.conf
	echo "ExternalIgnoreList  /etc/opendkim/trusted.hosts" >> /etc/opendkim.conf
	echo "InternalHosts       /etc/opendkim/trusted.hosts" >> /etc/opendkim.conf


#	echo "Domain $HOSTNAME" >> /etc/opendkim.conf
#	echo 'KeyFile /etc/postfix/dkim.key' >> /etc/opendkim.conf
	echo 'Selector dkim' >> /etc/opendkim.conf

	mkdir -p /etc/opendkim/keys
        echo "127.0.0.1" >> /etc/opendkim/trusted.hosts
        echo "localhost" >> /etc/opendkim/trusted.hosts
        echo "127.0.0.0/8" >> /etc/opendkim/trusted.hosts
        echo "172.16.0.0/12" >> /etc/opendkim/trusted.hosts
        echo "172.17.0.0/16" >> /etc/opendkim/trusted.hosts
        echo "10.0.0.0/8" >> /etc/opendkim/trusted.hosts

     fi

	mkdir -p /etc/opendkim/keys/$HOSTNAME
	chown -R opendkim:opendkim /etc/opendkim
	chmod go-rw /etc/opendkim/keys

	echo "*@$HOSTNAME    dkim._domainkey.$HOSTNAME" >>  /etc/opendkim/signing.table
	echo "*@*$HOSTNAME    dkim._domainkey.$HOSTNAME" >>  /etc/opendkim/signing.table

	echo "dkim._domainkey.$HOSTNAME     $HOSTNAME:dkim:/etc/opendkim/keys/$HOSTNAME/dkim.key" >> /etc/opendkim/key.table
	
	echo ".$HOSTNAME" >> /etc/opendkim/trusted.hosts

	opendkim-genkey -t -s dkim -d $HOSTNAME

	mv dkim.private /etc/opendkim/keys/$HOSTNAME/dkim.key
	chmod 660 /etc/opendkim/keys/$HOSTNAME/dkim.key
	chown root:opendkim /etc/opendkim/keys/$HOSTNAME/dkim.key

	echo "=======add these 3 records(spf,dkim,dmarc) to your domain dns zone file==========================="
	sed -i s/t=y\;// dkim.txt
	sed -i s/dkim._domainkey/dkim._domainkey.$HOSTNAME./ dkim.txt
	echo "$HOSTNAME.		3600	IN	TXT	\"v=spf1 a:$HOSTNAME mx ~all\""
	cat dkim.txt	
	echo "_dmarc.$HOSTNAME.	3600	IN	TXT	\"v=DMARC1; p=none; sp=none; rua=mailto:info@$HOSTNAME\""
	echo "==========================================================================================="


	service opendkim restart
	service postfix restart
}


function adduser {
	EMAIL_USER=$(echo $USER | cut -d'@' -f 1)
	HOSTNAME=$(echo $USER | cut -d'@' -f 2)

	echo "$USER:{PLAIN}$PASS::::::" >> /etc/dovecot/dovecot-users

	echo "$USER  $USER" >> /etc/postfix/valias
        echo "$USER  $HOSTNAME/$EMAIL_USER" >> /etc/postfix/vusers

	postmap /etc/postfix/valias
        postmap /etc/postfix/vusers

	service dovecot restart
        service postfix restart

}

function deluser {
	sed -i "\:^$USER.*:d" /etc/dovecot/dovecot-users
	sed -i "\:^$USER.*:d" /etc/postfix/valias
	sed -i "\:^$USER.*:d" /etc/postfix/vusers

        postmap /etc/postfix/valias
        postmap /etc/postfix/vusers

        service dovecot restart
        service postfix restart
}

function domainadd {
	echo "$HOSTNAME OK" >> /etc/postfix/vdomains
	postmap /etc/postfix/vdomains

	service dovecot restart
        service postfix restart
}


function deldomain {
	sed -i "\:^$HOSTNAME.*:d" /etc/postfix/vdomains
	postmap /etc/postfix/vdomains

        service dovecot restart
        service postfix restart
}

case $1 in
        "dkim" )
          HOSTNAME=$2
          setup_dkim
          ;;
	"dkimtest" )
	  HOSTNAME=$2
	  opendkim-testkey -d $HOSTNAME -s dkim -vvv
	  ;;
	"adduser" )
	  USER=$2
	  PASS=$3
          adduser
          ;;
	"domainadd" )
	  HOSTNAME=$2
          domainadd
          ;;
	"listusers" )
	  cat /etc/dovecot/dovecot-users
	 ;;
	"listdomains" )
	  cat /etc/postfix/vdomains
	 ;;
	"deluser" )
	  USER=$2
	  deluser
	  ;;
	"deldomain")
	  HOSTNAME=$2
	  deldomain
	  ;;
	*)
	echo "=================================================="
	echo "Examples : "
	echo ""
	echo "  bash mailconfig.sh  dkim  example.com"
	echo ""
	echo "  bash mailconfig.sh  adduser  info@example.com  passwort"
	echo ""
	echo "  bash mailconfig.sh  domainadd example.com"	
	echo ""
	echo "  bash mailconfig.sh  listusers"
	echo ""
	echo "  bash mailconfig.sh  listdomains"
	echo ""
	echo "  bash mailconfig.sh  deluser  info@example.com"
	echo ""
	echo "  bash mailconfig.sh  deldomain  example.com"
	echo "=================================================="
	;;
# ... and so on
esac

