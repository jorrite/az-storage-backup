#!/bin/bash
set -e

blob_enabled=$(dig +short $SOURCE_STORAGE_ACCOUNT_NAME.blob.core.windows.net)
file_enabled=$(dig +short $SOURCE_STORAGE_ACCOUNT_NAME.file.core.windows.net)

container="$SOURCE_STORAGE_ACCOUNT_NAME"
directory="$BACKUP_FREQUENCY"
sub_directory="`date +%Y-%m-%d-%H-%M`"


backup() {
    path=""
    source=""
    endpoint=""
    case "$1" in
        files)
            path="$1/$directory/$sub_directory"
            services="f"
            endpoint="file.core.windows.net"
            ;;
        
        blobs)
            path="$1/$directory/$sub_directory"
            services="b"
            endpoint="blob.core.windows.net"
            ;;    
    esac
    
    end=$(date -d@"$(( `date +%s`+120*60))" '+%Y-%m-%dT%H:%M:%SZ')
    SOURCE_SAS=$(az storage account generate-sas --services $services --resource-types sco --account-key $SOURCE_STORAGE_ACCOUNT_KEY --account-name $SOURCE_STORAGE_ACCOUNT_NAME --https-only --permissions dlrw --expiry $end -otsv)
    DESTINATION_SAS=$(az storage account generate-sas --services b --resource-types sco --account-key $DESTINATION_STORAGE_ACCOUNT_KEY --account-name $DESTINATION_STORAGE_ACCOUNT_NAME --https-only --permissions dlrw --expiry $end -otsv)
    azcopy cp "https://$SOURCE_STORAGE_ACCOUNT_NAME.$endpoint/?$SOURCE_SAS" "https://$DESTINATION_STORAGE_ACCOUNT_NAME.blob.core.windows.net/$container/$path?$DESTINATION_SAS" --recursive=true
}

rotate () {
    if [[ -z "${BACKUP_RETENTION_COUNT}" ]]; then
        echo "retention not set, skipping backup rotation"
    else
        # tail -n +X starts from Xth line, so add 1
        BACKUP_RETENTION_COUNT=$((BACKUP_RETENTION_COUNT+1))
        rotate_dirs=($(az storage blob directory list --account-key $DESTINATION_STORAGE_ACCOUNT_KEY --account-name $DESTINATION_STORAGE_ACCOUNT_NAME -c $container -d "$1/$directory" -o json --delimiter '/' | jq -r 'sort_by(.name) | reverse | .[].name' | tail -n +${BACKUP_RETENTION_COUNT}))
        for k in "${rotate_dirs[@]}"
        do
            echo "deleting ${k%/} ..."
            az storage blob directory delete --account-key $DESTINATION_STORAGE_ACCOUNT_KEY --account-name $DESTINATION_STORAGE_ACCOUNT_NAME -c $container -d ${k%/} --recursive
        done
    fi
}

az storage container create \
    -n $container \
    --account-key $DESTINATION_STORAGE_ACCOUNT_KEY \
    --account-name $DESTINATION_STORAGE_ACCOUNT_NAME 

if [[ ! -z "$file_enabled" ]]; then
    backup "files"
    rotate "files"
fi

if [[ ! -z "$blob_enabled" ]]; then
    backup "blobs"
    rotate "blobs"
fi
