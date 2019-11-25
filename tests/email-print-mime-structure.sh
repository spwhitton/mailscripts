#!/bin/bash

set -e

for eml in tests/email-print-mime-structure/*.eml; do
    printf "Testing %s\n" "${eml##*/}"
    diff -u "${eml%%.eml}.out" <(./email-print-mime-structure < "$eml")
done
