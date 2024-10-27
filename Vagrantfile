# Copyright 2019 Yoshimasa Niwa
# Copyright 2024 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: MIT
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  config.vm.provider :virtualbox do |v|
    v.gui = true
    v.memory = 2048

    # Enable 3D acceleration for better performance
    v.customize ["modifyvm", :id, "--accelerate-3d=on"]

    # Customize guest display scaling for HiDPI host displays
    # https://forums.virtualbox.org/viewtopic.php?p=362196&sid=268bb84dc835643e14b7c7d7398e6e2c#p362196
    #v.customize ["setextradata", :id, "GUI/ScaleFactor", "1"]
  end

  config.vm.synced_folder ".", "/vagrant"

  # Run provision program
  config.vm.provision :shell, path: "vagrant-assets/provision.sh"
end
