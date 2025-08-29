#!/bin/bash

# Magtek Card Reader Plugin Installation Script
# This script sets up the required system dependencies and permissions

set -e

echo "=== Magtek Card Reader Plugin Installation ==="
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script as root. Run as a regular user with sudo access."
    exit 1
fi

# Check for sudo access
if ! sudo -n true 2>/dev/null; then
    echo "This script requires sudo access for system configuration."
    echo "You may be prompted for your password."
fi

# Detect Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
else
    echo "Error: Cannot detect Linux distribution"
    exit 1
fi

echo "Detected distribution: $DISTRO $VERSION"
echo

# Install system dependencies based on distribution
install_dependencies() {
    echo "Installing system dependencies..."
    
    case $DISTRO in
        ubuntu|debian|raspbian)
            sudo apt-get update
            sudo apt-get install -y \
                libusb-1.0-0-dev \
                libhidapi-dev \
                build-essential \
                cmake \
                pkg-config \
                libudev-dev
            ;;
        fedora)
            sudo dnf install -y \
                libusb1-devel \
                hidapi-devel \
                gcc-c++ \
                cmake \
                pkgconfig \
                systemd-devel
            ;;
        centos|rhel)
            if [ "${VERSION%%.*}" -ge 8 ]; then
                sudo dnf install -y \
                    libusb1-devel \
                    hidapi-devel \
                    gcc-c++ \
                    cmake \
                    pkgconfig
            else
                sudo yum install -y \
                    libusb1-devel \
                    hidapi-devel \
                    gcc-c++ \
                    cmake \
                    pkgconfig
            fi
            ;;
        arch|manjaro)
            sudo pacman -S --needed \
                libusb \
                hidapi \
                base-devel \
                cmake \
                pkgconf
            ;;
        opensuse|opensuse-leap|opensuse-tumbleweed)
            sudo zypper install -y \
                libusb-1_0-devel \
                libhidapi-devel \
                gcc-c++ \
                cmake \
                pkg-config
            ;;
        *)
            echo "Warning: Unsupported distribution '$DISTRO'"
            echo "Please install the following packages manually:"
            echo "- libusb-1.0 development headers"
            echo "- hidapi development headers"
            echo "- C++ compiler and build tools"
            echo "- cmake"
            echo "- pkg-config"
            echo
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
    
    echo "Dependencies installed successfully."
    echo
}

# Set up USB permissions
setup_usb_permissions() {
    echo "Setting up USB permissions..."
    
    # Create plugdev group if it doesn't exist
    if ! getent group plugdev > /dev/null 2>&1; then
        echo "Creating plugdev group..."
        sudo groupadd plugdev
    fi
    
    # Add user to plugdev group
    echo "Adding user $USER to plugdev group..."
    sudo usermod -aG plugdev $USER
    
    # Install udev rules
    echo "Installing udev rules..."
    sudo cp udev/99-magtek.rules /etc/udev/rules.d/
    sudo chmod 644 /etc/udev/rules.d/99-magtek.rules
    
    # Reload udev rules
    echo "Reloading udev rules..."
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    echo "USB permissions configured successfully."
    echo
}

# Verify installation
verify_installation() {
    echo "Verifying installation..."
    
    # Check if development packages are available
    echo -n "Checking libusb-1.0... "
    if pkg-config --exists libusb-1.0; then
        echo "OK"
    else
        echo "MISSING"
        echo "Warning: libusb-1.0 development package not found"
    fi
    
    echo -n "Checking hidapi... "
    if pkg-config --exists hidapi; then
        echo "OK"
    else
        echo "MISSING (this might be normal on some distributions)"
    fi
    
    # Check group membership
    echo -n "Checking group membership... "
    if groups $USER | grep -q plugdev; then
        echo "OK"
    else
        echo "PENDING (requires logout/login)"
    fi
    
    # Check udev rules
    echo -n "Checking udev rules... "
    if [ -f /etc/udev/rules.d/99-magtek.rules ]; then
        echo "OK"
    else
        echo "MISSING"
    fi
    
    echo
}

# Check for connected Magtek devices
check_devices() {
    echo "Checking for connected Magtek devices..."
    
    # List USB devices
    MAGTEK_DEVICES=$(lsusb | grep -i "0801:" || true)
    
    if [ -n "$MAGTEK_DEVICES" ]; then
        echo "Found Magtek devices:"
        echo "$MAGTEK_DEVICES"
    else
        echo "No Magtek devices found. Connect your device and try again."
    fi
    
    echo
}

# Main installation process
main() {
    echo "This script will:"
    echo "1. Install required system dependencies"
    echo "2. Set up USB permissions for Magtek devices"
    echo "3. Configure udev rules"
    echo "4. Add your user to the plugdev group"
    echo
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    install_dependencies
    setup_usb_permissions
    verify_installation
    check_devices
    
    echo "=== Installation Complete ==="
    echo
    echo "IMPORTANT: You must log out and log back in for group changes to take effect."
    echo
    echo "After logging back in:"
    echo "1. Connect your Magtek card reader"
    echo "2. Run 'flutter pub get' in your project"
    echo "3. Run the example app to test: 'flutter run -d linux'"
    echo
    echo "If you encounter issues, check the README.md and SETUP.md files for troubleshooting."
}

# Run main function
main "$@"
