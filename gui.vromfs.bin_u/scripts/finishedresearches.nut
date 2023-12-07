from "%scripts/dagui_library.nut" import *

let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let prepareUnitsForPurchaseMods = require("%scripts/weaponry/prepareUnitsForPurchaseMods.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { isInMenu, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")

::researched_items_table <- null
::abandoned_researched_items_for_session <- []
::researchedModForCheck <- "prevMod"
::researchedUnitForCheck <- "prevUnit"

registerPersistentData("finishedResearchesGlobals", getroottable(),
  ["researched_items_table", "abandoned_researched_items_for_session"])

let isResearchForModification = @(research)
  "name" in research && ::researchedModForCheck in research

let getUnitNameFromResearchItem = @(research)
  research?[isResearchForModification(research) ? "name" : "unit"] ?? ""

::gui_start_choose_next_research <- function gui_start_choose_next_research(researchBlock = null) {
  if (!isResearchForModification(researchBlock)) {
    ::gui_start_shop_research({ researchBlock = researchBlock })
    loadHandler(gui_handlers.researchUnitNotification, { researchBlock = researchBlock })
  }
  else {
    let unit = getAircraftByName(getUnitNameFromResearchItem(researchBlock))
    ::open_weapons_for_unit(unit, { researchMode = true, researchBlock = researchBlock })
  }
}

let function isResearchEqual(research1, research2) {
  foreach (key in ["name", ::researchedModForCheck, ::researchedUnitForCheck]) {
    let haveValue = key in research1
    if (haveValue != (key in research2))
      return false
    if (haveValue && research1[key] != research2[key])
      return false
  }
  return true
}

let function isResearchAbandoned(research) {
  foreach (_idx, abandoned in ::abandoned_researched_items_for_session)
    if (isResearchEqual(research, abandoned))
      return true
  return false
}

let function isResearchLast(research, checkUnit = false) {
  if (isResearchForModification(research))
    return getTblValue("mod", research, "") == ""
  else if (checkUnit)
    return getTblValue("unit", research, "") == ""
  return false
}

let function removeResearchBlock(researchBlock) {
  if (!researchBlock)
    return

  if (!isResearchAbandoned(researchBlock))
    ::abandoned_researched_items_for_session.append(researchBlock)

  foreach (idx, newResearch in ::researched_items_table)
    if (isResearchEqual(researchBlock, newResearch)) {
      ::researched_items_table.remove(idx)
      break
    }
}

::checkNonApprovedResearches <- function checkNonApprovedResearches(needUpdateResearchTable = false, needResearchAction = true) {
  if (!isInMenu() || ::checkIsInQueue())
    return false

  if (needUpdateResearchTable) {
    ::researched_items_table = ::shop_get_countries_list_with_autoset_units()
    ::researched_items_table.extend(::shop_get_units_list_with_autoset_modules())
  }

  if (!::researched_items_table || !::researched_items_table.len())
    return false

  for (local i = ::researched_items_table.len() - 1; i >= 0; --i) {
    if (isResearchAbandoned(::researched_items_table[i]) ||
      !getAircraftByName(getUnitNameFromResearchItem(::researched_items_table[i]))?.unitType.isAvailable()
    )
      removeResearchBlock(::researched_items_table[i])
  }

  if (!::researched_items_table.len())
    return false

  foreach (research in ::researched_items_table) {
    if (!isResearchLast(research))
      continue

    if (isResearchForModification(research)) {
      let unit = getAircraftByName(getUnitNameFromResearchItem(research))
      sendBqEvent("CLIENT_GAMEPLAY_1", "completed_new_research_modification",{ unit = unit.name
        modification = research.name })
      ::shop_set_researchable_unit_module(unit.name, "")
      prepareUnitsForPurchaseMods.addUnit(unit)
    }
    removeResearchBlock(research)
  }

  if (!::researched_items_table.len()) {
    if (prepareUnitsForPurchaseMods.haveUnits()) {
      if (needResearchAction)
        prepareUnitsForPurchaseMods.checkUnboughtMods(::get_auto_buy_modifications())
      return true
    }
    else
      return false
  }

  if (needResearchAction) {
    let resBlock = ::researched_items_table[0]
    if (isResearchForModification(resBlock)
      && isHandlerInScene(gui_handlers.WeaponsModalHandler))
      return true

    if (isHandlerInScene(gui_handlers.ShopCheckResearch))
      return true

    ::gui_start_choose_next_research(resBlock)
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
    placeObj.tooltipId = ::g_tooltip.getIdUnit(this.unit.name)
    fillUnitSlotTimers(placeObj.findObject(this.unit.name), this.unit)
  }

  function onEventCrewTakeUnit(_params) {
    this.goBack()
  }

  function onEventUnitBought(params) {
    if (getTblValue("unitName", params) != this.unit.name) {
      this.purchaseUnit()
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
    let isBought = ::isUnitBought(this.unit)
    let isUsable = ::isUnitUsable(this.unit)

    this.showSceneBtn("btn_buy", !isBought)
    this.showSceneBtn("btn_exit", isBought)
    this.showSceneBtn("btn_trainCrew", isUsable)
  }

  function purchaseUnit() {
    ::buyUnit(this.unit)
  }

  function trainCrew() {
    if (!::isUnitUsable(this.unit))
      return

    ::gui_start_selecting_crew({
      unit = this.unit
      unitObj = this.scene.findObject(this.unit.name)
      cellClass = "slotbarClone"
      isNewUnit = true
    })
  }
}
