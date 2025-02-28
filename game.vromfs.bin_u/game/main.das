options no_aot = true//since this is merely loader
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

  // temporary disable autolaunch for das debugger
  // currently das scripts load 3 times in the row and sometimes debugger crash game
  // https://app.pararam.io/#/organizations/2/threads/300#post_no-140499
  // if !is_in_aot() && get_DAGOR_ADDRESS_SANITIZER() == 0 && ecs_has_tag("render") && typeinfo(builtin_module_exists network) && typeinfo(builtin_module_exists debugapi) && find_index(get_command_line_arguments(), "--das-no-debugger") == -1
  //   ok = load_optional_folder("%gameDev/debugger") && ok

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