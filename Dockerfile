# rfdrake/cibh
#
# BUILD: docker build -t rfdrake/cibh .
# RUN:   docker run -d -p $PORT:8048 -v $CIBHRCFILE:/etc/cibhrc -v $DATA_LOCATION:/data rfdrake/cibh

FROM ubuntu:14.04

# need this for snmp-mibs-downloader
RUN sed -i 's/universe/universe multiverse/' /etc/apt/sources.list
RUN apt-get update && apt-get install -y \
    snmp-mibs-downloader \
    libsnmp-dev \
    curl \
    perl \
    make \
    rsyslog \
    supervisor && \
    apt-get build-dep -y libgd-gd2-perl

ADD vendor/crontab /etc/crontab
RUN touch /var/log/cron.log

ADD vendor/supervisord.conf /etc/supervisor/supervisord.conf
ADD . /cibh

RUN curl -L https://cpanmin.us | perl - App::cpanminus
RUN cd /cibh && cpanm --notest --installdeps .

EXPOSE 8048
CMD []
ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
