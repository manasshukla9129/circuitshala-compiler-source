# CircuitShala: compiler build scripts and source offer

[CircuitShala](https://circuitshala-arduino-lab.web.app) is an Android app for students that simulates Arduino circuits and compiles Arduino code on the phone. This repository holds what the open-source licences ask us to publish for the compiler that ships inside the app. It does **not** contain the app's own code.

## What the app ships

| Program | Version | Licence | Official source |
|---|---|---|---|
| GCC (cc1plus, C++ compiler for AVR) | 14.2.0 | GPL-3.0 with the GCC Runtime Library Exception | https://ftp.gnu.org/gnu/gcc/gcc-14.2.0/ |
| GNU Binutils (as, ld) | 2.43 | GPL-3.0 | https://ftp.gnu.org/gnu/binutils/ |
| GMP, MPFR, MPC (built into GCC) | 6.3.0, 4.2.1, 1.3.1 | LGPL-3.0 | https://ftp.gnu.org/gnu/gmp/, /mpfr/, /mpc/ |
| avr-libc | 2.2.1 | BSD-style | https://github.com/avrdudes/avr-libc |
| ArduinoCore-avr | 1.8.6 | LGPL-2.1 | https://github.com/arduino/ArduinoCore-avr |
| LiquidCrystal, Servo, Keypad, DHT sensor library | see `libraries/README.md` | LGPL-2.1, LGPL-2.1, GPL-3.0, MIT | copies in `libraries/` |

The programs are the **unmodified official releases**, only cross-compiled to run on Android (arm64-v8a, armeabi-v7a). No patches are applied.

## Rebuild them

`build_toolchain.sh`, `build_core.sh`, `make_sdk.sh` and `install_into_app.sh` are the exact scripts used. See `BUILD.md` for the steps (download the archives above into a work folder, run the scripts with the Android NDK).

## Licences

Each component keeps its own licence; the full texts are in the official source archives linked above and in `libraries/*/LICENSE*`. If you think something is missing from this offer, please open an issue in this repository.
