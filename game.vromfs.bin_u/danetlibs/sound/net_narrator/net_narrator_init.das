options no_aot

require ecs.fs
require ECSGlobalTags


[export]
def load_net_narrator(base_path : string) : bool
  var ok = true

  if ecs_has_tag("soundNet") || is_in_aot()
    ok = load_sub_folder(base_path, "modules") && ok

  return ok
