FROM microsoft/dotnet:2.1-runtime-alpine

RUN apk add --no-cache curl bash rsync

RUN curl -L -o azcopy.tar.gz \
    https://aka.ms/downloadazcopyprlinux \
    && tar -xf azcopy.tar.gz && rm -f azcopy.tar.gz \
    && ./install.sh && rm -f install.sh \
    && rm -rf azcopy

COPY . .
RUN chmod u+x backup.sh
CMD ["./backup.sh"]