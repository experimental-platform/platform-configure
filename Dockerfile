FROM quay.io/experimentalplatform/ubuntu:latest

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install --no-install-recommends gawk systemd \
      python-pkg-resources python-pystache udev jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ADD https://get.docker.com/builds/Linux/x86_64/docker-1.10.3 /docker
RUN chmod +x /docker
ADD services /services
ADD config /config
ADD prep.sh /prep.sh
ADD test.sh /test.sh
ADD scripts /scripts
ADD button /button
ADD tcpdump /tcpdump
ADD speedtest /speedtest
ADD masterpassword /masterpassword
ADD ipmitool /ipmitool
ADD self_destruct /self_destruct
ADD platconf-v4 /platconf
COPY binaries /binaries

CMD [ "/prep.sh" ]
