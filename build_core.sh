#!/usr/bin/env bash
# Precompiles the Arduino Uno core (core.a) without LTO, so the phone only has
# to compile the student's sketch and link it.
# Usage: build_core.sh <avr toolchain prefix> <ArduinoCore-avr dir> <out dir>
set -euo pipefail
PREFIX="$1"; CORE="$2"; OUT="$3"
export PATH="$PREFIX/bin:$PATH"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
DEFS=(-mmcu=atmega328p -DF_CPU=16000000L -DARDUINO=10819 -DARDUINO_AVR_UNO -DARDUINO_ARCH_AVR
  "-I$CORE/cores/arduino" "-I$CORE/variants/standard")
F=(-c -Os -w -ffunction-sections -fdata-sections "${DEFS[@]}")
for f in "$CORE"/cores/arduino/*.c; do avr-gcc "${F[@]}" -std=gnu11 "$f" -o "$WORK/$(basename "$f").o"; done
for f in "$CORE"/cores/arduino/*.cpp; do
  avr-g++ "${F[@]}" -std=gnu++11 -fpermissive -fno-exceptions -fno-threadsafe-statics "$f" -o "$WORK/$(basename "$f").o"
done
for f in "$CORE"/cores/arduino/*.S; do avr-gcc -c -x assembler-with-cpp "${DEFS[@]}" "$f" -o "$WORK/$(basename "$f").o"; done
# Libraries students can #include, unchanged from the Arduino Library Manager
# (tool/toolchain/libraries: LiquidCrystal, LiquidCrystal_I2C, Keypad, DHT, Servo),
# plus those that ship with the AVR core (SoftwareSerial, SPI, Wire).
LIBS="$(cd "$(dirname "$0")" && pwd)/libraries"
INC=(-I"$CORE/libraries/Wire/src")
for d in "$LIBS"/*/; do INC+=(-I"$d"); done
compile_lib() { # <source file> <library root>
  local f="$1" root="$2"
  local o="$WORK/lib_$(basename "$root")_$(basename "$f").o"
  case "$f" in
    *.c) avr-gcc "${F[@]}" -std=gnu11 -I"$root" -I"$(dirname "$f")" "${INC[@]}" "$f" -o "$o" ;;
    *) avr-g++ "${F[@]}" -std=gnu++11 -fpermissive -fno-exceptions -fno-threadsafe-statics \
         -I"$root" -I"$(dirname "$f")" "${INC[@]}" "$f" -o "$o" ;;
  esac
}
for d in "$LIBS"/*/; do
  while IFS= read -r f; do compile_lib "$f" "${d%/}"; done < <(find "$d" -name '*.cpp' -o -name '*.c')
done
for lib in SoftwareSerial SPI Wire; do
  while IFS= read -r f; do compile_lib "$f" "$CORE/libraries/$lib/src"; done \
    < <(find "$CORE/libraries/$lib/src" -name '*.cpp' -o -name '*.c')
done
mkdir -p "$OUT"
rm -f "$OUT/core.a"
avr-ar rcs "$OUT/core.a" "$WORK"/*.o
echo "core.a: $(wc -c < "$OUT/core.a") bytes"
