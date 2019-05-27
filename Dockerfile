# Dockerfile - Ubuntu Bionic
# https://github.com/openresty/docker-openresty

ARG RESTY_IMAGE_BASE="ubuntu"
ARG RESTY_IMAGE_TAG="bionic"

FROM ${RESTY_IMAGE_BASE}:${RESTY_IMAGE_TAG}

LABEL maintainer="Evan Wies <evan@neomantra.net>"

# list of lua libs to install
ARG ROCKS

# set timezone
ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Docker Build Arguments
ARG RESTY_VERSION="1.13.6.2"
ARG RESTY_LUAROCKS_VERSION="2.4.4"
ARG RESTY_OPENSSL_VERSION="1.1.0i"
ARG RESTY_PCRE_VERSION="8.42"
ARG RESTY_J="1"
ARG RESTY_CONFIG_OPTIONS="\
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""
ARG RESTY_ADD_PACKAGE_BUILDDEPS=""
ARG RESTY_ADD_PACKAGE_RUNDEPS=""
ARG RESTY_EVAL_PRE_CONFIGURE=""
ARG RESTY_EVAL_POST_MAKE=""

LABEL resty_version="${RESTY_VERSION}"
LABEL resty_luarocks_version="${RESTY_LUAROCKS_VERSION}"
LABEL resty_openssl_version="${RESTY_OPENSSL_VERSION}"
LABEL resty_pcre_version="${RESTY_PCRE_VERSION}"
LABEL resty_config_options="${RESTY_CONFIG_OPTIONS}"
LABEL resty_config_options_more="${RESTY_CONFIG_OPTIONS_MORE}"
LABEL resty_add_package_builddeps="${RESTY_ADD_PACKAGE_BUILDDEPS}"
LABEL resty_add_package_rundeps="${RESTY_ADD_PACKAGE_RUNDEPS}"
LABEL resty_eval_pre_configure="${RESTY_EVAL_PRE_CONFIGURE}"
LABEL resty_eval_post_make="${RESTY_EVAL_POST_MAKE}"
LABEL luarocks_install="${LUAROCKS_INSTALL}"

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"


# 1) Install apt dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && USER=root mkdir -p /usr/share/man/man1 \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        ca-certificates \
        curl \
        gettext-base \
        libgd-dev \
        libgeoip-dev \
        libncurses5-dev \
        libperl-dev \
        libreadline-dev \
        libxslt1-dev \
        make \
        perl \
        unzip \
        zlib1g-dev \
        git \
        build-essential \
        libxml2-dev \
        libfftw3-dev \
        libmagickwand-dev \
        libopenexr-dev \
        liborc-0.4-0 \
        gobject-introspection \
        libgsf-1-dev \
        libglib2.0-dev \
        liborc-0.4-dev \
        libjpeg-turbo-progs \
        librsvg2-bin \
        libtiff-opengl \
        libtiff-tools \
        liblcms2-utils \
        libpng++-dev \
        automake \
        libtool \
        swig \
        gtk-doc-tools \
        python-gi-dev \
        libgirepository1.0-dev \
        libwebp-dev \
        libwebp6 \
        libwebpdemux2 \
        libwebpmux3 \
        libgif-dev \
        giflib-tools \
        libgif7 \
        libperl4-corelibs-perl \
        libpng-dev \
        libpng16-16 \
        libpng-tools \
        libopenslide-dev \
        libopenslide0 \
        libopenjp2-7 \
        libpangoft2-1.0-0 \
        libcfitsio5 \
        libcfitsio-dev \
        libcfitsio-bin \
        libastro-fits-cfitsio-perl \
        libcfitsio-doc \
        poppler-utils \
        poppler-data \
        libpopplerkit0 \
        libpopplerkit-dev \
        libpoppler73 \
        libpoppler-private-dev \
        libpoppler-glib8 \
        libpoppler-glib-doc \
        libpoppler-glib-dev \
        libpoppler-dev \
        gir1.2-poppler-0.18 \
        libpoppler-cil \
        libpoppler-cil-dev \
        libpoppler-cpp-dev \
        libpoppler-cpp0v5 \
        python3-gst-1.0 \
        python3-gi \
        python3-gi-cairo \
        nifti-bin \
        libnifti-dev \
        libnifti-doc \
        libnifti2 \
        libmatio-dev \
        libmatio-doc \
        libmatio4 \
        hdf5-helpers \
        libaec-dev \
        libaec0 \
        libgfortran4 \
        libhdf5-100 \
        libhdf5-cpp-100 \
        libhdf5-dev \
        libsz2 \
        libpangoxft-1.0-0 \
        libpango1.0-dev \
        libpango1.0-0 \
        pngquant \
        ${RESTY_ADD_PACKAGE_BUILDDEPS} \
        ${RESTY_ADD_PACKAGE_RUNDEPS} \
    && cd /tmp \
    && if [ -n "${RESTY_EVAL_PRE_CONFIGURE}" ]; then eval $(echo ${RESTY_EVAL_PRE_CONFIGURE}); fi \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION} \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
    && curl -fSL https://github.com/luarocks/luarocks/archive/${RESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && tar xzf luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && cd luarocks-${RESTY_LUAROCKS_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit \
        --lua-suffix=jit-2.1.0-beta3 \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make build \
    && make install \
    && cd /tmp \
    && if [ -n "${RESTY_EVAL_POST_MAKE}" ]; then eval $(echo ${RESTY_EVAL_POST_MAKE}); fi \
    && rm -rf luarocks-${RESTY_LUAROCKS_VERSION} luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && if [ -n "${RESTY_ADD_PACKAGE_BUILDDEPS}" ]; then DEBIAN_FRONTEND=noninteractive apt-get remove --purge "${RESTY_ADD_PACKAGE_BUILDDEPS}" ; fi \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin

# Add LuaRocks paths
# If OpenResty changes, these may need updating:
#    /usr/local/openresty/bin/resty -e 'print(package.path)'
#    /usr/local/openresty/bin/resty -e 'print(package.cpath)'
ENV LUA_PATH="/usr/local/openresty/site/lualib/?.ljbc;/usr/local/openresty/site/lualib/?/init.ljbc;/usr/local/openresty/lualib/?.ljbc;/usr/local/openresty/lualib/?/init.ljbc;/usr/local/openresty/site/lualib/?.lua;/usr/local/openresty/site/lualib/?/init.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;./?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta3/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua$/lua?.lua;/images/app/?.lua;/images/src/?.lua"

ENV LUA_CPATH="/usr/local/openresty/site/lualib/?.so;/usr/local/openresty/lualib/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;/images/app/socket/core.so;"

# Copy nginx configuration files
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY tpl.static.conf /etc/nginx/conf.d/templates/tpl.static.conf
COPY images /images


# set ENVIRONMENT
ENV GI_TYPELIB_PATH=/usr/local/lib/girepository-1.0 \
    VIPSHOME=/usr/local \
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib \
    PATH=$PATH:/usr/local/bin \
    PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig \
    MANPATH=$MANPATH:/usr/local/man \
    PYTHONPATH=/usr/local/lib/python2.7/site-packages

# build libvips from source
RUN cd /tmp \
	&& git clone https://github.com/libvips/libvips.git \
	&& cd libvips \
	&& ./autogen.sh \
	&& make \
	&& make install \
	&& ldconfig \
	&& cd /tmp \
    && rm -rf libvips

# luarocks packages in string with spaces
ENV LUAROCKS_INSTALL ${ROCKS:-lua-vips lua-resty-template lua-resty-http lrexlib-PCRE lua-cjson}

# copy to image luarocks install script
COPY install-luarocks.sh /usr/bin

# install all packages
RUN chmod +x /usr/bin/install-luarocks.sh \
    && ./usr/bin/install-luarocks.sh



#CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
CMD /bin/bash -c "envsubst '$${DOMAIN_NAME} $${CONTENT_PWD} $${IMAGES_PWD} $${LUA_CODE_CACHE} $${RESOLVER}' < /etc/nginx/conf.d/templates/tpl.static.conf > /etc/nginx/conf.d/default.conf && /usr/local/openresty/bin/openresty -g 'daemon off;'"

# Use SIGQUIT instead of default SIGTERM to cleanly drain requests
# See https://github.com/openresty/docker-openresty/blob/master/README.md#tips--pitfalls
STOPSIGNAL SIGQUIT