#!/bin/bash

if [ ! -z "$NSCA_PASSWORD" ]
then
  sed -r -i "s/^#?password=.*/password=$NSCA_PASSWORD/" /etc/nsca.cfg
fi

if [ -z "$NSCA_DECRYPTION_METHOD" ]
then
  NSCA_DECRYPTION_METHOD=1
fi

echo -n > /etc/esmtprc

if [ ! -z "$SMTP_HOSTNAME" ]
then
  echo "hostname=$SMTP_HOSTNAME" >> /etc/esmtprc
fi

if [ ! -z "$SMTP_USERNAME" ]
then
  echo "username=$SMTP_USERNAME" >> /etc/esmtprc
fi

if [ ! -z "$SMTP_PASSWORD" ]
then
  echo "password=$SMTP_PASSWORD" >> /etc/esmtprc
fi

if [ ! -z "$SMTP_FROM" ]
then
  echo "force reverse_path=$SMTP_FROM" >> /etc/esmtprc
fi

sed -i "s/^decryption_method=.*/decryption_method=$NSCA_DECRYPTION_METHOD/" /etc/nsca.cfg

mkdir /nsca-checkresults
chown -R nagios:nagios /etc/nagios4 /scripts/cache /nsca-checkresults

rm -f /var/run/nagios/nsca.pid
rm -f /etc/nagios4/conf.d/* /etc/nagios4/objects/*
rm /etc/apache2/sites-enabled/*

service rsyslog start
service apache2 start
service nsca start

tail --retry -F /var/log/syslog /var/log/apache2/access.log /var/log/apache2/error.log /var/log/nagios4/nagios.log &

su - nagios -s /bin/bash -c "ruby /scripts/nagios.rb"
