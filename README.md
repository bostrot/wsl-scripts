# wsl-scripts

This is the repository for the community WSL Quick Action scripts.

## Contribute

See `scripts/fake-systemd-nonroot` as an example.

Try to keep your scripts maintainable. If you download files from non-verified sources (e.g. using wget) please check if the file checksum is correct:

Here is a little example on how you could do that:

    wget https://raw.githubusercontent.com/bostrot/fake-systemd/0d7518a61d71d1716d8dcd5b05a2c4cf57c24f84/systemctl -O /tmp/systemctl.download
    if [ -f /tmp/systemctl.download ]; then 
        echo "0ba2e32057e7a09977d45a033caf5558ca5f40d2f4f0d75429a7c2fd7eb0c7f7 /tmp/systemctl.download" | sha256sum --check
        if [ $? -eq 0 ]; then
            chmod +x /tmp/systemctl.download
            mv /tmp/systemctl.download /usr/bin/systemctl
        else
            echo "Checksum failed"
            exit 1
        fi
    fi

For metadata please add an `info.yml` file with at least following content:

    name: fake-systemd-wsl-nonroot
    description: Fake systemd for WSL as non-root user (but with sudo rights)
    version: 1.0.0
    author: bostrot
    license: MIT
    git: https://github.com/bostrot/fake-systemd
    distro: Debian

__Note: The name MUST be the same as the folder name__
