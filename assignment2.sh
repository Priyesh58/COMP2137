#!/bin/bash

# Ensure the script is executed as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Function to display messages
echo_step() {
  echo -e "\033[1;36m$@\033[0m" # Cyan
}

# Update netplan configuration for 192.168.16 network
configure_network() {
  echo_step "Configuring Network..."
  cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.16.21
      gateway4: 192.168.16.2
      nameservers:
          addresses: [8.8.8.8, 8.8.4.4]
EOF
  netplan apply
}

# Update /etc/hosts
configure_hosts() {
  echo_step "Updating /etc/hosts..."
  sed -i '/server1/d' /etc/hosts
  echo "192.168.16.21 server1" >> /etc/hosts
}

# Install and configure Apache and Squid
install_software() {
  echo_step "Installing Apache and Squid..."
  apt-get update
  apt-get install -y apache2 squid
  systemctl enable --now apache2 squid
}

# Configure UFW
configure_firewall() {
  echo_step "Configuring Firewall..."
  ufw allow from 192.168.16.0/24 to any port 22
  ufw allow 80
  ufw allow 3128
  ufw --force enable
}

# Create user accounts, directories, and SSH keys
create_users() {
  echo_step "Creating User Accounts..."
  for user in dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda; do
    if ! id "$user" &>/dev/null; then
      useradd -m -s /bin/bash "$user"
      echo "$user:password" | chpasswd
      
      # SSH key setup
      mkdir -p /home/$user/.ssh
      chmod 700 /home/$user/.ssh
      touch /home/$user/.ssh/authorized_keys
      chmod 600 /home/$user/.ssh/authorized_keys
      
      # Add public key for dennis
      if [ "$user" = "dennis" ]; then
        echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> /home/$user/.ssh/authorized_keys
        usermod -aG sudo $user
      fi
      
      # Generate and add RSA and ED25519 keys for each user
      ssh-keygen -t rsa -N "" -f /home/$user/.ssh/id_rsa
      ssh-keygen -t ed25519 -N "" -f /home/$user/.ssh/id_ed25519
      cat /home/$user/.ssh/id_rsa.pub >> /home/$user/.ssh/authorized_keys
      cat /home/$user/.ssh/id_ed25519.pub >> /home/$user/.ssh/authorized_keys
      
      chown $user:$user -R /home/$user/.ssh
    fi
  done
}

main() {
  configure_network
  configure_hosts
  install_software
  configure_firewall
  create_users
  echo_step "Script execution completed."
}

main "$@"
