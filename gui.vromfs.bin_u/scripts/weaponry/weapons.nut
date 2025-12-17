from "%scripts/dagui_natives.nut" import save_online_single_job, shop_is_weapon_available,
  get_auto_buy_modifications, shop_get_unit_excess_exp, set_char_cb, utf8_strlen,
  shop_set_researchable_unit_module, set_auto_buy_modifications, shop_get_researchable_module_name
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import *
from "%scripts/options/optionsConsts.nut" import SAVE_ONLINE_JOB_DIGIT
from "%scripts/items/itemsConsts.nut" import itemType
from "%scripts/controls/rawShortcuts.nut" import GAMEPAD_ENTER_SHORTCUT
from "%scripts/utils_sa.nut" import get_flush_exp_text, roman_numerals, check_aircraft_tags

let { deep_clone } = require("%sqstd/underscore.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { toPixels, move_mouse_on_child, move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getModsTreeSize, generateModsTree, generateModsBgElems, commonProgressMods,
  isModificationInTree, modsWndWidthRestrictions, getNextTierModsCount } = require("%scripts/weaponry/modsTree.nut")
let tutorialModule = require("%scripts/user/newbieTutorialDisplay.nut")
let guiStartWeaponryPresets = require("%scripts/weaponry/guiStartWeaponryPresets.nut")
let prepareUnitsForPurchaseMods = require("%scripts/weaponry/prepareUnitsForPurchaseMods.nut")
let { canBuyMod, canResearchMod, isModResearched, isModUpgradeable, isModClassPremium,
  isModClassExpendable, getModificationByName, findAnyNotResearchedMod,
  getModificationBulletsGroup } = require("%scripts/weaponry/modificationInfo.nut")
let { isUnitHaveSecondaryWeapons } = require("%scripts/unit/unitWeaponryInfo.nut")
let { getItemAmount, getItemCost, getAllModsCost, getByCurBundle, getItemStatusTbl,
  isCanBeDisabled, isModInResearch, getBundleCurItem, canResearchItem
} = require("%scripts/weaponry/itemInfo.nut")
let { getModItemName, getReqModsText, getBulletsListHeader
} = require("%scripts/weaponry/weaponryDescription.nut")
let { updateModItem, createModItem, createModBundle, createModItemLayout
} = require("%scripts/weaponry/weaponryVisual.nut")
let { isBullets, getBulletsList, setUnitLastBullets,
  getBulletGroupIndex, getBulletsItemsList, isWeaponTierAvailable, getModificationName,
  getLastFakeBulletsIndex, isBulletsGroupActiveByMod, isPairBulletsGroup
} = require("%scripts/weaponry/bulletsInfo.nut")
let { WEAPON_TAG, getLastWeapon, validateLastWeapon, setLastWeapon, checkUnitBullets,
  checkUnitSecondaryWeapons, getLastPrimaryWeapon, getPrimaryWeaponsList,
  getSecondaryWeaponsList, isUnitHaveAnyWeaponsTags, needSecondaryWeaponsWnd,
} = require("%scripts/weaponry/weaponryInfo.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { setDoubleTextToButton, placePriceTextToButton
} = require("%scripts/viewUtils/objectTextUpdate.nut")
let { MODIFICATION_DELAYED_TIER } = require("%scripts/weaponry/weaponryTooltips.nut")
let { weaponsPurchase } = require("%scripts/weaponry/weaponsPurchase.nut")
let { showDamageControl } = require("%scripts/damageControl/damageControlWnd.nut")
let { hasShipDamageControl } = require("%scripts/damageControl/damageControlModule.nut")
let { isShipDamageControlEnabled } = require("%scripts/unit/unitParams.nut")
let { getSavedBullets } = require("%scripts/weaponry/savedWeaponry.nut")
let { promptReqModInstall, needReqModInstall } = require("%scripts/weaponry/checkInstallMods.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { floor } = require("math")
let { getSkinId } = require("%scripts/customization/skinUtils.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { canDoUnlock, isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { defer } = require("dagor.workcycle")
let { get_balance } = require("%scripts/user/balance.nut")
let { addTask } = require("%scripts/tasker.nut")
let nightBattlesOptionsWnd = require("%scripts/events/nightBattlesOptionsWnd.nut")
let { findPlaceForHint, updateHintPosition } = require("%scripts/help/helpInfoHandlerModal.nut")
let { canGoToNightBattleOnUnit, needShowUnseenNightBattlesForUnit,
  markSeenNightBattle } = require("%scripts/events/nightBattlesStates.nut")
let { OPTIONS_MODE_TRAINING, USEROPT_DIFFICULTY } = require("%scripts/options/optionsExtNames.nut")
let { get_meta_mission_info_by_name } = require("guiMission")
let { needShowUnseenModTutorialForUnitMod, markSeenModTutorial,
  startModTutorialMission } = require("%scripts/missions/modificationTutorial.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { isUnitInSlotbar } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { showAirDiscount } = require("%scripts/discounts/discountUtils.nut")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { flushExcessExpToModule } = require("%scripts/unit/unitActions.nut")
let { gui_modal_tutor } = require("%scripts/guiTutorial.nut")
let { currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let { enable_modifications } = require("%scripts/weaponry/weaponryActions.nut")
let { RESEARCHED_MODE_FOR_CHECK } = require ("%scripts/researches/researchConsts.nut")
let { checkNonApprovedResearches } = require("%scripts/researches/researchActions.nut")
let { buildConditionsConfig } = require("%scripts/unlocks/unlocksViewModule.nut")
let { canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")
let { weaponryTypes } = require("%scripts/weaponry/weaponryTypes.nut")
let { getWeaponsForInfantryUnit, infantryWeaponsSlotIdx, createEmptyWeaponSlot,
  getPresetCompositionByName, getSoldiersWeaponsListForPreset, createCustomInfantryPreset,
  createEmptyInfantryPreset, isEmptyPresetAlreadyExist, getPresetSpecialWeapons, getSoldiersCount,
  getWeaponDataByWeaponInfo
} = require("%scripts/weaponry/infantryWeapons.nut")
let { getUnitArmorData, getAppliedArmorForUnit } = require("%scripts/weaponry/infantryArmor.nut")
let { addCustomPreset, deleteCustomPreset } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { isCustomPreset, EMPTY_PRESET_NAME } = require("%scripts/weaponry/weaponryPresets.nut")
let { checkSecondaryWeaponModsRecount, updateUnitAfterSwitchMod
  } = require("%scripts/unit/unitChecks.nut")


local timerPID = dagui_propid_add_name_id("_size-timer")
const HEADER_LEN_PER_CELL = 16

let getCustomTooltipId = @(unitName, mod, params) (mod?.tier ?? 1) > 1 && mod.type == weaponsItem.modification
  ? MODIFICATION_DELAYED_TIER.getTooltipId(unitName, mod.name, params)
  : null

local heightInModCell = @(height) height * 1.0 / to_pixels("1@modCellHeight")





function getSkinMod(unit) {
  local lastSkin = null 
  local highestMaxVal = 0
  local curSkin = null 
  local curSkinProgress = null
  foreach (skinInfo in unit.getSkins()) {
    if (skinInfo.name == "") 
      continue

    let skinId = getSkinId(unit.name, skinInfo.name)
    let skinDecorator = getDecorator(skinId, decoratorTypes.SKINS)
    if (skinDecorator?.unlockBlk == null)
      continue

    let unlockCfg = buildConditionsConfig(skinDecorator.unlockBlk)
    let progress = unlockCfg.getProgressBarData()
    let canDoSkinUnlock = isUnlockVisible(skinDecorator.unlockBlk)
      && !skinDecorator.isUnlocked()
      && canDoUnlock(skinDecorator.unlockBlk)
    if (canDoSkinUnlock) {
      if ((curSkinProgress == null) || (progress.maxVal < curSkinProgress.maxVal)) {
        curSkin = skinDecorator
        curSkinProgress = progress
      }
      continue
    }

    if (progress.maxVal > highestMaxVal) {
      lastSkin = skinDecorator
      highestMaxVal = progress.maxVal
    }
  }

  let decor = curSkin ?? lastSkin
  return decor != null ? {
    name = "skin"
    decor
    canDo = curSkinProgress != null
    progress = curSkinProgress?.value ?? -1
  } : null
}

gui_handlers.WeaponsModalHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  items = null

  wndWidth = 7
  unitSlotCellHeight = 0
  mainModsObj = null
  premiumModsHeight = 0
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
  sceneBlkName = "%gui/weaponry/weapons.blk"
  tierIdPrefix = "tierLine_"

  tooltipOpenTime = -1

  shownTiers = []

  premiumModsList     = null
  bulletsByGroupIndex = null
  expendablesArray    = null

  needCheckTutorial = false
  curEdiff = null
  purchasedModifications = null
  needHideSlotbar = false

  shouldBeRestoredOnMainMenu = false
  isHeaderHidden = false
  offsetCoordsForSecondaryWeapons = null

  openedWeaponDropDownsCount = 0
  needToKeepDropDown = false

  function initScreen() {
    this.setResearchManually = !this.researchMode
    this.mainModsObj = this.scene.findObject("main_modifications")

    showObjById("weaponry_close_btn", !this.researchMode, this.scene)

    this.unitSlotCellHeight = to_pixels("1@slot_height+2@slot_vert_pad")
    this.premiumModsHeight = this.unitSlotCellHeight
      + to_pixels($"{this.researchMode ? 2 : 1}@buttonHeight +1@modCellHeight")

    let imageBlock = this.scene.findObject("researchMode_image_block")
    if (imageBlock?.isValid()) {
      imageBlock.height = $"{heightInModCell(this.premiumModsHeight)}@modCellHeight"
      imageBlock.show(this.researchMode)
    }

    let textSpendExp = loc("mainmenu/spendExcessExp")
    setDoubleTextToButton(this.scene, "btn_spendExcessExp",
      $"{textSpendExp} {loc("currency/researchPoints/sign")}",
      $"{textSpendExp} {loc("currency/researchPoints/sign/colored")}")

    this.airName = unitNameForWeapons.get()
    this.air = getAircraftByName(this.airName)
    this.initMainParams()

    this.initSlotbar()

    if (this.researchMode)
      this.sendModResearchedStatistic(this.air, this.researchBlock?[RESEARCHED_MODE_FOR_CHECK] ?? "")

    this.selectResearchModule()
    this.checkOnResearchCurMod()
    this.showNewbieResearchHelp()
  }

  function initSlotbar() {
    if (this.researchMode || !isUnitInSlotbar(this.air) || this.needHideSlotbar)
      return
    this.createSlotbar({
      crewId = getCrewByAir(this.air).id
      showNewSlot = false
      emptyText = "#shop/aircraftNotSelected"
      afterSlotbarSelect = this.onSlotbarSelect
    })
  }

  function initMainParams() {
    if (!this.air) {
      this.goBack()
      return
    }
    this.curEdiff = this.curEdiff == null ? -1 : this.curEdiff
    this.isOwn = this.air.isUsable()
    this.purchasedModifications = []
    this.updateWeaponsAndBulletsLists()
    this.updateWndWidth()

    let frameObj = this.scene.findObject("mods_frame")
    if (frameObj?.isValid())
      frameObj.width = to_pixels($"{this.wndWidth}@modCellWidth + 1.5@modBlockTierNumHeight $min 1@rw")
    let data = "tdiv { id:t='bg_elems'; position:t='absolute'; inactive:t='yes' }"
    this.mainModsObj.setValue(-1)
    this.guiScene.replaceContentFromText(this.mainModsObj, data, data.len(), this)
    this.modsBgObj = this.mainModsObj.findObject("bg_elems")

    this.items = []
    this.openedWeaponDropDownsCount = 0
    this.needToKeepDropDown = false
    this.fillPage()

    if (isUnitInSlotbar(this.air) && !check_aircraft_tags(this.air.tags, ["bomberview"]))
      if (!this.canBomb(true) && this.canBomb(false))
        this.needCheckTutorial = true

    this.shownTiers = []

    this.updateWindowTitle()
  }

  function addCustomPresetImpl(preset) {
    let unitName = this.airName
    function callback() {
      setLastWeapon(unitName, preset.name)
    }
    addCustomPreset(this.air, preset, callback)
  }

  function changeWeaponForSoldier(weaponItem) {
    local currentPreset = getPresetCompositionByName(this.air, getLastWeapon(this.airName))
    if (!currentPreset)
      return

    let { soldierId, name, slot } = weaponItem

    
    let { specialWeaponsBySoldier, nonUniqeBysoldier } = getSoldiersWeaponsListForPreset(currentPreset)
    if (slot == infantryWeaponsSlotIdx.special && specialWeaponsBySoldier?[soldierId] == name)
      return
    if (slot == infantryWeaponsSlotIdx.nonUniqe && nonUniqeBysoldier?[soldierId] == name)
      return

    if (!isCustomPreset(currentPreset))
      currentPreset = createCustomInfantryPreset(this.air, currentPreset)

    let soldierToChange = currentPreset.soldiers[soldierId]

    let modifyIdx = soldierToChange.weapons.findindex(@(w) w.slot == slot)
    if (modifyIdx == null) {
      soldierToChange.weapons.append({ name, slot })
    }
    else {
      let { minCount, addCurrCount } = getSoldiersCount(this.air, this.curEdiff)
      let availableSoldiersCount = minCount + addCurrCount
      let presetSpecialWeapons = getPresetSpecialWeapons(currentPreset, availableSoldiersCount)
      let oldWeaponName = soldierToChange.weapons[modifyIdx].name
      soldierToChange.weapons[modifyIdx].name = name

      let soldierIdWithSameSpecialWeapon = presetSpecialWeapons?[name]
      if (soldierIdWithSameSpecialWeapon != null) {
        let sameSpecialWeapon = currentPreset.soldiers[soldierIdWithSameSpecialWeapon].weapons.findvalue(@(w) w.slot == slot)
        if (sameSpecialWeapon) {
          sameSpecialWeapon.name = oldWeaponName
        }
      }
    }

    this.needToKeepDropDown = true
    this.addCustomPresetImpl(currentPreset)
  }

  function changeArmorForSoldier(armorItem) {
    let appliedArmor = getAppliedArmorForUnit(this.air)
    if (!appliedArmor || armorItem.name == appliedArmor?.name)
      return
    
    if (armorItem.isDefaultArmor) {
      this.doSwitchMod(appliedArmor, true)
      return
    }
    
    this.doSwitchMod(armorItem, false)
  }

  
  function updateBundleCompositionForPreset(selectorBundleIdx, secondaryWeapons) {
    let bundle = this.items[selectorBundleIdx]
    bundle.itemsList <- secondaryWeapons
  }

  
  
  function updateSelectedItemInBundle(item, presetSpecialWeapons = null) {
    let bundle = item.type == weaponsItem.infantryWeapon ? this.getWeaponBundle(item)
      : this.getItemBundle(item)
    if (!bundle)
      return
    foreach(bundleItem in bundle.itemsList) {
      let selected = bundleItem.name == item.name
      bundleItem.selected <- selected

      local visualDisabled = false
      if (presetSpecialWeapons) {
        if (bundleItem.slot == infantryWeaponsSlotIdx.special)
          visualDisabled = presetSpecialWeapons?[bundleItem.name] != null
            && presetSpecialWeapons[bundleItem.name] != bundleItem.soldierId
        bundleItem.visualDisabled <- visualDisabled
      }

      let bItem = this.items?[bundleItem.guiPosIdx]
      if (bItem && bItem?.name == bundleItem.name) {
        bItem.selected <- selected
        if (presetSpecialWeapons)
          bItem.visualDisabled <- visualDisabled
      }
    }
  }

  function updateWeaponsAndBulletsLists() {
    this.premiumModsList = []
    foreach (mod in this.air.modifications)
      if ((!this.researchMode || canResearchMod(this.air, mod))
          && (isModClassPremium(mod)
              || (mod.modClass == "" && getModificationBulletsGroup(mod.name) == "")
          ))
            this.premiumModsList.append(mod)

    this.lastBullets = []
    this.bulletsByGroupIndex = {}
    for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(this.air); groupIndex++) {
      let bulletsList = getBulletsList(this.air.name, groupIndex, {
        needCheckUnitPurchase = false, needOnlyAvailable = false
      })
      let curBulletsName = getSavedBullets(this.air.name, groupIndex)
      if (groupIndex < this.air.unitType.bulletSetsQuantity)
        this.lastBullets.append(curBulletsName)
      if (!bulletsList.values.len() || bulletsList.duplicate)
        continue
      if (isPairBulletsGroup(bulletsList))
        continue
      this.bulletsByGroupIndex[groupIndex] <- bulletsList
    }
    this.expendablesArray = this.getExpendableModificationsArray(this.air)
  }

  function updateWndWidth() {
    let weaponsAndBulletsLen = 1               
      +(isUnitHaveSecondaryWeapons(this.air) ? 1 : 0) 
      +this.bulletsByGroupIndex.len()
      + this.expendablesArray.len()
    let premiumModsLen = this.premiumModsList.len() + (this.air.spare && !this.researchMode ? 1 : 0)
    this.wndWidth = clamp(max(weaponsAndBulletsLen, premiumModsLen, getModsTreeSize(this.air).guiPosX),
      modsWndWidthRestrictions.min, modsWndWidthRestrictions.max)
  }

  function onSlotbarSelect() {
    let newCrew = this.getCurCrew()
    let newUnit = newCrew ? getCrewUnit(newCrew) : null
    if (!newUnit || newUnit == this.air)
      return

    this.sendModPurchasedStatistic(this.air)
    if (this.getAutoPurchaseValue())
      this.onBuyAll(false, true)

    this.air = newUnit
    this.airName = this.air?.name ?? ""
    unitNameForWeapons.set(this.airName)

    this.initMainParams()
  }

  function checkOnResearchCurMod() {
    if (this.researchMode && !this.isAnyModuleInResearch()) {
      let modForResearch = findAnyNotResearchedMod(this.air)
      if (modForResearch) {
        this.setModificatonOnResearch(modForResearch,
          function() {
            this.updateAllItems()
            let guiPosIdx = getTblValue("guiPosIdx", modForResearch, -1)
            assert(guiPosIdx >= 0, $"missing guiPosIdx, mod - {modForResearch?.name ?? "none"}; unit - {this.air.name}")
            this.selectResearchModule(guiPosIdx >= 0 ? guiPosIdx : 0)
          })
      }
    }
  }

  function selectResearchModule(customPosIdx = -1) {
    local modIdx = customPosIdx
    if (modIdx < 0) {
      let finishedResearch = this.researchBlock?[RESEARCHED_MODE_FOR_CHECK] ?? "CdMin_Fuse"
      foreach (item in this.items)
        if (isModInResearch(this.air, item)) {
          modIdx = item.guiPosIdx
          break
        }
        else if (item.name == finishedResearch)
          modIdx = item.guiPosIdx
    }

    if (checkObj(this.mainModsObj) && modIdx >= 0)
      this.mainModsObj.setValue(modIdx + 1)
  }

  function updateWindowTitle() {
    let titleObj = this.scene.findObject("wnd_title")
    if (!checkObj(titleObj))
      return

    local titleText = " ".concat(loc("mainmenu/btnWeapons"), loc("ui/mdash"), getUnitName(this.air))
    if (this.researchMode) {
      let modifName = this.researchBlock?[RESEARCHED_MODE_FOR_CHECK] ?? "CdMin_Fuse"
      titleText = loc("modifications/finishResearch",
        { modName = getModificationName(this.air, modifName) })
    }
    titleObj.setValue(titleText)
  }

  function hideFrameHeader(frameObj) {
    frameObj.isHeaderHidden = "yes"

    showObjById("close_alt_btn", !this.researchMode, this.scene)

    let researchModeImgObj = this.scene.findObject("researchMode_image_block")
    researchModeImgObj["pos"] = researchModeImgObj["posWithoutHeader"]

    this.scene.findObject("overflow-div")["top"] = "-1@frameHeaderHeight"

    let progressBlock = this.scene.findObject("progressMods")
    if (progressBlock.isValid()) {
      progressBlock["top"] = "-1@frameHeaderHeight"
      progressBlock["margin-bottom"] = "1@frameHeaderHeight"
    }
  }

  function updateWindowHeightAndPos() {
    let frameObj = this.scene.findObject("mods_frame")
    if (!frameObj.isValid())
      return

    if (this.isHeaderHidden) {
      this.hideFrameHeader(frameObj)
      return
    }

    let frameHeight = frameObj.getSize()[1]
    let maxFrameHeight = toPixels(this.guiScene, "@maxWeaponsWindowHeight")

    if (frameHeight <= maxFrameHeight) {
      this.scene.findObject("overflow-div")["top"] = "0"
      return
    }

    let frameHeaderHeight = toPixels(this.guiScene, "@frameHeaderHeight")
    if (frameHeight - frameHeaderHeight < maxFrameHeight) {
      this.hideFrameHeader(frameObj)
      this.isHeaderHidden = true
    }
    else {
      this.needHideSlotbar = true
      frameObj["pos"] = frameObj["posWithoutSlotbar"]
    }
  }

  function updateWeaponsDropDownBackdropPos() {
    let frameObj = this.scene.findObject("mods_frame")
    if (!frameObj.isValid())
      return
    let weaponsRowObj = this.scene.findObject("weapons")
    if (!weaponsRowObj?.isValid())
      return
    let backdrop = this.scene.findObject("dropdown-backdrop")
    backdrop.top = weaponsRowObj.getPos()[1] - frameObj.getPos()[1]
  }

  function showNewbieResearchHelp() {
    if (!this.researchMode || !tutorialModule.needShowTutorial("researchMod", 1))
      return

    tutorialModule.saveShowedTutorial("researchMod")

    let finMod = this.researchBlock?[RESEARCHED_MODE_FOR_CHECK] ?? ""
    let newMod = shop_get_researchable_module_name(this.airName)

    let finIdx = this.getItemIdxByName(finMod)
    let newIdx = this.getItemIdxByName(newMod)

    if (finIdx < 0 || newIdx < 0)
      return

    let newModName = getModificationName(this.air, this.items[newIdx].name, true)
    let steps = [
      {
        obj = [$"item_{newIdx}"]
        text = loc("help/newModification", { modName = newModName })
        nextActionShortcut = "help/OBJ_CLICK"
        actionType = tutorAction.OBJ_CLICK
        shortcut = GAMEPAD_ENTER_SHORTCUT
        cb = @() this.setModificatonOnResearch(this.items[newIdx], @() this.updateAllItems())
      },
      {
        obj = ["available_free_exp_text"]
        text = loc("help/FreeExp")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = GAMEPAD_ENTER_SHORTCUT
      }
    ]

    let finItem = this.items[finIdx]
    let balance = Cost()
    balance.setFromTbl(get_balance())
    if (getItemAmount(this.air, finItem) < 1 && getItemCost(this.air, finItem) <= balance) {
      let finModName = getModificationName(this.air, this.items[finIdx].name, true)
      steps.insert(0,
        {
          obj = [$"item_{finIdx}"]
          text = loc("help/finishedModification", { modName = finModName })
          nextActionShortcut = "help/OBJ_CLICK"
          actionType = tutorAction.OBJ_CLICK
          shortcut = GAMEPAD_ENTER_SHORTCUT
          cb = @() this.checkAndBuyWeaponry(finItem)
        })
    }

    gui_modal_tutor(steps, this)
  }

  function fillPage() {
    this.guiScene.setUpdatesEnabled(false, false)
    this.createItem(this.wrapUnitToItem(this.air), weaponsItem.curUnit, this.mainModsObj, 0.0, 0.0)
    this.fillModsTree()
    this.fillPremiumMods()
    this.fillWeaponsAndBullets()

    this.updateAllItems()
    this.guiScene.setUpdatesEnabled(true, true)
    this.updateWindowHeightAndPos()
    this.updateWeaponsDropDownBackdropPos()
  }

  function fillAvailableRPText() {
    if (!this.researchMode)
      return

    this.availableFlushExp = shop_get_unit_excess_exp(this.airName)
    let freeRPObj = this.scene.findObject("available_free_exp_text")
    if (checkObj(freeRPObj))
      freeRPObj.setValue(get_flush_exp_text(this.availableFlushExp))
  }

  function automaticallySpendAllExcessiveExp() { 
    this.showTaskProgressBox()
    this.availableFlushExp = shop_get_unit_excess_exp(this.airName)
    let curResModuleName = shop_get_researchable_module_name(this.airName)

    if (this.availableFlushExp <= 0 || curResModuleName == "") {
      let afterDoneFunc = function() {
        this.destroyProgressBox()
        this.updateAllItems()
        this.goBack()
      }

      this.setModificatonOnResearch(getModificationByName(this.air, curResModuleName), afterDoneFunc)
      return
    }

    this.flushItemExp(curResModuleName, this.automaticallySpendAllExcessiveExp)
  }

  function onEventUnitResearch(_params) {
    this.updateAllItems()
  }

  function onEventUnitBought(_params) {
    this.isOwn = this.air.isUsable()
    this.updateAllItems()
  }

  function onEventUnitRented(params) {
    this.onEventUnitBought(params)
  }

  function onEventExpConvert(_params) {
    this.updateAllItems()
  }

  function onEventUnitRepaired(_params) {
    foreach (idx, item in this.items)
      if (this.isItemTypeUnit(item.type))
        return this.updateItem(idx)
  }

  function onEventModificationPurchased(params) {
    let modName = params?.modName
    if (modName)
      this.purchasedModifications.append(modName)

    this.updateAllItems()
    this.updateBulletsWarning()
  }
  function onEventWeaponPurchased(_params) {
    this.updateAllItems()
    this.updateWeaponsWarning()
  }
  function onEventSparePurchased(_params) { this.updateAllItems() }
  function onEventSlotbarPresetLoaded(_params) { this.onSlotbarSelect() }
  function onEventCrewsListChanged(_params) { this.onSlotbarSelect() }

  function createEmptyPresetItem() {
    return { name = EMPTY_PRESET_NAME }
  }

  function forceCloseDropDownBackdrop() {
    if (this.needToKeepDropDown)
      return
    this.openedWeaponDropDownsCount = 0
    showObjById("dropdown-backdrop", false, this.scene)
  }

  
  function rebuildSecondaryWeaponsSelector() {
    if (!isUnitHaveSecondaryWeapons(this.air) || needSecondaryWeaponsWnd(this.air))
      return
    foreach (item in this.items) {
      if (item.type != weaponsItem.weapon)
        continue
      let itemObj = this.getItemObj(item.guiPosIdx)
      if (itemObj?.isValid())
        this.guiScene.destroyElement(itemObj)
    }

    let selectorBundleIdx = this.getPresetsSelectorBundleIdx()
    if (selectorBundleIdx < 0)
      return

    let selectorBundle = this.items[selectorBundleIdx]
    let bundleObj = this.getItemObj(selectorBundle.guiPosIdx)
    if (bundleObj?.isValid()) {
      this.guiScene.destroyElement(bundleObj)
      this.forceCloseDropDownBackdrop()
    }

    let lastWeapon = getLastWeapon(this.airName)
    let secondaryWeapons = getSecondaryWeaponsList(this.air)
      .map(function(w) {
        w.selected <- w.name == lastWeapon
        return w
      })
    if (this.air.isHuman())
      secondaryWeapons.append(this.createEmptyPresetItem())
    this.updateBundleCompositionForPreset(selectorBundleIdx, secondaryWeapons)
    let { offsetX, offsetY } = this.offsetCoordsForSecondaryWeapons
    if (secondaryWeapons.len())
      this.createBundle(secondaryWeapons, weaponsItem.weapon, 0, this.mainModsObj, offsetX, offsetY)
  }

  
  function updateWeaponBundlesForSelectedPreset() {
    let currentPreset = getPresetCompositionByName(this.air, this.lastWeapon)
    if (!currentPreset)
      return

    let { minCount, addCurrCount } = getSoldiersCount(this.air, this.curEdiff)
    let availableSoldiersCount = minCount + addCurrCount
    let presetSpecialWeapons = getPresetSpecialWeapons(currentPreset, availableSoldiersCount)

    foreach (soldier in currentPreset.soldiers) {
      let soldierIndex = soldier.index
      if (soldierIndex >= availableSoldiersCount)
        break
      foreach (weapon in soldier.weapons) {
        let weaponItem = this.items.findvalue(@(i) i.name == weapon.name
          && i?.soldierId == soldierIndex
          && i?.slot == weapon.slot)
        if (!weaponItem)
          continue
        this.updateSelectedItemInBundle(weaponItem, presetSpecialWeapons)
      }
    }
    let disabledWeaponItems = this.items.filter(@(i) i?.disabledWeaponItem)
    foreach (disabledItem in disabledWeaponItems) {
      let { soldierId, slot } = disabledItem
      let newDisabledWeapon = currentPreset.soldiers?[soldierId].weapons.findvalue(@(w) w.slot == slot)
      if (!newDisabledWeapon)
        continue
      
      let { name, image = "" } = getWeaponDataByWeaponInfo(this.air, newDisabledWeapon) ?? createEmptyWeaponSlot(slot)
      disabledItem.name = name
      disabledItem.image = image
    }
  }

  function onEventUnitWeaponChanged(params = {}) {
    let { weaponName = "" } = params
    if (this.getPresetsSelectorBundleIdx() && weaponName != this.lastWeapon) {
      this.lastWeapon = getLastWeapon(this.airName)
      this.updateWeaponBundlesForSelectedPreset()
    }
    this.updateAllItems()

    if (!isUnitHaveSecondaryWeapons(this.air) || !needSecondaryWeaponsWnd(this.air))
      return

    this.lastWeapon = getLastWeapon(this.airName)
    let secondaryWeapons = getSecondaryWeaponsList(this.air)
    let selWeapon = secondaryWeapons.findvalue((@(w) w.name == this.lastWeapon).bindenv(this))
    if (selWeapon == null)
      return

    foreach (idx, item in this.items)
      if (item.type == weaponsItem.weapon) {
        this.items[idx] = selWeapon
        this.updateItem(idx)
        return
      }
  }

  function onEventCustomPresetChanged(params) {
    let { presetId = "", unitName } = params
    if (unitName != this.airName)
      return

    this.updateWeaponBundlesForSelectedPreset()
    this.rebuildSecondaryWeaponsSelector()
    if (presetId == this.lastWeapon)
      this.updateAllItems()
  }

  function onEventCustomPresetRemoved(params) {
    let { unitName } = params
    if (unitName != this.airName)
      return

    this.rebuildSecondaryWeaponsSelector()

    if (this.getPresetsSelectorBundleIdx()) {
      this.lastWeapon = getLastWeapon(this.airName)
      this.updateWeaponBundlesForSelectedPreset()
    }
    this.updateAllItems()
  }

  function onEventUnitBulletsChanged(_params) {
    this.updateAllItems()
  }

  function isItemTypeUnit(iType) {
    return iType == weaponsItem.curUnit
  }

  function addItemToList(item, iType) {
    let existedIdx  =
      iType == weaponsItem.weapon ? this.items.findindex(@(i) i.type == weaponsItem.weapon && i.name == item.name)
      : iType == weaponsItem.bundle && item?.itemsType == weaponsItem.weapon ? this.getPresetsSelectorBundleIdx()
      : null

    let idx = existedIdx ?? this.items.len()

    item.type <- iType
    item.guiPosIdx <- idx

    if(existedIdx == null)
      this.items.append(item)
    return $"item_{idx}"
  }

  function createItem(item, iType, holderObj, posX, posY, itemWidth = null) {
    let id = this.addItemToList(item, iType)

    if (this.isItemTypeUnit(iType))
      return this.createUnitItemObj(id, item, holderObj, posX, posY)

    if (iType == weaponsItem.skin)
      return createModItem(id, this.air, item, iType, holderObj, this, { posX, posY })

    let currentEdiff = this.getCurrentEdiff()
    return createModItem(id, this.air, item, iType, holderObj, this, {
      posX, posY
      curEdiff = currentEdiff
      tooltipId = getCustomTooltipId(this.air.name, item, { curEdiff = currentEdiff })
      itemWidth
    })
  }

  function createItemLayout(item, iType, posX, posY) {
    let id = this.addItemToList(item, iType)
    if (iType == weaponsItem.skin)
      return createModItemLayout(id, this.air, item, iType, { posX, posY })

    let currentEdiff = this.getCurrentEdiff()
    return createModItemLayout(id, this.air, item, iType, {
      posX, posY
      curEdiff = currentEdiff
      tooltipId = getCustomTooltipId(this.air.name, item, { curEdiff = currentEdiff })
      researchFinished = this?.researchBlock.prevMod == item.name
      isModeEnabledFn = @() shopIsModificationEnabled(this.air.name, item.name)
    })
  }

  function wrapUnitToItem(unit) {
    return {
      name = unit.name
      unit = unit
    }
  }

  function createUnitItemObj(id, _item, holderObj, posX, posY) {
    let blockObj = this.guiScene.createElementByObject(holderObj, "%gui/weaponry/nextUnitItem.blk", "weapon_item_unit", this)
    let titleObj = blockObj.findObject("nextResearch_title")
    titleObj.setValue(this.researchMode ? loc("mainmenu/nextResearch/title") : "")

    local position = $"{posX + 0.5}@modCellWidth-0.5w, {posY + 0.5}@modCellHeight-0.5h"
    if (this.researchMode)
      position = $"{posX + 0.5}@modCellWidth-0.5w, 1@framePadding+ 1@fadedImageFramePad"

    blockObj.pos = position
    local unitObj = blockObj.findObject("next_unit")
    unitObj.id = id
    return unitObj
  }

  function createItemLayoutForBundle(id, unit, item, iType, params = {}) {
    if (params?.supportUnitName)
      item.supportUnitName <- params.supportUnitName
    id = this.addItemToList(item, iType)
    return {
      itemId = id
      itemLayout = createModItemLayout(id, unit, item, iType, params)
    }
  }

  function createBundle(itemsList, itemsType, subType, holderObj, posX, posY, supportUnitName = null) {
    let id = itemsType == weaponsItem.weapon
      ? this.getPresetsSelectorBundleIdx() ?? this.items.len()
      : this.items.len()
    createModBundle($"bundle_{id}", this.air, itemsList, itemsType, holderObj, this,
      { posX = posX, posY = posY, subType = subType,
        maxItemsInColumn = 5,
        createItemLayoutFunc = this.createItemLayoutForBundle
        cellSizeObj = this.scene.findObject("cell_size")
        curEdiff = this.getCurrentEdiff()
        supportUnitName
      })
  }

  function getItemObj(idx) {
    return this.scene.findObject($"item_{idx}")
  }

  function updateItem(idx) {
    let itemObj = this.getItemObj(idx)
    if (!checkObj(itemObj) || !(idx in this.items))
      return

    let item = this.items[idx]
    if (item.type == weaponsItem.skin)
      return
    if (this.isItemTypeUnit(item.type))
      return this.updateUnitItem(item, itemObj)

    local isVisualDisabled = false
    local visualItem = item
    if (item.type == weaponsItem.bundle)
      visualItem = getBundleCurItem(this.air, item) || visualItem
    if (isBullets(visualItem))
      isVisualDisabled = !isBulletsGroupActiveByMod(this.air, visualItem)
    else if (item?.visualDisabled != null)
      isVisualDisabled = item.visualDisabled

    let isBundle = item.type == weaponsItem.bundle
    let actionBtnText = isBundle && showConsoleButtons.get() ? loc("mainmenu/btnAirGroupOpen")
      : (item.type == weaponsItem.weapon && needSecondaryWeaponsWnd(this.air)) ? loc("item/open")
      : null
    let hasMenu = isBundle || actionBtnText != null
    let currentEdiff = this.getCurrentEdiff()
    updateModItem(this.air, item, itemObj, true, this, {
      canShowResearch = this.availableFlushExp == 0 && this.setResearchManually
      flushExp = this.availableFlushExp
      researchMode = this.researchMode
      visualDisabled = isVisualDisabled
      hideStatus = hasMenu
      hasMenu
      actionBtnText
      curEdiff = currentEdiff
      tooltipId = getCustomTooltipId(this.air.name, item, {
        curEdiff = currentEdiff
      })
      researchFinished = this?.researchBlock.prevMod == item.name && this.lastResearchMod == null
      isModeEnabledFn = @() shopIsModificationEnabled(this.air.name, item.name)
    })
  }

  function updateBuyAllButton() {
    let canBuyAll = isUnitUsable(this.air) && hasFeature("BuyAllModifications")
    if (!canBuyAll) {
      showObjById("btn_buyAll", false, this.scene)
      showObjById("btn_buyAllResearched", false, this.scene)
      return
    }

    let costResearched = getAllModsCost(this.air)
    let isVisibleBuyAllResearched = !costResearched.isZero()
    showObjById("btn_buyAllResearched", isVisibleBuyAllResearched, this.scene)
    if (isVisibleBuyAllResearched) {
      placePriceTextToButton(this.scene, "btn_buyAllResearched", loc("mainmenu/btnBuyAllResearched"), costResearched)
      showObjById("btn_buyAll", false, this.scene)
      return
    }

    let costAll = getAllModsCost(this.air, true)
    let isVisibleBuyAll = !costAll.isZero()
    showObjById("btn_buyAll", isVisibleBuyAll, this.scene)
    if (isVisibleBuyAll)
      placePriceTextToButton(this.scene, "btn_buyAll", loc("mainmenu/btnBuyAll"), costAll)
  }

  function updateAllItems() {
    if (!this.isValid())
      return

    this.fillAvailableRPText()
    for (local i = 0; i < this.items.len(); i++)
      this.updateItem(i)
    let treeSize = getModsTreeSize(this.air)
    this.updateTiersStatus(treeSize)
    this.updateButtons()
    this.updateBuyAllButton()
    this.updateBonuses()
  }

  function updateBonuses() {
    let tree = generateModsTree(this.air)

    local bonuses = null
    foreach(branch in tree) {
      if (branch == null || branch.len() == 0 || type(branch[0]) != "string")
        continue
      if (branch[0] == "bonus") {
        bonuses = branch
        break
      }
    }

    if (bonuses == null)
      return

    foreach(bonus in bonuses) {
      if (type(bonus) == "string")
        continue

      let bonusObj = this.scene.findObject(bonus.id)
      bonusObj["tooltip"] = bonus.tooltip
      bonusObj.findObject("progressCurrent")["width"] = $"{bonus.progress}pw"
      bonusObj.findObject("favoriteImg")["display"] = bonus.isBonusReceived ? "show" : "hide"
      bonusObj.findObject("bonusText").setValue(bonus.isBonusReceived ?
        loc("modification/bonusReceived") :
        bonus.bonus)
    }
    this.updateProgressStatus()
  }

  function updateButtons() {
    let isAnyModInResearch = this.isAnyModuleInResearch()
    showObjById("btn_exit", this.researchMode && (!isAnyModInResearch || this.availableFlushExp <= 0 || this.setResearchManually), this.scene)
    showObjById("btn_spendExcessExp", this.researchMode && isAnyModInResearch && this.availableFlushExp > 0, this.scene)

    let checkboxObj = this.scene.findObject("auto_purchase_mods")
    if (checkObj(checkboxObj)) {
      checkboxObj.show(this.isOwn)
      if (this.isOwn)
        checkboxObj.setValue(get_auto_buy_modifications())
    }

    showObjById("btn_damage_control", this.air.isShipOrBoat() && hasFeature("DamageControl")
      && isShipDamageControlEnabled(this.air) && hasShipDamageControl(this.air.name), this.scene);
  }

  function updateUnitItem(item, itemObj) {
    let params = {
      slotbarActions = this.airActions
      getEdiffFunc  = this.getCurrentEdiff.bindenv(this)
    }
    let unitBlk = buildUnitSlot("unit_item", item.unit, params)
    this.guiScene.replaceContentFromText(itemObj, unitBlk, unitBlk.len(), this)
    itemObj.tooltipId = getTooltipType("UNIT").getTooltipId(item.unit.name, params)
    fillUnitSlotTimers(itemObj.findObject("unit_item"), item.unit)
  }

  function isAnyModuleInResearch() {
    let module = shop_get_researchable_module_name(this.airName)
    if (module == "")
      return false

    let moduleData = getModificationByName(this.air, module)
    if (!moduleData || isModResearched(this.air, moduleData))
      return false

    return !isModClassPremium(moduleData)
  }

  function updateItemBundle(item) {
    let bundle = this.getItemBundle(item)
    if (!bundle)
      this.updateItem(item.guiPosIdx)
    else {
      this.updateItem(bundle.guiPosIdx)
      foreach (bitem in bundle.itemsList)
        this.updateItem(bitem.guiPosIdx)
    }
  }

  function createTreeItems(obj, branch, treeOffsetY = 0) {
    let branchItems = this.collectBranchItems(branch, [])
    branchItems.sort(@(a, b) a.tier <=> b.tier || a.guiPosY <=> b.guiPosY || a.guiPosX <=> b.guiPosX)
    local data = ""
    foreach (item in branchItems)
      data = "\n".concat(data,
        this.createItemLayout(item, weaponsItem.modification, item.guiPosX,
          item.guiPosY + treeOffsetY))

    if (data == "")
      return

    this.guiScene.appendWithBlk(obj, data, this)
  }

  function collectBranchItems(branch, resItems) {
    foreach (_idx, item in branch)
      if (type(item) == "table") 
        resItems.append(item)
      else if (type(item) == "array") 
        this.collectBranchItems(item, resItems)
    return resItems
  }

  function createTreeBlocks(obj, columnsList, height, treeOffsetX, treeOffsetY, blockType = "", tiersConfig = null, headerId = null) {
    let fullWidth = this.wndWidth - treeOffsetX
    let view = {
      width = fullWidth
      height = height
      offsetX = treeOffsetX
      offsetY = treeOffsetY
      columnsList = columnsList
      rows = []
      rowType = blockType
      id = headerId
    }

    if (columnsList.len()) {
      local headerWidth = 0
      foreach (idx, column in columnsList) {
        column.needDivLine <- idx > 0
        headerWidth += column.width
        if (column.name && utf8_strlen(column.name) > HEADER_LEN_PER_CELL * column.width)
          column.isSmallFont <- true
      }

      
      let widthDiff = fullWidth - headerWidth
      if (widthDiff > 0)
        columnsList[columnsList.len() - 1].width += widthDiff
    }

    let needTierArrows = tiersConfig != null
    let { sizeByTier = {} , blockIdPrefix = "" } = tiersConfig
    let hasSeveralRowsOnTier = sizeByTier.len() > 0
    let rowsCount = hasSeveralRowsOnTier ? sizeByTier.len() - 1 : height
    for (local i = 1; i <= rowsCount; i++) {
      let row = {
        width = fullWidth
        top = i - 1
      }

      if (needTierArrows) {
        let { tierHeight = 1, offsetY = null } = sizeByTier?[i]
        let arrowHeight = sizeByTier?[i - 1].tierHeight ?? 1
        row.__update({
          id = $"{blockIdPrefix}{i}",
          needTierArrow = i > 1,
          tierText = get_roman_numeral(i),
          tierHeight,
          arrowHeight,
          top = offsetY || row.top,
          needDivLine = hasSeveralRowsOnTier && i > 1
        })
      }

      view.rows.append(row)
    }

    let data = handyman.renderCached("%gui/weaponry/weaponryBg.tpl", view)
    if (data != "")
      this.guiScene.appendWithBlk(obj, data, this)
  }

  function createTreeArrows(obj, arrowsList, treeOffsetY) {
    let data = []
    foreach (idx, a in arrowsList) {
      let id = $"arrow_{idx}"

      if (a.from[0] != a.to[0]) 
        data.append(format("".concat("modArrow { id:t='%s'; type:t='right'; ",
                         "pos:t='%.1f@modCellWidth-0.5@modArrowLen, %.1f@modCellHeight-0.5h'; ",
                         "width:t='@modArrowLen + %.1f@modCellWidth' ",
                       "}"),
                       id, a.from[0] + 1, a.from[1] - 0.5 + treeOffsetY + 1, a.to[0] - a.from[0] - 1
                      ))
      else if (a.from[1] != a.to[1]) 
        data.append(format("".concat("modArrow { id:t='%s'; type:t='down'; ",
                         "pos:t='%.1f@modCellWidth-0.5w, %.1f@modCellHeight-0.5@modArrowLen'; ",
                         "height:t='@modArrowLen + %.1f@modCellHeight' ",
                       "}"),
                       id, a.from[0] + 0.5, a.from[1] + treeOffsetY + 1, a.to[1] - a.from[1] - 1
                      ))
    }
    if (data.len() > 0)
      this.guiScene.appendWithBlk(obj, "".join(data), this)
  }

  function fillModsTree() {
    let treeOffsetY = heightInModCell(to_pixels("1@frameHeaderHeight") + this.premiumModsHeight)
    let tree = generateModsTree(this.air)
    if (!tree)
      return

    let treeSize = getModsTreeSize(this.air)
    if (treeSize.guiPosX > this.wndWidth)
      logerr($"Modifications: {this.air.name} too much modifications in a row")
    this.mainModsObj.size = format("%.1f@modCellWidth, %.1f@modCellHeight",
      this.wndWidth, treeSize.guiPosY + treeOffsetY)
    if (!(treeSize.guiPosY > 0))
      return

    let { blocks, arrows, sizeByTier } = generateModsBgElems(this.air)
    let tiersConfig = { sizeByTier, blockIdPrefix = this.tierIdPrefix }
    this.createTreeBlocks(this.modsBgObj, blocks, treeSize.guiPosY, 0, treeOffsetY,
      "unlocked", tiersConfig)
    this.createTreeArrows(this.modsBgObj, arrows, treeOffsetY)
    this.createTreeItems(this.mainModsObj, tree, treeOffsetY)
    if (treeSize.guiPosX > this.wndWidth)
      this.scene.findObject("overflow-div")["overflow-x"] = "auto"
    this.updateProgressStatus()
  }

  function updateProgressStatus() {
    if(commonProgressMods.hasSummary == false) {
      this.scene.findObject("progressMods").show(false)
      return
    }
    this.scene.findObject("progressMods").show(true)
    let earnedExp = Cost().setRp(commonProgressMods.earnedExp).toStringWithParams({ isRpAlwaysShown = true })
    let reqExp = Cost().setRp(commonProgressMods.reqExp).toStringWithParams({ isRpAlwaysShown = true })
    let progress = $"{floor(100 * commonProgressMods.progress)}%"
    this.scene.findObject("progressModsText").setValue(commonProgressMods.progress < 1 ?
      loc("modification/progressModsText", { earnedExp, reqExp }) :
      loc("modification/progressModsAllResearchedText"))
    this.scene.findObject("progressModsPercent").setValue(progress)
    let thumbWidth = 60
    this.scene.findObject("progressModsTrack")["width"] = $"{commonProgressMods.progress}(pw - {thumbWidth}@sf/@pf) + {thumbWidth/2}@sf/@pf"
  }

  function updateTiersStatus(size) {
    let tiersArray = this.getResearchedModsArray(size.tier)
    for (local i = 1; i <= size.tier; i++) {
      if (tiersArray[i - 1] == null) {
        assert(false, $"Missing modifications for unit '{this.air.name}' in tier {i}, but there are higher tiers")
        break
      }
      let unlocked = isWeaponTierAvailable(this.air, i)
      this.scene.findObject($"{this.tierIdPrefix}{i}").type = unlocked ? "unlocked" : "locked"

      let tierIdStr = $"{this.tierIdPrefix}{i + 1}"
      let jObj = this.scene.findObject(tierIdStr)
      if (checkObj(jObj)) {
        let modsCountObj = jObj.findObject($"{tierIdStr}_txt")
        let countMods = tiersArray[i - 1].researched
        let reqMods = this.air.needBuyToOpenNextInTier[i - 1]
        if (countMods >= reqMods)
          if (!unlocked) {
            modsCountObj.setValue($"{countMods}{loc("weapons_types/short/separator")}{reqMods}")
            let tooltipText = $"<color=@badTextColor>{loc("weaponry/unlockTier/reqPrevTiers")}</color>"
            modsCountObj.tooltip = $"{loc("weaponry/unlockTier/countsBlock/startText")}\n{tooltipText}"
            jObj.tooltip = tooltipText
          }
          else {
            modsCountObj.setValue("")
            modsCountObj.tooltip = ""
            jObj.tooltip = ""
          }
        else {
          modsCountObj.setValue($"{countMods}{loc("weapons_types/short/separator")}{reqMods}")
          let req = reqMods - countMods

          let tooltipText = loc("weaponry/unlockTier/tooltip",
            { amount = req, tier = get_roman_numeral(i + 1) })
          jObj.tooltip = tooltipText
          modsCountObj.tooltip = $"{loc("weaponry/unlockTier/countsBlock/startText")}\n{tooltipText}"
        }
      }
    }
  }

  function getResearchedModsArray(tiersCount) {
    local tiersArray = []
    if ("modifications" in this.air && tiersCount > 0) {
      tiersArray = array(tiersCount, null)
      foreach (mod in this.air.modifications) {
        if (!isModificationInTree(this.air, mod))
          continue

        let idx = mod.tier - 1
        tiersArray[idx] = tiersArray[idx] ?? { researched = 0, notResearched = 0 }

        if (isModResearched(this.air, mod))
          tiersArray[idx].researched++
        else
          tiersArray[idx].notResearched++
      }
    }
    return tiersArray
  }

  function fillPremiumMods() {
    if (!hasFeature("SpendGold"))
      return

    let offsetX = this.researchMode ? 0 : 1.0
    let offsetY = this.researchMode
      ? heightInModCell(this.premiumModsHeight - to_pixels("1@modCellHeight + 1@blockInterval"))
      : 0
    local nextX = offsetX
    local data = ""
    if (this.air.spare && !this.researchMode)
      data = "\n".concat(data, this.createItemLayout(this.air.spare, weaponsItem.spare, nextX++, offsetY))
    foreach (mod in this.premiumModsList)
      data = "\n".concat(data, this.createItemLayout(mod, weaponsItem.modification, nextX++, offsetY))

    if (this.researchMode) {
      if (data != "")
        this.guiScene.appendWithBlk(this.mainModsObj, data, this)
      return
    }

    let skinMod = getSkinMod(this.air)
    if (skinMod)
      data = "\n".concat(data, this.createItemLayout(skinMod, weaponsItem.skin, nextX, offsetY))

    if (data != "")
      this.guiScene.appendWithBlk(this.mainModsObj, data, this)

    let columnsList = [this.getWeaponsColumnData()]
    this.createTreeBlocks(this.modsBgObj, columnsList, 1, offsetX, offsetY)
  }

  function getWeaponsColumnData(name = null, width = 1, tooltip = "") {
    return { name = name
        width = width
        tooltip = tooltip
      }
  }

  function getExpendableModificationsArray(unit) {
    if (!("modifications" in unit))
      return []

    return unit.modifications.filter(isModClassExpendable)
  }

  function getModifiedSoldierWeaponsArray(weaponsArray, currSoldiertWeapon, slotIdx, index, presetSpecialWeapons = {}) {
    let modifiedWeaponsArray = deep_clone(weaponsArray)
      .append(createEmptyWeaponSlot(slotIdx))
      .map(function(sw, idx) {
        if (!currSoldiertWeapon && idx == 0)
          sw.selected <- true
        if (!!currSoldiertWeapon && sw?.name == currSoldiertWeapon.name)
          sw.selected <- true
        sw.soldierId <- index
        sw.customNameText <- loc($"weapons/{sw.name}")
        sw.visualDisabled <- presetSpecialWeapons?[sw.name] != null && presetSpecialWeapons[sw.name] != index
        return sw
      })
    return modifiedWeaponsArray
  }

  function getDisabledWeaponForSoldier(weaponItem, soldierId) {
    let { slot, name, image ="" } = weaponItem
    let disabledWeaponItem = {
      slot
      name
      soldierId
      amount = 0
      selected = false
      visualDisabled = true
      type = weaponsItem.infantryWeapon
      image
      customNameText = ""
      hideNameTextAndCenterIcon = true
      disabledWeaponItem = true
    }
    return disabledWeaponItem
  }

  function getModifiedArmorsArray(armorArray) {
    let appliedArmorName = getAppliedArmorForUnit(this.air)?.name ?? ""
    let modifiedArmorArray = armorArray.map(@(armorData) armorData.__merge({
        selected = armorData.name == appliedArmorName
        customNameText = loc($"modification/{armorData.name}")
      })
    )
    return modifiedArmorArray
  }

  function fillWeaponsAndBullets() {
    if (this.researchMode)
      return

    local offsetX = 0
    let offsetY = heightInModCell(to_pixels("1@buttonHeight+1@modCellHeight+1@blockInterval"))
    let columnsList = []
    if (!this.air.isHuman()) {
      
      let primaryWeaponsList = []
      foreach (_i, modName in getPrimaryWeaponsList(this.air)) {
        let mod = (modName == "") ? null : getModificationByName(this.air, modName)
        let item = { name = modName, weaponMod = mod }

        if (mod) {
          mod.isPrimaryWeapon <- true
          item.reqModification <- [modName]
        }
        else {
          item.image <- this.air.commonWeaponImage
          if ("weaponUpgrades" in this.air)
            item.weaponUpgrades <- this.air.weaponUpgrades
        }
        primaryWeaponsList.append(item)
      }
      this.createBundle(primaryWeaponsList, weaponsItem.primaryWeapon, 0, this.mainModsObj, offsetX, offsetY)
      columnsList.append(this.getWeaponsColumnData(loc("options/primary_weapons")))
      offsetX++
    }

    
    let unitArmorData = getUnitArmorData(this.air)
    if (unitArmorData.len()) {
      let modifiedArmorData = this.getModifiedArmorsArray(unitArmorData)
      this.createBundle(modifiedArmorData, weaponsItem.infantryArmor, 0, this.mainModsObj, offsetX, offsetY)
      columnsList.append(this.getWeaponsColumnData(loc("modification/category/protection")))
      offsetX+=1
    }

    
    let currentPreset = getPresetCompositionByName(this.air, getLastWeapon(this.airName))
    if (currentPreset) {
      let { specialWeapons, nonUniqe } = getWeaponsForInfantryUnit(this.air)
      let { minCount, maxCount, addCurrCount } = getSoldiersCount(this.air, this.curEdiff)
      let availableSoldiersCount = minCount + addCurrCount
      let presetSpecialWeapons = getPresetSpecialWeapons(currentPreset, availableSoldiersCount)
      for (local i = 0; i < currentPreset.soldiers.len(); i++) {
        if (i >= maxCount)
          break

        let { index, weapons } = currentPreset.soldiers[i]

        let currSoldierSpecWeapon = weapons.findvalue(@(w) w.slot == infantryWeaponsSlotIdx.special)
        let specialWeaponsModified = this.getModifiedSoldierWeaponsArray(
          specialWeapons, currSoldierSpecWeapon, infantryWeaponsSlotIdx.special, index, presetSpecialWeapons)
        if (i >= availableSoldiersCount) {
          let currSelectedSpecWeapon = specialWeaponsModified.findvalue(@(w) w?.selected) ?? createEmptyWeaponSlot(infantryWeaponsSlotIdx.special)
          this.createItem(this.getDisabledWeaponForSoldier(currSelectedSpecWeapon, index), weaponsItem.infantryWeapon, this.mainModsObj, offsetX, offsetY, 0.5)
        }
        else
          this.createBundle(specialWeaponsModified, weaponsItem.infantryWeapon, 0, this.mainModsObj, offsetX, offsetY)
        offsetX+=0.5

        let currSoldierNonUniqWeapon = weapons.findvalue(@(w) w.slot == infantryWeaponsSlotIdx.nonUniqe)
        let nonUniqWeaponsModified = this.getModifiedSoldierWeaponsArray(
          nonUniqe,  currSoldierNonUniqWeapon, infantryWeaponsSlotIdx.nonUniqe, index)
        if (i >= availableSoldiersCount) {
          let currSelectedNonUniqeWeapon = nonUniqWeaponsModified.findvalue(@(w) w?.selected) ?? createEmptyWeaponSlot(infantryWeaponsSlotIdx.nonUniqe)
          this.createItem(this.getDisabledWeaponForSoldier(currSelectedNonUniqeWeapon, index), weaponsItem.infantryWeapon, this.mainModsObj, offsetX, offsetY, 0.5)
        }
        else
          this.createBundle(nonUniqWeaponsModified, weaponsItem.infantryWeapon, 0, this.mainModsObj, offsetX, offsetY)
        offsetX+=0.5

        local soldierName = $"{loc("infantry/squad/member")} {index + 1}"
        if (i >= availableSoldiersCount)
          soldierName = "".concat(soldierName, loc("ui/parentheses/space", { text = loc("infantry/squad/member_inactive") }))
        columnsList.append(this.getWeaponsColumnData(soldierName))
      }
    }

    
    if (isUnitHaveSecondaryWeapons(this.air)) {
      this.lastWeapon = validateLastWeapon(this.airName) 
      let secondaryWeapons = getSecondaryWeaponsList(this.air)
      if (this.air.isHuman())
        secondaryWeapons.append(this.createEmptyPresetItem())

      log($"initial set lastWeapon {this.lastWeapon}")
      if (needSecondaryWeaponsWnd(this.air)) {
        let selWeapon = secondaryWeapons.findvalue((@(w) w.name == this.lastWeapon).bindenv(this))
          ?? secondaryWeapons?[0]
        if (selWeapon)
          this.createItem(selWeapon, weaponsItem.weapon, this.mainModsObj, offsetX, offsetY)
      }
      else {
        this.createBundle(secondaryWeapons, weaponsItem.weapon, 0, this.mainModsObj, offsetX, offsetY)
        this.offsetCoordsForSecondaryWeapons = { offsetX, offsetY }
      }
      columnsList.append(this.getWeaponsColumnData(
        weaponryTypes.WEAPON.getHeader(this.air)).__merge(
          {
            haveWarning = checkUnitSecondaryWeapons(this.air) != UNIT_WEAPONS_READY
            warningId = "weapons"
          }))
      offsetX++
    }

    
    foreach (groupIndex, bulletsList in this.bulletsByGroupIndex) {
      this.createBundle(getBulletsItemsList(this.air, bulletsList, groupIndex),
        weaponsItem.bullets, groupIndex, this.mainModsObj, offsetX, offsetY, bulletsList?.supportUnitName)
      let name = getBulletsListHeader(this.air, bulletsList)
      columnsList.append(this.getWeaponsColumnData(name).__merge(
        {
          haveWarning = checkUnitBullets(this.air, true, bulletsList.values) != UNIT_WEAPONS_READY
          warningId = $"bullets{groupIndex}"
        }))
      offsetX++
    }

    
    if (this.expendablesArray.len()) {
      columnsList.append(this.getWeaponsColumnData(loc("modification/category/expendables")))
      foreach (mod in this.expendablesArray) {
        this.createItem(mod, mod.type, this.mainModsObj, offsetX, offsetY)
        offsetX++
      }
    }

    this.createTreeBlocks(this.modsBgObj, columnsList, 1, 0, offsetY, "", null, "weapons")
  }

  function updateWeaponsWarning() {
    let iconObj = this.scene.findObject("weapons_warning")
    if (iconObj?.isValid())
      iconObj.display = (checkUnitSecondaryWeapons(this.air) != UNIT_WEAPONS_READY) ? "show" : "hide"
  }

  function updateBulletsWarning() {
    for (local groupIndex = 0; groupIndex < getLastFakeBulletsIndex(this.air); groupIndex++) {
      let bulletsList = getBulletsList(this.air.name, groupIndex, {
        needCheckUnitPurchase = false, needOnlyAvailable = false })
      if (!bulletsList.values.len() || bulletsList.duplicate)
        continue

      let iconObj = this.scene.findObject($"bullets{groupIndex}_warning")
      if (iconObj?.isValid())
        iconObj.display = (checkUnitBullets(this.air, true, bulletsList.values) != UNIT_WEAPONS_READY)
          ? "show" : "hide"
    }
  }

  function canBomb(checkPurchase) {
    return isUnitHaveAnyWeaponsTags(this.air, [WEAPON_TAG.ROCKET, WEAPON_TAG.BOMB], checkPurchase)
  }

  function getItemBundle(searchItem) {
    foreach (bundle in this.items)
      if (bundle.type == weaponsItem.bundle)
        foreach (item in bundle.itemsList)
          if (item.name == searchItem.name && item.type == searchItem.type)
            return bundle
    return null
  }

  function getWeaponBundle(searchWeapon) {
    foreach (bundle in this.items)
      if (bundle.type == weaponsItem.bundle)
        foreach (item in bundle.itemsList)
          if (item?.slot == searchWeapon.slot &&
            item.name == searchWeapon.name &&
            item.type == searchWeapon.type &&
            item?.soldierId == searchWeapon.soldierId)
              return bundle
    return null
  }

  
  function getPresetsSelectorBundleIdx() {
    return this.items.findindex(@(i) i.type == weaponsItem.bundle && i?.itemsType == weaponsItem.weapon)
  }

  function getItemIdxByObj(obj) {
    if (!obj)
      return -1
    local id = obj?.holderId ?? ""
    if (id == "")
      id = obj.id
    if (id.len() <= 5 || id.slice(0, 5) != "item_")
      return -1
    let idx = id.slice(5).tointeger()
    return (idx in this.items) ? idx : -1
  }

  function getItemIdxByName(name) {
    foreach (idx, item in this.items)
      if (item.name == name)
        return idx

    return -1
  }

  function getCurItemObj() {
    if (!checkObj(this.mainModsObj))
      return null

    let val = this.mainModsObj.getValue() - 1
    let itemObj = this.mainModsObj.findObject($"item_{val}")
    return checkObj(itemObj) ? itemObj : null
  }

  function doCurrentItemAction() {
    let itemObj = this.getCurItemObj()
    if (itemObj)
      this.onModAction(itemObj, false)
  }

  function onModItemClick(obj) {
    if (this.researchMode) {
      let idx = this.getItemIdxByObj(obj)
      if (idx >= 0)
        this.mainModsObj.setValue(this.items[idx].guiPosIdx + 1)
      return
    }

    this.onModAction(obj, false, showConsoleButtons.get())
  }

  function onModItemDblClick(obj) {
    this.onModAction(obj)
  }

  function onModActionBtn(obj) {
    this.onModAction(obj, true, true)
  }

  function onPresetDeleteBtn(obj) {
    let idx = this.getItemIdxByObj(obj)
    if (idx < 0)
      return
    let item = this.items[idx]
    let secondaryWeapons = getSecondaryWeaponsList(this.air)
    if (secondaryWeapons.findindex(@(w) w.name == item.name) != null)
      deleteCustomPreset(this.air, item.name)
  }

  function onModCheckboxClick(obj) {
    this.onModAction(obj)
  }

  function getSelectedUnit() {
    if (!checkObj(this.mainModsObj))
      return null
    let item = this.getSelItemFromNavObj(this.mainModsObj)
    return (item && this.isItemTypeUnit(item.type)) ? item : null
  }

  function getSelItemFromNavObj(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return null
    let idx = this.getItemIdxByObj(obj.getChild(value))
    if (idx < 0)
      return null
    return this.items[idx]
  }

  function canPerformAction(item, amount) {
    local reason = null
    if (!this.isOwn)
      reason = format(loc("weaponry/action_not_allowed"), loc("weaponry/unit_not_bought"))
    else if (!amount && !canBuyMod(this.air, item)) {
      local reqTierMods = 0
      local reqMods = ""
      if ("tier" in item)
        reqTierMods = getNextTierModsCount(this.air, item.tier - 1)
      if ("reqModification" in item)
        reqMods = getReqModsText(this.air, item)

      if (reqTierMods > 0)
        reason = format(loc("weaponry/action_not_allowed"),
                          loc("weaponry/unlockModTierReq",
                                { tier = roman_numerals[item.tier], amount = reqTierMods }))
      else if (reqMods.len() > 0)
        reason = format(loc("weaponry/action_not_allowed"), $"{loc("weaponry/unlockModsReq")}\n{reqMods}")
    }

    if (reason != null) {
      this.msgBox("not_available", reason, [["ok", function() {} ]], "ok")
      return false
    }
    return true
  }

  function onStickDropDown(obj, show) {
    if (!checkObj(obj))
      return

    let id = obj?.id
    if (!id || id.len() <= 5 || id.slice(0, 5) != "item_")
      return base.onStickDropDown(obj, show)

    if (!show) {
      this.curBundleTblObj = null
      return
    }

    this.curBundleTblObj = obj.findObject("items_field")
    this.guiScene.playSound("menu_appear")
    return
  }

  function unstickCurBundle() {
    if (!checkObj(this.curBundleTblObj))
      return
    this.onDropDownToggle(this.curBundleTblObj.getParent().getParent()) 
    this.curBundleTblObj = null
  }

  function onBundleAnimFinish(obj) {
    
    if (!showConsoleButtons.get() || !this.curBundleTblObj?.isValid() || obj.getFloatProp(timerPID, 0.0) < 1)
      return
    move_mouse_on_child(this.curBundleTblObj, 0)
  }

  function onBundleHover(obj) {
    
    if (!showConsoleButtons.get() || !this.curBundleTblObj?.isValid() || obj.getFloatProp(timerPID, 0.0) < 1)
      return
    this.unstickCurBundle()
  }

  function onCloseBundle(obj) {
    if (showConsoleButtons.get())
      move_mouse_on_obj(obj.getParent().getParent().getParent())
  }

  function onModAction(obj, fullAction = true, stickBundle = false) {
    let idx = this.getItemIdxByObj(obj)
    if (idx < 0)
      return

    let item = this.items[idx]
    if (item.type == weaponsItem.bundle) {
      if (stickBundle && checkObj(obj))
        this.onDropDownToggle(obj.getParent())
      return
    }
    if (item.type == weaponsItem.skin) {
      defer(@() item.decor.doPreview())
      return
    }

    this.doItemAction(item, fullAction)
  }

  function doItemAction(item, fullAction = true) {
    let amount = getItemAmount(this.air, item)
    let onlyBuy = !fullAction && !this.getItemBundle(item)

    if (this.checkResearchOperation(item))
      return
    if (item.type == weaponsItem.weapon && needSecondaryWeaponsWnd(this.air)) {
      guiStartWeaponryPresets({ unit = this.air, curEdiff = this.getCurrentEdiff() }) 
      return
    }
    if (!this.canPerformAction(item, amount))
      return

    if (item.type == weaponsItem.infantryWeapon) {
      this.changeWeaponForSoldier(item)
      return
    }
    if (item.type == weaponsItem.infantryArmor) {
      this.changeArmorForSoldier(item)
      return
    }

    if (item.type == weaponsItem.weapon) {
      if (item.name == EMPTY_PRESET_NAME) {
        if (isEmptyPresetAlreadyExist(this.air)) {
          showInfoMsgBox(loc($"msgbox/emptyPresetAlreadyExist"))
          return
        }
        let emptyPreset = createEmptyInfantryPreset(this.air)
        this.needToKeepDropDown = false
        this.addCustomPresetImpl(emptyPreset)
        return
      }
      if (getLastWeapon(this.airName) == item.name || !amount) {
        if (item.cost <= 0)
          return
        return this.onBuy(item.guiPosIdx)
      }

      if (onlyBuy)
        return

      this.guiScene.playSound("check")

      if (needReqModInstall(this.air, item)) {
        promptReqModInstall(this.air, item)
        return
      }

      setLastWeapon(this.airName, item.name)
      this.updateItemBundle(item)
      checkSecondaryWeaponModsRecount(this.air)
      return
    }
    else if (item.type == weaponsItem.primaryWeapon) {
      if (!onlyBuy) {
        this.setLastPrimary(item)
        return
      }
    }
    else if (item.type == weaponsItem.modification) {
      let groupDef = ("isDefaultForGroup" in item) ? item.isDefaultForGroup : -1
      if (groupDef >= 0) {
        this.setLastBullets(item, groupDef)
        return
      }
      else if (!onlyBuy) {
        if (getModificationBulletsGroup(item.name) != "") {
          let id = getBulletGroupIndex(this.airName, item.name)
          local isChanged = false
          if (id >= 0)
            isChanged = this.setLastBullets(item, id)
          if (isChanged)
            return
        }
        else if (amount) {
          this.switchMod(item)
          return
        }
      }
    }
    else if (item.type == weaponsItem.expendables) {
      if (!onlyBuy && amount) {
        this.switchMod(item)
        return
      }
    } 
    

    this.onBuy(item.guiPosIdx)
  }

  function checkResearchOperation(item) {
    if (canResearchItem(this.air, item, this.availableFlushExp <= 0 && this.setResearchManually)) {
      let afterFuncDone =  function() {
        this.setModificatonOnResearch(item, function() {
          this.updateAllItems()
          this.selectResearchModule()
          if (this.researchMode) {
            if (item && isModResearched(this.air, item))
              this.sendModResearchedStatistic(this.air, item.name)
          }
        })
      }

      this.flushItemExp(item.name, afterFuncDone)
      return true
    }
    return false
  }

  function setModificatonOnResearch(item, afterDoneFunc = null) {
    let executeAfterDoneFunc =  function() {
        if (afterDoneFunc)
          afterDoneFunc()
      }

    if (!item || isModResearched(this.air, item)) {
      executeAfterDoneFunc()
      return
    }

    this.taskId = shop_set_researchable_unit_module(this.airName, item.name)
    if (this.taskId >= 0) {
      this.setResearchManually = true
      this.lastResearchMod = item
      set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox()
      this.afterSlotOp = afterDoneFunc
      this.afterSlotOpError = @(_res) this.msgBox("unit_modul_research_fail",
        loc("weaponry/module_set_research_failed"),
        [["ok", @() executeAfterDoneFunc() ]], "ok")
    }
    else
      executeAfterDoneFunc()
  }

  function flushItemExp(modName, afterDoneFunc = null) {
    this.checkSaveBulletsAndDo(@() this._flushItemExp(modName, afterDoneFunc))
  }

  function _flushItemExp(modName, afterDoneFunc = null) {
    let executeAfterDoneFunc = function() {
        this.setResearchManually = true
        if (afterDoneFunc)
          afterDoneFunc()
      }

    if (this.availableFlushExp <= 0) {
      executeAfterDoneFunc()
      return
    }

    this.taskId = flushExcessExpToModule(this.airName, modName)
    if (this.taskId >= 0) {
      set_char_cb(this, this.slotOpCb)
      this.showTaskProgressBox()
      this.afterSlotOp = afterDoneFunc
      this.afterSlotOpError = function(_res) {
        executeAfterDoneFunc()
      }
    }
    else
      executeAfterDoneFunc()
  }

  function onAltModAction(obj) { 
    let idx = this.getItemIdxByObj(obj)
    if (idx < 0)
      return

    let item = this.items[idx]
    if (item.type == weaponsItem.spare) {
      gui_handlers.UniversalSpareApplyWnd.open(this.air, this.getItemObj(idx))
      return
    }
    else if (item.type == weaponsItem.modification) {
      if (getItemAmount(this.air, item) && isModUpgradeable(item.name)) {
        gui_handlers.ModUpgradeApplyWnd.open(this.air, item, this.getItemObj(idx))
        return
      }
    }

    this.onBuy(idx)
  }

  function onGoToModTutorial(obj) {
    let idx = this.getItemIdxByObj(obj)
    let item = this.items[idx]
    let { tutorialMission, name, tutorialMissionWeapon = null } = item
    let misInfo = get_meta_mission_info_by_name(tutorialMission)
    let unit = this.air

    this.markSeenModTutorialIfNeeded(item)

    let params = {
      modalHeader = loc("mod/start_test_modal_title", { modName = getModificationName(this.air, name) })
      modalWidth = "900@sf/@pf"
      modalHeight = "300@sf/@pf"
      columnsRatio = 0.35
      options = [[USEROPT_DIFFICULTY, "spinner"]]
      optionsConfig = {
        missionName = misInfo.name,
        gm = GM_TRAINING
        forbiddenDifficulty = misInfo?.forbiddenDifficulty
      }
      applyAtClose = false
      wndOptionsMode = OPTIONS_MODE_TRAINING
      applyFunc = function() {
        if (!canJoinFlightMsgBox())
          return
        this.shouldBeRestoredOnMainMenu = true
        currentCampaignMission.set(misInfo?.name ?? "")
        startModTutorialMission(unit, name, tutorialMission, tutorialMissionWeapon)
      }.bindenv(this)
    }

    handlersManager.loadHandler(gui_handlers.GenericOptionsModal, params)
  }

  function onAltModActionCommon(obj) { 
    let idx = this.getItemIdxByObj(obj)
    if (idx < 0)
      return

    let item = this.items[idx]
    if (canGoToNightBattleOnUnit(this.air, item.name))
      nightBattlesOptionsWnd()
  }

  function onBuy(idx, buyAmount = 0) { 
    if (!this.isOwn)
      return

    local item = this.items[idx]
    local open = false

    if (item.type == weaponsItem.bundle)
      return getByCurBundle(this.air, item, @(_a, it) this.onBuy(it.guiPosIdx, buyAmount))

    if (item.type == weaponsItem.weapon) {
      if (!shop_is_weapon_available(this.airName, item.name, false, true))
        return
    }
    else if (item.type == weaponsItem.primaryWeapon) {
      if ("guiPosIdx" in item.weaponMod)
        item = this.items[item.weaponMod.guiPosIdx]
    }
    else if (item.type == weaponsItem.modification || item.type == weaponsItem.expendables) {
      let groupDef = ("isDefaultForGroup" in item) ? item.isDefaultForGroup : -1
      if (groupDef >= 0)
        return

      open = canResearchMod(this.air, item)
    }

    this.checkAndBuyWeaponry(item, open)
  }

  function onBuyAllButton() {
    this.onBuyAll()
  }

  onBuyAllResearchedButton = @() this.onBuyAll(false)

  function onBuyAll(forceOpen = true, silent = false) {
    let unit = this.air
    this.checkSaveBulletsAndDo(@() weaponsPurchase(unit, { open = forceOpen, silent = silent }))
  }

  function setLastBullets(item, groupIdx) {
    if (!(groupIdx in this.lastBullets))
      return false

    let curBullets = getSavedBullets(this.airName, groupIdx)
    let isChanged = curBullets != item.name && !("isDefaultForGroup" in item && curBullets == "")
    setUnitLastBullets(this.air, groupIdx, item.name)
    if (isChanged) {
      this.guiScene.playSound("check")
    }
    this.updateItemBundle(item)
    return isChanged
  }

  function checkAndBuyWeaponry(modItem, open = false) {
    let listObj = this.mainModsObj
    let curValue = this.mainModsObj.getValue()
    this.checkSaveBulletsAndDo(Callback(function() {
      weaponsPurchase(this.air, {
        modItem = modItem,
        open = open,
        onFinishCb = @() move_mouse_on_child(listObj, curValue)
      })
    }, this))
  }

  function setLastPrimary(item) {
    let lastPrimary = getLastPrimaryWeapon(this.air)
    if (lastPrimary == item.name)
      return
    let mod = getModificationByName(this.air, (item.name == "") ? lastPrimary : item.name)
    if (mod)
      this.switchMod(mod, false)
  }

  function switchMod(item, checkCanDisable = true) {
    let equipped = shopIsModificationEnabled(this.airName, item.name)
    if (checkCanDisable && equipped && !isCanBeDisabled(item))
      return

    this.guiScene.playSound(!equipped ? "check" : "uncheck")

    this.checkSaveBulletsAndDo(@() this.doSwitchMod(item, equipped))
  }

  function doSwitchMod(item, equipped) {
    let unit = this.air
    let taskSuccessCallback = function() {
      updateUnitAfterSwitchMod(unit, item.name)
      broadcastEvent("ModificationChanged")
    }

    let taskId = enable_modifications(this.airName, [item.name], !equipped)
    addTask(taskId, { showProgressBox = true }, taskSuccessCallback)
  }

  function onEventModificationChanged(_p) {
    let appliedArmorName = getAppliedArmorForUnit(this.air)?.name ?? ""
    let armorItem = this.items.findvalue(@(i) i.type == weaponsItem.infantryArmor && i.name == appliedArmorName)
    if (armorItem)
      this.updateSelectedItemInBundle(armorItem)

    this.doWhenActiveOnce("updateAllItems")
    this.doWhenActiveOnce("unstickCurBundle")

    let curWeapon = validateLastWeapon(this.airName)
    if (curWeapon != this.lastWeapon)
      this.doWhenActiveOnce("onEventUnitWeaponChanged")
  }

  function checkSaveBulletsAndDo(func) {
    local needSave = false
    for (local groupIndex = 0; groupIndex < this.air.unitType.bulletSetsQuantity; groupIndex++) {
        let curBulletsName = getSavedBullets(this.airName, groupIndex)
        if (this.lastBullets && groupIndex in this.lastBullets &&
            this.lastBullets[groupIndex] != curBulletsName) {
          log("".concat("force cln_update due lastBullets '",
            this.lastBullets[groupIndex], "' != '", curBulletsName, "'"))
          needSave = true;
          this.lastBullets[groupIndex] = curBulletsName
        }
    }
    if (isUnitHaveSecondaryWeapons(this.air) && this.lastWeapon != "" && this.lastWeapon != getLastWeapon(this.airName)) {
      log($"force cln_update due lastWeapon '{this.lastWeapon}' != {getLastWeapon(this.airName)}")
      needSave = true;
      this.lastWeapon = getLastWeapon(this.airName)
    }

    if (needSave) {
      this.taskId = save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      if (this.taskId >= 0 && func) {
        let cb = u.isFunction(func) ? Callback(func, this) : func
        addTask(this.taskId, { showProgressBox = true }, cb)
      }
    }
    else if (func)
      func()
    return true
  }

  function getAutoPurchaseValue() {
    return this.isOwn && get_auto_buy_modifications()
  }

  function onChangeAutoPurchaseModsValue(obj) {
    let value = obj.getValue()
    let savedValue = this.getAutoPurchaseValue()
    if (value == savedValue)
      return

    set_auto_buy_modifications(value)
    save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function goBack() {
    this.checkSaveBulletsAndDo(null)
    this.sendModPurchasedStatistic(this.air)

    if (this.researchMode) {
      let curResName = shop_get_researchable_module_name(this.airName)
      if (getTblValue("name", this.lastResearchMod, "") != curResName)
        this.setModificatonOnResearch(getModificationByName(this.air, curResName))
    }

    if (this.getAutoPurchaseValue())
      this.onBuyAll(false, true)
    else if (this.researchMode)
      prepareUnitsForPurchaseMods.addUnit(this.air)

    base.goBack()
  }

  function afterModalDestroy() {
    if (!checkNonApprovedResearches(false) && prepareUnitsForPurchaseMods.haveUnits())
      prepareUnitsForPurchaseMods.checkUnboughtMods()
  }

  needRestoreResearchMode = @() this.researchMode
    && (!this.setResearchManually || this.availableFlushExp > 0)
    && findAnyNotResearchedMod(this.air) != null

  function onDestroy() {
    if (this.needRestoreResearchMode() || this.shouldBeRestoredOnMainMenu)
      handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)

    this.sendModPurchasedStatistic(this.air)
  }

  function getHandlerRestoreData() {
    if (this.shouldBeRestoredOnMainMenu)
      return {}
    let openData = {
      curEdiff = this.curEdiff
      needHideSlotbar = this.needHideSlotbar
    }
    if (this.needRestoreResearchMode())
      openData.__update({
        researchMode = this.researchMode
        researchBlock = this.researchBlock
      })
    return { openData }
  }

  function onEventUniversalSpareActivated(_p) {
    foreach (idx, item in this.items)
      if (item.type == weaponsItem.spare)
        this.updateItem(idx)
  }

  function onEventModUpgraded(p) {
    if (p.unit != this.air)
      return
    let modName = p.mod.name
    let itemidx = this.items.findindex(@(item) item.name == modName)
    if (itemidx != null)
      this.updateItem(itemidx)
  }

  function getCurrentEdiff() {
    return this.curEdiff == -1 ? getCurrentGameModeEdiff() : this.curEdiff
  }

  function sendModResearchedStatistic(unit, modName) {
    sendBqEvent("CLIENT_GAMEPLAY_1", "completed_new_research_modification", { unit = unit.name
      modification = modName })
  }

  function sendModPurchasedStatistic(unit) {
    if (!unit || !this.purchasedModifications.len())
      return

    sendBqEvent("CLIENT_GAMEPLAY_1", "modifications_purchased", { unit = unit.name
      modifications = this.purchasedModifications })
    this.purchasedModifications.clear()
  }

  function onShowDamageControl() {
    showDamageControl(this.air)
  }

  function getUnhoveredItem(modObj, modSlotButtonsNest) {
    if (modObj.isHovered() || modSlotButtonsNest.isHovered())
      return null
    let idx = this.getItemIdxByObj(modObj)
    return idx < 0 ? null : this.items[idx]
  }

  function markSeenNightBattleIfNeed(item) {
    if (!needShowUnseenNightBattlesForUnit(this.air, item.name))
      return
    markSeenNightBattle()
  }

  function markSeenModTutorialIfNeeded(item) {
    if (!needShowUnseenModTutorialForUnitMod(this.air, item))
      return
    markSeenModTutorial(item)
  }

  function onEventMarkSeenNightBattle(_) {
    let unit = this.air
    let modificationsWithNVDSighst = unit.modifications
      .filter(@(v) unit.getNVDSights(v.name).len() > 0)
    if (modificationsWithNVDSighst.len() == 0)
      return

    foreach (mod in modificationsWithNVDSighst) {
      let itemidx = this.getItemIdxByName(mod.name)
      if (itemidx >= 0)
        this.updateItem(itemidx)
    }
  }

  function onHelp() {
    gui_handlers.HelpInfoHandlerModal.openHelp(this)
  }

  function getWndHelpConfig() {
    let res = {
      textsBlk = "%gui/weaponry/weaponryHelp.blk"
      objContainer = this.scene.findObject("mods_frame")
    }

    let links = [
      { obj = [$"auto_purchase_mods"], msgId = "hint_auto_purchase_mods"}
      { obj = [$"progressBonus", "progressModsThumb"], msgId = "hint_progressBonus"}
      { obj = [$"weapons", "header_weapons"], msgId = "hint_weapons"}
    ]

    let itemsByStatus = {}
    itemsByStatus.researched <- []
    itemsByStatus.canResearch <- []
    itemsByStatus.cantResearch <- []
    itemsByStatus.progress <- []
    itemsByStatus.buyed <- []

    let itemsLength = this.items.len()
    for ( local i = 0; i < itemsLength; i++) {
      let item = this.items[i]
      if (item.type == itemType.TICKET)
        continue

      if (item?.isBonusTier || item?.isHidden || item.name == "allowPremDecals") continue

      if (item.name == "spare") {
        links.append({ obj = [$"item_{i}"], msgId = "hint_item_spare"})
        continue
      }

      if (item.name == "premExpMul") {
        links.append({ obj = [$"item_{i}"], msgId = "hint_item_talisman"})
        continue
      }

      if (item.name == "skin") {
        let camouflageComplete = item.progress < 0 ? "_complete" : ""
        links.append({ obj = [$"item_{i}"], msgId = $"hint_item_camouflage{camouflageComplete}"})
        continue
      }

      let statusTbl = getItemStatusTbl(this.air , item)
      if (statusTbl.maxAmount == 0) continue

      let itemReqExp = item?.reqExp ?? 0
      let canResearch = canResearchItem(this.air, item, false)
      let isModResearching = canResearch &&
                             statusTbl.modExp >= 0 &&
                             statusTbl.modExp < itemReqExp &&
                             !statusTbl.amount

      if (isModResearching && isModInResearch(this.air, item)) {
        itemsByStatus.progress.append($"item_{i}")
        continue
      }

      if (statusTbl.unlocked) {
        if (statusTbl?.amount && statusTbl.amount > 0) {
          itemsByStatus.buyed.append($"item_{i}")
        } else {
          itemsByStatus.researched.append($"item_{i}")
        }
      } else if (canResearch) {
        itemsByStatus.canResearch.append($"item_{i}")
      }
    }

    let hintSizes = {
      hintWidth = to_pixels("2@shopWidthMax")
      hintHeight = to_pixels("1@modItemHeight + 4@modPadSize")
      padding = to_pixels("1@helpInterval")
    }

    let rects = [] 

    let itemStatusTypes = [
     {type = "progress", hintId = "hint_progressItem"}
     {type = "canResearch", hintId = "hint_noProgressItem"}
     {type = "researched", hintId = "hint_researchedItem"}
     {type = "buyed", hintId = "hint_buyedItem"}
    ]

    local safeArea = null 
    let window = this.scene.findObject("main_modifications")
    if (window?.isValid()) {
      let tierLine1 = window.findObject("tierLine_1")
      let tierLine1Pos = tierLine1.getPos()
      let saveAreaPaddingTop = tierLine1Pos[1] - to_pixels("1@cIco + 2@buttonImgPadding")
      let sw = to_pixels("sw")
      let windowPos = window.getPos()
      let windowSize = window.getSize()
      safeArea = {x = 0, y = saveAreaPaddingTop, w = sw, h = windowPos[1] + windowSize[1] - saveAreaPaddingTop}
    }

    foreach (itemStatusType in itemStatusTypes) {
      if (!itemsByStatus?[itemStatusType.type])
        continue
      foreach (itemId in itemsByStatus[itemStatusType.type]) {
        let hintRect = findPlaceForHint(this.scene.findObject(itemId), rects, hintSizes, safeArea)
        if (hintRect) {
          links.append({ obj = [itemId], msgId = itemStatusType.hintId, rect = hintRect})
          break;
        }
      }
    }

    res.links <- links
    return res
  }

  function prepareHelpPage(handler) {
    let spechialHintsParams = {
      hint_item_talisman = {
        hintName = "hint_item_talisman"
        shiftX = "+ 0.8@modItemWidth - 1@bw"
        shiftY = "- 2@helpInterval - h - 1@bh"
      }
      hint_item_camouflage_complete = {
        hintName = "hint_item_camouflage_complete"
        shiftX = "+ 1@modItemWidth + 1@helpInterval - 1@bw"
        shiftY = "- 1@bh - h"
        sizeMults = [0,1]
      }
      hint_item_camouflage = {
        hintName = "hint_item_camouflage"
        shiftX = "+ 1@modItemWidth + 1@helpInterval - 1@bw"
        shiftY = "- 1@bh - h"
        sizeMults = [0,1]
      }
      hint_auto_purchase_mods = {
        hintName = "hint_auto_purchase_mods"
        shiftX = $"- 1@bw",
        shiftY = $"+ 1@helpInterval - 1@bh"
        sizeMults = [0,1]
      }
      hint_progressBonus = {
        objName = "mods_frame"
        hintName = "hint_progressBonus"
        shiftX = "+ 2@shopWidthMax - 1@bw + 2@helpInterval"
        posY = "sh - 1@bh - h - 2@helpInterval"
        sizeMults = [0,1]
      }
      hint_item_spare = {
        hintName = "hint_item_spare"
        shiftX = "+ 1.8@modItemWidth - w - 1@bw -1@helpInterval"
        shiftY = "- h - 2@helpInterval - 1@bh"
      }
    }

    let mainModifications = this.scene.findObject("main_modifications")
    if ( mainModifications?.isValid()) {
      let mainModsPos = mainModifications.getPos()
      let hintLeftOffset = to_pixels("1.5@shopWidthMax - 1@modItemWidth")
      if ( mainModsPos[0] > hintLeftOffset ) {
        spechialHintsParams.hint_weapons <- {
          objName = "main_modifications"
          hintName = "hint_weapons"
          shiftX = "+ 1@modItemWidth - w-  1@bw"
          shiftY = "- 1@bh + 1@helpInterval"
        }
      } else {
        let hintObj = handler.scene.findObject("hint_weapons")
        if (hintObj?.isValid()) {
          hintObj.pos = "sw - w - 2@bw - 2@helpInterval, sh - 2@bh -h  - 2@helpInterval"
        }
      }
    }

    foreach (link in handler.config.links) {
      if (spechialHintsParams?[link.msgId]) {
        let spechialHint = spechialHintsParams[link.msgId]
        if (!spechialHint?.objName) {
          if (u.isArray(link.obj))
            spechialHint.objName <- link.obj[0]
          else
            spechialHint.objName <- link.obj
        }
        updateHintPosition(this.scene, handler.scene, spechialHint)
        continue
      }

      if (link?.rect) {
        let hintObj = handler.scene.findObject(link.msgId)
        if (hintObj.isValid)
          hintObj.pos = $"{link.rect.x} -1@bw, {link.rect.y} -1@bh"
      }
    }

  }

  function onEventMarkSeenModTutorial(params) {
    foreach(idx, item in this.items)
      if (item?.tutorialMission == params.missionName)
        this.updateItem(idx)
  }

  function onModUnhover(obj) {
    let item = this.getUnhoveredItem(obj, obj.findObject("modSlotButtonsNest"))
    if (!item)
      return
    this.markSeenNightBattleIfNeed(item)
    this.markSeenModTutorialIfNeeded(item)
  }

  function onHoverSizeMove(obj) {
    this.openedWeaponDropDownsCount++
    obj.getParent()["order-popup"] = "yes"
    showObjById("dropdown-backdrop", true, this.scene)

    base.onHoverSizeMove(obj)
  }

  function onDropDownClose(obj) {
    this.openedWeaponDropDownsCount--
    obj.getParent()["order-popup"] = "no"
    if (this.openedWeaponDropDownsCount == 0)
      showObjById("dropdown-backdrop", false, this.scene)
  }


  function onModButtonNestUnhover(obj) {
    let item = this.getUnhoveredItem(obj.getParent(), obj)
    if (!item)
      return
    this.markSeenNightBattleIfNeed(item)
    this.markSeenModTutorialIfNeeded(item)
  }

  function onEventBeforeOpenWeaponryPresetsWnd(_) {
    handlersManager.requestHandlerRestore(this)
  }
}

gui_handlers.MultiplePurchase <- class (gui_handlers.BaseGuiHandlerWT) {
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
  sceneBlkName = "%gui/multiplePurchase.blk"

  function initScreen() {
    if (this.minValue >= this.maxValue) {
      this.goBack()
      return
    }

    this.itemCost = getItemCost(this.unit, this.item)
    let statusTbl = getItemStatusTbl(this.unit, this.item)
    this.minValue = statusTbl.amount
    this.maxValue = statusTbl.maxAmount
    this.minUserValue = statusTbl.amount + 1
    this.maxUserValue = statusTbl.maxAmount

    this.scene.findObject("item_name_header").setValue(getModItemName(this.unit, this.item))

    this.updateSlider()
    createModItem($"mod_{this.item.name}", this.unit, this.item, this.item.type, this.scene.findObject("icon"), this, {
      canShowStatusImage = false
    })

    let discountType = this.item.type == weaponsItem.spare ? "spare" : (this.item.type == weaponsItem.weapon) ? "weapons" : "mods"
    showAirDiscount(this.scene.findObject("multPurch_discount"), this.unit.name, discountType, this.item.name, true)

    this.sceneUpdate()
    move_mouse_on_obj(this.scene.findObject("skillSlider"))
  }

  function updateSlider() {
    this.minUserValue = (this.minUserValue == null) ? this.minValue : clamp(this.minUserValue, this.minValue, this.maxValue)
    this.maxUserValue = (this.maxUserValue == null) ? this.maxValue : clamp(this.maxUserValue, this.minValue, this.maxValue)

    if (this.curValue <= this.minValue) {
      let balance = get_balance()
      local maxBuy = this.maxValue - this.minValue
      if (maxBuy * this.itemCost.gold > balance.gold && balance.gold >= 0)
        maxBuy = (balance.gold / this.itemCost.gold).tointeger()
      if (maxBuy * this.itemCost.wp > balance.wp && balance.wp >= 0)
        maxBuy = (balance.wp / this.itemCost.wp).tointeger()
      this.curValue = this.itemCost.gold > 0 ? this.minUserValue : this.minValue + max(maxBuy, 1)
    }

    let sObj = this.scene.findObject("skillSlider")
    sObj.max = this.maxValue

    let oldObj = this.scene.findObject("oldSkillProgress")
    oldObj.max = this.maxValue

    let newObj = this.scene.findObject("newSkillProgress")
    newObj.min = this.minValue
    newObj.max = this.maxValue
  }

  function onButtonDec() {
    this.curValue -= 1
    this.sceneUpdate()
  }

  function onButtonInc() {
    this.curValue += 1
    this.sceneUpdate()
  }

  function onButtonMax() {
    this.curValue = this.maxUserValue
    this.sceneUpdate()
  }

  function onProgressChanged(obj) {
    if (!obj || !this.someAction)
      return

    local newValue = obj.getValue()
    if (newValue == this.curValue)
      return

    if (newValue < this.minUserValue)
      newValue = this.minUserValue

    let value = clamp(newValue, this.minUserValue, this.maxUserValue)

    this.curValue = value
    this.sceneUpdate()
  }

  function updateButtonPriceText() {
    let buyValue = this.curValue - this.minValue
    let wpCost = buyValue * this.itemCost.wp
    let eaCost = buyValue * this.itemCost.gold
    placePriceTextToButton(this.scene, "item_price", loc("mainmenu/btnBuy"), wpCost, eaCost)
  }

  function sceneUpdate() {
    this.scene.findObject("skillSlider").setValue(this.curValue)
    this.scene.findObject("oldSkillProgress").setValue(this.minValue)
    this.scene.findObject("newSkillProgress").setValue(this.curValue)
    let buyValue = this.curValue - this.minValue
    let buyValueText = buyValue == 0 ? "" : $"+{buyValue}"
    this.scene.findObject("text_buyingValue").setValue(buyValueText)
    this.scene.findObject("buttonInc").enable(this.curValue < this.maxUserValue)
    this.scene.findObject("buttonMax").enable(this.curValue != this.maxUserValue)
    this.scene.findObject("buttonDec").enable(this.curValue > this.minUserValue)
    this.updateButtonPriceText()
  }

  function onBuy(_obj) {
    if (this.buyFunc)
      this.buyFunc(this.curValue - this.minValue)
  }

  function onDestroy() {
    if (this.onExitFunc)
      this.onExitFunc()
  }

  onEventModificationPurchased = @(_p) this.goBack()
  onEventWeaponPurchased = @(_p) this.goBack()
  onEventSparePurchased = @(_p) this.goBack()
  onEventProfileUpdated = @(_p) this.updateButtonPriceText()
}
