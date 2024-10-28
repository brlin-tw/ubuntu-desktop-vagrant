#!/usr/bin/env bash
# Provision the Ubuntu Desktop Vagrant VM instance
#
# Copyright 2024 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: MIT

ENABLE_JAPANESE_INPUT_METHOD_SUPPORT="${ENABLE_JAPANESE_INPUT_METHOD_SUPPORT:-false}"

printf \
    'Info: Configuring the defensive interpreter behaviors...\n'
set_opts=(
    # Terminate script execution when an unhandled error occurs
    -o errexit
    -o errtrace

    # Terminate script execution when an unset parameter variable is
    # referenced
    -o nounset
)
if ! set "${set_opts[@]}"; then
    printf \
        'Error: Unable to configure the defensive interpreter behaviors.\n' \
        1>&2
    exit 1
fi

printf \
    'Info: Checking the existence of the required commands...\n'
required_commands=(
    apt-get
    cat
    date
    install
    mktemp
    mount
    reboot
    rm
    sed
    snap
    sudo
    systemctl
    visudo
    update-grub
    wget
)
flag_required_command_check_failed=false
for command in "${required_commands[@]}"; do
    if ! command -v "${command}" >/dev/null; then
        flag_required_command_check_failed=true
        printf \
            'Error: This program requires the "%s" command to be available in your command search PATHs.\n' \
            "${command}" \
            1>&2
    fi
done
if test "${flag_required_command_check_failed}" == true; then
    printf \
        'Error: Required command check failed, please check your installation.\n' \
        1>&2
    exit 1
fi

printf \
    'Info: Setting up the EXIT trap...\n'
trap_exit(){
    if test -v tmpdir; then
        printf \
            'Info: Cleaning up the temporary directory...\n'
        rm_opts=(
            --recursive
            --force
        )
        if ! rm "${rm_opts[@]}" "${tmpdir}"; then
            printf \
                'Error: Unable to clean up the temporary directory.\n'
        fi\
    fi
}
if ! trap trap_exit EXIT; then
    printf \
        'Error: Unable to set up the EXIT trap for cleaning up.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Setting up the ERR trap...\n'
trap_err(){
    printf \
        'Error: The program has encountered an unhandled error and is prematurely aborted.\n' \
        1>&2
}
if ! trap trap_err ERR; then
    printf \
        'Error: Unable to set up the ERR trap.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Determining operation timestamp...\n'
if ! operation_timestamp="$(date +%Y%m%d-%H%M%S)"; then
    printf \
        'Error: Unable to determine the operation timestamp.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Creating a temporary directory for operation...\n'
mktemp_opts=(
    --directory
    --tmpdir
)
if ! tmpdir="$(
    mktemp \
        "${mktemp_opts[@]}" \
        "ubuntu-desktop-vagrant-${operation_timestamp}.XXX"
    )"; then
    printf \
        'Error: Unable to create a temporary directory for operation.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Recording operation start time for provision time statistics...\n'
if ! operation_start_epoch="$(date +%s)"; then
    printf \
        'Error: Unable to record operation start time for provision time statistics.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Creating the DEBIAN_FRONTEND environment variable passthrough sudoers drop-in configuration file...\n'
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND
sudoers_file_temp="${tmpdir}/passthrough-debian-frontend-envvar"
if ! cat >"${sudoers_file_temp}" <<END_OF_FILE
# Allow pass-through the DEBIAN_FRONTEND environment variable for customizing debconf(7)'s frontend behavior
Defaults:%sudo env_keep += "DEBIAN_FRONTEND"
END_OF_FILE
    then
    printf \
        'Error: Unable to create the DEBIAN_FRONTEND environment variable passthrough sudoers drop-in configuration file.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Checking syntax of the DEBIAN_FRONTEND environment variable passthrough sudoers drop-in configuration file.\n'
visudo_opts=(
    --check
    --file="${sudoers_file_temp}"
)
if ! visudo "${visudo_opts[@]}"; then
    printf \
        'Error: Syntax check failed for the DEBIAN_FRONTEND environment variable passthrough sudoers drop-in configuration file.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Installing the DEBIAN_FRONTEND environment variable passthrough sudoers drop-in configuration file...\n'
sudoers_file_installed=/etc/sudoers.d/passthrough-debian-frontend-envvar
install_opts=(
    --owner root
    --group root
    --mode 0644
    --verbose
)
if ! install \
    "${install_opts[@]}" \
    "${sudoers_file_temp}" \
    "${sudoers_file_installed}"; then
    printf \
        'Error: Unable to install the DEBIAN_FRONTEND environment variable passthrough sudoers drop-in configuration file.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Installing the Google Chrome package validation key...\n'
wget_opts=(
    -q

    # Output content to the standard output device
    -O -
)
if ! wget "${wget_opts[@]}" https://dl-ssl.google.com/linux/linux_signing_key.pub \
    | sudo apt-key add -; then
    printf \
        'Error: Unable to install the Google Chrome package validation key.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Configuring the Google Chrome APT software source list...\n'
if ! sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list'; then
    printf \
        'Error: Unable to configure the Google Chrome APT software source list.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Updating the APT software source local cache...\n'
if ! sudo apt-get update; then
    printf \
        'Error: Unable to update the APT software source local cache.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Installing build dependencies of the VirtualBox guest additions...\n'
if ! current_running_kernel_version="$(uname -r)"; then
    printf \
        'Error: Unable to detect the current running Ubuntu kernel version.\n' \
        1>&2
    exit 2
fi
vboxga_build_dependencies_pkgs=(
    dkms
    gcc
    make
    linux-headers-generic
    "linux-headers-${current_running_kernel_version}"
)
apt_get_install_opts=(
    -y
    --no-install-recommends
)
if ! sudo apt-get install \
    "${apt_get_install_opts[@]}" \
    "${vboxga_build_dependencies_pkgs[@]}"; then
    printf \
        'Error: Unable to install VirtualBox support packages.\n' \
        1>&2
    exit 2
fi

if ! test -e /mnt/VBoxLinuxAdditions.run; then
    printf \
        'Info: Mounting the VirtualBox guest additions disk image...\n'
    if ! sudo mount -o ro /dev/sr0 /mnt; then
        printf \
            'Error: Unable to mount the VirtualBox guest additions disk image.\n' \
            1>&2
        exit 2
    fi
fi

printf \
    'Info: Installing the VirtualBox Guest Additions...\n'
vboxga_installer_opts=(
    # Accept the license
    --accept
)
if ! (
    # NOTE: For some reason the installer return 2 even when successfully executed, ignore it for now
    sudo /mnt/VBoxLinuxAdditions.run "${vboxga_installer_opts[@]}" \
        || test "${?}" == 2
    ); then
    printf \
        'Error: Unable to install the VirtualBox Guest Additions.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Updating all packages in the system to apply bug and security fixes...\n'
apt_get_full_upgrade_opts=(
    -y
)
if ! sudo apt-get full-upgrade "${apt_get_full_upgrade_opts[@]}"; then
    printf \
        'Error: Unable to update all packages in the system to apply bug and security fixes...\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Installing the minimal variant of the Ubuntu desktop...\n'
ubuntu_desktop_pkgs=(
    # Install the minimal variant as the user won't likely need the complete desktop applications
    ubuntu-desktop-minimal

    # Manually select ubuntu-desktop-minimal recommended packages that are useful
    apport-gtk
    appstream
    apt-config-icons-hidpi
    avahi-daemon
    fonts-liberation
    fonts-noto-cjk
    fonts-ubuntu
    gnome-online-accounts
    gnome-terminal
    gnome-text-editor
    gsettings-ubuntu-schemas
    ibus
    ibus-gtk
    ibus-gtk3
    ibus-table
    im-config
    kerneloops
    libglib2.0-bin
    libnss-mdns
    network-manager
    packagekit
    plymouth-theme-spinner
    policykit-desktop-privileges
    seahorse
    snapd
    systemd-oomd
    ubuntu-docs
    ubuntu-wallpapers
    whoopsie
    xcursor-themes
    xdg-desktop-portal-gnome
    xdg-utils
    yaru-theme-gnome-shell
    yaru-theme-gtk
    yaru-theme-icon
    yaru-theme-sound

    # Allow GNOME Shell to reschedule KMS thread
    rtkit
)
apt_get_install_opts=(
    -y

    # There're some recommended packages that are not useful in a VM, we avoid installing them while manually select packages that is indeed useful in general
    --no-install-recommends
)
if ! sudo apt-get install \
    "${apt_get_install_opts[@]}" \
    "${ubuntu_desktop_pkgs[@]}"; then
    printf \
        'Error: Unable to install the minimal variant of the Ubuntu desktop.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Installing Google Chrome...\n'
apt_get_install_opts=(
    -y
)
if ! sudo apt-get install \
    "${apt_get_install_opts[@]}" \
    google-chrome-stable; then
    printf \
        'Error: Unable to install Google Chrome.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Installing Mozilla Firefox...\n'
if ! sudo snap install firefox; then
    printf \
        'Error: Unable to install Mozilla Firefox.\n' \
        1>&2
    exit 2
fi

if test "${ENABLE_JAPANESE_INPUT_METHOD_SUPPORT}" == true; then
    printf \
        'Info: Installing Japanese input method...\n'
    apt_get_install_opts=(
        -y
    )
    if ! sudo apt-get install \
        "${apt_get_install_opts[@]}" \
        fcitx-mozc; then
        printf \
            'Error: Unable to install Japanese input method.\n' \
            1>&2
        exit 2
    fi
fi

printf \
    'Info: Workarounding unnessary timeout due to the systemd-networkd-wait-online service...\n'
if ! sudo systemctl disable systemd-networkd-wait-online.service; then
    printf \
        'Error: Unable to workaround unnessary timeout due to the systemd-networkd-wait-online service.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Patching the default GRUB Linux kernel boot command-line arguments...\n'
sed_opts=(
    --regexp-extended
    --expression='s@^GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"$@GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"@'
    --in-place
)
if ! sed "${sed_opts[@]}" /etc/default/grub; then
    printf \
        'Error: Unable to patch the default GRUB Linux kernel boot command-line arguments.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Applying the GRUB bootloader configuration changes...\n'
if ! update-grub; then
    printf \
        'Error: Unable to apply the GRUB bootloader configuration changes.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Recording operation end time for provision time statistics...\n'
if ! operation_end_epoch="$(date +%s)"; then
    printf \
        'Error: Unable to record operation end time for provision time statistics.\n' \
        1>&2
    exit 2
fi

provision_time_duration="$((operation_end_epoch - operation_start_epoch))"
provision_time_hours="$((provision_time_duration / 3600))"
provision_time_minutes="$(((provision_time_duration % 3600) / 60))"
provision_time_seconds="$((provision_time_duration % 60))"

printf \
    'Info: Operation completed without errors using %s hours, %s minutes, and %s seconds.\n' \
    "${provision_time_hours}" \
    "${provision_time_minutes}" \
    "${provision_time_seconds}"

printf \
    'Info: Triggering system reboot to apply changes...\n'
if ! sudo reboot; then
    printf \
        'Error: Unable to trigger system reboot to apply changes.\n' \
        1>&2
    exit 2
fi
