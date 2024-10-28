# Copyright 2019 Yoshimasa Niwa
# Copyright 2024 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: MIT
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  config.vm.provider :virtualbox do |v|
    v.gui = true
    v.memory = 1024

    # Increase the video memory size if the guest display auto-resizing stops working over a certain console window size dimension
    # Default: 33MiB, increasing it to 64MiB should work in most usecases
    # https://www.virtualbox.org/manual/topics/BasicConcepts.html#settings-display
    v.customize ["modifyvm", :id, "--vram", 64]

    # Enable 3D acceleration for better performance
    v.customize ["modifyvm", :id, "--accelerate-3d=on"]

    # Customize guest display scaling for HiDPI host displays
    # https://forums.virtualbox.org/viewtopic.php?p=362196&sid=268bb84dc835643e14b7c7d7398e6e2c#p362196
    #v.customize ["setextradata", :id, "GUI/ScaleFactor", "1"]

    # Use Virt-IO network adapter to improve networking performance
    v.default_nic_type = "virtio"

    # Reduce port count to cut down boot time
    v.customize ["storagectl", :id, "--name=SATA Controller", "--controller=IntelAhci", "--portcount=2"]

    # Create a virtual DVD drive and mount guest additions ISO into it
    # WORKAROUND: In 7.0.3 "--medium=additions" only work if we first set the medium to an empty
    v.customize ["storageattach", :id, "--storagectl=SATA Controller", "--port=1", "--type=dvddrive", "--medium=emptydrive"]
    v.customize ["storageattach", :id, "--storagectl=SATA Controller", "--port=1", "--type=dvddrive", "--medium=additions"]

    # Supress warning messages regarding mouse capturing, which shouldn't be a concern for the running operating system
    v.customize ["setextradata", "global", "GUI/SuppressMessages", "all"]

    # Set much useful initial VM console size dimension(in 16:9 aspect ratio, but should be smaller than majority 1920x1080 physical screens)
    v.customize ["setextradata", :id, "GUI/LastGuestSizeHint", "1280,720"]

    # Enable clipboard sync support
    # SECURITY: This setting may leak sensitive personal information, use with care!
    v.customize ["modifyvm", :id, "--clipboard", "bidirectional"]

    # Enable host/guest file drag & drop support
    # NOTE: This does not work reliably(or, at all) in some desktop environments
    v.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
  end

  config.vm.synced_folder ".", "/vagrant"

  # Run provision program
  config.vm.provision :shell, path: "vagrant-assets/provision.sh"
end
