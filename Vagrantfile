# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
 
  config.vm.box = "hashicorp/precise64"
  
  config.vm.provider "virtualbox" do |v|
    v.name = "rpi-kernel-xcompile"
    if ENV['VAGRANT_CPUS']
      v.cpus = ENV['VAGRANT_CPUS']
    else 
      v.cpus = 4
    end
  end

  config.vm.provision "shell", path: "provision.sh" 
end
