#!/bin/bash
# Run from the Android source root after repo sync.
set -ex
D=device/samsung/slte
ln -sfn a8elte vendor/samsung/slte
for f in vendor/samsung/a8elte/*.mk; do sed -i 's#vendor/samsung/slte#vendor/samsung/a8elte#g' "$f"; done
sed -i 's#^TARGET_KERNEL_CONFIG .*#TARGET_KERNEL_CONFIG := exynos5430_a8elte_kor_skt_defconfig#' $D/BoardConfig.mk
cat > $D/lineage_a8elte.mk <<'MK'
$(call inherit-product, device/samsung/slte/device_slte.mk)
PRODUCT_NAME := lineage_a8elte
PRODUCT_DEVICE := slte
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-A800S
MK
echo 'PRODUCT_MAKEFILES := $(LOCAL_DIR)/lineage_a8elte.mk' > $D/AndroidProducts.mk
rm -f $D/cm.mk
echo 'add_lunch_combo lineage_a8elte-userdebug' > $D/vendorsetup.sh
# Kernel tree lacks a directory its Kconfig references: add an empty stub
K=kernel/samsung/slte/arch/arm/mach-mvebu
[ -f $K/Kconfig ] || { mkdir -p $K; touch $K/Kconfig; }
echo "--- product diagnostics"; ls -la $D/*.mk $D/vendorsetup.sh; cat $D/AndroidProducts.mk $D/lineage_a8elte.mk
