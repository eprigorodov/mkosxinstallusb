# mkosxinstallusb

Linux shell script that creates bootable USB flash drive with OS X installer.

OS X installer application contains a disk image "InstallESD.dmg" that can be
used to create a bootable USB flash drive. The procedure is well described in
the media, see references below.

This script automates process on Linux platform, doing essentially the
following:

    mkdir -p /mnt/OSX_InstallESD /mnt/OSX_BaseSystem /mnt/usbstick

    # convert installer disk image to raw format
    dmg2img "Install OS X <Version>.app/Contents/SharedSupport/InstallESD.dmg" InstallESD.img
    kpartx -a InstallESD.img
    mount /dev/mapper/loop0p2 /mnt/OSX_InstallESD

    # convert base system disk image to raw format
    dmg2img /mnt/OSX_InstallESD/BaseSystem.dmg BaseSystem.img
    kpartx -a BaseSystem.img
    mount /dev/mapper/loop1p1 /mnt/OSX_BaseSystem

    # partition the USB flash drive, /dev/sdX
    sgdisk -o /dev/sdX
    sgdisk -n 1:0:0 -t 1:AF00 -c 1:"disk image" -A 1:set:2 /dev/sdX
    mkfs.hfsplus -v "OS X Base System" /dev/sdX1
    mount /dev/sdX1 /mnt/usbstick

    # copy installer files
    rsync -aAEHW /mnt/OSX_BaseSystem/ /mnt/usbstick/
    rm -f /mnt/usbstick/System/Installation/Packages
    rsync -aAEHW /mnt/OSX_InstallESD/Packages /mnt/usbstick/System/Installation/
    rsync -aAEHW /mnt/OSX_InstallESD/BaseSystem.chunklist /mnt/usbstick/
    rsync -aAEHW /mnt/OSX_InstallESD/BaseSystem.dmg /mnt/usbstick/
    sync

Usage: `./mkosxinstallusb.sh </dev/sdX> "Install OS X <Version>.app"`, where
`</dev/sdX>` is a block device for target USB flash drive, e.g. `/dev/sdb`.

Known problems:
* High Sierra installers are not supported yet, 
* Korean localization can be omitted due to Linux/hfsplus bug, see
  https://ubuntuforums.org/showthread.php?t=1422374

References:
* https://www.afp548.com/2012/05/30/understanding-installesd-recovery-hd-internet-recovery/
* https://www.macworld.co.uk/how-to/mac-software/how-make-bootable-mavericks-install-drive-3475042/
* https://www.macworld.com/article/2367748/os-x/how-to-make-a-bootable-os-x-10-10-yosemite-install-drive.html
