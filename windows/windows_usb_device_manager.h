#ifndef WINDOWS_USB_DEVICE_MANAGER_H_
#define WINDOWS_USB_DEVICE_MANAGER_H_

#include <windows.h>
#include <setupapi.h>
#include <hidsdi.h>
#include <hidapi.h>
#include <vector>
#include <string>
#include <memory>
#include <functional>
#include <mutex>
#include <thread>
#include <atomic>

struct DeviceInfo {
    std::string device_id;
    std::string device_name;
    unsigned short vendor_id;
    unsigned short product_id;
    std::string serial_number;
    std::string device_path;
    bool is_connected;
};

struct CardData {
    std::string track1;
    std::string track2;
    std::string track3;
    std::string device_id;
    std::string raw_response;
    long long timestamp;
};

class WindowsUsbDeviceManager {
public:
    WindowsUsbDeviceManager();
    ~WindowsUsbDeviceManager();

    // Initialize the USB device manager
    bool Initialize();
    
    // Cleanup resources
    void Cleanup();
    
    // Get list of connected Magtek devices
    std::vector<DeviceInfo> GetConnectedDevices();
    
    // Connect to a specific device
    bool ConnectToDevice(const std::string& device_id);
    
    // Disconnect from current device
    void Disconnect();
    
    // Check if connected to a device
    bool IsConnected() const;
    
    // Start monitoring for card swipes
    void StartMonitoring();
    
    // Stop monitoring
    void StopMonitoring();
    
    // Set callback for card swipe events
    void SetCardSwipeCallback(std::function<void(const CardData&)> callback);
    
    // Set callback for device connection events
    void SetDeviceConnectionCallback(std::function<void(const DeviceInfo&)> callback);

private:
    // Check if vendor/product ID is a Magtek device
    bool IsMagtekDevice(unsigned short vendor_id, unsigned short product_id);
    
    // Get device name from vendor/product ID
    std::string GetDeviceName(unsigned short vendor_id, unsigned short product_id);
    
    // Parse HID input report from device
    CardData ParseInputReport(const unsigned char* data, size_t length, const std::string& device_id);
    
    // Device monitoring thread function
    void MonitoringThread();
    
    // Read data from HID device
    bool ReadFromDevice();
    
    // Convert wide string to UTF-8 string
    std::string WideStringToUtf8(const std::wstring& wide_string);
    
    // Convert UTF-8 string to wide string
    std::wstring Utf8ToWideString(const std::string& utf8_string);

    hid_device* current_device_;
    std::string current_device_id_;
    std::atomic<bool> is_monitoring_;
    std::thread monitoring_thread_;
    mutable std::mutex device_mutex_;
    
    std::function<void(const CardData&)> card_swipe_callback_;
    std::function<void(const DeviceInfo&)> device_connection_callback_;
    
    // Magtek vendor IDs and product IDs
    static const unsigned short MAGTEK_VENDOR_ID = 0x0801;
    static const std::vector<unsigned short> MAGTEK_PRODUCT_IDS;
};

#endif  // WINDOWS_USB_DEVICE_MANAGER_H_
