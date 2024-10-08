#!/bin/bash
# base hostname only , no trailing slashes
# example: https://hostname.domain.tld
base_qnap_host=
username=
pwd_in_plain_text=
GELF_URI=http://hostname.domain.tld:12201/gelf

# whether to verify HTTPS cert, [y, n]
VERIFY_CERT=n