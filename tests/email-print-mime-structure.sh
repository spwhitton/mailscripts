#!/bin/bash

set -e

test_eml() {
    message="$1"
    shift
    diff -u "$message.out" <(./email-print-mime-structure "$@" < "$message.eml")
}

for eml in tests/email-print-mime-structure/*.eml; do
    base="${eml%%.eml}"
    pgpkey="$base.pgpkey"
    if [ -e "$pgpkey" ]; then
        printf "Testing %s (PGPy)\n" "${eml##*/}"
        test_eml "$base" --pgpkey "$pgpkey"
    else
        printf "Testing %s\n" "${eml##*/}"
        test_eml "$base"
    fi
done
