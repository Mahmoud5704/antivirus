#!/bin/bash
# In [ ... ], spaces are required around the condition.
# Arrays use parentheses (...).
# Array indexing starts at 0.
# Array size is obtained using ${#array[@]}.

if [ $# -eq 2 ]; then
    original="$1"
    restore="$2"

    mkdir -p "$restore"

    while true; do
        shopt -s nullglob
        files=("$restore"/*)

        if [ ${#files[@]} -eq 0 ]; then
            echo "No malicious files to review."
            exit
        fi

        echo "Choose a file:"
        i=1
        for f in "${files[@]}"; do
            echo "$i: ${f##*/}"
            i=$((i + 1))
        done

        printf "> "
        if ! read -r num; then
            exit
        fi

        if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#files[@]}" ]; then
            echo "Invalid file number, please try again!"
            continue
        fi

        file="${files[$((num - 1))]}"

        echo "For ${file##*/}:"
        printf "1: Restore this file back into dir (it was a false positive)\n2: Permanently delete this file from malicious_dir (it was genuinely malicious)\n3: Go back\n"

        while :; do
            printf "> "
            if ! read -r option; then
                exit
            fi

            if [ "$option" = 1 ]; then
                cp "$file" "$original"
                echo "Restored ${file##*/} to $original."

                hash=$(sha256sum "$file" | cut -d ' ' -f1)
                extension="${file##*.}"
                result="$hash$extension"

                echo "$result" >> "$original/whitelist.txt"
                rm "$file"
                break

            elif [ "$option" = 2 ]; then
                rm "$file"
                echo "${file##*/} permanently deleted."
                break

            elif [ "$option" = 3 ]; then
                break

            else
                echo "Wrong option, please try again!"
            fi
        done
    done

else
    echo "Don't forget to pass the directory names!"
fi
