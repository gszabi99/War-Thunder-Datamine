options no_aot = true
require ecs
require app
require %dasGameLibs.ecs.fs
require %danetlibs.route_prober.route_prober_init
require %danetlibs.assets_import.assets_import_init
require %danetlibs.imgui_daeditor.imgui_daeditor_init









require DagorSystem
require ECSGlobalTags
require %game.wt_scripts_init

[init]
def load
  var ok = true

  
  
  
  
  

  ok = load_wt_scripts("%game") && ok
  ok = load_client("%game/client") && ok
  ok = load_folder("%appGame/es") && ok
  ok = load_client("%appGame/client") && ok
  
  ok = load_optional_folder("%gameDev/game/es") && ok
  ok = load_client("%gameDev/game/client") && ok

  if ecs_has_tag("render") || is_in_aot()
    ok = load_optional_folder("%appGame/render") && ok
    ok = load_optional_folder("%appGame/es/render") && ok



  if ecs_has_tag("sound") || is_in_aot()
    ok = load_folder("%game/sound") && ok
    ok = load_optional_folder("%appGame/es/sound") && ok









  ok = load_route_prober("%danetlibs/route_prober") && ok
  ok = load_assets_import("%danetlibs/assets_import") && ok
  ok = load_imgui_daeditor("%danetlibs/imgui_daeditor") && ok











  if (typeinfo builtin_module_exists(DagorImgui) && typeinfo builtin_module_exists(DagorEditor)) || is_in_aot()
    ok = load_optional_folder("%gameDev/game/es/imgui/daEditor") && ok

  ok = load_optional_folder("%appGame/es/animchar") && ok
  if ecs_has_tag("input") || is_in_aot()
    ok = load_folder("%game/input") && ok
    ok = load_optional_folder("%appGame/input") && ok




  ok = load_optional_folder("%appGame/ai") && ok

  if (typeinfo builtin_module_exists(DagorImgui) && typeinfo builtin_module_exists(DagorEditor)) || is_in_aot()
    ok = load_optional_folder("%gameDev/game/ai/daEditor") && ok

  print("Das scripts are loaded")
  if !ok
    logerr("Das scripts loading failed")