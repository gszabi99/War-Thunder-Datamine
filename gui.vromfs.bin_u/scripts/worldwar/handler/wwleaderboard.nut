from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
let wwRewards = require("%scripts/worldWar/handler/wwRewards.nut")
let time = require("%scripts/time.nut")
let { getSeparateLeaderboardPlatformName,
        getSeparateLeaderboardPlatformValue } = require("%scripts/social/crossplay.nut")
let { addClanTagToNameInLeaderbord } = require("%scripts/leaderboard/leaderboardView.nut")

::ww_leaderboards_list <- [
  ::g_lb_category.UNIT_RANK
  ::g_lb_category.WW_EVENTS_PERSONAL_ELO
  ::g_lb_category.OPERATION_COUNT
  ::g_lb_category.OPERATION_WINRATE
  ::g_lb_category.BATTLE_COUNT
  ::g_lb_category.BATTLE_WINRATE
  ::g_lb_category.FLYOUTS
  ::g_lb_category.DEATHS
  ::g_lb_category.PLAYER_KILLS
  ::g_lb_category.AI_KILLS
  ::g_lb_category.AVG_PLACE
  ::g_lb_category.AVG_SCORE
]


::gui_handlers.WwLeaderboard <- class extends ::gui_handlers.LeaderboardWindow
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/leaderboard/leaderboard.blk"

  beginningMode = null
  needDayOpen = false

  lbDay = null
  lbMode = null
  lbModeData = null
  lbMap = null
  lbCountry = null

  lbModesList = null
  lbDaysList = null
  lbMapsList = null
  lbCountriesList = null

  wwMapsList = null
  requestData = null

  rewardsBlk = null
  rewardsTimeData = null
  availableMapsList = null
  availableCountriesList = null

  function initScreen()
  {
    if (!lbModel)
    {
      lbModel = ::leaderboardModel
      lbModel.reset()
    }
    if (!lb_presets)
      lb_presets = ::ww_leaderboards_list

    platformFilter = getSeparateLeaderboardPlatformName()
    setRowsInPage()
    ::add_big_query_record("ww_leaderboard.open", platformFilter)

    initTable()
    fillMapsList()
    initModes()
    initTopItems()
    updateButtons()
    fetchRewardsData()
    fetchRewardsTimeData()
  }

  function fetchRewardsData()
  {
    let requestBlk = ::DataBlock()
    requestBlk.configname = "ww_rewards"
    ::g_tasker.charRequestBlk("cmn_get_config_bin", requestBlk, null,
      Callback(function(res) {
        rewardsBlk = ::DataBlock()
        let curCircuitRewardsBlk = res?.body?[::get_cur_circuit_name()]
        if (curCircuitRewardsBlk)
          rewardsBlk.setFrom(curCircuitRewardsBlk)
        updateButtons()
      }, this),
      Callback(function(res) {
        rewardsBlk = null
        updateButtons()
      }, this))
  }

  function fetchRewardsTimeData()
  {
    let userstatRequestData = {
      add_token = true
      headers = { appid = "1134" }
      action = "GetTablesInfo"
    }

    let callback = Callback(function(userstatTbl) {
      rewardsTimeData = {}
      foreach (key, val in (userstatTbl?.response ?? userstatTbl))
      {
        let rewardTimeStr = val?.interval?.index == 0 && val?.prevInterval?.index != 0 ?
          val?.prevInterval?.end : val?.interval?.end
        rewardsTimeData[key] <- rewardTimeStr ? time.getTimestampFromIso8601(rewardTimeStr) : 0
      }
    }, this)

    ::userstat.request(userstatRequestData, @(userstatTbl) callback(userstatTbl))
  }

  function fillMapsList()
  {
    wwMapsList = []
    foreach (map in ::g_ww_global_status_type.MAPS.getList())
      if (map.isVisible())
        wwMapsList.append(map)
  }

  function initModes()
  {
    lbModeData = null
    lbMode = null
    lbModesList = []

    let isAvailableWWSeparateLb = !getSeparateLeaderboardPlatformValue()
     || hasFeature("ConsoleSeparateWWLeaderboards")

    local data = ""
    foreach(idx, modeData in wwLeaderboardData.modes)
    {
      if (!modeData?.isInLeaderboardModes ||
        (modeData?.needFeature && !hasFeature(modeData.needFeature)))
        continue

      if (!isAvailableWWSeparateLb && modeData?.needShowConsoleFilter == true)
        continue

      lbModesList.append(modeData)
      let optionText = ::g_string.stripTags(
        loc($"worldwar/leaderboard/{modeData.mode}"))
      data += "option {text:t='{0}'}".subst(optionText)
    }

    let curMod = beginningMode
    let modeIdx = lbModesList.findindex(@(m) m.mode == curMod ) ?? 0

    let modesObj = this.showSceneBtn("modes_list", true)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(modeIdx)
  }

  function updateDaysComboBox(seasonDays)
  {
    let seasonDay = wwLeaderboardData.getSeasonDay(seasonDays)
    lbDaysList = [null]
    for (local i = 0; i < seasonDay; i++)
    {
      let dayNumber = seasonDay - i
      if (isInArray(wwLeaderboardData.getDayIdByNumber(dayNumber), seasonDays))
        lbDaysList.append(dayNumber)
    }

    local data = ""
    foreach(day in lbDaysList)
    {
      let optionText = ::g_string.stripTags(
        day ? loc("enumerated_day", {number = day}) : loc("worldwar/allSeason"))
      data += format("option {text:t='%s'}", optionText)
    }

    let daysObj = this.showSceneBtn("days_list", lbModeData.hasDaysData)
    guiScene.replaceContentFromText(daysObj, data, data.len(), this)

    daysObj.setValue(needDayOpen && lbDaysList.len() > 1 ? 1 : 0)
  }

  function updateMapsComboBox()
  {
    lbMapsList = getWwMaps()

    local data = ""
    foreach(wwMap in lbMapsList)
    {
      let optionText = ::g_string.stripTags(
        wwMap ? wwMap.getNameTextByMapName(wwMap.getId()) : loc("worldwar/allMaps"))
      data += format("option {text:t='%s'}", optionText)
    }

    let mapsObj = this.showSceneBtn("maps_list", lbMapsList.len() > 1)
    guiScene.replaceContentFromText(mapsObj, data, data.len(), this)

    local mapObjValue = 0
    if (lbMap)
    {
      let selectedMapId = lbMap.getId()
      mapObjValue = lbMapsList.findindex(@(m) m && m.getId() == selectedMapId) ?? 0
    }
    lbMap = null
    mapsObj.setValue(mapObjValue)
  }

  function updateCountriesComboBox(filterMap = null)
  {
    lbCountriesList = getWwCountries(filterMap)

    local data = ""
    foreach(country in lbCountriesList)
    {
      let optionText = ::g_string.stripTags(
        country ? loc(country) : loc("worldwar/allCountries"))
      data += format("option {text:t='%s'}", optionText)
    }

    let countriesObj = this.showSceneBtn("countries_list", lbCountriesList.len() > 1)
    guiScene.replaceContentFromText(countriesObj, data, data.len(), this)

    local countryObjValue = 0
    if (lbCountry)
    {
      let selectedCountry = lbCountry
      countryObjValue = lbCountriesList.findindex(@(c) c && c == selectedCountry) ?? 0
    }
    lbCountry = null
    countriesObj.setValue(countryObjValue)
  }

  function fetchLbData(isForce = false)
  {
    let newRequestData = getRequestData()
    if (!newRequestData)
      return

    let isRequestDifferent = !::u.isEqual(requestData, newRequestData)
    if (!isRequestDifferent && !isForce)
      return

    if (isRequestDifferent)
      pos = 0

    lbField = curLbCategory.field
    requestData = newRequestData

    let requestParams = {
      gameMode = requestData.modeName + requestData.modePostFix
      table    = requestData.day && requestData.day > 0 ? "day" + requestData.day : "season"
      category = lbField
      platformFilter = requestData.platformFilter
    }

    let cb = function(hasSelfRow = false)
    {
      let callback = Callback(
        function(lbPageData) {
          if (!hasSelfRow)
            selfRowData = []
          pageData = wwLeaderboardData.addClanInfoIfNeedAndConvert(requestData.modeName, lbPageData, isCountriesLeaderboard())
          fillLeaderboard(pageData)
        }, this)
      wwLeaderboardData.requestWwLeaderboardData(
        requestData.modeName,
        requestParams.__update({
          start    = pos
          count    = rowsInPage
        }),
        @(lbPageData) callback(lbPageData))
    }

    if (isUsersLeaderboard() || (forClans && ::is_in_clan()))
    {
      let callback = Callback(
        function(lbSelfData) {
          selfRowData = wwLeaderboardData.addClanInfoIfNeedAndConvert(requestData.modeName, lbSelfData, isCountriesLeaderboard()).rows
          if(isRequestDifferent)
            requestSelfPage(getSelfPos())
          cb(true)
        }, this)
      wwLeaderboardData.requestWwLeaderboardData(
        requestData.modeName,
        requestParams.__update({
          start = null
          count = 0
        }),
        @(lbSelfData) callback(lbSelfData),
        { userId = isUsersLeaderboard() ? ::my_user_id_int64
          : ::clan_get_my_clan_id() })
    }
    else
      cb()
  }

  function onModeSelect(obj)
  {
    let modeObjValue = obj.getValue()
    if (modeObjValue < 0 || modeObjValue >= lbModesList.len())
      return

    lbModeData = lbModesList[modeObjValue]
    lbMode = lbModeData.mode
    forClans = lbMode == "ww_clans"
    ::add_big_query_record("ww_leaderboard.select_mode", lbMode);

    checkLbCategory()

    let callback = Callback(
      function(modesData) {
        updateModeDataByAvailableTables(modesData?.modes ?? [])
        updateModeComboBoxes(modesData?.tables)
      }, this)

    wwLeaderboardData.requestWwLeaderboardModes(
      lbMode,
      @(modesData) callback(modesData))
  }

  function updateModeComboBoxes(seasonDays = null)
  {
    if (isCountriesLeaderboard())
    {
      lbCountry = null
      updateCountriesComboBox()
    }
    updateMapsComboBox()
    updateDaysComboBox(seasonDays)
  }

  function checkLbCategory()
  {
    if (!curLbCategory || !lbModel.checkLbRowVisibility(curLbCategory, this))
      curLbCategory = ::u.search(lb_presets, (@(row) lbModel.checkLbRowVisibility(row, this)).bindenv(this))
  }

  function onDaySelect(obj)
  {
    let dayObjValue = obj.getValue()
    if (dayObjValue < 0 || dayObjValue >= lbDaysList.len())
      return

    lbDay = lbDaysList[dayObjValue]
    ::add_big_query_record("ww_leaderboard.select_day", lbDay?.tostring() ?? "all")

    fetchLbData()
  }

  function onMapSelect(obj)
  {
    let mapObjValue = obj.getValue()
    if (mapObjValue < 0 || mapObjValue >= lbMapsList.len())
      return

    lbMap = lbMapsList[mapObjValue]
    ::add_big_query_record("ww_leaderboard.select_map", lbMap?.getId() ?? "all")

    if (!isCountriesLeaderboard())
      updateCountriesComboBox(lbMap)
    else
      fetchLbData()
  }

  function onCountrySelect(obj)
  {
    let countryObjValue = obj.getValue()
    if (countryObjValue < 0 || countryObjValue >= lbCountriesList.len())
      return

    lbCountry = lbCountriesList[countryObjValue]
    ::add_big_query_record("ww_leaderboard.select_country", lbCountry ?? "all")

    if (!isCountriesLeaderboard())
      fetchLbData()
  }

  function onUserDblClick()
  {
    if (isCountriesLeaderboard())
      return

    base.onUserDblClick()
  }

  function getRequestData()
  {
    if (!lbModeData)
      return null

    let mapId = lbMap && isInArray(lbMap, availableMapsList) ? "__" + lbMap.getId() : ""
    let countryId = lbCountry && isInArray(lbCountry, availableCountriesList)
      ? "__" + lbCountry : ""

    return {
      modeName = lbModeData.mode
      modePostFix = mapId + countryId
      day = lbModeData.hasDaysData ? lbDay : null
      platformFilter = lbModeData?.needShowConsoleFilter ? platformFilter : ""
    }
  }

  function getWwMaps()
  {
    let maps = [null]
    foreach (map in availableMapsList)
      maps.append(map)

    return maps
  }

  function getWwCountries(filterMap)
  {
    let countrries = [null]
    if (filterMap)
    {
      foreach (country in filterMap.getCountries())
        if(isInArray(country, availableCountriesList))
          countrries.append(country)

      return countrries
    }

    let countrriesData = {}
    foreach (map in availableMapsList)
      foreach (country in map.getCountries())
        if (!(country in countrriesData) && isInArray(country, availableCountriesList))
          countrriesData[country] <- country

    foreach (country in countrriesData)
      countrries.append(country)

    return countrries
  }

  function isUsersLeaderboard()
  {
    return wwLeaderboardData.isUsersLeaderboard(lbModeData)
  }

  function isCountriesLeaderboard()
  {
    return lbMode == "ww_countries"
  }

  function onRewards()
  {
    let curRewardsBlk = getCurModeAwards()
    if (!curRewardsBlk)
      return ::showInfoMsgBox(loc("leaderboards/has_no_rewards"))

    wwRewards.open({
      isClanRewards = forClans
      rewardsBlk = curRewardsBlk
      rewardsTime = getCurRewardsTime()
      lbMode    = lbMode
      lbDay     = lbDay
      lbMap     = lbMap
      lbCountry = lbCountry
    })
  }

  function updateButtons() {
    base.updateButtons()
    updateWwRewardsButton()
  }

  function updateWwRewardsButton()
  {
    let curRewardsBlk = getCurModeAwards()
    let rewardsBtn = this.showSceneBtn("btn_ww_rewards", true)
    rewardsBtn.inactiveColor = curRewardsBlk ? "no" : "yes"
  }

  function getCurModeAwards()
  {
    let rewardTableName = wwLeaderboardData.getModeByName(lbMode)?.rewardsTableName
    if (!rewardTableName || !rewardsBlk || !requestData)
      return null

    let day = lbDay ? wwLeaderboardData.getDayIdByNumber(lbDay) : "season"
    let awardTableName = requestData.modeName + requestData.modePostFix

    return rewardsBlk?[rewardTableName]?[day]?.awards?[awardTableName]
  }

  function getCurRewardsTime()
  {
    let day = lbDay ? wwLeaderboardData.getDayIdByNumber(lbDay) : "season"
    return rewardsTimeData?[day] ?? 0
  }

  function updateModeDataByAvailableTables(modes)
  {
    availableMapsList = getAvailableMapsList(modes)
    availableCountriesList = getAvailableCountriesList(modes)
  }

  function getAvailableMapsList(modes)
  {
    let mode = lbMode
    let maps = []
    foreach (map in wwMapsList)
      if(::u.search(modes, @(m) m.split(mode)?[1] && m.split(map.name)?[1]) != null)
        maps.append(map)

    return maps
  }

  function getAvailableCountriesList(modes)
  {
    let countries = []
    foreach (mode in modes)
      if(mode.split(lbMode)?[1] != null)
      {
        let cName = mode.split("__country")?[1]
        let country = cName == null ? cName : $"{"country"}{cName}"
        if(country != null && !isInArray(country, countries))
          countries.append(country)
      }

    return countries
  }

  function updateClanTagRowsData(clansInfoList) {
    if (clansInfoList.len() == 0)
      return

    let clansInfo = clansInfoList
    let function updateClanTag(row) {
      row.__update({
        clanTag = clansInfo?[row?.clanId.tostring() ?? ""].tag ?? row?.clanTag ?? ""
      })
    }
    (selfRowData ?? []).map(updateClanTag)
    pageData?.rows.map(updateClanTag)
  }

  function onEventUpdateClansInfoList(p) {
    if (lbMode != "ww_users_manager")
      return

    let clansInfoList = p?.clansInfoList ?? {}
    updateClanTagRowsData(clansInfoList)
    addClanTagToNameInLeaderbord(scene.findObject("lb_table_nest"), clansInfoList)
  }
}
