from "%scripts/invalid_user_id.nut" import INVALID_USER_ID
from "%scripts/dagui_natives.nut" import is_player_unit_alive, is_crew_slot_was_ready_at_host, get_auto_refill, get_cur_circuit_name, shop_get_first_win_wp_rate, get_crew_slot_cost, get_player_unit_name, is_first_win_reward_earned, shop_get_first_win_xp_rate, is_respawn_screen, get_spare_aircrafts_count
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import UNIT_WEAPONS_READY
from "%scripts/mainConsts.nut" import SEEN

let { deferOnce } = require("dagor.workcycle")
let { getObjIdByPrefix } = require("%scripts/utils_sa.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getObjValidIndex, toPixels } = require("%sqDagui/daguiUtil.nut")
let callback = require("%sqStdLibs/helpers/callback.nut")
let selectUnitHandler = require("%scripts/slotbar/selectUnitHandler.nut")
let { getWeaponsStatusName, checkUnitWeapons } = require("%scripts/weaponry/weaponryInfo.nut")
let { getNearestSelectableChildIndex } = require("%sqDagui/guiBhv/guiBhvUtils.nut")
let { getBitStatus, isUnitElite, isRequireUnlockForUnit, isUnitUsable
} = require("%scripts/unit/unitStatus.nut")
let { getUnitItemStatusText } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRequireUnlockShortText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { isCountrySlotbarHasUnits, isUnitUnlockedInSlotbar, initSelectedCrews,
  selectCrew, getSelectedCrews, getCrewById
} = require("%scripts/slotbar/slotbarState.nut")
let { setShowUnit, getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getAvailableRespawnBases } = require("guiRespawn")
let { getShopVisibleCountries } = require("%scripts/shop/shopCountriesList.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
let { getUnlockIdsByCountry } = require("%scripts/unlocks/unlockMarkers.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { startsWith } = require("%sqstd/string.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { isInFlight } = require("gameplayBinding")
let { bit_unit_status } = require("%scripts/unit/unitInfo.nut")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { selectCountryForCurrentOverrideSlotbar } = require("%scripts/slotbar/slotbarOverride.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { buildUnitSlot, fillUnitSlotTimers, getSlotObjId, getSlotObj, getUnitSlotRankText,
  isUnitEnabledForSlotbar, getSpareCountText, calcUnitSlotMissionInfoTextsWidth, getSlotCrewHint
} = require("%scripts/slotbar/slotbarView.nut")
let { getUnlockedCountries, isCountryAvailable } = require("%scripts/firstChoice/firstChoice.nut")
let { showAirExpWpBonus, getBonus } = require("%scripts/bonusModule.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCrewLevel, purchaseNewCrewSlot, getCrewUnit, getCrew, updateCrewSkillsAvailable,
  isCrewNeedUnseenIcon } = require("%scripts/crew/crew.nut")
let { getSpecTypeByCrewAndUnit } = require("%scripts/crew/crewSpecType.nut")
let { isCrewListOverrided, getCrewsListVersion, getCrewsList
} = require("%scripts/slotbar/crewsList.nut")
let { removeAllGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { startSlotbarUnitDnD } = require("%scripts/slotbar/slotbarUnitDnDHandler.nut")
let swapCrewHandler = require("%scripts/slotbar/swapCrewHandler.nut")
let swapCrewsBegin = require("%scripts/slotbar/swapCrewsDnDHandler.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let { getCountryMarkersWidth } = require("%scripts/markers/markerUtils.nut")
let { floor } = require("math")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { GuiBox } = require("%scripts/guiBox.nut")
let { open_weapons_for_unit } = require("%scripts/weaponry/weaponryActions.nut")
let { hasSessionInLobby, canChangeCrewUnits, canChangeCountry } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_modal_crew } = require("%scripts/crew/crewModalHandler.nut")

const SLOT_NEST_TAG = "unitItemContainer { {0} }"

let hasCrewModalWndInScene = @() isHandlerInScene(gui_handlers.CrewModalHandler)

function initSlotbarTopBar(slotbarObj, boxesShow) {
  if (!checkObj(slotbarObj))
    return

  showObjById("slotbar_buttons_place", true, slotbarObj)
  let mainObj = showObjById("autorefill-settings", true, slotbarObj)
  if (!checkObj(mainObj))
    return

  let repObj = showObjById("slots-autorepair", boxesShow, mainObj)
  let weapObj = showObjById("slots-autoweapon", boxesShow, mainObj)
  if (!boxesShow)
    return

  if (checkObj(repObj))
    repObj.setValue(get_auto_refill(0))

  if (checkObj(weapObj))
    weapObj.setValue(get_auto_refill(1))
}

gui_handlers.SlotbarWidget <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/slotbar/slotbar.blk"
  ownerWeak = null
  slotbarOninit = false

  
  singleCountry = null 
  showSingleCountryFlag = true
  crewId = null 
  shouldSelectCrewRecruit = false 
  isCountryChoiceAllowed = true 
                               
  customCountry = null 
  showTopPanel = true  
  showRepairBox = true  
  hasResearchesBtn = false 
  hasActions = true
  hasCrewHint = true
  missionRules = null
  showNewSlot = null 
  showEmptySlot = null 
  emptyText = "#shop/chooseAircraft" 
  alwaysShowBorder = false 
  checkRespawnBases = false 
  hasExtraInfoBlock = null 
  hasExtraInfoBlockTop = null 
  showAdditionExtraInfo = false
  showCrewHintUnderSlot = false
  showCrewUnseenIcon = true
  showCrewInfoTranslucent = false
  unitForSpecType = null 
  shouldSelectAvailableUnit = null 
  needPresetsPanel = null 
  countriesToShow = null
  selectOnHover = false  
  draggableSlots = true
  highlightSelected = false 

  
  mainMenuSlotbar = false 
  roomCreationContext = null 
  availableUnits = null 
  customUnitsList = null 
  customUnitsListName = null 
  eventId = null 
  gameModeName = null 

  toBattle = false 
  haveRespawnCost = false 
  haveSpawnDelay = false  
  totalSpawnScore = -1 
  sessionWpBalance = 0 

  shouldCheckQueue = null 
  needActionsWithEmptyCrews = true 
  applySlotSelectionOverride = null 
  beforeSlotbarSelect = null 
                             
                             
                             
  afterSlotbarSelect = null 
  onSlotDblClick = null 
  onSlotActivate = null 
  onCountryChanged = null 
  onCountryDblClick = null
  beforeFullUpdate = null 
  afterFullUpdate = null 
  onSlotBattleBtn = null 
  getLockedCountryData = null 
  needHugeFooter = "no"


  
  isSceneLoaded = false
  loadedCountries = null 
  lastUpdatedVersion = null 

  curSlotCountryId = -1
  curSlotIdInCountry = -1
  slotbarActions = null
  isShaded = false

  ignoreCheckSlotbar = false
  skipCheckCountrySelect = false
  skipCheckAirSelect = false
  skipActionWithEmptySlot = false

  headerObj = null
  crewsObj = null
  selectedCrewData = null
  customViewCountryData = null
  slotbarBehavior = null
  needFullSlotBlock = false
  showAlwaysFullSlotbar = false
  needCheckUnitUnlock = false
  slotbarHintText = ""

  initialCountriesWidths = null
  crewPopupSlotObj = null

  static function create(params) {
    let nest = params?.scene
    if (!checkObj(nest))
      return null

    if (params?.shouldAppendToObject ?? true) { 
      let data = "slotbarDiv { id:t='nav-slotbar' }"
      nest.getScene().appendWithBlk(nest, data)
      params.scene = nest.findObject("nav-slotbar")
    }

    return handlersManager.loadHandler(gui_handlers.SlotbarWidget, params)
  }

  function destroy() {
    if (checkObj(this.scene))
      this.guiScene.replaceContentFromText(this.scene, "", 0, null)
    this.scene = null
  }

  function initScreen() {
    this.headerObj = this.scene.findObject("header_countries")
    this.crewsObj =  this.scene.findObject("countries_crews")
    this.crewsObj.needHugeFooter = this.needHugeFooter

    this.loadedCountries = {}
    this.isSceneLoaded = true
    this.refreshAll()

    if (this.hasResearchesBtn) {
      let slotbarHeaderNestObj = this.scene.findObject("slotbar_buttons_place")
      if (checkObj(slotbarHeaderNestObj))
        slotbarHeaderNestObj["offset"] = "yes"
    }
  }

  function setParams(params) {
    base.setParams(params)
    if (this.ownerWeak)
      this.ownerWeak = this.ownerWeak.weakref()
    this.validateParams()
    if (this.isSceneLoaded) {
      this.loadedCountries.clear() 
      this.refreshAll()
    }
  }

  function validateParams() {
    this.showNewSlot = this.showNewSlot ?? !this.singleCountry
    this.showEmptySlot = this.showEmptySlot ?? !this.singleCountry
    this.hasExtraInfoBlock = this.hasExtraInfoBlock ?? !this.singleCountry
    this.hasExtraInfoBlockTop = this.hasExtraInfoBlockTop ?? !this.singleCountry
    this.shouldSelectAvailableUnit = this.shouldSelectAvailableUnit ?? isInFlight()
    this.needPresetsPanel = this.needPresetsPanel ?? (!this.singleCountry && this.isCountryChoiceAllowed)
    this.shouldCheckQueue = this.shouldCheckQueue ?? !isInFlight()
    this.onSlotDblClick = this.onSlotDblClick ?? this.getDefaultDblClickFunc()
    this.onSlotActivate = this.onSlotActivate ?? this.defaultOnSlotActivateFunc

    
    foreach (funcName in ["beforeSlotbarSelect", "afterSlotbarSelect", "onSlotDblClick", "onCountryChanged",
        "beforeFullUpdate", "afterFullUpdate", "onSlotBattleBtn", "applySlotSelectionOverride"])
      if (this[funcName])
        this[funcName] = callback.make(this[funcName], this.ownerWeak)
  }

  function refreshAll() {
    this.fillCountries()

    if (!this.singleCountry)
      setShowUnit(this.getCurSlotUnit(), this.getHangarFallbackUnitParams())

    if (this.crewId != null)
      this.crewId = null
    if (this.ownerWeak) 
      this.ownerWeak.setSlotbarPresetsListAvailable(this.needPresetsPanel && canChangeCrewUnits())
  }

  function getForcedCountry() { 
    if (this.singleCountry)
      return this.singleCountry
    if (!canChangeCountry())
      return profileCountrySq.value
    if (!this.isCountryChoiceAllowed)
      return this.customCountry || profileCountrySq.value
    return null
  }

  function addCrewData(list, params) {
    let crew = params?.crew
    let data = {
      crew = crew,
      unit = null,
      isUnlocked = true,
      status = bit_unit_status.owned
      idInCountry = crew?.idInCountry ?? -1 
      idCountry = crew?.idCountry ?? -1         
    }.__update(params)

    data.crewIdVisible <- data?.crewIdVisible ?? list.len()

    let canSelectEmptyCrew = this.shouldSelectCrewRecruit
      || !this.needActionsWithEmptyCrews
      || (crew?.country != null && !isCountrySlotbarHasUnits(crew.country) && data.idInCountry == 0)
    data.isSelectable <- data?.isSelectable
      ?? ((data.isUnlocked || !this.shouldSelectAvailableUnit) && (canSelectEmptyCrew || data.unit != null))
    let isControlledUnit = !is_respawn_screen()
      && is_player_unit_alive()
      && get_player_unit_name() == data.unit?.name
    if (this.haveRespawnCost
        && data.isSelectable
        && data.unit
        && this.totalSpawnScore >= 0
        && (this.totalSpawnScore < data.unit.getSpawnScore() || this.totalSpawnScore < data.unit.getMinimumSpawnScore())
        && !isControlledUnit)
      data.isSelectable = false

    if (data.isSelectable && data.unit && !(this.missionRules?.canRespawnOnUnitByRageTokens(data.unit) ?? true))
      data.isSelectable = false

    list.append(data)
    return data
  }

  function getUnitStatus(unit, crew, country) {
    let isUnlocked = (!this.needCheckUnitUnlock || !isRequireUnlockForUnit(unit))
      && isUnitUnlockedInSlotbar(unit, crew, country, this.missionRules, true)
    if (unit == null)
      return {
        status = bit_unit_status.empty
        isUnlocked
      }

    if (!isUnlocked)
      return {
        status = bit_unit_status.locked
        isUnlocked
      }
    if (!is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, false))
      return {
        status = bit_unit_status.broken
        isUnlocked
      }

    local disabled = !isUnitEnabledForSlotbar(unit, this)
    if (this.checkRespawnBases)
      disabled = disabled || !getAvailableRespawnBases(unit.tags).len()
    if (disabled)
      return {
        status = bit_unit_status.disabled
        isUnlocked
      }

    return {
      status = getBitStatus(unit)
      isUnlocked
    }
  }

  function gatherVisibleCrewsConfig(onlyForCountryIdx = null) {
    let res = []
    let country = this.getForcedCountry()
    let needNewSlot = !isCrewListOverrided.get() && this.showNewSlot
    let needShowLockedSlots = this.missionRules == null || this.missionRules.needShowLockedSlots
    let needEmptySlot = !isCrewListOverrided.get() && needShowLockedSlots && this.showEmptySlot

    let crewsListFull = getCrewsList()
    for (local c = 0; c < crewsListFull.len(); c++) {
      if (onlyForCountryIdx != null && onlyForCountryIdx != c)
        continue

      let visibleCountries = this.countriesToShow ?? getShopVisibleCountries()
      let listCountry = crewsListFull[c].country
      if ((this.singleCountry != null && this.singleCountry != listCountry)
        || visibleCountries.indexof(listCountry) == null
        || (!needEmptySlot && !isCountrySlotbarHasUnits(listCountry)))
        continue

      let countryData = {
        country = listCountry
        id = c
        isEnabled = !country || country == listCountry
        crews = []
      }
      res.append(countryData)

      if (!countryData.isEnabled)
        continue

      let curPreset = ::slotbarPresets.getCurrentPreset(listCountry)
      local crewInSlots = curPreset?.crewInSlots ?? []
      if (!needEmptySlot)
        crewInSlots = crewInSlots.filter(@(id) curPreset?.crews.contains(id) ?? false)

      let crewsList = crewsListFull[c].crews
      foreach (idx, crew in crewsList) {
        let unit = this.getCurCrewUnit(crew)

        if (!unit && !needEmptySlot)
          continue

        let unitName = unit?.name ?? ""
        let { isUnlocked, status } = this.getUnitStatus(unit, crew, country)
        let isUnitForcedVisible = this.missionRules && this.missionRules.isUnitForcedVisible(unitName)
        let isUnitForcedHiden = this.missionRules && this.missionRules.isUnitForcedHiden(unitName)
        let isUnitEnabledByRandomGroups = !this.missionRules || this.missionRules.isUnitEnabledByRandomGroups(unitName)
        let isAllowedByLockedSlots = isUnitForcedVisible || needShowLockedSlots
          || status == bit_unit_status.owned || status == bit_unit_status.empty
        if (unit && (!isAllowedByLockedSlots || !isUnitEnabledByRandomGroups || isUnitForcedHiden))
          continue

        let crewIdVisible = crewInSlots.indexof(crew.id) ?? idx
        this.addCrewData(countryData.crews,
          { crew = crew, unit = unit, isUnlocked = isUnlocked, status = status, crewIdVisible })
      }

      if (!needNewSlot)
        continue

      let slotCostTbl = get_crew_slot_cost(listCountry)
      if (!slotCostTbl || (slotCostTbl.costGold > 0 && !hasFeature("SpendGold")))
        continue

      this.addCrewData(countryData.crews,
        { idInCountry = crewsList.len()
          idCountry = c
          cost = Cost(slotCostTbl.cost, slotCostTbl.costGold)
        })
    }
    return res
  }

  
  function calcSelectedCrewData(crewsConfig) {
    let forcedCountry = this.getForcedCountry()
    local unitShopCountry = forcedCountry || profileCountrySq.value
    local curUnit = getPlayerCurUnit()
    local curCrewId = this.crewId

    if (!forcedCountry && !curCrewId) {
      let unlockedCountries = getUnlockedCountries()
      if (!isCountryAvailable(unitShopCountry) && unlockedCountries.len() > 0)
        unitShopCountry = unlockedCountries[0]
      if (curUnit && curUnit.shopCountry != unitShopCountry)
        curUnit = null
    }
    else if (forcedCountry && this.curSlotIdInCountry >= 0) {
      let curCrew = getCrew(this.curSlotCountryId, this.curSlotIdInCountry)
      if (curCrew)
        curCrewId = curCrew.id
    }

    if (curCrewId || this.shouldSelectCrewRecruit)
      curUnit = null

    local isFoundCurUnit = false
    local selCrewData = null
    foreach (countryData in crewsConfig) {
      if (!countryData.isEnabled)
        continue

      
      local firstAvailableCrewData = null
      let selCrewidInCountry = getSelectedCrews(countryData.id)
      foreach (crewData in countryData.crews) {
        let crew = crewData.crew
        let unit = crewData.unit
        let isSelectable = crewData.isSelectable
        if ((crew?.id != null && curCrewId == crew.id)
          || (unit && unit == curUnit)
          || (!crew && this.shouldSelectCrewRecruit)) {
          selCrewData = crewData
          isFoundCurUnit = true
          if (isSelectable)
            break
        }

        if (isSelectable
          && (!firstAvailableCrewData || selCrewidInCountry == crew?.idInCountry))
          firstAvailableCrewData = crewData
      }

      if (isFoundCurUnit && selCrewData.isSelectable)
        break

      if (firstAvailableCrewData
          && (!selCrewData || !selCrewData.isSelectable || unitShopCountry == countryData.country))
        selCrewData = firstAvailableCrewData

      if (!selCrewData && countryData.crews.len())
        selCrewData = countryData.crews[0] 
    }

    return selCrewData
  }

  
  function getSelectedCrewDataInCountry(countryData) {
    local selCrewData = null
    let selCrewIdInCountry = getSelectedCrews(countryData.id)
    foreach (crewData in countryData.crews) {
      if (crewData.idInCountry == selCrewIdInCountry) {
        selCrewData = crewData
        break
      }

      if (!selCrewData || (crewData.isSelectable && !selCrewData.isSelectable))
        selCrewData = crewData
    }
    return selCrewData
  }

  function fillCountries() {
    if (!isLoggedIn.get())
      return
    if (this.slotbarOninit) {
      script_net_assert_once("slotbar recursion", "init_slotbar: recursive call found")
      return
    }

    if (!getCrewsList().len()) {
      if (isLoggedIn.get() && (get_cur_circuit_name().indexof("production") != null
        || get_cur_circuit_name() == "nightly"))
          scene_msg_box("no_connection", null,
            loc("char/no_connection"), [["ok", startLogout ]], "ok")
      return
    }

    this.slotbarOninit = true
    initSelectedCrews()
    updateCrewSkillsAvailable()
    let crewsConfig = this.gatherVisibleCrewsConfig()
    this.selectedCrewData = this.calcSelectedCrewData(crewsConfig)

    let isFullSlotbar = crewsConfig.len() > 1 || this.showAlwaysFullSlotbar
    let hasCountryTopBar = isFullSlotbar && this.showTopPanel && !this.singleCountry
    if (hasCountryTopBar)
      initSlotbarTopBar(this.scene, this.showRepairBox) 

    this.crewsObj.hasHeader = !hasCountryTopBar && this.showSingleCountryFlag  ? "yes" : "no"
    this.crewsObj.hasBackground = isFullSlotbar ? "no" : "yes"
    let hObj = this.scene.findObject("slotbar_background")
    hObj.show(isFullSlotbar)
    hObj.hasPresetsPanel = this.needPresetsPanel ? "yes" : "no"
    if (showConsoleButtons.value)
      this.updateConsoleButtonsVisible(hasCountryTopBar)

    let countriesView = {
      hasNotificationIcon = this.hasResearchesBtn
      countries = []
    }
    local selCountryIdx = 0
    let ediff = getShopDiffCode()
    foreach (idx, countryData in crewsConfig) {
      let country = countryData.country
      if (countryData.id == this.selectedCrewData?.idCountry)
        selCountryIdx = idx

      local bonusData = null
      if (!is_first_win_reward_earned(country, INVALID_USER_ID))
        bonusData = this.getCountryBonusData(country)

      let cEnabled = countryData.isEnabled
      let cUnlocked = isCountryAvailable(country)
      let tooltipText = !cUnlocked ? loc("mainmenu/countryLocked/tooltip")
        : loc(country)
      countriesView.countries.append({
        countryIdx = countryData.id
        country = this.customViewCountryData?[country].locId ?? country
        tooltipText = tooltipText
        countryIcon = getCountryIcon(
          this.customViewCountryData?[country].icon ?? country, false, !cUnlocked || !cEnabled)
        bonusData = bonusData
        isEnabled = cEnabled && cUnlocked
        seenIconCfg = bhvUnseen.makeConfigStr(seenList.id,
          getUnlockIdsByCountry(country, ediff))
      })
    }

    let countriesNestObj = this.headerObj
    let countriesObjsCount = countriesNestObj.childrenCount()
    local needUpdateCountriesMarkup = countriesObjsCount != countriesView.countries.len()
    if (!needUpdateCountriesMarkup)
      for (local i = 0; i < countriesObjsCount; i++) {
         needUpdateCountriesMarkup = countriesView.countries.findindex(
           function(v) {
             let countryObj = countriesNestObj.getChild(i)
             return v.country == countryObj?.countryId && v.isEnabled == countryObj.isEnabled()
           }) == null
         if (needUpdateCountriesMarkup)
           break
      }
    if (needUpdateCountriesMarkup) {
      let countriesData = handyman.renderCached("%gui/slotbar/slotbarCountryItem.tpl", countriesView)
      this.guiScene.replaceContentFromText(this.headerObj, countriesData, countriesData.len(), this)
    }

    let needUpdateCountryContent = this.headerObj.getValue() == selCountryIdx
    this.headerObj.setValue(selCountryIdx)
    this.updateMarkers()
    if (needUpdateCountryContent)
      this.onHeaderCountry(this.headerObj)

    if (this.selectedCrewData) {
      let selItem = getSlotObj(this.crewsObj, this.selectedCrewData.idCountry, this.selectedCrewData.idInCountry)
      if (selItem)
        this.guiScene.performDelayed(this, function() {
          if (checkObj(selItem) && selItem.isVisible())
            selItem.scrollToView()
        })
    }

    this.slotbarOninit = false
    this.guiScene.applyPendingChanges(false)

    let countriesNestMaxWidth = toPixels(this.guiScene, "1@slotbarCountriesMaxWidth")
    let countriesNestWithBtnsObj = this.scene.findObject("header_countries_nest")
    if (countriesNestWithBtnsObj.getSize()[0] > countriesNestMaxWidth)
      this.headerObj.isShort = "yes"

    let needEvent = this.selectedCrewData
      && ((this.curSlotCountryId >= 0 && this.curSlotCountryId != this.selectedCrewData.idCountry)
        || (this.curSlotIdInCountry >= 0 && this.curSlotIdInCountry != this.selectedCrewData.idInCountry))
    if (needEvent) {
      let cObj = this.scene.findObject($"airs_table_{this.selectedCrewData.idCountry}")
      if (checkObj(cObj)) {
        this.skipCheckAirSelect = true
        this.onSlotbarSelect(cObj)
      }
    }
    else {
      this.curSlotCountryId   = this.selectedCrewData?.idCountry ?? -1
      this.curSlotIdInCountry = this.selectedCrewData?.idInCountry ?? -1
      selectCrew(this.curSlotCountryId, this.curSlotIdInCountry)
    }
  }

  getCountryBonusData = @(country) getBonus(
    shop_get_first_win_xp_rate(country),
    shop_get_first_win_wp_rate(country), "item")

  function fillCountryContent(countryData, tblObj) {
    this.updateSlotbarHint()
    if (this.loadedCountries?[countryData.id] == getCrewsListVersion()
      || !checkObj(tblObj))
      return

    this.loadedCountries[countryData.id] <- getCrewsListVersion()
    this.lastUpdatedVersion = getCrewsListVersion()

    let selCrewData = this.selectedCrewData?.idCountry == countryData.id
      ? this.selectedCrewData
      : this.getSelectedCrewDataInCountry(countryData)

    this.updateSlotRowView(countryData, tblObj)
    if (selCrewData)
      tblObj.setValue(selCrewData.crewIdVisible)

    foreach (crewData in countryData.crews)
      if (crewData.unit) {
        let id = getSlotObjId(countryData.id, crewData.idInCountry)
        fillUnitSlotTimers(tblObj.findObject(id), crewData.unit)
        showAirExpWpBonus(tblObj.findObject($"{id}-bonus"), crewData.unit.name)
      }

    this.updateMissionInfoVisibility()
  }

  function checkUpdateCountryInScene(countryIdx) {
    if (this.loadedCountries?[countryIdx] == getCrewsListVersion())
      return

    let countryData = this.gatherVisibleCrewsConfig(countryIdx)?[0]
    if (!countryData)
      return

    this.fillCountryContent(countryData, this.scene.findObject($"airs_table_{countryData.id}"))
  }

  function getCurSlotUnit() {
    return getCrewUnit(getCrew(this.curSlotCountryId, this.curSlotIdInCountry))
  }

  function getCurCrew() { 
    return getCrew(this.curSlotCountryId, this.curSlotIdInCountry)
  }

  function getCurCountry() {
    return getCrewsList()?[this.curSlotCountryId]?.country ?? ""
  }

  function getCurrentEdiff() {
    if (u.isFunction(this.ownerWeak?.getCurrentEdiff))
      return this.ownerWeak.getCurrentEdiff()
    return getCurrentGameModeEdiff()
  }

  function getSlotbarActions() {
    return this.slotbarActions ?? this.ownerWeak?.getSlotbarActions?()
  }

  function getCurrentAirsTable() {
    return this.scene.findObject($"airs_table_{this.curSlotCountryId}")
  }

  function getCurrentCrewSlot() {
    return getSlotObj(this.scene, this.curSlotCountryId, this.curSlotIdInCountry)
  }

  function getHangarFallbackUnitParams() {
    return {
      country = this.getCurCountry()
      slotbarUnits = (getCrewsList()?[this.curSlotCountryId].crews ?? [])
        .map(@(crew) getCrewUnit(crew))
        .filter(@(unit) unit != null)
    }
  }

  function getSlotIdByObjId(slotObjId, countryId) {
    let prefix = $"td_slot_{countryId}_"
    if (!startsWith(slotObjId, prefix))
      return -1
    return to_integer_safe(slotObjId.slice(prefix.len()), -1)
  }

  function getSelSlotDataByObj(obj) {
    let res = {
      isValid = this.selectOnHover
      countryId = -1
      crewIdInCountry = -1
    }

    let countryIdStr = getObjIdByPrefix(obj, "airs_table_")
    if (!countryIdStr)
      return res
    res.countryId = countryIdStr.tointeger()

    let curValue = getObjValidIndex(obj)
    if (curValue < 0)
      return res

    let curSlotId = obj.getChild(curValue).id
    res.crewIdInCountry = this.getSlotIdByObjId(curSlotId, res.countryId)
    res.isValid = res.crewIdInCountry >= 0
    return res
  }

  function onSlotbarSelect(obj) {
    if (!checkObj(obj))
      return

    if (this.slotbarOninit || this.skipCheckAirSelect || !this.shouldCheckQueue) {
      this.onSlotbarSelectImpl(obj)
      this.skipCheckAirSelect = false
    }
    else
      this.checkedAirChange(
         function() {
          if (checkObj(obj))
            this.onSlotbarSelectImpl(obj)
        },
         function() {
          if (checkObj(obj)) {
            this.skipCheckAirSelect = true
            this.selectTblAircraft(obj, getSelectedCrews(this.curSlotCountryId))
          }
        }
      )
  }

  function onSlotbarSelectImpl(obj) {
    if (!checkObj(obj))
      return

    let selSlot = this.getSelSlotDataByObj(obj)
    if (!selSlot.isValid)
      return
    if (this.curSlotCountryId == selSlot.countryId
        && this.curSlotIdInCountry == selSlot.crewIdInCountry)
      return

    if (this.beforeSlotbarSelect) {
      this.ignoreCheckSlotbar = true
      this.beforeSlotbarSelect(
        Callback(function() {
          this.ignoreCheckSlotbar = false
          if (checkObj(obj))
            this.applySlotSelection(obj, selSlot)
        }, this),
        Callback(function() {
          this.ignoreCheckSlotbar = false
          if (this.curSlotCountryId != selSlot.countryId)
            this.setCountry(getCrewsList()?[this.curSlotCountryId]?.country)
          else if (checkObj(obj))
            this.selectTblAircraft(obj, this.curSlotIdInCountry)
        }, this),
        selSlot
      )
    }
    else
      this.applySlotSelection(obj, selSlot)
  }

  function onUnitSlotMouseEnter(obj) {
    if (this.selectOnHover)
      this.selectCrew(to_integer_safe(obj.id.split("_").top(), -1))
  }

  function onSlotbarMouseLeave(_obj) {
    if (this.selectOnHover)
      this.selectCrew(-1)
  }

  function applySlotSelectionDefault(_prevSlot, restorePrevSelection) {
    let crew = getCrew(this.curSlotCountryId, this.curSlotIdInCountry)
    if (crew) {
      let unit = this.getCurCrewUnit(crew)
      if (unit != null || (!isCountrySlotbarHasUnits(crew.country) && this.curSlotIdInCountry == 0))
        this.setCrewUnit(unit)
      if (!unit && this.needActionsWithEmptyCrews && !this.skipActionWithEmptySlot)
        this.onSlotChangeAircraft()
      return
    }

    if (!this.needActionsWithEmptyCrews || (this.curSlotCountryId not in getCrewsList()))
      return

    let country = getCrewsList()[this.curSlotCountryId].country

    let rawCost = get_crew_slot_cost(country)
    let cost = rawCost ? Cost(rawCost.cost, rawCost.costGold) : Cost()
    if (!checkBalanceMsgBox(cost)) {
      restorePrevSelection()
      return
    }

    if (cost <= zero_money) {
      this.purchaseNewSlot(country)
      return
    }

    let msgText = warningIfGold(
      format(loc("shop/needMoneyQuestion_purchaseCrew"),
        cost.getTextAccordingToBalance()),
      cost)
    this.ignoreCheckSlotbar = true
    this.msgBox("need_money", msgText,
      [["ok",
        function() {
          this.ignoreCheckSlotbar = false
          this.purchaseNewSlot(country)
        }
       ],
       ["cancel", restorePrevSelection ]
      ], "ok")
  }

  function applySlotSelection(obj, selSlot) {
    let prevSlot = { countryId = this.curSlotCountryId, crewIdInCountry = this.curSlotIdInCountry }
    this.curSlotCountryId = selSlot.countryId
    this.curSlotIdInCountry = selSlot.crewIdInCountry

    if (!this.slotbarOninit)
      (this.applySlotSelectionOverride ?? this.applySlotSelectionDefault)(prevSlot,
        Callback(function() {
          if (this.curSlotCountryId != selSlot.countryId)
            return
          this.ignoreCheckSlotbar = false
          this.skipActionWithEmptySlot = true
          this.selectTblAircraft(obj, getSelectedCrews(this.curSlotCountryId))
          this.skipActionWithEmptySlot = false
        }, this))
    this.afterSlotbarSelect?()
  }

  



  function selectCrew(crewIdInCountry) {
    let objId =$"airs_table_{this.curSlotCountryId}"
    let obj = this.scene.findObject(objId)
    if (checkObj(obj))
      this.selectTblAircraft(obj, crewIdInCountry)
  }

  function selectTblAircraft(tblObj, slotIdInCountry = 0) {
    if (!checkObj(tblObj) || (slotIdInCountry < 0 && !this.selectOnHover))
      return
    let slotIdx = this.getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
    if (slotIdx < 0 && !this.selectOnHover)
      return
    tblObj.setValue(slotIdx)
  }

  function getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry) {
    if (!tblObj.childrenCount())
      return -1
    if (tblObj?.id != $"airs_table_{this.curSlotCountryId}") {
      let tblObjId = tblObj?.id         
      let countryId = this.curSlotCountryId  
      script_net_assert_once("bad slot country id", "Error: Try to select crew from wrong country")
      return -1
    }
    let prefix = $"td_slot_{this.curSlotCountryId}_"
    for (local i = 0; i < tblObj.childrenCount(); i++) {
      let id = getObjIdByPrefix(tblObj.getChild(i), prefix)
      if (!id) {
        let objId = tblObj.getChild(i).id 
        script_net_assert_once("bad slot id", "Error: Bad slotbar slot id")
        continue
      }

      if (to_integer_safe(id) == slotIdInCountry)
        return i
    }

    return -1
  }

  function onSlotbarDblClick() {
    if (!this.isValid())
      return
    let cellObj = this.scene.findObject($"td_slot_{this.curSlotCountryId}_{this.curSlotIdInCountry}")
    if (!cellObj?.isValid() || !cellObj.isHovered())
      return
    this.onSlotDblClick(this.getCurCrew())
  }

  function checkSelectCountryByIdx(obj) {
    let idx = obj.getValue()
    let countryIdx = to_integer_safe(
      getObjIdByPrefix(obj.getChild(idx), "header_country"), this.curSlotCountryId)
    if (this.curSlotCountryId >= 0 && this.curSlotCountryId != countryIdx && countryIdx in getCrewsList()
        && !isCountryAvailable(getCrewsList()[countryIdx].country) && getUnlockedCountries().len()) {
      this.msgBox("notAvailableCountry", loc("mainmenu/countryLocked/tooltip"),
             [["ok",  function() {
               if (checkObj(obj))
                 obj.setValue(this.curSlotCountryId)
             } ]], "ok")
      return false
    }
    return true
  }

  function checkCreateCrewsNest(countryData) {
    let countriesCount = this.crewsObj.childrenCount()
    let animBlockId =$"crews_anim_{countryData.idx}"
    for (local i = 0; i < countriesCount; i++) {
      let animObj = this.crewsObj.getChild(i)
      animObj.animation = animObj?.id == animBlockId ? "show" : "hide"

      if (animObj?.id != animBlockId && animObj?["_transp-timer"] == null)
        animObj["_transp-timer"] = "0"
    }

    let animBlockObj = this.crewsObj.findObject(animBlockId)
    if (checkObj(animBlockObj))
      return

    let country = countryData.country
    let blk = handyman.renderCached("%gui/slotbar/slotbarItem.tpl", {
      countryIdx = countryData.idx
      needSkipAnim = countriesCount == 0
      alwaysShowBorder = this.alwaysShowBorder
      countryImage = getCountryIcon(this.customViewCountryData?[country].icon ?? country, false)
      slotbarBehavior = this.slotbarBehavior
      selectOnHover = this.selectOnHover
      highlightSelected = this.highlightSelected
    })
    this.guiScene.appendWithBlk(this.crewsObj, blk, this)
  }

  function onHeaderCountry(obj) {
    let countryData = this.getCountryDataByObject(obj)
    if (this.slotbarOninit || this.skipCheckCountrySelect) {
      this.onSlotbarCountryImpl(countryData)
      this.skipCheckCountrySelect = false
      return
    }

    let lockedCountryData = this.getLockedCountryData?()
    if (lockedCountryData != null
      && !isInArray(countryData.country, lockedCountryData.availableCountries)) {
      this.setCountry(profileCountrySq.value)
      showInfoMsgBox(lockedCountryData.reasonText)
    }
    else {
      this.switchSlotbarCountry(this.headerObj, countryData)
    }

    this.updateMarkers()
  }

  function onCountriesListDblClick() {
    if (this.onCountryDblClick)
      this.onCountryDblClick()
  }

  function switchSlotbarCountry(obj, countryData) {
    if (!this.shouldCheckQueue) {
      if (this.checkSelectCountryByIdx(obj)) {
        this.onSlotbarCountryImpl(countryData)
        ::slotbarPresets.setCurrentGameModeByPreset(countryData.country)
      }
    }
    else {
      if (!this.checkSelectCountryByIdx(obj))
        return

      this.checkedCrewAirChange(
        function() {
          if (checkObj(obj)) {
            this.onSlotbarCountryImpl(countryData)
            ::slotbarPresets.setCurrentGameModeByPreset(countryData.country)
          }
        },
        function() {
          if (checkObj(obj))
            this.setCountry(profileCountrySq.value)
        }
      )
    }
  }

  function setCountry(country) {
    foreach (idx, c in getCrewsList())
      if (c.country == country) {
        if (!checkObj(this.headerObj) || this.headerObj.getValue() == idx)
          break

        this.skipCheckCountrySelect = true
        this.skipCheckAirSelect = true
        this.headerObj.setValue(idx)
        this.updateMarkers()
        break
      }
  }

  function getCountryDataByObject(obj) {
    if (!checkObj(obj))
      return null

    let curValue = obj.getValue()
    if (obj.childrenCount() <= curValue)
      return null

    let countryIdx = to_integer_safe(
      getObjIdByPrefix(obj.getChild(curValue), "header_country"), this.curSlotCountryId)
    let country = getCrewsList()[countryIdx].country

    return {
      idx = countryIdx
      country = country
    }
  }

  function onSlotbarCountryImpl(countryData) {
    if (!countryData)
      return

    this.skipActionWithEmptySlot = true
    this.checkCreateCrewsNest(countryData)
    this.checkUpdateCountryInScene(countryData.idx)

    if (!this.singleCountry) {
      if (!this.checkSelectCountryByIdx(this.headerObj))
        return

      switchProfileCountry(countryData.country)
      if (isCrewListOverrided.get() && !this.slotbarOninit && !this.skipCheckCountrySelect)
        selectCountryForCurrentOverrideSlotbar(countryData.country)
      this.onSlotbarSelect(this.crewsObj.findObject($"airs_table_{countryData.idx}"))
    }
    else
      this.onSlotbarSelect(this.crewsObj.findObject($"airs_table_{countryData.idx}"))

    this.skipActionWithEmptySlot = false
    this.onSlotbarCountryChanged()
  }

  function onSlotbarCountryChanged() {
    if (this.ownerWeak?.presetsListWeak)
      this.ownerWeak.presetsListWeak.update()
    if (this.onCountryChanged)
      this.onCountryChanged()
  }

  function prevCountry(_obj) { this.switchCountry(-1) }

  function nextCountry(_obj) { this.switchCountry(1) }

  function switchCountry(way) {
    if (this.singleCountry)
      return

    if (this.headerObj.childrenCount() <= 1)
      return

    let curValue = this.headerObj.getValue()
    let value = getNearestSelectableChildIndex(this.headerObj, curValue, way)
    if (value != curValue) {
      this.headerObj.setValue(value)
      this.updateMarkers()
    }
  }

  function onSlotChangeAircraft(obj = null) {
    let crewIdInCountry = obj?.crewIdInCountry.tointeger()
    if (crewIdInCountry != null)
      this.selectCrew(crewIdInCountry)

    let crew = this.getCurCrew()
    if (!crew)
      return

    let slotbar = this
    this.ignoreCheckSlotbar = true
    this.checkedCrewAirChange(function() {
        this.ignoreCheckSlotbar = false
        selectUnitHandler.open(crew, slotbar)
      },
      function() {
        this.ignoreCheckSlotbar = false
        this.checkSlotbar()
      }
    )
  }

  function shade(shouldShade) {
    if (this.isShaded == shouldShade)
      return

    this.isShaded = shouldShade
    let shadeObj = this.scene.findObject("slotbar_shade")
    if (checkObj(shadeObj))
      shadeObj.animation = this.isShaded ? "show" : "hide"
    if (showConsoleButtons.value)
      this.updateConsoleButtonsVisible(!this.isShaded)
  }

  function updateConsoleButtonsVisible(isVisible) {
    showObjById("prev_country_btn", isVisible, this.scene)
    showObjById("next_country_btn", isVisible, this.scene)
  }

  function forceUpdate() {
    this.updateSlotbarImpl()
  }

  function fullUpdate() {
    this.doWhenActiveOnce("updateSlotbarImpl")
  }

  function updateSlotbarImpl() {
    if (this.ignoreCheckSlotbar)
      return

    this.loadedCountries.clear()
    if (this.beforeFullUpdate)
      this.beforeFullUpdate()

    this.curSlotCountryId = -1
    this.curSlotIdInCountry = -1

    this.refreshAll()
    if (this.afterFullUpdate)
      this.afterFullUpdate()
  }

  function checkSlotbar() {
    if(::slotbarPresets.isLoading)
      return

    if (this.ignoreCheckSlotbar || !isInMenu())
      return

    let curCountry = profileCountrySq.value

    if (!(this.curSlotCountryId in getCrewsList())
        || getCrewsList()[this.curSlotCountryId].country != curCountry
        || this.curSlotIdInCountry != getSelectedCrews(this.curSlotCountryId)
        || (this.getCurSlotUnit() == null && isCountrySlotbarHasUnits(curCountry)))
      this.updateSlotbarImpl()
    else if (this.selectedCrewData && this.selectedCrewData?.unit != getPlayerCurUnit())
      this.refreshAll()
  }

  function onSceneActivate(show) {
    base.onSceneActivate(show)
    if (this.checkActiveForDelayedAction())
      this.checkSlotbar()
  }

  function onEventModalWndDestroy(p) {
    base.onEventModalWndDestroy(p)
    if (this.checkActiveForDelayedAction())
      this.checkSlotbar()
  }

  function purchaseNewSlot(country) {
    this.ignoreCheckSlotbar = true

    let onTaskSuccess = Callback(function() {
      this.ignoreCheckSlotbar = false
      this.onSlotChangeAircraft()
    }, this)

    let onTaskFail = Callback(function(_result) { this.ignoreCheckSlotbar = false }, this)

    if (!purchaseNewCrewSlot(country, onTaskSuccess, onTaskFail))
      this.ignoreCheckSlotbar = false
  }

  
  function getBoxOfUnits() {
    let obj = this.scene.findObject($"airs_table_{this.curSlotCountryId}")
    if (!checkObj(obj))
      return null

    let box = GuiBox().setFromDaguiObj(obj)
    let pBox = GuiBox().setFromDaguiObj(obj.getParent())
    if (box.c2[0] > pBox.c2[0])
      box.c2[0] = pBox.c2[0] + pBox.c1[0] - box.c1[0]
    return box
  }

  
  function getBoxOfCountries() {
    if (!checkObj(this.headerObj))
      return null

    return GuiBox().setFromDaguiObj(this.headerObj)
  }

  function getSlotsData(unitId = null, slotCrewId = -1, searchCountryId = -1, withEmptySlots = false) {
    let unitSlots = []
    foreach (countryId, countryData in getCrewsList()) {
      if (this.singleCountry && countryData.country != this.singleCountry)
        continue

      if (searchCountryId != -1 && countryId != searchCountryId)
        continue

      foreach (idInCountry, crew in countryData.crews) {
        if (slotCrewId != -1 && slotCrewId != (crew?.id ?? -1))
          continue
        let unit = this.getCurCrewUnit(crew)
        if (unitId && unit && unitId != unit.name)
          continue
        let obj = getSlotObj(this.scene, countryId, idInCountry)
        if (obj && (unit || withEmptySlots))
          unitSlots.append({
            unit      = unit
            crew      = crew
            countryId = countryId
            obj       = obj
          })
      }
    }
    return unitSlots
  }

  function getCurCrewUnit(crew) {
    return getCrewUnit(crew)
  }

  function updateDifficulty(unitSlots = null) {
    unitSlots = unitSlots || this.getSlotsData()

    let showBR = hasFeature("SlotbarShowBattleRating")
    let curEdiff = this.getCurrentEdiff()

    foreach (slot in unitSlots) {
      let obj = slot.obj.findObject("rank_text")
      if (checkObj(obj)) {
        local unitRankText = getUnitSlotRankText(slot.unit, slot.crew, showBR, curEdiff)
        obj.setValue(unitRankText)
      }
    }
  }

  function updateCrews(unitSlots = null) {
    if (isCrewListOverrided.get())
      return

    unitSlots = unitSlots || this.getSlotsData()

    foreach (slot in unitSlots) {
      slot.obj["hasUnseenIcon"] = isCrewNeedUnseenIcon(slot.crew, slot.unit) ? "yes" : "no"

      let crewLevelObj = slot.obj.findObject("crew_level")
      if (checkObj(crewLevelObj)) {
        let crewLevelText = slot.unit
          ? getCrewLevel(slot.crew, slot.unit, slot.unit.getCrewUnitType()).tointeger().tostring()
          : ""
        crewLevelObj.setValue(crewLevelText)

        let crewLevelHintBlockObj = slot.obj.findObject("crew_level_hint_block")
        if (crewLevelHintBlockObj?.isValid())
          crewLevelHintBlockObj.setValue(crewLevelText)
      }

      let crewSpecObj = slot.obj.findObject("crew_spec")
      if (checkObj(crewSpecObj)) {
        let crewSpecIcon = getSpecTypeByCrewAndUnit(slot.crew, slot.unit).trainedIcon
        crewSpecObj["background-image"] = crewSpecIcon

        let crewSpecHintBlockObj = slot.obj.findObject("crew_spec_hint_block")
        if (crewSpecHintBlockObj?.isValid())
          crewSpecHintBlockObj["background-image"] = crewSpecIcon
      }
    }
  }

  function updateSlotsStatuses(unitSlots) {
    foreach (slot in unitSlots) {
      let { obj, unit, crew } = slot
      obj.shopStat = getUnitItemStatusText(this.getUnitStatus(unit, crew, unit.shopCountry).status)
      let isBroken = unit.isBroken()
      obj.isBroken = isBroken ? "yes" : "no"
      showObjById("repair_icon", isBroken, obj)
    }
  }

  function onSlotBattle(_obj) {
    if (this.onSlotBattleBtn)
      this.onSlotBattleBtn()
  }

  function onEventCrewsListChanged(_p) {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid() || this.lastUpdatedVersion == getCrewsListVersion())
        return
      this.fullUpdate()
    })
  }

  function onEventSlotbarPresetChangedWithoutProfileUpdate(_p) {
    this.fullUpdate()
  }

  function onEventCrewsOrderChanged(_p) {
    this.fullUpdate()
  }

  function onEventCrewSkillsChanged(params) {
    let crew = getTblValue("crew", params)
    if (crew)
      this.updateCrews(this.getSlotsData(null, crew.id))
  }

  function onEventQualificationIncreased(params) {
    let unit = getTblValue("unit", params)
    if (unit)
      this.updateCrews(this.getSlotsData(unit.name))
  }

  function onEventUnitRepaired(params) {
    this.updateSlotsStatuses(this.getSlotsData(params?.unit.name))
  }

  function updateMissionInfoVisibility() {
    if (!isInFlight())
      return

    this.guiScene.applyPendingChanges(false)

    let unitSlots = this.getSlotsData(null, -1, -1, true)
    local hasAllMissionBlocksEmpty = true
    foreach (slot in unitSlots) {
      let missionInfoObj = slot.obj.findObject("extraInfoBlockTop")
      if (!missionInfoObj?.isValid() || missionInfoObj?.hasInfo != "yes")
        continue

      hasAllMissionBlocksEmpty = false
      break
    }

    foreach (slot in unitSlots) {
      let missionInfoObj = slot.obj.findObject("extraInfoBlockTop")
      if (!missionInfoObj?.isValid())
        continue

      missionInfoObj.show(!hasAllMissionBlocksEmpty)

      let toBattleBtnObj = slot.obj.findObject("slotBtn_battle")
      if (toBattleBtnObj?.isValid())
        toBattleBtnObj["showAboveInfoBlock"] = hasAllMissionBlocksEmpty ? "no" : "yes"
    }

    let crewNestObj = this.scene.findObject($"crew_nest_{this.curSlotCountryId}")
    if (crewNestObj?.isValid())
      crewNestObj["noMissionBlock"] = hasAllMissionBlocksEmpty ? "yes" : "no"

    let slotbarTableObj = this.scene.findObject($"airs_table_{this.curSlotCountryId}")
    if (slotbarTableObj?.isValid())
      slotbarTableObj["noMissionBlock"] = hasAllMissionBlocksEmpty ? "yes" : "no"

    let countryCrewObj = this.scene.findObject("countries_crews")
    if (countryCrewObj?.isValid())
      countryCrewObj["noMissionBlock"] = hasAllMissionBlocksEmpty ? "yes" : "no"
  }

  function updateSpareCount(unitName) {
    let slotData = this.getSlotsData(unitName)?[0]
    if (slotData == null)
      return
    let { unit, crew, obj } = slotData
    if (unit == null)
      return
    let spareCountObj = obj.findObject("spareCount")
    if (!spareCountObj?.isValid())
      return

    let spareCount = !isCrewListOverrided.get() ? get_spare_aircrafts_count(unit.name) : 0
    let spareText = getSpareCountText(spareCount, crew, unit, this.missionRules)
    let hasSpareInfo = spareText != ""
    spareCountObj.show(hasSpareInfo)
    if (hasSpareInfo)
      spareCountObj.setValue(spareText)

    this.updateTopExtraInfoBlock(obj)
  }

  function updateTopExtraInfoBlock(slotObj) {
    this.guiScene.applyPendingChanges(false)
    let priceObj = slotObj.findObject("extraInfoPriceText")
    let isVisiblePrice = priceObj.hasInfo == "yes"
    let addHistoricalRespawnsNestObj = slotObj.findObject("additionalHistoricalRespawnsNest")
    let addHistoricalRespawnsObj = addHistoricalRespawnsNestObj.findObject("additionalHistoricalRespawns")
    let isVisibleAdditionalHisotircalRespawns = addHistoricalRespawnsNestObj.hasInfo == "yes"
    let addRespawnsObj = slotObj.findObject("additionalRespawns")
    let isVisibleAdditionalRespawns = addRespawnsObj.hasInfo == "yes"
    let spareCountObj = slotObj.findObject("spareCount")
    let isVisibleSpare = spareCountObj.hasInfo == "yes"
    if (isVisiblePrice) {
      let { priceWidth, addHistoricalRespawnsWidth, addRespawnsWidth
      } = calcUnitSlotMissionInfoTextsWidth(priceObj.getValue(), addHistoricalRespawnsObj.getValue(),
        addRespawnsObj.getValue(), spareCountObj.getValue())
      priceObj.width = priceWidth
      addHistoricalRespawnsNestObj.width = addHistoricalRespawnsWidth
      addRespawnsObj.width = addRespawnsWidth
    }
    slotObj.findObject("priceSeparator").show(isVisiblePrice && isVisibleAdditionalHisotircalRespawns)
    slotObj.findObject("additionalRespawnsSeparator").show(isVisibleAdditionalRespawns
      && (isVisiblePrice || isVisibleAdditionalHisotircalRespawns))
    slotObj.findObject("spareSeparator").show(isVisibleSpare
      && (isVisiblePrice || isVisibleAdditionalRespawns || isVisibleAdditionalHisotircalRespawns))
    let hasExtraInfo = isVisiblePrice || isVisibleAdditionalRespawns
      || isVisibleSpare || isVisibleAdditionalHisotircalRespawns
    slotObj.findObject("emptyExtraInfoText").show(!hasExtraInfo)
    slotObj.findObject("extraInfoBlockTop").hasInfo = hasExtraInfo ? "yes" : "no"
  }

  onEventUniversalSpareActivated = @(p) this.updateSpareCount(p.unit.name)
  onEventSparePurchased = @(p) this.updateSpareCount(p.unit.name)

  function onEventAutorefillChanged(params) {
    if (!("id" in params) || !("value" in params))
      return

    let obj = this.scene.findObject(params.id)
    if (obj && obj.getValue() != params.value)
      obj.setValue(params.value)
  }

  onEventAllModificationsPurchased = @(params) this.getSlotsData(params.unit.name)
    .map(@(slot) slot.obj)
    .filter(@(obj) obj?.isValid() && isUnitElite(params.unit))
    .each(@(obj) obj.isElite = "yes")

  function onOpenCrewWindow(obj) {
    let crew = getCrewById(obj.crewId.tointeger())
    if (crew.isEmpty) {
      this.msgBox("no_unit_in_slot", loc("msgBox/unitNecessaryForSlot"),
        [["ok", @() null]], "ok", { cancel_fn = @() null })
      return
    }

    if (handlersManager.findHandlerClassInScene(gui_handlers.CrewModalHandler)) {
      this.selectCrew(crew.idInCountry)
      return
    }

    gui_modal_crew({
      countryId = crew.idCountry,
      idInCountry = crew.idInCountry
    })
  }

  function updateSlotRowView(countryData, tblObj) {
    if (!countryData)
      return

    local countryDataCrews = countryData.crews
    let crewInSlots = ::slotbarPresets.getCurrentPreset(countryData.country)?.crewInSlots
    if(crewInSlots != null) {
      countryDataCrews = countryData.crews.map(function(c, idx) {
        c.slotIndex <- crewInSlots.indexof(c?.crew.id) ?? idx
        return c
      })
      countryDataCrews.sort(@(c1, c2) c1.slotIndex <=> c2.slotIndex)
    }
    let slotsData = []
    foreach (crewData in countryDataCrews) {
      let id = getSlotObjId(countryData.id, crewData.idInCountry)
      let crew = crewData.crew
      if (!crew) {
        let unitItem = buildUnitSlot(
          id,
          null,
          {
            emptyText = "#shop/recruitCrew",
            crewImage = $"#ui/gameuiskin#slotbar_crew_recruit_{countryData.country.slice(8)}"
            isCrewRecruit = true
            emptyCost = crewData.cost
            isSlotbarItem = true
            fullBlock     = this.needFullSlotBlock
            selectOnHover = this.selectOnHover
          })

        slotsData.append(this.needFullSlotBlock ? unitItem : SLOT_NEST_TAG.subst(unitItem))
        continue
      }

      let isVisualDisabled = crewData?.isVisualDisabled ?? false
      let isLocalState = !isCrewListOverrided.get() && (crewData?.isLocalState ?? true)
      let airParams = {
        emptyText      = isVisualDisabled ? "" : this.emptyText,
        crewImage      = $"#ui/gameuiskin#slotbar_crew_free_{countryData.country.slice(8)}"
        status         = getUnitItemStatusText(crewData.status),
        hasActions     = this.hasActions && !isCrewListOverrided.get()
        hasCrewHint    = this.hasCrewHint
        toBattle       = this.toBattle
        mainActionFunc = canChangeCrewUnits() ? "onSlotChangeAircraft" : ""
        mainActionText = "" 
        mainActionIcon = "#ui/gameuiskin#slot_change_aircraft.svg"
        crewId         = crew?.id
        isSlotbarItem  = true
        showBR         = hasFeature("SlotbarShowBattleRating")
        getEdiffFunc   = this.getCurrentEdiff.bindenv(this)
        hasExtraInfoBlock = this.hasExtraInfoBlock
        hasExtraInfoBlockTop = this.hasExtraInfoBlockTop
        showAdditionExtraInfo = this.showAdditionExtraInfo
        haveRespawnCost = this.haveRespawnCost
        haveSpawnDelay = this.haveSpawnDelay
        totalSpawnScore = this.totalSpawnScore
        sessionWpBalance = this.sessionWpBalance
        curSlotIdInCountry = crew.idInCountry
        curSlotCountryId = crew.idCountry
        unlocked = crewData.isUnlocked
        tooltipParams = {
          needCrewInfo = !isCrewListOverrided.get()
          showLocalState = isLocalState
          needCrewModificators = true
          needShopInfo = this.needCheckUnitUnlock
          crewId = crew?.id
        }
        missionRules = this.missionRules
        forceCrewInfoUnit = this.unitForSpecType
        isLocalState = isLocalState
        fullBlock        = this.needFullSlotBlock
        bottomLineText = this.needCheckUnitUnlock && isRequireUnlockForUnit(crewData.unit)
          ? getUnitRequireUnlockShortText(crewData.unit)
          : null
        selectOnHover = this.selectOnHover
        needDnD = this.draggableSlots && !isCrewListOverrided.get()
        showCrewUnseenIcon = this.showCrewUnseenIcon
        showCrewInfoTranslucent = this.showCrewInfoTranslucent
      }
      airParams.__update(this.getCrewDataParams(crewData))
      let unitItem = buildUnitSlot(id, crewData.unit, airParams)
      slotsData.append(this.needFullSlotBlock ? unitItem : SLOT_NEST_TAG.subst(unitItem))
    }

    let slotsDataString = "".join(slotsData)
    this.guiScene.replaceContentFromText(tblObj, slotsDataString, slotsDataString.len(), this)
  }

  getCrewDataParams = @(_crewData) {}
  getSlotbar = @() this

  function setCrewUnit(unit) {
    setShowUnit(unit, this.getHangarFallbackUnitParams())
    
    selectCrew(this.curSlotCountryId, this.curSlotIdInCountry, true)
  }

  function getDefaultDblClickFunc() {
    return Callback(function(crew) {
      if (isCrewListOverrided.get())
        return
      let unit = this.getCurCrewUnit(crew)
      if (unit)
        open_weapons_for_unit(unit, { curEdiff = this.getCurrentEdiff() })
    }, this)
  }

  function onSlotbarActivate(_obj) {
    if (!this.isValid())
      return
    let cellObj = this.scene.findObject($"td_slot_{this.curSlotCountryId}_{this.curSlotIdInCountry}")
    if (!cellObj?.isValid() || !cellObj.isHovered())
      return
    this.onSlotActivate(this.getCurCrew())
  }

  function defaultOnSlotActivateFunc(_crew) {
    if (this.hasActions && !isCrewListOverrided.get()) {
      if (isCountrySlotbarHasUnits(profileCountrySq.value))
        this.openUnitActionsList(this.getCurrentCrewSlot())
      else
        this.onSlotChangeAircraft()
    }
  }

  function updateWeaponryData(unitSlots = null) {
    if (isCrewListOverrided.get())
      return

    unitSlots = unitSlots ?? this.getSlotsData()
    foreach (slot in unitSlots) {
      let obj = slot.obj.findObject("weapons_icon")
      let unit = slot.unit
      if (!checkObj(obj) || unit == null)
        continue

      let weaponsStatus = getWeaponsStatusName((slot.crew?.isLocalState ?? true) && isUnitUsable(unit)
        ? checkUnitWeapons(unit)
        : UNIT_WEAPONS_READY
      )
      obj.weaponsStatus = weaponsStatus
    }
  }

  function onEventUnitBulletsChanged(p) {
    this.updateWeaponryData(this.getSlotsData(p.unit.name))
  }

  function onEventUnitWeaponChanged(p) {
    this.updateWeaponryData(this.getSlotsData(p.unitName))
  }

  function updateSlotbarHint() {
    let obj = showObjById("slotbarHint", this.slotbarHintText != "", this.scene)
    if (obj != null && this.slotbarHintText != "")
     obj.findObject("slotbarHintText").setValue(this.slotbarHintText)
  }

  function onEventLobbyIsInRoomChanged(p) {
    if (p.wasSessionInLobby != hasSessionInLobby())
      this.fullUpdate()
  }

  function onEventVisibleCountriesCacheInvalidate(_p) {
    if (this.loadedCountries.len() != getShopVisibleCountries().len())
      this.fullUpdate()
  }

  function onEventProfileUpdated(_) {
    if (!this.needCheckUnitUnlock) 
      return

    this.updateSlotsStatuses(this.getSlotsData(null, -1, this.curSlotCountryId))
  }

  function onUnitCellDragStart(obj) {
    let unit = getAircraftByName(obj?.unit_name)
    if (!unit)
      return
    removeAllGenericTooltip()
    if (gui_handlers.ActionsList.hasActionsListOnObject(obj)) 
      gui_handlers.ActionsList.removeActionsListFromObject(obj)
    startSlotbarUnitDnD({ draggedObj = obj, country = profileCountrySq.value, unit })
  }

  function onCrewDragStart(obj) {
    removeAllGenericTooltip()
    let draggedObj = obj.getParent().getParent().getParent()
    swapCrewsBegin(draggedObj, this.getCurrentAirsTable())
  }

  function onSwapCrews(obj) {
    let crewIdInCountry = obj.crewIdInCountry.tointeger()
    let crew = getCrew(this.curSlotCountryId, crewIdInCountry)
    if (!crew)
      return
    swapCrewHandler.open(crew, this.getCurrentAirsTable(), this)
  }

  function onCrewSlotClick(obj) {
    if (obj?.isEmptySlot != "yes") {
      let crewIdInCountry = obj.crewIdInCountry.tointeger()
      this.selectCrew(crewIdInCountry)
    }
    let handler = this
    if (obj?.hasActions == "yes")
      deferOnce(@() obj.isValid() ? handler.onOpenCrewPopup(obj) : null)
  }

  function onOpenCrewPopup(obj, closeOnUnhover = true, openByHover = false) {
    if (handlersManager.findHandlerClassInScene(gui_handlers.SwapCrewsHandler) != null)
      return

    if (this.crewPopupSlotObj?.isValid() && obj.isEqual(this.crewPopupSlotObj)) {
      let actionsList = handlersManager.findHandlerClassInScene(gui_handlers.ActionsList)
      if (actionsList && obj.isEqual(actionsList.parentObj)) {
        if (openByHover)
          return
        actionsList.close()
        this.crewPopupSlotObj = null
        return
      }
    }
    this.crewPopupSlotObj = obj

    let actions = []
    let thisHandler = this
    let crew = getCrewById(obj.crewId.tointeger())
    let hasUnit = (obj?.forcedUnit != null) || !(crew?.isEmpty ?? false)
    let unitForCrewInfo = hasUnit ? getAircraftByName(obj?.forcedUnit ?? crew?.aircraft) : null
    let isShowDragAndDropIcon = !showConsoleButtons.value

    if (this.hasActions) {
      actions.append({
        actionName   = "swap"
        action       = @() thisHandler.isValid() ? thisHandler.onSwapCrews(obj) : null
        text         = loc("slotbar/swapCrewButton")
        show         = true
        icon         = "#ui/gameuiskin#slot_change_aircraft.svg"
        isShowDragAndDropIcon
        dragAndDropIconHint = isShowDragAndDropIcon ? loc("slotbar/dragCrewHint") : null
        iconRotation = 90
      })

      if (!hasCrewModalWndInScene())
        actions.append({
          actionName   = "openCrewWnd"
          action       = @() thisHandler.isValid() ?  thisHandler.onOpenCrewWindow(obj) : null
          text         = loc("slotInfoPanel/crewButton")
          show         = true
          icon         = "#ui/gameuiskin#slot_crew.svg"
          haveWarning  = isCrewNeedUnseenIcon(crew, unitForCrewInfo)
        })
    }

    let params = {
      handler = null
      closeOnUnhover
      onDeactivateCb = null
      actions = actions
      cssParams = {
        menu_align = this.showCrewHintUnderSlot ? "bottom" : null,
        ["min-width"] = "1@mainMenuButtonWidth",
      }
      orientation = this.showCrewHintUnderSlot ? ALIGN.BOTTOM : ALIGN.TOP
      infoBlock = getSlotCrewHint(crew, unitForCrewInfo,
        {
          hasSeparator = this.hasActions ? true : false
          showAdditionExtraInfo = this.showAdditionExtraInfo
        }
      )
    }
    gui_handlers.ActionsList.open(obj, params)
  }

  function showCrewSlotHint(obj) {
    let handler = this
    deferOnce(@() obj.isValid() ? handler.onOpenCrewPopup(obj, true, true) : null)
  }

  function updateMarkers() {
    if (!this.hasResearchesBtn || this.singleCountry != null)
      return
    this.guiScene.applyPendingChanges(false)
    let countriesCount = this.headerObj.childrenCount()
    let needReinitCountriesWidths = (this.initialCountriesWidths?.len() ?? 0) != countriesCount
    if (!topMenuShopActive.get()) {
      if (!needReinitCountriesWidths)
        for (local i = 0; i < countriesCount; i++) {
          let countryObj = this.headerObj.getChild(i)
          let countryId = countryObj.countryId
          countryObj["width"] = this.initialCountriesWidths[countryId]
        }
      return
    }

    if (needReinitCountriesWidths) {
      this.initialCountriesWidths = {}
      for (local i = 0; i < countriesCount; i++) {
        let countryObj = this.headerObj.getChild(i)
        let countryId = countryObj.countryId
        this.initialCountriesWidths[countryId] <- countryObj.getSize()[0]
      }
    }

    let countryIndex = this.headerObj.getValue()
    for (local i = 0; i < countriesCount; i++) {
      let countryObj = this.headerObj.getChild(i)
      let countryId = countryObj.countryId
      let countryMarkersWidth = getCountryMarkersWidth(countryId)
      let needStack = (countryIndex != i) && this.initialCountriesWidths[countryId] * 0.95 < countryMarkersWidth
      let markersHolder = countryObj.findObject("markersHolder")
      let markersCount = markersHolder.childrenCount() - 1
      local counter = 0;

      for (local j = 0; j < markersCount; j++) {
        local markerObj = markersHolder.getChild(j)
        if (markerObj?.id == "unlockMarkerDiv")
          markerObj = markerObj.getChild(0)
        if (!markerObj.isVisible())
          continue

        markerObj["stacked"] = needStack ? "yes" : "no"
        markerObj["left"] = needStack ? $"{counter * 0.5}@markerWidth"
          : $"{counter}@markerWidth + {counter * 0.5}@blockInterval"

        counter++
      }

      countryObj["width"] = needStack ? $"{this.initialCountriesWidths[countryId]}"
        : $"{max(this.initialCountriesWidths[countryId], floor(countryMarkersWidth / 0.95))}"

      let tooltipArea = markersHolder.findObject("tooltipArea")
      tooltipArea["enable"] = needStack ? "yes" : "no"
      if (needStack)
        tooltipArea["width"] = $"{1 + 0.5 * (counter - 1)}@markerWidth"
    }
  }

  onEventShopWndSwitched = @(_p) this.updateMarkers()
  onEventCountryMarkersInvalidate = @(_p) this.updateMarkers()
  onUnitCellDrop = @() null
  onUnitCellMove = @() null
  onCrewDropFinish = @() null
  onCrewDrop = @() null
  onCrewMove = @() null
}
