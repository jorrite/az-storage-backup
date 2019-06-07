FROM debian:jessie

RUN apt-get update \
    && apt-get install curl apt-transport-https lsb-release rsync gnupg libunwind-dev libicu-dev jq -y

RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
RUN AZ_REPO=$(lsb_release -cs) \
    && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    tee /etc/apt/sources.list.d/azure-cli.list

RUN apt-get update && apt-get install azure-cli -y
RUN mkdir azcopy \
    && curl -L -o azcopy.tar.gz \
    https://aka.ms/downloadazcopy-v10-linux \
    && tar -xf azcopy.tar.gz -C azcopy --strip-components=1 && rm -f azcopy.tar.gz \
    && ln -s /azcopy/azcopy /usr/bin/azcopy

COPY . .
RUN chmod u+x backup.sh
CMD ["./backup.sh"]