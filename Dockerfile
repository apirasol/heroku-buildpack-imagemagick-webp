FROM heroku/heroku:26-build
ARG DEBIAN_FRONTEND=noninteractive
USER root

# See env vars below to update package versions
# * $LIBIMAGEMAGICK_VERSION
# * $LIBWEBP_VERSION
# * $LIBHIEF_VERSION
# * $LIBDE265_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
  libheif-dev libjpeg-dev libpng-dev libtiff-dev libgif-dev libomp-dev busybox-static \
  && rm -rf /var/lib/apt/lists/*

# Under linux/amd64 builds on Apple Silicon (QEMU), coreutils mv may SIGILL.
# Use BusyBox mv during the build to keep configure scripts reliable.
RUN ln -sf /bin/busybox /usr/local/bin/mv

# https://github.com/strukturag/libde265/releases
ENV LIBDE265_VERSION=1.0.8

RUN curl -L https://github.com/strukturag/libde265/releases/download/v$LIBDE265_VERSION/libde265-$LIBDE265_VERSION.tar.gz | tar zx \
  && cd libde265-$LIBDE265_VERSION \
  && ./autogen.sh \
  && ./configure --disable-dependency-tracking \
  && make \
  && make install

# https://github.com/strukturag/libheif/releases
ENV LIBHIEF_VERSION=1.12.0

RUN curl -L https://github.com/strukturag/libheif/releases/download/v$LIBHIEF_VERSION/libheif-$LIBHIEF_VERSION.tar.gz | tar zx \
  && cd libheif-$LIBHIEF_VERSION \
  && ./autogen.sh \
  && ./configure --disable-dependency-tracking \
  && make \
  && make install

# https://github.com/webmproject/libwebp/tags
ENV LIBWEBP_VERSION=1.2.2

RUN cd /opt \
  &&   curl -L http://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$LIBWEBP_VERSION.tar.gz | tar zx \
  && cd libwebp-$LIBWEBP_VERSION \
  && ./configure --disable-dependency-tracking \
  && make \
  && make install

ENV PATH="/usr/src/imagemagick/bin:$PATH"
ENV CPPPATH="/usr/src/imagemagick/include"
ENV CPATH="/usr/src/imagemagick/include"
ENV LIBRARY_PATH="/usr/src/imagemagick/lib"
ENV LD_LIBRARY_PATH="/usr/src/imagemagick/lib"

# Remove libwebp from heroku image
RUN ldconfig /usr/src/imagemagick/lib/

# https://github.com/ImageMagick/Website/blob/main/ChangeLog.md
ENV IMAGEMAGICK_VERSION=7.1.0-43

RUN cd /usr/src/ \
  && wget https://github.com/ImageMagick/ImageMagick/archive/refs/tags/$IMAGEMAGICK_VERSION.tar.gz \
  && tar xf $IMAGEMAGICK_VERSION.tar.gz \
  && cd ImageMagick-7* \
  && ./configure --with-heic=yes --with-webp=yes --prefix=/usr/src/imagemagick --disable-dependency-tracking \
  && make \
  && make install

# Additional copy of libwebp that will be included in the .tar.gz for Heroku
RUN curl -L http://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$LIBWEBP_VERSION.tar.gz | tar zx \
  && cd libwebp-$LIBWEBP_VERSION \
  && ./configure --prefix=/usr/src/imagemagick --disable-dependency-tracking \
  && make \
  && make install

RUN cp /usr/local/lib/libde265.so.0 /usr/src/imagemagick/lib \
  && cp /usr/local/lib/libheif.so.1 /usr/src/imagemagick/lib


RUN cd /usr/src/imagemagick \
  && rm -rf build \
  && mkdir build \
  && tar czf \
  /usr/src/imagemagick/build/imagemagick.tar.gz bin include lib etc share
CMD ["tail", "-f", "/dev/null"]
