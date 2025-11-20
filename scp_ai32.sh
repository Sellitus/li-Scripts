#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Usage: $0 {--send|-s|--receive|-r} <source> <destination>"
    echo ""
    echo "Send (upload) examples:"
    echo "  $0 --send /local/file.txt /home/sellitus/file.txt"
    echo "  $0 -s /local/folder /home/sellitus/folder"
    echo ""
    echo "Receive (download) examples:"
    echo "  $0 --receive /home/sellitus/file.txt /local/file.txt"
    echo "  $0 -r /home/sellitus/folder /local/folder"
    exit 1
fi

MODE="$1"
SOURCE="$2"
DEST="$3"
HOST="sellitus@100.121.41.40"

case "$MODE" in
    -s|--send)
        if [ ! -e "$SOURCE" ]; then
            echo "Error: Local path does not exist: $SOURCE"
            exit 1
        fi

        if [ -d "$SOURCE" ]; then
            echo "Uploading directory '$SOURCE' to '$HOST:$DEST'"
            scp -i ~/.ssh/id_ed25519 -r "$SOURCE" "$HOST:$DEST"
            echo "Uploaded directory: $SOURCE"
        else
            echo "Uploading file '$SOURCE' to '$HOST:$DEST'"
            scp -i ~/.ssh/id_ed25519 "$SOURCE" "$HOST:$DEST"
            echo "Uploaded file: $SOURCE"
        fi
        ;;

    -r|--receive)
        if ! ssh -i ~/.ssh/id_ed25519 "$HOST" "[ -e \"$SOURCE\" ]" 2>/dev/null; then
            echo "Error: Remote path does not exist or is not accessible: $SOURCE"
            exit 1
        fi

        if ssh -i ~/.ssh/id_ed25519 "$HOST" "[ -d \"$SOURCE\" ]" 2>/dev/null; then
            echo "Downloading directory '$SOURCE' to '$DEST'"
            scp -i ~/.ssh/id_ed25519 -r "$HOST:$SOURCE" "$DEST"
            echo "Downloaded directory to: $DEST"
        else
            echo "Downloading file '$SOURCE' to '$DEST'"
            scp -i ~/.ssh/id_ed25519 "$HOST:$SOURCE" "$DEST"
            echo "Downloaded file to: $DEST"
        fi
        ;;

    *)
        echo "Error: Invalid mode '$MODE'. Use --send/-s or --receive/-r"
        exit 1
        ;;
esac
