#!/bin/bash
set -e

INITIAL_TOOLCHAIN="nightly-2022-07-25"
KEEP="--keep-stage 0 --keep-stage 1 --keep-stage-std 0 --keep-stage-std 1"
STAGE2STD="$PWD/build/x86_64-unknown-linux-gnu/stage2-std"

rustup toolchain install $INITIAL_TOOLCHAIN
INITIAL_TOOLCHAIN_PATH="$(rustup toolchain list -v | grep $INITIAL_TOOLCHAIN | cut -f2)"

if [ ! -e config.toml.theseus ] ; then
    echo "USING THESEUS config.toml"
    echo "Previously existing config.toml will be renamed config.toml.backup" && sleep 2

    echo "profile = \"user\""       > config.toml.theseus
    echo "changelog-seen = 2"      >> config.toml.theseus
    echo "[llvm]"                  >> config.toml.theseus
    echo "download-ci-llvm = true" >> config.toml.theseus
    echo "[rust]"                  >> config.toml.theseus
    echo "deny-warnings = false"   >> config.toml.theseus
    echo "incremental = true"      >> config.toml.theseus
    echo "[build]"                 >> config.toml.theseus
    echo "rustc = \"$PWD/build/rustc-toolchain/bin/rustc\"" >> config.toml.theseus
    echo "cargo = \"$PWD/build/rustc-toolchain/bin/cargo\"" >> config.toml.theseus

    mv config.toml config.toml.backup
    cp config.toml.theseus config.toml
fi

if [ ! -d build/stage1 ] ; then
    echo "BUILDING AND EXTRACTING STAGE 1 RUSTC" && sleep 2

    mkdir -p build
    rm -f build/*-toolchain
    ln -sf $INITIAL_TOOLCHAIN_PATH build/rustc-toolchain
    ln -sf $INITIAL_TOOLCHAIN_PATH build/cargo-toolchain

    # Building up to library/alloc ensures stage1 toolchain is fully built
    ./x.py build library/alloc --stage 2

    cp -r build/x86_64-unknown-linux-gnu/stage1 build/stage1
    rm -f build/rustc-toolchain
    ln -sf $PWD/build/stage1 build/rustc-toolchain
fi

rm -rf $STAGE2STD

echo "BUILDING UP TO STAGE 2'S ALLOC" && sleep 2
./x.py build library/alloc $KEEP --stage 2 --target ./x86_64-theseus.json

# Klim's solution to rustc-dep-of-std
export RUSTFLAGS="-L$STAGE2STD/x86_64-theseus/release/deps"

echo "BUILDING STAGE 2'S STD" && sleep 2
./x.py build library/std $KEEP --stage 2 --target ./x86_64-theseus.json
