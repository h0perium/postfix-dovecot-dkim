
#!/bin/bash

# configure postfix

function setup_conf_and_secret {
    postconf -e 'smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.trust.crt'
    postconf -e "relayhost = [$MTP_RELAY]:$MTP_PORT"
    postconf -e 'smtp_sasl_auth_enable = yes'
    postconf -e 'smtp_sasl_password_maps = hash:/etc/postfix/relay_passwd'
    postconf -e 'smtp_sasl_security_options = noanonymous'
    postconf -e 'smtp_tls_security_level = encrypt'
    postconf -e 'mynetworks = 127.0.0.0/8 172.16.0.0/12 172.17.0.0/16 10.0.0.0/8'

    echo "$MTP_RELAY   $MTP_USER:$MTP_PASS" > /etc/postfix/relay_passwd
    postmap /etc/postfix/relay_passwd
}

function setup_dovecot {
	sed -i "s/^\(mail_location\s*=\s*\).*\$/\1maildir\:\/var\/mail\/vhosts\/\%d\/\%n/" /etc/dovecot/conf.d/10-mail.conf

	groupadd -g 5000 vmail
	useradd -r -g vmail -u 5000 vmail -d /var/mail/vhosts -c "virtual mail user"
	chown -R vmail:vmail /var/mail/vhosts/

	sed -e '/disable_plaintext_auth/ s/^#*//' -i  /etc/dovecot/conf.d/10-auth.conf	#uncomment
	sed -i "s/^\(auth_mechanisms\s*=\s*\).*\$/\1plain login/" /etc/dovecot/conf.d/10-auth.conf	#replace
	sed -i "s/^\(disable_plaintext_auth\s*=\s*\).*\$/\1no/" /etc/dovecot/conf.d/10-auth.conf

	sed -e '/NOTE\:/ s/^#*/#/' -i  /etc/dovecot/conf.d/10-auth.conf #comment

	sed -e '/mbox_write_locks/ s/^#*//' -i  /etc/dovecot/conf.d/10-auth.conf  #uncomment
	sed -i "s/^\(mbox_write_locks\s*=\s*\).*\$/\1fcntl/" /etc/dovecot/conf.d/10-mail.conf      #replace

	sed -e '/\!include auth-system\.conf\.ext/ s/^#*/#/' -i  /etc/dovecot/conf.d/10-auth.conf #comment
	sed -e '/\!include auth-passwdfile\.conf\.ext/ s/^#*//' -i  /etc/dovecot/conf.d/10-auth.conf  #uncomment

	echo "$INIT_EMAIL:{PLAIN}$INIT_EMAIL_PASS::::::" > /etc/dovecot/dovecot-users

	EMAIL_USER=$(echo $INIT_EMAIL | cut -d'@' -f 1)
	echo "$INIT_EMAIL  $INIT_EMAIL" > /etc/postfix/valias
	echo "$MTP_HOST OK" > /etc/postfix/vdomains
	echo "$INIT_EMAIL  $MTP_HOST/$EMAIL_USER" > /etc/postfix/vusers


	postmap /etc/postfix/valias
	postmap /etc/postfix/vdomains
	postmap /etc/postfix/vusers

	sed -i "s/^\(ssl\s*=\s*\).*\$/\1yes/" /etc/dovecot/conf.d/10-ssl.conf #replace
	#sed -e '/ssl\s*=/ s/^#*/#/' -i  /etc/dovecot/conf.d/10-ssl.conf #comment

	sed -i "s/^\(ssl_cert\s*=\s*\).*\$/\1\<\/etc\/ssl\/certs\/ssl-cert-snakeoil\.pem/" /etc/dovecot/conf.d/10-ssl.conf
	sed -i "s/^\(ssl_key\s*=\s*\).*\$/\1\<\/etc\/ssl\/private\/ssl-cert-snakeoil\.key/" /etc/dovecot/conf.d/10-ssl.conf


	echo "virtual_transport = dovecot" >> /etc/postfix/main.cf
	echo "smtpd_sasl_type = dovecot" >> /etc/postfix/main.cf
	echo "smtpd_sasl_path = private/auth" >> /etc/postfix/main.cf
	echo "virtual_mailbox_base = /var/mail/vhosts" >> /etc/postfix/main.cf
	echo "virtual_mailbox_domains = hash:/etc/postfix/vdomains" >> /etc/postfix/main.cf
	echo "virtual_mailbox_maps = hash:/etc/postfix/vusers" >> /etc/postfix/main.cf
	echo "virtual_alias_maps = hash:/etc/postfix/valias" >> /etc/postfix/main.cf
	echo "virtual_uid_maps = static:5000" >> /etc/postfix/main.cf
	echo "virtual_gid_maps = static:5000" >> /etc/postfix/main.cf
	#echo "smtpd_tls_auth_only = no" >> /etc/postfix/main.cf
	
	chown -R vmail:dovecot /etc/dovecot
	chmod -R o-rwx /etc/dovecot 


	postfix reload
	service postfix restart
	service dovecot restart

	echo "initialized." > dovecot.txt
}

if [ -z "$MTP_INTERFACES" ]; then
  postconf -e "inet_interfaces = all"
else
  postconf -e "inet_interfaces = $MTP_INTERFACES"
fi

if [ -n "$MTP_PROTOCOLS" ]; then
  postconf -e "inet_protocols = $MTP_PROTOCOLS"
fi

if [ -n "$MTP_HOST" ]; then
  postconf -e "myhostname = $MTP_HOST"
  mkdir -p /var/mail/vhosts/$MTP_HOST
fi

if [ -n "$MTP_DESTINATION" ]; then
  postconf -e "mydestination = $MTP_DESTINATION"
fi

if [ -n "$MTP_BANNER" ]; then
  postconf -e "smtpd_banner = $MTP_BANNER"
fi

if [ -n "$MTP_RELAY_DOMAINS" ]; then
  postconf -e "relay_domains = $MTP_RELAY_DOMAINS"
fi

if [ -n "$MTP_MS_SIZE_LIMIT" ]; then
   postconf -e "message_size_limit = $MTP_MS_SIZE_LIMIT"
fi

if [ ! -z "$MTP_RELAY" -a ! -z "$MTP_PORT" -a ! -z "$MTP_USER" -a ! -z "$MTP_PASS" ]; then
    setup_conf_and_secret
else
    postconf -e 'mynetworks = 127.0.0.1/32 192.168.0.0/16 172.16.0.0/12 172.17.0.0/16 10.0.0.0/8'
fi

if [ ! -f /dovecot.txt ]; then
    setup_dovecot
else
    service dovecot restart
fi

if [ $(grep -c "^#header_checks" /etc/postfix/main.cf) -eq 1 ]; then
	sed -i 's/#header_checks/header_checks/' /etc/postfix/main.cf
        echo "/^Subject:/     WARN" >> /etc/postfix/header_checks
        postmap /etc/postfix/header_checks
fi

newaliases
