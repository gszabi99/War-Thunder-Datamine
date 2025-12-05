require ecs
require ecs.safe
require ecs.common
require %appGame.infantry.es.inventory_common
require %appGame.infantry.es.team_common
require DagorMath
require net
require DagorSystem

require %appGame.wt_events
require %appGame.infantry.es.human_weap_common
require strings


struct ResupplyGunPrice
  magazines : int
  boxUses : int


struct ResupplyGunResult
  emptyMagazinesRefilled : int
  partialMagazinesRefilled : int
  boxUses : int


enum RefillAmmoStatus
  SUCCESS
  FAIL_INCOMPATIBLE_FRIENDLY_GUN
  FAIL_INCOMPATIBLE_ENEMY_GUN
  FAIL_AMMO_FULL
  FAIL_EMPTY_BOX


struct RefillAmmoResult
  boxUses : int
  status : RefillAmmoStatus

[es(tag=server, on_appear, REQUIRE=(initial_inventory, hand_grenade))]
def init_human_inventory_grenades_set(evt : Event;
                                      eid : EntityId;
                                      item__ownerEid : EntityId)
  query(item__ownerEid) <| $ [es] (var human_inventory__grenadesOnInit : StringList&)
    var grenadeTemplate = getEntityTemplateName(eid)
    grenadeTemplate = replace(grenadeTemplate, "+initial_inventory", "")
    human_inventory__grenadesOnInit |> push(grenadeTemplate)

def private calculate_resupply_gun_price(max_magazines : int;
                                         requires_refill_count : int;
                                         wanted_magazines : int;
                                         box_use_count : int)
  let tolerance = 0.0001 
  let boxUsesPerMag = safediv(float(requires_refill_count), float(max_magazines))
  var ret = ResupplyGunPrice(
    magazines = wanted_magazines,
    boxUses   = ceili(boxUsesPerMag * float(wanted_magazines) - tolerance)
  )

  if box_use_count < ret.boxUses
    
    let coeff = safediv(float(box_use_count), float(ret.boxUses))
    ret.magazines = ceili(coeff * float(ret.magazines) - tolerance)
    ret.boxUses   = box_use_count

  return ret


def resupply_gun_check(box_use_count : int;
                       requires_refill_count : int;
                       holder_ammo_count : int;
                       ammo_in_gun : int;
                       max_magazines : int;
                       item_container : EidList;
                       is_suitable_ammo_cb : block<(itemTemplate : string) : bool>)
  let magazines = get_magazines_count(ammo_in_gun, holder_ammo_count, item_container, is_suitable_ammo_cb)

  if magazines.current > max_magazines
    return ResupplyGunResult(
      partialMagazinesRefilled = 0,
      emptyMagazinesRefilled = 0,
      boxUses = 0
    )

  let emptyMagazines = max_magazines - magazines.current
  let price = calculate_resupply_gun_price(max_magazines, requires_refill_count, emptyMagazines + magazines.partial, box_use_count)
  let partialMagsRefilled = max(price.magazines - emptyMagazines, 0)

  return ResupplyGunResult(
    partialMagazinesRefilled = partialMagsRefilled,
    emptyMagazinesRefilled = price.magazines - partialMagsRefilled,
    boxUses = price.boxUses
  )


def has_ammo_holder(gun_eid; item_template)
  var hasHolder = false
  query(gun_eid) <| $ [es] (gun__ammoHolders : Array)
    if is_ammo_for_gun(item_template, gun__ammoHolders) 
      hasHolder = true
      return

  return hasHolder


def try_refill_ammoholder_for_gun(requester_eid : EntityId;
                                  gun_eid : EntityId;
                                  gun_ammo : int;
                                  ammo_template : string | #;
                                  ammo_num : int;
                                  var new_box_use_count : int&;
                                  var item_container : EidList;
                                  is_suitable_ammo_cb : block<(itemTemplate : string) : bool>)
  let ammoTplComp = ammo_template |> getTemplateByName
  if ammoTplComp == null
    logerr("Template '{ammo_template}' not exist in entity '{getEntityTemplateName(gun_eid)}'")
    return

  let holderAmmoCount = *ammoTplComp |> getTemplateComponent("ammo_holder__ammoCount") |> get_int ?? 0
  if holderAmmoCount <= 0
    logerr("<{requester_eid}> ammo_holder.ammoCount is less than or equal to 0 in template: {ammo_template}")
    return

  let ammoRefillsCount = max(1, get_int(getTemplateComponent(*ammoTplComp, "requiresAmmoRefillsCount")) ?? 1)

  let resupplyResult = resupply_gun_check(new_box_use_count,
                                          ammoRefillsCount,
                                          holderAmmoCount,
                                          gun_ammo,
                                          ammo_num,
                                          item_container,
                                          is_suitable_ammo_cb)

  new_box_use_count -= resupplyResult.boxUses

  resupply_gun(resupplyResult.emptyMagazinesRefilled,
               resupplyResult.partialMagazinesRefilled,
               requester_eid,
               holderAmmoCount,
               ammo_template,
               item_container,
               is_suitable_ammo_cb)


def try_to_refill_ammo(requester; box_use_count; box_team; any_team : bool; resupply_launchers : bool; resupply__ammoSlots : StringList)
  var newBoxUseCount = box_use_count
  var isFriendlyBox = false
  var incompatibleGunFailed = false
  var ret = RefillAmmoResult(
    boxUses = 0,
    status = RefillAmmoStatus.SUCCESS
  )

  query(requester) <| $ [es] (human_weap__gunEids : EidList;
                              team aka requester_team : int;
                              human_weap__gunMods : Array;
                              var itemContainer : EidList&)
    isFriendlyBox = any_team || is_teams_friendly(requester_team, box_team)

    for slotName in resupply__ammoSlots
      let slotId = get_weapon_slot_index_from_name(string(slotName))
      if slotId == -1
        return
      if newBoxUseCount <= 0
        break

      query(human_weap__gunEids[int(slotId)]) <| $ [es(REQUIRE_NOT=itemInWeaponSlot)] (gun__ammoHolders : Array;
                                                                                       gun__curAmmoHolderIndex : int;
                                                                                       item__ownedByTeam : int;
                                                                                       gun__ammo : int;
                                                                                       gun__numReserveAmmo : int;
                                                                                       gun__reserveAmmoTemplate : string;
                                                                                       gun__additionalReserveAmmoTemplates : StringList;
                                                                                       gun__additionalNumReserveAmmos : IntList;
                                                                                       launcherTag : Tag const?)
        if resupply_launchers == (launcherTag == null)
          return

        if item__ownedByTeam != box_team && !any_team
          incompatibleGunFailed = true
          return

        var ammoHolders : array<string>
        for ammoHolder in gun__ammoHolders
          push(ammoHolders, ammoHolder ?? "")
        let numReserveAmmo = max(1, gun__numReserveAmmo) 
        var ammoTempl = gun__reserveAmmoTemplate
        if empty(gun__reserveAmmoTemplate) && !empty(ammoHolders)
          ammoTempl = ammoHolders[0]

        if numReserveAmmo > 0
          let ammoHolderIdx = find_index(ammoHolders, ammoTempl)
          let ammoInGun = (ammoHolderIdx == gun__curAmmoHolderIndex) ? gun__ammo : 0
          try_refill_ammoholder_for_gun(requester,
                                        human_weap__gunEids[int(slotId)],
                                        ammoInGun,
                                        ammoTempl,
                                        numReserveAmmo,
                                        newBoxUseCount,
                                        itemContainer) <| $(itemTemplate)
            return is_ammo_for_gun(itemTemplate, gun__ammoHolders) && find_index(gun__additionalReserveAmmoTemplates, itemTemplate) < 0

        for ammoTemplateStr, ammoNum in gun__additionalReserveAmmoTemplates, gun__additionalNumReserveAmmos
          if ammoNum <= 0
            continue

          peek(ammoTemplateStr) <| $(ammoTemplate)
            let ammoHolderIdx = find_index(ammoHolders, string(ammoTemplateStr))
            let ammoInGun = (ammoHolderIdx == gun__curAmmoHolderIndex) ? gun__ammo : 0
            try_refill_ammoholder_for_gun(requester,
                                          human_weap__gunEids[int(slotId)],
                                          ammoInGun,
                                          ammoTemplate,
                                          ammoNum,
                                          newBoxUseCount,
                                          itemContainer) <| $(itemTemplate)
              return itemTemplate == ammoTemplate

      if resupply_launchers
        let slotCount = human_weap__gunMods.length() - 1
        for i in range(0, slotCount)
          if newBoxUseCount < 0
            break
          let gunMods = human_weap__gunMods[i] |> get_ecs_EidList()
          if gunMods != null
            for gunModEid in *gunMods
              let gun__ammoHolderEid = gunModEid |> get_Eid("gun__ammoHolderEid") ?? INVALID_ENTITY_ID
              if !!gun__ammoHolderEid
                let ammo_holder__templateName = gun__ammoHolderEid |> get_ecs_string("ammo_holder__templateName") ?? ""
                if !empty(ammo_holder__templateName)
                  let success = try_to_refill_grenades_launcher(requester, ammo_holder__templateName)
                  if success
                    newBoxUseCount -= 1

  ret.boxUses = box_use_count - newBoxUseCount

  if box_use_count <= 0
    ret.status = RefillAmmoStatus.FAIL_EMPTY_BOX
  elif ret.boxUses <= 0
    if incompatibleGunFailed
      ret.status = isFriendlyBox ? RefillAmmoStatus.FAIL_INCOMPATIBLE_ENEMY_GUN : RefillAmmoStatus.FAIL_INCOMPATIBLE_FRIENDLY_GUN
    else
      ret.status = RefillAmmoStatus.FAIL_AMMO_FULL
  return ret

[es(tag=server, track=useful_box__useCount, REQUIRE=ammunitionBox)]
def ammo_box_on_refill_es(evt : Event;
                          useful_box__maxUseCount : int;
                          useful_box__useCount : int;
                          maxCostReturnedOnDestructionMul : float;
                          var costReturnedOnDestructionMul : float&)
  let ammoFullness = safediv(float(useful_box__useCount), float(useful_box__maxUseCount))
  costReturnedOnDestructionMul = maxCostReturnedOnDestructionMul * ammoFullness

[es(tag=server, before=useful_box_use_finish_es, REQUIRE=ammunitionBox)]
def ammo_box_resupply_ammo_es(evt : CmdUseUsefulBox;
                              eid : EntityId;
                              useful_box__useCount : int;
                              team aka box_team : int;
                              useful_box__anyTeam : Tag const?;
                              resupply_launchers : Tag const?;
                              resupply__ammoSlots : StringList;
                              var useful_box__requiredUseCount : int&;
                              var useful_box__successUse : bool&)
  let refillAmmoResult = try_to_refill_ammo(evt.requesterEid, useful_box__useCount, box_team, useful_box__anyTeam != null, resupply_launchers != null, resupply__ammoSlots)

  useful_box__requiredUseCount = refillAmmoResult.boxUses
  useful_box__successUse ||= refillAmmoResult.status == RefillAmmoStatus.SUCCESS

  if useful_box__successUse
    send_net_event(eid, CmdPlayItemUseSound(requesterEid = evt.requesterEid))

  if refillAmmoResult.status == RefillAmmoStatus.FAIL_AMMO_FULL
    send_net_event(evt.requesterEid, CmdHeroLogEvent(event = "ammo_full", text = "resupply/ammo_full"))
  elif refillAmmoResult.status == RefillAmmoStatus.FAIL_INCOMPATIBLE_FRIENDLY_GUN
    send_net_event(evt.requesterEid, CmdHeroLogEvent(event = "cant_refill_picked_weapon", text = "resupply/cant_refill_friendly_weapon_from_enemy_box"))
  elif refillAmmoResult.status == RefillAmmoStatus.FAIL_INCOMPATIBLE_ENEMY_GUN
    send_net_event(evt.requesterEid, CmdHeroLogEvent(event = "cant_refill_picked_weapon", text = "resupply/cant_refill_picked_weapon"))

[es(tag=server, before=useful_box_use_finish_es, REQUIRE=ammunitionBox)]
def ammo_box_resupply_grenade_es(evt : CmdUseUsefulBox;
                                 eid : EntityId;
                                 var useful_box__successUse : bool&;
                                 var useful_box__requiredUseCount : int&;
                                 grenadeResupplyItem : string)
  useful_box__requiredUseCount = 1
  query(evt.requesterEid) <| $ [es] (human_inventory__grenadesOnInit : StringList&)
    if human_inventory__grenadesOnInit |> empty()
      let success = try_to_refill_grenades(evt.requesterEid, grenadeResupplyItem)
      useful_box__successUse ||= success
    else
      for grenadeItem in human_inventory__grenadesOnInit
        let success = try_to_refill_grenades(evt.requesterEid, string(grenadeItem))
        useful_box__successUse ||= success
    if useful_box__successUse
      send_net_event(eid, CmdPlayItemUseSound(requesterEid = evt.requesterEid))


def try_fill_additional_ammo_templates(weap_info : Object const?; var additional_ammo_templates : StringList)
  clear(additional_ammo_templates)

  let additionalReserveAmmoTemplates = weap_info?.additionalReserveAmmoTemplates ?as Array
  if additionalReserveAmmoTemplates != null
    clear(additional_ammo_templates)
    for ammoTemplateItem in *additionalReserveAmmoTemplates
      push(additional_ammo_templates, ammoTemplateItem ?? "")


def try_fill_additional_ammo_nums(weap_info : Object const?; var additional_ammo_nums : IntList)
  clear(additional_ammo_nums)

  let additionalNumReserveAmmos = weap_info?.additionalNumReserveAmmos ?as Array
  if additionalNumReserveAmmos != null
    clear(additional_ammo_nums)
    for ammoNumItem in *additionalNumReserveAmmos
      push(additional_ammo_nums, ammoNumItem ?? 0)

def private init_gun_initial_components(weaponIndex : int;
                                        team : int;
                                        gun__ammoHolders : Array;
                                        inventory__itemCreateTemplates : Object;
                                        human_weap__weapInfo : Array;
                                        var item__ownedByTeam : int&;
                                        var gun__reserveAmmoTemplate : das_string&;
                                        var gun__numReserveAmmo : int&;
                                        var gun__additionalReserveAmmoTemplates : StringList;
                                        var gun__additionalNumReserveAmmos : IntList;
                                        var gun__initialComponents : Object&)
  item__ownedByTeam = team
  for ammoHolder in gun__ammoHolders
    let ammoHolderName = ammoHolder ?? ""
    let numAmmosToCreate = get_int(inventory__itemCreateTemplates, ammoHolderName) ?? 0
    if numAmmosToCreate > 0
      gun__reserveAmmoTemplate := ammoHolderName
      gun__numReserveAmmo = numAmmosToCreate
      break
  let weapInfo = get_ecs_object(human_weap__weapInfo[weaponIndex])
  try_fill_additional_ammo_templates(weapInfo, gun__additionalReserveAmmoTemplates)
  try_fill_additional_ammo_nums(weapInfo, gun__additionalNumReserveAmmos)

  gun__initialComponents |> set("item__ownedByTeam", item__ownedByTeam)
  gun__initialComponents |> set("gun__numReserveAmmo", gun__numReserveAmmo)
  gun__initialComponents |> set("gun__reserveAmmoTemplate", gun__reserveAmmoTemplate)
  gun__initialComponents |> set("gun__additionalReserveAmmoTemplates", gun__additionalReserveAmmoTemplates)
  gun__initialComponents |> set("gun__additionalNumReserveAmmos", gun__additionalNumReserveAmmos)


[es(tag=server, on_appear, track=human_weap__gunEids, after=create_items_for_soldier_on_appear)]
def human_weapon_set_gun_info_es(evt : Event;
                                 team : int;
                                 inventory__itemCreateTemplates : Object;
                                 human_weap__gunEids : EidList;
                                 human_weap__weapInfo : Array)
  let gunCount = min(length(human_weap__gunEids), length(human_weap__weapInfo))
  for i in range(gunCount)
    query(human_weap__gunEids[i]) <| $ [es] (gun__ammoHolders : Array;
                                             var gun__initialComponents : Object&;
                                             var item__ownedByTeam : int&;
                                             var gun__reserveAmmoTemplate : das_string&;
                                             var gun__numReserveAmmo : int&;
                                             var gun__additionalReserveAmmoTemplates : StringList;
                                             var gun__additionalNumReserveAmmos : IntList)
      if item__ownedByTeam != TEAM_UNASSIGNED
        return
      init_gun_initial_components(i, team, gun__ammoHolders, inventory__itemCreateTemplates,
                                  human_weap__weapInfo, item__ownedByTeam, gun__reserveAmmoTemplate,
                                  gun__numReserveAmmo, gun__additionalReserveAmmoTemplates,
                                  gun__additionalNumReserveAmmos, gun__initialComponents)

[es(tag=server, on_appear, track=gun__owner)]
def weapon_set_initial_gun_info_es(evt : Event;
                                   eid : EntityId;
                                   gun__owner : EntityId;
                                   gun__ammoHolders : Array;
                                   var gun__initialComponents : Object&;
                                   var item__ownedByTeam : int&;
                                   var gun__reserveAmmoTemplate : das_string&;
                                   var gun__numReserveAmmo : int&;
                                   var gun__additionalReserveAmmoTemplates : StringList;
                                   var gun__additionalNumReserveAmmos : IntList)
  if item__ownedByTeam != TEAM_UNASSIGNED
    return

  query(gun__owner) <| $ [es] (team : int;
                               human_weap__gunEids : EidList;
                               human_weap__weapInfo : Array;
                               inventory__itemCreateTemplates : Object)
    let weapIndex = find_index(human_weap__gunEids, eid)
    if weapIndex <= -1 || weapIndex >= length(human_weap__weapInfo)
      return

    init_gun_initial_components(weapIndex, team, gun__ammoHolders, inventory__itemCreateTemplates,
                                human_weap__weapInfo, item__ownedByTeam, gun__reserveAmmoTemplate,
                                gun__numReserveAmmo, gun__additionalReserveAmmoTemplates,
                                gun__additionalNumReserveAmmos, gun__initialComponents)


