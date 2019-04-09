#!/bin/bash
BACKUP_NAME="backup-`date +%Y-%m-%d-%H-%M`"
end=`date -d "30 minutes" '+%Y-%m-%dT%H:%M:%SZ'`

endpoint="blob.core.windows.net"
azCommand="container"

if [ "$TARGET_MODE" == "FILES" ]; then
    endpoint="file.core.windows.net"
    azCommand="share"
fi


#make sure source container exists
az storage $azCommand create -n $SOURCE_CONTAINER --account-key $SOURCE_KEY --account-name $SOURCE_NAME
#make sure dest container exists
#unfortunately, recursively copying from file-share to file-share doesn't work. See https://github.com/Azure/azure-storage-azcopy/issues/248#issuecomment-481204287
az storage container create -n $SOURCE_CONTAINER-$BACKUP_NAME --account-key $DESTINATION_KEY --account-name $DESTINATION_NAME

SOURCE_SAS=$(az storage $azCommand generate-sas -n $SOURCE_CONTAINER --account-key $SOURCE_KEY --account-name $SOURCE_NAME --https-only --permissions dlrw --expiry $end -otsv)
DESTINATION_SAS=$(az storage container generate-sas -n $SOURCE_CONTAINER-$BACKUP_NAME --account-key $DESTINATION_KEY --account-name $DESTINATION_NAME --https-only --permissions dlrw --expiry $end -otsv)
azcopy cp "https://$SOURCE_NAME.$endpoint/$SOURCE_CONTAINER?$SOURCE_SAS" "https://$DESTINATION_NAME.blob.core.windows.net/$SOURCE_CONTAINER-$BACKUP_NAME?$DESTINATION_SAS" --recursive=true