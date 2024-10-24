# Copyright 2019 Yoshimasa Niwa
# SPDX-License-Identifier: MIT
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  config.vm.provider :virtualbox do |v|
    v.gui = true
    v.memory = 2048
  end

  config.vm.synced_folder ".", "/vagrant"

  # Add Google Chrome repository
  config.vm.provision :shell, inline: "wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub|sudo apt-key add -"
  config.vm.provision :shell, inline: "sudo sh -c 'echo \"deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main\" > /etc/apt/sources.list.d/google.list'"

  # Update repositories
  config.vm.provision :shell, inline: "sudo apt update -y"

  # Upgrade installed packages
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y"

  # Add desktop environment
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal network-manager"

  # Enable VirtualBox guest additions support
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends virtualbox-guest-utils virtualbox-guest-x11"

  # Add `vagrant` to Administrator
  config.vm.provision :shell, inline: "sudo usermod -a -G sudo vagrant"

  # Add Google Chrome
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y google-chrome-stable"

  # Add Chromium
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser"

  # Add Firefox
  config.vm.provision :shell, inline: "sudo snap install firefox"

  # Add Japanese support
  #config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fcitx-mozc"
  config.vm.provision :shell, inline: "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fonts-noto"

  # Restart
  config.vm.provision :shell, inline: "sudo shutdown -r now"
end
