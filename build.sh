#!/bin/bash
set -e

INITIAL_TOOLCHAIN="nightly-2022-07-25"
KEEP="--keep-stage 0 --keep-stage 1 --keep-stage-std 0 --keep-stage-std 1"
STAGE2STD="$PWD/build/x86_64-unknown-linux-gnu/stage2-std"
CFG="config.theseus.toml"

rustup toolchain install $INITIAL_TOOLCHAIN
INITIAL_TOOLCHAIN_PATH="$(rustup toolchain list -v | grep $INITIAL_TOOLCHAIN | cut -f2)"

if [ ! -e $CFG ] ; then

    echo "profile = \"user\""       > $CFG
    echo "changelog-seen = 2"      >> $CFG
    echo "[llvm]"                  >> $CFG
    echo "download-ci-llvm = true" >> $CFG
    echo "[build]"                 >> $CFG
    echo "rustc = \"$PWD/build/rustc-toolchain/bin/rustc\"" >> $CFG
    echo "cargo = \"$PWD/build/cargo-toolchain/bin/cargo\"" >> $CFG
    echo "[rust]"                  >> $CFG
    echo "deny-warnings = false"   >> $CFG
    echo "incremental = true"      >> $CFG

fi

if [ ! -d build/stage1 ] ; then
    echo "BUILDING AND EXTRACTING STAGE 1 RUSTC" && sleep 2

    mkdir -p build
    rm -f build/*-toolchain
    ln -sf $INITIAL_TOOLCHAIN_PATH build/rustc-toolchain
    ln -sf $INITIAL_TOOLCHAIN_PATH build/cargo-toolchain

    # Building up to library/alloc ensures stage1 toolchain is fully prepared
    ./x.py build --config "$CFG" library/alloc --stage 2

    cp -r build/x86_64-unknown-linux-gnu/stage1 build/stage1
    rm -f build/rustc-toolchain
    ln -sf $PWD/build/stage1 build/rustc-toolchain
fi

rm -rf $STAGE2STD

export RUSTFLAGS="-Z merge-functions=disabled -Z share-generics=no --emit=obj -C code-model=large -C relocation-model=static"
echo RUSTFLAGS=$RUSTFLAGS

echo "BUILDING UP TO STAGE 2'S ALLOC" && sleep 2
./x.py build --config "$CFG" library/alloc $KEEP --stage 2 --target ./x86_64-theseus.json

# Klim's solution to rustc-dep-of-std
export RUSTFLAGS="$RUSTFLAGS -L$STAGE2STD/x86_64-theseus/release/deps"
echo RUSTFLAGS=$RUSTFLAGS

echo "BUILDING STAGE 2" && sleep 2
./x.py build --config "$CFG" $KEEP --stage 2 --target ./x86_64-theseus.json

echo "ADDING TOOL BINARIES TO THE TOOLCHAIN"
cp build/x86_64-unknown-linux-gnu/stage2-tools-bin/* build/x86_64-unknown-linux-gnu/stage2/bin
