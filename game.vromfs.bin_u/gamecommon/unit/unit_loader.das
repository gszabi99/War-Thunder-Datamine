require ecs
require Mission
require DagorDataBlock
require DagorSystem
require strings
require Unit


[es(on_event=EventEcsMissionLoaded, tag=server)]
def unit_loader_init(evt : Event;
                     eid : EntityId;
                     setting__unitType : string;
                     setting__className, setting__unit_class : string;
                     setting__tm : float3x4;
                     setting__name : string;
                     setting__army : int;
                     setting__playerNo : int;
                     setting__unit_target_list : StringList;
                     var setting__count : int&;
                     setting__active : bool;
                     setting__canChangeUnit : bool)
  if setting__count > 1
    logerr("unit_loader: setting__count {setting__count} > 1 is no longer supported and will be ignored name:{empty(setting__className) ? setting__unit_class : setting__className}")
    setting__count = 1
  if setting__playerNo != -1
    logerr("unit_loader: setting__playerNo {setting__playerNo} is not supported, set it to -1 or omit it name:{empty(setting__className) ? setting__unit_class : setting__className}")

  
  if setting__unitType == "objectGroups"
    using() <| $(var blk : DataBlock)
      add(blk, "unit_class", setting__unit_class)
      datablock_add_block(blk, "props") <| $(prop)
        add(prop, "name", setting__name)
        add(prop, "army", setting__army)
        add(prop, "active", setting__active)
      create_object_group(setting__tm, blk)
    print("unit_loader: re-create into object group name:{setting__unit_class}")
    destroyEntity(eid)
    return

  
  
  
  
  
  
  
  
  
  
  let customTemplatePrefix = "template:"
  var templateName = ""
  let fullUnitName = empty(setting__className) ? setting__unit_class : setting__className
  if starts_with(setting__unitType, customTemplatePrefix)
    templateName = slice(setting__unitType, length(customTemplatePrefix))
  else
    var unitTypeHint = UnitType.UT_Unknown
    var isValidType = true
    if setting__unitType == "tank"
      unitTypeHint = UnitType.UT_HeavyVehicle
    elif setting__unitType == "ship"
      unitTypeHint = UnitType.UT_Ship
    elif setting__unitType == "lightVehicle"
      unitTypeHint = UnitType.UT_LightVehicle
    elif setting__unitType == "barrageBalloon"
      unitTypeHint = UnitType.UT_Balloon
    elif setting__unitType == "walker"
      unitTypeHint = UnitType.UT_WalkerVehicle
    elif setting__unitType == "infantry"
      unitTypeHint = UnitType.UT_InfTroop
    elif setting__unitType == "fortification"
      unitTypeHint = UnitType.UT_Fortification
    elif setting__unitType == "aircraft"
      unitTypeHint = UnitType.UT_Airplane
    elif setting__unitType == "human"
      unitTypeHint = UnitType.UT_Human
    elif setting__unitType != ""
      isValidType = false
    if isValidType
      templateName = resolve_unit_ecs_template_from_name(fullUnitName, unitTypeHint)

  if templateName == ""
    logerr("unit_loader: failed to resolve type:{setting__unitType} name:{fullUnitName} pos:{setting__tm[3]}")
    destroyEntity(eid)
    return

  if !empty(setting__unit_target_list)
    templateName += "+unit_target_list"

  print("unit_loader: re-create into template:{templateName}(type:{setting__unitType}) eid:{eid} name:{fullUnitName} pos:{setting__tm[3]}")
  addSubTemplate(eid, templateName) <| $(init)
    init |> set("transform", setting__tm)
    init |> set("unit__canChangeUnitInHangar", setting__canChangeUnit)
    
    
    
    init |> set("unit__verifyEcsTemplate", false)
    if !empty(setting__unit_target_list)
      init |> set("unit_target_list", setting__unit_target_list)
