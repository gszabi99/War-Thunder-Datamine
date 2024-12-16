from "%scripts/dagui_natives.nut" import shop_set_researchable_unit_module, shop_get_units_list_with_autoset_modules, get_auto_buy_modifications, shop_get_countries_list_with_autoset_units
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let prepareUnitsForPurchaseMods = require("%scripts/weaponry/prepareUnitsForPurchaseMods.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { isInMenu, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let guiStartSelectingCrew = require("%scripts/slotbar/guiStartSelectingCrew.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { register_command } = require("console")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")
let { buyUnit } = require("%scripts/unit/unitActions.nut")

let researched_items_table = persist("researched_items_table", @() [])
let abandoned_researched_items_for_session = persist("abandoned_researched_items_for_session", @() [])
::researchedModForCheck <- "prevMod"
::researchedUnitForCheck <- "prevUnit"

eventbus_subscribe("on_sign_out", @(...) abandoned_researched_items_for_session.clear())

let isResearchForModification = @(research)
  "name" in research && ::researchedModForCheck in research

let getUnitNameFromResearchItem = @(research)
  research?[isResearchForModification(research) ? "name" : "unit"] ?? ""

function guiStartChooseNextResearch(researchBlock = null) {
  if (!isResearchForModification(researchBlock)) {
    loadHandler(gui_handlers.ShopCheckResearch, { researchBlock = researchBlock })
    loadHandler(gui_handlers.researchUnitNotification, { researchBlock = researchBlock })
  }
  else {
    let unit = getAircraftByName(getUnitNameFromResearchItem(researchBlock))
    ::open_weapons_for_unit(unit, { researchMode = true, researchBlock = researchBlock })
  }
}

function isResearchEqual(research1, research2) {
  foreach (key in ["name", ::researchedModForCheck, ::researchedUnitForCheck]) {
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
::abandoned_researched_items_for_session <- abandoned_researched_items_for_session //used only for debug dump

::checkNonApprovedResearches <- function checkNonApprovedResearches(needUpdateResearchTable = false, needResearchAction = true) {
  if (!isInMenu() || ::checkIsInQueue())
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

gui_handlers.researchUnitNotification <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/researchedModifications.blk"

  researchBlock = null
  unit = null

  function initScreen() {
    if (!this.researchBlock) {
      this.goBack()
      return
    }

    let unitName = getTblValue(::researchedUnitForCheck, this.researchBlock)
    this.unit = getAircraftByName(unitName)
    if (!this.unit) {
      this.goBack()
      return
    }

    this.updateResearchedUnit()
    this.updateButtons()
  }

  function updateResearchedUnit() {
    let placeObj = this.getUnitPlaceObj()
    if (!checkObj(placeObj))
      return

    let unit_blk = buildUnitSlot(this.unit.name, this.unit)
    this.guiScene.replaceContentFromText(placeObj, unit_blk, unit_blk.len(), this)
    placeObj.tooltipId = getTooltipType("UNIT").getTooltipId(this.unit.name)
    fillUnitSlotTimers(placeObj.findObject(this.unit.name), this.unit)
  }

  function onEventCrewTakeUnit(_params) {
    this.goBack()
  }

  function onEventUnitBought(params) {
    let { unitName = null, needSelectCrew = false } = params
    if (unitName != this.unit.name) {
      this.purchaseUnit()
      return
    }

    if (!needSelectCrew) {
      this.goBack()
      return
    }

    this.updateResearchedUnit()
    this.updateButtons()
    this.trainCrew()
  }

  function getUnitPlaceObj() {
    if (!checkObj(this.scene))
      return null

    return this.scene.findObject("rankup_aircraft_table")
  }

  function updateButtons() {
    let isBought = isUnitBought(this.unit)
    let isUsable = isUnitUsable(this.unit)

    showObjById("btn_buy", !isBought, this.scene)
    showObjById("btn_exit", isBought, this.scene)
    showObjById("btn_trainCrew", isUsable, this.scene)
  }

  function purchaseUnit() {
    buyUnit(this.unit)
  }

  function trainCrew() {
    if (!isUnitUsable(this.unit))
      return

    guiStartSelectingCrew({
      unit = this.unit
      unitObj = this.scene.findObject(this.unit.name)
      cellClass = "slotbarClone"
      isNewUnit = true
    })
  }
}

register_command(
  @() guiStartChooseNextResearch({
    prevUnit = "v_156_b1", country = "country_britain"}),
  "showUnitFinishedResearchWnd")

register_command(
  @() guiStartChooseNextResearch({
    name = "v_156_b1", prevMod = "new_radiator"}),
  "showModificationFinishedResearchWnd")