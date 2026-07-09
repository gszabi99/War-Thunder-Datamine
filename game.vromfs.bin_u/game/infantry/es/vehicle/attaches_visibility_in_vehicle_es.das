require ecs
require ecs.common
require ecs.safe

def childrens_visibility(attach_eid : EntityId; hide : bool)
  query(attach_eid) <| $ [es(REQUIRE_NOT=gun__visible)] (hide_counter : int;
                                                         var slot_attach__visible : bool&;
                                                         attaches_list : EidList const?)
    slot_attach__visible = !hide && hide_counter == 0
    if attaches_list != null
      for childEid in *attaches_list
        childrens_visibility(childEid, hide)

[es(tag=gameClient, track=human_vehicle__occupiedSeatEid, on_appear)]
def attaches_visibility_in_vehicle(evt : Event;
                                   attaches_list : EidList;
                                   human_vehicle__occupiedSeatEid : EntityId;
                                   human_anim__vehicleSelected : EntityId;
                                   var human_vehicle__attachesWasHidden : bool&)
  var shouldHideAttaches = !!human_vehicle__occupiedSeatEid && has(human_vehicle__occupiedSeatEid, "seat__hideAttaches")
  shouldHideAttaches &&= !has(human_anim__vehicleSelected, "vehicle__dontHideAttaches")

  if shouldHideAttaches == human_vehicle__attachesWasHidden
    return
  human_vehicle__attachesWasHidden = shouldHideAttaches
  for attachEid in attaches_list
    query(attachEid) <| $ [es(REQUIRE_NOT=gun__visible)] (attaches_list : EidList const? = null;
                                                          vehicleHideAttach : Tag const? = null;
                                                          vehicleDontHideAttachButChildren : Tag const? = null;
                                                          hide_counter : int;
                                                          var slot_attach__visible : bool&)
      if vehicleHideAttach != null
        slot_attach__visible = !shouldHideAttaches && hide_counter == 0
      elif vehicleDontHideAttachButChildren != null && attaches_list != null
        for childEid in *attaches_list
          childrens_visibility(childEid, shouldHideAttaches)

[es(tag=gameClient, on_appear, REQUIRE_NOT=gun__visible)]
def hide_attach_in_vehicle_on_attach_appear(evt : Event;
                                            item__ownerEid : EntityId;
                                            var slot_attach__visible : bool&;
                                            attaches_list : EidList const?;
                                            vehicleHideAttach : Tag const?;
                                            vehicleDontHideAttachButChildren : Tag const?)
  let seatEid = get_Eid(item__ownerEid, "human_vehicle__occupiedSeatEid") ?? INVALID_ENTITY_ID
  let vehicleEid = get_Eid(item__ownerEid, "human_anim__vehicleSelected") ?? INVALID_ENTITY_ID

  if !seatEid || !has(seatEid, "seat__hideAttaches") || has(vehicleEid, "vehicle__dontHideAttaches")
    return
  if vehicleHideAttach != null
    slot_attach__visible = false
  elif vehicleDontHideAttachButChildren != null && attaches_list != null
    for childEid in *attaches_list
      childrens_visibility(childEid, true)
