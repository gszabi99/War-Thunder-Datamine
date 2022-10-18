from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let callback = require("%sqStdLibs/helpers/callback.nut")
let selectUnitHandler = require("%scripts/slotbar/selectUnitHandler.nut")
let { getWeaponsStatusName, checkUnitWeapons } = require("%scripts/weaponry/weaponryInfo.nut")
let { getNearestSelectableChildIndex } = require("%sqDagui/guiBhv/guiBhvUtils.nut")
let { getBitStatus, isRequireUnlockForUnit } = require("%scripts/unit/unitStatus.nut")
let { getUnitItemStatusText } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRequireUnlockShortText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { isCountrySlotbarHasUnits } = require("%scripts/slotbar/slotbarState.nut")
let { getCrew } = require("%scripts/crew/crew.nut")
let { setShowUnit, getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getAvailableRespawnBases } = require("guiRespawn")
let { getShopVisibleCountries } = require("%scripts/shop/shopCountriesList.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
let { getUnlockIdsByCountry } = require("%scripts/unlocks/unlockMarkers.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")

const SLOT_NEST_TAG = "unitItemContainer { {0} }"

::gui_handlers.SlotbarWidget <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/slotbar/slotbar.blk"
  ownerWeak = null
  slotbarOninit = false

  //slotbar config
  singleCountry = null //country name to show it alone in slotbar
  crewId = null //crewId to force select. reset after init
  shouldSelectCrewRecruit = false //should select crew recruit slot on create slotbar.
  isCountryChoiceAllowed = true //When false, not allow to change country, but show all countries.
                               //(look like it almost duplicate of singleCountry)
  customCountry = null //country name when not isCountryChoiceAllowed mode.
  showTopPanel = true  //need to show panel with repair checkboxes. ignored in singleCountry or when not isCountryChoiceAllowed modes
  hasResearchesBtn = false //offset from left border for Researches button
  hasActions = true
  missionRules = null
  showNewSlot = null //bool
  showEmptySlot = null //bool
  emptyText = "#shop/chooseAircraft" //text to show on empty slot
  alwaysShowBorder = false //should show focus border when no show_console_buttons
  checkRespawnBases = false //disable slot when no available respawn bases for unit
  hasExtraInfoBlock = null //bool
  unitForSpecType = null //unit to show crew specializations
  shouldSelectAvailableUnit = null //bool
  needPresetsPanel = null //bool

  //!!FIX ME: Better to remove parameters group below, and replace them by isUnitEnabled function
  mainMenuSlotbar = false //is slotbar in mainmenu
  roomCreationContext = false //check enbled by roomCreation context
  availableUnits = null //available units table
  customUnitsList = null //custom units table to filter unsuitable units in unit selecting
  customUnitsListName = null //string. Custom list name for unit select option filter
  eventId = null //string. Used to check unit availability
  gameModeName = null //string. Custom mission name for unit select option filter

  toBattle = false //has toBattle button
  haveRespawnCost = false //!!FIX ME: should to take this from mission rules
  haveSpawnDelay = false  //!!FIX ME: should to take this from mission rules
  totalSpawnScore = -1 //to disable slots by spawn score //!!FIX ME: should to take this from mission rules
  sessionWpBalance = 0 //!!FIX ME: should to take this from mission rules

  shouldCheckQueue = null //bool.  should check queue before select unit. !::is_in_flight by default.
  needActionsWithEmptyCrews = true //allow create crew and choose unit to crew while select empty crews.
  applySlotSelectionOverride = null //full override slot selection instead of select_crew
  beforeSlotbarSelect = null //function(onContinueCb, onCancelCb) to do before apply slotbar select.
                             //must call one of listed callbacks on finidh.
                             //when onContinueCb will be called, slotbar will aplly unit selection
                             //when onCancelCb will be called, slotbar will return selection to previous state
  afterSlotbarSelect = null //function() will be called after unit selection applied.
  onSlotDblClick = null //function(crew) when not set will open unit modifications window
  onSlotActivate = null //function(crew) when activate chosen crew
  onCountryChanged = null //function()
  onCountryDblClick = null
  beforeFullUpdate = null //function()
  afterFullUpdate = null //function()
  onSlotBattleBtn = null //function()
  getLockedCountryData = null //function()


  //******************************* self slotbar params ***********************************//
  isSceneLoaded = false
  loadedCountries = null //loaded countries versions
  lastUpdatedVersion = null // version IDX which has already updated

  curSlotCountryId = -1
  curSlotIdInCountry = -1
  slotbarActions = null
  isShaded = false

  ignoreCheckSlotbar = false
  skipCheckCountrySelect = false
  skipCheckAirSelect = false

  headerObj = null
  crewsObj = null
  selectedCrewData = null
  customViewCountryData = null
  slotbarBehavior = null
  needFullSlotBlock = false
  showAlwaysFullSlotbar = false
  needCheckUnitUnlock = false
  slotbarHintText = ""

  static function create(params)
  {
    let nest = params?.scene
    if (!checkObj(nest))
      return null

    if (params?.shouldAppendToObject ?? true) //we append to nav-bar by default
    {
      let data = "slotbarDiv { id:t='nav-slotbar' }"
      nest.getScene().appendWithBlk(nest, data)
      params.scene = nest.findObject("nav-slotbar")
    }

    return ::handlersManager.loadHandler(::gui_handlers.SlotbarWidget, params)
  }

  function destroy()
  {
    if (checkObj(this.scene))
      this.guiScene.replaceContentFromText(this.scene, "", 0, null)
    this.scene = null
  }

  function initScreen()
  {
    headerObj = this.scene.findObject("header_countries")
    crewsObj =  this.scene.findObject("countries_crews")

    loadedCountries = {}
    isSceneLoaded = true
    refreshAll()

    if (hasResearchesBtn)
    {
      let slotbarHeaderNestObj = this.scene.findObject("slotbar_buttons_place")
      if (checkObj(slotbarHeaderNestObj))
        slotbarHeaderNestObj["offset"] = "yes"
    }
  }

  function setParams(params)
  {
    base.setParams(params)
    if (ownerWeak)
      ownerWeak = ownerWeak.weakref()
    validateParams()
    if (isSceneLoaded)
    {
      loadedCountries.clear() //params can change visual style and visibility of crews
      refreshAll()
    }
  }

  function validateParams()
  {
    showNewSlot = showNewSlot ?? !singleCountry
    showEmptySlot = showEmptySlot ?? !singleCountry
    hasExtraInfoBlock = hasExtraInfoBlock ?? !singleCountry
    shouldSelectAvailableUnit = shouldSelectAvailableUnit ?? ::is_in_flight()
    needPresetsPanel = needPresetsPanel ?? (!singleCountry && isCountryChoiceAllowed)
    shouldCheckQueue = shouldCheckQueue ?? !::is_in_flight()
    onSlotDblClick = onSlotDblClick ?? getDefaultDblClickFunc()
    onSlotActivate = onSlotActivate ?? defaultOnSlotActivateFunc

    //update callbacks
    foreach(funcName in ["beforeSlotbarSelect", "afterSlotbarSelect", "onSlotDblClick", "onCountryChanged",
        "beforeFullUpdate", "afterFullUpdate", "onSlotBattleBtn", "applySlotSelectionOverride"])
      if (this[funcName])
        this[funcName] = callback.make(this[funcName], ownerWeak)
  }

  function refreshAll()
  {
    fillCountries()

    if (!singleCountry)
      setShowUnit(getCurSlotUnit(), getHangarFallbackUnitParams())

    if (crewId != null)
      crewId = null
    if (ownerWeak) //!!FIX ME: Better to presets list self catch canChangeCrewUnits
      ownerWeak.setSlotbarPresetsListAvailable(needPresetsPanel && ::SessionLobby.canChangeCrewUnits())
  }

  function getForcedCountry() //return null if you have countries choice
  {
    if (singleCountry)
      return singleCountry
    if (!::SessionLobby.canChangeCountry())
      return profileCountrySq.value
    if (!isCountryChoiceAllowed)
      return customCountry || profileCountrySq.value
    return null
  }

  function addCrewData(list, params)
  {
    let crew = params?.crew
    let data = {
      crew = crew,
      unit = null,
      isUnlocked = true,
      status = bit_unit_status.owned
      idInCountry = crew?.idInCountry ?? -1 //for recruit slots, but correct for all
      idCountry = crew?.idCountry ?? -1         //for recruit slots, but correct for all
    }.__update(params)

    data.crewIdVisible <- data?.crewIdVisible ?? list.len()

    let canSelectEmptyCrew = shouldSelectCrewRecruit
      || !needActionsWithEmptyCrews
      || (crew?.country != null && !isCountrySlotbarHasUnits(crew.country) && data.idInCountry == 0)
    data.isSelectable <- data?.isSelectable
      ?? ((data.isUnlocked || !shouldSelectAvailableUnit) && (canSelectEmptyCrew || data.unit != null))
    let isControlledUnit = !::is_respawn_screen()
      && ::is_player_unit_alive()
      && ::get_player_unit_name() == data.unit?.name
    if (haveRespawnCost
        && data.isSelectable
        && data.unit
        && totalSpawnScore >= 0
        && (totalSpawnScore < data.unit.getSpawnScore() || totalSpawnScore < data.unit.getMinimumSpawnScore())
        && !isControlledUnit)
      data.isSelectable = false

    list.append(data)
    return data
  }

  function gatherVisibleCrewsConfig(onlyForCountryIdx = null)
  {
    let res = []
    let country = getForcedCountry()
    let needNewSlot = !::g_crews_list.isCrewListOverrided && showNewSlot
    let needShowLockedSlots = missionRules == null || missionRules.needShowLockedSlots
    let needEmptySlot = !::g_crews_list.isCrewListOverrided && needShowLockedSlots && showEmptySlot

    let crewsListFull = ::g_crews_list.get()
    for(local c = 0; c < crewsListFull.len(); c++)
    {
      if (onlyForCountryIdx != null && onlyForCountryIdx != c)
        continue

      let visibleCountries = getShopVisibleCountries()
      let listCountry = crewsListFull[c].country
      if ((singleCountry != null && singleCountry != listCountry)
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

      let crewsList = crewsListFull[c].crews
      foreach(crewIdInCountry, crew in crewsList)
      {
        let unit = getCrewUnit(crew)

        if (!unit && !needEmptySlot)
          continue

        let unitName = unit?.name || ""
        let isUnitEnabledByRandomGroups = !missionRules || missionRules.isUnitEnabledByRandomGroups(unitName)
        let isUnlocked = (!needCheckUnitUnlock || !isRequireUnlockForUnit(unit))
          && ::isUnitUnlocked(unit, c, crewIdInCountry, country, missionRules, true)
        local status = bit_unit_status.empty
        let isUnitForcedVisible = missionRules && missionRules.isUnitForcedVisible(unitName)
        let isUnitForcedHiden = missionRules && missionRules.isUnitForcedHiden(unitName)
        if (unit)
        {
          status = getBitStatus(unit)
          if (!isUnlocked)
            status = bit_unit_status.locked
          else if (!::is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, false))
            status = bit_unit_status.broken
          else
          {
            local disabled = !::is_unit_enabled_for_slotbar(unit, this)
            if (checkRespawnBases)
              disabled = disabled || !getAvailableRespawnBases(unit.tags).len()
            if (disabled)
              status = bit_unit_status.disabled
          }
        }

        let isAllowedByLockedSlots = isUnitForcedVisible || needShowLockedSlots
          || status == bit_unit_status.owned || status == bit_unit_status.empty
        if (unit && (!isAllowedByLockedSlots || !isUnitEnabledByRandomGroups || isUnitForcedHiden))
          continue

        addCrewData(countryData.crews,
          { crew = crew, unit = unit, isUnlocked = isUnlocked, status = status })
      }

      if (!needNewSlot)
        continue

      let slotCostTbl = ::get_crew_slot_cost(listCountry)
      if (!slotCostTbl || (slotCostTbl.costGold > 0 && !hasFeature("SpendGold")))
        continue

      addCrewData(countryData.crews,
        { idInCountry = crewsList.len()
          idCountry = c
          cost = ::Cost(slotCostTbl.cost, slotCostTbl.costGold)
        })
    }
    return res
  }

  //calculate selected crew and country by slotbar params
  function calcSelectedCrewData(crewsConfig)
  {
    let forcedCountry = getForcedCountry()
    local unitShopCountry = forcedCountry || profileCountrySq.value
    local curUnit = getShowedUnit()
    local curCrewId = crewId

    if (!forcedCountry && !curCrewId)
    {
      if (!::isCountryAvailable(unitShopCountry) && ::unlocked_countries.len() > 0)
        unitShopCountry = ::unlocked_countries[0]
      if (curUnit && curUnit.shopCountry != unitShopCountry)
        curUnit = null
    }
    else if (forcedCountry && curSlotIdInCountry >= 0)
    {
      let curCrew = getCrew(curSlotCountryId, curSlotIdInCountry)
      if (curCrew)
        curCrewId = curCrew.id
    }

    if (curCrewId || shouldSelectCrewRecruit)
      curUnit = null

    local isFoundCurUnit = false
    local selCrewData = null
    foreach(countryData in crewsConfig)
    {
      if (!countryData.isEnabled)
        continue

      //when current crew not available in this mission, first available crew will be selected.
      local firstAvailableCrewData = null
      let selCrewidInCountry = ::selected_crews?[countryData.id]
      foreach(crewData in countryData.crews)
      {
        let crew = crewData.crew
        let unit = crewData.unit
        let isSelectable = crewData.isSelectable
        if ((crew?.id != null && curCrewId == crew.id)
          || (unit && unit == curUnit)
          || (!crew && shouldSelectCrewRecruit))
        {
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
        selCrewData = countryData.crews[0] //select not selectable when nothing found
    }

    return selCrewData
  }

  //get crew data selected in country (selected_crews[curSlotCountryId])
  function getSelectedCrewDataInCountry(countryData)
  {
    local selCrewData = null
    let selCrewIdInCountry = ::selected_crews?[countryData.id]
    foreach(crewData in countryData.crews)
    {
      if (crewData.idInCountry == selCrewIdInCountry)
      {
        selCrewData = crewData
        break
      }

      if (!selCrewData || (crewData.isSelectable && !selCrewData.isSelectable))
        selCrewData = crewData
    }
    return selCrewData
  }

  function fillCountries()
  {
    if (!::g_login.isLoggedIn())
      return
    if (slotbarOninit)
    {
      ::script_net_assert_once("slotbar recursion", "init_slotbar: recursive call found")
      return
    }

    if (!::g_crews_list.get().len())
    {
      if (::g_login.isLoggedIn() && (::isProductionCircuit() || ::get_cur_circuit_name() == "nightly"))
        ::scene_msg_box("no_connection", null, loc("char/no_connection"), [["ok", startLogout ]], "ok")
      return
    }

    slotbarOninit = true
    ::init_selected_crews()
    ::update_crew_skills_available()
    let crewsConfig = gatherVisibleCrewsConfig()
    selectedCrewData = calcSelectedCrewData(crewsConfig)

    let isFullSlotbar = crewsConfig.len() > 1 || showAlwaysFullSlotbar
    let hasCountryTopBar = isFullSlotbar && showTopPanel && !singleCountry
    if (hasCountryTopBar)
      ::initSlotbarTopBar(this.scene, true) //show autorefill checkboxes

    crewsObj.hasHeader = !hasCountryTopBar ? "yes" : "no"
    crewsObj.hasBackground = isFullSlotbar ? "no" : "yes"
    let hObj = this.scene.findObject("slotbar_background")
    hObj.show(isFullSlotbar)
    hObj.hasPresetsPanel = needPresetsPanel ? "yes" : "no"
    if (::show_console_buttons)
      updateConsoleButtonsVisible(hasCountryTopBar)

    let countriesView = {
      hasNotificationIcon = hasResearchesBtn
      countries = []
    }
    local selCountryIdx = 0
    let ediff = getShopDiffCode()
    foreach(idx, countryData in crewsConfig)
    {
      let country = countryData.country
      if (countryData.id == selectedCrewData?.idCountry)
        selCountryIdx = idx

      local bonusData = null
      if (!::is_first_win_reward_earned(country, ::INVALID_USER_ID))
        bonusData = getCountryBonusData(country)

      let cEnabled = countryData.isEnabled
      let cUnlocked = ::isCountryAvailable(country)
      let tooltipText = !cUnlocked ? loc("mainmenu/countryLocked/tooltip")
        : loc(country)
      countriesView.countries.append({
        countryIdx = countryData.id
        country = customViewCountryData?[country].locId ?? country
        tooltipText = tooltipText
        countryIcon = ::get_country_icon(
          customViewCountryData?[country].icon ?? country, false, !cUnlocked || !cEnabled)
        bonusData = bonusData
        isEnabled = cEnabled && cUnlocked
        seenIconCfg = bhvUnseen.makeConfigStr(seenList.id,
          getUnlockIdsByCountry(country, ediff))
      })
    }

    let countriesNestObj = this.scene.findObject("header_countries")
    let prevCountriesNestValue = countriesNestObj.getValue()
    let countriesObjsCount = countriesNestObj.childrenCount()
    local needUpdateCountriesMarkup = countriesObjsCount != countriesView.countries.len()
    if (!needUpdateCountriesMarkup)
      for (local i = 0;i < countriesObjsCount; i++) {
         needUpdateCountriesMarkup = countriesView.countries.findindex(
           function(v) {
             let countryObj = countriesNestObj.getChild(i)
             return v.country == countryObj?.countryId && v.isEnabled == countryObj.isEnabled()
           }) == null
         if (needUpdateCountriesMarkup)
           break
      }
    if (needUpdateCountriesMarkup)
    {
      let countriesData = ::handyman.renderCached("%gui/slotbar/slotbarCountryItem", countriesView)
      this.guiScene.replaceContentFromText(countriesNestObj, countriesData, countriesData.len(), this)
    }

    countriesNestObj.setValue(selCountryIdx)
    if (prevCountriesNestValue == selCountryIdx)
      onHeaderCountry(countriesNestObj)

    if (selectedCrewData)
    {
      let selItem = ::get_slot_obj(crewsObj, selectedCrewData.idCountry, selectedCrewData.idInCountry)
      if (selItem)
        this.guiScene.performDelayed(this, function() {
          if (checkObj(selItem) && selItem.isVisible())
            selItem.scrollToView()
        })
    }

    slotbarOninit = false
    this.guiScene.applyPendingChanges(false)

    let countriesNestMaxWidth = ::g_dagui_utils.toPixels(this.guiScene, "1@slotbarCountriesMaxWidth")
    let countriesNestWithBtnsObj = this.scene.findObject("header_countries_nest")
    if (countriesNestWithBtnsObj.getSize()[0] > countriesNestMaxWidth)
      countriesNestObj.isShort = "yes"

    let needEvent = selectedCrewData
      && ((curSlotCountryId >= 0 && curSlotCountryId != selectedCrewData.idCountry)
        || (curSlotIdInCountry >= 0 && curSlotIdInCountry != selectedCrewData.idInCountry))
    if (needEvent)
    {
      let cObj = this.scene.findObject("airs_table_" + selectedCrewData.idCountry)
      if (checkObj(cObj))
      {
        skipCheckAirSelect = true
        onSlotbarSelect(cObj)
      }
    }
    else
    {
      curSlotCountryId   = selectedCrewData?.idCountry ?? -1
      curSlotIdInCountry = selectedCrewData?.idInCountry ?? -1
      ::select_crew(curSlotCountryId, curSlotIdInCountry)
    }
  }

  getCountryBonusData = @(country) ::getBonus(
    ::shop_get_first_win_xp_rate(country),
    ::shop_get_first_win_wp_rate(country), "item")

  function fillCountryContent(countryData, tblObj)
  {
    updateSlotbarHint()
    if (loadedCountries?[countryData.id] == ::g_crews_list.version
      || !checkObj(tblObj))
      return

    loadedCountries[countryData.id] <- ::g_crews_list.version
    lastUpdatedVersion = ::g_crews_list.version

    let selCrewData = selectedCrewData?.idCountry == countryData.id
      ? selectedCrewData
      : getSelectedCrewDataInCountry(countryData)

    updateSlotRowView(countryData, tblObj)
    if (selCrewData)
      tblObj.setValue(selCrewData.crewIdVisible)

    foreach(crewData in countryData.crews)
      if (crewData.unit)
      {
        let id = ::get_slot_obj_id(countryData.id, crewData.idInCountry)
        ::fill_unit_item_timers(tblObj.findObject(id), crewData.unit)
        let bonusId = ::get_slot_obj_id(countryData.id, crewData.idInCountry, true)
        ::showAirExpWpBonus(tblObj.findObject(bonusId), crewData.unit.name)
      }
  }

  function checkUpdateCountryInScene(countryIdx)
  {
    if (loadedCountries?[countryIdx] == ::g_crews_list.version)
      return

    let countryData = gatherVisibleCrewsConfig(countryIdx)?[0]
    if (!countryData)
      return

    fillCountryContent(countryData, this.scene.findObject("airs_table_" + countryData.id))
  }

  function getCurSlotUnit()
  {
    return ::g_crew.getCrewUnit(getCrew(curSlotCountryId, curSlotIdInCountry))
  }

  function getCurCrew() //will return null when selected recruitCrew
  {
    return getCrew(curSlotCountryId, curSlotIdInCountry)
  }

  function getCurCountry()
  {
    return ::g_crews_list.get()?[curSlotCountryId]?.country ?? ""
  }

  function getCurrentEdiff()
  {
    if (::u.isFunction(ownerWeak?.getCurrentEdiff))
      return ownerWeak.getCurrentEdiff()
    return ::get_current_ediff()
  }

  function getSlotbarActions()
  {
    return slotbarActions ?? ownerWeak?.getSlotbarActions?()
  }

  function getCurrentAirsTable()
  {
    return this.scene.findObject("airs_table_" + curSlotCountryId)
  }

  function getCurrentCrewSlot()
  {
    return ::get_slot_obj(this.scene, curSlotCountryId, curSlotIdInCountry)
  }

  function getHangarFallbackUnitParams()
  {
    return {
      country = getCurCountry()
      slotbarUnits = (::g_crews_list.get()?[curSlotCountryId].crews ?? [])
        .map(@(crew) ::g_crew.getCrewUnit(crew))
        .filter(@(unit) unit != null)
    }
  }

  function getSlotIdByObjId(slotObjId, countryId)
  {
    let prefix = "td_slot_"+countryId+"_"
    if (!::g_string.startsWith(slotObjId, prefix))
      return -1
    return ::to_integer_safe(slotObjId.slice(prefix.len()), -1)
  }

  function getSelSlotDataByObj(obj)
  {
    let res = {
      isValid = false
      countryId = -1
      crewIdInCountry = -1
    }

    let countryIdStr = ::getObjIdByPrefix(obj, "airs_table_")
    if (!countryIdStr)
      return res
    res.countryId = countryIdStr.tointeger()

    let curValue = ::get_obj_valid_index(obj)
    if (curValue < 0)
      return res

    let curSlotId = obj.getChild(curValue).id
    res.crewIdInCountry = getSlotIdByObjId(curSlotId, res.countryId)
    res.isValid = res.crewIdInCountry >= 0
    return res
  }

  function onSlotbarSelect(obj)
  {
    if (!checkObj(obj))
      return

    if (slotbarOninit || skipCheckAirSelect || !shouldCheckQueue)
    {
      onSlotbarSelectImpl(obj)
      skipCheckAirSelect = false
    }
    else
      this.checkedAirChange(
        (@(obj) function() {
          if (checkObj(obj))
            onSlotbarSelectImpl(obj)
        })(obj),
        (@(obj) function() {
          if (checkObj(obj))
          {
            skipCheckAirSelect = true
            selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
          }
        })(obj)
      )
  }

  function onSlotbarSelectImpl(obj)
  {
    if (!checkObj(obj))
      return

    let selSlot = getSelSlotDataByObj(obj)
    if (!selSlot.isValid)
      return
    if (curSlotCountryId == selSlot.countryId
        && curSlotIdInCountry == selSlot.crewIdInCountry)
      return

    if (beforeSlotbarSelect)
    {
      ignoreCheckSlotbar = true
      beforeSlotbarSelect(
        Callback(function()
        {
          ignoreCheckSlotbar = false
          if (checkObj(obj))
            applySlotSelection(obj, selSlot)
        }, this),
        Callback(function()
        {
          ignoreCheckSlotbar = false
          if (curSlotCountryId != selSlot.countryId)
            setCountry(::g_crews_list.get()?[curSlotCountryId]?.country)
          else if (checkObj(obj))
            selectTblAircraft(obj, curSlotIdInCountry)
        }, this),
        selSlot
      )
    }
    else
      applySlotSelection(obj, selSlot)
  }

  function applySlotSelectionDefault(_prevSlot, restorePrevSelection) {
    let crew = getCrew(curSlotCountryId, curSlotIdInCountry)
    if (crew)
    {
      let unit = getCrewUnit(crew)
      if (unit != null || (!isCountrySlotbarHasUnits(crew.country) && curSlotIdInCountry == 0))
        setCrewUnit(unit)
      if (!unit && needActionsWithEmptyCrews)
        onSlotChangeAircraft()
      return
    }

    if (!needActionsWithEmptyCrews || (curSlotCountryId not in ::g_crews_list.get()))
      return

    let country = ::g_crews_list.get()[curSlotCountryId].country

    let rawCost = ::get_crew_slot_cost(country)
    let cost = rawCost? ::Cost(rawCost.cost, rawCost.costGold) : ::Cost()
    if (!::check_balance_msgBox(cost)) {
      restorePrevSelection()
      return
    }

    if (cost <= ::zero_money) {
      purchaseNewSlot(country)
      return
    }

    let msgText = ::warningIfGold(
      format(loc("shop/needMoneyQuestion_purchaseCrew"),
        cost.getTextAccordingToBalance()),
      cost)
    ignoreCheckSlotbar = true
    this.msgBox("need_money", msgText,
      [["ok",
        function() {
          ignoreCheckSlotbar = false
          purchaseNewSlot(country)
        }
       ],
       ["cancel", restorePrevSelection ]
      ], "ok")
  }

  function applySlotSelection(obj, selSlot)
  {
    let prevSlot = { countryId = curSlotCountryId, crewIdInCountry = curSlotIdInCountry }
    curSlotCountryId = selSlot.countryId
    curSlotIdInCountry = selSlot.crewIdInCountry

    if (!slotbarOninit)
      (applySlotSelectionOverride ?? applySlotSelectionDefault)(prevSlot,
        Callback(function() {
          if (curSlotCountryId != selSlot.countryId)
            return
          ignoreCheckSlotbar = false
          selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
        }, this))
    afterSlotbarSelect?()
  }

  /**
   * Selects crew in slotbar with specified id
   * as if player clicked slot himself.
   */
  function selectCrew(crewIdInCountry)
  {
    let objId = "airs_table_" + curSlotCountryId
    let obj = this.scene.findObject(objId)
    if (checkObj(obj))
      selectTblAircraft(obj, crewIdInCountry)
  }

  function selectTblAircraft(tblObj, slotIdInCountry=0)
  {
    if (!checkObj(tblObj) || slotIdInCountry < 0)
      return
    let slotIdx = getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
    if (slotIdx < 0)
      return
    tblObj.setValue(slotIdx)
  }

  function getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
  {
    if (!tblObj.childrenCount())
      return -1
    if (tblObj?.id != "airs_table_" + curSlotCountryId)
    {
      let tblObjId = tblObj?.id         // warning disable: -declared-never-used
      let countryId = curSlotCountryId  // warning disable: -declared-never-used
      ::script_net_assert_once("bad slot country id", "Error: Try to select crew from wrong country")
      return -1
    }
    let prefix = "td_slot_" + curSlotCountryId +"_"
    for(local i = 0; i < tblObj.childrenCount(); i++)
    {
      let id = ::getObjIdByPrefix(tblObj.getChild(i), prefix)
      if (!id)
      {
        let objId = tblObj.getChild(i).id // warning disable: -declared-never-used
        ::script_net_assert_once("bad slot id", "Error: Bad slotbar slot id")
        continue
      }

      if (::to_integer_safe(id) == slotIdInCountry)
        return i
    }

    return -1
  }

  function onSlotbarDblClick()
  {
    if (!this.isValid())
      return
    let cellObj = this.scene.findObject($"td_slot_{curSlotCountryId}_{curSlotIdInCountry}")
    if (!cellObj?.isValid() || !cellObj.isHovered())
      return
    onSlotDblClick(getCurCrew())
  }

  function checkSelectCountryByIdx(obj)
  {
    let idx = obj.getValue()
    let countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(idx), "header_country"), curSlotCountryId)
    if (curSlotCountryId >= 0 && curSlotCountryId != countryIdx && countryIdx in ::g_crews_list.get()
        && !::isCountryAvailable(::g_crews_list.get()[countryIdx].country) && ::unlocked_countries.len())
    {
      this.msgBox("notAvailableCountry", loc("mainmenu/countryLocked/tooltip"),
             [["ok", (@(obj) function() {
               if (checkObj(obj))
                 obj.setValue(curSlotCountryId)
             })(obj) ]], "ok")
      return false
    }
    return true
  }

  function checkCreateCrewsNest(countryData)
  {
    let countriesCount = crewsObj.childrenCount()
    let animBlockId = "crews_anim_" + countryData.idx
    for (local i = 0; i < countriesCount; i++)
    {
      let animObj = crewsObj.getChild(i)
      animObj.animation = animObj?.id == animBlockId ? "show" : "hide"

      if (animObj?.id != animBlockId && animObj?["_transp-timer"] == null)
        animObj["_transp-timer"] = "0"
    }

    let animBlockObj = crewsObj.findObject(animBlockId)
    if (checkObj(animBlockObj))
      return

    let country = countryData.country
    let blk = ::handyman.renderCached("%gui/slotbar/slotbarItem", {
      countryIdx = countryData.idx
      needSkipAnim = countriesCount == 0
      alwaysShowBorder = alwaysShowBorder
      countryImage = ::get_country_icon(customViewCountryData?[country].icon ?? country, false)
      slotbarBehavior = slotbarBehavior
    })
    this.guiScene.appendWithBlk(crewsObj, blk, this)
  }

  function onHeaderCountry(obj)
  {
    let countryData = getCountryDataByObject(obj)
    if (slotbarOninit || skipCheckCountrySelect)
    {
      onSlotbarCountryImpl(countryData)
      skipCheckCountrySelect = false
      return
    }

    let lockedCountryData = getLockedCountryData?()
    if (lockedCountryData != null
      && !isInArray(countryData.country, lockedCountryData.availableCountries))
    {
      setCountry(profileCountrySq.value)
      ::showInfoMsgBox(lockedCountryData.reasonText)
    }
    else
    {
      switchSlotbarCountry(headerObj, countryData)
    }
  }

  function onCountriesListDblClick()
  {
    if (onCountryDblClick)
      onCountryDblClick()
  }

  function switchSlotbarCountry(obj, countryData)
  {
    if (!shouldCheckQueue)
    {
      if (checkSelectCountryByIdx(obj))
      {
        onSlotbarCountryImpl(countryData)
        ::slotbarPresets.setCurrentGameModeByPreset(countryData.country)
      }
    }
    else
    {
      if (!checkSelectCountryByIdx(obj))
        return

      this.checkedCrewAirChange(
        function() {
          if (checkObj(obj))
          {
            onSlotbarCountryImpl(countryData)
            ::slotbarPresets.setCurrentGameModeByPreset(countryData.country)
          }
        },
        function() {
          if (checkObj(obj))
            setCountry(profileCountrySq.value)
        }
      )
    }
  }

  function setCountry(country)
  {
    foreach(idx, c in ::g_crews_list.get())
      if (c.country == country)
      {
        let hObj = this.scene.findObject("header_countries")
        if (!checkObj(hObj) || hObj.getValue() == idx)
          break

        skipCheckCountrySelect = true
        skipCheckAirSelect = true
        hObj.setValue(idx)
        break
      }
  }

  function getCountryDataByObject(obj)
  {
    if (!checkObj(obj))
      return null

    let curValue = obj.getValue()
    if (obj.childrenCount() <= curValue)
      return null

    let countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(curValue), "header_country"), curSlotCountryId)
    let country = ::g_crews_list.get()[countryIdx].country

    return {
      idx = countryIdx
      country = country
    }
  }

  function onSlotbarCountryImpl(countryData)
  {
    if (!countryData)
      return

    checkCreateCrewsNest(countryData)
    checkUpdateCountryInScene(countryData.idx)

    if (!singleCountry)
    {
      if (!checkSelectCountryByIdx(headerObj))
        return

      switchProfileCountry(countryData.country)
      onSlotbarSelect(crewsObj.findObject("airs_table_" + countryData.idx))
    }
    else
      onSlotbarSelect(crewsObj.findObject("airs_table_" + countryData.idx))

    onSlotbarCountryChanged()
  }

  function onSlotbarCountryChanged()
  {
    if (ownerWeak?.presetsListWeak)
      ownerWeak.presetsListWeak.update()
    if (onCountryChanged)
      onCountryChanged()
  }

  function prevCountry(_obj) { switchCountry(-1) }

  function nextCountry(_obj) { switchCountry(1) }

  function switchCountry(way)
  {
    if (singleCountry)
      return

    let hObj = this.scene.findObject("header_countries")
    if (hObj.childrenCount() <= 1)
      return

    let curValue = hObj.getValue()
    let value = getNearestSelectableChildIndex(hObj, curValue, way)
    if(value != curValue)
      hObj.setValue(value)
  }

  function onSlotChangeAircraft()
  {
    let crew = getCurCrew()
    if (!crew)
      return

    let slotbar = this
    ignoreCheckSlotbar = true
    this.checkedCrewAirChange(function() {
        ignoreCheckSlotbar = false
        selectUnitHandler.open(crew, slotbar)
      },
      function() {
        ignoreCheckSlotbar = false
        checkSlotbar()
      }
    )
  }

  function shade(shouldShade)
  {
    if (isShaded == shouldShade)
      return

    isShaded = shouldShade
    let shadeObj = this.scene.findObject("slotbar_shade")
    if(checkObj(shadeObj))
      shadeObj.animation = isShaded ? "show" : "hide"
    if (::show_console_buttons)
      updateConsoleButtonsVisible(!isShaded)
  }

  function updateConsoleButtonsVisible(isVisible)
  {
    this.showSceneBtn("prev_country_btn", isVisible)
    this.showSceneBtn("next_country_btn", isVisible)
  }

  function forceUpdate()
  {
    updateSlotbarImpl()
  }

  function fullUpdate()
  {
    this.doWhenActiveOnce("updateSlotbarImpl")
  }

  function updateSlotbarImpl()
  {
    if (ignoreCheckSlotbar)
      return

    loadedCountries.clear()
    if (beforeFullUpdate)
      beforeFullUpdate()

    curSlotCountryId = -1
    curSlotIdInCountry = -1

    refreshAll()
    if (afterFullUpdate)
      afterFullUpdate()
  }

  function checkSlotbar()
  {
    if (ignoreCheckSlotbar || !::isInMenu())
      return

    let curCountry = profileCountrySq.value

    if (!(curSlotCountryId in ::g_crews_list.get())
        || ::g_crews_list.get()[curSlotCountryId].country != curCountry
        || curSlotIdInCountry != ::selected_crews?[curSlotCountryId]
        || (getCurSlotUnit() == null && isCountrySlotbarHasUnits(curCountry)))
      updateSlotbarImpl()
    else if (selectedCrewData && selectedCrewData?.unit != getShowedUnit())
      refreshAll()
  }

  function onSceneActivate(show)
  {
    base.onSceneActivate(show)
    if (this.checkActiveForDelayedAction())
      checkSlotbar()
  }

  function onEventModalWndDestroy(p)
  {
    base.onEventModalWndDestroy(p)
    if (this.checkActiveForDelayedAction())
      checkSlotbar()
  }

  function purchaseNewSlot(country)
  {
    ignoreCheckSlotbar = true

    let onTaskSuccess = Callback(function()
    {
      ignoreCheckSlotbar = false
      onSlotChangeAircraft()
    }, this)

    let onTaskFail = Callback(function(_result) { ignoreCheckSlotbar = false }, this)

    if (!::g_crew.purchaseNewSlot(country, onTaskSuccess, onTaskFail))
      ignoreCheckSlotbar = false
  }

  //return GuiBox of visible slotbar units
  function getBoxOfUnits()
  {
    let obj = this.scene.findObject("airs_table_" + curSlotCountryId)
    if (!checkObj(obj))
      return null

    let box = ::GuiBox().setFromDaguiObj(obj)
    let pBox = ::GuiBox().setFromDaguiObj(obj.getParent())
    if (box.c2[0] > pBox.c2[0])
      box.c2[0] = pBox.c2[0] + pBox.c1[0] - box.c1[0]
    return box
  }

  //return GuiBox of visible slotbar countries
  function getBoxOfCountries()
  {
    let headerCountriesObj = this.scene.findObject("header_countries")
    if (!checkObj(headerCountriesObj))
      return null

    return ::GuiBox().setFromDaguiObj(headerCountriesObj)
  }

  function getSlotsData(unitId = null, slotCrewId = -1, withEmptySlots = false)
  {
    let unitSlots = []
    foreach(countryId, countryData in ::g_crews_list.get())
      if (!singleCountry || countryData.country == singleCountry)
        foreach (idInCountry, crew in countryData.crews)
        {
          if (slotCrewId != -1 && slotCrewId != (crew?.id ?? -1))
            continue
          let unit = getCrewUnit(crew)
          if (unitId && unit && unitId != unit.name)
            continue
          let obj = ::get_slot_obj(this.scene, countryId, idInCountry)
          if (obj && (unit || withEmptySlots))
            unitSlots.append({
              unit      = unit
              crew      = crew
              countryId = countryId
              obj       = obj
            })
        }

    return unitSlots
  }

  function getCrewUnit(crew)
  {
    return ::g_crew.getCrewUnit(crew)
  }

  function updateDifficulty(unitSlots = null)
  {
    unitSlots = unitSlots || getSlotsData()

    let showBR = hasFeature("SlotbarShowBattleRating")
    let curEdiff = getCurrentEdiff()

    foreach (slot in unitSlots)
    {
      let obj = slot.obj.findObject("rank_text")
      if (checkObj(obj))
      {
        local unitRankText = ::get_unit_rank_text(slot.unit, slot.crew, showBR, curEdiff)
        obj.setValue(unitRankText)
      }
    }
  }

  function updateCrews(unitSlots = null)
  {
    if (::g_crews_list.isCrewListOverrided)
      return

    unitSlots = unitSlots || getSlotsData()

    foreach (slot in unitSlots)
    {
      slot.obj["crewStatus"] = ::get_crew_status(slot.crew, slot.unit)

      local obj = slot.obj.findObject("crew_level")
      if (checkObj(obj))
      {
        let crewLevelText = slot.unit
          ? ::g_crew.getCrewLevel(slot.crew, slot.unit, slot.unit.getCrewUnitType()).tointeger().tostring()
          : ""
        obj.setValue(crewLevelText)
      }

      obj = slot.obj.findObject("crew_spec")
      if (checkObj(obj))
      {
        let crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(slot.crew, slot.unit).trainedIcon
        obj["background-image"] = crewSpecIcon
      }
    }
  }

  function onSlotBattle(_obj)
  {
    if (onSlotBattleBtn)
      onSlotBattleBtn()
  }

  function onEventCrewsListChanged(_p)
  {
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid() || lastUpdatedVersion == ::g_crews_list.version)
        return

      fullUpdate()
    })
  }

  function onEventCrewSkillsChanged(params)
  {
    let crew = getTblValue("crew", params)
    if (crew)
      updateCrews(getSlotsData(null, crew.id))
  }

  function onEventQualificationIncreased(params)
  {
    let unit = getTblValue("unit", params)
    if (unit)
      updateCrews(getSlotsData(unit.name))
  }

  function onEventAutorefillChanged(params)
  {
    if (!("id" in params) || !("value" in params))
      return

    let obj = this.scene.findObject(params.id)
    if (obj && obj.getValue() != params.value)
      obj.setValue(params.value)
  }

  function updateSlotRowView(countryData, tblObj)
  {
    if (!countryData)
      return

    let slotsData = []
    foreach(crewData in countryData.crews)
    {
      let id = ::get_slot_obj_id(countryData.id, crewData.idInCountry)
      let crew = crewData.crew
      if (!crew)
      {
        let unitItem = ::build_aircraft_item(
          id,
          null,
          {
            emptyText = "#shop/recruitCrew",
            crewImage = $"#ui/gameuiskin#slotbar_crew_recruit_{countryData.country.slice(8)}.png"
            isCrewRecruit = true
            emptyCost = crewData.cost
            isSlotbarItem = true
            fullBlock     = needFullSlotBlock
          })

        slotsData.append(needFullSlotBlock ? unitItem : SLOT_NEST_TAG.subst(unitItem))
        continue
      }

      let isVisualDisabled = crewData?.isVisualDisabled ?? false
      let isLocalState = !::g_crews_list.isCrewListOverrided && (crewData?.isLocalState ?? true)
      let airParams = {
        emptyText      = isVisualDisabled ? "" : emptyText,
        crewImage      = $"#ui/gameuiskin#slotbar_crew_free_{countryData.country.slice(8)}.png"
        status         = getUnitItemStatusText(crewData.status),
        hasActions     = hasActions && !::g_crews_list.isCrewListOverrided
        toBattle       = toBattle
        mainActionFunc = ::SessionLobby.canChangeCrewUnits() ? "onSlotChangeAircraft" : ""
        mainActionText = "" // "#multiplayer/changeAircraft"
        mainActionIcon = "#ui/gameuiskin#slot_change_aircraft.svg"
        crewId         = crew?.id
        isSlotbarItem  = true
        showBR         = hasFeature("SlotbarShowBattleRating")
        getEdiffFunc   = getCurrentEdiff.bindenv(this)
        hasExtraInfoBlock = hasExtraInfoBlock
        haveRespawnCost = haveRespawnCost
        haveSpawnDelay = haveSpawnDelay
        totalSpawnScore = totalSpawnScore
        sessionWpBalance = sessionWpBalance
        curSlotIdInCountry = crew.idInCountry
        curSlotCountryId = crew.idCountry
        unlocked = crewData.isUnlocked
        tooltipParams = { needCrewInfo = hasFeature("CrewInfo") && !::g_crews_list.isCrewListOverrided
          showLocalState = isLocalState
          needCrewModificators = true
          needShopInfo = needCheckUnitUnlock
          crewId = crew?.id}
        missionRules = missionRules
        forceCrewInfoUnit = unitForSpecType
        isLocalState = isLocalState
        fullBlock        = needFullSlotBlock
        bottomLineText = needCheckUnitUnlock && isRequireUnlockForUnit(crewData.unit)
          ? getUnitRequireUnlockShortText(crewData.unit)
          : null
      }
      airParams.__update(getCrewDataParams(crewData))
      let unitItem = ::build_aircraft_item(id, crewData.unit, airParams)
      slotsData.append(needFullSlotBlock ? unitItem : SLOT_NEST_TAG.subst(unitItem))
    }

    let slotsDataString = "".join(slotsData)
    this.guiScene.replaceContentFromText(tblObj, slotsDataString, slotsDataString.len(), this)
  }

  getCrewDataParams = @(_crewData) {}
  getSlotbar = @() this

  function setCrewUnit(unit)
  {
    setShowUnit(unit, getHangarFallbackUnitParams())
    //need to send event when crew in country not changed, because main unit changed.
    ::select_crew(curSlotCountryId, curSlotIdInCountry, true)
  }

  function getDefaultDblClickFunc()
  {
    return Callback(function(crew) {
      if (::g_crews_list.isCrewListOverrided)
        return
      let unit = getCrewUnit(crew)
      if (unit)
        ::open_weapons_for_unit(unit, { curEdiff = getCurrentEdiff() })
    }, this)
  }

  function onSlotbarActivate(_obj) {
    if (!this.isValid())
      return
    let cellObj = this.scene.findObject($"td_slot_{curSlotCountryId}_{curSlotIdInCountry}")
    if (!cellObj?.isValid() || !cellObj.isHovered())
      return
    onSlotActivate(getCurCrew())
  }

  function defaultOnSlotActivateFunc(_crew)
  {
    if (hasActions && !::g_crews_list.isCrewListOverrided)
    {
      if (isCountrySlotbarHasUnits(profileCountrySq.value))
        this.openUnitActionsList(getCurrentCrewSlot())
      else
        onSlotChangeAircraft()
    }
  }

  function updateWeaponryData(unitSlots = null) {
    if (::g_crews_list.isCrewListOverrided)
      return

    unitSlots = unitSlots ?? getSlotsData()
    foreach (slot in unitSlots)
    {
      let obj = slot.obj.findObject("weapons_icon")
      let unit = slot.unit
      if (!checkObj(obj) || unit == null)
        continue

      let weaponsStatus = getWeaponsStatusName((slot.crew?.isLocalState ?? true) && ::isUnitUsable(unit)
        ? checkUnitWeapons(unit)
        : UNIT_WEAPONS_READY
      )
      obj.weaponsStatus = weaponsStatus
    }
  }

  function onEventUnitBulletsChanged(p) {
    updateWeaponryData(getSlotsData(p.unit.name))
  }

  function onEventUnitWeaponChanged(p) {
    updateWeaponryData(getSlotsData(p.unitName))
  }

  function updateSlotbarHint() {
    let obj = this.showSceneBtn("slotbarHint", slotbarHintText != "")
    if (obj != null && slotbarHintText != "")
     obj.findObject("slotbarHintText").setValue(slotbarHintText)
  }

  function onEventLobbyIsInRoomChanged(p) {
    if (p.wasSessionInLobby != ::SessionLobby.hasSessionInLobby())
      fullUpdate()
  }

  function onEventVisibleCountriesCacheInvalidate(_p) {
    if (loadedCountries.len() != getShopVisibleCountries().len())
      fullUpdate()
  }
}