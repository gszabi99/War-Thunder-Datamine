//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { AMMO,
        getAmmoAmount,
        getAmmoMaxAmount } = require("%scripts/weaponry/ammoInfo.nut")

let isReqModificationsUnlocked = @(unit, mod) mod?.reqModification.findvalue(
  @(req) !::shop_is_modification_purchased(unit.name, req)) == null

let function canBuyMod(unit, mod) {
  if (!isReqModificationsUnlocked(unit, mod))
    return false

  let status = ::shop_get_module_research_status(unit.name, mod.name)
  if (status & ES_ITEM_STATUS_CAN_BUY)
    return true

  if (status & (ES_ITEM_STATUS_MOUNTED | ES_ITEM_STATUS_OWNED)) {
    let amount = getAmmoAmount(unit, mod.name, AMMO.MODIFICATION)
    let maxAmount = getAmmoMaxAmount(unit, mod.name, AMMO.MODIFICATION)
    return amount < maxAmount
  }

  return false
}

let function isModResearched(unit, mod) {
  let status = ::shop_get_module_research_status(unit.name, mod.name)
  if (status & (ES_ITEM_STATUS_CAN_BUY | ES_ITEM_STATUS_OWNED | ES_ITEM_STATUS_MOUNTED | ES_ITEM_STATUS_RESEARCHED))
    return true

  return false
}

let isModClassPremium = @(moduleData) (moduleData?.modClass ?? "") == "premium"
let isModClassExpendable = @(moduleData) (moduleData?.modClass ?? "") == "expendable"

let function canResearchMod(unit, mod, checkCurrent = false) {
  let status = ::shop_get_module_research_status(unit.name, mod.name)
  let canResearch = checkCurrent ? status == ES_ITEM_STATUS_CAN_RESEARCH :
                        0 != (status & (ES_ITEM_STATUS_CAN_RESEARCH | ES_ITEM_STATUS_IN_RESEARCH))

  return canResearch
}

let function findAnyNotResearchedMod(unit) {
  if (!("modifications" in unit))
    return null

  foreach (mod in unit.modifications)
    if (canResearchMod(unit, mod) && !isModResearched(unit, mod))
      return mod

  return null
}

let function isModMounted(unitName, modName) {
  let status = ::shop_get_module_research_status(unitName, modName)
  return (status & ES_ITEM_STATUS_MOUNTED) != 0
}

let function isModAvailableOrFree(unitName, modName) {
  return (::shop_is_modification_available(unitName, modName, true)
          || (!::wp_get_modification_cost(unitName, modName) && !::wp_get_modification_cost_gold(unitName, modName)))
}

let function getModBlock(modName, blockName, templateKey) {
  let modsBlk = ::get_modifications_blk()
  let modBlock = modsBlk?.modifications?[modName]
  if (!modBlock || modBlock?[blockName])
    return modBlock?[blockName]
  let tName = modBlock?[templateKey]
  return tName ? modsBlk?.templates?[tName]?[blockName] : null
}

let isModUpgradeable = @(modName) getModBlock(modName, "upgradeEffect", "modUpgradeType")
let hasActiveOverdrive = @(unitName, modName) ::get_modifications_overdrive(unitName).len() > 0
  && getModBlock(modName, "overdriveEffect", "modOverdriveType")

let function getModificationByName(unit, modName) {
  if (!("modifications" in unit))
    return null

  foreach (_i, modif in unit.modifications)
    if (modif.name == modName)
      return modif

  return null
}

let function getModificationBulletsGroup(modifName) {
  let blk = ::get_modifications_blk()
  let modification = blk?.modifications?[modifName]
  if (modification) {
    if (!modification?.group)
      return "" //new_gun etc. - not a bullets list
    if (modification?.effects)
      for (local i = 0; i < modification.effects.paramCount(); i++) {
        let effectType = modification.effects.getParamName(i)
        if (effectType == "additiveBulletMod") {
          let underscore = modification.group.indexof("_")
          if (underscore)
            return modification.group.slice(0, underscore)
        }
        if (effectType == "bulletMod" || effectType == "additiveBulletMod")
          return modification.group
      }
  }
  else if (modifName.len() > 8 && modifName.slice(modifName.len() - 8) == "_default")
    return modifName.slice(0, modifName.len() - 8)

  return ""
}

let function updateRelationModificationList(unit, modifName) {
  let mod = getModificationByName(unit, modifName)
  if (mod && !("relationModification" in mod)) {
    let blk = ::get_modifications_blk();
    mod.relationModification <- [];
    foreach (_ind, m in unit.modifications) {
      if ("reqModification" in m && isInArray(modifName, m.reqModification)) {
        let modification = blk?.modifications?[m.name]
        if (modification?.effects)
          for (local i = 0; i < modification.effects.paramCount(); i++)
            if (modification.effects.getParamName(i) == "additiveBulletMod") {
              mod.relationModification.append(m.name)
              break
            }
      }
    }
  }
}

::cross_call_api.getModificationByName <- @(unitName, modName)
  getModificationByName(getAircraftByName(unitName), modName)

return {
  canBuyMod
  isModMounted
  isModResearched
  isModClassPremium
  isModClassExpendable
  canResearchMod
  findAnyNotResearchedMod
  isModAvailableOrFree
  isModUpgradeable
  hasActiveOverdrive
  getModificationByName
  getModificationBulletsGroup
  isReqModificationsUnlocked
  updateRelationModificationList
}