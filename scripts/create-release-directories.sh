#!/bin/bash
read tags
for release in $tags; do
    echo "Create directory: $release"
    mkdir -p $release

    #### Linux
    mkdir -p $release/linux
    mkdir -p $release/linux/x86_64
    mkdir -p $release/linux/x86_64/musl
    mkdir -p $release/linux/x86_64/gnu

    mkdir -p $release/linux/aarch64
    mkdir -p $release/linux/aarch64/musl
    mkdir -p $release/linux/aarch64/gnu

    mkdir -p $release/linux/riscv64
    mkdir -p $release/linux/riscv64/musl
    mkdir -p $release/linux/riscv64/gnu

    #### Darwin
    mkdir -p $release/darwin
    mkdir -p $release/darwin/x86_64
    mkdir -p $release/darwin/aarch64
done