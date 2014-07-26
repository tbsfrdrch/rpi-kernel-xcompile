#!/bin/bash

if [ `id -u` != 0 ]; then
  echo
  echo "The installation should be done as root or via the 'sudo' command."
  echo
  echo "Aborting."
  echo
  exit 1
fi

usage()
{
  cat <<EOF
Usage: $0 [options]
    --help          : show this help message
    --backupdir dir : define location where to store the backup file
                      (default: '$BACKUPDIR') 
    --bootdir dir   : specify a different location of the /boot folder
    --libdir  dir   : specify a different location of the /lib folder 
EOF
  exit 1
}

WD=`pwd`
BOOTDIR=""
LIBDIR=""
BACKUPDIR=`dirname $WD`

while true
do
  case "$1" in
    --help)
      usage
      ;;
    --backupdir)
      BACKUPDIR="$2"
      shift 2
      ;;
    --bootdir)
      BOOTDIR="$2" 
      shift 2
      ;;
    --libdir)
      LIBDIR="$2"
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

if [ ! -d "$BACKUPDIR" ]; then
  echo "The backup directory '$BACKUPDIR' does not exist!"
  exit 1
fi

if [ -z "$BOOTDIR" ]; then
  BOOTDIR="/boot"
fi
if [ ! -d "$BOOTDIR" ]; then
  echo "The boot directory '$BOOTDIR' does not exist!"
  exit 1
fi
if [ ! -e "$BOOTDIR/cmdline.txt" ]; then
  echo "The directory '$BOOTDIR' does not seem to be the"
  echo "Raspberry Pi boot folder! Aborting installation!"
  exit 1
fi

if [ -z "$LIBDIR" ]; then
  LIBDIR="/lib"
fi
if [ ! -d "$LIBDIR" ]; then
  echo "The lib directory '$LIBDIR' does not exist!"
  exit 1
fi
if [ ! -d "$LIBDIR/arm-linux-gnueabihf" ]; then
  echo "The directory '$LIBDIR' does not seem to be the"
  echo "Raspberry Pi lib folder! Aborting installation!"
  exit 1
fi

VERSION=`cat version.txt`
KERNELFILE="kernel_$VERSION.img"
KERNELIMG="$BOOTDIR/$KERNELFILE"
CONFIGFILE="$BOOTDIR/config.txt"
FIRMWAREDIR="$LIBDIR/firmware"
MODULESDIR="$LIBDIR/modules"

TMPDIR=`mktemp -d`
BACKUPPKGDIR="$TMPDIR/rpi_kernel_backup_$VERSION"
mkdir $BACKUPPKGDIR

echo "Creating backup of existing components" 
if [ -f "$KERNELIMG" ]; then
  mv "$KERNELIMG" "$BACKUPPKGDIR"
fi
cp "$CONFIGFILE" "$BACKUPPKGDIR"
if [ -d "$FIRMWAREDIR" ]; then
  mv "$FIRMWAREDIR" "$BACKUPPKGDIR"
fi
if [ -d "$MODULESDIR/$VERSION" ]; then 
  mv "$MODULESDIR/$VERSION" "$BACKUPPKGDIR"
fi

OUTFILE="$BACKUPPKGDIR/rollback.sh"
(
cat <<EOF
#!/bin/bash
read -p "WARNING: the kernel file $KERNELFILE, the boot configuration $CONFIGFILE and the contents of $LIBDIR/firmware and $LIBDIR/modules will be rolled back. Hit ENTER to continue!"
rm -rf "$FIRMWAREDIR"
rm -rf "$MODULESDIR/$VERSION"
if [ -f "$KERNELFILE" ]; then
  cp "$KERNELFILE" "$BOOTDIR"
fi
cp config.txt "$BOOTDIR"
cp -R firmware "$LIBDIR"
if [ -d "$VERSION" ]; then
  cp -R "$VERSION" "$MODULESDIR"
fi
EOF
) > $OUTFILE
chmod a+x $OUTFILE

BACKUPFILE="$BACKUPDIR/rpi_kernel_backup_$VERSION.tar.gz" 
echo "Creating backup file $BACKUPFILE"
cd "$TMPDIR"
tar czf "$BACKUPFILE" `basename $BACKUPPKGDIR`

echo "Installing new kernel, firmware and kernel modules"
cd "$WD"
chown -R root:root .
cp "$KERNELFILE" "$BOOTDIR"
cp -R ./firmware "$LIBDIR"
cp -R ./modules "$LIBDIR"

if [ `grep -c "^kernel=$KERNELFILE$" $CONFIGFILE` -eq 0 ]; then
  # only touch config.txt if the new entry does not exist yet
  echo "Registering the new kernel in $CONFIGFILE"
  if [ `grep -c "^kernel=" $CONFIGFILE` -gt 0 ]; then
    # comment the old kernel entry and attach the new one
    sed -i 's|^kernel=.*$|# &\nkernel='$KERNELFILE'|g' $CONFIGFILE
  else
    echo "kernel=$KERNELFILE" >> "$CONFIGFILE"
  fi
fi

echo "Cleaning temporary folder"
rm -rf "$TMPDIR"

echo "Installation complete."
