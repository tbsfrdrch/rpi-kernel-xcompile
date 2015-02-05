#!/bin/bash

umask 0022

if [ -z `which VBoxControl` ]; then
  echo
  echo "No VirtualBox guest additions found. It seems as if"
  echo "this script is not running in a virtual machine!"
  echo
  echo "Aborting."
  echo
  exit 1
fi

# Set default configuration values
DOWNLOAD=y
MENUCONFIG=y
BUILD=y
CUSTOM_CONFIG=n

# Set paths
BASE_DIR=~/pi
KERNEL_SRC_DIR="$BASE_DIR/linux"
TOOLS_DIR="$BASE_DIR/tools"
CONFIG_FILE="$KERNEL_SRC_DIR/arch/arm/configs/bcmrpi_cutdown_defconfig"
BUILD_DIR="$BASE_DIR/build"

usage()
{
  cat <<EOF
Usage: $0 [options]
    --help         : show this help message
    --nodownload   : do not download the kernel sources but use the
                     sources already present in the ~/pi folder instead
    --nomenuconfig : build the kernel without modifications to
                     the kernel configuration. Note that the console
                     based configuration tool will still start when
                     the used .config file is missing values for any
                     kernel options
    --nobuild      : do not build the kernel
    --config file  : use an existing kernel configuration file. This will
                     override any already existing .config file in the
                     linux sources folder!
EOF
  exit 1
}

proceed_yn()
{
  read -p "Do you want to proceed? [Y/n] "
  if [ -n "$REPLY" ] && [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo
    echo "Aborting."
    echo
    exit 1
  fi
}

proceed_enter()
{
  read -p "Hit ENTER to proceed"
}

# Evaluate command-line options
while true
do
  case "$1" in
    --help)
      usage
      ;;
    --nodownload)
      DOWNLOAD=n
      shift
      ;;
    --nomenuconfig)
      MENUCONFIG=n
      shift
      ;;
    --nobuild)
      BUILD=n
      shift
      ;;
    --config)
      CONFIG_FILE=`readlink -f "$2"`
      if [ ! -r "$CONFIG_FILE" ]; then
        echo "Kernel configuration file '$CONFIG_FILE' is not readable!"
        echo "Aborting."
        exit 1
      fi
      CUSTOM_CONFIG=y
      shift 2
      ;;
    -*)
      echo Unrecognized option: "$1"
      usage
      ;;
    *)
      break
      ;;
  esac
done

if [ "$DOWNLOAD" = y ]; then
  echo
  echo "WARNING:"
  echo
  echo "  The Linux kernel and tools will be downloaded from Github."
  echo "  This can take a considerable amount of time (depending on"
  echo "  the bandwidth of your internet connection)."
  echo
  proceed_yn
  echo
  if [ -d "$BASE_DIR" ]; then
    rm -rf "$BASE_DIR"  
  fi
  mkdir -p "$BASE_DIR"
  echo "Created working directory $BASE_DIR"
  cd "$BASE_DIR"
  
  echo "Downloading raspberrypi/linux"
  curl -L https://api.github.com/repos/raspberrypi/linux/tarball > linux.tar.gz
  tar xzf linux.tar.gz
  mv `ls -d raspberrypi-linux-*` linux
  rm linux.tar.gz

  echo "Downloading raspberrypi/tools"
  curl -L https://api.github.com/repos/raspberrypi/tools/tarball > tools.tar.gz
  tar xzf tools.tar.gz
  mv `ls -d raspberrypi-tools-*` tools
  rm tools.tar.gz
fi

if [ ! -d "$KERNEL_SRC_DIR" ]; then
  echo "The kernel source directory $KERNEL_SRC_DIR could not be found!"
  echo "Aborting."
  exit 1
fi

cd "$KERNEL_SRC_DIR"

if [ "$BUILD" = y ] || [ "$MENUCONFIG" = y ]; then
  if [ ! -f .config ] || [ "$CUSTOM_CONFIG" = y ]; then
    cp "$CONFIG_FILE" .config
    echo "Copied kernel configuration file $CONFIG_FILE to `pwd`/.config"
  fi
else
  exit 0
fi

if [ "$MENUCONFIG" = y ]; then
  echo "About to start 'make menuconfig'."
  echo
  echo "NOTE:"
  echo
  echo "  Make sure your terminal is at least 19 lines by 80 columns big"
  echo "  for menuconfig to start correctly."
  echo
  proceed_enter
  make ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabi- menuconfig
fi

if [ ! "$BUILD" = y ]; then
  exit 0
fi

JOBS=$(($(nproc)+1))
make ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabi- -k -j$JOBS

if [ -d "$BUILD_DIR" ]; then
  rm -rf "$BUILD_DIR"
fi
mkdir "$BUILD_DIR"

make modules_install ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabi- INSTALL_MOD_PATH="$BUILD_DIR"
cd "$TOOLS_DIR/mkimage"
./imagetool-uncompressed.py "$KERNEL_SRC_DIR/arch/arm/boot/Image"

VERSION=`ls $BUILD_DIR/lib/modules`
TMPDIR=`mktemp -d`
PKGDIR="$TMPDIR/rpi_kernel_$VERSION"
mkdir "$PKGDIR"

echo "$VERSION" > "$PKGDIR/version.txt"

echo "Packaging self-extracting kernel installer"
cp -R "$BUILD_DIR/lib/firmware" "$PKGDIR"
cp -R "$BUILD_DIR/lib/modules" "$PKGDIR"

# before packaging of the installer remove the links that point from the
# modules folder back to the kernel sources directory
find "$PKGDIR" -type l \( -name "source" -or -name "build" \) -exec rm -f {} \;

cp kernel.img "$PKGDIR/kernel_$VERSION.img"
cd /vagrant
cp install.sh "$PKGDIR"

if [ ! -d output ]; then
  mkdir output
fi
makeself --notemp "$PKGDIR" "/vagrant/output/rpi_kernel_$VERSION.sh" "Custom kernel (version $VERSION) for the Raspberry Pi" ./install.sh

rm -rf "$TMPDIR"
