require ecs
require Mission
require DagorDataBlock
require DagorSystem
require strings

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
                             setting__isDead : bool;
                             setting__active : bool;
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
                             setting__moveSysTraceRI : bool;
                             setting__accuracy : float;
                             setting__effShootingRate : float;
                             setting__lightlyArmored : bool;
                             setting__avoidObstacles : bool;
                             setting__targetableByAi : bool;
                             setting__aiEnabled : bool;
                             setting__isImmortal : bool;
                             setting__calmDetection : bool;
                             setting__aiReloadMult : float;
                             setting__speed : float;
                             setting__name : string;
                             setting__routeName : string;
                             setting__unit_target_list : StringList;
                             setting__toGround : bool;
                             setting__forcePos : bool;
                             setting__loadSound : bool;
                             setting__cannotMove : bool;
                             setting__ignoreCollisions : bool;
                             setting__canControlInHangar : bool)
    add(blk, "crewSkillK", setting__crewSkillK)
    add(blk, "weapons", setting__weapons)
    add(blk, "isPhysPredictionEnabled", setting__isPhysPredictionEnabled)
    add(blk, "loadAnim", setting__loadAnim)
    add(blk, "unit_class", setting__unit_class)
    add(blk, "applyAllMods", setting__applyAllMods)
    add(blk, "closed_waypoints", setting__closed_waypoints)
    add(blk, "flags", setting__flags)
    add(blk, "route", setting__routeName)
    add(blk, "canChangeUnit", setting__canChangeUnit)
    add(blk, "toGround", setting__toGround)
    add(blk, "forcePos", setting__forcePos)
    add(blk, "cannotMove", setting__cannotMove)
    add(blk, "loadSound", setting__loadSound)
    add(blk, "ignoreCollisions", setting__ignoreCollisions)
    add(blk, "canControlInHangar", setting__canControlInHangar)
    for i in range(0, length(setting__bullets))
      let bullet = string(setting__bullets[i])
      add(blk, "bullets{i}", bullet)
    for i in range(0, length(setting__bulletsCount))
      add(blk, "bulletsCount{i}", setting__bulletsCount[i])
    datablock_add_block(blk, "props") <| $(prop)
      add(prop, "isDelayed", setting__isDelayed)
      add(prop, "isDead", setting__isDead)
      add(prop, "active", setting__active)
      add(prop, "skin", setting__skin)
      add(prop, "shouldDrawSmallIndForMissTarget", setting__shouldDrawSmallIndForMissTarget)
      add(prop, "uniqueName", setting__uniqueName)
      add(prop, "count", setting__count)
      add(prop, "attack_type", setting__attack_type)
      add(prop, "army", setting__army)
      add(prop, "formation_type", setting__formation_type)
      add(prop, "formation_div", setting__formation_div)
      add(prop, "formation_step", setting__formation_step)
      add(prop, "formation_noise", setting__formation_noise)
      add(prop, "stealthRadius", setting__stealthRadius)
      add(prop, "supportUnitType", setting__supportUnitType)
      add(prop, "targetAir", setting__targetAir)
      add(prop, "targetGnd", setting__targetGnd)
      add(prop, "targetAAA", setting__targetAAA)
      add(prop, "maxDeviationAngle", setting__maxDeviationAngle)
      add(prop, "moveSysTraceRI", setting__moveSysTraceRI)
      add(prop, "accuracy", setting__accuracy)
      add(prop, "effShootingRate", setting__effShootingRate)
      add(prop, "lightlyArmored", setting__lightlyArmored)
      add(prop, "avoidObstacles", setting__avoidObstacles)
      add(prop, "targetableByAi", setting__targetableByAi)
      add(prop, "aiEnabled", setting__aiEnabled)
      add(prop, "isImmortal", setting__isImmortal)
      add(prop, "calmDetection", setting__calmDetection)
      add(prop, "aiReloadMult", setting__aiReloadMult)
      add(prop, "speed", setting__speed)
      add(prop, "name", setting__name)
    datablock_add_block(blk, "targetList") <| $(tBlk)
      for i in range(0, length(setting__unit_target_list))
        let target = string(setting__unit_target_list[i])
        add(tBlk, "t", target)

[es(on_event=EventEcsMissionLoaded, tag=server)]
def unit_loader_init(evt : Event;
                     eid : EntityId;
                     setting__unitType, setting__className : string;
                     setting__tm : float3x4;
                     setting__playerNo, setting__flags : int)
  using() <| $(var settingsBlk : DataBlock)
    components_to_blk(settingsBlk, eid)

    if setting__unitType == "ship"
      create_ship(setting__className, setting__tm, settingsBlk, setting__playerNo, 0)
    elif setting__unitType == "tank"
      create_tank(setting__className, setting__tm, settingsBlk, setting__playerNo, 0)
    elif setting__unitType == "lightVehicle"
      create_light_vehicle(setting__className, setting__tm, settingsBlk, setting__playerNo, 0)
    elif setting__unitType == "barrageBalloon"
      create_barrage_balloon(setting__className, setting__tm, settingsBlk, setting__playerNo, 0)
    elif setting__unitType == "walker"
      create_walker(setting__className, setting__tm, settingsBlk, setting__playerNo, 0)
    elif setting__unitType == "infantry"
      create_infantry(setting__className, setting__tm, settingsBlk, setting__playerNo, 0)
    elif setting__unitType == "fortification"
      create_fortification(setting__className, setting__tm, settingsBlk, setting__playerNo, setting__flags)
    elif setting__unitType == "aircraft"
      create_aircraft(setting__className, setting__tm, settingsBlk, setting__playerNo, 0)
    elif setting__unitType == "objectGroups"
      create_object_group(setting__tm, settingsBlk)
    elif setting__unitType == "human"
      create_human(setting__className, setting__tm, settingsBlk, setting__playerNo, setting__flags)

    let customTemplatePrefix = "template:"
    if starts_with(setting__unitType, customTemplatePrefix)
      add(settingsBlk, "ecsTemplateOverride", slice(setting__unitType, length(customTemplatePrefix)))
      create_tank(setting__className, setting__tm, settingsBlk, setting__playerNo, 0)
  destroyEntity(eid)
