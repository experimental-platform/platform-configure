FROM dockerregistry.protorz.net/ubuntu:latest

ADD services /services
ADD prep.sh /prep.sh

CMD [ "/prep.sh" ]