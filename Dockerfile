FROM golang:alpine as builder

RUN apk add --no-cache git && rm -rf /var/cache/apk/*
RUN go get -u github.com/Azure/azure-storage-azcopy
WORKDIR /go/src/github.com/Azure/azure-storage-azcopy
RUN git checkout tags/v10.5.0
ENV GOOS linux
ENV GARCH amd64
ENV CGO_ENABLED 0
RUN go install -v -a -installsuffix cgo

FROM mcr.microsoft.com/azure-cli:2.8.0

COPY --from=builder /go/bin/azure-storage-azcopy /usr/local/bin/azcopy
RUN apk add --no-cache tini jq bind
RUN az extension add --name storage-preview

WORKDIR /app

COPY backup.sh .

ENV BACKUP_FREQUENCY "default"
ENV SOURCE_STORAGE_ACCOUNT_NAME ""
ENV SOURCE_STORAGE_ACCOUNT_KEY ""
ENV DESTINATION_STORAGE_ACCOUNT_NAME ""
ENV DESTINATION_STORAGE_ACCOUNT_KEY ""
ENV BACKUP_RETENTION_COUNT ""
# mode can be FULL or SYNC
ENV MODE "" 

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/backup.sh"]