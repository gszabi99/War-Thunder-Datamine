from "%scripts/dagui_natives.nut" import wp_get_modification_cost_gold, shop_get_module_research_status, wp_get_modification_cost, get_modifications_overdrive
from "%scripts/dagui_library.nut" import *
let { get_modifications_blk } = require("blkGetters")
let { AMMO, getAmmoAmount, getAmmoMaxAmount } = require("%scripts/weaponry/ammoInfo.nut")
let { shopIsModificationAvailable, shopIsModificationPurchased, shopIsModificationEnabled
} = require("chardResearch")
let { get_gui_option } = require("guiOptions")
let { get_game_mode } = require("mission")
let { USEROPT_MODIFICATIONS } = require("%scripts/options/optionsExtNames.nut")

let isReqModificationsUnlocked = @(unit, mod) mod?.reqModification.findvalue(
  @(req) !shopIsModificationPurchased(unit.name, req)) == null

function canBuyMod(unit, mod) {
  if (!isReqModificationsUnlocked(unit, mod))
    return false

  let status = shop_get_module_research_status(unit.name, mod.name)
  if (status & ES_ITEM_STATUS_CAN_BUY)
    return true

  if (status & (ES_ITEM_STATUS_MOUNTED | ES_ITEM_STATUS_OWNED)) {
    let amount = getAmmoAmount(unit, mod.name, AMMO.MODIFICATION)
    let maxAmount = getAmmoMaxAmount(unit, mod.name, AMMO.MODIFICATION)
    return amount < maxAmount
  }

  return false
}

function isModResearched(unit, mod) {
  let status = shop_get_module_research_status(unit.name, mod.name)
  if (status & (ES_ITEM_STATUS_CAN_BUY | ES_ITEM_STATUS_OWNED | ES_ITEM_STATUS_MOUNTED | ES_ITEM_STATUS_RESEARCHED))
    return true

  return false
}

let isModClassPremium = @(moduleData) (moduleData?.modClass ?? "") == "premium"
let isModClassExpendable = @(moduleData) (moduleData?.modClass ?? "") == "expendable"

function canResearchMod(unit, mod, checkCurrent = false) {
  let status = shop_get_module_research_status(unit.name, mod.name)
  let canResearch = checkCurrent ? status == ES_ITEM_STATUS_CAN_RESEARCH :
                        0 != (status & (ES_ITEM_STATUS_CAN_RESEARCH | ES_ITEM_STATUS_IN_RESEARCH))

  return canResearch
}

function findAnyNotResearchedMod(unit) {
  if (!("modifications" in unit))
    return null

  foreach (mod in unit.modifications)
    if (canResearchMod(unit, mod) && !isModResearched(unit, mod))
      return mod

  return null
}

function isModMounted(unitName, modName) {
  let status = shop_get_module_research_status(unitName, modName)
  return (status & ES_ITEM_STATUS_MOUNTED) != 0
}

function isModAvailableOrFree(unitName, modName) {
  return (shopIsModificationAvailable(unitName, modName, true)
          || (!wp_get_modification_cost(unitName, modName) && !wp_get_modification_cost_gold(unitName, modName)))
}

function isModPurchasedOrFree(unitName, modName) {
  return (shopIsModificationPurchased(unitName, modName)
          || (!wp_get_modification_cost(unitName, modName) && !wp_get_modification_cost_gold(unitName, modName)))
}

function isWeaponModsPurchasedOrFree(unitName, weapon) {
  let reqModifications = weapon % "reqModification"
  if (reqModifications.len() == 0)
    return true

  local allModsPurchased = true
  foreach (modification in reqModifications) {
    allModsPurchased = allModsPurchased && isModPurchasedOrFree(unitName, modification)
  }
  return allModsPurchased
}

function getModBlock(modName, blockName, templateKey) {
  let modsBlk = get_modifications_blk()
  let modBlock = modsBlk?.modifications?[modName]
  if (!modBlock || modBlock?[blockName])
    return modBlock?[blockName]
  let tName = modBlock?[templateKey]
  return tName ? modsBlk?.templates?[tName]?[blockName] : null
}

let isModUpgradeable = @(modName) getModBlock(modName, "upgradeEffect", "modUpgradeType")
let hasActiveOverdrive = @(unitName, modName) get_modifications_overdrive(unitName).len() > 0
  && getModBlock(modName, "overdriveEffect", "modOverdriveType")

function getModificationByName(unit, modName) {
  if (!("modifications" in unit))
    return null

  foreach (_i, modif in unit.modifications)
    if (modif.name == modName)
      return modif

  return null
}

function getModificationBulletsGroup(modifName) {
  let blk = get_modifications_blk()
  let modification = blk?.modifications?[modifName]
  if (modification) {
    if (!modification?.group)
      return "" 
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

function updateRelationModificationList(unit, modifName) {
  let mod = getModificationByName(unit, modifName)
  if (mod && !("relationModification" in mod)) {
    let blk = get_modifications_blk();
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

function isModificationEnabled(unitName, modName) {
  if (shopIsModificationEnabled(unitName, modName))
    return true

  let gm = get_game_mode()
  return (gm == GM_TEST_FLIGHT || gm == GM_BUILDER) && !get_gui_option(USEROPT_MODIFICATIONS)
}

return {
  canBuyMod
  isModMounted
  isModResearched
  isModClassPremium
  isModClassExpendable
  canResearchMod
  findAnyNotResearchedMod
  isModAvailableOrFree
  isModificationEnabled
  isWeaponModsPurchasedOrFree
  isModUpgradeable
  hasActiveOverdrive
  getModificationByName
  getModificationBulletsGroup
  isReqModificationsUnlocked
  updateRelationModificationList
}