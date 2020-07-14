docker build -t az-storage-backup:latest .
docker run --env-file ./test.full.env az-storage-backup:latest
docker run --env-file ./test.sync.env az-storage-backup:latest