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

ARG PRIVATE_REGISTRY
ARG VER="8"
ARG ARCH="x86_64"
ARG OS="linux"
ARG PKG="base"
ARG PLATFORM="el8"
ARG ACM_GID="10000"
ARG ACM_GROUP="acm"

# ARG BASE_REPO="registry.stage.redhat.io/ubi8/ubi"
ARG BASE_REPO="docker.io/rockylinux"
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

#
# Based on https://catalog.redhat.com/software/containers/ubi8/s2i-core/5c83967add19c77a15918c27?container-tabs=dockerfile
# ( Click Cancel whe it prompts you to login )
#

ENV STI_SCRIPTS_PATH="/usr/libexec/s2i"
ENV STI_SCRIPTS_URL="image://${STI_SCRIPTS_PATH}"
ENV APP_ROOT="/opt/app"
ENV HOME="${APP_ROOT}/src" \
    PATH="${APP_ROOT}/src/bin:${APP_ROOT}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    PLATFORM="${PLATFORM}"

ENV SUMMARY="Base image which allows using of source-to-image." \
    DESCRIPTION="The s2i-core image provides any images layered on top of it \
with all the tools needed to use source-to-image functionality while keeping \
the image size as small as possible."

LABEL summary="${SUMMARY}" \
      description="${DESCRIPTION}" \
      io.k8s.description="${DESCRIPTION}" \
      io.k8s.display-name="s2i core" \
      io.openshift.s2i.scripts-url="image://${STI_SCRIPTS_PATH}" \
      io.s2i.scripts-url="image://${STI_SCRIPTS_PATH}" \
      com.redhat.component="s2i-core-container" \
      name="ubi8/s2i-core" \
      version="1" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"

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

# This is the list of basic dependencies that all language container image can
# consume.
# Also setup the 'openshift' user that is used for the build execution and for the
# application runtime execution.
# TODO: Use better UID and GID values

RUN mkdir -p "${HOME}/.pki/nssdb" && \
    chown -R "${DEF_UID}:${DEF_GID}" "${HOME}/.pki" && \
    yum -y update && \
    yum -y install --setopt=tsflags=nodocs \
        authselect \
        bsdtar \
        crypto-policies-scripts \
        findutils \
        gettext \
        glibc-langpack-en \
        glibc-locale-source \
        groff-base \
        jq \
        openssl \
        python3-pyyaml \
        python3-pip \
        rsync \
        scl-utils \
        sudo \
        tar \
        tzdata-java \
        unzip \
        wget \
        xmlstarlet \
        xz \
    && \
    yum -y clean all --enablerepo='*' && \
    update-alternatives --set python /usr/bin/python3

# Copy extra files to the image.
COPY ./core/root/ /

# Reset permissions of modified directories and add default user
RUN rpm-file-permissions && \
    groupadd --system --gid "${DEF_GID}" "${DEF_GROUP}" && \
    useradd --system --uid "${DEF_UID}" --gid "${DEF_GID}" --home-dir "${HOME}" --shell /sbin/nologin \
        --comment "Default Application User" "${DEF_USER}" && \
    chown -R "${DEF_USER}:${DEF_GROUP}" ${APP_ROOT} && \
    mkdir -p "${BASE_DIR}"

COPY --chown=root:root scripts/ /usr/local/bin
RUN chmod a+rX /usr/local/bin/*

COPY --chown=root:root --chmod=0755 --from=gucci /gucci /usr/local/bin/gucci

ENV ACM_GROUP="${ACM_GROUP}"
ENV ACM_GID="${ACM_GID}"
RUN groupadd --gid "${ACM_GID}" "${ACM_GROUP}"

# Install STEP
COPY --chown=root:root --chmod=0755 --from=step /step /usr/local/bin/

# Copy the STIG file so it can be consumed by the scanner
RUN yum -y install scap-security-guide && \
    cp -vf "/usr/share/xml/scap/ssg/content/ssg-rl8-ds.xml" "/ssg-ds.xml" && \
    yum -y remove scap-security-guide && \
    yum -y clean all

# Add the acme-init stuff (only accessible by ACM_GROUP)
COPY --chown=root:${ACM_GROUP} acme-init acme-validate expand-urls /usr/local/bin/
COPY --chown=root:root 00-acme-init /etc/sudoers.d
RUN chmod 0640 /etc/sudoers.d/00-acme-init && \
    chmod 0750 /usr/local/bin/acme-init /usr/local/bin/acme-validate /usr/local/bin/expand-urls && \
    sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/00-acme-init

# Add the common-use functions
COPY --chown=root:root functions /.functions
RUN chmod 0444 /.functions

# STIG Remediations
RUN authselect select minimal --force
COPY --chown=root:root stig/ /usr/share/stig/
RUN cd /usr/share/stig && ./run-all

# Enable FIPS
RUN fips-mode-setup --enable

ENV CURL_HOME="/etc/curl"
COPY --chown=root:root curlrc "${CURL_HOME}/.curlrc"
RUN chmod a=r "${CURL_HOME}/.curlrc"

COPY --chown=root:root --chmod=0755 apply-fixes /usr/local/bin/

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR "${HOME}"

ENTRYPOINT [ "container-entrypoint" ]
CMD [ "base-usage" ]

###########################################################################################################
#   END: Base Image simliar to simliar to registry.access.redhat.com/ubi8/s2i-core:latest #################
###########################################################################################################
