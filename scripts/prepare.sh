#!/bin/bash
# Run from the Android source root after repo sync.
set -ex
D=device/samsung/slte
ln -sfn a8elte vendor/samsung/slte
for f in vendor/samsung/a8elte/*.mk; do sed -i 's#vendor/samsung/slte#vendor/samsung/a8elte#g' "$f"; done
sed -i 's#^TARGET_KERNEL_CONFIG .*#TARGET_KERNEL_CONFIG := exynos5430_a8elte_kor_skt_defconfig#' $D/BoardConfig.mk
# Halium/Ubuntu Touch kernel options missing from the Samsung defconfig
DEFC=kernel/samsung/slte/arch/arm/configs/exynos5430_a8elte_kor_skt_defconfig
while read -r opt; do
  [ -z "$opt" ] && continue
  sed -i "/^# $opt is not set\$/d;/^$opt=/d" $DEFC
  echo "$opt=y" >> $DEFC
done < /recipe/scripts/halium-kernel-options.txt
# AppArmor (mainline 3.10 code) uses current->no_new_privs; this Samsung kernel has the newer task_no_new_privs() accessor
sed -i 's/current->no_new_privs/task_no_new_privs(current)/g' kernel/samsung/slte/security/apparmor/domain.c
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
# MobiCore / TrustZone secure-world stack is not needed for Halium: remove it and every reference to its libraries
rm -rf hardware/samsung_slsi-cm/exynos5430/mobicore hardware/samsung_slsi-cm/exynos5430/libsecurepath
MCLIBS='libMcClient|libMcRegistry|libsecurepath|libcommonpawrapper|libMcStub|libMcDriverDaemon'
grep -rlE "$MCLIBS" --include=Android.mk --include='*.mk' hardware device 2>/dev/null | xargs -r sed -i -E -e '/^[[:space:]]*LOCAL_[A-Z_]+[[:space:]]*\+?:?=[[:space:]]*('"$MCLIBS"')[[:space:]]*\\?[[:space:]]*$/d' -e 's/(^|[[:space:]])('"$MCLIBS"')([[:space:]]|$)/ /g'
# libgscaler calls content-protection hooks that lived in libsecurepath: provide no-op versions
GS=hardware/samsung_slsi-cm/exynos5/libgscaler
cat > $GS/cp_stub.cpp <<'CPS'
#include <stdint.h>
#include <sys/cdefs.h>
#include "content_protect.h"
extern "C" cpResult_t CP_Enable_Path_Protection(uint32_t protect_ip) { (void)protect_ip; return CP_SUCCESS; }
extern "C" cpResult_t CP_Disable_Path_Protection(uint32_t protect_ip) { (void)protect_ip; return CP_SUCCESS; }
CPS
sed -i 's#^\([[:space:]]*\)libgscaler_obj.cpp \\#\1libgscaler_obj.cpp \\\n\1cp_stub.cpp \\#' $GS/Android.mk
grep -n "cp_stub" $GS/Android.mk
# libMcClient (Samsung secure-world client) has no source here; drop it from hardware libs (only needed for protected video)
grep -rl "libMcClient" --include=Android.mk hardware device 2>/dev/null | xargs -r sed -i -e '/^[[:space:]]*LOCAL_SHARED_LIBRARIES[[:space:]]*+=[[:space:]]*libMcClient[[:space:]]*$/d' -e 's/[[:space:]]libMcClient\b//g'
# gcc 4.8 flags warnings in Samsung code; do not treat warnings as errors in the kernel build
KM=kernel/samsung/slte
for f in $KM/Makefile $KM/arch/arm/Makefile; do sed -i -E 's/(^|[[:space:]])-Werror([[:space:]]|$)/ /g' $f; done
echo 'KBUILD_CFLAGS += -Wno-error' >> $KM/Makefile
# Restore stock Linux 3.10 files the Samsung kernel repo lacks (compile once with host cross-gcc to find them)
bash /recipe/scripts/fetch-missing.sh "$PWD/kernel/samsung/slte" O=/tmp/kout-stub -j4 KCFLAGS=-Wno-error CROSS_COMPILE=$PWD/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8/bin/arm-eabi- zImage || true
# Samsung RIL (modem/telephony) needs a merged ril.h (vendor + Android 7 constants). Skip it for the first bootable image; TODO restore for calls/SMS/data.
echo '# libril skipped for first bootable image' > hardware/samsung/ril/libril/Android.mk   # keep libsecril-client: the audio HAL links against it
find hardware/ril -name Android.mk -delete 2>/dev/null || true
echo '# telephony stack skipped for first bootable image' > hardware/ril/Android.mk
# Device SELinux policy violates Android 7 neverallow rules; Halium runs without it: clear the device policy lists
cat >> device/samsung/slte/BoardConfig.mk <<'SEP'

BOARD_SEPOLICY_DIRS :=
BOARD_SEPOLICY_UNION :=
BOARD_SEPOLICY_REPLACE :=
BOARD_SEPOLICY_M4DEFS :=
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 0x01400000
SEP
# Samsung userspace HALs include exynos kernel uapi headers that the Kbuild list omits: export them too
KU=kernel/samsung/slte/include/uapi/linux
for f in $KU/*exynos*.h; do b=$(basename "$f"); grep -q "header-y += $b" $KU/Kbuild || echo "header-y += $b" >> $KU/Kbuild; done
# Device headers use C-style casts; Android 7 clang builds with -Werror. Silence those warnings inside these headers only.
for h in device/samsung/slte/include/hardware/gralloc.h device/samsung/slte/include/hardware/gps.h device/samsung/slte/include/telephony/ril.h device/samsung/slte/include/camera/CameraParametersExtra.h device/samsung/slte/include/fd_utils-inl-extra.h; do
  [ -f "$h" ] && sed -i '1i #if defined(__clang__)\n#pragma clang diagnostic ignored "-Wold-style-cast"\n#pragma clang diagnostic ignored "-Wunused-parameter"\n#pragma clang diagnostic ignored "-Wsign-compare"\n#endif' "$h"
done
# goldfish is only needed for its data files (apns-conf.xml, init.goldfish.sh): drop its emulator build modules
find device/generic/goldfish -name Android.mk -delete
# apns-conf.xml normally comes from device/generic/goldfish, which Halium's manifest does not include: provide an empty valid one
mkdir -p device/generic/goldfish/data/etc
[ -f device/generic/goldfish/data/etc/apns-conf.xml ] || printf '<?xml version="1.0" encoding="utf-8"?>\n<apns version="8">\n</apns>\n' > device/generic/goldfish/data/etc/apns-conf.xml
