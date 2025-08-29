#include "include/magtek_card_reader/magtek_card_reader_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>
#include <memory>

#include "magtek_card_reader_plugin_private.h"
#include "usb_device_manager.h"

#define MAGTEK_CARD_READER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), magtek_card_reader_plugin_get_type(), \
                              MagtekCardReaderPlugin))

struct _MagtekCardReaderPlugin {
  GObject parent_instance;
  FlEventChannel* card_swipe_event_channel;
  FlEventChannel* device_event_channel;
  FlEventChannelHandler* card_swipe_handler;
  FlEventChannelHandler* device_event_handler;
  std::unique_ptr<UsbDeviceManager> device_manager;
};

G_DEFINE_TYPE(MagtekCardReaderPlugin, magtek_card_reader_plugin, g_object_get_type())

// Forward declarations
static FlMethodResponse* handle_initialize(MagtekCardReaderPlugin* self);
static FlMethodResponse* handle_dispose(MagtekCardReaderPlugin* self);
static FlMethodResponse* handle_get_connected_devices(MagtekCardReaderPlugin* self);
static FlMethodResponse* handle_connect_to_device(MagtekCardReaderPlugin* self, FlValue* args);
static FlMethodResponse* handle_disconnect(MagtekCardReaderPlugin* self);
static FlMethodResponse* handle_is_connected(MagtekCardReaderPlugin* self);
static void send_card_swipe_event(MagtekCardReaderPlugin* self, const CardData& card_data);
static void send_device_event(MagtekCardReaderPlugin* self, const DeviceInfo& device_info);

// Event channel handlers
static FlMethodErrorResponse* card_swipe_listen_cb(FlEventChannel* channel,
                                                   FlValue* args,
                                                   gpointer user_data) {
  // Event channel setup - no action needed for listen
  return nullptr;
}

static FlMethodErrorResponse* card_swipe_cancel_cb(FlEventChannel* channel,
                                                   FlValue* args,
                                                   gpointer user_data) {
  // Event channel cleanup - no action needed for cancel
  return nullptr;
}

static FlMethodErrorResponse* device_event_listen_cb(FlEventChannel* channel,
                                                     FlValue* args,
                                                     gpointer user_data) {
  // Event channel setup - no action needed for listen
  return nullptr;
}

static FlMethodErrorResponse* device_event_cancel_cb(FlEventChannel* channel,
                                                     FlValue* args,
                                                     gpointer user_data) {
  // Event channel cleanup - no action needed for cancel
  return nullptr;
}

// Called when a method call is received from Flutter.
static void magtek_card_reader_plugin_handle_method_call(
    MagtekCardReaderPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "initialize") == 0) {
    response = handle_initialize(self);
  } else if (strcmp(method, "dispose") == 0) {
    response = handle_dispose(self);
  } else if (strcmp(method, "getConnectedDevices") == 0) {
    response = handle_get_connected_devices(self);
  } else if (strcmp(method, "connectToDevice") == 0) {
    response = handle_connect_to_device(self, args);
  } else if (strcmp(method, "disconnect") == 0) {
    response = handle_disconnect(self);
  } else if (strcmp(method, "isConnected") == 0) {
    response = handle_is_connected(self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_initialize(MagtekCardReaderPlugin* self) {
  if (!self->device_manager) {
    self->device_manager = std::make_unique<UsbDeviceManager>();
  }

  if (!self->device_manager->Initialize()) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INITIALIZATION_FAILED", "Failed to initialize USB device manager", nullptr));
  }

  // Set up callbacks
  self->device_manager->SetCardSwipeCallback([self](const CardData& card_data) {
    send_card_swipe_event(self, card_data);
  });

  self->device_manager->SetDeviceConnectionCallback([self](const DeviceInfo& device_info) {
    send_device_event(self, device_info);
  });

  self->device_manager->StartMonitoring();

  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_dispose(MagtekCardReaderPlugin* self) {
  if (self->device_manager) {
    self->device_manager->Cleanup();
    self->device_manager.reset();
  }

  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_get_connected_devices(MagtekCardReaderPlugin* self) {
  if (!self->device_manager) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NOT_INITIALIZED", "Device manager not initialized", nullptr));
  }

  auto devices = self->device_manager->GetConnectedDevices();
  g_autoptr(FlValue) device_list = fl_value_new_list();

  for (const auto& device : devices) {
    g_autoptr(FlValue) device_map = fl_value_new_map();
    
    fl_value_set_string_take(device_map, "deviceId", fl_value_new_string(device.device_id.c_str()));
    fl_value_set_string_take(device_map, "deviceName", fl_value_new_string(device.device_name.c_str()));
    fl_value_set_string_take(device_map, "vendorId", fl_value_new_int(device.vendor_id));
    fl_value_set_string_take(device_map, "productId", fl_value_new_int(device.product_id));
    fl_value_set_string_take(device_map, "serialNumber", fl_value_new_string(device.serial_number.c_str()));
    fl_value_set_string_take(device_map, "devicePath", fl_value_new_string(device.device_path.c_str()));
    fl_value_set_string_take(device_map, "isConnected", fl_value_new_bool(device.is_connected));

    fl_value_append_take(device_list, device_map);
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(device_list));
}

static FlMethodResponse* handle_connect_to_device(MagtekCardReaderPlugin* self, FlValue* args) {
  if (!self->device_manager) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NOT_INITIALIZED", "Device manager not initialized", nullptr));
  }

  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENTS", "Arguments must be a map", nullptr));
  }

  FlValue* device_id_value = fl_value_lookup_string(args, "deviceId");
  if (!device_id_value || fl_value_get_type(device_id_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGUMENTS", "deviceId must be a string", nullptr));
  }

  const char* device_id = fl_value_get_string(device_id_value);
  bool success = self->device_manager->ConnectToDevice(std::string(device_id));

  g_autoptr(FlValue) result = fl_value_new_bool(success);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_disconnect(MagtekCardReaderPlugin* self) {
  if (!self->device_manager) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "NOT_INITIALIZED", "Device manager not initialized", nullptr));
  }

  self->device_manager->Disconnect();

  g_autoptr(FlValue) result = fl_value_new_null();
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_is_connected(MagtekCardReaderPlugin* self) {
  if (!self->device_manager) {
    g_autoptr(FlValue) result = fl_value_new_bool(false);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  bool connected = self->device_manager->IsConnected();
  g_autoptr(FlValue) result = fl_value_new_bool(connected);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void send_card_swipe_event(MagtekCardReaderPlugin* self, const CardData& card_data) {
  if (!self->card_swipe_handler) {
    return;
  }

  g_autoptr(FlValue) event_map = fl_value_new_map();
  fl_value_set_string_take(event_map, "track1", fl_value_new_string(card_data.track1.c_str()));
  fl_value_set_string_take(event_map, "track2", fl_value_new_string(card_data.track2.c_str()));
  fl_value_set_string_take(event_map, "track3", fl_value_new_string(card_data.track3.c_str()));
  fl_value_set_string_take(event_map, "deviceId", fl_value_new_string(card_data.device_id.c_str()));
  fl_value_set_string_take(event_map, "rawResponse", fl_value_new_string(card_data.raw_response.c_str()));
  fl_value_set_string_take(event_map, "timestamp", fl_value_new_int(card_data.timestamp));

  fl_event_channel_send(self->card_swipe_event_channel, event_map, nullptr, nullptr);
}

static void send_device_event(MagtekCardReaderPlugin* self, const DeviceInfo& device_info) {
  if (!self->device_event_handler) {
    return;
  }

  g_autoptr(FlValue) event_map = fl_value_new_map();
  fl_value_set_string_take(event_map, "type", fl_value_new_string("device_connected"));
  
  g_autoptr(FlValue) device_map = fl_value_new_map();
  fl_value_set_string_take(device_map, "deviceId", fl_value_new_string(device_info.device_id.c_str()));
  fl_value_set_string_take(device_map, "deviceName", fl_value_new_string(device_info.device_name.c_str()));
  fl_value_set_string_take(device_map, "vendorId", fl_value_new_int(device_info.vendor_id));
  fl_value_set_string_take(device_map, "productId", fl_value_new_int(device_info.product_id));
  fl_value_set_string_take(device_map, "serialNumber", fl_value_new_string(device_info.serial_number.c_str()));
  fl_value_set_string_take(device_map, "devicePath", fl_value_new_string(device_info.device_path.c_str()));
  fl_value_set_string_take(device_map, "isConnected", fl_value_new_bool(device_info.is_connected));
  
  fl_value_set_string_take(event_map, "device", device_map);

  fl_event_channel_send(self->device_event_channel, event_map, nullptr, nullptr);
}

static void magtek_card_reader_plugin_dispose(GObject* object) {
  MagtekCardReaderPlugin* self = MAGTEK_CARD_READER_PLUGIN(object);
  
  if (self->device_manager) {
    self->device_manager->Cleanup();
    self->device_manager.reset();
  }

  G_OBJECT_CLASS(magtek_card_reader_plugin_parent_class)->dispose(object);
}

static void magtek_card_reader_plugin_class_init(MagtekCardReaderPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = magtek_card_reader_plugin_dispose;
}

static void magtek_card_reader_plugin_init(MagtekCardReaderPlugin* self) {
  self->card_swipe_event_channel = nullptr;
  self->device_event_channel = nullptr;
  self->card_swipe_handler = nullptr;
  self->device_event_handler = nullptr;
  self->device_manager = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  MagtekCardReaderPlugin* plugin = MAGTEK_CARD_READER_PLUGIN(user_data);
  magtek_card_reader_plugin_handle_method_call(plugin, method_call);
}

void magtek_card_reader_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  MagtekCardReaderPlugin* plugin = MAGTEK_CARD_READER_PLUGIN(
      g_object_new(magtek_card_reader_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  
  // Set up method channel
  g_autoptr(FlMethodChannel) method_channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "magtek_card_reader",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(method_channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  // Set up event channels
  g_autoptr(FlStandardMethodCodec) event_codec = fl_standard_method_codec_new();
  
  plugin->card_swipe_event_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "magtek_card_reader/card_swipe",
      FL_METHOD_CODEC(event_codec));
  
  plugin->card_swipe_handler = fl_event_channel_set_stream_handlers(
      plugin->card_swipe_event_channel,
      card_swipe_listen_cb,
      card_swipe_cancel_cb,
      g_object_ref(plugin),
      g_object_unref);

  plugin->device_event_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "magtek_card_reader/device_events",
      FL_METHOD_CODEC(event_codec));
  
  plugin->device_event_handler = fl_event_channel_set_stream_handlers(
      plugin->device_event_channel,
      device_event_listen_cb,
      device_event_cancel_cb,
      g_object_ref(plugin),
      g_object_unref);

  g_object_unref(plugin);
}
