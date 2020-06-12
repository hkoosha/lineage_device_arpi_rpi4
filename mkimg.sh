#/bin/bash

set -eu

readonly DATE=`date +%Y%m%d`
readonly IMGNAME=endorphin--lineage--$DATE--rpi4.img
readonly IMGSIZE=2
readonly OUTDIR=${ANDROID_PRODUCT_OUT:="../../../out/target/product/erpi4"}

echo "creating image file $IMGNAME"
dd if=/dev/zero of="$IMGNAME" bs=512k count=$(echo "$IMGSIZE*1024*2" | bc)

echo "creating partitions..."
(
echo o
echo n
echo p
echo 1
echo
echo +128M
echo n
echo p
echo 2
echo
echo +1524M
echo n
echo p
echo 3
echo
echo +256M
echo n
echo p
echo
echo
echo t
echo 1
echo c
echo a
echo 1
echo w
) | fdisk "$IMGNAME"
sync

readonly LOOPDEV=$(sudo kpartx -av "$IMGNAME" | awk 'NR==1{ sub(/p[0-9]$/, "", $3); print $3 }')
if [[ -z "$LOOPDEV" ]]; then
	echo "unable to find loop device"
	sudo kpartx -d "$IMGNAME"
	exit 1
fi
echo "image mounted as $LOOPDEV"
sleep 1

sudo mkfs.fat -F 32 "/dev/mapper/${LOOPDEV}p1"
sudo mkfs.ext4 "/dev/mapper/${LOOPDEV}p4"
sudo resize2fs "/dev/mapper/${LOOPDEV}p4" 256000

echo "copying system"
sudo dd if="$OUTDIR/system.img" "of=/dev/mapper/${LOOPDEV}p2" bs=1M
sync

echo "copying vendor"
sudo dd if="$OUTDIR/vendor.img" of="/dev/mapper/${LOOPDEV}p3" bs=1M
sync

echo "copying boot"
sudo mkdir -p './sdcard/boot/'
sudo mount "/dev/mapper/${LOOPDEV}p1" './sdcard/boot'
sudo mkdir './sdcard/boot/overlays/'
sudo cp ./boot/* './sdcard/boot/'
sudo cp "$OUTDIR/ramdisk.img" './sdcard/boot/'
sudo cp "../../../kernel/arpi/arch/arm/boot/zImage" './sdcard/boot/'
sudo cp "../../../kernel/arpi/arch/arm/boot/dts/bcm2711-rpi-4-b.dtb" './sdcard/boot/'
sudo cp "../../../kernel/arpi/arch/arm/boot/dts/overlays/vc4-kms-v3d-pi4.dtbo" './sdcard/boot/overlays/'
sync

sudo umount "/dev/mapper/${LOOPDEV}p1"
sudo kpartx -d "$IMGNAME"
sync

echo "done: $IMGNAME"
