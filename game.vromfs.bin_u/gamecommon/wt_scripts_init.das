options no_aot = true
require %dasGameLibs.ecs.fs
require ECSGlobalTags
require app
require DagorSystem

[export]
def load_client(path : string) : bool
  var ok = true
  if ecs_has_tag("gameClient") || is_in_aot()
    ok = load_optional_folder(path)
  return ok

[export]
def load_wt_scripts(base_path : string) : bool
  var ok = true
  ok = load_folder(base_path) && ok
  ok = load_sub_folder(base_path, "unit") && ok
  ok = load_sub_folder(base_path, "dm") && ok
  if (typeinfo builtin_module_exists(DagorImgui) && typeinfo builtin_module_exists(DagorEditor)) || is_in_aot()
    ok = load_sub_folder(base_path, "imgui") && ok
  return ok
