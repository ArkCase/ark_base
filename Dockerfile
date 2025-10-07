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
ARG VER="22.04"
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

ARG GUCCI_REGISTRY="${PRIVATE_REGISTRY}"
ARG GUCCI_REPO="arkcase/rebuild-gucci"
ARG GUCCI_TAG="latest"
ARG GUCCI_IMG="${GUCCI_REGISTRY}/${GUCCI_REPO}:${GUCCI_TAG}"

ARG STEP_REBUILD_REGISTRY="${PRIVATE_REGISTRY}"
ARG STEP_REBUILD_REPO="arkcase/rebuild-step-ca"
ARG STEP_REBUILD_TAG="latest"
ARG STEP_REBUILD_IMG="${STEP_REBUILD_REGISTRY}/${STEP_REBUILD_REPO}:${STEP_REBUILD_TAG}"

FROM "${GUCCI_IMG}" AS gucci

FROM "${STEP_REBUILD_IMG}" AS step

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

ENV DEF_USER="default"
ENV DEF_UID="1001"
ENV DEF_GROUP="${DEF_USER}"
ENV DEF_GID="${DEF_UID}"

RUN mkdir -p "${HOME}/.pki/nssdb" && \
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
        jq \
        libpam-pwquality \
        libxml2-utils \
        openssl \
        python-is-python3 \
        python3 \
        python3-pip \
        sudo \
        tar \
        unzip \
        wget \
        xmlstarlet \
        xz-utils \
      && \
    apt-get clean

# Reset permissions of modified directories and add default user
RUN groupadd --system --gid "${DEF_GID}" "${DEF_GROUP}" && \
    useradd --system --uid "${DEF_UID}" --gid "${DEF_GID}" --home-dir "${HOME}" --shell /sbin/nologin \
        --comment "Default Application User" "${DEF_USER}" && \
    chown -R "${DEF_USER}:${DEF_GROUP}" ${APP_ROOT} && \
    mkdir -p "${BASE_DIR}"

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

# FINAL STEP: ensure all sensitive directories are duly protected
RUN secure-permissions

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR "${HOME}"

ENTRYPOINT [ "container-entrypoint" ]
CMD [ "base-usage" ]
