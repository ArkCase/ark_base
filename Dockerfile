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
ARG STEP_VER="0.28.7"
ARG STEP_SRC="https://github.com/smallstep/cli/releases/download/v${STEP_VER}/step-cli_amd64.rpm"

ARG BC_GROUP="org.bouncycastle"

ARG BC_PKIX_GROUP="${BC_GROUP}"
ARG BC_PKIX="bcpkix-fips"
ARG BC_PKIX_VER="2.0.10"
ARG BC_PKIX_SRC="${BC_PKIX_GROUP}:${BC_PKIX}:${BC_PKIX_VER}:jar"

ARG BC_PROV_GROUP="${BC_GROUP}"
ARG BC_PROV="bc-fips"
ARG BC_PROV_VER="2.0.1"
ARG BC_PROV_SRC="${BC_PROV_GROUP}:${BC_PROV}:${BC_PROV_VER}:jar"

ARG BC_TLS_GROUP="${BC_GROUP}"
ARG BC_TLS="bctls-fips"
ARG BC_TLS_VER="2.0.22"
ARG BC_TLS_SRC="${BC_TLS_GROUP}:${BC_TLS}:${BC_TLS_VER}:jar"

ARG BC_UTIL_GROUP="${BC_GROUP}"
ARG BC_UTIL="bcutil-fips"
ARG BC_UTIL_VER="2.0.5"
ARG BC_UTIL_SRC="${BC_UTIL_GROUP}:${BC_UTIL}:${BC_UTIL_VER}:jar"

# ARG BASE_REPO="registry.stage.redhat.io/ubi8/ubi"
ARG BASE_REPO="docker.io/rockylinux"
ARG BASE_IMG="${BASE_REPO}:${VER}"

ARG GUCCI_REPO="arkcase/gucci"
ARG GUCCI_TAG="latest"
ARG GUCCI_IMG="${PRIVATE_REGISTRY}/${GUCCI_REPO}:${GUCCI_TAG}"

FROM "${GUCCI_IMG}" AS gucci

FROM "${BASE_IMG}"

ARG OS_VERSION
ARG VER
ARG ARCH
ARG OS
ARG PKG
ARG PLATFORM
ARG ACM_GROUP
ARG ACM_GID
ARG STEP_SRC
ARG BC_PKIX
ARG BC_PKIX_SRC
ARG BC_PROV
ARG BC_PROV_SRC
ARG BC_TLS
ARG BC_TLS_SRC
ARG BC_UTIL
ARG BC_UTIL_SRC

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

ARG BASE_DIR="/app"
ENV BASE_DIR="${BASE_DIR}"

# This is the list of basic dependencies that all language container image can
# consume.
# Also setup the 'openshift' user that is used for the build execution and for the
# application runtime execution.
# TODO: Use better UID and GID values

RUN mkdir -p "${HOME}/.pki/nssdb" && \
    chown -R 1001:0 "${HOME}/.pki" && \
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
    useradd -u 1001 -r -g 0 -d "${HOME}" -s /sbin/nologin \
        -c "Default Application User" default && \
    chown -R 1001:0 ${APP_ROOT} && \
    mkdir -p "${BASE_DIR}"

COPY --chown=root:root scripts/ /usr/local/bin
RUN chmod a+rX /usr/local/bin/*

COPY --chown=root:root --chmod=0755 --from=gucci /gucci /usr/local/bin/gucci

ENV ACM_GROUP="${ACM_GROUP}"
ENV ACM_GID="${ACM_GID}"
RUN groupadd --gid "${ACM_GID}" "${ACM_GROUP}"

# Install STEP
RUN yum -y install "${STEP_SRC}" && \
    yum -y clean all

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
ENV CRYPTO_DIR="${BASE_DIR}/crypto"
ENV BC_DIR="${CRYPTO_DIR}/bc"
ENV BC_PKIX_JAR="${BC_DIR}/${BC_PKIX}.jar"
ENV BC_PROV_JAR="${BC_DIR}/${BC_PROV}.jar"
ENV BC_TLS_JAR="${BC_DIR}/${BC_TLS}.jar"
ENV BC_UTIL_JAR="${BC_DIR}/${BC_UTIL}.jar"
RUN mkdir -p "${CRYPTO_DIR}" \
    && mvn-get "${BC_PKIX_SRC}" "${BC_PKIX_JAR}" \
    && mvn-get "${BC_PROV_SRC}" "${BC_PROV_JAR}" \
    && mvn-get "${BC_TLS_SRC}" "${BC_TLS_JAR}" \
    && mvn-get "${BC_UTIL_SRC}" "${BC_UTIL_JAR}"

ENV CURL_HOME="/etc/curl"
COPY --chown=root:root curlrc "${CURL_HOME}/.curlrc"
RUN chmod a=r "${CURL_HOME}/.curlrc"

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR "${HOME}"

ENTRYPOINT [ "container-entrypoint" ]
CMD [ "base-usage" ]

###########################################################################################################
#   END: Base Image simliar to simliar to registry.access.redhat.com/ubi8/s2i-core:latest #################
###########################################################################################################
