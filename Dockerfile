FROM experimentalplatform/ubuntu:latest

ADD services /services
ADD config /config
ADD prep.sh /prep.sh
ADD platform-configure.sh /platform-configure.sh
ADD platform-passwd.sh /platform-passwd.sh
ADD systemd-docker/systemd-docker /systemd-docker

CMD [ "/prep.sh" ]
