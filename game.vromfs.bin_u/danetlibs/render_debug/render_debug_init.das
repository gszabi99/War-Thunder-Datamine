options no_aot

require app
require ecs.fs
require ECSGlobalTags


[export]
def load_render_debug(base_path : string) : bool
  var ok = true
  if ecs_has_tag("render") || is_in_aot()
    ok = load_sub_folder(base_path, "render") && ok

  return ok



