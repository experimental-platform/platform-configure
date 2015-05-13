FROM dockerregistry.protorz.net/ubuntu:latest

ADD services /services

CMD [ "rm", "-rf", "/data/*", ";", "cp", "-a", "/services/*", "/data/" ]