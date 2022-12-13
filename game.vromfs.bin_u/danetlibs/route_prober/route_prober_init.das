options no_aot

require app
require ecs.fs
require ECSGlobalTags


[export]
def load_route_prober(base_path : string) : bool
  var ok = true

  if ecs_has_tag("gameClient") || app::get_game_name() == "aot"
    // THIS IS A HACK TO ALLOW RELEASE OF SOME CHAGES TO PRODUCTION
    // IN MASTER IT IS IMMEDIATELY REVERTED IN THE FOLLOWING COMMIT
    if typeinfo(builtin_module_exists auth) && typeinfo(builtin_module_exists OnlineStorage)
      ok = load_sub_folder(base_path, "main") && ok
    else
      ok = load_sub_folder(base_path, "main_fallback") && ok

  return ok


[export]
def test()
  let ok = load_route_prober("%danetlibs/route_prober")
  assert(ok)
