#include "usb_device_manager.h"
#include <cstring>
#include <chrono>
#include <iostream>
#include <sstream>
#include <iomanip>

// Known Magtek product IDs
const std::vector<unsigned short> UsbDeviceManager::MAGTEK_PRODUCT_IDS = {
    0x0001, // Magtek Mini Swipe Reader
    0x0002, // Magtek USB Swipe Reader
    0x0003, // Magtek eDynamo
    0x0004, // Magtek uDynamo
    0x0010, // Magtek SureSwipe Reader
};

UsbDeviceManager::UsbDeviceManager() 
    : current_device_(nullptr), is_monitoring_(false) {
}

UsbDeviceManager::~UsbDeviceManager() {
    Cleanup();
}

bool UsbDeviceManager::Initialize() {
    // Initialize HIDAPI
    if (hid_init() != 0) {
        std::cerr << "Failed to initialize HIDAPI" << std::endl;
        return false;
    }
    return true;
}

void UsbDeviceManager::Cleanup() {
    StopMonitoring();
    Disconnect();
    hid_exit();
}

std::vector<DeviceInfo> UsbDeviceManager::GetConnectedDevices() {
    std::vector<DeviceInfo> devices;
    
    struct hid_device_info* device_info = hid_enumerate(0, 0);
    struct hid_device_info* current = device_info;
    
    while (current != nullptr) {
        if (IsMagtekDevice(current->vendor_id, current->product_id)) {
            DeviceInfo info;
            
            // Generate unique device ID
            std::stringstream ss;
            ss << std::hex << current->vendor_id << ":" << current->product_id << ":";
            if (current->serial_number) {
                // Convert wide string to regular string
                std::wstring ws(current->serial_number);
                ss << std::string(ws.begin(), ws.end());
            } else {
                ss << current->path;
            }
            info.device_id = ss.str();
            
            info.device_name = GetDeviceName(current->vendor_id, current->product_id);
            info.vendor_id = current->vendor_id;
            info.product_id = current->product_id;
            info.device_path = current->path ? current->path : "";
            
            if (current->serial_number) {
                std::wstring ws(current->serial_number);
                info.serial_number = std::string(ws.begin(), ws.end());
            }
            
            info.is_connected = (current_device_ != nullptr && current_device_id_ == info.device_id);
            
            devices.push_back(info);
        }
        current = current->next;
    }
    
    hid_free_enumeration(device_info);
    return devices;
}

bool UsbDeviceManager::ConnectToDevice(const std::string& device_id) {
    std::lock_guard<std::mutex> lock(device_mutex_);
    
    // Disconnect from current device first
    if (current_device_) {
        hid_close(current_device_);
        current_device_ = nullptr;
        current_device_id_.clear();
    }
    
    // Find the device in the enumeration
    struct hid_device_info* device_info = hid_enumerate(0, 0);
    struct hid_device_info* current = device_info;
    std::string target_path;
    
    while (current != nullptr) {
        if (IsMagtekDevice(current->vendor_id, current->product_id)) {
            // Generate device ID for comparison
            std::stringstream ss;
            ss << std::hex << current->vendor_id << ":" << current->product_id << ":";
            if (current->serial_number) {
                std::wstring ws(current->serial_number);
                ss << std::string(ws.begin(), ws.end());
            } else {
                ss << current->path;
            }
            
            if (ss.str() == device_id) {
                target_path = current->path;
                break;
            }
        }
        current = current->next;
    }
    
    hid_free_enumeration(device_info);
    
    if (target_path.empty()) {
        std::cerr << "Device not found: " << device_id << std::endl;
        return false;
    }
    
    // Open the device
    current_device_ = hid_open_path(target_path.c_str());
    if (!current_device_) {
        std::cerr << "Failed to open device: " << target_path << std::endl;
        return false;
    }
    
    current_device_id_ = device_id;
    
    // Set non-blocking mode
    hid_set_nonblocking(current_device_, 1);
    
    // Notify about device connection
    if (device_connection_callback_) {
        auto devices = GetConnectedDevices();
        for (const auto& device : devices) {
            if (device.device_id == device_id) {
                device_connection_callback_(device);
                break;
            }
        }
    }
    
    std::cout << "Connected to device: " << device_id << std::endl;
    return true;
}

void UsbDeviceManager::Disconnect() {
    std::lock_guard<std::mutex> lock(device_mutex_);
    
    if (current_device_) {
        hid_close(current_device_);
        current_device_ = nullptr;
        current_device_id_.clear();
        std::cout << "Disconnected from device" << std::endl;
    }
}

bool UsbDeviceManager::IsConnected() const {
    std::lock_guard<std::mutex> lock(device_mutex_);
    return current_device_ != nullptr;
}

void UsbDeviceManager::StartMonitoring() {
    if (is_monitoring_.load()) {
        return;
    }
    
    is_monitoring_ = true;
    monitoring_thread_ = std::thread(&UsbDeviceManager::MonitoringThread, this);
    std::cout << "Started device monitoring" << std::endl;
}

void UsbDeviceManager::StopMonitoring() {
    if (!is_monitoring_.load()) {
        return;
    }
    
    is_monitoring_ = false;
    if (monitoring_thread_.joinable()) {
        monitoring_thread_.join();
    }
    std::cout << "Stopped device monitoring" << std::endl;
}

void UsbDeviceManager::SetCardSwipeCallback(std::function<void(const CardData&)> callback) {
    card_swipe_callback_ = callback;
}

void UsbDeviceManager::SetDeviceConnectionCallback(std::function<void(const DeviceInfo&)> callback) {
    device_connection_callback_ = callback;
}

bool UsbDeviceManager::IsMagtekDevice(unsigned short vendor_id, unsigned short product_id) {
    if (vendor_id != MAGTEK_VENDOR_ID) {
        return false;
    }
    
    for (unsigned short pid : MAGTEK_PRODUCT_IDS) {
        if (product_id == pid) {
            return true;
        }
    }
    
    return false;
}

std::string UsbDeviceManager::GetDeviceName(unsigned short vendor_id, unsigned short product_id) {
    if (vendor_id != MAGTEK_VENDOR_ID) {
        return "Unknown Device";
    }
    
    switch (product_id) {
        case 0x0001:
            return "Magtek Mini Swipe Reader";
        case 0x0002:
            return "Magtek USB Swipe Reader";
        case 0x0003:
            return "Magtek eDynamo";
        case 0x0004:
            return "Magtek uDynamo";
        case 0x0010:
            return "Magtek SureSwipe Reader";
        default:
            std::stringstream ss;
            ss << "Magtek Card Reader (PID: 0x" << std::hex << std::setfill('0') << std::setw(4) << product_id << ")";
            return ss.str();
    }
}

void UsbDeviceManager::MonitoringThread() {
    const int SLEEP_INTERVAL_MS = 50; // Check every 50ms
    
    while (is_monitoring_.load()) {
        if (IsConnected()) {
            ReadFromDevice();
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(SLEEP_INTERVAL_MS));
    }
}

bool UsbDeviceManager::ReadFromDevice() {
    if (!current_device_) {
        return false;
    }
    
    unsigned char buffer[256];
    int bytes_read = hid_read_timeout(current_device_, buffer, sizeof(buffer), 10); // 10ms timeout
    
    if (bytes_read > 0) {
        // Parse the input report and extract card data
        CardData card_data = ParseInputReport(buffer, bytes_read, current_device_id_);
        
        // Only notify if we have valid track data
        if (!card_data.track1.empty() || !card_data.track2.empty() || !card_data.track3.empty()) {
            if (card_swipe_callback_) {
                card_swipe_callback_(card_data);
            }
            std::cout << "Card swipe detected" << std::endl;
        }
        return true;
    } else if (bytes_read < 0) {
        // Error occurred
        std::cerr << "Error reading from device: " << hid_error(current_device_) << std::endl;
        return false;
    }
    
    // No data available (bytes_read == 0)
    return true;
}

CardData UsbDeviceManager::ParseInputReport(const unsigned char* data, size_t length, const std::string& device_id) {
    CardData card_data;
    card_data.device_id = device_id;
    card_data.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    
    // Store raw response for debugging
    std::stringstream raw_ss;
    for (size_t i = 0; i < length; i++) {
        raw_ss << std::hex << std::setfill('0') << std::setw(2) << (int)data[i] << " ";
    }
    card_data.raw_response = raw_ss.str();
    
    // Magtek devices typically send card data in a specific format
    // The exact format may vary by device model, but generally:
    // - Byte 0: Report ID or status
    // - Following bytes: Track data or encoded magnetic stripe data
    
    if (length < 2) {
        return card_data; // Not enough data
    }
    
    // Look for track data patterns in the input report
    // Track 1: Starts with '%' (0x25), ends with '?' (0x3F)
    // Track 2: Starts with ';' (0x3B), ends with '?' (0x3F)
    // Track 3: Variable format
    
    std::string data_str;
    for (size_t i = 1; i < length; i++) { // Skip first byte (report ID)
        if (data[i] >= 0x20 && data[i] <= 0x7E) { // Printable ASCII
            data_str += (char)data[i];
        }
    }
    
    if (data_str.empty()) {
        return card_data;
    }
    
    // Parse track data from the string
    size_t track1_start = data_str.find('%');
    if (track1_start != std::string::npos) {
        size_t track1_end = data_str.find('?', track1_start);
        if (track1_end != std::string::npos) {
            card_data.track1 = data_str.substr(track1_start, track1_end - track1_start + 1);
        }
    }
    
    size_t track2_start = data_str.find(';');
    if (track2_start != std::string::npos) {
        size_t track2_end = data_str.find('?', track2_start);
        if (track2_end != std::string::npos) {
            card_data.track2 = data_str.substr(track2_start, track2_end - track2_start + 1);
        }
    }
    
    // Track 3 parsing is more complex and device-dependent
    // For now, we'll leave it empty unless we find a specific pattern
    
    return card_data;
}

std::string UsbDeviceManager::ParseTrackData(const unsigned char* data, size_t length, int track_number) {
    // This method can be extended for more sophisticated track data parsing
    // based on the specific Magtek device protocol
    return "";
}
