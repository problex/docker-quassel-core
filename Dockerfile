FROM lsiobase/alpine:3.10 as build-stage

# build time arguements
ARG CXXFLAGS="\
	-D_FORTIFY_SOURCE=2 \
	-Wp,-D_GLIBCXX_ASSERTIONS \
	-fstack-protector-strong \
	-fPIE -pie -Wl,-z,noexecstack \
	-Wl,-z,relro -Wl,-z,now"
ARG QUASSEL_RELEASE
# install build packages
RUN \
 apk add --no-cache \
	cmake \
	curl \
	dbus-dev \
	g++ \
	gcc \
	icu-dev \
	icu-libs \
	jq \
	openssl-dev \
	openldap-dev \
	make \
	paxmark \
	qt5-qtbase-dev \
	qt5-qtscript-dev \
	qt5-qtbase-postgresql \
	qt5-qtbase-sqlite

# fetch source
RUN \
 mkdir -p \
	/tmp/quassel-src/build && \
 if [ -z ${QUASSEL_RELEASE+x} ]; then \
	QUASSEL_RELEASE=$(curl -sX GET "https://api.github.com/repos/quassel/quassel/releases/latest" \
	| jq -r .tag_name); \
 fi && \
 curl -o \
 /tmp/quassel.tar.gz -L \
	"https://github.com/quassel/quassel/archive/${QUASSEL_RELEASE}.tar.gz" && \
 tar xf \
 /tmp/quassel.tar.gz -C \
	/tmp/quassel-src --strip-components=1

# build package
RUN \
 cd /tmp/quassel-src/build && \
 cmake \
	-DCMAKE_BUILD_TYPE="Release" \
	-DCMAKE_INSTALL_PREFIX=/usr \
	-DUSE_QT5=ON \
	-DWANT_CORE=ON \
	-DWANT_MONO=OFF \
	-DWANT_QTCLIENT=OFF \
	-DWITH_KDE=OFF \
	/tmp/quassel-src && \
 make -j2 && \
 make DESTDIR=/build/quassel install && \
 paxmark -m /build/quassel/usr/bin/quasselcore

FROM lsiobase/alpine:3.10

# set version label
ARG BUILD_DATE
ARG VERSION
ARG QUASSEL_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="sparklyballs & chbmb"

# set environment variables
ENV HOME /config

# install runtime packages
RUN \
 apk add --no-cache \
	icu-libs \
	openssl \
	qt5-qtbase \
	qt5-qtbase-postgresql \
	qt5-qtbase-sqlite \
	qt5-qtscript

# copy artifacts build stage
COPY --from=build-stage /build/quassel/usr/bin/ /usr/bin/

# add local files
COPY root/ /

# ports and volumes
VOLUME /config
EXPOSE 4242 10113
