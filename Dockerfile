FROM dockerregistry.protorz.net/ubuntu:latest

ADD services /services
ADD stuff /stuff
ADD prep.sh /prep.sh

CMD [ "/prep.sh" ]
