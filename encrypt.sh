#!/bin/bash
set -ex -o pipefail
INPUT_FILE=$1
OUTPUT_FILE=$(echo ${INPUT_FILE} | sed 's/.yaml$/.sops.yaml/' | sed 's/.yml$/.sops.yml/')
export SOPS_AGE_KEY_FILE=$(dirname $0)/key.txt
sops --encrypt --age age1ej7fjm78n44tz3jnr6hkzhraf97egzekjfy87rfmhlnv9flwy55se0c5gz ${INPUT_FILE} > ${OUTPUT_FILE}
rm -f ${INPUT_FILE}