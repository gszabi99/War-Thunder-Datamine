require ecs
require Mission
require DagorDataBlock
require DagorSystem

def components_to_blk(var blk : DataBlock; eid : EntityId)
  ecs::query(eid) <| $ [es] (setting_dot_crewSkillK : float;
                            setting_dot_weapons : string;
                            setting_dot_isPhysPredictionEnabled : bool;
                            setting_dot_loadAnim : bool;
                            setting_dot_unit_class : string;
                            setting_dot_applyAllMods : bool;
                            setting_dot_closed_waypoints : bool;
                            setting_dot_bullets : StringList;
                            setting_dot_bulletsCount : IntList;
                            setting_dot_flags : int;
                            setting_dot_isDelayed : bool;
                            setting_dot_skin : string;
                            setting_dot_canChangeUnit : bool;
                            setting_dot_shouldDrawSmallIndForMissTarget : bool;
                            setting_dot_uniqueName : string;
                            setting_dot_count : int;
                            setting_dot_attack_type : string;
                            setting_dot_army : int;
                            setting_dot_formation_type : string;
                            setting_dot_formation_div : int;
                            setting_dot_formation_step : float2;
                            setting_dot_formation_noise : float2;
                            setting_dot_stealthRadius : float;
                            setting_dot_supportUnitType : int;
                            setting_dot_targetAir : bool;
                            setting_dot_targetGnd : bool;
                            setting_dot_targetAAA : bool;
                            setting_dot_maxDeviationAngle : float;
                            setting_dot_accuracy : float;
                            setting_dot_effShootingRate : float;
                            setting_dot_lightlyArmored : bool;
                            setting_dot_avoidObstacles : bool;
                            setting_dot_targetableByAi : bool;
                            setting_dot_isImmortal : bool;
                            setting_dot_calmDetection : bool;
                            setting_dot_aiReloadMult : float;
                            setting_dot_speed : float;
                            setting_dot_name : string;
                            setting_dot_routeName : string;
                            setting_dot_unit_target_list : StringList;
                            setting_dot_toGround : bool)
    datablock_addReal(blk, "crewSkillK", setting_dot_crewSkillK)
    datablock_addStr(blk, "weapons", setting_dot_weapons)
    datablock_addBool(blk, "isPhysPredictionEnabled", setting_dot_isPhysPredictionEnabled)
    datablock_addBool(blk, "loadAnim", setting_dot_loadAnim)
    datablock_addStr(blk, "unit_class", setting_dot_unit_class)
    datablock_addBool(blk, "applyAllMods", setting_dot_applyAllMods)
    datablock_addBool(blk, "closed_waypoints", setting_dot_closed_waypoints)
    datablock_addInt(blk, "flags", setting_dot_flags)
    datablock_addStr(blk, "route", setting_dot_routeName)
    datablock_addBool(blk, "canChangeUnit", setting_dot_canChangeUnit)
    datablock_addBool(blk, "toGround", setting_dot_toGround)
    for i in range(0, length(setting_dot_bullets))
      let bullet = string(setting_dot_bullets[i]) 
      datablock_addStr(blk, "bullets{i}", bullet)
    for i in range(0, length(setting_dot_bulletsCount))
      datablock_addInt(blk, "bulletsCount{i}", setting_dot_bulletsCount[i])
    var prop = datablock_add_block(blk, "props")
    datablock_addBool(prop, "isDelayed", setting_dot_isDelayed)
    datablock_addStr(prop, "skin", setting_dot_skin)
    datablock_addBool(prop, "shouldDrawSmallIndForMissTarget", setting_dot_shouldDrawSmallIndForMissTarget)
    datablock_addStr(prop, "uniqueName", setting_dot_uniqueName)
    datablock_addInt(prop, "count", setting_dot_count)
    datablock_addStr(prop, "attack_type", setting_dot_attack_type)
    datablock_addInt(prop, "army", setting_dot_army)
    datablock_addStr(prop, "formation_type", setting_dot_formation_type)
    datablock_addInt(prop, "formation_div", setting_dot_formation_div)
    datablock_addPoint2(prop, "formation_step", setting_dot_formation_step)
    datablock_addPoint2(prop, "formation_noise", setting_dot_formation_noise)
    datablock_addReal(prop, "stealthRadius", setting_dot_stealthRadius)
    datablock_addInt(prop, "supportUnitType", setting_dot_supportUnitType)
    datablock_addBool(prop, "targetAir", setting_dot_targetAir)
    datablock_addBool(prop, "targetGnd", setting_dot_targetGnd)
    datablock_addBool(prop, "targetAAA", setting_dot_targetAAA)
    datablock_addReal(prop, "maxDeviationAngle", setting_dot_maxDeviationAngle)
    datablock_addReal(prop, "accuracy", setting_dot_accuracy)
    datablock_addReal(prop, "effShootingRate", setting_dot_effShootingRate)
    datablock_addBool(prop, "lightlyArmored", setting_dot_lightlyArmored)
    datablock_addBool(prop, "avoidObstacles", setting_dot_avoidObstacles)
    datablock_addBool(prop, "targetableByAi", setting_dot_targetableByAi)
    datablock_addBool(prop, "isImmortal", setting_dot_isImmortal)
    datablock_addBool(prop, "calmDetection", setting_dot_calmDetection)
    datablock_addReal(prop, "aiReloadMult", setting_dot_aiReloadMult)
    datablock_addReal(prop, "speed", setting_dot_speed)
    datablock_addStr(prop, "name", setting_dot_name)
    var tBlk = datablock_add_block(blk, "targetList")
    for i in range(0, length(setting_dot_unit_target_list))
      let target = string(setting_dot_unit_target_list[i])
      datablock_addStr(tBlk, "t", target)

[es (on_event=EventLevelLoaded)]
def unit_loader_init(evt : Event;
                  eid : EntityId;
                  setting_dot_unitType, setting_dot_className : string;
                  setting_dot_tm : float3x4;
                  setting_dot_playerNo, setting_dot_flags : int)
  var settingsBlk : DataBlock?
  settingsBlk = datablock_init()
  components_to_blk(*settingsBlk, eid)

  if setting_dot_unitType == "ship"
    create_ship(setting_dot_className, setting_dot_tm, *settingsBlk, setting_dot_playerNo, 0)
  elif setting_dot_unitType == "tank"
    create_tank(setting_dot_className, setting_dot_tm, *settingsBlk, setting_dot_playerNo, 0)
  elif setting_dot_unitType == "lightVehicle"
    create_light_vehicle(setting_dot_className, setting_dot_tm, *settingsBlk, setting_dot_playerNo, 0)
  elif setting_dot_unitType == "barrageBalloon"
    create_barrage_balloon(setting_dot_className, setting_dot_tm, *settingsBlk, setting_dot_playerNo, 0)
  elif setting_dot_unitType == "walker"
    create_walker(setting_dot_className, setting_dot_tm, *settingsBlk, setting_dot_playerNo, 0)
  elif setting_dot_unitType == "infantry"
    create_infantry(setting_dot_className, setting_dot_tm, *settingsBlk, setting_dot_playerNo, 0)
  elif setting_dot_unitType == "fortification"
    create_fortification(setting_dot_className, setting_dot_tm, *settingsBlk, setting_dot_playerNo, setting_dot_flags)
  elif setting_dot_unitType == "aircraft"
    create_aircraft(setting_dot_className, setting_dot_tm, *settingsBlk, setting_dot_playerNo, 0)

  destroyEntity(eid)
  datablock_delete(settingsBlk)