# Copyright 2019 Yoshimasa Niwa
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

  # Add Google Chrome repository
  config.vm.provision :shell, inline: "wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub|sudo apt-key add -"
  config.vm.provision :shell, inline: "sudo sh -c 'echo \"deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main\" > /etc/apt/sources.list.d/google-chrome.list'"

  # Update repositories
  config.vm.provision :shell, inline: "sudo apt update -y"

  # Upgrade installed packages
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"

  # Add desktop environment
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal network-manager"

  # Enable VirtualBox guest additions support
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends virtualbox-guest-utils virtualbox-guest-x11"

  # Add `vagrant` to Administrator
  config.vm.provision :shell, inline: "sudo usermod -a -G sudo vagrant"

  # Add Google Chrome
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y google-chrome-stable"

  # Add Firefox
  config.vm.provision :shell, inline: "sudo snap install firefox"

  # Add Japanese support
  #config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fcitx-mozc"
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fonts-noto"

  # WORKAROUND: Avoid unnecessary timeout for a desktop system
  config.vm.provision :shell, inline: "sudo systemctl disable systemd-networkd-wait-online.service"

  # Restart
  config.vm.provision :shell, inline: "sudo shutdown -r now"
end
