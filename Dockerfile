FROM experimentalplatform/ubuntu:latest

ADD services /services
ADD config /config
ADD prep.sh /prep.sh
ADD platform-configure.sh /platform-configure.sh

CMD [ "/prep.sh" ]
