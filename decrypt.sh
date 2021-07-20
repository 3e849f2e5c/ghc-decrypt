#!/bin/bash

# how much trash is at the beginning of the save data section
DATA_TRASH_AMOUNT=25

# how much trash is at the beginning of the save initialization vector section
IV_TRASH_AMOUNT=12

# file which contains the decryption key for the game's save file
PASSWORD_PATH="password.txt"

# file to output the decrypted save data to
OUTFILE_PATH="save.json"

# file to save metadata used to re-encrypt the save file again
OUTFILE_META_PATH="save.meta"

REQUIRED_COMMANDS=(bash cat read openssl tr jq od realpath)

for cmd in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v "${cmd}" &> /dev/null; then
    echo "command \"${cmd}\" is required by the script but was not found."
    exit 1
  fi
done

if [[ -z "${1}" ]]; then
  INFILE_PATH="save.sav"
else
  INFILE_PATH="${1}"
fi

PASSWORD="$(cat ${PASSWORD_PATH})"
[[ -z "${PASSWORD}" ]] && { echo "Password is missing."; exit 1; }

SAVE_FILE_PLAIN="$(cat "${INFILE_PATH}")"
[[ -z "${SAVE_FILE_PLAIN}" ]] && { echo "Error reading save file: ${INFILE_PATH}"; exit 1; }

# split the string into an array
IFS='.'
read -ra ADDR <<< "${SAVE_FILE_PLAIN}"

if [[ -z "${ADDR[0]}" || -z "${ADDR[1]}" ]]; then
  echo 'Save file is not in correct format.'
  exit 1
fi

# the game adds fixed amount of trash at the beginning, let's trim it
DATA_TRASH="${ADDR[0]:0:${DATA_TRASH_AMOUNT}}"
DATA=${ADDR[0]:${DATA_TRASH_AMOUNT}}
IV_TRASH="${ADDR[1]:0:${IV_TRASH_AMOUNT}}"
IV=${ADDR[1]:${IV_TRASH_AMOUNT}}

# convert string to hex
to_hex() {
  echo -n "${1}" | od -A n -t x1 | tr -d '\n '
}

# convert the initialization vector and password into hex
IV_HEX=$(to_hex "$(base64 -d <<< "${IV}")")
KEY_HEX=$(to_hex "${PASSWORD}")

# decrypt the data using openssl
DECRYPT=$(openssl enc -aes-256-cbc -nosalt -base64 -d -K "${KEY_HEX}" -iv "${IV_HEX}" 2> /dev/null <<< "${DATA}")

# pretty print the JSON
DECRYPT_PRETTY=$(jq . <<< "${DECRYPT}")

# output the decrypted data into a file
echo -n "${DECRYPT_PRETTY}" > "${OUTFILE_PATH}"
echo "Decrypted save file to $(realpath "${OUTFILE_PATH}")"

# create the metadata file
echo -ne "${KEY_HEX}.${DATA_TRASH}.${IV_TRASH}${IV}.${IV_HEX}" > "${OUTFILE_META_PATH}"
echo "Created metadata file at $(realpath "${OUTFILE_META_PATH}")"
