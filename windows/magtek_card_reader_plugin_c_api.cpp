#include "include/magtek_card_reader/magtek_card_reader_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "magtek_card_reader_plugin.h"

void MagtekCardReaderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  magtek_card_reader::MagtekCardReaderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
