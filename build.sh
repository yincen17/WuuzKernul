#!/bin/bash
#
# Copyright (C) 2020 azrim.
# All rights reserved.

# Init
KERNEL_DIR="${PWD}"
KERN_IMG="${KERNEL_DIR}"/out/arch/arm64/boot/Image.gz
KERN_DTB_NONTB="${KERNEL_DIR}"/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-tissot-nontreble.dtb
KERN_DTB_TB="${KERNEL_DIR}"/out/arch/arm64/boot/dts/qcom/msm8953-qrd-sku3-tissot-treble.dtb
ANYKERNEL="${HOME}"/anykernel

# Repo URL
CLANG_REPO="https://github.com/silont-project/silont-clang.git"
ANYKERNEL_REPO="https://github.com/yincen17/AnyKernel3.git"
ANYKERNEL_BRANCH="tissot"

# Compiler
CLANG_DIR="$HOME/proton-clang"
if ! [ -d "${CLANG_DIR}" ]; then
    git clone "$CLANG_REPO" --depth=1 "$CLANG_DIR"
fi
# git clone https://github.com/baalajimaestro/aarch64-maestro-linux-android.git -b 07032020-9.2.1 --depth=1 "${KERNEL_DIR}/gcc"
# git clone https://github.com/baalajimaestro/arm-maestro-linux-gnueabi.git -b 07032020-9.2.1 --depth=1 "${KERNEL_DIR}/gcc32"

# Defconfig
DEFCONFIG="tissot_defconfig"
REGENERATE_DEFCONFIG="true" # unset if don't want to regenerate defconfig

# Costumize
KERNEL="WuuzKernul"
DEVICE="Tissot"
KERNELTYPE="4.9"
KERNELNAME="${KERNEL}-${DEVICE}-${KERNELTYPE}-$(TZ=Asia/Jakarta date +%y%m%d-%H%M)"
TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
ZIPNAME="${KERNELNAME}.zip"

# Telegram
CHATIDQ="-425671460"
CHATID="-1001225236454" # Group/channel chatid (use rose/userbot to get it)
TELEGRAM_TOKEN="" # Get from botfather

# Export Telegram.sh
TELEGRAM_FOLDER="${HOME}"/telegram
if ! [ -d "${TELEGRAM_FOLDER}" ]; then
    git clone https://github.com/fabianonline/telegram.sh/ "${TELEGRAM_FOLDER}"
fi

TELEGRAM="${TELEGRAM_FOLDER}"/telegram

tg_cast() {
    "${TELEGRAM}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -H \
    "$(
		for POST in "${@}"; do
			echo "${POST}"
		done
    )"
}

# Regenerating Defconfig
regenerate() {
    cp out/.config arch/arm64/configs/"${DEFCONFIG}"
    git add arch/arm64/configs/"${DEFCONFIG}"
    git commit -m "defconfig: Regenerate"
}

# Building
makekernel() {
    export PATH="$HOME/proton-clang/bin:$PATH"
#    export CROSS_COMPILE=${KERNEL_DIR}/gcc/bin/aarch64-maestro-linux-gnu-
#    export CROSS_COMPILE_ARM32=${KERNEL_DIR}/gcc32/bin/arm-maestro-linux-gnueabi-
    rm -rf "${KERNEL_DIR}"/out/arch/arm64/boot # clean previous compilation
    mkdir -p out
    make O=out ARCH=arm64 ${DEFCONFIG}
    if [[ "${REGENERATE_DEFCONFIG}" =~ "true" ]]; then
        regenerate
    fi
    make -j$(nproc --all) CC=clang CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- O=out ARCH=arm64

# Check If compilation is success
    if ! [ -f "${KERN_IMG}" ]; then
	    END=$(TZ=Asia/Jakarta date +"%s")
	    DIFF=$(( END - START ))
	    echo -e "Kernel compilation failed, See buildlog to fix errors"
	    tg_cast "Build for ${DEVICE} <b>failed</b> in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! Check Instance for errors @ThisIsTag"
	    exit 1
    fi
}

# Packing kranul
packingkernel() {
    # Copy compiled kernel
    if [ -d "${ANYKERNEL}" ]; then
        rm -rf "${ANYKERNEL}"
    fi
    git clone "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" "${ANYKERNEL}"
    	mkdir "${ANYKERNEL}"/kernel/
        cp "${KERN_IMG}" "${ANYKERNEL}"/kernel/Image.gz
        mkdir "${ANYKERNEL}"/dtb-nontreble/
        cp "${KERN_DTB_NONTB}" "${ANYKERNEL}"/dtb-nontreble/msm8953-qrd-sku3-tissot-nontreble.dtb
	mkdir "${ANYKERNEL}"/dtb-treble/
        cp "${KERN_DTB_TB}" "${ANYKERNEL}"/dtb-treble/msm8953-qrd-sku3-tissot-treble.dtb

    # Zip the kernel, or fail
    cd "${ANYKERNEL}" || exit
    zip -r9 "${TEMPZIPNAME}" ./*

    # Sign the zip before sending it to Telegram
    curl -sLo zipsigner-3.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/master/zipsigner-3.0.jar
    java -jar zipsigner-3.0.jar "${TEMPZIPNAME}" "${ZIPNAME}"

    # Ship it to the CI channel
    "${TELEGRAM}" -f "$ZIPNAME" -t "${TELEGRAM_TOKEN}" -c "${CHATIDQ}"
}

# Starting
tg_cast "<b>STARTING KERNEL BUILD</b>" \
	"Device: ${DEVICE}" \
	"Kernel: <code>${KERNEL}, ${KERNELTYPE}</code>" \
	"Linux Version: <code>$(make kernelversion)</code>"
START=$(TZ=Asia/Jakarta date +"%s")
makekernel
packingkernel
END=$(TZ=Asia/Jakarta date +"%s")
DIFF=$(( END - START ))
tg_cast "Build for ${DEVICE} with ${COMPILER_STRING} <b>succeed</b> took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)! @ThisIsTag"
