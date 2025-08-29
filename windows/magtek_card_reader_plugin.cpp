#include "magtek_card_reader_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>

#include <memory>
#include <sstream>

#include "windows_usb_device_manager.h"

namespace magtek_card_reader {

// static
void MagtekCardReaderPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  
  // Create method channel
  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "magtek_card_reader",
          &flutter::StandardMethodCodec::GetInstance());

  // Create event channels
  auto card_swipe_event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "magtek_card_reader/card_swipe",
          &flutter::StandardMethodCodec::GetInstance());

  auto device_event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "magtek_card_reader/device_events",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<MagtekCardReaderPlugin>();

  // Set up method channel
  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // Set up event channels
  auto card_swipe_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->SetCardSwipeEventSink(std::move(events));
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->SetCardSwipeEventSink(nullptr);
        return nullptr;
      });

  auto device_event_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->SetDeviceEventSink(std::move(events));
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->SetDeviceEventSink(nullptr);
        return nullptr;
      });

  card_swipe_event_channel->SetStreamHandler(std::move(card_swipe_handler));
  device_event_channel->SetStreamHandler(std::move(device_event_handler));

  registrar->AddPlugin(std::move(plugin));
}

MagtekCardReaderPlugin::MagtekCardReaderPlugin() 
    : device_manager_(std::make_unique<WindowsUsbDeviceManager>()) {}

MagtekCardReaderPlugin::~MagtekCardReaderPlugin() {
  if (device_manager_) {
    device_manager_->Cleanup();
  }
}

void MagtekCardReaderPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const std::string& method_name = method_call.method_name();
  
  if (method_name == "getPlatformVersion") {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } 
  else if (method_name == "initialize") {
    HandleInitialize(result);
  }
  else if (method_name == "dispose") {
    HandleDispose(result);
  }
  else if (method_name == "getConnectedDevices") {
    HandleGetConnectedDevices(result);
  }
  else if (method_name == "connectToDevice") {
    HandleConnectToDevice(method_call, result);
  }
  else if (method_name == "disconnect") {
    HandleDisconnect(result);
  }
  else if (method_name == "isConnected") {
    HandleIsConnected(result);
  }
  else {
    result->NotImplemented();
  }
}

void MagtekCardReaderPlugin::HandleInitialize(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (!device_manager_->Initialize()) {
    result->Error("INITIALIZATION_FAILED", "Failed to initialize USB device manager");
    return;
  }

  // Set up callbacks
  device_manager_->SetCardSwipeCallback([this](const CardData& card_data) {
    SendCardSwipeEvent(card_data);
  });

  device_manager_->SetDeviceConnectionCallback([this](const DeviceInfo& device_info) {
    SendDeviceEvent(device_info);
  });

  device_manager_->StartMonitoring();

  result->Success();
}

void MagtekCardReaderPlugin::HandleDispose(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (device_manager_) {
    device_manager_->Cleanup();
  }

  result->Success();
}

void MagtekCardReaderPlugin::HandleGetConnectedDevices(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (!device_manager_) {
    result->Error("NOT_INITIALIZED", "Device manager not initialized");
    return;
  }

  auto devices = device_manager_->GetConnectedDevices();
  flutter::EncodableList device_list;

  for (const auto& device : devices) {
    flutter::EncodableMap device_map;
    device_map[flutter::EncodableValue("deviceId")] = flutter::EncodableValue(device.device_id);
    device_map[flutter::EncodableValue("deviceName")] = flutter::EncodableValue(device.device_name);
    device_map[flutter::EncodableValue("vendorId")] = flutter::EncodableValue(static_cast<int>(device.vendor_id));
    device_map[flutter::EncodableValue("productId")] = flutter::EncodableValue(static_cast<int>(device.product_id));
    device_map[flutter::EncodableValue("serialNumber")] = flutter::EncodableValue(device.serial_number);
    device_map[flutter::EncodableValue("devicePath")] = flutter::EncodableValue(device.device_path);
    device_map[flutter::EncodableValue("isConnected")] = flutter::EncodableValue(device.is_connected);

    device_list.emplace_back(device_map);
  }

  result->Success(flutter::EncodableValue(device_list));
}

void MagtekCardReaderPlugin::HandleConnectToDevice(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (!device_manager_) {
    result->Error("NOT_INITIALIZED", "Device manager not initialized");
    return;
  }

  const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!arguments) {
    result->Error("INVALID_ARGUMENTS", "Arguments must be a map");
    return;
  }

  auto device_id_it = arguments->find(flutter::EncodableValue("deviceId"));
  if (device_id_it == arguments->end()) {
    result->Error("INVALID_ARGUMENTS", "deviceId is required");
    return;
  }

  const auto* device_id = std::get_if<std::string>(&device_id_it->second);
  if (!device_id) {
    result->Error("INVALID_ARGUMENTS", "deviceId must be a string");
    return;
  }

  bool success = device_manager_->ConnectToDevice(*device_id);
  result->Success(flutter::EncodableValue(success));
}

void MagtekCardReaderPlugin::HandleDisconnect(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (!device_manager_) {
    result->Error("NOT_INITIALIZED", "Device manager not initialized");
    return;
  }

  device_manager_->Disconnect();
  result->Success();
}

void MagtekCardReaderPlugin::HandleIsConnected(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  if (!device_manager_) {
    result->Success(flutter::EncodableValue(false));
    return;
  }

  bool connected = device_manager_->IsConnected();
  result->Success(flutter::EncodableValue(connected));
}

void MagtekCardReaderPlugin::SetCardSwipeEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events) {
  card_swipe_event_sink_ = std::move(events);
}

void MagtekCardReaderPlugin::SetDeviceEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events) {
  device_event_sink_ = std::move(events);
}

void MagtekCardReaderPlugin::SendCardSwipeEvent(const CardData& card_data) {
  if (!card_swipe_event_sink_) {
    return;
  }

  flutter::EncodableMap event_map;
  event_map[flutter::EncodableValue("track1")] = flutter::EncodableValue(card_data.track1);
  event_map[flutter::EncodableValue("track2")] = flutter::EncodableValue(card_data.track2);
  event_map[flutter::EncodableValue("track3")] = flutter::EncodableValue(card_data.track3);
  event_map[flutter::EncodableValue("deviceId")] = flutter::EncodableValue(card_data.device_id);
  event_map[flutter::EncodableValue("rawResponse")] = flutter::EncodableValue(card_data.raw_response);
  event_map[flutter::EncodableValue("timestamp")] = flutter::EncodableValue(card_data.timestamp);

  card_swipe_event_sink_->Success(flutter::EncodableValue(event_map));
}

void MagtekCardReaderPlugin::SendDeviceEvent(const DeviceInfo& device_info) {
  if (!device_event_sink_) {
    return;
  }

  flutter::EncodableMap device_map;
  device_map[flutter::EncodableValue("deviceId")] = flutter::EncodableValue(device_info.device_id);
  device_map[flutter::EncodableValue("deviceName")] = flutter::EncodableValue(device_info.device_name);
  device_map[flutter::EncodableValue("vendorId")] = flutter::EncodableValue(static_cast<int>(device_info.vendor_id));
  device_map[flutter::EncodableValue("productId")] = flutter::EncodableValue(static_cast<int>(device_info.product_id));
  device_map[flutter::EncodableValue("serialNumber")] = flutter::EncodableValue(device_info.serial_number);
  device_map[flutter::EncodableValue("devicePath")] = flutter::EncodableValue(device_info.device_path);
  device_map[flutter::EncodableValue("isConnected")] = flutter::EncodableValue(device_info.is_connected);

  flutter::EncodableMap event_map;
  event_map[flutter::EncodableValue("type")] = flutter::EncodableValue("device_connected");
  event_map[flutter::EncodableValue("device")] = flutter::EncodableValue(device_map);

  device_event_sink_->Success(flutter::EncodableValue(event_map));
}

}  // namespace magtek_card_reader
