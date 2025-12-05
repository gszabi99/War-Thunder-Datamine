options no_aot
require ecs
require imgui
require DagorImgui
require DagorEditor
require danetlibs.imgui_daeditor.daEditor.daEditor_common


def entity_button(name : string; eid : EntityId)
  if imgui::Button("{name} ({eid})")
    if eid != INVALID_ENTITY_ID
      entity_object_editor_updateObjectsList()
      editor_select_eid(eid, true)

  if IsItemHovered()
    BeginTooltip()
    TextUnformatted(eid != INVALID_ENTITY_ID ? getEntityTemplateName(eid) : "None")
    EndTooltip()


[imgui_window(name="Common Entities", group="Editor")]
def editor_common_entities_debug_window()

  init_entity_object_editor()

  query <| $ [es(REQUIRE=hero)] (possessedByPlr : EntityId)
    entity_button("Local Player", possessedByPlr)

  query() <| $ [es] (eid : EntityId;
                     camera__active : bool)
    if camera__active
      entity_button("Active Camera", eid)

  query() <| $ [es(REQUIRE=watchedHero)] (eid aka soldier_eid : EntityId;
                                          squad_member__squad : EntityId = INVALID_ENTITY_ID;
                                          human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                                          human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                                          human_anim__vehicleSelected : EntityId = INVALID_ENTITY_ID;
                                          human_vehicle__occupiedSeatEid : EntityId = INVALID_ENTITY_ID;
                                          human__controlledDrone : EntityId = INVALID_ENTITY_ID)
    imgui::Text("Watched Hero:")
    entity_button("Hero", eid)
    entity_button("Squad", squad_member__squad)

    entity_button("Current Gun", human_weap__currentGunEid)

    var subsidiaryEid = INVALID_ENTITY_ID
    query(human_weap__currentGunEid) <| $ [es] (subsidiaryGunEid : EntityId)
      subsidiaryEid = subsidiaryGunEid
    entity_button("Current Subsidiary", subsidiaryEid)

    entity_button("Stationary Gun", human_attached_gun__attachedGunEid)

    entity_button("Vehicle", human_anim__vehicleSelected)
    entity_button("Vehicle Seat", human_vehicle__occupiedSeatEid)

    query(human_anim__vehicleSelected) <| $ [es] (cockpit__eid : EntityId)
      entity_button("Vehicle Cockpit", cockpit__eid)

    var droneEid = human__controlledDrone
    if human__controlledDrone == INVALID_ENTITY_ID
      find_query() <| $ [es] (eid aka drone_eid, drone__owner : EntityId)
        if drone__owner == soldier_eid
          droneEid = drone_eid
          return true
        return false
    entity_button("Current Drone", droneEid)
