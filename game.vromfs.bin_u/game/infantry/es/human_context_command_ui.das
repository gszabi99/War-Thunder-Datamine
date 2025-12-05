require app
require ecs
require net
require DngHuman
require %appGame.infantry.es.hero_common
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.ai.ai_weapons_common


def update_local_player_human_context_state(hero_eid : EntityId;
                                            squad_member__squad : EntityId;
                                            human_context_command__menuCtxType : das_string;
                                            human_context_command__menuCtxEid : EntityId)
  let hasGroundTarget = human_context_command__menuCtxType == "enemy_vehicle" && human_context_command__menuCtxEid |> has("unit_tag__tank")
  let hasAirTarget = human_context_command__menuCtxType == "enemy_vehicle" && human_context_command__menuCtxEid |> has("unit_tag__aircraft")

  var hasGroundVehicleAttacker = false
  var hasAirVehicleAttacker = false
  if hasGroundTarget || hasAirTarget
    query(squad_member__squad) <| $ [es] (squad__allMembers : EidList)
      for memberEid in squad__allMembers
        if (!hasGroundTarget || hasGroundVehicleAttacker) && (!hasAirTarget || hasAirVehicleAttacker)
          break
        if memberEid == hero_eid
          continue
        query(memberEid) <| $ [es] (squad_member__canAttackGroundVehicle : bool; squad_member__canAttackAirVehicle : bool)
          hasGroundVehicleAttacker ||= squad_member__canAttackGroundVehicle
          hasAirVehicleAttacker ||= squad_member__canAttackAirVehicle

  query(get_local_player_eid()) <| $ [es] (var local_player_human_context__ctxState : Object&)
    assume state = local_player_human_context__ctxState
    state |> set("hasGroundVehicleAttackerAndTarget", hasGroundTarget && hasGroundVehicleAttacker)
    state |> set("hasAirVehicleAttackerAndTarget", hasAirTarget && hasAirVehicleAttacker)

[es(tag=gameClient, on_appear)]
def human_context_command_ui_init_state(evt : Event; var local_player_human_context__ctxState : Object&)
  assume state = local_player_human_context__ctxState
  state |> set("hasGroundVehicleAttackerAndTarget", false)
  state |> set("hasAirVehicleAttackerAndTarget", false)

[es(on_appear, track=(isAlive, isDowned, human_weap__gunEids, itemContainer))]
def human_context_command_ui_update_soldier_state(evt : Event;
                                                  isAlive : bool;
                                                  isDowned : bool;
                                                  itemContainer : EidList;
                                                  human_weap__gunEids : EidList;
                                                  squad_member__squad : EntityId;
                                                  var squad_member__canAttackGroundVehicle : bool&;
                                                  var squad_member__canAttackAirVehicle : bool&)
  if !isAlive || isDowned
    squad_member__canAttackGroundVehicle = false
    squad_member__canAttackAirVehicle = false
  else
    let gun_eid = human_weap__gunEids[int(HUWeaponSlots.EWS_TERTIARY)]
    query(gun_eid) <| $ [es] (gun__wishAmmoItemType : int;
                              specialAIWeaponType : int = 0)
      if specialAIWeaponType == int(SpecialAIWeaponType.ATGM_MPADS_LAUNCHERS) || specialAIWeaponType == int(SpecialAIWeaponType.ROCKET_LAUNCHERS)
        let totalAmmo = get_total_ammo_count(itemContainer, gun__wishAmmoItemType, gun_eid)
        if totalAmmo > 0
          squad_member__canAttackGroundVehicle = true

  if !is_server()
    let hero_eid = get_controlled_hero_eid()
    query(hero_eid) <| $ [es] (human_context_command__menuCtxType : das_string; human_context_command__menuCtxEid : EntityId)
      update_local_player_human_context_state(hero_eid, squad_member__squad, human_context_command__menuCtxType, human_context_command__menuCtxEid)

[es(tag=gameClient, track=human_context_command__menuCtxEid, REQUIRE=watchedHero)]
def human_context_command_ui_update_context_state(evt : Event;
                                                  eid : EntityId;
                                                  squad_member__squad : EntityId;
                                                  human_context_command__menuCtxType : das_string;
                                                  human_context_command__menuCtxEid : EntityId)
  update_local_player_human_context_state(eid, squad_member__squad, human_context_command__menuCtxType, human_context_command__menuCtxEid)
