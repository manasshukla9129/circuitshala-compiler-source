#!/usr/bin/env bash
# Compiles every ready example with the app's toolchain (built for the Mac) and the
# same SDK the phone uses (stock ArduinoCore-avr + the official libraries), into
# test/fixtures/exN.hex. Fails if any example does not compile.
# Run from the app folder. Usage: build_example_fixtures.sh [toolchain work dir]
set -euo pipefail
T="${1:-$HOME/circuitlab-toolchain-build}"
W="$(mktemp -d)"; trap 'rm -rf "$W" test/_tmp' EXIT
mkdir -p test/_tmp
cat > test/_tmp/dump_test.dart <<'DART'
import 'dart:io';
import 'package:circuit_lab/compiler/ino_preprocessor.dart';
import 'package:circuit_lab/project/part_examples.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('dump', () {
    final out = Platform.environment['OUT']!;
    for (var i = 0; i < partExamples.length; i++) {
      File('$out/ex$i.cpp').writeAsStringSync(preprocessIno(partExamples[i].code).cpp);
    }
  });
}
DART
OUT="$W" flutter test test/_tmp/dump_test.dart >/dev/null
fail=0
for f in $(ls "$W"/ex*.cpp | sort -V); do
  i="$(basename "$f" .cpp)"
  if bash "$T/phone_pipeline.sh" "$T/mac/libexec/gcc/avr/14.2.0/cc1plus" "$T/mac/bin/avr-as" "$T/mac/bin/avr-ld" \
      "$T/sdk" "$W" "$f" 2>"$W/$i.err"; then
    "$T/mac/bin/avr-objcopy" -O ihex -R .eeprom "$W/sketch.elf" "test/fixtures/$i.hex"
    echo "$i OK $("$T/mac/bin/avr-size" "$W/sketch.elf" | tail -1 | awk '{print $1+$2}') bytes"
  else
    echo "$i FAILED"; head -8 "$W/$i.err"; fail=1
  fi
done
exit $fail
