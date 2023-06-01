#!/bin/bash

set -e

export CLANG_PATH="$PWD/toolchain/proton-clang"
export PATH=$CLANG_PATH/bin:$PATH

TARGET_ARCH=arm64
TARGET_CC=clang
TRAGET_CLANG_TRIPLE=aarch64-linux-gnu-
TARGET_CROSS_COMPILE=aarch64-linux-gnu-
TARGET_CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
THREAD=$(nproc --all)
CC_ADDITIONAL_FLAGS="LLVM_IAS=1 LLVM=1"
TARGET_OUT="../out"
TARGET_DEVICE=renoir

export TARGET_PRODUCT=$TARGET_DEVICE

PREFIX_KERNEL_BUILD_PARA="ARCH=$TARGET_ARCH \
                         CC=$TARGET_CC \
                         CROSS_COMPILE=$TARGET_CROSS_COMPILE \
                         CROSS_COMPILE_COMPAT=$TARGET_CROSS_COMPILE_COMPAT \
                         CLANG_TRIPLE=$TARGET_CLANG_TRIPLE"

FINAL_KERNEL_BUILD_PARA="$PREFIX_KERNEL_BUILD_PARA \
                         $CC_ADDITIONAL_FLAGS \
                         -j$THREAD \
                         O=$TARGET_OUT \
                         TARGET_PRODUCT=$TARGET_DEVICE"

TARGET_KERNEL_FILE=arch/arm64/boot/Image
TARGET_KERNEL_NAME=Kernel
TARGET_KERNEL_MOD_VERSION=$(make kernelversion)

DEFCONFIG_PATH=arch/arm64/configs
DEFCONFIG_NAME="vendor/lahaina-qgki_defconfig vendor/renoir_QGKI.config"

START_SEC=$(date +%s)
CURRENT_TIME=$(date '+%Y%m%d-%H%M')

clean() {
    echo "Cleaning source tree and build files..."
    make mrproper -j$THREAD
    make clean -j$THREAD
    rm -rf $TARGET_OUT
}

make_defconfig() {
    echo "Building kernel defconfig..."
    make $FINAL_KERNEL_BUILD_PARA $DEFCONFIG_NAME
}

build_kernel() {
    echo "Building kernel..."
    make $FINAL_KERNEL_BUILD_PARA
    END_SEC=$(date +%s)
    COST_SEC=$[ $END_SEC-$START_SEC ]
    echo "Kernel build took $(($COST_SEC/60))min $(($COST_SEC%60))s"
}

link_all_dtb_files() {
    find $TARGET_OUT/arch/arm64/boot/dts/vendor/qcom -name '*.dtb' -exec cat {} + > $TARGET_OUT/arch/arm64/boot/dtb;
}

update_gki_defconfig() {
    echo "Updating GKI defconfig..."
    eval $PREFIX_KERNEL_BUILD_PARA REAL_CC=$TARGET_CC LD=ld.lld LLVM=1 \
        scripts/gki/generate_defconfig.sh vendor/lahaina-qgki_defconfig
}

if [ ! -d $CLANG_PATH ]; then
    git clone --depth=1 https://github.com/kdrag0n/proton-clang $CLANG_PATH
fi

if [ ! -f $PWD/arch/arm64/configs/vendor/lahaina-qgki_defconfig ] && [[ $1 != "--upgkidefconf" ]]; then
    update_gki_defconfig
fi

if [[ $1 == "--clean" ]]; then
    clean
elif [[ $1 == "--upgkidefconf" ]]; then
    update_gki_defconfig
else
    make_defconfig
    build_kernel
    link_all_dtb_files
fi
