module skeleton_debug_common shared
options no_aot
require ecs
require DagorConsole
require strings

require daslib/strings_boost


struct SkeletonNodeDrawDebugContext
  drawGizmos : bool
  gizmoAxisSize : float
  drawNodeIndicies : bool
  nodeNameFilterInclude : StringList const?
  nodeNameFilterExclude : StringList const?


def toggle_skeleton_debug(draw_gizmo : bool = false; draw_distance : float = 6.0)
  let exist = find_query() <| $ [es(REQUIRE=skeleton_debug_draw)] (var skeleton_debug_draw__enabled : bool&)
    skeleton_debug_draw__enabled = !skeleton_debug_draw__enabled
    return true
  if !exist
    createEntity("skeleton_debug_draw") <| $(init)
      init |> set("skeleton_debug_draw__drawGizmos", draw_gizmo)
      init |> set("skeleton_debug_draw__maxDistance", draw_distance)
  console_print("skeleton debug {exist ? "disabled" : "enabled"}")


def skeleton_debug_toggle_selected_only(draw_gizmo : bool = false; draw_distance : float = 6.0)
  var isEnabled = true
  let exist = find_query() <| $ [es(REQUIRE=skeleton_debug_draw)] (var skeleton_debug_draw__enabled : bool&;
                                                                   var skeleton_debug_draw__filterEditorSelectedEntityOnly : bool&)
    skeleton_debug_draw__filterEditorSelectedEntityOnly = !skeleton_debug_draw__filterEditorSelectedEntityOnly
    skeleton_debug_draw__enabled = skeleton_debug_draw__filterEditorSelectedEntityOnly
    isEnabled = skeleton_debug_draw__enabled
    return true
  if !exist
    createEntity("skeleton_debug_draw") <| $(init)
      init |> set("skeleton_debug_draw__drawGizmos", draw_gizmo)
      init |> set("skeleton_debug_draw__maxDistance", draw_distance)
      init |> set("skeleton_debug_draw__filterEditorSelectedEntityOnly", true)
  console_print("skeleton debug (selected entity only) {isEnabled ? "enabled" : "disabled"}")


def skeleton_debug_set_filter(filter : string)
  find_query() <| $ [es(REQUIRE=skeleton_debug_draw)] (var skeleton_debug_draw__filterString : das_string&;
                                                       var skeleton_debug_draw__filterByNodeNameInclude : StringList&;
                                                       var skeleton_debug_draw__filterByNodeNameExclude : StringList&)
    skeleton_debug_draw__filterString := replace(filter, "\"", "")

    skeleton_debug_draw__filterByNodeNameInclude.clear()
    skeleton_debug_draw__filterByNodeNameExclude.clear()

    let nonSanitizedfilters <- split("{skeleton_debug_draw__filterString}", ",")
    for s in nonSanitizedfilters
      let sanitisedFilter = s |> trim
      if sanitisedFilter != ""
        if sanitisedFilter.character_at(0) == '-'
          skeleton_debug_draw__filterByNodeNameExclude.push(sanitisedFilter |> slice(1))
        else
          skeleton_debug_draw__filterByNodeNameInclude.push(sanitisedFilter)
    return true
