#!/bin/bash
set -ex
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git curl python python3 openjdk-8-jdk bc bison build-essential flex g++-multilib gcc-multilib \
  gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5-dev \
  libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev unzip \
  libgl1-mesa-dev openssl android-tools-fsutils cpio kmod libarchive-tools
export LC_ALL=C USE_CCACHE=0 ALLOW_MISSING_DEPENDENCIES=true
git config --global user.email ci@example.invalid
git config --global user.name ci
curl -s https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo
chmod +x /usr/local/bin/repo
sed -i '1s/python$/python3/' /usr/local/bin/repo
mkdir -p /work/src && cd /work/src
repo init -u https://github.com/Halium/android -b halium-7.1 --depth=1 --no-clone-bundle
mkdir -p .repo/local_manifests
cp /recipe/manifests/samsung_a8elte.xml .repo/local_manifests/
repo sync -c --no-tags --no-clone-bundle -j4 --force-sync
df -h /work
bash /recipe/scripts/prepare.sh
bash /recipe/scripts/check-kernel.sh /work/src
source build/envsetup.sh
lunch lineage_a8elte-userdebug || { find device vendor -maxdepth 6 -name AndroidProducts.mk | head; exit 1; }
mka -j4 halium-boot
mka -j4 systemimage
mkdir -p /work/out
cp out/target/product/slte/halium-boot.img out/target/product/slte/system.img /work/out/
