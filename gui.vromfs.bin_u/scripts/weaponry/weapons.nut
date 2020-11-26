local modsTree = require("scripts/weaponry/modsTree.nut")
local tutorialModule = require("scripts/user/newbieTutorialDisplay.nut")
local weaponryPresetsModal = require("scripts/weaponry/weaponryPresetsModal.nut")
local prepareUnitsForPurchaseMods = require("scripts/weaponry/prepareUnitsForPurchaseMods.nut")
local { canBuyMod,
        canResearchMod,
        isModResearched,
        isModUpgradeable,
        isModClassPremium,
        isModClassExpendable,
        getModificationByName,
        findAnyNotResearchedMod } = require("scripts/weaponry/modificationInfo.nut")
local { isUnitHaveSecondaryWeapons } = require("scripts/unit/unitStatus.nut")
local { getItemAmount,
        getItemCost,
        getAllModsCost,
        canBeResearched,
        getByCurBundle,
        getItemStatusTbl,
        isCanBeDisabled,
        isModInResearch,
        getBundleCurItem,
        canResearchItem } = require("scripts/weaponry/itemInfo.nut")
local { updateModItem,
        createModItem,
        getModItemName,
        getReqModsText,
        createModBundle,
        updateWeaponTooltip,
        getBulletsListHeader } = require("scripts/weaponry/weaponryVisual.nut")
local { isBullets,
        getBulletsList,
        setUnitLastBullets,
        getBulletGroupIndex,
        getBulletsItemsList,
        getModificationName,
        isWeaponTierAvailable,
        getLastFakeBulletsIndex,
        isBulletsGroupActiveByMod,
        getModificationBulletsGroup } = require("scripts/weaponry/bulletsInfo.nut")
local { AMMO, getAmmoCost } = require("scripts/weaponry/ammoInfo.nut")
local { WEAPON_TAG,
        getLastWeapon,
        setLastWeapon,
        getLastPrimaryWeapon,
        getPrimaryWeaponsList,
        getSecondaryWeaponsList,
        isUnitHaveAnyWeaponsTags } = require("scripts/weaponry/weaponryInfo.nut")
local tutorAction = require("scripts/tutorials/tutorialActions.nut")
local { setDoubleTextToButton, setColoredDoubleTextToButton,
  placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

local timerPID = ::dagui_propid.add_name_id("_size-timer")
::header_len_per_cell <- 17
::tooltip_display_delay <- 2
::max_spare_amount <- 100

::enable_modification <- function enable_modification(unitName, modificationName, enable)
{
  if (modificationName == "")
    return;

  local db = ::DataBlock()
  db[unitName] <- ::DataBlock()
  db[unitName][modificationName] <- enable
  return ::shop_enable_modifications(db)
}

::enable_current_modifications <- function enable_current_modifications(unitName)
{
  local db = ::DataBlock()
  db[unitName] <- ::DataBlock()

  local air = getAircraftByName(unitName)
  foreach(mod in air.modifications)
    db[unitName][mod.name] <- ::shop_is_modification_enabled(unitName, mod.name)

  return ::shop_enable_modifications(db)
}

::open_weapons_for_unit <- function open_weapons_for_unit(unit, params = {})
{
  if (!("name" in unit))
    return
  ::aircraft_for_weapons = unit.name
  ::handlersManager.loadHandler(::gui_handlers.WeaponsModalHandler, params)
}

local needSecondaryWeaponsWindow = @(unit) (unit.isAir() || unit.isHelicopter()) && ::has_feature("ShowWeapPresetsMenu")

class ::gui_handlers.WeaponsModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  items = null

  wndWidth = 6
  mainModsObj = null
  modsBgObj = null
  curBundleTblObj = null

  air = null
  airName = ""
  lastWeapon = ""
  lastBullets = null

  researchMode = false
  researchBlock = null
  availableFlushExp = 0
  lastResearchMod = null
  setResearchManually = false

  airActions = ["research", "buy"]
  isOwn = true
  guiScene = null
  scene = null
  wndType = handlerType.MODAL
  sceneBlkName = "gui/weaponry/weapons.blk"
  tierIdPrefix = "tierLine_"

  tooltipOpenTime = -1

  shownTiers = []

  needCheckTutorial = false
  curEdiff = null
  purchasedModifications = null
  needHideSlotbar = false

  function initScreen()
  {
    setResearchManually = !researchMode
    mainModsObj = scene.findObject("main_modifications")

    showSceneBtn("weaponry_close_btn", !researchMode)

    local imageBlock = scene.findObject("researchMode_image_block")
    if (::checkObj(imageBlock))
      imageBlock.show(researchMode)

    setDoubleTextToButton(scene, "btn_spendExcessExp",
        ::getRpPriceText(::loc("mainmenu/spendExcessExp") + " ", false),
        ::getRpPriceText(::loc("mainmenu/spendExcessExp") + " ", true))

    airName = ::aircraft_for_weapons
    air = getAircraftByName(airName)
    initMainParams()

    initSlotbar()

    if (researchMode)
      sendModResearchedStatistic(air, researchBlock?[::researchedModForCheck] ?? "")

    selectResearchModule()
    checkOnResearchCurMod()
    showNewbieResearchHelp()
  }

  function initSlotbar()
  {
    if (researchMode || !::isUnitInSlotbar(air) || needHideSlotbar)
      return
    createSlotbar({
      crewId = getCrewByAir(air).id
      showNewSlot=false
      emptyText="#shop/aircraftNotSelected"
      afterSlotbarSelect = onSlotbarSelect
    })
  }

  function initMainParams()
  {
    if (!air)
    {
      goBack()
      return
    }
    curEdiff = curEdiff == null ? -1 : curEdiff
    isOwn = air.isUsable()
    purchasedModifications = []

    local data = "tdiv { id:t='bg_elems'; position:t='absolute'; inactive:t='yes' }"
    mainModsObj.setValue(-1)
    guiScene.replaceContentFromText(mainModsObj, data, data.len(), this)
    modsBgObj = mainModsObj.findObject("bg_elems")

    items = []
    fillPage()

    if (::isUnitInSlotbar(air) && !::check_aircraft_tags(air.tags, ["bomberview"]))
      if (!canBomb(true) && canBomb(false))
        needCheckTutorial = true

    shownTiers = []

    updateWindowTitle()
  }

  function onSlotbarSelect()
  {
    local newCrew = getCurCrew()
    local newUnit = newCrew ? ::g_crew.getCrewUnit(newCrew) : null
    if (!newUnit || newUnit == air)
      return

    sendModPurchasedStatistic(air)
    if (getAutoPurchaseValue())
      onBuyAll(false, true)

    air = newUnit
    airName = air?.name ?? ""
    ::aircraft_for_weapons = airName

    initMainParams()
  }

  function checkOnResearchCurMod()
  {
    if (researchMode && !isAnyModuleInResearch())
    {
      local modForResearch = findAnyNotResearchedMod(air)
      if (modForResearch)
      {
        setModificatonOnResearch(modForResearch,
          (@(modForResearch) function() {
            updateAllItems()
            local guiPosIdx = ::getTblValue("guiPosIdx", modForResearch, -1)
            ::dagor.assertf(guiPosIdx >= 0, "missing guiPosIdx, mod - " + ::getTblValue("name", modForResearch, "none") + "; unit - " + air.name)
            selectResearchModule(guiPosIdx >= 0? guiPosIdx : 0)
          })(modForResearch))
      }
    }
  }

  function selectResearchModule(customPosIdx = -1)
  {
    local modIdx = customPosIdx
    if (modIdx < 0)
    {
      local finishedResearch = ::getTblValue(::researchedModForCheck, researchBlock, "")
      foreach(item in items)
        if (isModInResearch(air, item))
        {
          modIdx = item.guiPosIdx
          break
        }
        else if (item.name == finishedResearch)
          modIdx = item.guiPosIdx
    }

    if (::checkObj(mainModsObj) && modIdx >= 0)
      mainModsObj.setValue(modIdx+1)
  }

  function updateWindowTitle()
  {
    local titleObj = scene.findObject("wnd_title")
    if (!::checkObj(titleObj))
      return

    local titleText = ::loc("mainmenu/btnWeapons") + " " + ::loc("ui/mdash") + " " + ::getUnitName(air)
    if (researchMode)
      titleText = ::loc("modifications/finishResearch",
          {modName = getModificationName(air, ::getTblValue(::researchedModForCheck, researchBlock, "CdMin_Fuse"))})
    titleObj.setValue(titleText)
  }

  function updateWindowHeightAndPos()
  {
    local frameObj = scene.findObject("mods_frame")
    if (::check_obj(frameObj))
    {
      local frameHeight = frameObj.getSize()[1]
      local maxFrameHeight = ::g_dagui_utils.toPixels(guiScene, "@maxWeaponsWindowHeight")

      if (frameHeight > maxFrameHeight)
      {
        local frameHeaderHeight = ::g_dagui_utils.toPixels(guiScene, "@frameHeaderHeight")
        if (frameHeight - frameHeaderHeight < maxFrameHeight)
        {
          frameObj.isHeaderHidden = "yes"
          showSceneBtn("close_alt_btn", !researchMode)
          local researchModeImgObj = scene.findObject("researchMode_image_block")
          researchModeImgObj["pos"] = researchModeImgObj["posWithoutHeader"]
        }
        else
        {
          needHideSlotbar = true
          frameObj["pos"] = frameObj["posWithoutSlotbar"]
        }
      }
    }
  }

  function showNewbieResearchHelp()
  {
    if (!researchMode || !tutorialModule.needShowTutorial("researchMod", 1))
      return

    tutorialModule.saveShowedTutorial("researchMod")

    local finMod = ::getTblValue(::researchedModForCheck, researchBlock, "")
    local newMod = ::shop_get_researchable_module_name(airName)

    local finIdx = getItemIdxByName(finMod)
    local newIdx = getItemIdxByName(newMod)

    if (finIdx < 0 || newIdx < 0)
      return

    local newModName = getModificationName(air, items[newIdx].name, true)
    local steps = [
      {
        obj = ["item_" + newIdx]
        text = ::loc("help/newModification", {modName = newModName})
        nextActionShortcut = "help/OBJ_CLICK"
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        cb = (@(newIdx) function() {setModificatonOnResearch(items[newIdx], function(){updateAllItems()})})(newIdx)
      },
      {
        obj = ["available_free_exp_text"]
        text = ::loc("help/FreeExp")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      }
    ]

    local finItem = items[finIdx]
    local balance = ::Cost()
    balance.setFromTbl(::get_balance())
    if (getItemAmount(air, finItem) < 1 && getItemCost(air, finItem) <= balance)
    {
      local finModName = getModificationName(air, items[finIdx].name, true)
      steps.insert(0,
        {
          obj = ["item_" + finIdx]
          text = ::loc("help/finishedModification", {modName = finModName})
          nextActionShortcut = "help/OBJ_CLICK"
          actionType = tutorAction.OBJ_CLICK
          shortcut = ::GAMEPAD_ENTER_SHORTCUT
          cb =  (@(finItem) function () { checkAndBuyWeaponry(finItem) })(finItem)
        })
    }

    ::gui_modal_tutor(steps, this)
  }

  function fillPage()
  {
    guiScene.setUpdatesEnabled(false, false)
    createItem(wrapUnitToItem(air), weaponsItem.curUnit, mainModsObj, 0.0, 0.0)
    fillModsTree(3.0)

    if (researchMode)
      fillPremiumMods(0.0, 1.6)
    else
    {
      fillPremiumMods(1.0, 0.0)
      fillWeaponsAndBullets(0, 1.5)
    }

    updateAllItems()
    guiScene.setUpdatesEnabled(true, true)
    updateWindowHeightAndPos()
  }

  function fillAvailableRPText()
  {
    if (!researchMode)
      return

    availableFlushExp = ::shop_get_unit_excess_exp(airName)
    local freeRPObj = scene.findObject("available_free_exp_text")
    if (::checkObj(freeRPObj))
      freeRPObj.setValue(::get_flush_exp_text(availableFlushExp))
  }

  function automaticallySpendAllExcessiveExp() //!!!TEMP function, true func must be from code
  {
    showTaskProgressBox()
    availableFlushExp = ::shop_get_unit_excess_exp(airName)
    local curResModuleName = ::shop_get_researchable_module_name(airName)

    if(availableFlushExp <= 0 || curResModuleName == "")
    {
      local afterDoneFunc = function() {
        destroyProgressBox()
        updateAllItems()
        goBack()
      }

      setModificatonOnResearch(getModificationByName(air, curResModuleName), afterDoneFunc)
      return
    }

    flushItemExp(curResModuleName, automaticallySpendAllExcessiveExp)
  }

  function onEventUnitResearch(params)
  {
    updateAllItems()
  }

  function onEventUnitBought(params)
  {
    isOwn = air.isUsable()
    updateAllItems()
  }

  function onEventUnitRented(params)
  {
    onEventUnitBought(params)
  }

  function onEventExpConvert(params)
  {
    updateAllItems()
  }

  function onEventUnitRepaired(params)
  {
    foreach(idx, item in items)
      if (isItemTypeUnit(item.type))
        return updateItem(idx)
  }

  function onEventModificationPurchased(params)
  {
    local modName = params?.modName
    if (modName)
      purchasedModifications.append(modName)

    updateAllItems()
  }
  function onEventWeaponPurchased(params) { updateAllItems() }
  function onEventSparePurchased(params) { updateAllItems() }
  function onEventSlotbarPresetLoaded(params) { onSlotbarSelect() }
  function onEventCrewsListChanged(params) { onSlotbarSelect() }

  function onEventUnitWeaponChanged(params)
  {
    if (!isUnitHaveSecondaryWeapons(air) || !needSecondaryWeaponsWindow(air)) {
      updateAllItems()
      return
    }

    lastWeapon = getLastWeapon(airName)
    local secondaryWeapons = getSecondaryWeaponsList(air)
    local selWeapon = secondaryWeapons.findvalue((@(w) w.name == lastWeapon).bindenv(this))
    if (selWeapon == null)
      return

    foreach(idx, item in items)
      if (item.type == weaponsItem.weapon) {
        items[idx] = selWeapon
        updateItem(idx)
        return
      }
  }

  function onEventUnitBulletsChanged(params)
  {
    updateAllItems()
  }

  function isItemTypeUnit(iType)
  {
    return iType == weaponsItem.curUnit
  }

  function addItemToList(item, iType)
  {
    local idx = items.len()

    item.type <- iType
    item.guiPosIdx <- idx

    items.append(item)
    return "item_" + idx
  }

  function createItem(item, iType, holderObj, posX, posY)
  {
    local id = addItemToList(item, iType)

    if (isItemTypeUnit(iType))
      return createUnitItemObj(id, item, holderObj, posX, posY)

    return createModItem(id, air, item, iType, holderObj, this, { posX = posX, posY = posY })
  }

  function wrapUnitToItem(unit)
  {
    return {
      name = unit.name
      unit = unit
    }
  }

  function createUnitItemObj(id, item, holderObj, posX, posY)
  {
    local blockObj = guiScene.createElementByObject(holderObj, "gui/weaponry/nextUnitItem.blk", "weapon_item_unit", this)
    local titleObj = blockObj.findObject("nextResearch_title")
    titleObj.setValue(researchMode? ::loc("mainmenu/nextResearch/title") : "")

    local position = (posX + 0.5).tostring() + "@modCellWidth-0.5w, " + (posY + 0.5).tostring() + "@modCellHeight-0.5h"
    if (researchMode)
      position = (posX + 0.5).tostring() + "@modCellWidth-0.5w, 1@framePadding+ 1@fadedImageFramePad"

    blockObj.pos = position
    local unitObj = blockObj.findObject("next_unit")
    unitObj.id = id
    return unitObj
  }

  function createItemForBundle(id, unit, item, iType, holderObj, handler, params = {})
  {
    id = addItemToList(item, iType)
    return createModItem(id, unit, item, iType, holderObj, handler, params)
  }

  function createBundle(itemsList, itemsType, subType, holderObj, posX, posY)
  {
    createModBundle("bundle_" + items.len(), air, itemsList, itemsType, holderObj, this,
      { posX = posX, posY = posY, subType = subType,
        maxItemsInColumn = 5, createItemFunc = createItemForBundle
        cellSizeObj = scene.findObject("cell_size")
      })
  }

  function getItemObj(idx)
  {
    return scene.findObject("item_" + idx)
  }

  function updateItem(idx)
  {
    local itemObj = getItemObj(idx)
    if (!::checkObj(itemObj) || !(idx in items))
      return

    local item = items[idx]
    if (isItemTypeUnit(item.type))
      return updateUnitItem(item, itemObj)

    local isVisualDisabled = false
    local visualItem = item
    if (item.type == weaponsItem.bundle)
      visualItem = getBundleCurItem(air, item) || visualItem
    if (isBullets(visualItem))
      isVisualDisabled = !isBulletsGroupActiveByMod(air, visualItem)

    local hasMenu = item.type == weaponsItem.bundle || (item.type == weaponsItem.weapon && needSecondaryWeaponsWindow(air))
    updateModItem(air, item, itemObj, true, this, {
      canShowResearch = availableFlushExp == 0 && setResearchManually
      flushExp = availableFlushExp
      researchMode = researchMode
      visualDisabled = isVisualDisabled
      hideStatus = hasMenu
      hasMenu
      actionBtnText = hasMenu ? ::loc("mainmenu/btnAirGroupOpen") : null
    })
  }

  function updateBuyAllButton()
  {
    local btnId = "btn_buyAll"
    local cost = getAllModsCost(air, true)
    local show = !cost.isZero() && ::isUnitUsable(air) && ::has_feature("BuyAllModifications")
    showSceneBtn(btnId, show)
    if (show)
      placePriceTextToButton(scene, btnId, ::loc("mainmenu/btnBuyAll"), cost)
  }

  function updateAllItems()
  {
    if (!isValid())
      return

    fillAvailableRPText()
    for(local i = 0; i < items.len(); i++)
      updateItem(i)
    local treeSize = modsTree.getModsTreeSize(air)
    updateTiersStatus(treeSize)
    updateButtons()
    updateBuyAllButton()
  }

  function updateButtons()
  {
    local isAnyModInResearch = isAnyModuleInResearch()
    showSceneBtn("btn_exit", researchMode && (!isAnyModInResearch || availableFlushExp <= 0 || setResearchManually))
    showSceneBtn("btn_spendExcessExp", researchMode && isAnyModInResearch && availableFlushExp > 0)

    local checkboxObj = scene.findObject("auto_purchase_mods")
    if (::checkObj(checkboxObj))
    {
      checkboxObj.show(isOwn)
      if (isOwn)
        checkboxObj.setValue(::get_auto_buy_modifications())
    }

    updateDependingButtons()
  }

  function updateDependingButtons()
  {
    if (!items
        || items.len() == 0
        || !::checkObj(mainModsObj))
      return

    local index = (mainModsObj.getValue() || 0) - 1
    if (index < 0 || index >= mainModsObj.childrenCount())
      return

    local btnObj = scene.findObject("btn_nav_research")
    if (!::checkObj(btnObj))
      return

    local item = items[index]
    local showResearchButton = researchMode
                       && getAmmoCost(air, item.name, AMMO.MODIFICATION).gold == 0
                       && !isModClassPremium(item)
                       && canBeResearched(air, item, false)
                       && availableFlushExp > 0

    showSceneBtn("btn_nav_research", showResearchButton)
    if (showResearchButton)
    {
      local flushExp = item.reqExp < availableFlushExp ? item.reqExp : availableFlushExp
      setColoredDoubleTextToButton(scene, "btn_nav_research",
        ::format(::loc("weaponry/research") + " (%s)", ::Cost().setRp(flushExp).tostring()))
    }

    local showPurchaseButton = researchMode
                               && getAmmoCost(air, item.name, AMMO.MODIFICATION).gold == 0
                               && !isModClassPremium(item)
                               && canBuyMod(air, item)

    showSceneBtn("btn_buy_mod", showPurchaseButton)
    if (showPurchaseButton)
      placePriceTextToButton(scene, "btn_buy_mod", ::loc("mainmenu/btnBuy"), getItemCost(air, item).wp)

    local textObj = scene.findObject("no_action_text")
    if (::checkObj(textObj))
      textObj.show(researchMode
                   && availableFlushExp > 0
                   && !showResearchButton
                   && !showPurchaseButton)
  }

  function updateUnitItem(item, itemObj)
  {
    local params = {
      slotbarActions = airActions
      getEdiffFunc  = getCurrentEdiff.bindenv(this)
    }
    local unitBlk = ::build_aircraft_item("unit_item", item.unit, params)
    guiScene.replaceContentFromText(itemObj, unitBlk, unitBlk.len(), this)
    ::fill_unit_item_timers(itemObj.findObject("unit_item"), item.unit, params)
  }

  function isAnyModuleInResearch()
  {
    local module = ::shop_get_researchable_module_name(airName)
    if (module == "")
      return false

    local moduleData = getModificationByName(air, module)
    if (!moduleData || isModResearched(air, moduleData))
      return false

    return !isModClassPremium(moduleData)
  }

  function updateItemBundle(item)
  {
    local bundle = getItemBundle(item)
    if (!bundle)
      updateItem(item.guiPosIdx)
    else
    {
      updateItem(bundle.guiPosIdx)
      foreach(bitem in bundle.itemsList)
        updateItem(bitem.guiPosIdx)
    }
  }

  function createTreeItems(obj, branch, treeOffsetY = 0)
  {
    local branchItems = collectBranchItems(branch, [])
    branchItems.sort(@(a,b) a.tier <=> b.tier || a.guiPosX <=> b.guiPosX)
    foreach(item in branchItems)
      createItem(item, weaponsItem.modification, obj, item.guiPosX, item.tier + treeOffsetY - 1)
  }

  function collectBranchItems(branch, resItems)
  {
    foreach(idx, item in branch)
      if (typeof(item)=="table") //modification
        resItems.append(item)
      else if (typeof(item)=="array") //branch
        collectBranchItems(item, resItems)
    return resItems
  }

  function createTreeBlocks(obj, columnsList, height, treeOffsetX, treeOffsetY, blockType = "", blockIdPrefix = "")
  {
    local fullWidth = wndWidth - treeOffsetX
    local view = {
      width = fullWidth
      height = height
      offsetX = treeOffsetX
      offsetY = treeOffsetY
      columnsList = columnsList
      rows = []
      rowType = blockType
    }

    if (columnsList.len())
    {
      local headerWidth = 0
      foreach(idx, column in columnsList)
      {
        column.needDivLine <- idx > 0
        headerWidth += column.width
        if (column.name && ::utf8_strlen(column.name) > ::header_len_per_cell * column.width)
          column.isSmallFont <- true
      }

      //increase last column width to full window width
      local widthDiff = fullWidth - headerWidth
      if (widthDiff > 0)
        columnsList[columnsList.len() - 1].width += widthDiff
    }

    local needTierArrows = blockIdPrefix != ""
    for(local i = 1; i <= height; i++)
    {
      local row = {
        width = fullWidth
        top = i - 1
      }

      if(needTierArrows)
      {
        row.id <- blockIdPrefix + i
        row.needTierArrow <- i > 1
        row.tierText <- ::get_roman_numeral(i)
      }

      view.rows.append(row)
    }

    local data = ::handyman.renderCached("gui/weaponry/weaponryBg", view)
    if (data!="")
      guiScene.appendWithBlk(obj, data, this)
  }

  function createTreeArrows(obj, arrowsList, treeOffsetY)
  {
    local data = ""
    foreach(idx, a in arrowsList)
    {
      local id = "arrow_" + idx

      if (a.from[0]!=a.to[0]) //hor arrow
        data += format("modArrow { id:t='%s'; type:t='right'; " +
                         "pos:t='%.1f@modCellWidth-0.5@modArrowLen, %.1f@modCellHeight-0.5h'; " +
                         "width:t='@modArrowLen + %.1f@modCellWidth' " +
                       "}",
                       id, a.from[0] + 1, a.from[1] - 0.5 + treeOffsetY, a.to[0]-a.from[0]-1
                      )
      else if (a.from[1]!=a.to[1]) //vert arrow
        data += format("modArrow { id:t='%s'; type:t='down'; " +
                         "pos:t='%.1f@modCellWidth-0.5w, %.1f@modCellHeight-0.5@modArrowLen'; " +
                         "height:t='@modArrowLen + %.1f@modCellHeight' " +
                       "}",
                       id, a.from[0] + 0.5, a.from[1] + treeOffsetY, a.to[1]-a.from[1]-1
                      )
    }
    if (data!="")
      guiScene.appendWithBlk(obj, data, this)
  }

  function fillModsTree(treeOffsetY)
  {
    local tree = modsTree.generateModsTree(air)
    if (!tree)
      return

    local treeSize = modsTree.getModsTreeSize(air)
    if (treeSize.guiPosX > 6)
      ::dagor.logerr($"Modifications: {air.name} too much modifications in a row")

    mainModsObj.size = format("%.1f@modCellWidth, %.1f@modCellHeight", treeSize.guiPosX, treeSize.tier + treeOffsetY)
    if (!(treeSize.tier > 0))
      return

    local bgElems = modsTree.generateModsBgElems(air)
    createTreeBlocks(modsBgObj, bgElems.blocks, treeSize.tier, 0, treeOffsetY, "unlocked", tierIdPrefix)
    createTreeArrows(modsBgObj, bgElems.arrows, treeOffsetY)
    createTreeItems(mainModsObj, tree, treeOffsetY)
    if (treeSize.guiPosX > wndWidth)
      scene.findObject("overflow-div")["overflow-x"] = "auto"
  }

  function updateTiersStatus(size)
  {
    local tiersArray = getResearchedModsArray(size.tier)
    for(local i = 1; i <= size.tier; i++)
    {
      if (tiersArray[i-1] == null)
      {
        ::dagor.assertf(false, ::format("No modification data for unit '%s' in tier %s.", air.name, i.tostring()))
        break
      }
      local unlocked = isWeaponTierAvailable(air, i)
      local owned = (tiersArray[i-1].notResearched == 0)
      scene.findObject(tierIdPrefix + i).type = owned? "owned" : unlocked ? "unlocked" : "locked"

      local jObj = scene.findObject(tierIdPrefix + (i+1).tostring())
      if(::checkObj(jObj))
      {
        local modsCountObj = jObj.findObject(tierIdPrefix + (i+1).tostring() + "_txt")
        local countMods = tiersArray[i-1].researched
        local reqMods = air.needBuyToOpenNextInTier[i-1]
        if(countMods >= reqMods)
          if(!unlocked)
          {
            modsCountObj.setValue(countMods.tostring() + ::loc("weapons_types/short/separator") + reqMods.tostring())
            local tooltipText = "<color=@badTextColor>" + ::loc("weaponry/unlockTier/reqPrevTiers") + "</color>"
            modsCountObj.tooltip = ::loc("weaponry/unlockTier/countsBlock/startText") + "\n" +  tooltipText
            jObj.tooltip = tooltipText
          }
          else
          {
            modsCountObj.setValue("")
            modsCountObj.tooltip = ""
            jObj.tooltip = ""
          }
        else
        {
          modsCountObj.setValue(countMods.tostring() + ::loc("weapons_types/short/separator") + reqMods.tostring())
          local req = reqMods - countMods

          local tooltipText = ::loc("weaponry/unlockTier/tooltip",
                                    { amount = req.tostring(), tier = ::get_roman_numeral(i+1) })
          jObj.tooltip = tooltipText
          modsCountObj.tooltip = ::loc("weaponry/unlockTier/countsBlock/startText") + "\n" + tooltipText
        }
      }
    }
  }

  function getResearchedModsArray(tiersCount)
  {
    local tiersArray = []
    if("modifications" in air && tiersCount > 0)
    {
      tiersArray = array(tiersCount, null)
      foreach(mod in air.modifications)
        if (!::wp_get_modification_cost_gold(airName, mod.name) &&
            getModificationBulletsGroup(mod.name) == ""
           )
          {
            local idx = mod.tier-1
            tiersArray[idx] = tiersArray[idx] || { researched=0, notResearched=0 }

            if(isModResearched(air, mod))
              tiersArray[idx].researched++
            else
              tiersArray[idx].notResearched++
          }
    }
    return tiersArray
  }

  function fillPremiumMods(offsetX, offsetY)
  {
    if (!::has_feature("SpendGold"))
      return

    local nextX = offsetX
    if (air.spare && !researchMode)
      createItem(air.spare, weaponsItem.spare, mainModsObj, nextX++, offsetY)
    foreach(mod in air.modifications)
      if ((!researchMode || canResearchMod(air, mod))
          && (isModClassPremium(mod)
              || (mod.modClass == "" && getModificationBulletsGroup(mod.name) == "")
          ))
        createItem(mod, weaponsItem.modification, mainModsObj, nextX++, offsetY)

    if (researchMode)
      return

    local columnsList = [getWeaponsColumnData()]
    createTreeBlocks(modsBgObj, columnsList, 1, offsetX, offsetY)
  }

  function getWeaponsColumnData(name = null, width = 1, tooltip = "")
  {
    return { name = name
        width = width
        tooltip = tooltip
      }
  }

  function getExpendableModificationsArray(unit)
  {
    if (!("modifications" in unit))
      return []

    return ::u.filter(unit.modifications, isModClassExpendable)
  }

  function fillWeaponsAndBullets(offsetX, offsetY)
  {
    local columnsList = []
    //add primary weapons bundle
    local primaryWeaponsNames = getPrimaryWeaponsList(air)
    local primaryWeaponsList = []
    foreach(i, modName in primaryWeaponsNames)
    {
      local mod = (modName=="")? null : getModificationByName(air, modName)
      local item = { name = modName, weaponMod = mod }

      if (mod)
      {
        mod.isPrimaryWeapon <- true
        item.reqModification <- [modName]
      }
      else
      {
        item.image <- air.commonWeaponImage
        if("weaponUpgrades" in air)
          item.weaponUpgrades <- air.weaponUpgrades
      }
      primaryWeaponsList.append(item)
    }
    createBundle(primaryWeaponsList, weaponsItem.primaryWeapon, 0, mainModsObj, offsetX, offsetY)
    columnsList.append(getWeaponsColumnData(::loc("options/primary_weapons")))
    offsetX++

    //add secondary weapons
    if (isUnitHaveSecondaryWeapons(air))
    {
      local secondaryWeapons = getSecondaryWeaponsList(air)
      lastWeapon = getLastWeapon(airName) //real weapon or ..._default
      dagor.debug("initial set lastWeapon " + lastWeapon )
      if (needSecondaryWeaponsWindow(air)) {
        local selWeapon = secondaryWeapons.findvalue((@(w) w.name == lastWeapon).bindenv(this))
          ?? secondaryWeapons?[0]
        if (selWeapon)
          createItem(selWeapon, weaponsItem.weapon, mainModsObj, offsetX, offsetY)
      } else
        createBundle(secondaryWeapons, weaponsItem.weapon, 0, mainModsObj, offsetX, offsetY)
      columnsList.append(getWeaponsColumnData(::g_weaponry_types.WEAPON.getHeader(air)))
      offsetX++
    }

    //add bullets bundle
    lastBullets = []

    for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(air); groupIndex++)
    {
      local bulletsList = getBulletsList(air.name, groupIndex, {
        needCheckUnitPurchase = false, needOnlyAvailable = false
      })
      local curBulletsName = ::get_last_bullets(air.name, groupIndex)
      if (groupIndex < air.unitType.bulletSetsQuantity)
        lastBullets.append(curBulletsName)
      if (!bulletsList.values.len() || bulletsList.duplicate)
        continue

      createBundle(getBulletsItemsList(air, bulletsList, groupIndex),
        weaponsItem.bullets, groupIndex, mainModsObj, offsetX, offsetY)

      local name = getBulletsListHeader(air, bulletsList)
      columnsList.append(getWeaponsColumnData(name))
      offsetX++
    }

    //add expendables
    local expendablesArray = getExpendableModificationsArray(air)
    if (expendablesArray.len())
    {
      columnsList.append(getWeaponsColumnData(::loc("modification/category/expendables")))
      foreach (mod in expendablesArray)
      {
        createItem(mod, mod.type, mainModsObj, offsetX, offsetY)
        offsetX++
      }
    }

    createTreeBlocks(modsBgObj, columnsList, 1, 0, offsetY)
  }

  function canBomb(checkPurchase)
  {
    return isUnitHaveAnyWeaponsTags(air, [WEAPON_TAG.ROCKET, WEAPON_TAG.BOMB], checkPurchase)
  }

  function getItemBundle(searchItem)
  {
    foreach(bundle in items)
      if (bundle.type == weaponsItem.bundle)
        foreach(item in bundle.itemsList)
          if (item.name == searchItem.name && item.type==searchItem.type)
            return bundle
    return null
  }

  function onModificationTooltipOpen(obj)
  {
    local id = ::getObjIdByPrefix(obj, "tooltip_item_")
    if (!id) return
    local idx = id.tointeger()
    if (!(idx in items))
      return

    local item = items[idx]
    local curTier = "tier" in item? item.tier : 1
    local canDisplayInfo = curTier <= 1 || ::isInArray(curTier, shownTiers)
    tooltipOpenTime = canDisplayInfo? -1 : ::tooltip_display_delay
    updateWeaponTooltip(obj, air, item, this, { canDisplayInfo = canDisplayInfo })

    obj.findObject("weapons_timer").setUserData(this)
  }

  function onUpdateWeaponTooltip(obj, dt)
  {
    if(tooltipOpenTime <= 0)
      return
    tooltipOpenTime -= dt
    if(tooltipOpenTime <= 0)
    {
      local tooltipObj = obj.getParent()
      local id = ::getObjIdByPrefix(tooltipObj, "tooltip_item_")
      if (!id)
        return
      local idx = id.tointeger()
      if (!(idx in items))
        return
      local item = items[idx]
      if ("tier" in item && !::isInArray(item.tier, shownTiers))
        shownTiers.append(item.tier)
      updateWeaponTooltip(tooltipObj, air, item, this)
    }
  }

  function getItemIdxByObj(obj)
  {
    if (!obj) return -1
    local id = obj?.holderId ?? ""
    if (id == "")
      id = obj.id
    if (id.len() <= 5 || id.slice(0,5) != "item_")
      return -1
    local idx = id.slice(5).tointeger()
    return (idx in items)? idx : -1
  }

  function getItemIdxByName(name)
  {
    foreach(idx, item in items)
      if (item.name == name)
        return idx

    return -1
  }

  function getCurItemObj() {
    if (!::checkObj(mainModsObj))
      return null

    local val = mainModsObj.getValue() - 1
    local itemObj = mainModsObj.findObject("item_" + val)
    return ::check_obj(itemObj) ? itemObj : null
  }

  function doCurrentItemAction()
  {
    local itemObj = getCurItemObj()
    if (itemObj)
      onModAction(itemObj, false)
  }

  function onModItemClick(obj)
  {
    if (researchMode)
    {
      local idx = getItemIdxByObj(obj)
      if (idx >= 0)
        mainModsObj.setValue(items[idx].guiPosIdx+1)
      return
    }

    onModAction(obj, false, ::show_console_buttons)
  }

  function onModItemDblClick(obj)
  {
    onModAction(obj)
  }

  function onModActionBtn(obj)
  {
    onModAction(obj, true, true)
  }

  function onModCheckboxClick(obj)
  {
    onModAction(obj)
  }

  function getSelectedUnit()
  {
    if (!::checkObj(mainModsObj))
      return null
    local item = getSelItemFromNavObj(mainModsObj)
    return (item && isItemTypeUnit(item.type))? item : null
  }

  function getSelItemFromNavObj(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return null
    local idx = getItemIdxByObj(obj.getChild(value))
    if (idx < 0)
      return null
    return items[idx]
  }

  function canPerformAction(item, amount)
  {
    local reason = null
    if(!isOwn)
      reason = ::format(::loc("weaponry/action_not_allowed"), ::loc("weaponry/unit_not_bought"))
    else if (!amount && !canBuyMod(air, item))
    {
      local reqTierMods = 0
      local reqMods = ""
      if("tier" in item)
        reqTierMods = ::getNextTierModsCount(air, item.tier - 1)
      if ("reqModification" in item)
        reqMods = getReqModsText(air, item)

      if(reqTierMods > 0)
        reason = ::format(::loc("weaponry/action_not_allowed"),
                          ::loc("weaponry/unlockModTierReq",
                                { tier = ::roman_numerals[item.tier], amount = (reqTierMods).tostring() }))
      else if(reqMods.len() > 0)
        reason = ::format(::loc("weaponry/action_not_allowed"), ::loc("weaponry/unlockModsReq") + "\n" + reqMods)
    }

    if(reason != null)
    {
      msgBox("not_available", reason, [["ok", function() {} ]], "ok")
      return false
    }
    return true
  }

  function onStickDropDown(obj, show)
  {
    if (!::checkObj(obj))
      return

    local id = obj?.id
    if (!id || id.len() <= 5 || id.slice(0,5) != "item_")
      return base.onStickDropDown(obj, show)

    if (!show)
    {
      curBundleTblObj = null
      return
    }

    curBundleTblObj = obj.findObject("items_field")
    guiScene.playSound("menu_appear")
    return
  }

  function unstickCurBundle()
  {
    if (!::checkObj(curBundleTblObj))
      return
    onDropDown(curBundleTblObj.getParent().getParent()) //need a hoverSize here or bundleItem.
    curBundleTblObj = null
  }

  function onBundleAnimFinish(obj) {
    //this only for animated gamepad cursor. for pc mouse logic look onHoverSizeMove
    if (!::show_console_buttons || !curBundleTblObj?.isValid() || obj.getFloatProp(timerPID, 0.0) < 1)
      return
    ::move_mouse_on_child(curBundleTblObj, 0)
  }

  function onBundleHover(obj) {
    // see func onBundleAnimFinish
    if (!::show_console_buttons || !curBundleTblObj?.isValid() || obj.getFloatProp(timerPID, 0.0) < 1)
      return
    unstickCurBundle()
  }

  function onCloseBundle(obj) {
    if (::show_console_buttons)
      ::move_mouse_on_obj(obj.getParent().getParent().getParent())
  }

  function onModAction(obj, fullAction = true, stickBundle = false)
  {
    local idx = getItemIdxByObj(obj)
    if (idx < 0)
      return

    if (items[idx].type == weaponsItem.bundle)
    {
      if (stickBundle && ::check_obj(obj))
        onDropDown(obj.getParent())
      return
    }
    doItemAction(items[idx], fullAction)
  }

  function doItemAction(item, fullAction = true)
  {
    local amount = getItemAmount(air, item)
    local onlyBuy = !fullAction && !getItemBundle(item)

    if (checkResearchOperation(item))
      return
    if(!canPerformAction(item, amount))
      return

    if (item.type == weaponsItem.weapon) {
      if (needSecondaryWeaponsWindow(air)) {
        weaponryPresetsModal.open({ unit = air }) //open modal menu for air and helicopter only
        return
      }

      if(getLastWeapon(airName) == item.name || !amount) {
        if (item.cost <= 0)
          return
        return onBuy(item.guiPosIdx)
      }

      if (onlyBuy)
        return

      guiScene.playSound("check")
      setLastWeapon(airName, item.name)
      updateItemBundle(item)
      ::check_secondary_weapon_mods_recount(air)
      return
    }
    else if (item.type == weaponsItem.primaryWeapon)
    {
      if (!onlyBuy)
      {
        setLastPrimary(item)
        return
      }
    }
    else if (item.type == weaponsItem.modification)
    {
      local groupDef = ("isDefaultForGroup" in item)? item.isDefaultForGroup : -1
      if (groupDef >= 0)
      {
        setLastBullets(item, groupDef)
        return
      }
      else if (!onlyBuy)
      {
        if (getModificationBulletsGroup(item.name) != "")
        {
          local id = getBulletGroupIndex(airName, item.name)
          local isChanged = false
          if (id >= 0)
            isChanged = setLastBullets(item, id)
          if (isChanged)
            return
        }
        else if(amount)
        {
          switchMod(item)
          return
        }
      }
    }
    else if (item.type == weaponsItem.expendables)
    {
      if (!onlyBuy && amount)
      {
        switchMod(item)
        return
      }
    }// else
    //if (item.type==weaponsItem.spare)

    onBuy(item.guiPosIdx)
  }

  function checkResearchOperation(item)
  {
    if (canResearchItem(air, item, availableFlushExp <= 0 && setResearchManually))
    {
      local afterFuncDone = (@(item) function() {
        setModificatonOnResearch(item, function()
        {
          updateAllItems()
          selectResearchModule()
          if (researchMode)
          {
            if (item && isModResearched(air, item))
              sendModResearchedStatistic(air, item.name)
          }
        })
      })(item)

      flushItemExp(item.name, afterFuncDone)
      return true
    }
    return false
  }

  function setModificatonOnResearch(item, afterDoneFunc = null)
  {
    local executeAfterDoneFunc = (@(afterDoneFunc) function() {
        if (afterDoneFunc)
          afterDoneFunc()
      })(afterDoneFunc)

    if (!item || isModResearched(air, item))
    {
      executeAfterDoneFunc()
      return
    }

    taskId = ::shop_set_researchable_unit_module(airName, item.name)
    if (taskId >= 0)
    {
      setResearchManually = true
      lastResearchMod = item
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = afterDoneFunc
      afterSlotOpError = (@(executeAfterDoneFunc) function(res) {
          msgBox("unit_modul_research_fail", ::loc("weaponry/module_set_research_failed"),
            [["ok", (@(executeAfterDoneFunc) function() { executeAfterDoneFunc() })(executeAfterDoneFunc)]], "ok")
        })(executeAfterDoneFunc)
    }
    else
      executeAfterDoneFunc()
  }

  function flushItemExp(modName, afterDoneFunc = null)
  {
    checkSaveBulletsAndDo((@(modName, afterDoneFunc) function() {
      _flushItemExp(modName, afterDoneFunc)
    })(modName, afterDoneFunc))
  }

  function _flushItemExp(modName, afterDoneFunc = null)
  {
    local executeAfterDoneFunc = (@(afterDoneFunc) function() {
        setResearchManually = true
        if (afterDoneFunc)
          afterDoneFunc()
      })(afterDoneFunc)

    if (availableFlushExp <= 0)
    {
      executeAfterDoneFunc()
      return
    }

    taskId = ::flushExcessExpToModule(airName, modName)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = afterDoneFunc
      afterSlotOpError = (@(executeAfterDoneFunc) function(res) {
          executeAfterDoneFunc()
        })(executeAfterDoneFunc)
    }
    else
      executeAfterDoneFunc()
  }

  function onAltModAction(obj) //only buy atm before no research.
  {
    local idx = getItemIdxByObj(obj)
    if (idx < 0)
      return

    local item = items[idx]
    if (item.type==weaponsItem.spare)
    {
      ::gui_handlers.UniversalSpareApplyWnd.open(air, getItemObj(idx))
      return
    }
    else if (item.type == weaponsItem.modification)
    {
      if (getItemAmount(air, item) && isModUpgradeable(item.name))
      {
        ::gui_handlers.ModUpgradeApplyWnd.open(air, item, getItemObj(idx))
        return
      }
    }

    onBuy(idx)
  }

  function onBuy(idx, buyAmount = 0) //buy for wp or gold
  {
    if (!isOwn)
      return

    local item = items[idx]
    local open = false

    if (item.type==weaponsItem.bundle)
      return getByCurBundle(air, item, @(a, it) onBuy(it.guiPosIdx, buyAmount))

    if (item.type==weaponsItem.weapon)
    {
      if (!::shop_is_weapon_available(airName, item.name, false, true))
        return
    }
    else if (item.type==weaponsItem.primaryWeapon)
    {
      if ("guiPosIdx" in item.weaponMod)
        item = items[item.weaponMod.guiPosIdx]
    }
    else if (item.type==weaponsItem.modification || item.type==weaponsItem.expendables)
    {
      local groupDef = ("isDefaultForGroup" in item)? item.isDefaultForGroup : -1
      if (groupDef>=0)
        return

      open = canResearchMod(air, item)
    }

    checkAndBuyWeaponry(item, open)
  }

  function onBuyAllButton()
  {
    onBuyAll()
  }

  function onBuyAll(forceOpen = true, silent = false)
  {
    checkSaveBulletsAndDo(::Callback((@(air, forceOpen, silent) function() {
      ::WeaponsPurchase(air, {open = forceOpen, silent = silent})
    })(air, forceOpen, silent), this))
  }

  function setLastBullets(item, groupIdx)
  {
    if (!(groupIdx in lastBullets))
      return false

    local curBullets = ::get_last_bullets(airName, groupIdx)
    local isChanged = curBullets != item.name && !("isDefaultForGroup" in item && curBullets == "")
    setUnitLastBullets(air, groupIdx, item.name)
    if (isChanged) {
      guiScene.playSound("check")
    }
    updateItemBundle(item)
    return isChanged
  }

  function checkAndBuyWeaponry(modItem, open = false)
  {
    local listObj = mainModsObj
    local curValue = mainModsObj.getValue()
    checkSaveBulletsAndDo(::Callback(function() {
      ::WeaponsPurchase(air, {
        modItem = modItem,
        open = open,
        onFinishCb = @() ::move_mouse_on_child(listObj, curValue)
      })
    }, this))
  }

  function setLastPrimary(item)
  {
    local lastPrimary = getLastPrimaryWeapon(air)
    if (lastPrimary==item.name)
      return
    local mod = getModificationByName(air, (item.name=="") ? lastPrimary : item.name)
    if (mod)
      switchMod(mod, false)
  }

  function switchMod(item, checkCanDisable = true)
  {
    local equipped = ::shop_is_modification_enabled(airName, item.name)
    if (checkCanDisable && equipped && !isCanBeDisabled(item))
      return

    guiScene.playSound(!equipped ? "check" : "uncheck")

    checkSaveBulletsAndDo((@(item, equipped) function() { doSwitchMod(item, equipped) })(item, equipped))
  }

  function doSwitchMod(item, equipped)
  {
    local wndUpdateItems = ::Callback(function() {
      updateAllItems()
      unstickCurBundle()
    }, this)

    local taskSuccessCallback = (@(air, item) function() {
      ::updateAirAfterSwitchMod(air, item.name)
      ::broadcastEvent("ModificationChanged", {unit = air, modName = item.name})
      wndUpdateItems()
    }) (air, item)

    local taskId = enable_modification(airName, item.name, !equipped)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, taskSuccessCallback)
  }

  function checkSaveBulletsAndDo(func)
  {
    local needSave = false;
    for (local groupIndex = 0; groupIndex < air.unitType.bulletSetsQuantity; groupIndex++)
    {
        if (lastBullets && groupIndex in lastBullets &&
            lastBullets[groupIndex] != ::get_last_bullets(airName, groupIndex))
        {
          dagor.debug("force cln_update due lastBullets '" + lastBullets[groupIndex] + "' != '" +
                      ::get_last_bullets(airName, groupIndex) + "'")
          needSave = true;
          lastBullets[groupIndex] = ::get_last_bullets(airName, groupIndex)
        }
    }
    if (isUnitHaveSecondaryWeapons(air) && lastWeapon!="" && lastWeapon != getLastWeapon(airName))
    {
      dagor.debug("force cln_update due lastWeapon '" + lastWeapon + "' != " + getLastWeapon(airName))
      needSave = true;
      lastWeapon = getLastWeapon(airName)
    }

    if (needSave)
    {
      taskId = save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      if (taskId >= 0 && func)
      {
        local cb = ::u.isFunction(func) ? ::Callback(func, this) : func
        ::g_tasker.addTask(taskId, {showProgressBox = true}, cb)
      }
    }
    else if (func)
      func()
    return true
  }

  function getAutoPurchaseValue()
  {
    return isOwn && ::get_auto_buy_modifications()
  }

  function onChangeAutoPurchaseModsValue(obj)
  {
    local value = obj.getValue()
    local savedValue = getAutoPurchaseValue()
    if (value == savedValue)
      return

    ::set_auto_buy_modifications(value)
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function goBack()
  {
    checkSaveBulletsAndDo(null)
    sendModPurchasedStatistic(air)

    if (researchMode)
    {
      local curResName = ::shop_get_researchable_module_name(airName)
      if (::getTblValue("name", lastResearchMod, "") != curResName)
        setModificatonOnResearch(getModificationByName(air, curResName))
    }

    if (getAutoPurchaseValue())
      onBuyAll(false, true)
    else if (researchMode)
      prepareUnitsForPurchaseMods.addUnit(air)

    base.goBack()
  }

  function afterModalDestroy()
  {
    if (!::checkNonApprovedResearches(false) && prepareUnitsForPurchaseMods.haveUnits())
      prepareUnitsForPurchaseMods.checkUnboughtMods()
  }

  function onDestroy()
  {
    if (researchMode && findAnyNotResearchedMod(air))
      ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)

    sendModPurchasedStatistic(air)
  }

  function getHandlerRestoreData()
  {
    if (!researchMode || (setResearchManually && !availableFlushExp))
      return null
    return {
      openData = {
        researchMode = researchMode
        researchBlock = researchBlock
      }
    }
  }

  function onEventUniversalSpareActivated(p)
  {
    foreach(idx, item in items)
      if (item.type == weaponsItem.spare)
        updateItem(idx)
  }

  function onEventModUpgraded(p)
  {
    if (p.unit != air)
      return
    local modName = p.mod.name
    local itemidx = items.findindex(@(item) item.name == modName)
    if (itemidx != null)
      updateItem(itemidx)
  }

  function getCurrentEdiff()
  {
    return curEdiff == -1 ? ::get_current_ediff() : curEdiff
  }

  function sendModResearchedStatistic(unit, modName)
  {
    ::add_big_query_record("completed_new_research_modification",
        ::save_to_json({ unit = unit.name
          modification = modName }))
  }

  function sendModPurchasedStatistic(unit)
  {
    if (!unit || !purchasedModifications.len())
      return

    ::add_big_query_record("modifications_purchased",
        ::save_to_json({ unit = unit.name
          modifications = purchasedModifications }))
    purchasedModifications.clear()
  }
}

class ::gui_handlers.MultiplePurchase extends ::gui_handlers.BaseGuiHandlerWT
{
  curValue = 0
  minValue = 0
  maxValue = 1
  minUserValue = null
  maxUserValue = null
  item = null
  unit = null

  itemCost = null

  buyFunc = null
  onExitFunc = null
  showDiscountFunc = null

  someAction = true
  scene = null
  wndType = handlerType.MODAL
  sceneBlkName = "gui/multiplePurchase.blk"

  function initScreen()
  {
    if (minValue >= maxValue)
    {
      goBack()
      return
    }

    itemCost = getItemCost(unit, item)
    local statusTbl = getItemStatusTbl(unit, item)
    minValue = statusTbl.amount
    maxValue = statusTbl.maxAmount
    minUserValue = statusTbl.amount + 1
    maxUserValue = statusTbl.maxAmount

    scene.findObject("item_name_header").setValue(getModItemName(unit, item))

    updateSlider()
    createModItem("mod_" + item.name, unit, item, item.type, scene.findObject("icon"), this)

    local discountType = item.type == weaponsItem.spare? "spare" : (item.type == weaponsItem.weapon)? "weapons" : "mods"
    ::showAirDiscount(scene.findObject("multPurch_discount"), unit.name, discountType, item.name, true)

    sceneUpdate()
    ::move_mouse_on_obj(scene.findObject("skillSlider"))
  }

  function updateSlider()
  {
    minUserValue = (minUserValue == null)? minValue : clamp(minUserValue, minValue, maxValue)
    maxUserValue = (maxUserValue == null)? maxValue : clamp(maxUserValue, minValue, maxValue)

    if (curValue <= minValue)
    {
      local balance = ::get_balance()
      local maxBuy = maxValue - minValue
      if (maxBuy * itemCost.gold > balance.gold && balance.gold >= 0)
        maxBuy = (balance.gold / itemCost.gold).tointeger()
      if (maxBuy * itemCost.wp > balance.wp && balance.wp >= 0)
        maxBuy = (balance.wp / itemCost.wp).tointeger()
      curValue = itemCost.gold > 0 ? minUserValue: minValue + max(maxBuy, 1)
    }

    local sObj = scene.findObject("skillSlider")
    sObj.max = maxValue

    local oldObj = scene.findObject("oldSkillProgress")
    oldObj.max = maxValue

    local newObj = scene.findObject("newSkillProgress")
    newObj.min = minValue
    newObj.max = maxValue
  }

  function onModificationTooltipOpen(obj)
  {
    updateWeaponTooltip(obj, unit, item, this)
  }

  function onButtonDec()
  {
    curValue -= 1
    sceneUpdate()
  }

  function onButtonInc()
  {
    curValue += 1
    sceneUpdate()
  }

  function onButtonMax()
  {
    curValue = maxUserValue
    sceneUpdate()
  }

  function onProgressChanged(obj)
  {
    if(!obj || !someAction)
      return

    local newValue = obj.getValue()
    if (newValue == curValue)
      return

    if (newValue < minUserValue)
      newValue = minUserValue

    local value = clamp(newValue, minUserValue, maxUserValue)

    curValue = value
    sceneUpdate()
  }

  function sceneUpdate()
  {
    scene.findObject("skillSlider").setValue(curValue)
    scene.findObject("oldSkillProgress").setValue(minValue)
    scene.findObject("newSkillProgress").setValue(curValue)
    local buyValue = curValue - minValue
    local buyValueText = buyValue==0? "": ("+" + buyValue.tostring())
    scene.findObject("text_buyingValue").setValue(buyValueText)
    scene.findObject("buttonInc").enable(curValue < maxUserValue)
    scene.findObject("buttonMax").enable(curValue != maxUserValue)
    scene.findObject("buttonDec").enable(curValue > minUserValue)

    local wpCost = buyValue * itemCost.wp
    local eaCost = buyValue * itemCost.gold
    placePriceTextToButton(scene, "item_price", ::loc("mainmenu/btnBuy"), wpCost, eaCost)
  }

  function onBuy(obj)
  {
    if (buyFunc)
      buyFunc(curValue - minValue)
  }

  function goBack()
  {
    if (onExitFunc)
      onExitFunc()
    base.goBack()
  }

  function onEventModificationPurchased(params) { goBack() }
  function onEventWeaponPurchased(params) { goBack() }
  function onEventSparePurchased(params) { goBack() }
}
