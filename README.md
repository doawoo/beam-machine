# BEAM Machine

This is a collection of scripts, templates, and configuration used to build many versions of Erlang for Linux and MacOS. I make no promises that these will be useful to you on their own!

# I Just Want The Builds

> https://beammachine.cloud

# What can it build?

Erlang, OpenSSL, and NCurses totalling into a full static ERTS release. (Excluding wx!) for the following platforms:

* Linux (CPUs: x86_64, aarch64, RISC-V 64) x (LibC: glibc, musl)
* MacOS (CPUs: x86_64, aarch64)

Currently supports OTP `OTP-23.3` -> `OTP-25.x`

# Using The BEAM Machine

## Requirements

* Elixir/Erlang installed on your host machine (I recommend using `asdf`).
* Ncurses `tic` in your path from version 6.2 or later (Set this path using the `TIC_PATH` env variable).
* (MacOS-Only) GNU version of `sed`, `make`, and `binutils` in your `PATH`.

## Getting Started

This tool is intended to be used on an Apple Silicon Mac. I run this on my M1 Mac Mini with 8GB of RAM, to build ALL releases from nothing it usually takes about 24 hours.

First you need to create a build directory that will contains all the OTP releases:

```sh
mkdir build
cd build
scripts/get-erlang-releases.sh | scripts/create-release-directories.sh
```

This will create a directory tree in the shape of:

```
./build/
├── OTP-[VERSION]/
│   ├── darwin/
│   │   ├── aarch64/
│   │   └── x86_64/
│   └── linux/
│       ├── aarch64/
│       │   ├── gnu/
│       │   └── musl/
│       ├── riscv64/
│       │   ├── gnu/
│       │   └── musl/
│       └── x86_64/
│           ├── gnu/
│           └── musl/
...
...
etc.
```

### Build a single release

Navigate into one of the bottom-most directories that matches the OS, CPU and libc you want to build for.
Ex. `./build/OTP-25.0/linux/aarch64/`

### Building ALL the releases

> ⚠️ **THIS WILL TAKE A LONG TIME** ⚠️

From the top level `build/` directory execute `scripts/the-big-build.sh` and wait...