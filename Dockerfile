FROM experimentalplatform/ubuntu:latest

ADD services /services
ADD stuff /stuff
ADD prep.sh /prep.sh
ADD platform-configure.sh /platform-configure.sh

CMD [ "/prep.sh" ]
