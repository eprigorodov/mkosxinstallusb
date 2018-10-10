#!/bin/sh

set +o errexit

stick_dev=$1
installer_path=${2:-$PWD}
InstallESD_mount_point=/mnt/OSX_InstallESD
BaseSystem_mount_point=/mnt/OSX_BaseSystem
target_drive_mount_point=/mnt/OSX_installer_drive

cleanup () {
    set +e
    for path in $target_drive_mount_point $BaseSystem_mount_point $InstallESD_mount_point; do
        [ -d "$path" ] && umount "$path"
    done
    sync
    for img in BaseSystem.img InstallESD.img "$stick_dev"; do
        [ -f "$img" ] && kpartx -d "$img"
    done
    sync
    for path in $target_drive_mount_point $BaseSystem_mount_point $InstallESD_mount_point; do
        [ -d "$path" ] && rmdir "$path"
    done
    rm -f InstallESD.img BaseSystem.img
}

map_partitions () {
    device="$1"
    if [ -f "$device" ]
    then
        partitions=$(kpartx -asv "$device" | sed -r 's/^add\s+map\s+(\w+).*$/\/dev\/mapper\/\1/')
    else
        partitions=$(lsblk -lnp -o NAME "$device" | grep -v "^$device$")
    fi
    part_count=$(count_args() { echo $#; }; count_args $partitions)
    if [ "$part_count" = "1" ]
    then
        # shortcut for the target device 
        # which has just been re-partitioned by sgdisk
        # and knowingly contains only one partition
        echo "$partitions"
    else
        for part in $partitions 
        do
            fstype=$(lsblk -ln -o FSTYPE "$part")
            if [ "$fstype" = "hfsplus" ]
            then
                echo "$part"
                break
            fi
        done
    fi
}

trap cleanup EXIT

if [ -z "$stick_dev" ]
then
    echo 'Usage: $0 <target_usb_drive> [InstallESD.dmg]'
    echo '\twhere <target_usb_drive> should be a block device path, /dev/sdX'
    exit 1
fi

if [ -f "$installer_path" ]
then
    installer_dmg=$installer_path
else
    # assume .app package   
    installer_dmg="$installer_path/Contents/SharedSupport/InstallESD.dmg"
    if [ ! -f "$installer_dmg" ]
    then
        # last resort
        installer_dmg="$installer_path/InstallESD.dmg"
    fi
fi

if [ ! -f "$installer_dmg" ]
then
    echo "Cannot find OS X installer disk image InstallESD.dmg"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]
then
    echo "This script can only be executed by root"
    exit 1
fi

for cmd in lsblk dmg2img kpartx sgdisk partprobe mkfs.hfsplus rsync; do
    if [ ! $(which $cmd) ]
    then
        echo "\nCommand '$cmd' is not found. Please install required system packages:"
        echo "util-linux, dmg2img, kpartx, gdisk, parted, hfsprogs, rsync"
        exit 1
    fi
done

if [ -b "$stick_dev" ]
then 
    mounted_at_root=$(lsblk $stick_dev | grep "part /$") || true

    if [ ! -z "$mounted_at_root" ]
    then
        lsblk $stick_dev
        echo "Target drive appears to contain partition mounted as root filesystem, aborting"
        exit 1
    fi
fi

echo "\nAll information on the target drive $stick_dev is going to be ERASED\n"
REPLY="no"
read -p "Are you sure that you want to continue [yes/no]? " REPLY
if [ "$REPLY" != "yes" ]
then
    exit 0
fi

high_sierra_checksums="d815748c242fbbe35754a8f37aea1cfbc7e919f6 b38e5f4daa014d324f1a78f91c1f30f6d68289ef e78e5f58fa3eeecf8638067902772ce814d1a89d d6e2514b5c7c7c35b53fb79e245f61eff5d54b8e 4164f0dde7316ad745426438ef013568fe0313ba 530839420356e6d77b5ff6da3a3753305da26567 ff1b9cef69573a97dccc7997f1f028c02542decf 70abc4f7240edb2674008fa68e9c7c792aa71463 0c26ff40fb1d2ac33eb956f375435504f6c82aab f67a9ef856e9cadc5e72e91df5d74e10bb485993 671f49b99e5449a5fb33b9b6e79c2578421bf52d 22e6f0335f2f98a7b0e479aa79591fcaab1505d0 23de5e8003692d47ebd09eabdffcd6b7f5ddaf6f 7b41b675611183ecb62087a1951e65b7a07ec970 52f33ce14e6d743b2eddc40ba3c73d3d37e6838a 4342b2238f8ced923de2eae48aaeaa68b146fd9f 457bf24edddc9f873542f5d4cad8adb351a8824a 57121f3d870b4d38c68111a5f5203bbe88e4b4b0 68e3149a78c27a0b1b62afad83a532ba45d09680 f4526c750174c1ecf79dacbda7ffeab5c24ca5f9 b85d4359f1b5d11f5aa1585c13da0fa3c937383b 5d6e3d13b6022b538cc1a853905169b5c037d908 901523d51d18d26b99e5179d72e0413eca253e84 b6d33822be36008b6107ea85162b886f9e59eacb 48bb76cabe2ff7be61dcd396087bc8c238b8bbee 63c47f303883473bfef56007cc63033f8547353c dc9e81f0ba874b23ed62a084ac63702bedebc8cd 20f05fa198d03046d20b17f8617843c4c71b2b8c"

supported_checksums="b53c36706eef6e0e15c1f76ef51d1b552705fc75 51df126965433187403987c9d74d95c26cba9266 30b9245f7c7608c40bbdf4d4a74f3ab84dbac716 77d354ec06df0d0acc37c105ae524ba96948142b 94f9e8f7ae2540dee6fe3465f60fc037e2547d16 1432e3be6222c434b536721076ed8b16b1c6050e f7f147c54627c2a9beb1fa318394e1579b30b167 e559e142a4c9ebaaa740c575d5c3c23c6eb3fb06 139ef35e4af0da8286b2a3af326cb114d774f606 3e58d8fcff9f941f28fc7ab47b51c5651c2dfd6d f38a32b512f70ce72fa054f86991ca057ef37f78 2df533dbb6b5af5d8cc8b352de5c2d4c81ce4cf2 6b1368c4be9f043203efb2e6dd7b73541e016dbf c3cdf53048a9a99a1d1355ccef09179a0b6a3dee 7739e3f62080000da5d28efa689c53976112a262 850781fe8cb5d88c5d1bc23e704e6686ff1fcc2f f6292573395b46e8110be6077fd4827409bc948b e4311d93127d0668372b32e5342f3b455b6bc9bd 2b11b8b618a2e5100507c3c432363081db65c4c8 306a080c07e293b6765ba950bab213572704acec 5e21097f2e98417ecc12574a7bb46a402594ea4a ef5cc8851b893dbe4bc9a5cf5c648c10450af6bc a8da3a4f4499c68559a2bad4ce232f2443a333ca dc4d4d0a7cd4aea4514025d23a58d05107369fa9 4b93ff2cef88220a116fbce7c5707c9c57442bd0 059f2603a91465bcee24c864d446da30df920f85 a673c2c6d967f4da2934b7d6cf3736936970b194 eebf02a20ac27665a966957eec6f5e6fe3228a19 4a0a01806be8676cb39fb0ab5d049a198d255538 e804dea01e38f8cd28d6c1b1697487e50898dbe7 bd1997666f9786af584bfa0dc1a64d95ab4b42e6 7bc54f504aa0b769a2d0b8546393a6e0fc24671f eaf54b1b1a630af85547fed8eabbf6fe159f2b42 e5dd2bf5560033cade7dd7d7da5ceec49f701b0e a044fc01fa75b1f255dbdd6ea4fefa30cef147b0 f8fa177e4be9a69f87be23b83c30e0c8eedacf5b 67ab755a3604cd767787fed56150bdb566358f69"

echo "\n# verifying installer image checksum"
output=$(sha1sum "$installer_dmg")
checksum=${output%% *}
if $(echo $supported_checksums | grep -q "$checksum")
then
    echo "\t$checksum is a known checksum of OS X installer disk image"
else
    if $(echo $high_sierra_checksums | grep -q "$checksum")
    then
        echo "\nWARNING: checksum $checksum belongs to High Sierra installer which is not supported yet"
    else
        echo "\nWARNING: checksum $checksum does not match any of known OSX images"
    fi
    echo "\tconsult with https://github.com/notpeter/apple-installer-checksums#mac-osx-installers-sha1-checksums\n"
    exit 1
fi

echo "\n# converting installer disk image to raw format"
dmg2img "$installer_dmg" InstallESD.img
InstallESD_partition="$(map_partitions "InstallESD.img")"

echo "\n# converting base system disk image to raw format"
mkdir -p $InstallESD_mount_point
mount "${InstallESD_partition}" $InstallESD_mount_point
dmg2img $InstallESD_mount_point/BaseSystem.dmg BaseSystem.img
BaseSystem_partition="$(map_partitions "BaseSystem.img")"

echo "\n# partitioning USB drive"
ls -1 "${stick_dev}"? | xargs -n1 umount || true
sgdisk -o $stick_dev
sgdisk -n 1:0:0 -t 1:AF00 -c 1:"disk image" -A 1:set:2 $stick_dev
sync
stick_partition="$(map_partitions "$stick_dev")"
echo "\nAll information on the target partition ${stick_partition} is going to be ERASED\n"
REPLY="no"
read -p "Are you sure that you want to continue [yes/no]? " REPLY
if [ "$REPLY" != "yes" ]
then
    exit 0
fi
mkfs.hfsplus -v "OS X Base System" "${stick_partition}"

rsync="rsync -aAEHW"

echo "\n# copying ~1.2G of installer files to the USB drive, please wait for a long sync"
mkdir -p $BaseSystem_mount_point
mount "${BaseSystem_partition}" $BaseSystem_mount_point
mkdir -p $target_drive_mount_point
mount "${stick_partition}" $target_drive_mount_point
# can return 24 on Korean filenames, so suppress errors
$rsync --info=progress2 $BaseSystem_mount_point/ $target_drive_mount_point/ || true
sync

echo "\n# copying ~5G of additional files to the USB drive, please wait"
mount -o remount,sync $target_drive_mount_point
rm $target_drive_mount_point/System/Installation/Packages
$rsync -P $InstallESD_mount_point/Packages $target_drive_mount_point/System/Installation/
$rsync -P $InstallESD_mount_point/BaseSystem.chunklist $target_drive_mount_point/
$rsync -P $InstallESD_mount_point/BaseSystem.dmg $target_drive_mount_point/
sync

echo "\n# cleaning up"
exit 0
