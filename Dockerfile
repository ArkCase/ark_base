# When we are ready to switch to RHEL, this image will be replaced with registry.access.redhat.com/ubi8/s2i-core:latest

###########################################################################################################
#
# How to build:
#
# docker build -t 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest .
# docker push 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest
# 
# How to run: (Docker)
#
# docker run --name ark_base -d 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest sleep infinity
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

#FROM registry.stage.redhat.io/ubi8/ubi:8.7
FROM docker.io/rockylinux:8.7

#
# Base on https://catalog.redhat.com/software/containers/ubi8/s2i-core/5c83967add19c77a15918c27?container-tabs=dockerfile
# ( Click Cancel whe it prompts you to login )

ENV SUMMARY="Base image which allows using of source-to-image." \
    DESCRIPTION="The s2i-core image provides any images layered on top of it \
with all the tools needed to use source-to-image functionality while keeping \
the image size as small as possible."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="s2i core" \
      io.openshift.s2i.scripts-url=image:///usr/libexec/s2i \
      io.s2i.scripts-url=image:///usr/libexec/s2i \
      com.redhat.component="s2i-core-container" \
      name="ubi8/s2i-core" \
      version="1" \
      com.redhat.license_terms="https://www.redhat.com/en/about/red-hat-end-user-license-agreements#UBI"

ENV \
    # DEPRECATED: Use above LABEL instead, because this will be removed in future versions.
    STI_SCRIPTS_URL=image:///usr/libexec/s2i \
    # Path to be used in other layers to place s2i scripts into
    STI_SCRIPTS_PATH=/usr/libexec/s2i \
    APP_ROOT=/opt/app-root \
    # The $HOME is not set by default, but some applications needs this variable
    HOME=/opt/app-root/src \
    PATH=/opt/app-root/src/bin:/opt/app-root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PLATFORM="el8"

# This is the list of basic dependencies that all language container image can
# consume.
# Also setup the 'openshift' user that is used for the build execution and for the
# application runtime execution.
# TODO: Use better UID and GID values

RUN INSTALL_PKGS="bsdtar \
  findutils \
  groff-base \
  glibc-locale-source \
  glibc-langpack-en \
  gettext \
  rsync \
  scl-utils \
  tar \
  unzip \
  xz \
  yum" && \
  mkdir -p ${HOME}/.pki/nssdb && \
  chown -R 1001:0 ${HOME}/.pki && \
  yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
  rpm -V $INSTALL_PKGS && \
  yum -y clean all --enablerepo='*'

# Copy extra files to the image.
COPY ./core/root/ /

# Directory with the sources is set as the working directory so all STI scripts
# can execute relative to this path.
WORKDIR ${HOME}

ENTRYPOINT ["container-entrypoint"]
CMD ["base-usage"]

# Reset permissions of modified directories and add default user
RUN rpm-file-permissions && \
  useradd -u 1001 -r -g 0 -d ${HOME} -s /sbin/nologin \
      -c "Default Application User" default && \
  chown -R 1001:0 ${APP_ROOT}

###########################################################################################################
#   END: Base Image simliar to simliar to registry.access.redhat.com/ubi8/s2i-core:latest #################
###########################################################################################################

