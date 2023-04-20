FROM debian:buster-slim

ARG version=20.0.0.36-1
# In addition to installing the Amazon corretto, we also install
# fontconfig. The folks who manage the docker hub's
# official image library have found that font management
# is a common usecase, and painpoint, and have
# recommended that Java images include font support.
#
# See:
#  https://github.com/docker-library/official-images/blob/master/test/tests/java-uimanager-font/container.java

RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg software-properties-common fontconfig java-common \
    && curl -fL https://apt.corretto.aws/corretto.key | apt-key add - \
    && add-apt-repository 'deb https://apt.corretto.aws stable main' \
    && mkdir -p /usr/share/man/man1 || true \
    && apt-get update \
    && apt-get install -y java-20-amazon-corretto-jdk=1:$version \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
        curl gnupg software-properties-common

ENV LANG C.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/java-20-amazon-corretto


RUN apt-get install -y python3-pip libffi-dev

# add requirements.txt, written this way to gracefully ignore a missing file
COPY requirements.txt .
RUN ([ -f requirements.txt ] \
    && pip3 install --no-cache-dir -r requirements.txt) \
        || pip3 install --no-cache-dir jupyter jupyterlab


RUN apt-get install -y curl 

RUN apt-get install -y unzip

USER root

# Download the kernel release
RUN curl -L https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip > ijava-kernel.zip

# Unpack and install the kernel
RUN unzip ijava-kernel.zip -d ijava-kernel \
  && cd ijava-kernel \
  && python3 install.py --sys-prefix

# Set up the user environment

ENV NB_USER jovyan
ENV NB_UID 1000
ENV HOME /home/$NB_USER

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid $NB_UID \
    $NB_USER

COPY . $HOME
RUN chown -R $NB_UID $HOME


WORKDIR $HOME
RUN curl -L "https://pkgs.dev.azure.com/bnalgo/QuantPublic/_apis/packaging/feeds/3d33c49e-00cf-48e5-a9e3-f44f01fd5db7/maven/uk.co.bnikolic/QuantLib-linux_GLIBC_2.2.5-J11/1.29/QuantLib-linux_GLIBC_2.2.5-J11-1.29.zip/content" > QuantLib.zip
RUN unzip QuantLib.zip
RUN cp *.so*  /usr/lib/x86_64-linux-gnu
RUN mkdir -p  /usr/lib64
RUN cp *.so*  /usr/lib64
RUN cp *.jar /usr/share/jupyter/kernels/java

USER $NB_USER

# Launch the notebook server
WORKDIR $HOME
CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
