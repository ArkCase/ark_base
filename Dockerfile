###########################################################################################################
#
# How to build:
#
# docker build -t arkcase/base:latest .
# 
# How to run: (Docker)
#
# docker run --name ark_base -d arkcase/base:latest sleep infinity
# docker exec -it ark_base /bin/bash
# docker stop ark_base
# docker rm ark_base
#
# How to run: (Kubernetes) 
#
# kubectl create -f pod_ark_base.yaml
# kubectl exec -it pod/base -- bash
# kubectl delete -f pod_ark_base.yaml
#
###########################################################################################################

ARG PRIVATE_REGISTRY
ARG VER="24.04"
ARG ARCH="x86_64"
ARG OS="linux"
ARG PKG="base"
ARG PLATFORM="ubuntu:${VER}"
ARG ACM_GID="10000"
ARG ACM_GROUP="acm"

# TODO: Swap the BASE_REGISTRY and BASE_REPO to the secure UBI
# once we get Ubuntu Pro into the mix
# ARG BASE_REGISTRY="docker.io"
ARG BASE_REPO="docker.io/library/ubuntu"
ARG BASE_IMG="${BASE_REPO}:${VER}"

ARG STEP_VER="0.29.0"
ARG STEP_REBUILD_REGISTRY="${PRIVATE_REGISTRY}"
ARG STEP_REBUILD_REPO="arkcase/rebuild-step-ca"
ARG STEP_REBUILD_TAG="${STEP_VER}"
ARG STEP_REBUILD_IMG="${STEP_REBUILD_REGISTRY}/${STEP_REBUILD_REPO}:${STEP_REBUILD_TAG}"

ARG GO="1.24"
ARG BUILDER_IMAGE="golang"
ARG BUILDER_VER="${GO}-alpine"
ARG BUILDER_IMG="${BUILDER_IMAGE}:${BUILDER_VER}"

FROM "${BUILDER_IMG}" AS gucci

ARG GO
ARG GUCCI_REPO="https://github.com/noqcks/gucci.git"
ARG GUCCI_VER="1.9.0"

RUN apk --no-cache add git

ENV SRCPATH="/build/gucci"
ENV GO111MODULE="on"
ENV CGO_ENABLED="0"
ENV GOOS="linux"
ENV GOARCH="amd64"
RUN mkdir -p "${SRCPATH}" && \
    cd "${SRCPATH}" && \
    git clone "${GUCCI_REPO}" "." --branch="v${GUCCI_VER}" && \
    go mod edit -go "${GO}" && \
    go get -u && \
    go mod tidy && \
    go install -v -ldflags "-X main.AppVersion='${GUCCI_VER}' -w -extldflags static" && \
    cp -vf /go/bin/gucci /gucci

ARG STEP_REBUILD_IMG

FROM "${STEP_REBUILD_IMG}" AS step

ARG BASE_IMG

FROM "${BASE_IMG}"

ARG OS_VERSION
ARG VER
ARG ARCH
ARG OS
ARG PKG
ARG PLATFORM
ARG ACM_GROUP
ARG ACM_GID

ENV APP_ROOT="/opt/app"
ENV HOME="${APP_ROOT}/src"
ENV PATH="${HOME}/bin:${APP_ROOT}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV PLATFORM="${PLATFORM}"

ENV SUMMARY="Base ArkCase image for support containers"
ENV DESCRIPTION="This image provides any images layered on top of it \
with all the tools needed to use hardened and secure functionality while keeping \
the image size as small as possible."

# The system-wide CA trusts
ENV CA_TRUSTS_PEM="/etc/ssl/certs/ca-certificates.crt"

LABEL summary="${SUMMARY}" \
      description="${DESCRIPTION}" \
      io.k8s.description="${DESCRIPTION}" \
      io.k8s.display-name="ArkCase Base"

LABEL ORG="ArkCase LLC"
LABEL MAINTAINER="ArkCase Support <support@arkcase.com>"
LABEL APP="Base"
LABEL VERSION="${VER}"

ARG BASE_DIR="/app"
ENV BASE_DIR="${BASE_DIR}"
ENV TEMP_DIR="${BASE_DIR}/temp"
ENV DATA_DIR="${BASE_DIR}/data"
ENV CONF_DIR="${BASE_DIR}/conf"
ENV LOGS_DIR="${BASE_DIR}/logs"

ENV DEF_USER="default"
ENV DEF_UID="1001"
ENV DEF_GROUP="${DEF_USER}"
ENV DEF_GID="${DEF_UID}"

ENV CHARSET="UTF-8"
ENV LANGUAGE="en_US:en"
ENV LANG="en_US.${CHARSET}"
ENV LC_ALL="${LANG}"

RUN mkdir -p "${HOME}/.pki/nssdb" && \
    echo "${LANG} ${CHARSET}" > /etc/locale.gen && \
    echo "LANG=${LANG}" > /etc/default/locale && \
    chown -R "${DEF_UID}:${DEF_GID}" "${HOME}/.pki" && \
    apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get -y install \
        acl \
        attr \
        bind9-utils \
        curl \
        dnsutils \
        findutils \
        gettext-base \
        inotify-tools \
        jq \
        libpam-pwquality \
        libxml2-utils \
        locales \
        lsb-release \
        openssl \
        python-is-python3 \
        python3 \
        python3-pip \
        python3-yaml \
        sudo \
        tar \
        unzip \
        uuid-runtime \
        wget \
        xmlstarlet \
        xz-utils \
        zip \
      && \
    apt-get clean

# Reset permissions of modified directories and add default user. We remove the "tape"
# and "floppy" groups because they can interfere with other stuff we're interested in.
#
# In that same vein, we remap the GID for sudo from 27 to 25
RUN groupadd --system --gid "${DEF_GID}" "${DEF_GROUP}" && \
    useradd --system --uid "${DEF_UID}" --gid "${DEF_GID}" --home-dir "${HOME}" --shell /sbin/nologin \
        --comment "Default Application User" "${DEF_USER}" && \
    groupdel tape && \
    groupdel floppy && \
    groupmod --gid 25 sudo && \
    chown -R "${DEF_USER}:${DEF_GROUP}" ${APP_ROOT}

# Install gucci
COPY --chown=root:root --chmod=0755 --from=gucci /gucci /usr/local/bin/gucci

# Install step
COPY --chown=root:root --chmod=0755 --from=step /step /usr/local/bin/

# Define the ACM_GROUP
ENV ACM_GROUP="${ACM_GROUP}"
ENV ACM_GID="${ACM_GID}"
RUN groupadd --gid "${ACM_GID}" "${ACM_GROUP}"

# Add the acme-init stuff (only accessible by ACM_GROUP)
COPY --chown=root:${ACM_GROUP} --chmod=0750 acme-init acme-validate expand-urls find-ssl-dirs /usr/local/bin/
COPY --chown=root:root --chmod=0640 00-acme-init /etc/sudoers.d
RUN sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/00-acme-init

# Copy extra files to the image, and fix permissions for sensitive directories
COPY ./core/root/ /

COPY --chown=root:root scripts/ /usr/local/bin
RUN chmod a+rX /usr/local/bin/*

# Add the common-use functions
COPY --chown=root:root --chmod=0444 functions /.functions

# STIG Remediations
COPY --chown=root:root stig/ /usr/share/stig/
RUN cd /usr/share/stig && ./run-all

# Enable FIPS (can't do this yet ... need to wait for Ubuntu Pro!)
# RUN fips-mode-setup --enable

ENV CURL_HOME="/etc/curl"
COPY --chown=root:root --chmod=0644 curlrc "${CURL_HOME}/.curlrc"

COPY --chown=root:root --chmod=0755 apply-fixes /usr/local/bin/

RUN mkdir -p "${BASE_DIR}" "${CONF_DIR}" "${DATA_DIR}" "${LOGS_DIR}" "${TEMP_DIR}" && \
    chmod -R ug=rwX,o= "${TEMP_DIR}"

# FINAL STEP: ensure all sensitive directories are duly protected
RUN secure-permissions

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR "${HOME}"

ENTRYPOINT [ "container-entrypoint" ]
CMD [ "base-usage" ]
