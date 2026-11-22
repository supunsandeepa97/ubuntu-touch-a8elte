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
# Restore stock Linux 3.10 files the Samsung kernel repo lacks (compile once with host cross-gcc to find them)
bash /recipe/scripts/fetch-missing.sh "$PWD/kernel/samsung/slte" O=/tmp/kout-stub -j4 CROSS_COMPILE=arm-linux-gnueabihf- zImage || true
