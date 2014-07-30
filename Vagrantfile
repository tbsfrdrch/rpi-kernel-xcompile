# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
 
  if ENV['VAGRANT_32BIT'] == "y"
    config.vm.box = "hashicorp/precise32"
  else
    config.vm.box = "hashicorp/precise64"
  end

  config.vm.provider "virtualbox" do |v|
    v.name = "rpi-kernel-xcompile"
    if ENV['VAGRANT_32BIT'] == "y"
      # required for the 32 bit VM to support more than 1 CPU
      # (see http://bit.ly/1xBi2qk)
      v.customize ["modifyvm", :id, "--ioapic", "on"]
    end
    if ENV['VAGRANT_CPUS']
      v.cpus = ENV['VAGRANT_CPUS']
    else 
      v.cpus = 4
    end
  end

  config.vm.provision "shell", path: "provision.sh" 
end
