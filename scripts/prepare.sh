#!/bin/bash
# Run from the Android source root after repo sync.
set -ex
D=device/samsung/slte
ln -sfn a8elte vendor/samsung/slte
for f in vendor/samsung/a8elte/*.mk; do sed -i 's#vendor/samsung/slte#vendor/samsung/a8elte#g' "$f"; done
sed -i 's#^TARGET_KERNEL_CONFIG .*#TARGET_KERNEL_CONFIG := exynos5430_a8elte_kor_skt_defconfig#' $D/BoardConfig.mk
mkdir -p device/samsung/a8elte
cat > device/samsung/a8elte/lineage.mk <<'MK'
$(call inherit-product, device/samsung/slte/device_slte.mk)
PRODUCT_NAME := lineage_a8elte
PRODUCT_DEVICE := slte
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-A800S
MK
true
rm -f $D/cm.mk $D/AndroidProducts.mk
echo 'add_lunch_combo lineage_a8elte-userdebug' > $D/vendorsetup.sh
# Kernel tree lacks a directory its Kconfig references: add an empty stub

bash /recipe/scripts/stub-kconfig.sh "$PWD/kernel/samsung/slte" exynos5430_a8elte_kor_skt_defconfig || true
echo "--- product diagnostics"; ls -la device/samsung/a8elte/; cat device/samsung/a8elte/lineage.mk
# Lineage 14.1/Halium forbids COMMON_GLOBAL_C(PP)FLAGS in device trees
grep -rlE "COMMON_GLOBAL_C(PP)?FLAGS" device/samsung vendor/samsung hardware/samsung* 2>/dev/null | xargs -r sed -i -E 's/COMMON_GLOBAL_C(PP)?FLAGS/BOARD_GLOBAL_C\1FLAGS/g'
cp /recipe/scripts/fetch-missing.sh /tmp/fetch-missing.sh
# Samsung security/Makefile lists tima_uevent/tima_uevent.o, which breaks separate-output (O=) kernel builds: build it from security/ instead
KS=kernel/samsung/slte/security
if grep -q "tima_uevent/tima_uevent.o" $KS/Makefile; then
  cp $KS/tima_uevent/tima_uevent.c $KS/tima_uevent/tima_uevent.h $KS/
  sed -i 's#tima_uevent/tima_uevent.o#tima_uevent.o#' $KS/Makefile
fi
# Samsung gud (MobiCore) Makefiles use source-relative paths that break separate-output kernel builds
find kernel/samsung/slte/drivers/gud -name Makefile | xargs sed -i 's#^GUD_ROOT_FOLDER[[:space:]]*:=[[:space:]]*drivers#GUD_ROOT_FOLDER := $(srctree)/drivers#'
grep -rn "GUD_ROOT_FOLDER :=" kernel/samsung/slte/drivers/gud | head
# Samsung Makefiles list objects as subdir/file.o; separate-output builds then need the output subdirs to exist. Pre-create them all.
for OUTD in /tmp/kout-stub /work/src/out/target/product/slte/obj/KERNEL_OBJ; do
  (cd kernel/samsung/slte && find . -type d -not -path './.git*' | while read -r d; do mkdir -p "$OUTD/$d"; done)
done
# MobiCore (secure world) daemon/libs: broken Android.mk and not needed for Halium
rm -rf hardware/samsung_slsi-cm/exynos5430/mobicore
# libMcClient (Samsung secure-world client) has no source here; drop it from hardware libs (only needed for protected video)
grep -rl "libMcClient" --include=Android.mk hardware device 2>/dev/null | xargs -r sed -i -e '/^[[:space:]]*LOCAL_SHARED_LIBRARIES[[:space:]]*+=[[:space:]]*libMcClient[[:space:]]*$/d' -e 's/[[:space:]]libMcClient\b//g'
# gcc 4.8 flags warnings in Samsung code; do not treat warnings as errors in the kernel build
KM=kernel/samsung/slte
for f in $KM/Makefile $KM/arch/arm/Makefile; do sed -i -E 's/(^|[[:space:]])-Werror([[:space:]]|$)/ /g' $f; done
echo 'KBUILD_CFLAGS += -Wno-error' >> $KM/Makefile
# Restore stock Linux 3.10 files the Samsung kernel repo lacks (compile once with host cross-gcc to find them)
bash /recipe/scripts/fetch-missing.sh "$PWD/kernel/samsung/slte" O=/tmp/kout-stub -j4 KCFLAGS=-Wno-error CROSS_COMPILE=$PWD/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi- zImage || true
