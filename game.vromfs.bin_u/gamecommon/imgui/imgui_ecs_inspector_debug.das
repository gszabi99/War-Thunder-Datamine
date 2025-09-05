options no_aot
options persistent_heap
options stack = 65536

require ecs
require imgui
require daslib/static_let
require %danetlibs.imgui_daeditor.imgui.daEditor.ecs_inspector_common


[es(on_event=CmdImGuiDebug, before=__first_sync_point)]
def imgui_debug_ecs_inspector(evt : Event; eid : EntityId)
  static_let_finalize <|
    var filter = new ImGuiTextFilter
  if !imgui::TreeNodeEx("ECS Inspector", ImGuiTreeNodeFlags.Framed)
    return
  var eids : array<EntityId>
  eids |> push(eid)
  inspect_item(0, *filter, unsafe(reinterpret< array<EntityId># > eids), true)
  imgui::TreePop()
