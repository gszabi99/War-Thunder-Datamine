require ecs
require Mission
require DagorDataBlock
require DagorSystem

def components_to_blk(var blk : DataBlock; eid : EntityId)
  ecs::query(eid) <| $ [es] (setting__crewSkillK : float;
                             setting__weapons : string;
                             setting__isPhysPredictionEnabled : bool;
                             setting__loadAnim : bool;
                             setting__unit_class : string;
                             setting__applyAllMods : bool;
                             setting__closed_waypoints : bool;
                             setting__bullets : StringList;
                             setting__bulletsCount : IntList;
                             setting__flags : int;
                             setting__isDelayed : bool;
                             setting__skin : string;
                             setting__canChangeUnit : bool;
                             setting__shouldDrawSmallIndForMissTarget : bool;
                             setting__uniqueName : string;
                             setting__count : int;
                             setting__attack_type : string;
                             setting__army : int;
                             setting__formation_type : string;
                             setting__formation_div : int;
                             setting__formation_step : float2;
                             setting__formation_noise : float2;
                             setting__stealthRadius : float;
                             setting__supportUnitType : int;
                             setting__targetAir : bool;
                             setting__targetGnd : bool;
                             setting__targetAAA : bool;
                             setting__maxDeviationAngle : float;
                             setting__accuracy : float;
                             setting__effShootingRate : float;
                             setting__lightlyArmored : bool;
                             setting__avoidObstacles : bool;
                             setting__targetableByAi : bool;
                             setting__isImmortal : bool;
                             setting__calmDetection : bool;
                             setting__aiReloadMult : float;
                             setting__speed : float;
                             setting__name : string;
                             setting__routeName : string;
                             setting__unit_target_list : StringList;
                             setting__toGround : bool)
    datablock_addReal(blk, "crewSkillK", setting__crewSkillK)
    datablock_addStr(blk, "weapons", setting__weapons)
    datablock_addBool(blk, "isPhysPredictionEnabled", setting__isPhysPredictionEnabled)
    datablock_addBool(blk, "loadAnim", setting__loadAnim)
    datablock_addStr(blk, "unit_class", setting__unit_class)
    datablock_addBool(blk, "applyAllMods", setting__applyAllMods)
    datablock_addBool(blk, "closed_waypoints", setting__closed_waypoints)
    datablock_addInt(blk, "flags", setting__flags)
    datablock_addStr(blk, "route", setting__routeName)
    datablock_addBool(blk, "canChangeUnit", setting__canChangeUnit)
    datablock_addBool(blk, "toGround", setting__toGround)
    for i in range(0, length(setting__bullets))
      let bullet = string(setting__bullets[i])
      datablock_addStr(blk, "bullets{i}", bullet)
    for i in range(0, length(setting__bulletsCount))
      datablock_addInt(blk, "bulletsCount{i}", setting__bulletsCount[i])
    var prop = datablock_add_block(blk, "props")
    datablock_addBool(prop, "isDelayed", setting__isDelayed)
    datablock_addStr(prop, "skin", setting__skin)
    datablock_addBool(prop, "shouldDrawSmallIndForMissTarget", setting__shouldDrawSmallIndForMissTarget)
    datablock_addStr(prop, "uniqueName", setting__uniqueName)
    datablock_addInt(prop, "count", setting__count)
    datablock_addStr(prop, "attack_type", setting__attack_type)
    datablock_addInt(prop, "army", setting__army)
    datablock_addStr(prop, "formation_type", setting__formation_type)
    datablock_addInt(prop, "formation_div", setting__formation_div)
    datablock_addPoint2(prop, "formation_step", setting__formation_step)
    datablock_addPoint2(prop, "formation_noise", setting__formation_noise)
    datablock_addReal(prop, "stealthRadius", setting__stealthRadius)
    datablock_addInt(prop, "supportUnitType", setting__supportUnitType)
    datablock_addBool(prop, "targetAir", setting__targetAir)
    datablock_addBool(prop, "targetGnd", setting__targetGnd)
    datablock_addBool(prop, "targetAAA", setting__targetAAA)
    datablock_addReal(prop, "maxDeviationAngle", setting__maxDeviationAngle)
    datablock_addReal(prop, "accuracy", setting__accuracy)
    datablock_addReal(prop, "effShootingRate", setting__effShootingRate)
    datablock_addBool(prop, "lightlyArmored", setting__lightlyArmored)
    datablock_addBool(prop, "avoidObstacles", setting__avoidObstacles)
    datablock_addBool(prop, "targetableByAi", setting__targetableByAi)
    datablock_addBool(prop, "isImmortal", setting__isImmortal)
    datablock_addBool(prop, "calmDetection", setting__calmDetection)
    datablock_addReal(prop, "aiReloadMult", setting__aiReloadMult)
    datablock_addReal(prop, "speed", setting__speed)
    datablock_addStr(prop, "name", setting__name)
    var tBlk = datablock_add_block(blk, "targetList")
    for i in range(0, length(setting__unit_target_list))
      let target = string(setting__unit_target_list[i])
      datablock_addStr(tBlk, "t", target)

[es(on_event=EventLevelLoaded)]
def unit_loader_init(evt : Event;
                     eid : EntityId;
                     setting__unitType, setting__className : string;
                     setting__tm : float3x4;
                     setting__playerNo, setting__flags : int)
  var settingsBlk : DataBlock?
  settingsBlk = datablock_init()
  components_to_blk(*settingsBlk, eid)

  if setting__unitType == "ship"
    create_ship(setting__className, setting__tm, *settingsBlk, setting__playerNo, 0)
  elif setting__unitType == "tank"
    create_tank(setting__className, setting__tm, *settingsBlk, setting__playerNo, 0)
  elif setting__unitType == "lightVehicle"
    create_light_vehicle(setting__className, setting__tm, *settingsBlk, setting__playerNo, 0)
  elif setting__unitType == "barrageBalloon"
    create_barrage_balloon(setting__className, setting__tm, *settingsBlk, setting__playerNo, 0)
  elif setting__unitType == "walker"
    create_walker(setting__className, setting__tm, *settingsBlk, setting__playerNo, 0)
  elif setting__unitType == "infantry"
    create_infantry(setting__className, setting__tm, *settingsBlk, setting__playerNo, 0)
  elif setting__unitType == "fortification"
    create_fortification(setting__className, setting__tm, *settingsBlk, setting__playerNo, setting__flags)
  elif setting__unitType == "aircraft"
    create_aircraft(setting__className, setting__tm, *settingsBlk, setting__playerNo, 0)

  destroyEntity(eid)
  datablock_delete(settingsBlk)