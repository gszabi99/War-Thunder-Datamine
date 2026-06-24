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
require DagorDataBlock
require app
require %game.utils.utils_common
require %game.unit.unit_events
require %appGame.wt_events

let REARM_TIME = 60.0

enum FireAndChangePosState
  SHOOTING
  CHANGING_POSITION
  REARMING

def collect_unit_target_positions(unit__missionName : string; var positions : array<float3>)
  for idx in range(1, 10)
    let area_name = "{unit__missionName}__move_area_0{idx}"
    let pos = get_area_center_by_name(area_name)
    if pos == float3(0., 0., 0.)
      break
    positions |> push(pos)
  if get_area_center_by_name("{unit__missionName}__move_area_10") != float3(0., 0., 0.)
    logerr("Unit {unit__missionName}: more than 9 move areas defined, __move_area_10 will not be used")


def move_mission_unit_to_random_pos(unit__missionName : string; var unit_fire_and_change_pos__move_target_pos_index : int&; var unit__ref : UnitRef&)
  var positions : array<float3>
  collect_unit_target_positions(unit__missionName, positions)
  if positions |> empty()
    logerr("No target areas found for unit {unit__missionName} (expected {unit__missionName}__move_area_01, ...)")
    return
  var targetIndex = rnd_int(0, length(positions) - 1)
  if targetIndex == unit_fire_and_change_pos__move_target_pos_index
    if length(positions) > 1
      targetIndex = (targetIndex + 1) % length(positions)
    else
      logerr("No NEW target area for unit {unit__missionName} - only one area defined")

  unit_fire_and_change_pos__move_target_pos_index = targetIndex

  var targetPos = IDENT_TM
  targetPos[3] = positions[targetIndex]
  set_destination_way_point(unit__ref.unit, "USE_SPLINE", targetPos, 20.)


def is_primary_gun_out_of_ammo(unit__ref : UnitRef&)
  var count = 0
  foreach_primary_gun(unit__ref.unit.weap.Weapons) <| $(var weapon)
    count += weapon.countBullets
  return count == 0


def set_fire_and_change_pos_state(eid : EntityId; unit__missionName : string; new_state : int; var unit_fire_and_change_pos__state : int&; var unit_fire_and_change_pos__move_target_pos_index : int&; var unit__ref : UnitRef&)
  unit_fire_and_change_pos__state = new_state
  if new_state == int(FireAndChangePosState.SHOOTING)
    sendEvent(eid, CmdUnitAttackTarget())
  elif new_state == int(FireAndChangePosState.CHANGING_POSITION)
    move_mission_unit_to_random_pos(unit__missionName, unit_fire_and_change_pos__move_target_pos_index, unit__ref)
    set_unit_attack_type(unit__ref.unit, "dont_aim")


[es(tag=server, on_appear, on_event=EventUnitRespawn, after=(unit_init_completed_es, unit_apply_attack_type_on_appear_es, unit_apply_attack_type_flight_start_es))]
def on_unit_appear_change_pos_es(evt : Event;
                                 eid : EntityId;
                                 unit__missionName : string;
                                 var unit_fire_and_change_pos__state : int&;
                                 var unit_fire_and_change_pos__move_target_pos_index : int&;
                                 var unit__ref : UnitRef&)
  set_fire_and_change_pos_state(eid, unit__missionName, int(FireAndChangePosState.CHANGING_POSITION), unit_fire_and_change_pos__state, unit_fire_and_change_pos__move_target_pos_index, unit__ref)

  var gm = as_gm(unit__ref.unit)
  if gm != null
    gm.rearmOnField.rearmTime = REARM_TIME
    gm.rearmOnField.isRearmAllowedByMission = true


[es(tag=server, no_order)]
def mission_unit_update_es(act : UpdateStageInfoAct;
                           eid : EntityId;
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
    set_fire_and_change_pos_state(eid, unit__missionName, changeState, unit_fire_and_change_pos__state, unit_fire_and_change_pos__move_target_pos_index, unit__ref)

[es(tag=server, on_event=EventOnUnitDead)]
def on_unit_death_substract_team_tickets_num(evt : Event;
                                             unit__ref : UnitRef&;
                                             on_death_substract_team_tickets_num : int)
  change_mp_tickets_for_team(unit__ref.unit.army, -on_death_substract_team_tickets_num)


def call_unit_attack_target(unit__missionName : string; attack_type : string; targets : StringList)
  using() <| $(var blk : DataBlock)
    add(blk, "object", unit__missionName)
    if !empty(attack_type)
      add(blk, "attack_type", attack_type)
    for target in targets
      add(blk, "target", string(target))
    call_mission_action("unitAttackTarget", blk)


[es(tag=server)]
def unit_init_attack_type_es(evt : CmdInitComponent;
                             eid : EntityId)
  let data = evt.data
  if data == null
    return
  let propsBlk = data.settingsBlk |> datablock_get_block_by_name("props")
  if propsBlk == null
    return

  let attack_type = *propsBlk |> datablock_getStr("attack_type", "")

  using() <| $(var targets : StringList)
    *propsBlk |> datablock_for_each_param("target") <| $(i, t)
      if t == int(DataBlockParamType.TYPE_STRING)
        targets |> push(string(*propsBlk |> datablock_getStr(i)))

    if targets |> empty()
      return

    addSubTemplate(eid, "unit_init_attack_type") <| $(var init : ComponentsInitializer)
      set(init, "unit_init_attack_type__attack_type", attack_type)
      set(init, "unit_init_attack_type__targets", targets)


[es(tag=server, on_event=(EventFlightStart, EventUnitRespawn), REQUIRE=(unit_init_attack_type__attack_type, unit_init_attack_type__targets))]
def unit_apply_attack_type_flight_start_es(evt : Event;
                                           eid : EntityId)
  sendEvent(eid, CmdUnitAttackTarget())

[es(tag=server, on_appear, after=unit_init_completed_es, REQUIRE=(unit_init_attack_type__attack_type, unit_init_attack_type__targets))]
def unit_apply_attack_type_on_appear_es(evt : Event;
                                        eid : EntityId)
  if !is_app_in_flight()
    return
  sendEvent(eid, CmdUnitAttackTarget())

[es(on_event=CmdUnitAttackTarget)]
def on_unit_attack_target_es(evt : Event;
                             unit__missionName : string;
                             unit_init_attack_type__attack_type : string;
                             unit_init_attack_type__targets : StringList)
  call_unit_attack_target(unit__missionName, unit_init_attack_type__attack_type, unit_init_attack_type__targets)
