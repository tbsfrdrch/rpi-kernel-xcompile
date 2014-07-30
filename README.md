[1]: https://www.virtualbox.org/ "VirtualBox"
[2]: http://vagrantup.com "Vagrant" 
[3]: http://megastep.org/makeself/ "Makeself"

#  A Vagrant-based environment to cross-compile the Raspberry Pi kernel

## Overview

This repository provides a Vagrant configuration to easily and repeatedly create a sandboxed environment for cross-compilation of the Raspberry Pi kernel.

It provides a convenient way of provisioning an Ubuntu box with all the tools that are necessary to cross-compile the Raspberry Pi kernel. In addition to that it comes with a script to automatically download the kernel sources, start the kernel configuration tool, build the kernel and finally package it into a self-extracting installer. The installer allows to easily install the new kernel on the Pi, while at the same time taking care of creating a backup of a possibly already existing kernel of the same version. Last but not least a basic script to rollback the kernel version is also packaged with that backup. 

**WARNING**
> Please be aware that your Raspberry Pi might stop working correctly or even refuses to boot after installing a new kernel. Therefore it is recommended to  create a backup image of your SD card prior to making changes to your Raspberry Pi such as installing a custom kernel! 

## Usage

### Prerequisites

To make use of the configuration provided in this repository the following applications need to be installed:

* [VirtualBox][1]
* [Vagrant][2]

### General workflow

The basic workflow when using the provided Vagrant environment to compile the Raspberry Pi kernel is as follows:

* start and connect to the VM configured in this repository
* build the kernel within the VM
* install the kernel to the Pi
* possibly revert the kernel on the Pi to the previous version 

### Starting and connecting to the VM

Clone this Git repository and start and connect to the virtual machine configured in this repository's Vagrantfile:
 
    $ cd rpi-kernel-xcompile
    $ vagrant up
    $ vagrant ssh

#### Customization of the Vagrant box

When using the default configuration provided in this repository, Vagrant will start a 64bit Ubuntu box ([hashicorp/precise64](https://vagrantcloud.com/hashicorp/precise64)) and the virtual machine will have 4 CPUs assigned per default.

This default configuration can be overridden by setting the following environment variable in the host operating system before invoking `vagrant up`:

* `VAGRANT_CPUS`: specify the number of CPUs that the virtual machine shall be started with

### Building a Raspberry Pi kernel

Once you are connected to the VM, you can execute the following script to download the kernel sources, interactively specify the kernel configuration and finally build the kernel with the following command:
    
    $ /vagrant/build.sh
    
Per default this will download the kernel sources first. After that the menu-driven kernel configuration tool is started via `make menuconfig` using the default configuration located under `arch/arm/configs/bcmrpi_cutdown_defconfig` in the kernel source tree as a basis for further refinement. 

After saving the configuration and leaving the configuration tool the kernel will be compiled.

The kernel image file and the `lib` folder with the firmware and the kernel modules will be packaged into a self-extracting archive that is made available under `/vagrant/output`, which can also be accessed from outside of the VM in the folder `rpi-kernel-xcompile/output`.

#### Build options

The build script allows you to control its behaviour by using one of the following options, e.g. to skip certain build steps or to pass in an already existing external kernel configuration file:

* `--help`: show configuration options of the build script
* `--nodownload`: especially when testing different kernel configurations for the same kernel version, it makes not much sense to download the kernel sources over and over again. For that reason the download of the kernel sources can be omitted with this flag. In this case it is assumed that the kernel sources can be found in the `pi` directory within the home directory of the `vagrant` user
* `--nomenuconfig`: when you have already prepared a kernel configuration in a previous run of this script and want to rebuild the kernel with the very same configuration, you can also skip the menuconfig tool with this flag. In combination with the `--nobuild`flag this could also be used to only download the kernel sources. Combining this flag with the `--config` option instead, this can be used to pass in an external configuration file and use it as is to build the kernel.
* `--nobuild`: when using this flag, the last step of actually building and packaging the new kernel into a self-extracting installer will be skipped. This can for example be used to only download the kernel sources when combined with the `--nomenuconfig` flag.
* `--config file`: this configuration option allows to pass in an already existing external kernel configuration file and either use it as is to build the kernel (when combined with the `--nomenuconfig`flag) or to use it as the basis for further refinement of the configuration in the menuconfig tool. 

#### Caveats

* Downloading the Linux kernel source can take quite some time to complete. You really might want to skip this step in repeated builds that are based on the same kernel sources by using the `--nodownload` option.
* Make sure your terminal window size is big enough, as otherwise you might receive the following error message and the kernel configuration will fall back to 'console mode':

        Your display is too small to run Menuconfig!
        It must be at least 19 lines by 80 columns.
        
* When using the `--nomenuconfig` option and specifying a fully pre-configured kernel configuration file it still can happen that the console-based configuration tool will start. This will be the case whenever the configuration file does not contain entries for all existing configuration options of the kernel it is used with. This is not unlikely to happen whenever the kernel configuration was created based on an older kernel version than the one it is used with in the build.
  
### Installing a custom kernel

Once the new kernel was built successfully it will be made available as a self-extracting installer file at `/vagrant/output/rpi_kernel_<version>.sh` within the VM, which is also accessible from outside of the VM at `rpi-kernel-xcompile/output/rpi_kernel_<version>.sh`.

To install the kernel contained within that file there are basically two options:

* execute the installer on an already running Raspberry Pi, or
* mount the SD card of the Raspberry Pi on another machine and execute the installer there while the Raspberry Pi is powered off

#### Invocation of the installer

The installer is based on [Makeself][3] and can be invoked as follows:

    $ rpi_kernel_<version>.sh [<makeself_options>] [-- <install_script_options>]

The different Makeself options are best described on the tool's [homepage][3]. 

The supported install script options can be shown with the following invocation of the installer:

    $ rpi_kernel_<version>.sh -- --help

If you would like to check upfront which files are included in the self-extracting installer that will be installed to your Raspberry Pi, you can use the following command:

    $ rpi_kernel_<version>.sh --list
    
The `kernel_<version>.img` file contained within the installer archive will be copied to the `/boot` directory and the installer registers this new kernel image with the boot configuration in `/boot/config.txt`. The contents of the `firmware` and `modules` folders will be copied to the `/lib` folder on the Pi. 

#### Installation directly on the Raspberry Pi

Especially when copying the kernel installer file to the Raspberry Pi and executing it directly on the device while it is running, just invoking the installer file without any additional options should be sufficient in most cases.

#### Installation on a mounted SD card

> NOTE: I would only recommend this approach when you mount the SD card of the Raspberry Pi under Linux. Although it is also possible to access the `/boot` partition of the Raspberry Pi, which normally has a FAT32 filesystem, under Windows or Mac OS X, the `/lib` folder will normally be located on an EXT4 partition, which can not so easily be mounted on those systems. Besides that the installer script was not tested in those environments and will probably not even execute in Cygwin or Mac OS X.
 
When you mount the SD card that contains the filesystem of the Raspberry Pi on another machine, you need to tell the installer where it can find the `/boot` and `/lib` folders of the Raspberry Pi according to the mount points that have been used while mounting the partition(s) of the SD card. You can do that by using the following options:

* `--bootdir`: allows you to specify where in the local filesystem the `/boot` directory of the Raspberry Pi can be found
* `--libdir`: allows you to specify where in the local filesystem the `/lib` folder of the Raspberry Pi can be found

An example invocation of the kernel installer could look as follows:

    $ rpi_kernel_<version>.sh -- --bootdir /mnt/pi/boot --libdir /mnt/pi/lib

##### Caveats

* The installer script which is included in the self-extracting archive will be extracted to a sub-directory of the current working directory. For that reason it is recommended to just specify absolute paths when using the configuration options above so that you don't have to deal with constructing paths that are relative to the folder to which the contents of the archive was extracted to.
* even though the installer comes with some (very simplistic) test logic to make sure that you don't accidentally install the Raspberry Pi kernel to the normal Linux box on which you execute the installer, you should not rely on this logic, but instead **ALWAYS** make use of the `--bootdir` and `--libdir` options whenever you do not execute the installer directly on the Raspberry Pi!  

#### Backup creation

Before the installer copies the new kernel components to the filesytem, it checks if the following files or directories already exist and creates backup copies if they do:

* `/boot/kernel_<version>.img`
* `/boot/config.txt`
* `/lib/firmware`
* `/lib/modules`

Per default the backup archive with copies of those files and folders is made available in the current working directory and is named `rpi_kernel_backup_<version>.tar.gz`.

You can override where the installer stores the backup by using the `--backupdir` option of the installer script.


### Rolling back to a previous kernel version

If you want to rollback the kernel version to the one that was active prior to executing the installer script, you can extract the contents of the `rpi_kernel_backup_<version>.tar.gz` archive and execute the `rollback.sh` script that is included in that archive.

**WARNING**
> Please note that the rollback script depends on being executed in the very same environment it was created in!

> If you executed the installer for a new kernel directly on the Raspberry Pi, then the rollback script should also be executed directly on the Pi. If on the other hand you mounted a SD card to install the new kernel to your Pi, then please make sure that prior to executing the rollback script the `/boot` and `/lib` folders are mounted to the exact same folders as they were when you executed the kernel installer.

## References
* Software
    * [VirtualBox][1]
    * [Vagrant][2]
    * [Makeself][3]
* Raspberry Pi kernel compilation guides:
    * [http://elinux.org/RPi_Kernel_Compilation](http://elinux.org/RPi_Kernel_Compilation)
    * [http://mitchtech.net/raspberry-pi-kernel-compile](http://mitchtech.net/raspberry-pi-kernel-compile)
