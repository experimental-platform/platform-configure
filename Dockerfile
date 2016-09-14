FROM ubuntu:16.04

RUN apt-get update && \
    apt-get -y install --no-install-recommends curl jq ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ADD https://get.docker.com/builds/Linux/x86_64/docker-1.10.3 /docker
RUN chmod +x /docker
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT /entrypoint.sh

