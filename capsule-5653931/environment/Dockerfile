FROM nvidia/cuda:11.7.1-cudnn8-runtime-ubuntu20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        fontconfig=2.13.1-2ubuntu3 \
        fonts-freefont-ttf=20120503-10 \
        libgl1=1.3.2-1~ubuntu0.20.04.2 \
        libglib2.0-0=2.64.6-1~ubuntu20.04.9 \
        wget=1.20.3-1ubuntu2.1 \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-wheel \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install -U --no-cache-dir \
    jupyter==1.1.1 \
    matplotlib==3.7.5 \
    numpy==1.24.4 \
    opencv-python==4.12.0.88 \
    pillow==10.4.0 \
    protobuf==3.20.0 \
    scikit-learn==1.3.2 \
    tensorflow==2.8.0 \
    tqdm==4.67.1

COPY fonts/ /tmp/fonts/
COPY postInstall /
RUN chmod +x /postInstall
RUN /postInstall
