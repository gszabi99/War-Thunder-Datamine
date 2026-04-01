require ecs
require Unit
require Weapon
require math.base
require math.random
require DagorSystem
require Mission
require DagorDebug3D
require DagorMath
require math
require math.base
require IGroundModel
require %game.utils.utils_common
require %game.unit.unit_events

let REARM_TIME = 60.0

enum FireAndChangePosState
  SHOOTING
  CHANGING_POSITION
  REARMING

def move_mission_unit_to_random_pos(unit__missionName : string; var unit_fire_and_change_pos__move_target_pos_index : int&; var unit__ref : UnitRef&)
  query() <| $ [es] (unit_move_to_random_position_names : Object)
    let positions = unit_move_to_random_position_names |> get_ecs_Point3List(unit__missionName)
    if positions == null
      logerr("No move positions for unit {unit__missionName}, in unit_move_to_random_position_names")
    else
      var targetIndex = rnd_int(0, length(*positions) - 1)
      if targetIndex == unit_fire_and_change_pos__move_target_pos_index
        if length(*positions) > 1
          targetIndex = (targetIndex + 1) % length(*positions)
        else
          logerr("No NEW move positions for unit {unit__missionName} in unit_move_to_random_position_names")

      unit_fire_and_change_pos__move_target_pos_index = targetIndex

      var targetPos = IDENT_TM
      targetPos[3] = (*positions)[targetIndex]
      set_destination_way_point(unit__ref.unit, "USE_SPLINE", targetPos, 20.)


def is_primary_gun_out_of_ammo(unit__ref : UnitRef&)
  var count = 0
  foreach_primary_gun(unit__ref.unit.weap.Weapons) <| $(var weapon)
    count += weapon.countBullets
  return count == 0


def set_fire_and_change_pos_state(unit__missionName : string; new_state : int; var unit_fire_and_change_pos__state : int&; var unit_fire_and_change_pos__move_target_pos_index : int&; var unit__ref : UnitRef&)
  unit_fire_and_change_pos__state = new_state
  if new_state == int(FireAndChangePosState.SHOOTING)
    set_unit_attack_type(unit__ref.unit, "fire_at_will")
  elif new_state == int(FireAndChangePosState.CHANGING_POSITION)
    move_mission_unit_to_random_pos(unit__missionName, unit_fire_and_change_pos__move_target_pos_index, unit__ref)
    set_unit_attack_type(unit__ref.unit, "dont_aim")


[es(tag=server, on_appear, on_event=EventUnitRespawn, after=unit_init_completed_es)]
def on_unit_appear_change_pos_es(evt : Event;
                                 unit__missionName : string;
                                 var unit_fire_and_change_pos__state : int&;
                                 var unit_fire_and_change_pos__move_target_pos_index : int&;
                                 var unit__ref : UnitRef&)
  set_fire_and_change_pos_state(unit__missionName, int(FireAndChangePosState.CHANGING_POSITION), unit_fire_and_change_pos__state, unit_fire_and_change_pos__move_target_pos_index, unit__ref)

  var gm = as_gm(unit__ref.unit)
  if gm != null
    gm.rearmOnField.rearmTime = REARM_TIME
    gm.rearmOnField.isRearmAllowedByMission = true


[es(tag=server, no_order)]
def mission_unit_update_es(act : UpdateStageInfoAct;
                           unit__missionName : string;
                           var unit__ref : UnitRef&;
                           var unit_fire_and_change_pos__state : int&;
                           var unit_fire_and_change_pos__move_target_pos_index : int&)
  if !unit__ref.unit.isAlive
    return

  var changeState = -1

  if unit_fire_and_change_pos__state == int(FireAndChangePosState.SHOOTING)
    let isOutOfAmmo = is_primary_gun_out_of_ammo(unit__ref)
    if isOutOfAmmo
      changeState = int(FireAndChangePosState.CHANGING_POSITION)

  elif unit_fire_and_change_pos__state == int(FireAndChangePosState.CHANGING_POSITION)
    let moveSysState = get_move_sys_state(unit__ref.unit)
    if moveSysState == int(MoveSysState.ST_HALT)
      changeState = int(FireAndChangePosState.REARMING)

  elif unit_fire_and_change_pos__state == int(FireAndChangePosState.REARMING)
    let isOutOfAmmo = is_primary_gun_out_of_ammo(unit__ref)
    if !isOutOfAmmo
      changeState = int(FireAndChangePosState.SHOOTING)

  if changeState != -1
    set_fire_and_change_pos_state(unit__missionName, changeState, unit_fire_and_change_pos__state, unit_fire_and_change_pos__move_target_pos_index, unit__ref)

[es(tag=server, on_event=EventOnUnitDead, REQUIRE=on_death_substract_team_tickets_num)]
def on_unit_death_substract_team_tickets_num(evt : Event;
                                             unit__ref : UnitRef&;
                                             on_death_substract_team_tickets_num : int)
  change_mp_tickets_for_team(unit__ref.unit.army, -on_death_substract_team_tickets_num)
