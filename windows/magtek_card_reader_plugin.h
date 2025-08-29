#ifndef FLUTTER_PLUGIN_MAGTEK_CARD_READER_PLUGIN_H_
#define FLUTTER_PLUGIN_MAGTEK_CARD_READER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/event_sink.h>

#include <memory>

// Forward declarations
class WindowsUsbDeviceManager;
struct DeviceInfo;
struct CardData;

namespace magtek_card_reader {

class MagtekCardReaderPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MagtekCardReaderPlugin();

  virtual ~MagtekCardReaderPlugin();

  // Disallow copy and assign.
  MagtekCardReaderPlugin(const MagtekCardReaderPlugin&) = delete;
  MagtekCardReaderPlugin& operator=(const MagtekCardReaderPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Event sink management
  void SetCardSwipeEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events);
  void SetDeviceEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> events);

 private:
  // Method handlers
  void HandleInitialize(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleDispose(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleGetConnectedDevices(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleConnectToDevice(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleDisconnect(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HandleIsConnected(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Event senders
  void SendCardSwipeEvent(const CardData& card_data);
  void SendDeviceEvent(const DeviceInfo& device_info);

  std::unique_ptr<WindowsUsbDeviceManager> device_manager_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> card_swipe_event_sink_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> device_event_sink_;
};

}  // namespace magtek_card_reader

#endif  // FLUTTER_PLUGIN_MAGTEK_CARD_READER_PLUGIN_H_
