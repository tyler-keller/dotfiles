#!/bin/bash
# Install the Eternal Terminal *server* (etserver) on a Linux box so you can
# attach to a persistent zellij session over a reconnecting connection.
#
# Pairs with mac/et.zsh on the client side:  et <host> -c "zellij attach -c <host>"
#
# Default port is 2022 (TCP+UDP); config lives at /etc/et.cfg. ET bootstraps
# over ssh, so ssh access to this box must already work from the client.
set -e

install_et_apt() {
    # Ubuntu/Debian via the maintainer PPA (covers focal..noble and newer).
    sudo add-apt-repository -y ppa:jgmath2000/et
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y et
}

if command -v etserver &> /dev/null; then
    echo "etserver already installed: $(etserver --version 2>/dev/null | head -1)"
else
    if command -v apt-get &> /dev/null; then
        install_et_apt
    else
        echo "No apt-get found. Install Eternal Terminal manually:"
        echo "  https://github.com/MisterTea/EternalTerminal#installing"
        echo "  (fallback: build from source, or grab a release .deb/.rpm)"
        exit 1
    fi
fi

# systemd service ships with the package; make sure it is enabled + running.
sudo systemctl enable --now et

echo "=== et service ==="
systemctl is-active et
ss -tlnp 2>/dev/null | grep 2022 || sudo ss -tlnp | grep 2022 || true
echo "done. connect from a client with:  et <host> -c \"zellij attach -c <host>\""
