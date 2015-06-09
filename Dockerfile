FROM dockerregistry.protorz.net/ubuntu:latest

ADD services /services
ADD update-images-protonet.sh /update-images-protonet.sh
ADD prep.sh /prep.sh

CMD [ "/prep.sh" ]
