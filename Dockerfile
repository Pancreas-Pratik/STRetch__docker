FROM ubuntu:latest

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

RUN bash install.sh && \
    ln -sf /opt/STRetch/tools/miniconda/envs/STR/bin/python   /opt/STRetch/tools/bin/python && \
    ln -sf /opt/STRetch/tools/miniconda/envs/STR/bin/goleft   /opt/STRetch/tools/bin/goleft && \
    ln -sf /opt/STRetch/tools/miniconda/envs/STR/bin/bedtools /opt/STRetch/tools/bin/bedtools && \
    ln -sf /opt/STRetch/tools/miniconda/envs/STR/bin/mosdepth /opt/STRetch/tools/bin/mosdepth

ENV PATH="/opt/STRetch/tools/bin:/opt/STRetch/tools/miniconda/envs/STR/bin:${PATH}"

CMD ["bash"]
