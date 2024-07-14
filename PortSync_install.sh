echo '#!/bin/bash
exec > /home/YOURNAME/PortSync_Config/port_changer.log 2>&1

echo "Starting script..."

# Main loop to continuously check until a valid IP is found
while true; do
  # Attempt to fetch the public IP
  pubip=$(piactl get pubip)
  
  # Check if the fetched IP address is correctly formatted
  if [[ "$pubip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Public IP: $pubip"
    break  # Exit the main loop if IP is valid
  else
    echo "Public IP not detected, starting retry logic..."
    # Inner loop to handle retries when IP is not valid
    while true; do
      # Wait for PIA client process to launch
      while ! pgrep -x "pia-client" > /dev/null; do
        echo "Waiting for PIA client..."
        sleep 1
      done
      # Wait for the wgpia0 interface to connect
      while ! ip link show wgpia0 > /dev/null 2>&1; do
        echo "Waiting for wgpia0 interface..."
        sleep 1
      done

      echo "PIA client detected."

      # Re-fetch the public IP after detecting PIA client
      pubip=$(piactl get pubip)
      if [[ "$pubip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Public IP: $pubip"
        break 2  # Break out of both loops if new IP is valid
      else
        echo "Public IP still not detected, retrying..."
        sleep 3

        # Close the PIA GUI
        killall pia-client

        # Wait a moment before reopening
        sleep 3

        # Create the trigger file to start the PIA service again
        touch /tmp/launchPIA_trigger
      fi
    done
  fi
done

echo "Script completed. Valid IP retrieved."

sleep 3

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
fi
' > /home/YOURNAME/PortSync_Config/port_changer.sh && \
chmod +x /home/YOURNAME/PortSync_Config/port_changer.sh


# Create the port_changer.service file
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
EOF'

# Create the launchPIA.service file
sudo bash -c 'cat > /etc/systemd/system/launchPIA.service <<EOF
[Unit]
Description=Launch PIA Client
After=network.target

[Service]
Type=simple
ExecStart=/home/YOURNAME/PortSync_Config/redirect.sh
Restart=on-failure
RestartSec=10
User=YOURNAME
Environment=XDG_SESSION_TYPE=x11
Environment=DISPLAY=:0


[Install]
WantedBy=multi-user.target
EOF'

# Create the launchPIA.path file
sudo bash -c 'cat > /etc/systemd/system/launchPIA.path <<EOF
[Unit]
Description=Path Unit for Launch PIA Client

[Path]
PathExists=/tmp/launchPIA_trigger

[Install]
WantedBy=multi-user.target
EOF'

echo '#!/bin/bash
su YOURNAME /home/YOURNAME/PortSync_Config/launchPIA.sh ' > /home/YOURNAME/PortSync_Config/redirect.sh && \
chmod +x /home/YOURNAME/PortSync_Config/redirect.sh

# Create the launchPIA.sh script
echo '#!/bin/bash
screen -dmS pia_session nohup env XDG_SESSION_TYPE=x11 DISPLAY=:0 /opt/piavpn/bin/pia-client %u &> /dev/null' > /home/YOURNAME/PortSync_Config/launchPIA.sh && \
chmod +x /home/YOURNAME/PortSync_Config/launchPIA.sh


# Create the alias_portsync.sh script
echo '#!/bin/bash
# Execute with passed arguments
"$@" && touch /tmp/port_changer_trigger
' >/home/YOURNAME/PortSync_Config/alias_portsync.sh && \
chmod +x /home/YOURNAME/PortSync_Config/alias_portsync.sh

# Add alias to .bashrc if not present
if ! grep -q 'alias pia-client=' ~/.bashrc; then
  echo 'alias pia-client="/home/YOURNAME/PortSync_Config/alias_portsync.sh"' >> ~/.bashrc
fi

# Reload the systemd daemon and enable the services
sudo systemctl daemon-reload
sudo systemctl start port_changer.service
sudo systemctl enable port_changer.service
sudo systemctl enable launchPIA.path

# Source the .bashrc to apply the alias
source ~/.bashrc
