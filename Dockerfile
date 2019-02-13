FROM alpine:3.9

RUN apk add --no-cache curl bash rsync

RUN curl -L -o azcopy.tar.gz \
    https://aka.ms/downloadazcopylinux64 \
    && tar -xf azcopy.tar.gz && rm -f azcopy.tar.gz \
    && ./install.sh && rm -f install.sh \
    && rm -rf azcopy

COPY . .
RUN chmod u+x backup.sh
CMD ["./backup.sh"]