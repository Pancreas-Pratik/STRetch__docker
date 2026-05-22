FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV SKIP_REF=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        wget \
        curl \
        git \
        make \
        gcc \
        g++ \
        bzip2 \
        gzip \
        tar \
        unzip \
        openjdk-11-jre \
        perl \
        python3 \
        python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone https://github.com/Pancreas-Pratik/STRetch__docker.git STRetch

WORKDIR /opt/STRetch

RUN bash install.sh

ENV PATH="/opt/STRetch/tools/bin:${PATH}"

CMD ["bash"]
