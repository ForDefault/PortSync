# PortSync
.>> Required: <<.
>Needs the GUI VPN PIA (Private Internet Access) to work - must be the GUI

>Currently only supports qBittorent

>Only Linux users who also use UFW as their firewall

### Automated to:

>Fix PIA bug: 
- PIA failing to get the needed user "IP" upon launch. This error was resulting in a `false positive` - appearing like the VPN connection exists when it does not. 
>qBittorrent port 
- qBittorrent port will match PIA's Forwarded Port
>Change UFW

-ADD PIA Forwarded port to the UFW

-REMOVE any old Forwarded port from PIA that exists on the UFW

>Create System Service

-So anytime PIA VPN is launched (`/opt/piavpn/bin/pia-client`) it ensures the above actions occur. 

### PortSync_Config 
>/home/$USER/PortSync_Config

- any scripts or files will be kept here
- the port change to UFW is located here in the `old.port.check.txt`

> The install is easy and will automatically change the script to match your username

## Install
```
PUTHERE=$(whoami) && \
REPO_URL="https://github.com/ForDefault/qbittorrent_automatic_forward_port_changer.git" && \
REPO_NAME=$(basename $REPO_URL .git) && \
git clone $REPO_URL && \
cd $REPO_NAME && \
sed -i "s|/home/\YOURNAME|/home/$PUTHERE|g" for_pia_install.sh && \
chmod +x for_pia_install.sh && \
./for_pia_install.sh && \
cd .. && rm -rf $REPO_NAME

```

## What PortSync Does (short form)
- 
