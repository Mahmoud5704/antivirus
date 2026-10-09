#!/bin/bash
# We use double quotes around variables to treat their contents as a single argument.
# Do not put commands inside another command unnecessarily.

if [ $# -eq 3 ]; then
    original=$1
    restore=$2
    interval=$3

    mkdir -p "$restore"

    scan_files() {
        shopt -s nullglob
        files=("$original"/*)

        for f in "${files[@]}"; do
            [ -f "$f" ] || continue
            hash=$(sha256sum "$f" | cut -d ' ' -f1)
            extension="${f##*.}"
            result="$hash$extension"
            virus=$(grep -Eci "virus|trojan|malware|worm|ransomware" "$f")

            if grep -Fqx "$result" "$original/whitelist.txt" 2>/dev/null; then
                echo "$f is whitelisted, skip..."
                continue
            fi

            if [ "$extension" = "exe" ] || [ "$extension" = "bat" ] || [ "$extension" = "vbs" ] || [ "$extension" = "scr" ] || [ "$extension" = "ps1" ] || [ "$virus" -gt 0 ]; then
                echo "$f is malicious and it is DELETED"
                cp "$f" "$restore"
                rm "$f"
            fi
        done
    }

    scan_files
    ls -l "$original" > directory-info.last

    while true; do
        sleep "$interval"
        ls -l "$original" > directory-info.new

        if ! cmp -s directory-info.last directory-info.new; then
            scan_files
            ls -l "$original" > directory-info.last
        fi
    done
else
    echo "pleaaaaaaaase dont forget arguments!"
fi
