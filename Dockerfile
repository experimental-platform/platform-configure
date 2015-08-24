FROM experimentalplatform/ubuntu:latest

ADD services /services
ADD config /config
ADD prep.sh /prep.sh
ADD platform-configure.sh /platform-configure.sh
ADD systemd-docker/systemd-docker /systemd-docker

CMD [ "/prep.sh" ]
