FROM dockerregistry.protorz.net/ubuntu:latest

RUN curl -sL https://deb.nodesource.com/setup | sudo bash - && \
    apt-get update && \
    apt-get install -y build-essential curl nodejs git systemd-services && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN npm install -g mustache

ENV VERSION development

ADD services /services
ADD stuff /stuff
ADD prep.sh /prep.sh

# Only needed for integration tests:
ADD cloud-config.yaml /cloud-config.yaml

CMD [ "/prep.sh" ]
