options no_aot
require ecs
require ecs.safe
require ecs.common
require DagorDebug3D
require DagorConsole
require WTCamera
require strings
require ecs.ecs_template


[ecs_template]
struct equipment_draw_debug
  equipmentDrawDebug : Tag
  showFullTemplate : bool = false
  equipmentDebugMaxDist : float = 3.0


[console_cmd(name="equipment.debug", hint="Draw all human equipment slots")]
def equipment_draw_debug_cmd(full_template : bool = false; draw_dist : float = 3.0)
  let exist = find_query() <| $ [es(REQUIRE=equipmentDrawDebug)] (eid : EntityId)
    destroyEntity(eid)
    return true
  if !exist
    createEntity("equipment_draw_debug") <| $(init)
      init |> set("showFullTemplate", full_template)
      init |> set("equipmentDebugMaxDist", draw_dist)
  console_print("equipment debug {exist ? "disabled" : "enabled"}")


def get_short_template_name(tmpl_name : string) : string
  let endIdx = find(tmpl_name, "+")
  if endIdx >= 0
    return slice(tmpl_name, 0, endIdx)
  return tmpl_name


def get_item_template_name(item_eid : EntityId; full_template : bool) : string
  let tmplName = string(getEntityTemplateName(item_eid))
  return full_template ? tmplName : get_short_template_name(tmplName)


[es(no_order, REQUIRE=equipmentDrawDebug)]
def draw_equipment_slots(evt : UpdateStageInfoRenderDebug;
                         showFullTemplate : bool;
                         equipmentDebugMaxDist : float)
  let camPos = get_camera_orig_pos()
  let maxDistSq = equipmentDebugMaxDist * equipmentDebugMaxDist
  var tpsTargetEid = INVALID_ENTITY_ID
  find_query() <| $ [es] (camera__target : EntityId; isTpsView : bool = false)
    if isTpsView
      tpsTargetEid = camera__target
    return isTpsView
  begin_draw_cached_debug_lines(false, false, false)
  query() <| $ [es] (eid : EntityId;
                     human_equipment__slots : Object;
                     human_equipment__clientSlots : Object const?;
                     transform aka human_transform : float3x4)
    if tpsTargetEid != INVALID_ENTITY_ID
      if eid != tpsTargetEid
        return
    elif distance_sq(human_transform[3], camPos) > maxDistSq
      return
    var drawPos = human_transform[3]
    drawPos.y += tpsTargetEid != INVALID_ENTITY_ID ? 2.0 : 1.0
    var lineOffset = 0.0
    for slot in human_equipment__slots
      let itemEid = (slot.value as Object)?.item ?? INVALID_ENTITY_ID
      if itemEid == INVALID_ENTITY_ID || !doesEntityExist(itemEid)
        continue
      add_debug_text_mark(drawPos, "{slot.key}: {get_item_template_name(itemEid, showFullTemplate)}", -1, -lineOffset, E3DCOLOR(0xFF68D3C5))
      lineOffset += 1.5
    if human_equipment__clientSlots != null
      for slot in *human_equipment__clientSlots
        let itemEid = (slot.value as Object)?.item ?? INVALID_ENTITY_ID
        if itemEid == INVALID_ENTITY_ID || !doesEntityExist(itemEid) || !has(itemEid, "clientLocalWearItem")
          continue
        add_debug_text_mark(drawPos, "{slot.key}: {get_item_template_name(itemEid, showFullTemplate)}", -1, -lineOffset, E3DCOLOR(0xFF017A6A))
        lineOffset += 1.5
  end_draw_cached_debug_lines()
