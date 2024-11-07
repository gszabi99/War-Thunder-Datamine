from "%scripts/dagui_natives.nut" import get_cur_circuit_name, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let DataBlock  = require("DataBlock")
let wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
let wwRewards = require("%scripts/worldWar/handler/wwRewards.nut")
let { getSeparateLeaderboardPlatformName,
        getSeparateLeaderboardPlatformValue } = require("%scripts/social/crossplay.nut")
let { addClanTagToNameInLeaderbord } = require("%scripts/leaderboard/leaderboardView.nut")
let { stripTags } = require("%sqstd/string.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { charRequestBlk } = require("%scripts/tasker.nut")
let { lbCategoryTypes } = require("%scripts/leaderboard/leaderboardCategoryType.nut")
let { leaderboardModel } = require("%scripts/leaderboard/leaderboardHelpers.nut")

::ww_leaderboards_list <- [
  lbCategoryTypes.UNIT_RANK
  lbCategoryTypes.WW_EVENTS_PERSONAL_ELO
  lbCategoryTypes.OPERATION_COUNT
  lbCategoryTypes.OPERATION_WINRATE
  lbCategoryTypes.BATTLE_COUNT
  lbCategoryTypes.BATTLE_WINRATE
  lbCategoryTypes.FLYOUTS
  lbCategoryTypes.DEATHS
  lbCategoryTypes.PLAYER_KILLS
  lbCategoryTypes.AI_KILLS
  lbCategoryTypes.AVG_PLACE
  lbCategoryTypes.AVG_SCORE
]


gui_handlers.WwLeaderboard <- class (gui_handlers.LeaderboardWindow) {
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
  availableMapsList = null
  availableCountriesList = null

  function initScreen() {
    if (!this.lbModel) {
      this.lbModel = leaderboardModel
      this.lbModel.reset()
    }
    if (!this.lb_presets)
      this.lb_presets = ::ww_leaderboards_list

    this.platformFilter = getSeparateLeaderboardPlatformName()
    this.setRowsInPage()
    sendBqEvent("CLIENT_POPUP_1", "ww_leaderboard.open", { platformFilter = this.platformFilter })

    this.initTable()
    this.fillMapsList()
    this.initModes()
    this.updateButtons()
    this.fetchRewardsData()
  }

  function fetchRewardsData() {
    let requestBlk = DataBlock()
    requestBlk.configname = "ww_rewards"
    charRequestBlk("cmn_get_config_bin", requestBlk, null,
      Callback(function(res) {
        this.rewardsBlk = DataBlock()
        let curCircuitRewardsBlk = res?.body?[get_cur_circuit_name()]
        if (curCircuitRewardsBlk)
          this.rewardsBlk.setFrom(curCircuitRewardsBlk)
        this.updateButtons()
      }, this),
      Callback(function(_res) {
        this.rewardsBlk = null
        this.updateButtons()
      }, this))
  }

  function fillMapsList() {
    this.wwMapsList = []
    foreach (map in ::g_ww_global_status_type.MAPS.getList())
      if (map.isVisible())
        this.wwMapsList.append(map)
  }

  function initModes() {
    this.lbModeData = null
    this.lbMode = null
    this.lbModesList = []

    let isAvailableWWSeparateLb = !getSeparateLeaderboardPlatformValue()
     || hasFeature("ConsoleSeparateWWLeaderboards")

    local data = ""
    foreach (_idx, modeData in wwLeaderboardData.modes) {
      if (!modeData?.isInLeaderboardModes ||
        (modeData?.needFeature && !hasFeature(modeData.needFeature)))
        continue

      if (!isAvailableWWSeparateLb && modeData?.needShowConsoleFilter == true)
        continue

      this.lbModesList.append(modeData)
      let optionText = stripTags(
        loc($"worldwar/leaderboard/{modeData.mode}"))
      data = "".concat(data, "option {text:t='{0}'}".subst(optionText))
    }

    let curMod = this.beginningMode
    let modeIdx = this.lbModesList.findindex(@(m) m.mode == curMod) ?? 0

    let modesObj = showObjById("modes_list", true, this.scene)
    this.guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(modeIdx)
  }

  function updateDaysComboBox(seasonDays) {
    let seasonDay = wwLeaderboardData.getSeasonDay(seasonDays)
    this.lbDaysList = [null]
    for (local i = 0; i < seasonDay; i++) {
      let dayNumber = seasonDay - i
      if (isInArray(wwLeaderboardData.getDayIdByNumber(dayNumber), seasonDays))
        this.lbDaysList.append(dayNumber)
    }

    local data = ""
    foreach (day in this.lbDaysList) {
      let optionText = stripTags(
        day ? loc("enumerated_day", { number = day }) : loc("worldwar/allSeason"))
      data = "".concat(data, "option {text:t='{0}'}".subst(optionText))
    }

    let daysObj = showObjById("days_list", this.lbModeData.hasDaysData, this.scene)
    this.guiScene.replaceContentFromText(daysObj, data, data.len(), this)

    daysObj.setValue(this.needDayOpen && this.lbDaysList.len() > 1 ? 1 : 0)
  }

  function updateMapsComboBox() {
    this.lbMapsList = this.getWwMaps()

    local data = ""
    foreach (wwMap in this.lbMapsList) {
      let optionText = stripTags(
        wwMap ? wwMap.getNameTextByMapName(wwMap.getId()) : loc("worldwar/allMaps"))
      data = "".concat(data, "option {text:t='{0}'}".subst(optionText))
    }

    let mapsObj = showObjById("maps_list", this.lbMapsList.len() > 1, this.scene)
    this.guiScene.replaceContentFromText(mapsObj, data, data.len(), this)

    local mapObjValue = 0
    if (this.lbMap) {
      let selectedMapId = this.lbMap.getId()
      mapObjValue = this.lbMapsList.findindex(@(m) m && m.getId() == selectedMapId) ?? 0
    }
    this.lbMap = null
    mapsObj.setValue(mapObjValue)
  }

  function updateCountriesComboBox(filterMap = null) {
    this.lbCountriesList = this.getWwCountries(filterMap)

    local data = ""
    foreach (country in this.lbCountriesList) {
      let optionText = stripTags(
        country ? loc(country) : loc("worldwar/allCountries"))
      data = "".concat(data, "option {text:t='{0}'}".subst(optionText))
    }

    let countriesObj = showObjById("countries_list", this.lbCountriesList.len() > 1, this.scene)
    this.guiScene.replaceContentFromText(countriesObj, data, data.len(), this)

    local countryObjValue = 0
    if (this.lbCountry) {
      let selectedCountry = this.lbCountry
      countryObjValue = this.lbCountriesList.findindex(@(c) c && c == selectedCountry) ?? 0
    }
    this.lbCountry = null
    countriesObj.setValue(countryObjValue)
  }

  function fetchLbData(isForce = false) {
    let newRequestData = this.getRequestData()
    if (!newRequestData)
      return

    let isRequestDifferent = !u.isEqual(this.requestData, newRequestData)
    if (!isRequestDifferent && !isForce)
      return

    if (isRequestDifferent)
      this.pos = 0

    this.lbField = this.curLbCategory.field
    this.requestData = newRequestData

    let requestParams = {
      gameMode = $"{this.requestData.modeName}{this.requestData.modePostFix}"
      table    = this.requestData.day && this.requestData.day > 0 ? $"day{this.requestData.day}" : "season"
      category = this.lbField
      platformFilter = this.requestData.platformFilter
    }

    let cb = function(hasSelfRow = false) {
      let callback = Callback(
        function(lbPageData) {
          if (!hasSelfRow)
            this.selfRowData = []
          this.pageData = wwLeaderboardData.addClanInfoIfNeedAndConvert(this.requestData.modeName, lbPageData, this.isCountriesLeaderboard())
          this.fillLeaderboard(this.pageData)
        }, this)
      wwLeaderboardData.requestWwLeaderboardData(
        this.requestData.modeName,
        requestParams.__update({
          start    = this.pos
          count    = this.rowsInPage
        }),
        @(lbPageData) callback(lbPageData))
    }

    if (this.isUsersLeaderboard() || (this.forClans && ::is_in_clan())) {
      let callback = Callback(
        function(lbSelfData) {
          this.selfRowData = wwLeaderboardData.addClanInfoIfNeedAndConvert(this.requestData.modeName, lbSelfData, this.isCountriesLeaderboard()).rows
          if (isRequestDifferent)
            this.requestSelfPage(this.getSelfPos())
          cb(true)
        }, this)
      wwLeaderboardData.requestWwLeaderboardData(
        this.requestData.modeName,
        requestParams.__update({
          start = null
          count = 0
        }),
        @(lbSelfData) callback(lbSelfData),
        { userId = this.isUsersLeaderboard() ? userIdInt64.value
          : clan_get_my_clan_id() })
    }
    else
      cb()
  }

  function onModeSelect(obj) {
    let modeObjValue = obj.getValue()
    if (modeObjValue < 0 || modeObjValue >= this.lbModesList.len())
      return

    this.lbModeData = this.lbModesList[modeObjValue]
    this.lbMode = this.lbModeData.mode
    this.forClans = this.lbMode == "ww_clans"
    sendBqEvent("CLIENT_POPUP_1", "ww_leaderboard.select_mode", { select_mode = this.lbMode })

    this.checkLbCategory()

    let callback = Callback(
      function(modesData) {
        this.updateModeDataByAvailableTables(modesData?.modes ?? [])
        this.updateModeComboBoxes(modesData?.tables)
      }, this)

    wwLeaderboardData.requestWwLeaderboardModes(
      this.lbMode,
      @(modesData) callback(modesData))
  }

  function updateModeComboBoxes(seasonDays = null) {
    if (this.isCountriesLeaderboard()) {
      this.lbCountry = null
      this.updateCountriesComboBox()
    }
    this.updateMapsComboBox()
    this.updateDaysComboBox(seasonDays)
  }

  function checkLbCategory() {
    if (!this.curLbCategory || !this.lbModel.checkLbRowVisibility(this.curLbCategory, this))
      this.curLbCategory = u.search(this.lb_presets, (@(row) this.lbModel.checkLbRowVisibility(row, this)).bindenv(this))
  }

  function onDaySelect(obj) {
    let dayObjValue = obj.getValue()
    if (dayObjValue < 0 || dayObjValue >= this.lbDaysList.len())
      return

    this.lbDay = this.lbDaysList[dayObjValue]
    sendBqEvent("CLIENT_POPUP_1", "ww_leaderboard.select_day", { select_day = this.lbDay?.tostring() ?? "all" })

    this.fetchLbData()
  }

  function onMapSelect(obj) {
    let mapObjValue = obj.getValue()
    if (mapObjValue < 0 || mapObjValue >= this.lbMapsList.len())
      return

    this.lbMap = this.lbMapsList[mapObjValue]
    sendBqEvent("CLIENT_POPUP_1", "ww_leaderboard.select_map", { select_map = this.lbMap?.getId() ?? "all" })

    if (!this.isCountriesLeaderboard())
      this.updateCountriesComboBox(this.lbMap)
    else
      this.fetchLbData()
  }

  function onCountrySelect(obj) {
    let countryObjValue = obj.getValue()
    if (countryObjValue < 0 || countryObjValue >= this.lbCountriesList.len())
      return

    this.lbCountry = this.lbCountriesList[countryObjValue]
    sendBqEvent("CLIENT_POPUP_1", "ww_leaderboard.select_country", { select_country = this.lbCountry ?? "all" })

    if (!this.isCountriesLeaderboard())
      this.fetchLbData()
  }

  function onUserDblClick() {
    if (this.isCountriesLeaderboard())
      return

    base.onUserDblClick()
  }

  function getRequestData() {
    if (!this.lbModeData)
      return null

    let mapId = this.lbMap && isInArray(this.lbMap, this.availableMapsList) ? $"__{this.lbMap.getId()}" : ""
    let countryId = this.lbCountry && isInArray(this.lbCountry, this.availableCountriesList)
      ? $"__{this.lbCountry}" : ""

    return {
      modeName = this.lbModeData.mode
      modePostFix = $"{mapId}{countryId}"
      day = this.lbModeData.hasDaysData ? this.lbDay : null
      platformFilter = this.lbModeData?.needShowConsoleFilter ? this.platformFilter : ""
    }
  }

  function getWwMaps() {
    let maps = [null]
    foreach (map in this.availableMapsList)
      maps.append(map)

    return maps
  }

  function getWwCountries(filterMap) {
    let countrries = [null]
    if (filterMap) {
      foreach (country in filterMap.getCountries())
        if (isInArray(country, this.availableCountriesList))
          countrries.append(country)

      return countrries
    }

    let countrriesData = {}
    foreach (map in this.availableMapsList)
      foreach (country in map.getCountries())
        if (!(country in countrriesData) && isInArray(country, this.availableCountriesList))
          countrriesData[country] <- country

    foreach (country in countrriesData)
      countrries.append(country)

    return countrries
  }

  function isUsersLeaderboard() {
    return wwLeaderboardData.isUsersLeaderboard(this.lbModeData)
  }

  function isCountriesLeaderboard() {
    return this.lbMode == "ww_countries"
  }

  function onRewards() {
    let curRewardsBlk = this.getCurModeAwards()
    if (!curRewardsBlk)
      return showInfoMsgBox(loc("leaderboards/has_no_rewards"))

    wwRewards.open({
      isClanRewards = this.forClans
      rewardsBlk = curRewardsBlk
      day       = this.lbDay ? wwLeaderboardData.getDayIdByNumber(this.lbDay) : "season"
      lbMode    = this.lbMode
      lbDay     = this.lbDay
      lbMap     = this.lbMap
      lbCountry = this.lbCountry
    })
  }

  function updateButtons() {
    base.updateButtons()
    this.updateWwRewardsButton()
  }

  function updateWwRewardsButton() {
    let curRewardsBlk = this.getCurModeAwards()
    let rewardsBtn = showObjById("btn_ww_rewards", true, this.scene)
    rewardsBtn.inactiveColor = curRewardsBlk ? "no" : "yes"
  }

  function getCurModeAwards() {
    let rewardTableName = wwLeaderboardData.getModeByName(this.lbMode)?.rewardsTableName
    if (!rewardTableName || !this.rewardsBlk || !this.requestData)
      return null

    let day = this.lbDay ? wwLeaderboardData.getDayIdByNumber(this.lbDay) : "season"
    let awardTableName = $"{this.requestData.modeName}{this.requestData.modePostFix}"

    return this.rewardsBlk?[rewardTableName]?[day]?.awards?[awardTableName]
  }

  function updateModeDataByAvailableTables(modes) {
    this.availableMapsList = this.getAvailableMapsList(modes)
    this.availableCountriesList = this.getAvailableCountriesList(modes)
  }

  function getAvailableMapsList(modes) {
    let mode = this.lbMode
    let maps = []
    foreach (map in this.wwMapsList)
      if (u.search(modes, @(m) m.split(mode)?[1] && m.split(map.name)?[1]) != null)
        maps.append(map)

    return maps
  }

  function getAvailableCountriesList(modes) {
    let countries = []
    foreach (mode in modes)
      if (mode.split(this.lbMode)?[1] != null) {
        let cName = mode.split("__country")?[1]
        let country = cName == null ? cName : $"{"country"}{cName}"
        if (country != null && !isInArray(country, countries))
          countries.append(country)
      }

    return countries
  }

  function updateClanTagRowsData(clansInfoList) {
    if (clansInfoList.len() == 0)
      return

    let clansInfo = clansInfoList
    function updateClanTag(row) {
      row.__update({
        clanTag = clansInfo?[row?.clanId.tostring() ?? ""].tag ?? row?.clanTag ?? ""
      })
    }
    (this.selfRowData ?? []).map(updateClanTag)
    this.pageData?.rows.map(updateClanTag)
  }

  function onEventUpdateClansInfoList(p) {
    if (this.lbMode != "ww_users_manager")
      return

    let clansInfoList = p?.clansInfoList ?? {}
    this.updateClanTagRowsData(clansInfoList)
    addClanTagToNameInLeaderbord(this.scene.findObject("lb_table_nest"), clansInfoList)
  }
}
