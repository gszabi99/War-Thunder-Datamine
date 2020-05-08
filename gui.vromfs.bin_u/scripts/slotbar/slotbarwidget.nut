local callback = ::require("sqStdLibs/helpers/callback.nut")
local Callback = callback.Callback
local battleRating = ::require("scripts/battleRating.nut")
local selectUnitHandler = require("scripts/slotbar/selectUnitHandler.nut")

::slotbar_oninit <- false //!!FIX ME: Why this variable is global?

class ::gui_handlers.SlotbarWidget extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/slotbar/slotbar.blk"
  ownerWeak = null

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
  beforeSlotbarSelect = null //function(onContinueCb, onCancelCb) to do before apply slotbar select.
                             //must call one of listed callbacks on finidh.
                             //when onContinueCb will be called, slotbar will aplly unit selection
                             //when onCancelCb will be called, slotbar will return selection to previous state
  afterSlotbarSelect = null //function() will be called after unit selection applied.
  onSlotDblClick = null //function(crew) when not set will open unit modifications window
  onCountryChanged = null //function()
  onCountryDblClick = null
  beforeFullUpdate = null //function()
  afterFullUpdate = null //function()
  onSlotBattleBtn = null //function()


  //******************************* self slotbar params ***********************************//
  isPrimaryFocus = false
  isSceneLoaded = false
  loadedCountries = null //loaded countries versions
  lastUpdatedVersion = null // version IDX which has already updated
  focusArray = ["autorefill-settings", "header_countries", @() getFocusObj()]
  currentFocusItem = 2

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

  static function create(params)
  {
    local nest = params?.scene
    if (!::check_obj(nest))
      return null

    if (params?.shouldAppendToObject ?? true) //we append to nav-bar by default
    {
      local data = "slotbarDiv { id:t='nav-slotbar' }"
      nest.getScene().appendWithBlk(nest, data)
      params.scene = nest.findObject("nav-slotbar")
    }

    return ::handlersManager.loadHandler(::gui_handlers.SlotbarWidget, params)
  }

  function destroy()
  {
    if (::check_obj(scene))
      guiScene.replaceContentFromText(scene, "", 0, null)
    scene = null
  }

  function initScreen()
  {
    headerObj = scene.findObject("header_countries")
    crewsObj =  scene.findObject("countries_crews")

    loadedCountries = {}
    isSceneLoaded = true
    refreshAll()

    if (hasResearchesBtn)
    {
      local slotbarHeaderNestObj = scene.findObject("slotbar_buttons_place")
      if (::check_obj(slotbarHeaderNestObj))
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

    //update callbacks
    foreach(funcName in ["beforeSlotbarSelect", "afterSlotbarSelect", "onSlotDblClick", "onCountryChanged",
        "beforeFullUpdate", "afterFullUpdate", "onSlotBattleBtn"])
      if (this[funcName])
        this[funcName] = callback.make(this[funcName], ownerWeak)
  }

  function refreshAll()
  {
    fillCountries()

    if (!singleCountry)
      ::set_show_aircraft(getCurSlotUnit())

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
      return ::get_profile_country_sq()
    if (!isCountryChoiceAllowed)
      return customCountry || ::get_profile_country_sq()
    return null
  }

  function addCrewData(list, params)
  {
    local crew = params?.crew
    local data = {
      crew = crew,
      unit = null,
      isUnlocked = true,
      status = bit_unit_status.owned
      idInCountry = crew?.idInCountry ?? -1 //for recruit slots, but correct for all
      idCountry = crew?.idCountry ?? -1         //for recruit slots, but correct for all
    }.__update(params)

    data.crewIdVisible <- data?.crewIdVisible ?? list.len()

    local canSelectEmptyCrew = shouldSelectCrewRecruit || !needActionsWithEmptyCrews
    data.isSelectable <- data?.isSelectable
      ?? ((data.isUnlocked || !shouldSelectAvailableUnit) && (canSelectEmptyCrew || data.unit != null))
    local isControlledUnit = !::is_respawn_screen()
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
    local res = []
    local country = getForcedCountry()
    local needNewSlot = !::g_crews_list.isSlotbarOverrided && showNewSlot
    local needShowLockedSlots = missionRules == null || missionRules.needShowLockedSlots
    local needEmptySlot = !::g_crews_list.isSlotbarOverrided && needShowLockedSlots && showEmptySlot

    local crewsListFull = ::g_crews_list.get()
    for(local c = 0; c < crewsListFull.len(); c++)
    {
      if (onlyForCountryIdx != null && onlyForCountryIdx != c)
        continue

      local listCountry = crewsListFull[c].country
      if ((singleCountry != null && singleCountry != listCountry)
          || !::is_country_visible(listCountry))
        continue

      local countryData = {
        country = listCountry
        id = c
        isEnabled = !country || country == listCountry
        crews = []
      }
      res.append(countryData)

      if (!countryData.isEnabled)
        continue

      local crewsList = crewsListFull[c].crews
      foreach(crewIdInCountry, crew in crewsList)
      {
        local unit = getCrewUnit(crew)

        if (!unit && !needEmptySlot)
          continue

        local unitName = unit?.name || ""
        local isUnitEnabledByRandomGroups = !missionRules || missionRules.isUnitEnabledByRandomGroups(unitName)
        local isUnlocked = ::isUnitUnlocked(this, unit, c, crewIdInCountry, country, true)
        local status = bit_unit_status.owned
        local isUnitForcedVisible = missionRules && missionRules.isUnitForcedVisible(unitName)
        local isUnitForcedHiden = missionRules && missionRules.isUnitForcedHiden(unitName)
        if (unit)
        {
          if (!isUnlocked)
            status = bit_unit_status.locked
          else if (!::is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, false))
            status = bit_unit_status.broken
          else
          {
            local disabled = !::is_unit_enabled_for_slotbar(unit, this)
            if (checkRespawnBases)
              disabled = disabled || !::get_available_respawn_bases(unit.tags).len()
            if (disabled)
              status = bit_unit_status.disabled
          }
        }

        local isAllowedByLockedSlots = isUnitForcedVisible || needShowLockedSlots || status == bit_unit_status.owned
        if (unit && (!isAllowedByLockedSlots || !isUnitEnabledByRandomGroups || isUnitForcedHiden))
          continue

        addCrewData(countryData.crews,
          { crew = crew, unit = unit, isUnlocked = isUnlocked, status = status })
      }

      if (!needNewSlot)
        continue

      local slotCostTbl = ::get_crew_slot_cost(listCountry)
      if (!slotCostTbl || (slotCostTbl.costGold > 0 && !::has_feature("SpendGold")))
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
    local forcedCountry = getForcedCountry()
    local unitShopCountry = forcedCountry || ::get_profile_country_sq()
    local curUnit = ::get_show_aircraft()
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
      local curCrew = ::getSlotItem(curSlotCountryId, curSlotIdInCountry)
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
      local selCrewidInCountry = ::selected_crews?[countryData.id]
      foreach(crewData in countryData.crews)
      {
        local crew = crewData.crew
        local unit = crewData.unit
        local isSelectable = crewData.isSelectable
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
    local selCrewIdInCountry = ::selected_crews?[countryData.id]
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
    if (::slotbar_oninit)
    {
      ::script_net_assert_once("slotbar recursion", "init_slotbar: recursive call found")
      return
    }

    if (!::g_crews_list.get().len())
    {
      if (::g_login.isLoggedIn() && (::isProductionCircuit() || ::get_cur_circuit_name() == "nightly"))
        ::scene_msg_box("no_connection", null, ::loc("char/no_connection"), [["ok", function () {::gui_start_logout()}]], "ok")
      return
    }

    ::slotbar_oninit = true
    ::init_selected_crews()
    ::update_crew_skills_available()
    local crewsConfig = gatherVisibleCrewsConfig()
    selectedCrewData = calcSelectedCrewData(crewsConfig)

    local isFullSlotbar = crewsConfig.len() > 1
    local hasCountryTopBar = isFullSlotbar && showTopPanel && !singleCountry
    if (hasCountryTopBar)
      ::initSlotbarTopBar(scene, true) //show autorefill checkboxes

    crewsObj.hasHeader = !hasCountryTopBar ? "yes" : "no"
    crewsObj.hasBackground = isFullSlotbar ? "no" : "yes"
    local hObj = scene.findObject("slotbar_background")
    hObj.show(isFullSlotbar)
    if (::show_console_buttons)
      updateConsoleButtonsVisible(hasCountryTopBar)

    local countriesView = {
      hasNotificationIcon = hasResearchesBtn
      countries = []
    }
    local selCountryIdx = 0
    local selCountryId = null
    foreach(idx, countryData in crewsConfig)
    {
      local country = countryData.country
      if (countryData.id == selectedCrewData?.idCountry)
      {
        selCountryIdx = idx
        selCountryId = countryData.id
      }

      local bonusData = null
      if (!::is_first_win_reward_earned(country, INVALID_USER_ID))
        bonusData = getCountryBonusData(country)

      local cEnabled = countryData.isEnabled
      local cUnlocked = ::isCountryAvailable(country)
      local tooltipText = !cUnlocked ? ::loc("mainmenu/countryLocked/tooltip")
        : ::loc(country)
      countriesView.countries.append({
        countryIdx = countryData.id
        country = country
        tooltipText = tooltipText
        countryIcon = ::get_country_icon(country, false, !cUnlocked || !cEnabled)
        bonusData = bonusData
        isEnabled = cEnabled && cUnlocked
      })
    }

    local countriesNestObj = scene.findObject("header_countries")
    local prevCountriesNestValue = countriesNestObj.getValue()
    if (!countriesNestObj.childrenCount())
    {
      local countriesData = ::handyman.renderCached("gui/slotbar/slotbarCountryItem", countriesView)
      guiScene.replaceContentFromText(countriesNestObj, countriesData, countriesData.len(), this)
    }

    countriesNestObj.setValue(selCountryIdx)
    if (prevCountriesNestValue == selCountryIdx)
      onHeaderCountry(countriesNestObj)

    if (selectedCrewData)
    {
      local selItem = ::get_slot_obj(crewsObj, selectedCrewData.idCountry, selectedCrewData.idInCountry)
      if (selItem)
        guiScene.performDelayed(this, function() {
          if (::check_obj(selItem) && selItem.isVisible())
            selItem.scrollToView()
        })
    }

    ::slotbar_oninit = false
    guiScene.applyPendingChanges(false)

    local countriesNestMaxWidth = ::g_dagui_utils.toPixels(guiScene, "1@slotbarCountriesMaxWidth")
    local countriesNestWithBtnsObj = scene.findObject("header_countries_nest")
    if (countriesNestWithBtnsObj.getSize()[0] > countriesNestMaxWidth)
      countriesNestObj.isShort = "yes"

    local needEvent = selectedCrewData
      && ((curSlotCountryId >= 0 && curSlotCountryId != selectedCrewData.idCountry)
        || (curSlotIdInCountry >= 0 && curSlotIdInCountry != selectedCrewData.idInCountry))
    if (needEvent)
    {
      local cObj = scene.findObject("airs_table_" + selectedCrewData.idCountry)
      if (::check_obj(cObj))
      {
        skipCheckAirSelect = true
        onSlotbarSelect(cObj)
      }
    }
    else
    {
      curSlotCountryId   = selectedCrewData?.idCountry ?? -1
      curSlotIdInCountry = selectedCrewData?.idInCountry ?? -1
    }
  }

  getCountryBonusData = @(country) getBonus(
    ::shop_get_first_win_xp_rate(country),
    ::shop_get_first_win_wp_rate(country), "item")

  function fillCountryContent(countryData, tblObj)
  {
    if (loadedCountries?[countryData.id] == ::g_crews_list.version
      || !::check_obj(tblObj))
      return

    loadedCountries[countryData.id] <- ::g_crews_list.version
    lastUpdatedVersion = ::g_crews_list.version

    local selCrewData = selectedCrewData?.idCountry == countryData.id
      ? selectedCrewData
      : getSelectedCrewDataInCountry(countryData)

    updateSlotRowView(countryData, tblObj)
    if (selCrewData)
      ::gui_bhv.columnNavigator.selectCell(tblObj, 0, selCrewData.crewIdVisible, false)

    foreach(crewData in countryData.crews)
      if (crewData.unit)
      {
        local id = ::get_slot_obj_id(countryData.id, crewData.idInCountry)
        ::fill_unit_item_timers(tblObj.findObject(id), crewData.unit)
        local bonusId = ::get_slot_obj_id(countryData.id, crewData.idInCountry, true)
        ::showAirExpWpBonus(tblObj.findObject(bonusId), crewData.unit.name)
      }
  }

  function checkUpdateCountryInScene(countryIdx)
  {
    if (loadedCountries?[countryIdx] == ::g_crews_list.version)
      return

    local countryData = gatherVisibleCrewsConfig(countryIdx)?[0]
    if (!countryData)
      return

    fillCountryContent(countryData, scene.findObject("airs_table_" + countryData.id))
  }

  function getCurSlotUnit()
  {
    return ::getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
  }

  function getCurCrew() //will return null when selected recruitCrew
  {
    return getSlotItem(curSlotCountryId, curSlotIdInCountry)
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

  function getCurFocusObj()
  {
    if (!isValid() || scene.getModalCounter() != 0 || !scene.isVisible())
      return null

    checkWrapFrom()
    return getObjByConfigItem(focusArray?[currentFocusItem]) ?? findObjInFocusArray(false)
  }

  function checkWrapFrom()
  {
    local wrapObj = ::g_last_nav_wrap.getWrapObj()
    if (!wrapObj)
      return false

    local wrapDir = ::g_last_nav_wrap.getWrapDir()
    local needWrapTo = wrapDir.isVertical
    ::g_last_nav_wrap.clearWrap()
    if (needWrapTo)
      selectItem(wrapDir.isPositive)
    return needWrapTo
  }

  function selectItem(isPositive)
  {
    if (currentFocusItem  < 0 && !isPositive)
    {
      currentFocusItem = 0
      return
    }

    if (currentFocusItem > focusArray.len() && isPositive)
    {
      currentFocusItem = focusArray.len() - 1
      return
    }

    local focusIdx = isPositive ? 0 : focusArray.len() - 1
    for(local i = 0; i < focusArray.len(); i++)
    {
      local obj = getObjByConfigItem(focusArray[focusIdx])
      if (!::check_obj(obj) || !obj.isVisible() || !obj.isEnabled())
      {
        focusIdx = focusIdx + (isPositive ? 1 : (-1))
        continue
      }

      currentFocusItem = focusIdx
      return
    }
  }

  function getFocusObj()
  {
    return getCurrentAirsTable()
  }

  function getCurrentAirsTable()
  {
    return scene.findObject("airs_table_" + curSlotCountryId)
  }

  function getCurrentCrewSlot()
  {
    local airsTable = getCurrentAirsTable()
    if (!::check_obj(airsTable))
      return null

    if (airsTable.getChild(0).childrenCount() > curSlotIdInCountry)
      return airsTable.getChild(0).getChild(curSlotIdInCountry).getChild(1)
    return null
  }

  function getSlotIdByObjId(slotObjId, countryId)
  {
    local prefix = "td_slot_"+countryId+"_"
    if (!::g_string.startsWith(slotObjId, prefix))
      return -1
    return ::to_integer_safe(slotObjId.slice(prefix.len()), -1)
  }

  function getSelSlotDataByObj(obj)
  {
    local res = {
      isValid = false
      countryId = -1
      crewIdInCountry = -1
    }

    local countryIdStr = ::getObjIdByPrefix(obj, "airs_table_")
    if (!countryIdStr)
      return res
    res.countryId = countryIdStr.tointeger()

    local curCol = obj.cur_col.tointeger()
    if (curCol < 0)
      return res
    local trObj = obj.getChild(0)
    if (curCol >= trObj.childrenCount())
      return res

    local curTdId = trObj.getChild(curCol).id
    res.crewIdInCountry = getSlotIdByObjId(curTdId, res.countryId)
    res.isValid = res.crewIdInCountry >= 0
    return res
  }

  function onSlotbarSelect(obj)
  {
    if (!::checkObj(obj))
      return

    if (::slotbar_oninit || skipCheckAirSelect || !shouldCheckQueue)
    {
      onSlotbarSelectImpl(obj)
      skipCheckAirSelect = false
    }
    else
      checkedAirChange(
        (@(obj) function() {
          if (::checkObj(obj))
            onSlotbarSelectImpl(obj)
        })(obj),
        (@(obj) function() {
          if (::checkObj(obj))
          {
            skipCheckAirSelect = true
            selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
          }
        })(obj)
      )
  }

  function onSlotbarSelectImpl(obj)
  {
    if (!::check_obj(obj))
      return

    local selSlot = getSelSlotDataByObj(obj)
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
          if (::check_obj(obj))
            applySlotSelection(obj, selSlot)
        }, this),
        Callback(function()
        {
          ignoreCheckSlotbar = false
          if (curSlotCountryId != selSlot.countryId)
            setCountry(::g_crews_list.get()?[curSlotCountryId]?.country)
          else if (::check_obj(obj))
            selectTblAircraft(obj, curSlotIdInCountry)
        }, this),
        selSlot
      )
    }
    else
      applySlotSelection(obj, selSlot)

   battleRating.updateBattleRating()
  }

  function applySlotSelection(obj, selSlot)
  {
    curSlotCountryId = selSlot.countryId
    curSlotIdInCountry = selSlot.crewIdInCountry

    if (::slotbar_oninit)
    {
      if (afterSlotbarSelect)
        afterSlotbarSelect()
      return
    }

    local crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    if (needActionsWithEmptyCrews && !crew && (curSlotCountryId in ::g_crews_list.get()))
    {
      local country = ::g_crews_list.get()[curSlotCountryId].country

      local rawCost = ::get_crew_slot_cost(country)
      local cost = rawCost? ::Cost(rawCost.cost, rawCost.costGold) : ::Cost()
      if (::check_balance_msgBox(cost))
      {
        if (cost > ::zero_money)
        {
          local msgText = ::warningIfGold(
            format(::loc("shop/needMoneyQuestion_purchaseCrew"),
              cost.getTextAccordingToBalance()),
            cost)
          ignoreCheckSlotbar = true
          msgBox("need_money", msgText,
            [["ok", (@(country) function() {
                      ignoreCheckSlotbar = false
                      purchaseNewSlot(country)
                    })(country) ],
             ["cancel", (@(obj, curSlotCountryId) function() {
                          ignoreCheckSlotbar = false
                          selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
                        })(obj, curSlotCountryId) ]
            ], "ok")
        }
        else
          purchaseNewSlot(country)
      }
      else
        selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
    }
    else if (crew)
    {
      local unit = getCrewUnit(crew)
      if (unit)
        setCrewUnit(unit)
      else if (needActionsWithEmptyCrews)
        onSlotChangeAircraft()
    }

    if (hasActions)
    {
      local slotItem = ::get_slot_obj(obj, curSlotCountryId, ::to_integer_safe(obj?.cur_col))
      openUnitActionsList(slotItem, true)
    }

    if (afterSlotbarSelect)
      afterSlotbarSelect()
  }

  /**
   * Selects crew in slotbar with specified id
   * as if player clicked slot himself.
   */
  function selectCrew(crewIdInCountry)
  {
    local objId = "airs_table_" + curSlotCountryId
    local obj = scene.findObject(objId)
    if (::checkObj(obj))
      selectTblAircraft(obj, crewIdInCountry)
  }

  function selectTblAircraft(tblObj, slotIdInCountry=0)
  {
    if (tblObj && tblObj.isValid() && slotIdInCountry >= 0)
    {
      local slotIdx = getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
      if (slotIdx < 0)
        return
      ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, tblObj, 0, slotIdx)
    }
  }

  function getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
  {
    if (!tblObj.childrenCount())
      return -1
    if (tblObj?.id != "airs_table_" + curSlotCountryId)
    {
      local tblObjId = tblObj?.id         // warning disable: -declared-never-used
      local countryId = curSlotCountryId  // warning disable: -declared-never-used
      ::script_net_assert_once("bad slot country id", "Error: Try to select crew from wrong country")
      return -1
    }
    local slotListObj = tblObj.getChild(0)
    if (!::checkObj(slotListObj))
      return -1
    local prefix = "td_slot_" + curSlotCountryId +"_"
    for(local i = 0; i < slotListObj.childrenCount(); i++)
    {
      local id = ::getObjIdByPrefix(slotListObj.getChild(i), prefix)
      if (!id)
      {
        local objId = slotListObj.getChild(i).id // warning disable: -declared-never-used
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
    onSlotDblClick(getCurCrew())
  }

  function onSlotbarClick(obj)
  {
    obj.select()
  }

  function checkSelectCountryByIdx(obj)
  {
    local idx = obj.getValue()
    local countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(idx), "header_country"), curSlotCountryId)
    if (curSlotCountryId >= 0 && curSlotCountryId != countryIdx && countryIdx in ::g_crews_list.get()
        && !::isCountryAvailable(::g_crews_list.get()[countryIdx].country) && ::unlocked_countries.len())
    {
      msgBox("notAvailableCountry", ::loc("mainmenu/countryLocked/tooltip"),
             [["ok", (@(obj) function() {
               if (::checkObj(obj))
                 obj.setValue(curSlotCountryId)
             })(obj) ]], "ok")
      return false
    }
    return true
  }

  function checkCreateCrewsNest(countryData)
  {
    local countriesCount = crewsObj.childrenCount()
    local animBlockId = "crews_anim_" + countryData.idx
    for (local i = 0; i < countriesCount; i++)
    {
      local animObj = crewsObj.getChild(i)
      animObj.animation = animObj?.id == animBlockId ? "show" : "hide"
    }

    local animBlockObj = crewsObj.findObject(animBlockId)
    if (::check_obj(animBlockObj))
      return

    local blk = ::handyman.renderCached("gui/slotbar/slotbarItem", {
      countryIdx = countryData.idx
      needSkipAnim = countriesCount == 0
      alwaysShowBorder = alwaysShowBorder
      countryImage = ::get_country_icon(countryData.country, false)
    })
    guiScene.appendWithBlk(crewsObj, blk, this)
  }

  function onHeaderCountry(obj)
  {
    local countryData = getCountryDataByObject(obj)
    if (::slotbar_oninit || skipCheckCountrySelect)
    {
      onSlotbarCountryImpl(countryData)
      skipCheckCountrySelect = false
      return
    }

    local lockedCountryData = ::SessionLobby.getLockedCountryData()
      ?? ::g_world_war.getLockedCountryData()
      ?? ::g_squad_manager.getLockedCountryData()

    if (lockedCountryData != null
      && !::isInArray(countryData.country, lockedCountryData.availableCountries))
    {
      setCountry(::get_profile_country_sq())
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

      checkedCrewAirChange(
        function() {
          if (::checkObj(obj))
          {
            onSlotbarCountryImpl(countryData)
            ::slotbarPresets.setCurrentGameModeByPreset(countryData.country)
          }
        },
        function() {
          if (::checkObj(obj))
            setCountry(::get_profile_country_sq())
        }
      )
    }
  }

  function setCountry(country)
  {
    foreach(idx, c in ::g_crews_list.get())
      if (c.country == country)
      {
        local hObj = scene.findObject("header_countries")
        if (!::check_obj(hObj) || hObj.getValue() == idx)
          break

        skipCheckCountrySelect = true
        skipCheckAirSelect = true
        hObj.setValue(idx)
        break
      }
  }

  function getCountryDataByObject(obj)
  {
    if (!::check_obj(obj))
      return null

    local curValue = obj.getValue()
    if (obj.childrenCount() <= curValue)
      return null

    local countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(curValue), "header_country"), curSlotCountryId)
    local country = ::g_crews_list.get()[countryIdx].country

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

      ::switch_profile_country(countryData.country)
      onSlotbarSelect(crewsObj.findObject("airs_table_" + countryData.idx))
    }
    else
      onSlotbarSelect(crewsObj.findObject("airs_table_" + countryData.idx))

    onSlotbarCountryChanged()
    if (ownerWeak)
      ownerWeak.delayedRestoreFocus()
  }

  function onSlotbarCountryChanged()
  {
    if (ownerWeak?.presetsListWeak)
      ownerWeak.presetsListWeak.update()
    if (onCountryChanged)
      onCountryChanged()
    battleRating.updateBattleRating()
  }

  function prevCountry(obj) { switchCountry(-1) }

  function nextCountry(obj) { switchCountry(1) }

  function switchCountry(way)
  {
    if (singleCountry)
      return

    local hObj = scene.findObject("header_countries")
    if (hObj.childrenCount() <= 1)
      return

    local curValue = hObj.getValue()
    local value = ::getNearestSelectableChildIndex(hObj, curValue, way)
    if(value != curValue)
      hObj.setValue(value)
  }

  function onSlotChangeAircraft()
  {
    local crew = getCurCrew()
    if (!crew)
      return

    local slotbar = this
    ignoreCheckSlotbar = true
    checkedCrewAirChange(function() {
        ignoreCheckSlotbar = false
        selectUnitHandler.open(crew, slotbar)
      },
      function() {
        ignoreCheckSlotbar = false
        checkSlotbar()
      }
    )
  }

  function nextSlot(way)
  {
    local tblObj = scene.findObject("airs_table_" + curSlotCountryId)
    if (::check_obj(tblObj))
      ::gui_bhv.columnNavigator.selectColumn.call(::gui_bhv.columnNavigator, tblObj, way)
  }

  function onSlotbarNextAir() { nextSlot(1) }
  function onSlotbarPrevAir() { nextSlot(-1) }

  function shade(shouldShade)
  {
    if (isShaded == shouldShade)
      return

    isShaded = shouldShade
    local shadeObj = scene.findObject("slotbar_shade")
    if(::check_obj(shadeObj))
      shadeObj.animation = isShaded ? "show" : "hide"
    if (::show_console_buttons)
      updateConsoleButtonsVisible(!isShaded)
  }

  function updateConsoleButtonsVisible(isVisible)
  {
    showSceneBtn("prev_country_btn", isVisible)
    showSceneBtn("next_country_btn", isVisible)
  }

  function forceUpdate()
  {
    updateSlotbarImpl()
  }

  function fullUpdate()
  {
    doWhenActiveOnce("updateSlotbarImpl")
  }

  function updateSlotbarImpl()
  {
    if (ignoreCheckSlotbar)
      return

    loadedCountries.clear()
    if (beforeFullUpdate)
      beforeFullUpdate()

    refreshAll()
    if (isSceneActiveNoModals() && ownerWeak)
      ownerWeak.restoreFocus()

    if (afterFullUpdate)
      afterFullUpdate()
  }

  function checkSlotbar()
  {
    if (ignoreCheckSlotbar || !::isInMenu())
      return

    if (!(curSlotCountryId in ::g_crews_list.get())
        || ::g_crews_list.get()[curSlotCountryId].country != ::get_profile_country_sq()
        || curSlotIdInCountry != ::selected_crews[curSlotCountryId] || getCurSlotUnit() == null)
      updateSlotbarImpl()
    else if (selectedCrewData && selectedCrewData?.unit != get_show_aircraft())
      refreshAll()
  }

  function onSceneActivate(show)
  {
    base.onSceneActivate(show)
    if (checkActiveForDelayedAction())
      checkSlotbar()
  }

  function onEventModalWndDestroy(p)
  {
    base.onEventModalWndDestroy(p)
    if (checkActiveForDelayedAction())
      checkSlotbar()
  }

  function purchaseNewSlot(country)
  {
    ignoreCheckSlotbar = true

    local onTaskSuccess = Callback(function()
    {
      ignoreCheckSlotbar = false
      onSlotChangeAircraft()
    }, this)

    local onTaskFail = Callback(function(result) { ignoreCheckSlotbar = false }, this)

    if (!::g_crew.purchaseNewSlot(country, onTaskSuccess, onTaskFail))
      ignoreCheckSlotbar = false
  }

  //return GuiBox of visible slotbar units
  function getBoxOfUnits()
  {
    local obj = scene.findObject("airs_table_" + curSlotCountryId)
    if (!::check_obj(obj))
      return null

    local box = ::GuiBox().setFromDaguiObj(obj)
    local pBox = ::GuiBox().setFromDaguiObj(obj.getParent())
    if (box.c2[0] > pBox.c2[0])
      box.c2[0] = pBox.c2[0] + pBox.c1[0] - box.c1[0]
    return box
  }

  //return GuiBox of visible slotbar countries
  function getBoxOfCountries()
  {
    local headerCountriesObj = scene.findObject("header_countries")
    if (!::check_obj(headerCountriesObj))
      return null

    return ::GuiBox().setFromDaguiObj(headerCountriesObj)
  }

  function getSlotsData(unitId = null, slotCrewId = -1, withEmptySlots = false)
  {
    local unitSlots = []
    foreach(countryId, countryData in ::g_crews_list.get())
      if (!singleCountry || countryData.country == singleCountry)
        foreach (idInCountry, crew in countryData.crews)
        {
          if (slotCrewId != -1 && slotCrewId != (crew?.id ?? -1))
            continue
          local unit = getCrewUnit(crew)
          if (unitId && unit && unitId != unit.name)
            continue
          local obj = ::get_slot_obj(scene, countryId, idInCountry)
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

    local showBR = ::has_feature("SlotbarShowBattleRating")
    local curEdiff = getCurrentEdiff()

    foreach (slot in unitSlots)
    {
      local obj = slot.obj.findObject("rank_text")
      if (::checkObj(obj))
      {
        local unitRankText = ::get_unit_rank_text(slot.unit, slot.crew, showBR, curEdiff)
        obj.setValue(unitRankText)
      }
    }
  }

  function updateCrews(unitSlots = null)
  {
    if (::g_crews_list.isSlotbarOverrided)
      return

    unitSlots = unitSlots || getSlotsData()

    foreach (slot in unitSlots)
    {
      slot.obj["crewStatus"] = ::get_crew_status(slot.crew, slot.unit)

      local obj = slot.obj.findObject("crew_level")
      if (::checkObj(obj))
      {
        local crewLevelText = slot.unit
          ? ::g_crew.getCrewLevel(slot.crew, slot.unit, slot.unit.getCrewUnitType()).tointeger().tostring()
          : ""
        obj.setValue(crewLevelText)
      }

      obj = slot.obj.findObject("crew_spec")
      if (::check_obj(obj))
      {
        local crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(slot.crew, slot.unit).trainedIcon
        obj["background-image"] = crewSpecIcon
      }
    }
  }

  function onSlotBattle(obj)
  {
    if (onSlotBattleBtn)
      onSlotBattleBtn()
  }

  function onEventCrewsListChanged(p)
  {
    guiScene.performDelayed(this, function() {
      if (!isValid() || lastUpdatedVersion == ::g_crews_list.version)
        return

      fullUpdate()
    })
  }

  function onEventCrewSkillsChanged(params)
  {
    local crew = ::getTblValue("crew", params)
    if (crew)
      updateCrews(getSlotsData(null, crew.id))
  }

  function onEventQualificationIncreased(params)
  {
    local unit = ::getTblValue("unit", params)
    if (unit)
      updateCrews(getSlotsData(unit.name))
  }

  function onEventAutorefillChanged(params)
  {
    if (!("id" in params) || !("value" in params))
      return

    local obj = scene.findObject(params.id)
    if (obj && obj.getValue() != params.value)
      obj.setValue(params.value)
  }

  function updateSlotRowView(countryData, tblObj)
  {
    if (!countryData)
      return

    local rowData = ""
    foreach(crewData in countryData.crews)
    {
      local id = ::get_slot_obj_id(countryData.id, crewData.idInCountry)
      local crew = crewData.crew
      if (!crew)
      {
        rowData += ::build_aircraft_item(
          id,
          null,
          {
            emptyText = "#shop/recruitCrew",
            crewImage = "#ui/gameuiskin#slotbar_crew_recruit_" + ::g_string.slice(countryData.country, 8)
            isCrewRecruit = true
            emptyCost = crewData.cost
            isSlotbarItem = true
          })
        continue
      }

      local isVisualDisabled = crewData?.isVisualDisabled ?? false
      local isLocalState = crewData?.isLocalState ?? true
      local airParams = {
        emptyText      = isVisualDisabled ? "" : emptyText,
        crewImage      = "#ui/gameuiskin#slotbar_crew_free_" + ::g_string.slice(countryData.country, 8)
        status         = ::getUnitItemStatusText(crewData.status),
        inactive       = ::show_console_buttons && crewData.status == bit_unit_status.locked && ::is_in_flight(),
        hasActions     = hasActions
        toBattle       = toBattle
        mainActionFunc = ::SessionLobby.canChangeCrewUnits() ? "onSlotChangeAircraft" : ""
        mainActionText = "" // "#multiplayer/changeAircraft"
        mainActionIcon = "#ui/gameuiskin#slot_change_aircraft.svg"
        crewId         = crew?.id
        isSlotbarItem  = true
        showBR         = ::has_feature("SlotbarShowBattleRating")
        getEdiffFunc   = getCurrentEdiff.bindenv(this)
        hasExtraInfoBlock = hasExtraInfoBlock
        haveRespawnCost = haveRespawnCost
        haveSpawnDelay = haveSpawnDelay
        totalSpawnScore = totalSpawnScore
        sessionWpBalance = sessionWpBalance
        curSlotIdInCountry = crew.idInCountry
        curSlotCountryId = crew.idCountry
        unlocked = crewData.isUnlocked
        tooltipParams = { needCrewInfo = ::has_feature("CrewInfo") && !::g_crews_list.isSlotbarOverrided
          showLocalState = isLocalState
          crewId = crew?.id}
        missionRules = missionRules
        forceCrewInfoUnit = unitForSpecType
        isLocalState = isLocalState
      }
      airParams.__update(getCrewDataParams(crewData))

      rowData += ::build_aircraft_item(id, crewData.unit, airParams)
    }

    rowData = "tr { " + rowData + " } "

    guiScene.replaceContentFromText(tblObj, rowData, rowData.len(), this)
  }

  getCrewDataParams = @(crewData) {}
  getSlotbar = @() this

  function setCrewUnit(unit)
  {
    ::set_show_aircraft(unit)
    //need to send event when crew in country not changed, because main unit changed.
    ::select_crew(curSlotCountryId, curSlotIdInCountry, true)
  }

  function getDefaultDblClickFunc()
  {
    return ::Callback(function(crew) {
      if (::g_crews_list.isSlotbarOverrided)
        return
      local unit = getCrewUnit(crew)
      if (unit)
        ::open_weapons_for_unit(unit, { curEdiff = getCurrentEdiff() })
    }, this)
  }
}