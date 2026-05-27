# Eternal Terminal client helpers — source from the Mac's ~/.zshrc.
#
# Requires the et client:  brew install MisterTea/et/et
# Requires an ssh alias for the host (et bootstraps over ssh, then runs the
# ET data channel on port 2022). e.g. in ~/.ssh/config:
#
#     Host jackbot
#         HostName 192.168.10.202
#         User tyler
#
# `et <host> -c "<cmd>"` runs <cmd> on connect (and exits when it returns).
# Here we attach-or-create a zellij session named after the host, so panes/tabs
# persist across disconnects, laptop reboots, and network blips (ET auto-reconnects
# the PTY; zellij survives even if the PTY dies).

et-jackbot() { et jackbot -c "zellij attach -c jackbot"; }

# Generic helper: et-host <ssh-alias>  ->  attach session of the same name.
et-host() { et "$1" -c "zellij attach -c $1"; }
