/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "BUI_kit.h"
#include "BLI_math_base.h"
#ifdef BUI_SDK_HAS_IMGUI
#  include "imgui.h"
#  include "imgui_impl_bui.h"
#endif

extern "C" int bui_sdk_check_c(void);

int main()
{
#ifdef BUI_SDK_HAS_IMGUI
  ImGui::CreateContext();
  ImGui_ImplBUI_StyleBlender();
  ImGui::DestroyContext();
#endif
  return bui_sdk_check_c();
}
