# Ubuntu Desktop in Vagrant

Provision reproducible and consistent Ubuntu desktop virtual machines using [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/).

<https://gitlab.com/brlin/ubuntu-desktop-vagrant>  
[![The GitLab CI pipeline status badge of the project's `main` branch](https://gitlab.com/brlin/ubuntu-desktop-vagrant/badges/main/pipeline.svg?ignore_skipped=true "Click here to check out the comprehensive status of the GitLab CI pipelines")](https://gitlab.com/brlin/ubuntu-desktop-vagrant/-/pipelines) [![GitHub Actions workflow status badge](https://github.com/brlin-tw/ubuntu-desktop-vagrant/actions/workflows/check-potential-problems.yml/badge.svg "GitHub Actions workflow status")](https://github.com/brlin-tw/ubuntu-desktop-vagrant/actions/workflows/check-potential-problems.yml) [![pre-commit enabled badge](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white "This project uses pre-commit to check potential problems")](https://pre-commit.com/) [![REUSE Specification compliance badge](https://api.reuse.software/badge/gitlab.com/brlin/ubuntu-desktop-vagrant "This project complies to the REUSE specification to decrease software licensing costs")](https://api.reuse.software/info/gitlab.com/brlin/ubuntu-desktop-vagrant)

## Prerequisites

The following prerequisites must be match in order to use this solution:

* The host system must have the following software installed and has its commands available in the command search PATHs:
    + OPTIONAL - (Your preferred archive extraction application/utility)  
      For extracting the downloaded product release archive.
    + OPTIONAL - (Your preferred HTTPS client/Web browser)  
      For downloading the product release archive.
    + Vagrant  
      For provisioning the virtual machine that runs the Ubuntu desktop environment.
    + Oracle VirtualBox(must be in a version that your Vagrant installation supports, as of 2024/10/25 it is 7.0.\*)
* The host system must have access to the Internet in order to retrieve the virtual machine image and other guest packages.

## Usage

Follow the following instructions to use this solution:

1. Download the product release archive from [the Releases page](https://gitlab.com/brlin/ubuntu-desktop-vagrant/-/releases).
1. Extract the product release archive.
1. Launch a text terminal.
1. Change the working directory to the extracted product release directory by running the following command:

    ```bash
    cd /path/to/ubuntu-desktop-vagrant-X.Y.Z
    ```

1. Run the following command to provision the Ubuntu desktop virtual machine:

    ```bash
    vagrant up
    ```

   A VM console window should popup, allowing you to operate the desktop environment.

   You can also run the following command to gain access to a text shell:

    ```bash
    vagrant ssh
    ```

1. OPTIONAL: Run the following command to destroy the virtual machine:

    ```bash
    vagrant destroy
    ```

   All data will be lost after the operation.

## Credits

We would like to provide our gratitude to Yoshimasa Niwa, [who implemented and published the original implementation](https://gist.github.com/niw/bed28f823b4ebd2c504285ff99c1b2c2/0338af262d2c6664ed4ec2a2fc8d3f0b8b5d25f6).

## References

The following material are referenced during the development of this project:

* [A simple Vagrantfile to setup Ubuntu desktop environment with Google Chrome and Japanese input](https://gist.github.com/niw/bed28f823b4ebd2c504285ff99c1b2c2)  
  The inspiration of this project.
* [Shell Scripts - Provisioning | Vagrant | HashiCorp Developer](https://developer.hashicorp.com/vagrant/docs/provisioning/shell)  
  Explains how to run external provision shell scripts in a Vagrantfile.
* [Redirections (Bash Reference Manual)](https://www.gnu.org/software/bash/manual/html_node/Redirections.html#Here-Documents)  
  Explains how to use the Here Documents feature of the Bash shell scripting language.
* [Bug #1933248 “please drop virtualbox-guest-dkms virtualbox-guest...” : Bugs : virtualbox package : Ubuntu](https://bugs.launchpad.net/ubuntu/+source/virtualbox/+bug/1933248)  
  Explains the reason why the virtualbox-guest-dkms package is no longer available in recent Ubuntu releases.
* [Bug #2076520 “Ubuntu 24.04 LTS VBox VM does not boot anymore \[...” : Bugs : linux package : Ubuntu](https://bugs.launchpad.net/ubuntu/+source/linux/+bug/2076520)  
  Bug report regarding the problem where guest support no longer works when upgrading the Ubuntu kernel on a Ubuntu 24.04 system.

## Licensing

Unless otherwise noted(individual file's header/[REUSE.toml](REUSE.toml)), this product is licensed under [the MIT license](https://opensource.org/license/mit).

This work complies to [the REUSE Specification](https://reuse.software/spec/), refer the [REUSE - Make licensing easy for everyone](https://reuse.software/) website for info regarding the licensing of this product.
