FROM mcr.microsoft.com/azure-cli:2.7.0

RUN apk add --no-cache tini jq bind
RUN az extension add --name storage-preview
RUN chmod +x /root/.azure/cliextensions/storage-preview/azext_storage_preview/azcopy/azcopy_linux_amd64_10.3.1/azcopy
RUN ln -s /root/.azure/cliextensions/storage-preview/azext_storage_preview/azcopy/azcopy_linux_amd64_10.3.1/azcopy /usr/local/bin/azcopy

RUN mkdir /app
WORKDIR /app

COPY backup.sh .

ENV BACKUP_FREQUENCY "default"
ENV SOURCE_STORAGE_ACCOUNT_NAME ""
ENV SOURCE_STORAGE_ACCOUNT_KEY ""
ENV DESTINATION_STORAGE_ACCOUNT_NAME ""
ENV DESTINATION_STORAGE_ACCOUNT_KEY ""
ENV BACKUP_RETENTION_COUNT ""

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/app/backup.sh"]