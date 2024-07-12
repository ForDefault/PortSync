# PortSync
.>> Required: <<.
>Needs the GUI VPN PIA (Private Internet Access) to work - must be the GUI

>Currently only supports qBittorent

>Only Linux users who also use UFW as their firewall

## Automated to:

>Fix PIA bug: 

- PIA failing to get the needed user "IP" upon launch. This error was resulting in a `false positive` - appearing like the VPN connection exists when it does not. 

>qBittorrent port 

- qBittorrent port will match PIA's Forwarded Port

>Change UFW

- ADD PIA Forwarded port to the UFW

- REMOVE any old Forwarded port from PIA that exists on the UFW

>Create System Service

- So anytime PIA VPN is launched (`/opt/piavpn/bin/pia-client`) it ensures the above actions occur. 

### PortSync_Config 
>/home/$USER/PortSync_Config

- any scripts or files will be kept here
- the port change to UFW is located here in the `old.port.check.txt`

> The install is easy and will automatically change the script to match your username

## Install
```
PUTHERE=$(whoami) && \
REPO_URL="https://github.com/ForDefault/PortSync.git" && \
REPO_NAME=$(basename $REPO_URL .git) && \
DEST_DIR="/home/$PUTHERE/$REPO_NAME" && \
if [ -d "$DEST_DIR" ]; then \
  rm -rf "$DEST_DIR"; \
fi && \
git clone $REPO_URL "$DEST_DIR" && \
cd "$DEST_DIR" && \
mkdir -p /home/$PUTHERE/PortSync_Config && \
sed -i "s|/home/YOURNAME|/home/$PUTHERE|g" PortSync_install.sh && \
chmod +x PortSync_install.sh && \
echo installing && \
./PortSync_install.sh && \
cd .. && rm -rf "$DEST_DIR" && \
echo running && \
/home/$PUTHERE/PortSync_Config/port_changer.sh && \
cat /tmp/port_changer.log
```

## What PortSync Does (short form)
- 
