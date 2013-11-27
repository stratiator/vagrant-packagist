# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu-12.04"
  config.vm.network :private_network, ip: "192.168.33.110"
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--memory", "512"]
  end

  config.vm.synced_folder "/www", "/www", :owner => "vagrant", :group => "www-data", :mount_options => ["dmode=777","fmode=777"]

  config.vm.provision :chef_solo do |chef|
    chef.cookbooks_path = "./cookbooks"
    chef.add_recipe "packagist_cookbook"
    chef.json.merge!(JSON.parse(File.read("./chef.json")))
  end
end
