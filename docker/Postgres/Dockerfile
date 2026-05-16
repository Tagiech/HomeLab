FROM postgres:18.1 

ARG VCHORD_VERSION=0.5.3
ENV DEBIAN_FRONTEND=noninteractive
USER root
RUN apt-get update && \
  	apt-get install -y --no-install-recommends \
  	ca-certificates \
  	curl \
  	wget \
  	gnupg \
  	lsb-release \
  	build-essential \
  	git \
  	postgresql-server-dev-all \
  	postgresql-contrib \
  	pkg-config \
  	pgxnclient \
 && rm -rf /var/lib/apt/lists/* /tmp/*

RUN git clone --depth 1 https://github.com/pgvector/pgvector.git /tmp/pgvector \
	&& cd /tmp/pgvector \
	&& make \
	&& make install \
	&& rm -rf /tmp/pgvector

RUN if [ -n "$VCHORD_VERSION" ] ; then \
	arch=$(dpkg --print-architecture) ; \
	url="https://github.com/tensorchord/VectorChord/releases/download/${VCHORD_VERSION}/postgresql-18-vchord_${VCHORD_VERSION}-1_${arch}.deb" ; \
	wget -O /tmp/vchord.deb "$url" || (echo "vchord .deb not found" && exit 1) ; \
	apt-get update && apt-get install -y --no-install-recommends /tmp/vchord.deb || true ; \
	rm -f /tmp/vchord.deb ; \
    fi \
	&& rm -rf /var/lib/apt/lists/* /tmp/*

RUN mkdir -p /etc/postgresql/conf.d && \
	 echo "shared_preload_libraries = 'vchord,pgvector'" > /etc/postgresql/conf.d/preload.conf
