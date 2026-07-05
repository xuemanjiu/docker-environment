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
        build-essential \
	python3 \
        python3-pip \
	python3-venv && \
    python3 -m venv /opt/venv && \
    chown -R xuemanjiu:xuemanjiu /opt/venv

ENV PATH="/opt/venv/bin:$PATH"

USER xuemanjiu
WORKDIR /home/xuemanjiu

FROM common_pkg_provider AS verilator_provider

USER root

RUN apt-get update && \
    apt-get install -y \
        help2man \
        perl \
        autoconf \
        flex \
        bison \
        ccache \
        libfl2 \
        libfl-dev \
        zlib1g \
        zlib1g-dev \
        liblz4-1 \
        liblz4-dev \
        libgoogle-perftools-dev \
        libjemalloc-dev \
        numactl \
        perl-doc

RUN git clone --depth 1 --branch stable https://github.com/verilator/verilator.git /tmp/verilator && \
    cd /tmp/verilator && \
    unset VERILATOR_ROOT && \
    autoconf && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /tmp/verilator

USER xuemanjiu
WORKDIR /home/xuemanjiu

FROM verilator_provider AS systemc_provider

USER root

ENV SYSTEMC_HOME=/opt/systemc
ENV SYSTEMC_CXXFLAGS="-I/opt/systemc/include -std=c++17"
ENV SYSTEMC_LDFLAGS="-L/opt/systemc/lib -Wl,-rpath,/opt/systemc/lib -lsystemc -pthread"
ENV LD_LIBRARY_PATH="/opt/systemc/lib"

RUN apt-get update && \
    apt-get install -y cmake

RUN git clone --depth 1 --branch 3.0.2 https://github.com/accellera-official/systemc.git /tmp/systemc && \
    cmake -S /tmp/systemc -B /tmp/systemc/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${SYSTEMC_HOME} \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_CXX_STANDARD=17 && \
    cmake --build /tmp/systemc/build -j2 && \
    cmake --install /tmp/systemc/build && \
    cd / && \
    rm -rf /tmp/systemc

USER xuemanjiu
WORKDIR /home/xuemanjiu

FROM common_pkg_provider AS release
USER root

# 只 COPY 各 stage compile 出來的產物
COPY --from=verilator_provider /usr/local/bin/verilator* /usr/local/bin/
COPY --from=verilator_provider /usr/local/share/verilator /usr/local/share/verilator
COPY --from=systemc_provider /opt/systemc /opt/systemc

# runtime library（verilator/systemc 執行時期依賴）
# + verilator build toolchain：讓 `eman change-verilator` 能在 release
#   container 內從 source 編譯並切換不同版本的 Verilator
RUN apt-get update && \
    apt-get install -y \
        libfl2 \
        zlib1g \
        liblz4-1 \
        autoconf \
        flex \
        bison \
        ccache \
        help2man \
        perl \
        libfl-dev \
        zlib1g-dev \
        liblz4-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV SYSTEMC_HOME=/opt/systemc
ENV PATH="/home/xuemanjiu/.local/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/systemc/lib"
ENV SYSTEMC_CXXFLAGS="-I/opt/systemc/include -std=c++17"
ENV SYSTEMC_LDFLAGS="-L/opt/systemc/lib -Wl,-rpath,/opt/systemc/lib -lsystemc -pthread"

USER xuemanjiu
WORKDIR /home/xuemanjiu