#!/bin/bash
set -e

[ -z "$SOURCE_STORAGE_ACCOUNT_NAME" ] && echo -e "\e[31m\$SOURCE_STORAGE_ACCOUNT_NAME is empty\e[0m" && exit 1
[ -z "$SOURCE_STORAGE_ACCOUNT_KEY" ] && echo "e[31m\$SOURCE_STORAGE_ACCOUNT_KEY is empty\e[0m" && exit 1
[ -z "$DESTINATION_STORAGE_ACCOUNT_NAME" ] && echo "e[31m\$DESTINATION_STORAGE_ACCOUNT_NAME is empty\e[0m" && exit 1
[ -z "$DESTINATION_STORAGE_ACCOUNT_KEY" ] && echo "e[31m\$DESTINATION_STORAGE_ACCOUNT_KEY is empty\e[0m" && exit 1
[ "$MODE" != "FULL" ] && [ "$MODE" != "SYNC" ] && echo "e[31m\$MODE should be 'FULL' or 'SYNC'\e[0m" && exit 1

blob_enabled=$(dig +short $SOURCE_STORAGE_ACCOUNT_NAME.blob.core.windows.net)
file_enabled=$(dig +short $SOURCE_STORAGE_ACCOUNT_NAME.file.core.windows.net)

container="$SOURCE_STORAGE_ACCOUNT_NAME"
directory="$BACKUP_FREQUENCY"
sub_directory="`date +%Y-%m-%d-%H-%M`"


get_endpoint() {
    type=$1

    endpoint=""
    case "$type" in
        files)
            endpoint="file.core.windows.net"
            ;;
        
        blobs)
            endpoint="blob.core.windows.net"
            ;;    
    esac

    echo $endpoint
}

get_services() {
    type=$1

    services=""
    case "$type" in
        files)
            services="f"
            ;;
        
        blobs)
            services="b"
            ;;    
    esac

    echo $services
}

get_sas() {
    type=$1
    sa_name=$2
    sa_key=$3

    end=$(sas_end_date)
    services=$(get_services $type)
    sas=$(az storage account generate-sas --services $services --resource-types sco --account-name $sa_name --account-key $sa_key --https-only --permissions dlrw --expiry $end -otsv)

    echo $sas
}

sas_end_date() {
    end=$(date -d@"$(( `date +%s`+120*60))" '+%Y-%m-%dT%H:%M:%SZ')

    echo $end
}

backup() {
    type=$1

    source_endpoint=$(get_endpoint $type)
    destination_endpoint=$(get_endpoint "blobs")
    path="$type/$directory/$sub_directory"
    source_sas=$(get_sas $type $SOURCE_STORAGE_ACCOUNT_NAME $SOURCE_STORAGE_ACCOUNT_KEY)
    destination_sas=$(get_sas "blobs" $DESTINATION_STORAGE_ACCOUNT_NAME $DESTINATION_STORAGE_ACCOUNT_KEY)


    echo -e "\e[32m--- \e[0m"
    echo -e "\e[32m** BACKUP\e[0m"
    echo -e "\e[32m--- \e[0m"
    echo -e "\e[32mSource:\t\t https://$SOURCE_STORAGE_ACCOUNT_NAME.$source_endpoint/\e[0m"
    echo -e "\e[32mDestination:\t https://$DESTINATION_STORAGE_ACCOUNT_NAME.$destination_endpoint/$container/$path\e[0m"
    echo -e "\e[32m--- \e[0m"
    echo ""

    azcopy cp "https://$SOURCE_STORAGE_ACCOUNT_NAME.$source_endpoint/?$source_sas" "https://$DESTINATION_STORAGE_ACCOUNT_NAME.$destination_endpoint/$container/$path?$destination_sas" --recursive=true
}

sync() {
    type=$1
    endpoint=$(get_endpoint $type)
    source_sas=$(get_sas $type $SOURCE_STORAGE_ACCOUNT_NAME $SOURCE_STORAGE_ACCOUNT_KEY)
    destination_sas=$(get_sas $type $DESTINATION_STORAGE_ACCOUNT_NAME $DESTINATION_STORAGE_ACCOUNT_KEY)

    echo -e "\e[32m--- \e[0m"
    echo -e "\e[32m** SYNC\e[0m"
    echo -e "\e[32m--- \e[0m"
    echo -e "\e[32mSource:\t\t https://$SOURCE_STORAGE_ACCOUNT_NAME.$endpoint/\e[0m"
    echo -e "\e[32mDestination:\t https://$DESTINATION_STORAGE_ACCOUNT_NAME.$endpoint/\e[0m"
    echo -e "\e[32m--- \e[0m"
    echo ""

    source_containers_or_shares=""
    if [ "$type" == "blobs" ]; then
        source_containers_or_shares=$(az storage container list --only-show-errors -o json --account-key $SOURCE_STORAGE_ACCOUNT_KEY --account-name $SOURCE_STORAGE_ACCOUNT_NAME --num-results "*" | jq '[.[].name]')
    elif [ "$type" == "files" ]; then
        source_containers_or_shares=$(az storage share list --only-show-errors -o json --account-key $SOURCE_STORAGE_ACCOUNT_KEY --account-name $SOURCE_STORAGE_ACCOUNT_NAME --num-results "*" | jq '[.[].name]')
    fi

    destination_containers_or_shares=""
    if [ "$type" == "blobs" ]; then
        destination_containers_or_shares=$(az storage container list --only-show-errors -o json --account-key $DESTINATION_STORAGE_ACCOUNT_KEY --account-name $DESTINATION_STORAGE_ACCOUNT_NAME --num-results "*" | jq '[.[].name]')
    elif [ "$type" == "files" ]; then
        destination_containers_or_shares=$(az storage share list --only-show-errors -o json --account-key $DESTINATION_STORAGE_ACCOUNT_KEY --account-name $DESTINATION_STORAGE_ACCOUNT_NAME --num-results "*" | jq '[.[].name]')
    fi

    to_be_copied_containers_or_shares=$(echo $source_containers_or_shares | jq --argjson d "$destination_containers_or_shares" '. - $d')
    to_be_removed_containers_or_shares=($(echo $destination_containers_or_shares | jq -r --argjson s "$source_containers_or_shares" '. - $s | .[]'))
    to_be_synced_containers_or_shares=($(echo $source_containers_or_shares | jq -r --argjson c "$to_be_copied_containers_or_shares" '. - $c | .[]'))
    to_be_copied_containers_or_shares=($(echo $source_containers_or_shares | jq -r --argjson d "$destination_containers_or_shares" '. - $d | .[]'))


    for k in "${to_be_copied_containers_or_shares[@]}"
    do
        if [ -z "$k" ]; then
            break
        fi
        echo -e "\e[32m--- \e[0m"
        echo -e "\e[32m** COPY\e[0m"
        echo -e "\e[32m--- \e[0m"
        echo -e "\e[32mSource:\t\t https://$SOURCE_STORAGE_ACCOUNT_NAME.$endpoint/${k%/}\e[0m"
        echo -e "\e[32mDestination:\t https://$DESTINATION_STORAGE_ACCOUNT_NAME.$endpoint/${k%/}\e[0m"
        echo -e "\e[32m--- \e[0m"
        echo ""

        azcopy cp "https://$SOURCE_STORAGE_ACCOUNT_NAME.$endpoint/${k%/}?$source_sas" "https://$DESTINATION_STORAGE_ACCOUNT_NAME.$endpoint/${k%/}?$destination_sas" --recursive=true
    done

    for k in "${to_be_removed_containers_or_shares[@]}"
    do
        if [ -z "$k" ]; then
            break
        fi

        share_or_container=""
        if [ "$type" == "blobs" ]; then
            share_or_container="Container:\t"
        elif [ "$type" == "files" ]; then
            share_or_container="Share:\t\t"
        fi
        echo -e "\e[32m--- \e[0m"
        echo -e "\e[32m** REMOVE\e[0m"
        echo -e "\e[32m--- \e[0m"
        echo -e "\e[32m$share_or_container https://$DESTINATION_STORAGE_ACCOUNT_NAME.$endpoint/${k%/} ... \e[0m"
        echo -e "\e[32m--- \e[0m"
        echo ""

        if [ "$type" == "blobs" ]; then
            az storage container delete --only-show-errors --account-key $DESTINATION_STORAGE_ACCOUNT_KEY --account-name $DESTINATION_STORAGE_ACCOUNT_NAME -n ${k%/}
            echo ""
        elif [ "$type" == "files" ]; then
            az storage share delete --only-show-errors --account-key $DESTINATION_STORAGE_ACCOUNT_KEY --account-name $DESTINATION_STORAGE_ACCOUNT_NAME  -n ${k%/}
            echo ""
        fi
    done

    for k in "${to_be_synced_containers_or_shares[@]}"
    do
        if [ -z "$k" ]; then
            break
        fi
        echo -e "\e[32m--- \e[0m"
        echo -e "\e[32m** SYNC\e[0m"
        echo -e "\e[32m--- \e[0m"
        echo -e "\e[32mSource:\t\t https://$SOURCE_STORAGE_ACCOUNT_NAME.$endpoint/${k%/}\e[0m"
        echo -e "\e[32mDestination:\t https://$DESTINATION_STORAGE_ACCOUNT_NAME.$endpoint/${k%/}\e[0m"
        echo -e "\e[32m--- \e[0m"
        echo ""

        azcopy sync "https://$SOURCE_STORAGE_ACCOUNT_NAME.$endpoint/${k%/}?$source_sas" "https://$DESTINATION_STORAGE_ACCOUNT_NAME.$endpoint/${k%/}?$destination_sas" --recursive=true --delete-destination=true
    done
}

rotate () {
    type=$1
    
    if [[ -z "${BACKUP_RETENTION_COUNT}" ]]; then
        echo -e "\e[31mretention not set, skipping backup rotation\e[0m"
    else
        # tail -n +X starts from Xth line, so add 1
        keep=$((BACKUP_RETENTION_COUNT+1))
        endpoint=$(get_endpoint "blobs")
        destination_sas=$(get_sas "blobs" $DESTINATION_STORAGE_ACCOUNT_NAME $DESTINATION_STORAGE_ACCOUNT_KEY)
        rotate_dirs=($(az storage blob directory list --only-show-errors --account-key $DESTINATION_STORAGE_ACCOUNT_KEY --account-name $DESTINATION_STORAGE_ACCOUNT_NAME -c $container -d "$type/$directory" -o json --delimiter '/' | jq -r 'sort_by(.name) | reverse | .[].name' | tail -n +${keep}))

        for k in "${rotate_dirs[@]}"
        do
            echo -e "\e[32m--- \e[0m"
            echo -e "\e[32m** ROTATE\e[0m"
            echo -e "\e[32m--- \e[0m"
            echo -e "\e[32mDirectory:\thttps://$DESTINATION_STORAGE_ACCOUNT_NAME.$endpoint/$container/${k%/} ... \e[0m"
            echo -e "\e[32m--- \e[0m"
            echo ""
            azcopy rm "https://$DESTINATION_STORAGE_ACCOUNT_NAME.$endpoint/$container/${k%/}?$destination_sas" --recursive=true
        done
    fi
}

if [ ! -z "$file_enabled" ] && [ "$MODE" == "FULL" ]; then
    backup "files"
    rotate "files"
fi

if [ ! -z "$file_enabled" ] && [ "$MODE" == "SYNC" ]; then
    sync "files"
fi

if [ ! -z "$blob_enabled" ] && [ "$MODE" == "FULL" ]; then
    backup "blobs"
    rotate "blobs"
fi

if [ ! -z "$blob_enabled" ] && [ "$MODE" == "SYNC" ]; then
    sync "blobs"
fi