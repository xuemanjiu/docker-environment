FROM ubuntu:26.04 AS base

ENV TZ=Asia/Taipei
ENV DEBIAN_FRONTEND=noninteractive


ARG UID=1001
ARG GID=1001
ARG USERNAME=xuemanjiu

RUN apt-get update && \
    apt-get install -y tzdata && \
    ln -snf /usr/share/zoneinfo/Asia/Taipei /etc/localtime && \
    echo Asia/Taipei > /etc/timezone && \
    groupadd -g ${GID} ${USERNAME} && \
    useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}



FROM base AS common_pkg_provider

USER root

RUN apt-get update && \
    apt-get install -y \
        vim \
        git \
        curl \
        wget \
        ca-certificates \
        build-essential

USER xuemanjiu

WORKDIR /home/xuemanjiu