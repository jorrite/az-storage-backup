FROM golang:alpine as builder

LABEL maintainer="Jorrit Elfferich <jorrit@elfferi.ch>"
LABEL description="A simple Alpine container you can use to backup azure storage accounts."
LABEL attribution="Heavily inspired by https://github.com/hyperized/docker-azcopy-alpine"

RUN apk add --no-cache git && rm -rf /var/cache/apk/*
RUN go get -u github.com/Azure/azure-storage-azcopy
WORKDIR /go/src/github.com/Azure/azure-storage-azcopy
ENV GOOS linux
ENV GARCH amd64
ENV CGO_ENABLED 0
RUN go install -v -a -installsuffix cgo

FROM alpine
COPY --from=builder /go/bin/azure-storage-azcopy /usr/local/bin/azcopy
RUN apk add --no-cache ca-certificates && rm -rf /var/cache/apk/*
RUN apk update
RUN apk add make bash py-pip jq coreutils
RUN apk add --virtual=build gcc libffi-dev musl-dev openssl-dev python-dev
RUN pip install azure-cli
RUN apk del --purge build

COPY . .
RUN chmod u+x backup.sh
CMD ["./backup.sh"]