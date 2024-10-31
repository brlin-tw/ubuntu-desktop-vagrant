# Copyright 2019 Yoshimasa Niwa
# Copyright 2024 林博仁 <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: MIT
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  # Hostname in guest VM
  config.vm.hostname = "ubuntu-desktop-vm"

  config.vm.provider :virtualbox do |v|
    v.gui = true

    # Name that appears in the VirtualBox GUI
    v.name = "Ubuntu Desktop VM"

    v.cpus = 2
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

    # Enable USB controller emulation support
    # NOTE: USB 3.0 controller support depend on the VirtualBox Expansion Pack which is under a non-commercial license!
    #v.customize ["modifyvm", :id, "--usbehci", "on"]
    #v.customize ["modifyvm", :id, "--usbxhci", "on"]

    # Setup USB host device auto-redirection filter
    # FIXME: This configuration is NOT idempotent(additional entries will be created in subsequent runs)
    #v.customize [
    #    'usbfilter', 'add', '0', '--target', :id,
    #    '--name', 'Device filter name',
    #    '--vendorid', '0x1234',
    #    '--productid', '0x5678'
    #]
  end

  # Configure synced folders for ease access to project files
  config.vm.synced_folder ".", "/vagrant"

  # Allow SSH agent forwarding in the SSH service
  # SECURITY: The usage of this feature may have security concerns, use with care!
  # https://security.stackexchange.com/questions/101783/are-there-any-risks-associated-with-ssh-agent-forwarding
  #config.ssh.forward_agent = true

  # Allow X11 forwarding in the SSH service
  # SECURITY: The usage of this feature may have security concerns, use with care!
  # https://security.stackexchange.com/questions/14815/security-concerns-with-x11-forwarding
  #config.ssh.forward_x11 = true

  # Configure forward proxy
  # https://github.com/tmatilai/vagrant-proxyconf?tab=readme-ov-file#configuration-keys
  #if Vagrant.has_plugin?("vagrant-proxyconf")
    #config.proxy.http     = "http://192.168.49.1:8228/"
    #config.proxy.https    = "http://192.168.49.1:8228/"
    #config.proxy.no_proxy = "localhost,127.0.0.1,.example.com"
  #end

  # Run provision program
  config.vm.provision :shell,
    path: "vagrant-assets/provision.sh",
    env: {
      "ENABLE_VBOXADD_INSTALLATION" => "true",
      "INSTALL_LANGUAGE_SUPPORT" => "null"
    }
end
