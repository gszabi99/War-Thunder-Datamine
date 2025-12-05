options no_aot

require ecs.fs
require ECSGlobalTags

[export]
def load_motion_matching(base_path : string) : bool
  var ok = true

  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "es") && ok

    if ecs_has_tag("dev") || is_in_aot()
      ok = load_sub_folder(base_path, "debug/es") && ok

    if (ecs_has_tag("dev") && typeinfo builtin_module_exists(DagorImgui)) || is_in_aot()
      ok = load_sub_folder(base_path, "debug/ui") && ok

    if (ecs_has_tag("dev") && typeinfo builtin_module_exists(DngActor) && typeinfo builtin_module_exists(DngHuman))
      ok = load_sub_folder(base_path, "debug/dng") && ok

    if (ecs_has_tag("dev") && typeinfo builtin_module_exists(AssetsImport))
      ok = load_sub_folder(base_path, "debug/asset_mgr") && ok

  return ok



