require ecs


def calc_human_visibility(isInVehicleHidden : bool; isInVehicleHiddenLocal : bool; human__visible : bool)
  return !isInVehicleHidden && !isInVehicleHiddenLocal && human__visible


def calc_attachable_visibility(animchar_attach__attachedTo : EntityId; slot_attach__visible : bool;
                               gun__visible : bool; has_gun__visible : bool)
  
  var res = slot_attach__visible || gun__visible
  if has_gun__visible && !gun__visible
    
    
    
    res = false
  query(animchar_attach__attachedTo) <| $ [es] (animchar_render__enabled : bool)
    
    res &&= animchar_render__enabled

  query(animchar_attach__attachedTo) <| $ [es] (gun__visible : bool;
                                                animchar_attach__attachedTo : EntityId;
                                                slot_attach__visible : bool)

    let tmpRes = calc_attachable_visibility(animchar_attach__attachedTo, slot_attach__visible,
                                            gun__visible, true)
    
    if has_gun__visible
      
      res &&= tmpRes
    else
      
      res = tmpRes
  return res


def update_attached_visibility(parentEid : EntityId)
  query() <| $ [es] (eid : EntityId; animchar_attach__attachedTo : EntityId; var animchar_render__enabled : bool&;
                     slot_attach__visible : bool; gun__visible : bool = false)
    if animchar_attach__attachedTo == parentEid
      animchar_render__enabled = calc_attachable_visibility(animchar_attach__attachedTo, slot_attach__visible,
        gun__visible, has(eid, "gun__visible"))

      if parentEid != eid
        update_attached_visibility(eid)

[es(track=(isInVehicleHidden, human__visible, isInVehicleHiddenLocal), on_appear, on_event=EventUnitDelayedStatusChanged, after=human_visibility_update)]
def animchar_human_visibility_es(evt : Event;
                                 eid : EntityId;
                                 human__visible : bool;
                                 isInVehicleHidden : bool;
                                 isInVehicleHiddenLocal : bool;
                                 var animchar_render__enabled : bool&)
  animchar_render__enabled = calc_human_visibility(isInVehicleHidden, isInVehicleHiddenLocal, human__visible)

  update_attached_visibility(eid)
  query() <| $ [es(REQUIRE=skeleton_attach__attached)] (animchar_attach__attachedTo : EntityId;
                                                        var animchar_render__enabled : bool&;
                                                        slot_attach__visible : bool)
    if animchar_attach__attachedTo == eid
      animchar_render__enabled = calc_human_visibility(isInVehicleHidden, isInVehicleHiddenLocal, human__visible) && slot_attach__visible

[es(on_appear, track=slot_attach__visible, track=animchar_attach__attachedTo, track=gun__visible)]
def animchar_attachable_visibility_es(evt : Event; eid : EntityId; animchar_attach__attachedTo : EntityId;
                                      var animchar_render__enabled : bool&; slot_attach__visible : bool;
                                      gun__visible : bool = false)
  animchar_render__enabled = calc_attachable_visibility(animchar_attach__attachedTo, slot_attach__visible,
    gun__visible, has(eid, "gun__visible"))

  update_attached_visibility(eid)

[es(on_appear, REQUIRE=skeleton_attach__attached, track=animchar_attach__attachedTo, track=slot_attach__visible)]
def animchar_skeleton_visibility_es(evt : Event; animchar_attach__attachedTo : EntityId;
                                    var animchar_render__enabled : bool&; slot_attach__visible : bool)
  query(animchar_attach__attachedTo) <| $ [es] (isInVehicleHidden : bool; human__visible : bool; isInVehicleHiddenLocal : bool)
    animchar_render__enabled = calc_human_visibility(isInVehicleHidden, isInVehicleHiddenLocal, human__visible) && slot_attach__visible


[es(tag=gameClient, on_appear, track=(human_binocular__isHideHuman, human_attached_gun__isHideHuman), on_event=EventUnitDelayedStatusChanged)]
def human_visibility_update(evt : Event;
                            isAlive : bool;
                            active : bool;
                            human_binocular__isHideHuman : bool;
                            human_attached_gun__isHideHuman : bool;
                            var human__visible : bool&)
  if !isAlive
    return
  human__visible = !human_attached_gun__isHideHuman && !human_binocular__isHideHuman && active
