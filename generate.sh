#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <chipwhisperer_directory>"
  exit 2
fi

CW_MAIN="$1/hardware/victims/firmware"
if [ ! -d "${CW_MAIN}" ]; then
  echo "Directory \"${CW_MAIN}\" doesn't exist."
  exit 3
fi
DEST_DIR="$(dirname "$(readlink -e "$0")")"

declare -a succeeded=()
declare -a failed=()

function error {
  echo $@
  exit 1
}

function build_and_move {
  local exts="elf hex"
  local prefix="$1"
  local platform="$2"
  local crypto_target="$3"
  local dest_name="${platform}_${crypto_target}"
  local build_params="PLATFORM=${platform} CRYPTO_TARGET=${crypto_target}"
  mkdir -p "${DEST_DIR}/${prefix}/"
  if [ $# -eq 3 ]; then
    true
  elif [ $# -eq 4 ]; then
    build_params+=" $4"
  elif [ $# -eq 5 ]; then
    build_params+=" $4"
    dest_name="${dest_name}_$5"
  else
    error "Invalid function call to build_and_move(). Received $# args while expecting either 3, 4 or 5: $@"
  fi
  pushd "${CW_MAIN}/${prefix}"
  echo -e "[*] \033[36;1m${prefix}-${dest_name}\033[0;m"
  echo -e "    \033[33;1mmake ${build_params}\033[0;m"
  make ${build_params} > /dev/null && succeeded+=("${prefix}/${dest_name}") || failed+=("${prefix}/${dest_name}")
  for ext in $exts; do
    mv "${prefix}-${platform}.${ext}" "${DEST_DIR}/${prefix}/${prefix}-${dest_name}.${ext}"
  done
  popd
}

# CW303 XMEGA
build_and_move simpleserial-aes CW303 AVRCRYPTOLIB

# CW303 XMEGA HWCRYPTO
build_and_move simpleserial-aes CW303 HWAES "MCU=atxmega128a4u"

# NOTDUINO avrcrypto
build_and_move simpleserial-aes CW304 AVRCRYPTOLIB

# NOTDUINO masked aes v1 and v2
for v in 1 2; do
  build_and_move simpleserial-aes CW304 MASKEDAES "CRYPTO_OPTIONS=VERSION${v}" "V${v}"
done

# NOTDUINO masked aes 16MHz
for v in 1 2; do
  build_and_move simpleserial-aes CW304 MASKEDAES "CRYPTO_OPTIONS=VERSION${v} F_CPU=16000000" "V${v}_16MHz"
done

# ARM targets
for ptf in CW308_STM32F1 CW308_STM32F2 CW308_STM32F3 CW308_STM32F4 CW308_K24F CW308_NRF52; do
  for crypto in TINYAES128C MBEDTLS MASKEDAES HWAES; do
    build_and_move simpleserial-aes ${ptf} ${crypto}
  done
done

# print summary
echo 'Successfully built targets:'
printf '  + \033[32;1m%s\033[0;m\n' "${succeeded[@]}"
echo 'Failed targets:'
printf '  ! \033[31;1m%s\033[0;m\n' "${failed[@]}"
echo ''

