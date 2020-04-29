ARG AZURE_CLI_VERSION=2.5.0

FROM golang:1.14.2-buster as azcopy

RUN go get -u github.com/Azure/azure-storage-azcopy
WORKDIR /go/src/github.com/Azure/azure-storage-azcopy
RUN git checkout tags/v10.4.1
ENV GOOS linux
ENV GARCH amd64
ENV CGO_ENABLED 0
RUN go install -v -a -installsuffix cgo

# Install az CLI using PIP
FROM debian:buster-20191118-slim as azure-cli-pip
ARG AZURE_CLI_VERSION
RUN apt-get update
RUN apt-get install -y python3=3.7.3-1 --no-install-recommends
RUN apt-get install -y python3-pip=18.1-5
RUN pip3 install azure-cli==${AZURE_CLI_VERSION}
RUN pip3 uninstall -y pyOpenSSL cryptography
RUN pip3 install pyOpenSSL==19.1.0
RUN pip3 install cryptography==2.8

# Build final image
FROM debian:buster-20191118-slim

LABEL maintainer="Jorrit Elfferich <jorrit@elfferi.ch>"
LABEL description="A simple debian container you can use to backup azure storage accounts."
LABEL attribution="Heavily inspired by https://github.com/hyperized/docker-azcopy-alpine and https://github.com/Zenika/terraform-azure-cli"

ENV PYTHON_MAJOR_VERSION=3.7
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates=20190110 \
    git=1:2.20.1-2+deb10u1 \
    python3=${PYTHON_MAJOR_VERSION}.3-1 \
    jq=1.5+dfsg-2+b1 \
    python3-distutils=${PYTHON_MAJOR_VERSION}.3-1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_MAJOR_VERSION} 1
COPY --from=azcopy /go/bin/azure-storage-azcopy /usr/local/bin/azcopy
COPY --from=azure-cli-pip /usr/local/bin/az* /usr/local/bin/
COPY --from=azure-cli-pip /usr/local/lib/python${PYTHON_MAJOR_VERSION}/dist-packages /usr/local/lib/python${PYTHON_MAJOR_VERSION}/dist-packages
COPY --from=azure-cli-pip /usr/lib/python3/dist-packages /usr/lib/python3/dist-packages
WORKDIR /workspace
COPY . .
RUN chmod u+x backup.sh
CMD ["./backup.sh"]
