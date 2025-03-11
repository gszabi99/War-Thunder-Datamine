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
  ok = load_optional_folder("%gameDev/game") && ok
  ok = load_client("%gameDev/game/client") && ok
  ok = load_route_prober("%danetlibs/route_prober") && ok
  ok = load_assets_import("%danetlibs/assets_import") && ok
  ok = load_imgui_daeditor("%danetlibs/imgui_daeditor") && ok

  ok = load_folder("%appGame/es/animchar") && ok
  if ecs_has_tag("render") || app::get_game_name() == "aot"
    ok = load_folder("%appGame/es/render") && ok

  print("Das scripts are loaded")
  if !ok
    logerr("Das scripts loading failed")