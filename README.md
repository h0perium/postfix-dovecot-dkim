
![Dokcer compose Structure](https://github.com/h0perium/postfix-dovecot-dkim/blob/main/Mail%20Sever%20Postfix%20-%20dovcot%20-%20DKIM%20-%20roundcube.png)
### Fast and simple run :

```sh
docker run -d  --name mailserver \
       --restart always \
       -p 25:25 -p 993:993 -p 995:995 -p 587:587 -p 143:143 -p 110:110  \
       -e MTP_HOST=example.com \
       -e INIT_EMAIL=info@example.com \
       -e INIT_EMAIL_PASS=qwerty \
       -e MTP_DESTINATION='6a6a6586e71d, localhost.localdomain, localhost' \
       -v mailserver-storage:/var/mail \
       h0perium/postfix-dovecot-dkim
```

** you just need to replace the MTP_HOST  with your hostname and an initial email address and its password in INIT_EMAIL and INIT_EMAIL_PASS evn variables
, you can also connect this container to your own external docker network with your apache webserver and send emails without any username and password


## DKIM  And Other Configs

add dkim configuration for your domain so your email not get spammed. i have prepared an script inside the cotainer for you to generate all dkim configs and creating users or adding domains to your mailserver:

```sh
docker exec -it mailserver bash mailconfig.sh dkim example.com
```
after running this command the script will give you 3 dns records(spf,dkim,dmarc) which you need to set them in your domain dns zone file


to add a new email address:
```sh
docker exec -it mailserver bash mailconfig.sh adduser  admin@example.com
```

here there is help for more command that you can use :
```sh
==================================================
Examples : 

  bash mailconfig.sh  dkim  example.com

  bash mailconfig.sh  adduser  info@example.com  passwort

  bash mailconfig.sh  domainadd example.com

  bash mailconfig.sh  listusers

  bash mailconfig.sh  listdomains

  bash mailconfig.sh  deluser  info@example.com

  bash mailconfig.sh  deldomain  example.com
==================================================
```


## SSL Certificates

by default if no certificates set , it will use self-signed certificates . but you can replace and set your own verified certificates instead. just add the following lines and replace the path with your own certificate files
```sh
-v /path/to/your/publickey.crt:/etc/ssl/certs/ssl-cert-snakeoil.pem:ro \
-v /path/to/your/privatekey.key:/etc/ssl/private/ssl-cert-snakeoil.key:ro
```

## Roundcube Panel

if you need a graphical user interface to send and receive emails , we have also prepared a roundcube image to connect it to postfix-dovecot service. roundcube needs database which we use mysql here so you can run both services in a docker-compose file.

docker-compose.yml:
```sh
version: '3'

services:
  db:
    image: mysql:5.7
    restart: always
    environment:
      MYSQL_RANDOM_ROOT_PASSWORD: 1
      MYSQL_DATABASE: admin
      MYSQL_USER: admin
      MYSQL_PASSWORD: admin

  mailserver:
    image: h0perium/postfix-dovecot-dkim
    restart: always
    ports:
      - 25:25
      - 587:587
      - 993:993
      - 995:995
      - 143:143
      - 110:110
    volumes:
      - mailserver-storage:/var/mail

    environment:
      MTP_HOST: example.com
      INIT_EMAIL: info@example.com
      INIT_EMAIL_PASS: qwerty
      MTP_DESTINATION: '6a6a6586e71d, localhost.localdomain, localhost'



  roundcube:
    depends_on:
      - db
    image: h0perium/roundcube
  

    environment:
      ROUNDCUBEMAIL_DEFAULT_HOST: "mailserver"
      ROUNDCUBEMAIL_SMTP_SERVER:  "mailserver"
      ROUNDCUBEMAIL_SMTP_PORT: 25
      ROUNDCUBEMAIL_DB_TYPE: mysql
      ROUNDCUBEMAIL_DB_HOST: db
      ROUNDCUBEMAIL_DB_USER: admin
      ROUNDCUBEMAIL_DB_PASSWORD: admin
      ROUNDCUBEMAIL_DB_NAME: admin

    ports:
      - 6565:80
    restart: always

volumes:
   mailserver-storage:
```
you just need to replace the MTP_HOST  with your hostname and an initial email address and its password in INIT_EMAIL and INIT_EMAIL_PASS evn variables.
now you can access roundcube on port 6565 or any port you asigned in docker-compose file
and run it with command:

```sh
docker-compose up -d
```
it takes couple of minutes till roundcube get fully loaded.

you can add this microservice to your exisintg docker network like this:
```sh
version: '3'

services:
  db:
    image: mysql:5.7
    restart: always
    networks:
      - mynetwork

    environment:
      MYSQL_RANDOM_ROOT_PASSWORD: 1
      MYSQL_DATABASE: admin
      MYSQL_USER: admin
      MYSQL_PASSWORD: admin

  mailserver:
    image: h0perium/postfix-dovecot-dkim
    restart: always
    ports:
      - 25:25
      - 587:587
      - 993:993
      - 995:995
      - 143:143
      - 110:110
    volumes:
      - mailserver-storage:/var/mail
    networks:
      - mynetwork

    environment:
      MTP_HOST: example.com
      INIT_EMAIL: info@example.com
      INIT_EMAIL_PASS: qwerty
      MTP_DESTINATION: '6a6a6586e71d, localhost.localdomain, localhost'



  roundcube:
    depends_on:
      - db
    image: h0perium/roundcube
    networks:
      - mynetwork
    environment:
      ROUNDCUBEMAIL_DEFAULT_HOST: "mailserver"
      ROUNDCUBEMAIL_SMTP_SERVER:  "mailserver"
      ROUNDCUBEMAIL_SMTP_PORT: 25
      ROUNDCUBEMAIL_DB_TYPE: mysql
      ROUNDCUBEMAIL_DB_HOST: db
      ROUNDCUBEMAIL_DB_USER: admin
      ROUNDCUBEMAIL_DB_PASSWORD: admin
      ROUNDCUBEMAIL_DB_NAME: admin

    ports:
      - 6565:80
    restart: always

networks:
  mynetwork:
    external: true

volumes:
   mailserver-storage:

```

