#!/bin/bash
set -eux

OUTDIR=build

TARGETPREFIXLIST=(x86_64-linux-musl mipseb-linux-musl mipsel-linux-musl arm-linux-musleabi aarch64-linux-musl mips64eb-linux-musl mips64el-linux-musl  riscv64-linux-musl  powerpc-linux-musl powerpcle-linux-musl powerpc64-linux-musl powerpc64le-linux-musl loongarch64-unknown-linux-gnu)
TARGETNAMELIST=(  x86_64            mipseb              mipsel              armel                aarch64            mips64eb              mips64el                riscv64             powerpc            powerpcle            powerpc64            powerpc64le            loongarch64)
TARGETFLAGSLIST=( ""                -mips32r3         -mips32r3         ""                 ""                 -mips64r2           -mips64r2          ""                             ""                 -m32                 -m64                 -m64                  "")

mkdir -p $OUTDIR

for i in "${!TARGETNAMELIST[@]}"; do
    if [[ "${TARGETPREFIXLIST[i]}" == "mips64eb-linux-musl" ]]
    then
        SKIP_STRIP=y
    else
        SKIP_STRIP=n
    fi

    SKIP_STRIP=y

    make -j`nproc` ARCH=${TARGETNAMELIST[i]} CROSS_COMPILE=${TARGETPREFIXLIST[i]}- CFLAGS="${TARGETFLAGSLIST[i]}" SKIP_STRIP="${SKIP_STRIP}"

    # copy the unstripped version if the stripped version doesn't exist
    mkdir -p $OUTDIR/${TARGETNAMELIST[i]}
    mv busybox $OUTDIR/${TARGETNAMELIST[i]}/busybox \
        || mv busybox_unstripped $OUTDIR/${TARGETNAMELIST[i]}/busybox

    # busybox doesn't have any way to configure build artifact location,
    # so we need to clean up when we're done in case the next arch's build
    # fails. also we need to build 1-by-1
    make clean
done
