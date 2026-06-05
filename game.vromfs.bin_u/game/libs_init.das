



options no_aot = true
require gameLibs.daeditorPlotDebug.daeditorPlotDebug_init
require gameLibs.anim.motionMatching.motionMatching_init
require gameLibs.route_prober.route_prober_init
require gameLibs.console_commands.console_commands_init
require gameLibs.imgui_daeditor.imgui_daeditor_init
require gameLibs.assets_import.assets_import_init

def load_libs() : bool
  var ok = true
  ok = load_daeditorPlotDebug("%gameLibs/daeditorPlotDebug") && ok
  ok = load_motionMatching("%gameLibs/anim/motionMatching") && ok
  ok = load_route_prober("%gameLibs/route_prober") && ok
  ok = load_console_commands("%gameLibs/console_commands") && ok
  ok = load_imgui_daeditor("%gameLibs/imgui_daeditor") && ok
  ok = load_assets_import("%gameLibs/assets_import") && ok

  return ok

[export]
def test_all
  let ok = load_libs()
  assert(ok)

