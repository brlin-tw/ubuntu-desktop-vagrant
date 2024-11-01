#!/usr/bin/env bash
# Provision the Ubuntu Desktop Vagrant VM instance
#
# Copyright 2024 林博仁(Buo-ren Lin) <buo.ren.lin@gmail.com>
# SPDX-License-Identifier: MIT

ENABLE_VBOXADD_INSTALLATION="${ENABLE_VBOXADD_INSTALLATION:-true}"
INSTALL_LANGUAGE_SUPPORT="${INSTALL_LANGUAGE_SUPPORT:-null}"

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
    'Info: Checking runtime parameters...\n'
boolean_params=(
    ENABLE_VBOXADD_INSTALLATION
)
boolean_regex='^(true|false)$'
for param in "${boolean_params[@]}"; do
    if ! [[ "${!param}" =~ ${boolean_regex} ]]; then
        printf \
            'Error: The value of the "%s" environment variable should either be "true" or "false".\n' \
            "${param}" \
            1>&2
        exit 1
    fi
done

language_support_locales_regex='^(zh-han[st]|[[:alpha:]]{2,3}(_[[:alpha:]]{2})?(@[[:alpha:]]+)?|null)$'
if ! [[ "${INSTALL_LANGUAGE_SUPPORT}" =~ ${language_support_locales_regex} ]]; then
    printf \
        'Error: The value of the "INSTALL_LANGUAGE_SUPPORT" environment variable(%s) is invalid, refer to the documentation for more info.\n' \
        "${INSTALL_LANGUAGE_SUPPORT}" \
        1>&2
    exit 1
fi

printf \
    'Info: Checking the existence of the required commands...\n'
required_commands=(
    apt-get
    cat
    date
    dpkg
    id
    install
    mktemp
    mount
    reboot
    rm
    sed
    snap
    stat
    sudo
    systemctl
    uname
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

# Check whether the specified Debian packages are installed
#
# Return values
#
# 0: All specified packages are installed
# 1: Some of the specified packages are not installed
is_debian_packages_installed(){
    local -a packages=("${@}")

    if ! command -v dpkg >/dev/null; then
        printf \
            'Error: %s: This function requires the "dpkg" command to be available in your command search PATHs.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        exit 99
    fi

    if ! dpkg --status "${packages[@]}" &>/dev/null; then
        return 1
    else
        return 0
    fi
}

# Check whether the local cache of the APT package management system is stale
#
# Return values
#
# 0: Local cache is stale
# 1: Local cache is not stale
#
# Process exit statuses:
#
# 99: Error occurred
is_apt_local_cache_stale(){
    local -a required_commands=(
        # For determining the current time
        date

        # For determining the APT local cache creation time
        stat
    )
    local required_command_check_failed=false
    for command in "${required_commands[@]}"; do
        if ! command -v "${command}" >/dev/null; then
            printf \
                'Error: %s: This function requires the "%s" command to be available in your command search PATHs.\n' \
                "${FUNCNAME[0]}" \
                "${command}" \
                1>&2
            required_command_check_failed=true
        fi
    done
    if test "${required_command_check_failed}" == true; then
        printf \
            'Error: %s: Required command check failed.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        exit 99
    fi

    local apt_archive_cache_mtime_epoch
    if ! apt_archive_cache_mtime_epoch="$(
        stat \
            --format=%Y \
            /var/cache/apt/archives
        )"; then
        printf \
            'Error: %s: Unable to query the modification time of the APT software sources cache directory.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        exit 99
    fi

    local current_time_epoch
    if ! current_time_epoch="$(
        date +%s
        )"; then
        printf \
            'Error: %s: Unable to query the current time.\n' \
            "${FUNCNAME[0]}" \
            1>&2
        exit 99
    fi

    if test "$((current_time_epoch - apt_archive_cache_mtime_epoch))" -ge 86400; then
        return 0
    else
        return 1
    fi
}

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

# Provision stage don't have terminal to do any configuration
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

if is_apt_local_cache_stale; then
    printf \
        'Info: Updating the APT software source local cache...\n'
    if ! apt-get update; then
        printf \
            'Error: Unable to update the APT software source local cache.\n' \
            1>&2
        exit 2
    fi
fi

if test "${ENABLE_VBOXADD_INSTALLATION}" == true; then
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

    if ! is_debian_packages_installed "${vboxga_build_dependencies_pkgs[@]}"; then
        apt_get_install_opts=(
            -y
            --no-install-recommends
        )
        if ! apt-get install \
            "${apt_get_install_opts[@]}" \
            "${vboxga_build_dependencies_pkgs[@]}"; then
            printf \
                'Error: Unable to install VirtualBox support packages.\n' \
                1>&2
            exit 2
        fi
    fi

    if ! test -e /mnt/VBoxLinuxAdditions.run; then
        printf \
            'Info: Mounting the VirtualBox guest additions disk image...\n'
        if ! mount -o ro /dev/sr0 /mnt; then
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
        /mnt/VBoxLinuxAdditions.run "${vboxga_installer_opts[@]}" \
            || test "${?}" == 2
        ); then
        printf \
            'Error: Unable to install the VirtualBox Guest Additions.\n' \
            1>&2
        exit 2
    fi
fi

printf \
    'Info: Updating all packages in the system to apply bug and security fixes...\n'
apt_get_full_upgrade_opts=(
    -y
)
if ! apt-get full-upgrade "${apt_get_full_upgrade_opts[@]}"; then
    printf \
        'Error: Unable to update all packages in the system to apply bug and security fixes...\n' \
        1>&2
    exit 2
fi

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

    # Fix missing Ubuntu Desktop Guide in the Help application
    gnome-user-docs

    # Support editing system files using admin:/(and mounting remote filesystems, etc.)
    gvfs-backends

    # For displaying keyboard layout preview
    gkbd-capplet
)
if ! is_debian_packages_installed "${ubuntu_desktop_pkgs[@]}"; then
    printf \
        'Info: Installing the minimal variant of the Ubuntu desktop...\n'
    apt_get_install_opts=(
        -y

        # There're some recommended packages that are not useful in a VM, we avoid installing them while manually select packages that is indeed useful in general
        --no-install-recommends
    )
    if ! apt-get install \
        "${apt_get_install_opts[@]}" \
        "${ubuntu_desktop_pkgs[@]}"; then
        printf \
            'Error: Unable to install the minimal variant of the Ubuntu desktop.\n' \
            1>&2
        exit 2
    fi
fi

if ! is_debian_packages_installed google-chrome-stable; then
    printf \
        'Info: Querying the system processor architecture name...\n'
    if ! arch="$(uname --machine)"; then
        printf \
            'Error: Unable to query the system processor architecture name.\n' \
            1>&2
        exit 2
    fi
    printf \
        'Info: The system processor architecture name queried to be "%s".\n' \
        "${arch}"

    printf \
        'Info: Determining the Debian architecture name...\n'
    case "${arch}" in
        arm)
            debian_arch=armhf
        ;;
        aarch64)
            debian_arch=arm64
        ;;
        i?86)
            debian_arch=i386
        ;;
        ppcle|ppc64le)
            debian_arch=ppc64el
        ;;
        riscv64)
            debian_arch="${arch}"
        ;;
        s390x)
            debian_arch="${arch}"
        ;;
        x86_64)
            debian_arch=amd64
        ;;
        *)
            printf \
                'Error: Unsupported system processor architecture name "%s".\n' \
                "${arch}" \
                1>&2
            exit 2
        ;;
    esac
    printf \
        'Info: Debian architecture name determined to be "%s".\n' \
        "${debian_arch}"

    google_chrome_download_url="https://dl.google.com/linux/direct/google-chrome-stable_current_${debian_arch}.deb"
    google_chrome_package_name="${google_chrome_download_url##*/}"

    # We don't use tmpdir in order to reduce subsequent provision time, it'll be cleaned by the system during reboot so no cleanup is needed
    google_chrome_package_downloaded="${TMPDIR:-/tmp}/${google_chrome_package_name}"

    if ! test -e "${google_chrome_package_downloaded}"; then
        printf \
            'Info: Downloading the Google Chrome installation package...\n'
        wget_opts=(
            -q

            -O "${google_chrome_package_downloaded}"
        )
        if ! wget "${wget_opts[@]}" "${google_chrome_download_url}"; then
            printf \
                'Error: Unable to download the Google Chrome installation package.\n' \
                1>&2
            exit 2
        fi
    fi

    printf \
        'Info: Installing Google Chrome...\n'
    apt_get_install_opts=(
        -y
    )
    if ! apt-get install "${apt_get_install_opts[@]}" \
        "${google_chrome_package_downloaded}"; then
        printf \
            'Error: Unable to install Google Chrome.\n' \
            1>&2
        exit 2
    fi
fi

printf \
    'Info: Installing Mozilla Firefox...\n'
if ! snap install firefox; then
    printf \
        'Error: Unable to install Mozilla Firefox.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Workarounding unnessary timeout due to the systemd-networkd-wait-online service...\n'
if ! systemctl disable systemd-networkd-wait-online.service; then
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
    'Info: Creating backup of the original GDM customization configuration...\n'
gdm_customization_config_file=/etc/gdm3/custom.conf
cp_opts=(
    --archive
)
if ! cp \
    "${cp_opts[@]}" \
    "${gdm_customization_config_file}" \
    "${gdm_customization_config_file}.orig-${operation_timestamp}"; then
    printf \
        'Error: Unable to create backup of the original GDM customization configuration.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Configuring automatic login in GDM...\n'
if ! cat >"${gdm_customization_config_file}" <<END_OF_FILE
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=vagrant
END_OF_FILE
    then
    printf \
        'Error: Unable to configure automatic login in GDM.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Disabling suspend power management action...\n'
if ! systemctl mask suspend.target; then
    printf \
        'Error: Unable to disable suspend power management action.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Ensuring that the system local Polkit rules drop-in directory exists...\n'
polkit_rules_dropin_dir="/etc/polkit-1/rules.d"
mkdir_opts=(
    --parents
    --verbose
)
if ! mkdir "${mkdir_opts[@]}" "${polkit_rules_dropin_dir}"; then
    printf \
        'Error: Unable to ensure that the system local Polkit rules drop-in directory exists.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Configuring Polkit authorization bypass for the vagrant user...\n'
auth_bypass_rule_file="${polkit_rules_dropin_dir}/90-bypass-authorization-for-the-vagrant-user.rules"
if ! cat >"${auth_bypass_rule_file}" <<END_OF_FILE
// Bypass authorization for the vagrant user
polkit.addRule(function(action, subject) {
    if (subject.user !== 'vagrant')
        return undefined;

    return polkit.Result.YES;
});
END_OF_FILE
    then
    printf \
        'Error: Unable to configure Polkit authorization bypass for the vagrant user.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Checking runtime dependencies for the Gsettings modification operations...\n'
required_commands=(
    gsettings
)
for command in "${required_commands[@]}"; do
    if ! command -v "${command}" >/dev/null; then
        printf \
            'Error: This operation requires the "%s" command to be available in your command search PATHs.\n' \
            "${command}" \
            1>&2
        exit 2
    fi
done

printf \
    'Info: Querying the identification number of the "vagrant" user...\n'
if ! vagrant_userid="$(id --user vagrant)"; then
    printf \
        'Error: Unable to query the identification number of the "vagrant" user.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Disabling automatic session locking for the vagrant user...\n'
sudo_opts=(
    --login
    --user=vagrant
)
if ! sudo "${sudo_opts[@]}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${vagrant_userid}/bus" \
    gsettings set org.gnome.desktop.screensaver lock-enabled false; then
    printf \
        'Error: Unable to disable automatic session locking for the vagrant user.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Disabling screen blanking for the vagrant user...\n'
sudo_opts=(
    --login
    --user=vagrant
)
if ! sudo "${sudo_opts[@]}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${vagrant_userid}/bus" \
    gsettings set org.gnome.desktop.session idle-delay 0; then
    printf \
        'Error: Unable to disable automatic session locking for the vagrant user.\n' \
        1>&2
    exit 2
fi

language_support_dependency_pkgs=(
    # For the language2locale utility
    accountsservice

    # For the check-language-support command
    language-selector-common
)
if ! is_debian_packages_installed "${language_support_dependency_pkgs[@]}"; then
    printf \
        'Info: Installing the runtime dependencies of the language support installation operations...\n'
    apt_get_install_opts=(
        -y
    )
    if ! apt-get install "${apt_get_install_opts[@]}" \
        "${language_support_dependency_pkgs[@]}"; then
        printf \
            'Error: Unable to install the runtime dependencies of the language support installation operations.\n' \
            1>&2
        exit 2
    fi
fi

if test "${INSTALL_LANGUAGE_SUPPORT}" != null; then
    printf \
        'Info: Querying the packages for the language support of the "%s" locale...\n' \
        "${INSTALL_LANGUAGE_SUPPORT}"
    # NOTE: Fcitx will be enumerated if XDG_CURRENT_DESKTOP isn't GNOME
    # /usr/lib/python3/dist-packages/language_support_pkgs.py
    if ! language_support_pkgs_raw="$(
        XDG_CURRENT_DESKTOP=GNOME check-language-support -l "${INSTALL_LANGUAGE_SUPPORT}"
        )"; then
        printf \
            'Error: Unable to query the packages for the language support of the "%s" locale.\n' \
            "${INSTALL_LANGUAGE_SUPPORT}" \
            1>&2
        exit 2
    fi

    printf \
        'Info: Reading the output of the "check-langauge-support" command to the language_support_pkgs array...\n'
    if ! IFS=" " read -r -a language_support_pkgs <<<"${language_support_pkgs_raw}"; then
        printf \
            'Error: Unable to read the output of the "check-langauge-support" command to the language_support_pkgs array.\n' \
            1>&2
        exit 2
    fi

    # It is normally helpful to install zh_CN along with zh_TW
    language_support_additional_pkgs=()
    case "${INSTALL_LANGUAGE_SUPPORT}" in
        zh_TW)
            printf \
                'Info: Querying the packages for the language support of the "zh_CN" locale...\n'
            if ! language_support_additional_pkgs_raw="$(
                XDG_CURRENT_DESKTOP=GNOME check-language-support -l zh_CN
                )"; then
                printf \
                    'Error: Unable to check the packages for the language support of the "zh_CN" locale.\n' \
                    1>&2
                exit 2
            fi

            printf \
                'Info: Reading the output of the "check-langauge-support" command to the language_support_additional_pkgs array...\n'
            if ! IFS=" " read -r -a language_support_additional_pkgs <<<"${language_support_additional_pkgs_raw}"; then
                printf \
                    'Error: Unable to read the output of the "check-langauge-support" command to the language_support_additional_pkgs array.\n' \
                    1>&2
                exit 2
            fi

            # Additional zh_CN and zh_TW manpages
            language_support_additional_pkgs+=(manpages-zh)
        ;;
        zh_CN)
            # Additional zh_CN and zh_TW manpages
            language_support_additional_pkgs+=(manpages-zh)
        ;;
        *)
            # Nothing to do for the rest of the locales
            :
        ;;
    esac

    if {
        test "${#language_support_pkgs[@]}" -ne 0 \
            || test "${#language_support_additional_pkgs[@]}" -ne 0
        } && ! is_debian_packages_installed \
            "${language_support_pkgs[@]}" \
            "${language_support_additional_pkgs[@]}"; then
        printf \
            'Info: Installing the langauge support packages for the "%s" locale...\n' \
            "${INSTALL_LANGUAGE_SUPPORT}"
        apt_get_install_opts=(
            -y
        )
        if ! apt-get install "${apt_get_install_opts[@]}" \
            "${language_support_pkgs[@]}" \
            "${language_support_additional_pkgs[@]}"; then
            printf \
                'Error: Unable to install the langauge support packages for the "%s" locale.\n' \
                "${INSTALL_LANGUAGE_SUPPORT}" \
                1>&2
            exit 2
        fi
    fi

    printf \
        'Info: Configuring the default locale and language priority settings for the vagrant user...\n'
    lang="${INSTALL_LANGUAGE_SUPPORT}.UTF-8"
    if test "${INSTALL_LANGUAGE_SUPPORT}" == zh_TW; then
        # It is normally helpful to fallback to zh_CN translation
        language="${INSTALL_LANGUAGE_SUPPORT}:zh_CN:zh:en"
    else
        language="${INSTALL_LANGUAGE_SUPPORT}:en"
    fi

    sudo_opts=(
        -u vagrant
        --login
    )
    if ! sudo "${sudo_opts[@]}" \
        /usr/share/language-tools/save-to-pam-env \
            /home/vagrant \
            "${lang}" \
            "${language}"; then
        printf \
            'Error: Unable to configure default locale and language priority settings for the vagrant user.\n' \
            1>&2
        exit 2
    fi

    printf \
        'Info: Configuring the miscellaneous locale settings for the vagrant user...\n'
    sudo_opts=(
        -u vagrant
        --login
    )
    if ! sudo "${sudo_opts[@]}" \
        /usr/share/language-tools/save-to-pam-env \
            /home/vagrant \
            "${lang}"; then
        printf \
            'Error: Unable to configure miscellaneous locale settings for the vagrant user.\n' \
            1>&2
        exit 2
    fi

    case "${INSTALL_LANGUAGE_SUPPORT}" in
        zh_TW)
            printf \
                'Info: Configuring input sources for the "zh_TW" locale...\n'
            if ! sudo "${sudo_opts[@]}" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${vagrant_userid}/bus" \
                gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'chewing')]"; then
                printf \
                    'Error: Unable to configure input sources for the "zh_TW" locale.\n' \
                    1>&2
                exit 2
            fi
        ;;
        zh_CN)
            printf \
                'Info: Configuring input sources for the "zh_CN" locale...\n'
            if ! sudo "${sudo_opts[@]}" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${vagrant_userid}/bus" \
                gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'libpinyin')]"; then
                printf \
                    'Error: Unable to configure input sources for the "zh_CN" locale.\n' \
                    1>&2
                exit 2
            fi
        ;;
        ja_JP)
            printf \
                'Info: Configuring input sources for the "ja_JP" locale...\n'
            if ! sudo "${sudo_opts[@]}" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${vagrant_userid}/bus" \
                gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'mozc-jp')]"; then
                printf \
                    'Error: Unable to configure input sources for the "ja_JP" locale.\n' \
                    1>&2
                exit 2
            fi
        ;;
        *)
            # We don't know how to set these locales yet
            :
        ;;
    esac

    printf \
        'Info: Configuring the system locale settings...\n'
    if ! localectl set-locale "${lang}"; then
        printf \
            'Error: Unable to configure the system locale settings.\n' \
            1>&2
        exit 2
    fi
fi

printf \
    'Info: Recording operation end time for provision time statistics...\n'
if ! operation_end_epoch="$(date +%s)"; then
    printf \
        'Error: Unable to record operation end time for provision time statistics.\n' \
        1>&2
    exit 2
fi

printf \
    'Info: Determining provision total time...\n'
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
if ! reboot; then
    printf \
        'Error: Unable to trigger system reboot to apply changes.\n' \
        1>&2
    exit 2
fi
