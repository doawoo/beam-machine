# BEAM Machine

This is a Drone CI configuration file that allows me to build "Universal" Erlang/OTP releases for MacOS and Linux.

* MacOS releases use the `lipo` tool to combine `x86_64` and `aarch64` binaries into one (Fat Binaries).
* Linux releases are patched using `patchelf --set-interpreter ...` to point to a well-known musl libc location that [Burrito](https://github.com/burrito-elixir/burrito) automatically unpacks before launching Erlang.

# I Just Want The Builds

> https://beammachine.cloud

# What can it build?

Erlang, OpenSSL, and NCurses totalling into a full static ERTS release. (Excluding wx!) for the following platforms:

* Linux (CPUs: x86_64, aarch64) with musl libc and patched `.interp` section.
* MacOS (CPUs: x86_64, aarch64) fat binaries.

Currently supports OTP `OTP-25.0` and onward.
