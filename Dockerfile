FROM debian:buster

EXPOSE 80
EXPOSE 5667

RUN apt-get -y update ; apt-get -y install nagios4 nsca ruby esmtp esmtp-run exim4- rsyslog

RUN adduser www-data nagios

RUN rm -f /etc/nagios4/conf.d/* /etc/nagios4/objects/*
RUN mkdir /nsca-checkresults

COPY scripts /scripts

COPY defaults/defaults.yml /scripts/defaults.yml
COPY defaults/apache2.conf /etc/nagios4/apache2.conf
COPY defaults/nagios.cfg /etc/nagios4/nagios.cfg
COPY defaults/cgi.cfg /etc/nagios4/cgi.cfg
COPY defaults/nsca.cfg /etc/

CMD /scripts/start.sh
