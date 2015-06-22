FROM dockerregistry.protorz.net/ubuntu:latest

ADD services /services
ADD stuff /stuff
ADD prep.sh /prep.sh

# Only needed for integration tests:
ADD cloud-config.yaml /cloud-config.yaml

CMD [ "/prep.sh" ]
