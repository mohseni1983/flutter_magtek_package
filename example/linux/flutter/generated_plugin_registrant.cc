//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <magtek_card_reader/magtek_card_reader_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) magtek_card_reader_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MagtekCardReaderPlugin");
  magtek_card_reader_plugin_register_with_registrar(magtek_card_reader_registrar);
}
