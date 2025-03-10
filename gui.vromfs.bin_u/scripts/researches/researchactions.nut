from "%scripts/dagui_natives.nut" import shop_set_researchable_unit_module, shop_get_units_list_with_autoset_modules, get_auto_buy_modifications, shop_get_countries_list_with_autoset_units
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let prepareUnitsForPurchaseMods = require("%scripts/weaponry/prepareUnitsForPurchaseMods.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { isInMenu, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { register_command } = require("console")
let { open_weapons_for_unit } = require("%scripts/weaponry/weaponryActions.nut")
let { checkIsInQueue } = require("%scripts/queue/queueManager.nut")

let { RESEARCHED_MODE_FOR_CHECK, RESEARCHED_UNIT_FOR_CHECK } = require ("%scripts/researches/researchConsts.nut")

let researched_items_table = persist("researched_items_table", @() [])
let abandoned_researched_items_for_session = persist("abandoned_researched_items_for_session", @() [])

eventbus_subscribe("on_sign_out", @(...) abandoned_researched_items_for_session.clear())

let isResearchForModification = @(research)
  "name" in research && RESEARCHED_MODE_FOR_CHECK in research

let getUnitNameFromResearchItem = @(research)
  research?[isResearchForModification(research) ? "name" : "unit"] ?? ""

function guiStartChooseNextResearch(researchBlock = null) {
  if (!isResearchForModification(researchBlock)) {
    loadHandler(gui_handlers.ShopCheckResearch, { researchBlock = researchBlock })
    loadHandler(gui_handlers.researchUnitNotification, { researchBlock = researchBlock })
  }
  else {
    let unit = getAircraftByName(getUnitNameFromResearchItem(researchBlock))
    open_weapons_for_unit(unit, { researchMode = true, researchBlock = researchBlock })
  }
}

function isResearchEqual(research1, research2) {
  foreach (key in ["name", RESEARCHED_MODE_FOR_CHECK, RESEARCHED_UNIT_FOR_CHECK]) {
    let haveValue = key in research1
    if (haveValue != (key in research2))
      return false
    if (haveValue && research1[key] != research2[key])
      return false
  }
  return true
}

function isResearchAbandoned(research) {
  foreach (_idx, abandoned in abandoned_researched_items_for_session)
    if (isResearchEqual(research, abandoned))
      return true
  return false
}

function isResearchLast(research, checkUnit = false) {
  if (isResearchForModification(research))
    return getTblValue("mod", research, "") == ""
  else if (checkUnit)
    return getTblValue("unit", research, "") == ""
  return false
}

function removeResearchBlock(researchBlock) {
  if (!researchBlock)
    return

  if (!isResearchAbandoned(researchBlock))
    abandoned_researched_items_for_session.append(researchBlock)

  foreach (idx, newResearch in researched_items_table)
    if (isResearchEqual(researchBlock, newResearch)) {
      researched_items_table.remove(idx)
      break
    }
}

::abandoned_researched_items_for_session <- abandoned_researched_items_for_session 

function checkNonApprovedResearches(needUpdateResearchTable = false, needResearchAction = true) {
  if (!isInMenu() || checkIsInQueue())
    return false

  if (needUpdateResearchTable) {
    researched_items_table.replace(shop_get_countries_list_with_autoset_units())
    researched_items_table.extend(shop_get_units_list_with_autoset_modules())
  }

  if (!researched_items_table?.len())
    return false

  for (local i = researched_items_table.len() - 1; i >= 0; --i) {
    if (isResearchAbandoned(researched_items_table[i]) ||
      !getAircraftByName(getUnitNameFromResearchItem(researched_items_table[i]))?.unitType.isAvailable()
    )
      removeResearchBlock(researched_items_table[i])
  }

  if (!researched_items_table.len())
    return false

  foreach (research in researched_items_table) {
    if (!isResearchLast(research))
      continue

    if (isResearchForModification(research)) {
      let unit = getAircraftByName(getUnitNameFromResearchItem(research))
      sendBqEvent("CLIENT_GAMEPLAY_1", "completed_new_research_modification",{ unit = unit.name
        modification = research.name })
      shop_set_researchable_unit_module(unit.name, "")
      prepareUnitsForPurchaseMods.addUnit(unit)
    }
    removeResearchBlock(research)
  }

  if (!researched_items_table.len()) {
    if (prepareUnitsForPurchaseMods.haveUnits()) {
      if (needResearchAction)
        prepareUnitsForPurchaseMods.checkUnboughtMods(get_auto_buy_modifications())
      return true
    }
    else
      return false
  }

  if (needResearchAction) {
    let resBlock = researched_items_table[0]
    if (isResearchForModification(resBlock)
      && isHandlerInScene(gui_handlers.WeaponsModalHandler))
      return true

    if (isHandlerInScene(gui_handlers.ShopCheckResearch))
      return true

    guiStartChooseNextResearch(resBlock)
    removeResearchBlock(resBlock)
  }

  return true
}

register_command(
  @() guiStartChooseNextResearch({
    prevUnit = "v_156_b1", country = "country_britain"}),
  "showUnitFinishedResearchWnd")

register_command(
  @() guiStartChooseNextResearch({
    name = "v_156_b1", prevMod = "new_radiator"}),
  "showModificationFinishedResearchWnd")

return {
  checkNonApprovedResearches
}