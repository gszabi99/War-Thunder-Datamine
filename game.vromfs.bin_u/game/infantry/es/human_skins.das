require ecs
require ecs.safe
require app
require %game.unit.unit_events
require DagorSystem
require daslib.strings_boost
require DagorDataBlock
require Unit
require Mission

def find_key_in_initial_equip_by_slot(slot : string; equipList : Object)
  for equipKV in equipList
    let equipSlot = equipKV.value ?? ""
    if equipSlot == slot
      return equipKV.key
  return ""

def apply_armor_preset_skin(skinInfo : Object;
                            commonSkinPresetName, helmetProtectionTemplate, bodyProtectionTemplate : string;
                            var human_equipment__initialEquip : Object;
                            modeName : string; 
                            team : int;
                            skin : string;
                            tier, soldierIdx : int)
  if commonSkinPresetName != ""
    let commonSkinPreset = skinInfo |> get_ecs_object("commonSkinPreset")
    if commonSkinPreset == null
      logerr("No commonSkinPresets data for skin {skin} in {team} with tier {tier}, in infantry_equipment__teamSkins")
      return false

    let curPreset = *commonSkinPreset |> get_ecs_object(commonSkinPresetName)
    if curPreset == null
      logerr("No common skinPreset {commonSkinPresetName} for skin {skin} in {team} with tier {tier}, in infantry_equipment__teamSkins")
      return false
    for kv in *curPreset
      let slot = kv.key
      let gametempate = kv.value ?? ""
      let keyToErase := find_key_in_initial_equip_by_slot(slot, human_equipment__initialEquip)
      if keyToErase != ""
        human_equipment__initialEquip |> erase(keyToErase)
      if gametempate != ""
        human_equipment__initialEquip |> set(gametempate, slot)
          
          

  if helmetProtectionTemplate != ""
    let curHelmetTemplate := find_key_in_initial_equip_by_slot("helmet", human_equipment__initialEquip)
    if curHelmetTemplate != ""
      let templParts <- split(curHelmetTemplate, "+")
      human_equipment__initialEquip |> set(add_sub_template_name(templParts[0], helmetProtectionTemplate), "helmet")
      human_equipment__initialEquip |> erase(curHelmetTemplate)
    else
      logerr("No helmet for apply armor modification {modeName} for soldier with team {team} skin {skin} tier {tier} soldierIdx {soldierIdx} commonSkinPreset {commonSkinPresetName}")

  if bodyProtectionTemplate != ""
    let curBodyTemplate := find_key_in_initial_equip_by_slot("chest_armor", human_equipment__initialEquip)
    if curBodyTemplate != ""
      let templParts <- split(curBodyTemplate, "+") 
      human_equipment__initialEquip |> set(add_sub_template_name(templParts[0], bodyProtectionTemplate), "chest_armor")
      human_equipment__initialEquip |> erase(curBodyTemplate)
    else
      logerr("No chest_armor for apply armor modification {modeName} for soldier with team {team} skin {skin} tier {tier} soldierIdx {soldierIdx} commonSkinPreset {commonSkinPresetName}")
  return true

[es(tag=server, REQUIRE=(unit__ref, human), REQUIRE_NOT=shootingRangeDummy)]
def human_init_skins_preset_es(evt : CmdInitComponent;
                               team : int;
                               squad_member__memberIdx : int;
                               unit__ref : UnitRef;
                               var human_equipment__initialEquip : Object;
                               unit__overrideSkinRank : int const?)
  let missionTier = unit__overrideSkinRank == null ? get_mission_max_rank() : *unit__overrideSkinRank
  let skin = evt.data.humanSkin != "" ? string(evt.data.humanSkin) : "default"
  let soldierIdx = squad_member__memberIdx + 1

  find_query() <| $ [es] (infantry_equipment__teamSkins : Object)
    let teamInfo = infantry_equipment__teamSkins |> get_ecs_object("team_{team}")
    if teamInfo == null
      logerr("No data for team {team}, in infantry_equipment__teamSkins")
      return true

    var selectedTier = -1
    var minTier = -1
    for tierDataKV in *teamInfo
      let tierKey = tierDataKV.key
      let parts <- split(tierKey, "_")
      if length(parts) != 3
        logerr("incorrect tier data key {tierKey} must be looks like tier_1_squad")
        return true
      let iterTier = to_int(parts[1])
      if iterTier <= missionTier && iterTier > selectedTier
        selectedTier = iterTier
      if iterTier < minTier || minTier < 0
        minTier = iterTier

    if selectedTier < 0
      selectedTier = minTier

    if selectedTier < 0
      logerr("can't select correct skin tier for {missionTier} and team {team}")

    let tier = selectedTier
    let squadInfo = *teamInfo |> get_ecs_object("tier_{tier}_squad") 
    if squadInfo == null
      logerr("No data for squad in team {team} with tier {tier}, in infantry_equipment__teamSkins")
      return true

    let skinInfo = *squadInfo |> get_ecs_object(skin)
    if skinInfo == null
      logerr("No data for skin {skin} in {team} with tier {tier}, in infantry_equipment__teamSkins")
      return true
    let soldierEquipInfo = *skinInfo |> get_ecs_object("soldier_{soldierIdx}")
    if soldierEquipInfo == null
      logerr("No data for soldier {soldierIdx} in {skin} with team {team}, tier {tier}, in infantry_equipment__teamSkins")
      return true
    clear(human_equipment__initialEquip)
    for kv in *soldierEquipInfo
      let slot = kv.key
      if slot == "commonSkinPreset"
        continue
      let gametempate = kv.value ?? ""
      if gametempate != ""
        human_equipment__initialEquip |> set(gametempate, slot)

    if evt.modelBlk != null
      let unitCommonSkinPresetName = evt.modelBlk |> datablock_getStr("commonSkinPreset", "")
      if unitCommonSkinPresetName != ""
        let unitBodyProtectionTemplate = evt.modelBlk |> datablock_getStr("bodyProtectionTemplate", "")
        let unitHelmetProtectionTemplate = evt.modelBlk |> datablock_getStr("helmetProtectionTemplate", "")
        if !apply_armor_preset_skin(*soldierEquipInfo, unitCommonSkinPresetName, unitHelmetProtectionTemplate, unitBodyProtectionTemplate, human_equipment__initialEquip, "unitBlkMod", team, skin, tier, soldierIdx)
          return true

    
    let mods : DataBlock& = get_modifications_blk()
    let allMods = datablock_get_block_by_name(mods, "modifications")
    let modsNum = getModCount(*unit__ref.unit.unitMod)
    for i in range(0, modsNum)
      let modeName = getModName(*unit__ref.unit.unitMod, i)
      let modeBlock = datablock_get_block_by_name(*allMods, modeName)
      if modeBlock != null
        let modClass = *modeBlock |> datablock_getStr("modClass", "")
        if modClass != "equipment_common"
          continue;
        let effectsBlk = *modeBlock |> datablock_get_block_by_name("effects")
        if effectsBlk != null
          let helmetProtectionTemplate = effectsBlk |> datablock_getStr("helmetProtectionTemplate", "")
          let bodyProtectionTemplate = effectsBlk |> datablock_getStr("bodyProtectionTemplate", "")
          let commonSkinPresetName = effectsBlk |> datablock_getStr("commonSkinPreset", "")
          if !apply_armor_preset_skin(*soldierEquipInfo, commonSkinPresetName, helmetProtectionTemplate, bodyProtectionTemplate, human_equipment__initialEquip, modeName, team, skin, tier, soldierIdx)
            return true
    return true
