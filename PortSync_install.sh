echo '#!/bin/bash
exec > /home/YOURNAME/PortSync_Config/port_changer.log 2>&1

echo "Starting script..."

# Main loop to continuously check until a valid IP is found
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
        sleep 5  # Adjust the sleep interval to avoid tight loop
      done

      # Wait for the wgpia0 interface to connect
      while ! ip link show wgpia0 > /dev/null 2>&1; do
        echo "Waiting for wgpia0 interface..."
        sleep 5  # Adjust the sleep interval to avoid tight loop
      done

      while true; do
        # Get the current connection state
        vpnip=$(piactl get vpnip)
        if [[ "$vpnip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          echo "VPN IP: $vpnip"
          break
        fi
        sleep 5  # Adjust the sleep interval to avoid tight loop
      done
        
      # Re-fetch the public IP after detecting PIA client
      pubip=$(piactl get pubip)
      if [[ "$pubip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Public IP: $pubip"
        break 2  # Break out of both loops if new IP is valid
      else
        echo "Public IP still not detected, retrying..."
        sleep 3  # Adjust the sleep interval to avoid tight loop
        # Disconnect and reconnect logic
        while ! piactl disconnect > /dev/null; do
          echo "Waiting for disconnect..."
          sleep 7  # Adjust the sleep interval to avoid tight loop
        done
        
        while ! piactl connect > /dev/null; do
          echo "Waiting for reconnect..."
          sleep 5  # Adjust the sleep interval to avoid tight loop
        done

        # Wait for PIA to report as connected
        while ! piactl get connectionstate | grep -q "Connected"; do
          echo "Waiting for PIA to be connected..."
          sleep 5  # Adjust the sleep interval to avoid tight loop
        done

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

if [ "$old_port" != "$port" ]; then
    echo "Port has changed. Initiating check for old port removal..."
    attempts=0
    while [ $attempts -lt 3 ]; do
        if sudo ufw status | grep -q "$old_port"; then
            echo "Old port $old_port is still in UFW. Attempting to delete..."
            sudo ufw delete allow $old_port
            if ! sudo ufw status | grep -q "$old_port"; then
                echo "Successfully deleted old port $old_port from UFW."
                break
            else
                echo "Failed to delete old port $old_port. Retrying..."
            fi
        else
            echo "Old port $old_port is not in UFW. No need for further action."
            break
        fi
        ((attempts++))
        sleep 1
    done
    if [ $attempts -eq 3 ]; then
        echo "Failed to remove old port after three attempts."
    fi
else
    echo "Old Port is the same as the new Port, no action needed for UFW removal."
fi

' > /home/YOURNAME/PortSync_Config/port_changer.sh && \
chmod +x /home/YOURNAME/PortSync_Config/port_changer.sh && \

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
EOF' && \

sudo bash -c 'cat > /etc/systemd/system/port_changer.path <<EOF
[Unit]
Description=Path Unit to trigger port_changer.service

[Path]
PathChanged=/tmp/port_changer_trigger

[Install]
WantedBy=multi-user.target
EOF' && \


# Create the alias_portsync.sh script
echo '#!/bin/bash
# Execute with passed arguments
"$@" && touch /tmp/port_changer_trigger
' >/home/YOURNAME/PortSync_Config/alias_portsync.sh && \
chmod +x /home/YOURNAME/PortSync_Config/alias_portsync.sh && \

# Add alias to .bashrc if not present
if ! grep -q 'alias pia-client=' ~/.bashrc; then
  echo 'alias pia-client="/home/YOURNAME/PortSync_Config/alias_portsync.sh"' >> ~/.bashrc
fi



# Reload the systemd daemon and enable the services
sudo systemctl daemon-reload
sudo systemctl start port_changer.service
sudo systemctl enable port_changer.service
sudo systemctl enable port_changer.path

# Source the .bashrc to apply the alias
source ~/.bashrc
