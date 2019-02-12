#!/bin/bash
BACKUP_CONTAINER="backup-`date +%Y-%m-%d-%H-%M`"

azcopy --source $SOURCE \
    --source-key $SOURCE_KEY \
    --destination $DESTINATION/$BACKUP_CONTAINER \
    --dest-key $DESTINATION_KEY \
    --recursive