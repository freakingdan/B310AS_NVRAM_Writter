#!/bin/bash

# =============================================================================
#                  Huawei B310as-938 NVRAM Writer for Termux
#                      Unofficial script by FREAKINGDAN
#                      Original script by Jerome Laliag
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print output

show_title() {
    clear
    echo -e "${BLUE}"
    echo "==================================================="
    echo "          Huawei B310as-938 NVRAM Writter          "
    echo "    Unofficial script for Termux by FREAKINGDAN    "
    echo "       Official script made by Jerome Laliag       "
    echo "==================================================="
    echo -e "${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_error() {
    echo -e "${RED}[x] $1${NC}"
}

cancel_script() {
    clear
    show_title
    echo -e "${YELLOW}[✓] NVRAM Writing successfully canceled${NC}"
    echo -e "${GREEN}Have a good day!"
    echo -e "${NC}"
}

# If the script is cancelled
trap 'cancel_script; exit 0' INT

# Clear screen and show titlep
show_title

# Kill existing adb server
print_status "Killing any existing ADB server..."
adb kill-server 2>/dev/null || true

# Connect to device
print_status "Connecting to the device via WiFi or Ethernet"
if adb connect 192.168.8.1:5555 > /dev/null 2>&1; then
    output=$(adb connect 192.168.8.1:5555 2>&1)

    if echo "$output" | grep -q "error\|unreachable\|failed"; then
        print_error "Failed to connect"
        print_warning "Make sure your phone is connected to a WiFi or USB Ethernet"
        exit 1
    fi
fi
print_success "Successfully connected"
read -p "Press Enter to continue or Ctrl+C to cancel"

# Show Title
show_title

# Get IMEI
read -p "Enter IMEI (15 digits): " modemimei
if [[ ! "$modemimei" =~ ^[0-9]{15}$ ]]; then
    print_error "Invalid IMEI"
    exit 1
fi
adb shell "atc AT^PHYNUM=IMEI,$modemimei,0 > /dev/null 2>&1"
print_success "IMEI set successfully"

# Get Serial Number
read -p "Enter Serial Number: " modemsn
adb shell "atc AT^SN=$modemsn > /dev/null 2>&1"
print_success "Serial Number set successfully"

# Get LAN MAC Address
read -p "Enter LAN MAC Address (XX:XX:XX:XX:XX:XX): " modemmac
if [[ ! "$modemmac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
    print_error "Invalid MAC Address!"
    exit 1
fi
adb shell "atc AT^PHYNUM=MAC,$modemmac,0 > /dev/null 2>&1"
print_success "MAC Address set successfully"

# Get WiFi SSID
read -p "Enter WiFi SSID: " modemwifi
# Create and push SSID script
cat > modem_ssid.sh << EOF
#!/bin/sh
atc AT^SSID=0,\"$modemwifi\" > /dev/null 2>&1
atc AT^SSID=1,\"$modemwifi-1\" > /dev/null 2>&1
atc AT^SSID=2,\"$modemwifi-2\" > /dev/null 2>&1
atc AT^SSID=3,\"$modemwifi-3\" > /dev/null 2>&1
EOF

adb push modem_ssid.sh /tmp/ 2>/dev/null
adb shell "chmod +x /tmp/ssid.sh && /tmp/ssid.sh '$modemwifi'"
print_success "WiFi SSID set successfully"

# Get WiFi Password
read -sp "Enter WiFi Password: " modempass
echo
# Set password for all 4 slots
for i in 0 1 2 3; do
    adb shell "atc AT^WIKEY=$i,\"$modempass\" > /dev/null 2>&1"
done
print_success "WiFi Password set successfully"

# Save to NVRAM
print_status "Saving configuration to NVRAM..."
adb shell "atc AT^INFORBU > /dev/null 2>&1"
print_success "Configuration saved!"

# Reset instruction
echo
echo -e "${YELLOW}"
echo "======================================================"
echo "IMPORTANT: Press and HOLD the reset button on the"
echo "           back of the modem for 5 seconds to"
echo "           apply the changes!"
echo "======================================================"
echo -e "${NC}"
adb shell "atc AT^RESET > /dev/null 2>&1"

read -p "Press Enter AFTER completing reset..."

show_title

# Cleanup
print_status "Cleaning up..."
adb kill-server 2>/dev/null || true
rm -f /tmp/modem_ssid.sh 2>/dev/null || true

# Finishing up
print_success "NVRAM Writing Complete"
echo
echo -e "${BLUE}Press any key to exit...${NC}"
read -n 1 -s
