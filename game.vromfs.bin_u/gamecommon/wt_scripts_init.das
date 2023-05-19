options no_aot = true//since this is merely loader
require %dasGameLibs.ecs.fs

[export]
def load_wt_scripts(base_path : string) : bool
  var ok = true
  ok = load_folder(base_path) && ok
  ok = load_sub_folder(base_path, "unit") && ok
  ok = load_sub_folder(base_path, "dm") && ok
  return ok
