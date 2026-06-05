options no_aot
require ecs
require DagorDebug3D
require AnimV20
require GeomNodeTree
require DagorConsole
require math.base
require danetlibs.render_debug.render.draw_debug_common
require %game.utils.utils_common

[console_cmd(name="animchar.log_without_act_on_demand")]
def console_log_animchars_without_act_on_demand()
  var hist : table<string; int>
  var total = 0
  query() <| $ [es(REQUIRE=animchar, REQUIRE_NOT=animchar__actOnDemand)] (eid : EntityId; animchar__updatable : bool = true)
    if !animchar__updatable
      return
    total += 1
    let key = getEntityTemplateName(eid)
    hist.insert(key, (hist?[key] ?? 0) + 1)
  var histArr : array<tuple<templ : string; count : int>>
  for key, count in keys(hist), values(hist)
    histArr |> emplace((templ = key, count = count))
  sort(histArr) <| $(a, b)
    return b.count < a.count
  print("[animchar without actOnDemand2] {total} entities across {length(histArr)} templates")
  for entry in histArr
    print("[animchar without actOnDemand2] {entry.count} x {entry.templ}")
