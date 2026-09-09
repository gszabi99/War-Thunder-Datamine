options no_aot

require ecs.fs
require ECSGlobalTags

[export]
def load_netDebugDraw(base_path : string) : bool
  
  if ecs_has_tag("render") || is_in_aot()
    return load_sub_folder(base_path, "render")
  return true
