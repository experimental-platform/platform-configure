FROM experimentalplatform/ubuntu:latest

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install --no-install-recommends gawk systemd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ADD services /services
ADD config /config
ADD prep.sh /prep.sh
ADD test.sh /test.sh
ADD scripts /scripts
ADD button /button

CMD [ "/prep.sh" ]
