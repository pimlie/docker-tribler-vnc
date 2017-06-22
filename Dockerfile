FROM ubuntu:16.04
MAINTAINER pimlie <pimlie@hotmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        supervisor \
        lxde x11vnc xvfb \
	nginx net-tools \
	libav-tools libsodium18 libx11-6 python-apsw python-cherrypy3 python-cryptography python-decorator python-feedparser python-leveldb python-libtorrent python-matplotlib python-m2crypto python-netifaces python-pil python-pyasn1 python-twisted python2.7 vlc python-chardet python-configobj python-pyqt5 python-pyqt5.qtsvg \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

ENV TINI_VERSION v0.14.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

ADD libs/ /opt/

RUN ln -s /opt/websockify/run /usr/local/bin/websockify

COPY conf/openbox.xml /root/.config/openbox/rc.xml
COPY conf/nginx.default /etc/nginx/sites-available/default
COPY conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh

RUN mkdir /TriblerDownloads /TriblerWatch

ENTRYPOINT ["/start.sh"]
