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
