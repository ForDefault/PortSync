echo '#!/bin/bash
exec > /tmp/port_changer.log 2>&1
echo "Starting script..."

# Prompt for sudo password upfront
#sudo -v

# Wait for PIA client process to launch
while ! pgrep -x "pia-client" > /dev/null; do
  echo "Waiting for PIA client..."
  sleep 1
done

echo "PIA client detected."

# Wait for the wgpia0 interface to connect
while ! ip link show wgpia0 > /dev/null 2>&1; do
  echo "Waiting for wgpia0 interface..."
  sleep 1
done

echo "Interface wgpia0 is up."

sleep 3

# Loop until the public IP is correctly retrieved
while true; do
  pubip=$(piactl get pubip)
  if [[ "$pubip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Public IP: $pubip"
    break
  else
    echo "Public IP not detected, retrying..."
    sleep 3

    # Close the PIA GUI
    killall pia-client

    # Wait a moment before reopening
    sleep 3

    # Trigger the second service to launch the PIA client as the user
    sudo systemctl start launchPIA.service
  fi
done

echo "PIA client reopened and detected."

# Wait for the wgpia0 interface to connect
while ! ip link show wgpia0 > /dev/null 2>&1; do
  echo "Waiting for wgpia0 interface..."
  sleep 1
done

echo "Interface wgpia0 is up."

sleep 5

# Wait for PIA client process to launch
while ! pgrep -x "pia-client" > /dev/null; do
  echo "Waiting for PIA client..."
  sleep 1
done

echo "PIA client detected."

# Wait for the wgpia0 interface to connect
while ! ip link show wgpia0 > /dev/null 2>&1; do
  echo "Waiting for wgpia0 interface..."
  sleep 1
done

# Retrieve the forwarded port using piactl
port=$(sudo piactl get portforward)
echo "Retrieved port: $port"

# Update qBittorrent configuration file
config_file="/home/YOURNAME/.config/qBittorrent/qBittorrent.conf"
sudo sed -i "s/Session\\\\Port=.*/Session\\\\Port=$port/" $config_file
echo "Configuration file updated."

# Define the path for old ports
old_port_path="/home/YOURNAME/PortSync_Config"
mkdir -p "$old_port_path"
old_port_file="$old_port_path/old.port.check.txt"

# Check if old.port.check.txt exists
if [ -f "$old_port_file" ]; then
  echo "File old.port.check.txt exists."
else
  # If the file does not exist, create it with the current port
  echo $port > "$old_port_file"
  echo "Created old.port.check.txt with port: $port"
fi

# Read the file and compare the port
old_port=$(head -n 1 "$old_port_file")
if [ "$old_port" == "$port" ]; then
  echo "Port is the same, no action needed."
else
  # If the port is different, update the file
  echo "Port is different. Updating old.port.check.txt."
  old_port=$(head -n 1 "$old_port_file")
  echo -e "$port\nold.$old_port" > "$old_port_file"
  echo "Updated old.port.check.txt with new port: $port"
fi

# Check if the port is already allowed in UFW
if sudo ufw status | grep -q "$port"; then
  echo "Port $port is already allowed by UFW. No action needed."
else
  echo "Port $port is not allowed by UFW. Adding port to UFW."
  sudo ufw allow $port
  echo "Port $port has been added to UFW."
fi

# Double-checking logic for old port removal
if [ "$old_port" == "$port" ]; then
  echo "Old Port same as New Port, no action needed for UFW removal."
else
  if [ "$old_port" != "$port" ]; then
    for i in {1..3}; do
      if sudo ufw status | grep -q "$old_port"; then
        echo "Old port $old_port is in UFW. Deleting old port from UFW."
        sudo ufw delete allow $old_port
        echo "Old port $old_port has been deleted from UFW."
      else
        echo "Old port $old_port is not in UFW."
        if [ $i -eq 2 ]; then
          break
        fi
      fi
      sleep 1
    done
  fi
fi' > /home/YOURNAME/PortSync_Config/port_changer.sh && \
chmod +x /home/YOURNAME/PortSync_Config/port_changer.sh && \
echo '#!/bin/bash
nohup env XDG_SESSION_TYPE=X11 /opt/piavpn/bin/pia-client %u &> /dev/null &' > /home/YOURNAME/PortSync_Config/launchPIA.sh && \
chmod +x /home/YOURNAME/PortSync_Config/launchPIA.sh && \
sudo bash -c 'cat > /etc/systemd/system/port_changer.service <<EOF
[Unit]
Description=Change Port for qBittorrent upon startup
After=network.target

[Service]
Type=simple
ExecStart=/home/YOURNAME/PortSync_Config/port_changer.sh
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF' && \
sudo bash -c 'cat > /etc/systemd/system/launchPIA.service <<EOF
[Unit]
Description=Launch PIA Client
After=network.target

[Service]
Type=simple
ExecStart=/home/YOURNAME/PortSync_Config/launchPIA.sh
Restart=on-failure
User=YOURNAME

[Install]
WantedBy=multi-user.target
EOF' && \
echo '#!/bin/bash
# Execute with passed arguments
"$@" && touch /tmp/port_changer_trigger
' >/home/YOURNAME/PortSync_Config/alias_portsync.sh && \
chmod +x /home/YOURNAME/PortSync_Config/alias_portsync.sh && \
if ! grep -q 'alias pia-client=' ~/.bashrc; then
  echo 'alias pia-client="/home/YOURNAME/PortSync_Config/alias_portsync.sh"' >> ~/.bashrc
fi && \
sudo systemctl daemon-reload && \
sudo systemctl start port_changer.service && \
sudo systemctl enable port_changer.service && \
source ~/.bashrc
