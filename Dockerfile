FROM dockerregistry.protorz.net/ubuntu:latest

ADD services /services

CMD [ "cp", "-a", "/services/*", "/data/" ]