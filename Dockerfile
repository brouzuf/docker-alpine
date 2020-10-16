FROM alpine:edge
LABEL maintainer="Dave Conroy (dave at tiredofit dot ca)"

### Set defaults
ENV S6_OVERLAY_VERSION=v2.1.0.0 \
    DEBUG_MODE=FALSE \
    TIMEZONE=Etc/GMT \
    ENABLE_CRON=TRUE \
    ENABLE_SMTP=TRUE 

### Zabbix pre installation steps
RUN set -ex && \
    apk update && \
    apk upgrade && \
    apk add \
        iputils \
        bash \
        pcre \
        libssl1.1 && \
    \
### Zabbix compilation
    apk add --no-cache -t .zabbix-build-deps \
            coreutils \
            alpine-sdk \
            automake \
            autoconf \
            openssl-dev \
            pcre-dev && \
    \
### Install MailHog
    apk add --no-cache -t .mailhog-build-deps \
            go \
            git \
            musl-dev \
            && \
    mkdir -p /usr/src/gocode && \
    cd /usr/src && \
    export GOPATH=/usr/src/gocode && \
    go get github.com/mailhog/MailHog && \
    go get github.com/mailhog/mhsendmail && \
    mv /usr/src/gocode/bin/MailHog /usr/local/bin && \
    mv /usr/src/gocode/bin/mhsendmail /usr/local/bin && \
    rm -rf /usr/src/gocode && \
    apk del --purge \
            .mailhog-build-deps .zabbix-build-deps && \
    \
    adduser -D -u 1025 mailhog && \
    \
### Add core utils
    apk add -t .base-rundeps \
            bash \
            busybox-extras \
            curl \
            grep \
            less \
            logrotate \
            msmtp \
            nano \
            sudo \
            tzdata \
            vim \
            && \
    rm -rf /var/cache/apk/* && \
    rm -rf /etc/logrotate.d/acpid && \
    rm -rf /root/.cache /root/.subversion && \
    cp -R /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    echo '%zabbix ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    \
    ## Quiet down sudo
    echo "Set disable_coredump false" > /etc/sudo.conf && \
    \
### S6 installation
    apkArch="$(apk --print-arch)"; \
	case "$apkArch" in \
		x86_64) s6Arch='amd64' ;; \
		armhf) s6Arch='armhf' ;; \
		aarch64) s6Arch='aarch64' ;; \
		ppc64le) s6Arch='ppc64le' ;; \
		*) echo >&2 "Error: unsupported architecture ($apkArch)"; exit 1 ;; \
	esac; \
    curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${s6Arch}.tar.gz | tar xfz - -C / && \
    mkdir -p /assets/cron && \
### Clean up
    rm -rf /usr/src/*

### Networking configuration
EXPOSE 1025 8025 10050/TCP

### Add folders
ADD /install /

### Entrypoint configuration
ENTRYPOINT ["/init"]
