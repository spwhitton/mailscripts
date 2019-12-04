#!/bin/bash

set -e

test_eml() {
    message="$1"
    shift
    diff -u "$message.out" <(./email-print-mime-structure "$@" <"$message.eml")
}

for eml in tests/email-print-mime-structure/*.eml; do
    base="${eml%%.eml}"
    pgpkey="$base.pgpkey"
    p12key="$base.p12"
    if [ -e "$pgpkey" ]; then
        printf "Testing %s (PGPy)\n" "${eml##*/}"
        test_eml "$base" --pgpkey "$pgpkey"

        testgpghome=$(mktemp -d)
        printf "Testing %s (GnuPG PGP/MIME)\n" "${eml##*/}"
        gpg --homedir="$testgpghome" --batch --quiet --import <"$pgpkey"
        GNUPGHOME="$testgpghome" test_eml "$base" --use-gpg-agent
        rm -rf "$testgpghome"
    elif [ -e "$p12key" ]; then
        printf "Testing %s (OpenSSL)\n" "${eml##*/}"
        grep -v ^- < "$p12key" | base64 -d | \
            openssl pkcs12 -nocerts -nodes -passin pass: -passout pass: -out "$base.pemkey"
        test_eml "$base" --cmskey "$base.pemkey"
        rm -f "$base.pemkey"

        testgpghome=$(mktemp -d)
        printf "Testing %s (GnuPG S/MIME)\n" "${eml##*/}"
        gpgsm --pinentry-mode=loopback --passphrase-fd 4 4<<<'' --homedir="$testgpghome" --batch --quiet --import <"$p12key"
        GNUPGHOME="$testgpghome" test_eml "$base" --use-gpg-agent
        rm -rf "$testgpghome"
    else
        printf "Testing %s\n" "${eml##*/}"
        test_eml "$base"
    fi
done
