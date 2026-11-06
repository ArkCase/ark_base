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

ARG FIPS=""
ARG PRIVATE_REGISTRY
ARG VER="24.04"
ARG ARCH="x86_64"
ARG OS="linux"
ARG PKG="base"
ARG PLATFORM="ubuntu${FIPS}:${VER}"
ARG ACM_GID="10000"
ARG ACM_GROUP="acm"

ARG BASE_REGISTRY="${PRIVATE_REGISTRY}"
ARG BASE_REPO="arkcase/ubuntu"
ARG BASE_VER="${VER}"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}${FIPS}:${BASE_VER_PFX}${BASE_VER}"

ARG SCRIPTS_REGISTRY="${BASE_REGISTRY}"
ARG SCRIPTS_REPO="arkcase/base-container-scripts"
ARG SCRIPTS_VER="latest"
ARG SCRIPTS_VER_PFX="${BASE_VER_PFX}"
ARG SCRIPTS_IMG="${SCRIPTS_REGISTRY}/${SCRIPTS_REPO}${FIPS}:${SCRIPTS_VER_PFX}${SCRIPTS_VER}"

ARG STEP_REGISTRY="${PRIVATE_REGISTRY}"
ARG STEP_REPO="arkcase/rebuild-step-ca"
ARG STEP_VER="0.30.2"
ARG STEP_VER_PFX="${BASE_VER_PFX}"
ARG STEP_IMG="${STEP_REGISTRY}/${STEP_REPO}${FIPS}:${STEP_VER_PFX}${STEP_VER}"

FROM "${SCRIPTS_IMG}" AS scripts

ARG STEP_IMG

FROM "${STEP_IMG}" AS step

ARG BASE_IMG

FROM "${BASE_IMG}"

ARG OS_VERSION
ARG VER
ARG ARCH
ARG OS
ARG PKG
ARG PLATFORM
ARG FIPS
ARG ACM_GROUP
ARG ACM_GID

ENV APP_ROOT="/opt/app"
ENV HOME="${APP_ROOT}/src"
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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

# Reset permissions of modified directories and add default user. We remove the "tape"
# and "floppy" groups because they can interfere with other stuff we're interested in.
#
# In that same vein, we remap the GID for sudo from 27 to 25
ENV ACM_GROUP="${ACM_GROUP}"
ENV ACM_GID="${ACM_GID}"

# Configure curl
ENV CURL_HOME="/etc/curl"

ENV DEFAULT_ENTRYPOINT "/usr/local/bin/entrypoint"

RUN --mount=type=bind,target=/src \
    --mount=type=bind,from=scripts,target=/scripts \
    --mount=type=bind,from=step,target=/step \
    mkdir -p "${HOME}/.pki/nssdb" && \
    echo "${LANG} ${CHARSET}" > /etc/locale.gen && \
    echo "LANG=${LANG}" > /etc/default/locale && \
    userdel --remove ubuntu && \
    chown -R "${DEF_UID}:${DEF_GID}" "${HOME}/.pki" && \
    apt-get update && \
    apt-get -y install \
        acl \
        apt-transport-https \
        attr \
        bash-completion \
        bind9-utils \
        bzip2 \
        curl \
        dnsutils \
        findutils \
        gettext-base \
        gpg \
        inotify-tools \
        jq \
        libpam-modules \
        libpam-pwquality \
        libpam-runtime \
        libxml2-utils \
        locales \
        lsb-release \
        openssl \
        patch \
        python-is-python3 \
        python3 \
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
    apt-get clean && \
    mkdir -p "${HOME}" && \
    groupadd --gid "${DEF_GID}" "${DEF_GROUP}" && \
    useradd --uid "${DEF_UID}" --gid "${DEF_GID}" --home-dir "${HOME}" --shell /sbin/nologin \
        --comment "Default Application User" "${DEF_USER}" && \
    groupdel tape && \
    groupdel floppy && \
    groupmod --gid 25 sudo && \
    mkdir -p "${HOME}/bin" "${APP_ROOT}/bin" && \
    chown -R "${DEF_USER}:${DEF_GROUP}" "${APP_ROOT}" "${HOME}" && \
    chmod -R u=rwX,g=rX,o=X "${APP_ROOT}" "${HOME}" && \
    groupadd --gid "${ACM_GID}" "${ACM_GROUP}" && \
    ( cd /src/core/root && tar --owner=root --group=root --mode=u=rwX,go=rX -cf - . ) | tar -C / -xvf - && \
    ( cd /src/scripts && tar --owner=root --group="${ACM_GROUP}" --mode=u=rwX,g=rX,o= -cf - . ) | tar -C /usr/local/bin -xvf - && \
    sed -e "s;\${ACM_GROUP};${ACM_GROUP};g" < /src/00-ssl-init > /etc/sudoers.d/00-ssl-init && \
    chmod 0440 /etc/sudoers.d/00-ssl-init && \
    mkdir -p "${BASE_DIR}" "${CONF_DIR}" "${DATA_DIR}" "${LOGS_DIR}" "${TEMP_DIR}" && \
    chmod -R ug=rwX,o= "${TEMP_DIR}" && \
    ( cd /scripts && tar --owner=root --group=root --mode=u=rwX,go=rX -cf - . ) | tar -C / -xvf - && \
    chmod 0444 /.functions && \
    mkdir -p "${CURL_HOME}" && \
    cp /src/curlrc "${CURL_HOME}/.curlrc" && \
    chown -R root:root "${CURL_HOME}" && \
    chmod u=rwX,go=rX "${CURL_HOME}" && \
    install -o root -g root -m 0755 /step/step /usr/local/bin && \
    run-stig /src/stig && \
    secure-permissions

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR "${HOME}"

ENTRYPOINT [ "/entrypoint" ]
