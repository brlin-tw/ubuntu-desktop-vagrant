#!/usr/bin/env bash
# Provision the Ubuntu Desktop Vagrant VM instance
#
# Copyright 2024 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: MIT

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
    rm
    shutdown
    snap
    sudo
    systemctl
    visudo
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
if ! sudo apt update -y; then
    printf \
        'Error: Unable to update the APT software source local cache.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Updating all packages in the system to apply bug and security fixes...\n'
apt_get_upgrade_opts=(
    -y
)
if ! sudo apt-get upgrade "${apt_get_upgrade_opts[@]}"; then
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

    # For enabling GUI configuration of the network connections
    network-manager
)
apt_get_install_opts=(
    -y
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
    'Info: Installing VirtualBox guest support packages...\n'
virtualbox_guest_addition_pkgs=(
    # Ubuntu kernel now includes VirtualBox guest drivers, no need to install the virtualbox-guest-dkms package
    # https://bugs.launchpad.net/ubuntu/+source/virtualbox/+bug/1933248
    virtualbox-guest-utils
    virtualbox-guest-x11
)
apt_get_install_opts=(
    -y
    --no-install-recommends
)
if ! sudo apt-get install \
    "${apt_get_install_opts[@]}" \
    "${virtualbox_guest_addition_pkgs[@]}"; then
    printf \
        'Error: Unable to install VirtualBox support packages.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Granting the vagrant user sudo access...\n'
usermod_opts=(
    -a
    -G sudo
)
if ! sudo usermod "${usermod_opts[@]}" vagrant; then
    printf \
        'Error: Unable to grant the vagrant user sudo access.\n' \
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

printf \
    'Info: Installing Noto fonts for CJKV character rendering support...\n'
apt_get_install_opts=(
    -y
)
if ! sudo apt-get install \
    "${apt_get_install_opts[@]}" \
    fonts-noto; then
    printf \
        'Error: Unable to install Noto fonts for CJKV character rendering support.\n' \
        1>&2
    exit 2
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
if ! sudo shutdown -r now; then
    printf \
        'Error: Unable to trigger system reboot to apply changes.\n' \
        1>&2
    exit 2
fi
