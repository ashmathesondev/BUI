/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "BUI_kit.h"
#include "bui_c_api.h"
#ifdef BUI_SDK_HAS_IMGUI
#  include "cimgui.h"
#endif

int bui_sdk_check_c(void)
{
  BKNode *node = BK_node_new("frame");
  if (!node) {
    return 1;
  }
  BK_node_free(node);
#ifdef BUI_SDK_HAS_IMGUI
  ImGuiContext *imgui = ImGui_CreateContext();
  ImGui_DestroyContextEx(imgui);
#endif
  int major = -1, minor = -1, patch = -1;
  bui_get_version(&major, &minor, &patch);
  return major != BUI_KIT_VERSION_MAJOR || minor != BUI_KIT_VERSION_MINOR ||
         patch != BUI_KIT_VERSION_PATCH;
}
