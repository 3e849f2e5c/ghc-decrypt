#!/bin/bash

./decrypt.sh "save.sav"

FIRST_DATA="$(cat save.json)"

./encrypt.sh

./decrypt.sh "save.new"

SECOND_DATA="$(cat save.json)"

if [ "${FIRST_DATA}" = "${SECOND_DATA}" ]; then
    echo "OK"
else
    echo "Something is not right..."
fi