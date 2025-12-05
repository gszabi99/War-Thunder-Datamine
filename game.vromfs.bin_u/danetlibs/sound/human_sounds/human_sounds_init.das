options no_aot

require ecs.fs
require ECSGlobalTags


[export]
def load_human_sounds(base_path : string) : bool
  var ok = true

  if ecs_has_tag("sound") || is_in_aot()
    ok = load_sub_folder(base_path, "es") && ok
    if typeinfo builtin_module_exists(gpuReadbackQuery) && typeinfo builtin_module_exists(puddleQueryManager)
      ok = load_sub_folder(base_path, "es/gpu_sound_queries") && ok
  return ok



