local prepareUnitsForPurchaseMods = require("scripts/weaponry/prepareUnitsForPurchaseMods.nut")

::researched_items_table <- null
::abandoned_researched_items_for_session <- []
::researchedModForCheck <- "prevMod"
::researchedUnitForCheck <- "prevUnit"

::g_script_reloader.registerPersistentData("finishedResearchesGlobals", ::getroottable(),
  ["researched_items_table", "abandoned_researched_items_for_session"])

local isResearchForModification = @(research)
  "name" in research && ::researchedModForCheck in research

local getUnitNameFromResearchItem = @(research)
  research?[isResearchForModification(research)? "name" : "unit"] ?? ""

::gui_start_choose_next_research <- function gui_start_choose_next_research(researchBlock = null)
{
  if (!isResearchForModification(researchBlock))
  {
    ::gui_start_shop_research({researchBlock = researchBlock})
    ::gui_start_modal_wnd(::gui_handlers.researchUnitNotification, {researchBlock = researchBlock})
  }
  else
  {
    local unit = ::getAircraftByName(getUnitNameFromResearchItem(researchBlock))
    ::open_weapons_for_unit(unit, { researchMode = true, researchBlock = researchBlock })
  }
}

local function isResearchEqual(research1, research2)
{
  foreach(key in ["name", ::researchedModForCheck, ::researchedUnitForCheck])
  {
    local haveValue = key in research1
    if (haveValue != (key in research2))
      return false
    if (haveValue && research1[key] != research2[key])
      return false
  }
  return true
}

local function isResearchAbandoned(research)
{
  foreach(idx, abandoned in ::abandoned_researched_items_for_session)
    if (isResearchEqual(research, abandoned))
      return true
  return false
}

local function isResearchLast(research, checkUnit = false)
{
  if (isResearchForModification(research))
    return ::getTblValue("mod", research, "") == ""
  else if (checkUnit)
    return ::getTblValue("unit", research, "") == ""
  return false
}

local function removeResearchBlock(researchBlock)
{
  if (!researchBlock)
    return

  if (!isResearchAbandoned(researchBlock))
    ::abandoned_researched_items_for_session.append(researchBlock)

  foreach(idx, newResearch in ::researched_items_table)
    if (isResearchEqual(researchBlock, newResearch))
    {
      ::researched_items_table.remove(idx)
      break
    }
}

::checkNonApprovedResearches <- function checkNonApprovedResearches(needUpdateResearchTable = false, needResearchAction = true)
{
  if (!::isInMenu() || ::checkIsInQueue())
    return false

  if (needUpdateResearchTable)
  {
    ::researched_items_table = ::shop_get_countries_list_with_autoset_units()
    ::researched_items_table.extend(::shop_get_units_list_with_autoset_modules())
  }

  if (!::researched_items_table || !::researched_items_table.len())
    return false

  for (local i = ::researched_items_table.len()-1; i >= 0; --i)
  {
    if (isResearchAbandoned(::researched_items_table[i]) ||
      !::getAircraftByName(getUnitNameFromResearchItem(::researched_items_table[i]))?.unitType.isAvailable()
    )
      removeResearchBlock(::researched_items_table[i])
  }

  if (!::researched_items_table.len())
    return false

  foreach (research in ::researched_items_table)
  {
    if (!isResearchLast(research))
      continue

    if (isResearchForModification(research))
    {
      local unit = ::getAircraftByName(getUnitNameFromResearchItem(research))
      ::add_big_query_record("completed_new_research_modification",
        ::save_to_json({ unit = unit.name
          modification = research.name }))
      ::shop_set_researchable_unit_module(unit.name, "")
      prepareUnitsForPurchaseMods.addUnit(unit)
    }
    removeResearchBlock(research)
  }

  if (!::researched_items_table.len())
  {
    if (prepareUnitsForPurchaseMods.haveUnits())
    {
      if (needResearchAction)
        prepareUnitsForPurchaseMods.checkUnboughtMods(::get_auto_buy_modifications())
      return true
    }
    else
      return false
  }

  if (needResearchAction)
  {
    local resBlock = ::researched_items_table[0]
    if (isResearchForModification(resBlock)
      && ::isHandlerInScene(::gui_handlers.WeaponsModalHandler))
      return true

    if (::isHandlerInScene(::gui_handlers.ShopCheckResearch))
      return true

    ::gui_start_choose_next_research(resBlock)
    removeResearchBlock(resBlock)
  }

  return true
}

class ::gui_handlers.researchUnitNotification extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/researchedModifications.blk"

  researchBlock = null
  unit = null

  function initScreen()
  {
    if (!researchBlock)
    {
      goBack()
      return
    }

    local unitName = ::getTblValue(::researchedUnitForCheck, researchBlock)
    unit = ::getAircraftByName(unitName)
    if (!unit)
    {
      goBack()
      return
    }

    updateResearchedUnit()
    updateButtons()
  }

  function updateResearchedUnit()
  {
    local placeObj = getUnitPlaceObj()
    if (!::checkObj(placeObj))
      return

    local unit_blk = ::build_aircraft_item(unit.name, unit)
    guiScene.replaceContentFromText(placeObj, unit_blk, unit_blk.len(), this)
    placeObj.tooltipId = ::g_tooltip.getIdUnit(unit.name)
    ::fill_unit_item_timers(placeObj.findObject(unit.name), unit)
  }

  function onEventCrewTakeUnit(params)
  {
    goBack()
  }

  function onEventUnitBought(params)
  {
    if(::getTblValue("unitName", params) != unit.name)
    {
      purchaseUnit()
      return
    }

    updateResearchedUnit()
    updateButtons()
    trainCrew()
  }

  function getUnitPlaceObj()
  {
    if (!::checkObj(scene))
      return null

    return scene.findObject("rankup_aircraft_table")
  }

  function updateButtons()
  {
    ::show_facebook_screenshot_button(scene)

    local isBought = ::isUnitBought(unit)
    local isUsable = ::isUnitUsable(unit)

    showSceneBtn("btn_buy", !isBought)
    showSceneBtn("btn_exit", isBought)
    showSceneBtn("btn_trainCrew", isUsable)
  }

  function purchaseUnit()
  {
    ::buyUnit(unit)
  }

  function trainCrew()
  {
    if (!::isUnitUsable(unit))
      return

    ::gui_start_selecting_crew({
      unit = unit
      unitObj = scene.findObject(unit.name)
      cellClass = "slotbarClone"
      isNewUnit = true
    })
  }
}
