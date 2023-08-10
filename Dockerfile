# When we are ready to switch to RHEL, this image will be replaced with registry.access.redhat.com/ubi8/s2i-core:latest

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

###########################################################################################################
# START: Base Image simliar to registry.access.redhat.com/ubi8/s2i-core:latest ############################
###########################################################################################################

ARG OS_VERSION="8.7"
ARG VER="${OS_VERSION}.0"
ARG ARCH="x86_64"
ARG OS="linux"
ARG PKG="base"
# ARG SRC_IMAGE="registry.stage.redhat.io/ubi8/ubi"
ARG SRC_IMAGE="docker.io/rockylinux"
ARG PLATFORM="el8"
ARG GUCCI_VER="1.6.10"
ARG GUCCI_SRC="https://github.com/noqcks/gucci/releases/download/${GUCCI_VER}/gucci-v${GUCCI_VER}-linux-amd64"

FROM "${SRC_IMAGE}:${OS_VERSION}"

ARG OS_VERSION
ARG VER
ARG ARCH
ARG OS
ARG PKG
ARG PLATFORM
ARG GUCCI_SRC

#
# Based on https://catalog.redhat.com/software/containers/ubi8/s2i-core/5c83967add19c77a15918c27?container-tabs=dockerfile
# ( Click Cancel whe it prompts you to login )
#

ENV SUMMARY="Base image which allows using of source-to-image." \
    DESCRIPTION="The s2i-core image provides any images layered on top of it \
with all the tools needed to use source-to-image functionality while keeping \
the image size as small as possible."

LABEL summary="${SUMMARY}" \
      description="${DESCRIPTION}" \
      io.k8s.description="${DESCRIPTION}" \
      io.k8s.display-name="s2i core" \
      io.openshift.s2i.scripts-url=image:///usr/libexec/s2i \
      io.s2i.scripts-url=image:///usr/libexec/s2i \
      com.redhat.component="s2i-core-container" \
      name="ubi8/s2i-core" \
      version="1" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"

LABEL ORG="ArkCase LLC"
LABEL MAINTAINER="ArkCase Support <support@arkcase.com>"
LABEL APP="Base"
LABEL VERSION="${VER}"

ENV \
    STI_SCRIPTS_URL="image:///usr/libexec/s2i" \
    STI_SCRIPTS_PATH="/usr/libexec/s2i" \
    APP_ROOT="/opt/app-root" \
    HOME="/opt/app-root/src" \
    PATH="/opt/app-root/src/bin:/opt/app-root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    PLATFORM="${PLATFORM}"

# This is the list of basic dependencies that all language container image can
# consume.
# Also setup the 'openshift' user that is used for the build execution and for the
# application runtime execution.
# TODO: Use better UID and GID values

RUN mkdir -p "${HOME}/.pki/nssdb" && \
    chown -R 1001:0 "${HOME}/.pki" && \
    yum -y install --setopt=tsflags=nodocs \
        bsdtar \
        findutils \
        gettext \
        glibc-langpack-en \
        glibc-locale-source \
        groff-base \
        jq \
        python3-pyyaml \
        python3-pip \
        rsync \
        scl-utils \
        tar \
        tzdata-java \
        unzip \
        wget \
        xz \
    && \
    yum -y update && \
    yum -y clean all --enablerepo='*' && \
    update-alternatives --set python /usr/bin/python3

# Copy extra files to the image.
COPY ./core/root/ /

# Reset permissions of modified directories and add default user
RUN rpm-file-permissions && \
    useradd -u 1001 -r -g 0 -d "${HOME}" -s /sbin/nologin \
        -c "Default Application User" default && \
    chown -R 1001:0 ${APP_ROOT}

RUN curl -kL --fail -o "/usr/local/bin/gucci" "${GUCCI_SRC}" && \
    chown root:root "/usr/local/bin/gucci" && \
    chmod u=rwx,go=rx "/usr/local/bin/gucci"

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR "${HOME}"

ENTRYPOINT [ "container-entrypoint" ]
CMD [ "base-usage" ]

###########################################################################################################
#   END: Base Image simliar to simliar to registry.access.redhat.com/ubi8/s2i-core:latest #################
###########################################################################################################
