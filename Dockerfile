FROM centos:7
MAINTAINER xingo xu <xingoxu@gmail.com>

CMD ["ffmpeg --help"]
ENTRYPOINT ["/bin/bash"]

ARG NODEJS_VERSION=10
ARG LIBVA_VERSION=2.4.0
ARG VAAPI_DRIVER=2.3.0
ARG FFMPEG_VERSION=4.1.3
ARG NASM_VERSION=2.14.02

ENV PKG_CONFIG_PATH=/usr/lib/pkgconfig \
    SRC=/usr

RUN curl -sL https://rpm.nodesource.com/setup_${NODEJS_VERSION}.x | bash - \
    && yum install -y nodejs gcc-c++ make wget \
    && yum install -y --enablerepo=extras epel-release yum-utils \
    # Install libdrm
    && yum install -y libdrm yasm lame soxr \
    # Install build dependencies
    && build_deps="automake autoconf bzip2 \
                cmake freetype-devel gcc \
                git libtool make \
                mercurial pkgconfig \
                zlib-devel gnutls-devel libass-devel libvorbis-devel \
                libbluray-devel soxr-devel yasm-devel \
                lame-devel libdrm-devel" \
    && yum install -y ${build_deps}
    # compile nasm
RUN DIR=$(mktemp -d) && cd ${DIR} \
    && curl -sL https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/nasm-${NASM_VERSION}.tar.bz2 | \
    tar -jx --strip-components=1 \
    && ./autogen.sh \
    && ./configure --prefix=${SRC} \
    && make && make install \
    && rm -rf ${DIR}
    # Build libva
RUN DIR=$(mktemp -d) && cd ${DIR} \
    && curl -sL https://github.com/intel/libva/releases/download/${LIBVA_VERSION}/libva-${LIBVA_VERSION}.tar.bz2 | \
    tar -jx --strip-components=1 \
    && ./configure CFLAGS=' -O2' CXXFLAGS=' -O2' --prefix=${SRC} \
    && make && make install \
    # && pkg-config libva \
    && rm -rf ${DIR}
    # Build libva-intel-driver
RUN DIR=$(mktemp -d) && cd ${DIR} \
    && curl -sL https://github.com/intel/intel-vaapi-driver/releases/download/${VAAPI_DRIVER}/intel-vaapi-driver-${VAAPI_DRIVER}.tar.bz2 | \
    tar -jx --strip-components=1 \
    && ./configure \
    && make && make install \
    && rm -rf ${DIR}
    # compile opus
RUN DIR=$(mktemp -d) && cd ${DIR} \
    && curl -sL https://github.com/xiph/opus/archive/v1.3.1.tar.gz | \
    tar -zx --strip-components=1 \
    && ./autogen.sh \
    && ./configure --prefix=${SRC} --enable-shared --enable-pic \
    && make -j2 && make install \
    && rm -rf ${DIR}
    # compile libvpx
RUN DIR=$(mktemp -d) && cd ${DIR} \
    && curl -sL https://github.com/webmproject/libvpx/archive/v1.8.0.tar.gz | \
    tar -zx --strip-components=1 \
    && ./configure --enable-shared --enable-pic --target=x86_64-linux-gcc --as=yasm \
    && make -j2 && make install \
    && rm -rf ${DIR}
    # compile x264
RUN DIR=/tmp/x264 \
    && cd /tmp \
    && git clone https://git.videolan.org/git/x264.git --depth 1 \
    && cd ${DIR} \
    && ./configure --prefix="${SRC}" --enable-shared --enable-pic \
    && make && make install \
    && rm -rf ${DIR}
    # compile x265
RUN DIR=/tmp/x265 \
    && cd /tmp \
    && hg clone https://bitbucket.org/multicoreware/x265 && cd x265/build/linux \
    && cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=${SRC} -DENABLE_SHARED:bool=true -DENABLE_PIC:bool=true ../../source \
    && make -j2 && make install \
    && rm -rf ${DIR}
    # start ffmpeg
RUN DIR=$(mktemp -d) && cd ${DIR} \
    && curl -sL https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz | \
    tar -zx --strip-components=1 \
    && ./configure \
        --prefix=${SRC} \
        --enable-small \
        --enable-pic \
        --enable-shared \
        --enable-gpl \
        --enable-fontconfig \
        --enable-libass \
        --enable-libbluray \
        --enable-avresample \
        --enable-libfreetype \
        --enable-libfribidi \
        --enable-libmp3lame \
        --enable-libsoxr \
        --enable-libvorbis \
        --enable-libopus \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-gnutls \
        --disable-debug \
        --disable-doc \
        --disable-static \
        --arch=x86_64 \
        --enable-thumb \
        --enable-vaapi \
        --enable-small \
    && make && make install \
    && make distclean \
    && hash -r \
    && rm -rf ${DIR}
    # Cleanup build dependencies and temporary files
RUN sed -i '$a'${SRC}'/lib/' /etc/ld.so.conf \
    && sed -i '$a/usr/local/lib/' /etc/ld.so.conf \
    && ldconfig

RUN yum clean all \
    && ffmpeg -buildconf

RUN npm install pm2 -g \
    && pm2 startup

RUN git clone git://github.com/Chinachu/Chinachu.git /chinachu \
    && cd /chinachu/ \
    && sed -i '124d' chinachu \
    && echo 1 | ./chinachu installer \
    && cp config.sample.json config.json \
    && echo [] > rules.json 

RUN mkdir data && mkdir log

WORKDIR /chinachu
