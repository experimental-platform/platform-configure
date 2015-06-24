FROM experimentalplatform/ubuntu:latest

ADD services /services
ADD stuff /stuff
ADD prep.sh /prep.sh

CMD [ "/prep.sh" ]
