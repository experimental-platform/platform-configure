FROM experimentalplatform/ubuntu:latest

ADD services /services
ADD config /config
ADD prep.sh /prep.sh
ADD scripts /scripts
ADD systemd-docker/systemd-docker /systemd-docker
ADD button /button

CMD [ "/prep.sh" ]
