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
case "$(uname -s)" in
  Darwin) DEST_DIR="$(dirname "$(greadlink -e "$0")")";;
  Linux) DEST_DIR="$(dirname "$(readlink -e "$0")")";;
esac

if [ -z "$DEST_DIR" ]; then
  # try to use python3 as a last resort
  DEST_DIR=$(python3 -c "import pathlib;print(pathlib.Path('"$0"').resolve().parent)")
fi

declare -a succeeded=()
declare -a failed=()

function error {
  echo $@
  exit 1
}

function build_and_move {
  local exts="elf hex"
  local cleanup_exts="map sym lss eep"
  local prefix="$1"
  local platform="$2"
  local crypto_target="$3"
  local dest_name="${platform//_/-}_${crypto_target}"
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
  echo -e "[*] \033[36;1m${prefix}_${dest_name}\033[0;m"
  echo -e "    \033[33;1mmake ${build_params}\033[0;m"
  make ${build_params} > /dev/null && succeeded+=("${prefix}/${dest_name}") || failed+=("${prefix}/${dest_name}")
  for ext in $exts; do
    mv "${prefix}-${platform}.${ext}" "${DEST_DIR}/${prefix}/${prefix}_${dest_name}.${ext}"
  done
  for ext in $cleanup_exts; do
    rm -f *.${ext}
  done
  popd
}

# CW303 XMEGA
build_and_move simpleserial-aes CW303 AVRCRYPTOLIB

# CW303 XMEGA HWCRYPTO
build_and_move simpleserial-aes CW303 HWAES "MCU=atxmega128a4u"

# CW303 XMEGA with AES from Digitalbitbox crypto wallet
build_and_move simpleserial-aes CW303 DIGITALBITBOXAES

# CW308_MEGARF
build_and_move simpleserial-aes CW308_MEGARF AVRCRYPTOLIB
build_and_move simpleserial-aes CW308_MEGARF DIGITALBITBOXAES
build_and_move simpleserial-aes CW308_MEGARF HWAES

# NOTDUINO avrcrypto
build_and_move simpleserial-aes CW304 AVRCRYPTOLIB

# NOTDUINO masked aes v1 and v2
for v in 1 2; do
  build_and_move simpleserial-aes CW304 MASKEDAES "CRYPTO_OPTIONS=ANSSI+VERSION${v}" "V${v}"
done

# NOTDUINO masked aes 16MHz
for v in 1 2; do
  build_and_move simpleserial-aes CW304 MASKEDAES "CRYPTO_OPTIONS=ANSSI+VERSION${v} F_CPU=16000000" "V${v}_16MHz"
done

# ARM targets
# Format: <target>:<crypto_target_1>,<crypto_target_2>=<crypto_option_1>+<crypto_option_2>
#   target: e.g. STM32F0 for CW308_STM32F0
declare -a arm_targets=("STM32F0:TINYAES128C,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "STM32F1:TINYAES128C,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "STM32F2:TINYAES128C,MBEDTLS,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "STM32F3:TINYAES128C,MBEDTLS,DIGITALBITBOXAES,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "STM32F4:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,HWAES,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "STM32L4:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,HWAES,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "STM32L5:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,HWAES,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "CC2538:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        #"EFM32GG11:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "EFM32TG11B:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "EFR32MG21A:TINYAES128C,MBEDTLS,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "IMXRT1062:TINYAES128C,MBEDTLS,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES,HWAES"
                        "K24F:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,HWAES,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "K82F:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES,HWAES=MMCAU,HWAES=LTC"
                        "LPC55S6X:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES,HWAES"
                        "NRF52:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES,HWAES=CC310,HWAES=ECB"
                        "PSOC62:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES"
                        "SAM4L:TINYAES128C,MBEDTLS,MASKEDAES=ANSSI,MASKEDAES=ANSSI+UNROLLED,MASKEDAES=ANSSI+KEYSCHEDULE,MASKEDAES=ANSSI+UNROLLED+KEYSCHEDULE,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES,HWAES"
                        "SAML11:TINYAES128C,MBEDTLS,DIGITALBITBOXAES,MASKEDAES=KNARFRANK,MASKEDAES=RIOUBSAES,HWAES")
for target in ${arm_targets[@]}; do
  unset cryptos
  ptf=(${target//:/ })
  cryptos=${ptf[1]}
  cryptos=(${cryptos//,/ })
  ptf="CW308_"${ptf[0]}
  for crypto in ${cryptos[@]}; do
    tmp=(${crypto//=/ })
    crypto_target=${tmp[0]}
    crypto_options=${tmp[1]}
    if [ "x${crypto_options}" = "x" ]; then
      build_and_move simpleserial-aes ${ptf} ${crypto_target}
    else
      build_and_move simpleserial-aes ${ptf} ${crypto_target} "CRYPTO_OPTIONS=${crypto_options}" "${crypto_options}"
    fi
  done
done
unset cryptos ptf

# AURIX. Build only if the compiler is present
if which tricore-gcc > /dev/null 2>&1; then
  build_and_move simpleserial-aes CW308_AURIX HWAES
fi

# RISC-V
if which riscv64-unknown-elf-gcc > /dev/null 2>&1; then
  build_and_move simpleserial-aes CW308_FE310 TINYAES128C
  build_and_move simpleserial-aes CW308_FE310 MBEDTLS
  build_and_move simpleserial-aes CW308_FE310 DIGITALBOXAES
  build_and_move simpleserial-aes CW308_FE310 MASKEDAES "CRYPTO_OPTIONS=KNARFRANK" KNARFRANK
  build_and_move simpleserial-aes CW308_FE310 MASKEDAES "CRYPTO_OPTIONS=RIOUBSAES" RIOUBSAES
fi

# ESP32
if [ "${IDF_PATH}" != "" ]; then
  source "${IDF_PATH}/export.sh"
fi
if which idf_tools.py > /dev/null 2>&1; then
  # setting the env
  pushd "${CW_MAIN}/esp32/simpleserial"
  echo -e "[*] \033[36;1msimpleserial-aes_CW308-ESP32_HWAES\033[0;m"
  echo -e "    \033[33;1mmake\033[0;m"
  make > /dev/null && succeeded+=("simpleserial-aes_CW308-ESP32_HWAES") || failed+=("simpleserial-aes_CW308-ESP32_HWAES")
  mkdir -p "${DEST_DIR}/simpleserial-aes/"
  mv "build/simpleserial.elf" "${DEST_DIR}/simpleserial-aes/simpleserial-aes_CW308-ESP32_HWAES.elf"
  popd
fi

# print summary
echo 'Successfully built targets:'
printf '  + \033[32;1m%s\033[0;m\n' "${succeeded[@]}"
echo 'Failed targets:'
printf '  ! \033[31;1m%s\033[0;m\n' "${failed[@]}"
echo ''

