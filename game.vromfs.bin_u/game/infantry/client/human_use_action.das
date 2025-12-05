require ecs
require ecs.common
require %appGame.infantry.es.human_use_action_common
require %appGame.infantry.es.action_common
require %appGame.infantry.es.door_operations_common
require %appGame.infantry.es.inventory_common
require %appGame.infantry.es.team_common
require HumanPhys
require DngHuman
require inventory
require DagorDataBlock
require hud
require %game.events


[es(tag=( render, gameClient) , REQUIRE=watchedByPlr)]
def human_use_action_es(info : ParallelUpdateFrameDelayed;
                        eid : EntityId;
                        transform aka human_transform : float3x4;
                        human_net_phys : HumanActor const?;
                        human_weap__gunEids : EidList;
                        human_use_object__lookAtObject : EntityId;
                        human_inventory__selectedItem : EntityId;
                        human_use_object__selectedObject : EntityId;
                        human_breath__isUnderWater = false;
                        isAlive = true;
                        var useActionAvailable : int&;
                        var useActionEid : EntityId&;
                        var lookAtEid : EntityId&;
                        var pickupItemName : das_string&;
                        var pickupItemEid : EntityId&;
                        human__canPlantCarryingBomb : bool = false)
  useActionAvailable = int(HumanAction.ACTION_NONE)
  lookAtEid = INVALID_ENTITY_ID
  if human_net_phys == null || !isAlive
    pickupItemName := ""
    pickupItemEid = INVALID_ENTITY_ID
    useActionEid = INVALID_ENTITY_ID
    lookAtEid = INVALID_ENTITY_ID
    return
  if human_inventory__selectedItem == INVALID_ENTITY_ID
    pickupItemEid = INVALID_ENTITY_ID
    useActionEid = INVALID_ENTITY_ID
    pickupItemName := ""
  let selectedItemEid = human_inventory__selectedItem
  let selectedObjectEid = human_use_object__selectedObject
  if selectedObjectEid != INVALID_ENTITY_ID && doesEntityExist(selectedObjectEid)
    let doorState = get_int(selectedObjectEid, "door_operations__state")
    if doorState != null
      query(selectedObjectEid) <| $[es] (transform aka door_transform : float3x4;
                                         initialTransform aka door_initialTransform : float3x4;
                                         isDoor : bool = true;
                                         door__isLocked : bool = false;
                                         door__isLocking : bool = false)
        if !door__isLocking && !door__isLocked
          let stateAfterAction = get_door_main_action(*doorState, door_transform, door_initialTransform, human_transform[3])
          if isDoor
            useActionAvailable = stateAfterAction == int(DoorState.OPENED) ? int(HumanAction.ACTION_OPEN_DOOR) : int(HumanAction.ACTION_CLOSE_DOOR)
          else
            useActionAvailable = stateAfterAction == int(DoorState.OPENED) ? int(HumanAction.ACTION_OPEN_WINDOW) : int(HumanAction.ACTION_CLOSE_WINDOW)
    elif get_bool(selectedObjectEid, "isDowned") ?? false
      if !human_breath__isUnderWater
        useActionAvailable = int(HumanAction.ACTION_REVIVE_TEAMMATE)
    else
      let attachedGunEid = get_Eid(selectedObjectEid, "human_attached_gun__attachedGunEid") ?? INVALID_ENTITY_ID
      if attachedGunEid != INVALID_ENTITY_ID
        pass
      elif has(selectedObjectEid, "vehicle_seats__seats") && get_bool(selectedObjectEid, "isAlive") ?? false
        useActionAvailable = int(HumanAction.ACTION_USE)
      elif has(selectedObjectEid, "lootable") && !has(selectedObjectEid, "lootableGunOnly") && !(get_bool(selectedObjectEid, "isAlive") ?? true)
        useActionAvailable = int(HumanAction.ACTION_LOOT_BODY)
      elif has(selectedObjectEid, "squad_member__squad") && has(selectedObjectEid, "human")
        useActionAvailable = int(HumanAction.ACTION_REQUEST_AMMO)
      elif has(selectedObjectEid, "human_gun_attached")
        useActionAvailable = int(HumanAction.ACTION_USE)
      elif has(selectedObjectEid, "buildByPlayer")
        useActionAvailable = int(HumanAction.ACTION_NONE)
      else
        useActionAvailable = int(HumanAction.ACTION_USE)
    useActionEid = selectedObjectEid
  elif selectedItemEid != INVALID_ENTITY_ID
    var tryPickUp = false
    query(selectedItemEid) <| $ [es] (item__weapTemplate : string = ""; item__pickupOnlyAmmo : Tag const?)
      if item__pickupOnlyAmmo != null
        useActionAvailable = int(HumanAction.ACTION_PICK_UP_WEAPON_AMMO)
        return
      if item__weapTemplate != ""
        query(selectedItemEid) <| $ [es] (item__weapSlots : Array)
          tryPickUp = false
          var haveEmptySlot = false
          for slot in item__weapSlots
            let slotName = get_string(slot, "")
            let slotIdx = HUWeaponSlots(slotName)
            if human_weap__gunEids[int(slotIdx)] != INVALID_ENTITY_ID
              continue
            haveEmptySlot = true
            break
          if !haveEmptySlot
            useActionAvailable = int(HumanAction.ACTION_SWITCH_WEAPONS)
          else
            tryPickUp = true
      else
        tryPickUp = true

    if tryPickUp
      let volume = get_float(selectedItemEid, "item__volume") ?? 0f
      if volume == 0f || can_pickup_item_by_volume(selectedItemEid, eid)
        useActionAvailable = int(HumanAction.ACTION_PICK_UP)
      elif !can_pickup_item_by_uniqueness(eid, selectedItemEid)
        useActionAvailable = int(HumanAction.ACTION_DENIED_ALREADY_EQUIPIED)
      else
        useActionAvailable = int(HumanAction.ACTION_DENIED_TOO_MUCH_WEIGHT)
    query(selectedItemEid) <| $ [es] (item__name : string)
      pickupItemName := item__name
    pickupItemEid = selectedItemEid
  elif has(selectedItemEid, "stationary_gun")
    useActionAvailable = int(HumanAction.ACTION_USE)
  elif check_action_precondition(eid, "recover")
    useActionAvailable = int(HumanAction.ACTION_RECOVER)
  elif check_action_precondition(eid, "melee")
    useActionAvailable = int(HumanAction.ACTION_MELEE)
  elif human__canPlantCarryingBomb
    useActionAvailable = int(HumanAction.ACTION_PLANT_BOMB)
  if human_use_object__lookAtObject != INVALID_ENTITY_ID && doesEntityExist(human_use_object__lookAtObject)
    lookAtEid = human_use_object__lookAtObject

[es(tag=( render, gameClient), on_appear, track=useActionAvailable, REQUIRE=watchedByPlr)]
def human_use_action_hud_es(evt : Event;
                            useActionAvailable : int&)
  using() <| $(var eventData : DataBlock)
    hud_notify_script("hint:human_use_action:hide", eventData)
    if useActionAvailable == int(HumanAction.ACTION_USE)
      hud_notify_script("hint:human_use_action:show", eventData)
    elif useActionAvailable == int(HumanAction.ACTION_PICK_UP)
      hud_notify_script("hint:human_use_pick_up:show", eventData)
    elif useActionAvailable == int(HumanAction.ACTION_PICK_UP_WEAPON_AMMO)
      hud_notify_script("hint:human_use_pick_up_weapon_ammo:show", eventData)
    elif useActionAvailable == int(HumanAction.ACTION_SWITCH_WEAPONS)
      hud_notify_script("hint:human_use_switch_weapons:show", eventData)
    elif useActionAvailable == int(HumanAction.ACTION_OPEN_DOOR)
      hud_notify_script("hint:human_use_open_door:show", eventData)
    elif useActionAvailable == int(HumanAction.ACTION_CLOSE_DOOR)
      hud_notify_script("hint:human_use_close_door:show", eventData)
    elif useActionAvailable == int(HumanAction.ACTION_OPEN_WINDOW)
      hud_notify_script("hint:human_use_open_window:show", eventData)
    elif useActionAvailable == int(HumanAction.ACTION_CLOSE_WINDOW)
      hud_notify_script("hint:human_use_close_window:show", eventData)

[es(tag=gameClient, on_appear, REQUIRE=hero, track=human_use_object__selectedBuilding, before=ui_useful_box_ammo_count_changed_es)]
def ui_useful_box_hint_es(evt : Event;
                          human_use_object__selectedBuilding : EntityId;
                          team aka hero_team : int)
  using() <| $(var eventData : DataBlock)
    hud_notify_script("hint:resupply/useful_box:hide", eventData)
    query(human_use_object__selectedBuilding) <| $ [es] (team aka box_team : int;
                                                         useful_box__useCount : int;
                                                         useful_box__anyTeam : Tag const?;
                                                         armorBox : Tag const?;
                                                         humanAmmoBox : Tag const?;
                                                         explosiveBox : Tag const?)
      if (useful_box__anyTeam == null && !is_teams_friendly(hero_team, box_team))
        return
      if useful_box__useCount <= 0
        hud_notify_script("hint:resupply/useful_box_empty:show", eventData)
      else
        if explosiveBox != null
          hud_notify_script("hint:resupply/explosive_box_refill:show", eventData)
        elif armorBox != null
          hud_notify_script("hint:resupply/armor_box_refill:show", eventData)
        elif humanAmmoBox != null
          hud_notify_script("hint:resupply/ammo_box_refill:show", eventData)
        else
          hud_notify_script("hint:resupply/medkit_box_refill:show", eventData)


[es(tag=gameClient, on_appear, track=useful_box__useCount)]
def ui_useful_box_ammo_count_changed_es(evt : Event;
                                        eid aka box_eid : EntityId;
                                        useful_box__useCount : int)
  query() <| $ [es(REQUIRE=watchedByPlr)] (human_use_object__selectedBuilding : EntityId)
    if useful_box__useCount <= 0 && human_use_object__selectedBuilding == box_eid
      using() <| $(var eventData : DataBlock)
        hud_notify_script("hint:resupply/useful_box:hide", eventData)
        hud_notify_script("hint:resupply/useful_box_empty:show", eventData)

[es(tag=gameClient, REQUIRE=hero, on_appear, track=(bipod__placeable, bipod__enabled))]
def ui_place_bipod_tip_es(evt : Event;
                          bipod__placeable : bool;
                          bipod__enabled : bool)
  using() <| $(var eventData : DataBlock)
    if bipod__placeable && !bipod__enabled
      hud_notify_script("hint:human_place_bipod:show", eventData)
    else
      hud_notify_script("hint:human_place_bipod:hide", eventData)

[es(tag=gameClient, REQUIRE=(hero, bipod__placeable, bipod__enabled), on_disappear)]
def ui_displace_bipod_tip_es(evt : Event)
  using() <| $(var eventData : DataBlock)
    hud_notify_script("hint:human_place_bipod:hide", eventData)

[es(tag=gameClient, REQUIRE=watchedByPlr, on_appear, track=(burning__isBurning, burning__isPuttingOut))]
def human_burning_tip_show_es(evt : Event;
                              burning__isBurning : bool;
                              burning__isPuttingOut : bool)
  using() <| $(var eventData : DataBlock)
    if burning__isBurning && !burning__isPuttingOut
      hud_notify_script("hint:burning_tip:show", eventData)
    else
      hud_notify_script("hint:burning_tip:hide", eventData)

[es(tag=gameClient, REQUIRE=watchedByPlr, on_appear, track=(grenade_rethrow__grenadeEid))]
def grenade_rethrow_tip_show_es(evt : Event;
                                eid : EntityId;
                                grenade_rethrow__grenadeEid : EntityId)
  using() <| $(var eventData : DataBlock)
    if !!grenade_rethrow__grenadeEid
      query(grenade_rethrow__grenadeEid) <| $ [es] (shell__owner : EntityId)
        if eid != shell__owner
          hud_notify_script("hint:human_throw_back:show", eventData)
    else
      hud_notify_script("hint:human_throw_back:hide", eventData)
