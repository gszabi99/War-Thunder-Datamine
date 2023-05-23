//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { fabs } = require("math")
let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { getQueueByMapName, getOperationGroupByMapId
} = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { refreshGlobalStatusData } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

let WwMap = class {
  name = ""
  data = null

  constructor(v_name, v_data) {
    this.data = v_data
    this.name = v_name
  }

  function _tostring() {
    return "WwMap(" + this.name + ", " + toString(this.data) + ")"
  }

  function getId() {
    return this.name
  }

  function isEqual(map) {
    return map != null && map.name == this.name
  }

  function isVisible() {
    return (this.getChapterId() != "" || hasFeature("worldWarShowTestMaps"))
  }

  function getChapterId() {
    return getTblValue("operationChapter", this.data, "")
  }

  function getChapterText() {
    let chapterId = this.getChapterId()
    return loc(chapterId != "" ? ("ww_operation_chapter/" + chapterId) : "chapters/test")
  }

  function isDebugChapter() {
    return this.getChapterId() == ""
  }

  function getNameText() {
    return loc(this.getNameLocId())
  }

  static function getNameTextByMapName(mapName) {
    return loc("worldWar/map/" + mapName)
  }

  function getNameLocId() {
    return "worldWar/map/" + this.name
  }

  function getImage() {
    let mapImageName = this.data?.info.image
    if (u.isEmpty(mapImageName))
      return ""

    return "@" + mapImageName + "*"
  }

  function getDescription(needShowGroupInfo = true) {
    let baseDesc = loc("worldWar/map/" + this.name + "/desc", "")
    if (!needShowGroupInfo)
      return baseDesc

    let txtList = []
    if (this.getOpGroup().isMyClanParticipate())
      txtList.append(colorize("userlogColoredText", loc("worldwar/yourClanInOperationHere")))
    txtList.append(baseDesc)
    return "\n".join(txtList, true)
  }

  function getGeoCoordsText() {
    let latitude  = getTblValue("worldMapLatitude", this.data, 0.0)
    let longitude = getTblValue("worldMapLongitude", this.data, 0.0)

    let ud = loc("measureUnits/deg")
    let um = loc("measureUnits/degMinutes")
    let us = loc("measureUnits/degSeconds")

    let cfg = [
      { deg = fabs(latitude),  hem = latitude  >= 0 ? "N" : "S" }
      { deg = fabs(longitude), hem = longitude >= 0 ? "E" : "W" }
    ]

    let coords = []
    foreach (c in cfg) {
      let d  = c.deg.tointeger()
      let t = (c.deg - d) * 60
      let m  = t.tointeger()
      let s = (t - m) * 60
      coords.append(format("%d%s%02d%s%02d%s%s", d, ud, m, um, s, us, c.hem))
    }
    return loc("ui/comma").join(coords, true)
  }

  function isActive() {
    let active = this.data?.active ?? false
    let changeStateTime = this.getChangeStateTime()
    let timeLeft = changeStateTime - ::get_charserver_time_sec()
    if (active && (changeStateTime == -1 || timeLeft > 0))
      return true

    return !active && timeLeft <= 0 && changeStateTime != -1
  }

  function getChangeStateTimeText() {
    let changeStateTime = this.getChangeStateTime() - ::get_charserver_time_sec()
    return changeStateTime > 0
      ? time.hoursToString(time.secondsToHours(changeStateTime), false, true)
      : ""
  }

  function getChangeStateTime() {
    return this.data?.changeStateTime ?? -1
  }

  function getMapChangeStateTimeText() {
    let changeStateTimeStamp = this.getChangeStateTime()
    local text = ""
    if (changeStateTimeStamp >= 0) {
      let secToChangeState = changeStateTimeStamp - ::get_charserver_time_sec()
      if (secToChangeState > 0) {
        let changeStateLocId = "worldwar/operation/" +
          (this.isActive() ? "beUnavailableIn" : "beAvailableIn")
        let changeStateTime = time.hoursToString(
          time.secondsToHours(secToChangeState), false, true)
        text = loc(changeStateLocId, { time = changeStateTime })
      }
      else if (secToChangeState < 0)
        refreshGlobalStatusData()
    }
    else if (!this.isActive())
      text = loc("worldwar/operation/unavailable")

    return text
  }

  function hasValidStatus() {
    let changeStateTimeStamp = this.getChangeStateTime()
    return changeStateTimeStamp == -1
      || (changeStateTimeStamp - ::get_charserver_time_sec()) > 0
  }

  function isWillAvailable(isNearFuture = true) {
    let changeStateTime = this.getChangeStateTime() - ::get_charserver_time_sec()
    let operationAnnounceTimeSec = ::g_world_war.getSetting("operationAnnounceTimeSec",
      time.TIME_DAY_IN_SECONDS)
    return !this.isActive()
      && changeStateTime > 0
      && (!isNearFuture || changeStateTime < operationAnnounceTimeSec)
  }

  function isAnnounceAndNotDebug(isNearFuture = true) {
    return (this.isActive() || this.isWillAvailable(isNearFuture)) && !this.isDebugChapter()
  }

  function getCountryToSideTbl() {
    return this.data?.info.countries ?? {}
  }

  function getUnitInfoBySide(side) {
    return this.data?.info.sides["SIDE_{0}".subst(side)].units
  }

  function getUnitsViewBySide(side) {
    let unitsGroupsByCountry = this.getUnitsGroupsByCountry()
    local unitsList = this.getUnitInfoBySide(side)
    local wwUnitsList = []
    if (u.isEmpty(unitsList))
      return wwUnitsList

    unitsList = u.filter(wwActionsWithUnitsList.loadUnitsFromNameCountTbl(unitsList),
      @(unit) !unit.isControlledByAI())
    unitsList.sort(::g_world_war.sortUnitsBySortCodeAndCount)
    if (unitsGroupsByCountry != null) {
      foreach (wwUnit in unitsList) {
        let country = wwUnit?.unit.shopCountry
        let group = unitsGroupsByCountry?[country].groups[wwUnit.name]
        if (group == null)
          continue

        let defaultUnit = group.defaultUnit
        wwUnitsList.append({
          name         = loc(group.name)
          icon         = ::getUnitClassIco(defaultUnit)
          shopItemType = getUnitRole(defaultUnit)
        })

        local wwUnits = wwActionsWithUnitsList.loadWWUnitsFromUnitsArray(group.units)
        wwUnits.sort(@(a, b) a.name <=> b.name)
        wwUnitsList.extend(wwUnits.map(@(unit)
          unit.getShortStringView({ addPreset = false, needShopInfo = true, hasIndent = true })))
      }
    }
    else
      wwUnitsList = u.map(unitsList, @(wwUnit)
        wwUnit.getShortStringView({ addPreset = false, needShopInfo = true }))

    return wwUnitsList
  }

  _cachedCountriesByTeams = null
  function getCountriesByTeams() {
    if (this._cachedCountriesByTeams)
      return this._cachedCountriesByTeams

    this._cachedCountriesByTeams = {}
    let countries = this.getCountryToSideTbl()
    foreach (c in shopCountriesList) {
      let side = getTblValue(c, countries, SIDE_NONE)
      if (side == SIDE_NONE)
        continue

      if (!(side in this._cachedCountriesByTeams))
        this._cachedCountriesByTeams[side] <- []
      this._cachedCountriesByTeams[side].append(c)
    }

    return this._cachedCountriesByTeams
  }

  function getCountries() {
    let res = []
    foreach (cList in this.getCountriesByTeams())
      res.extend(cList)
    return res
  }

  function canJoinByCountry(country) {
    let countriesByTeams = this.getCountriesByTeams()
    foreach (cList in countriesByTeams)
      if (isInArray(country, cList))
        return true
    return false
  }

  function getQueue() {
    return getQueueByMapName(this.name)
  }

  function getOpGroup() {
    return getOperationGroupByMapId(this.name)
  }

  function getCountriesViewBySide(side, hasBigCountryIcon = true) {
    let countries = this.getCountryToSideTbl()
    let countryNames = u.keys(countries)
    let mapName = this.name
    let iconType = hasBigCountryIcon ? "small_country" : "country_battle"
    return "".join(countryNames
      .filter(@(country) countries[country] == side)
      .map(@(country, idx) "img { iconType:t='{type}'; background-image:t='{countryIcon}'; {margin} }".subst({
        countryIcon = getCustomViewCountryData(country, mapName).icon
        margin = idx > 0 ? "margin-left:t='@blockInterval'" : ""
        type = iconType
      }))
    )
  }

  function getMinClansCondition() {
    return getTblValue("minClanCount", this.data, 0)
  }

  function getClansConditionText(isSideInfo = false) {
    let minNumb = this.getMinClansCondition()
    let maxNumb = getTblValue("maxClanCount", this.data, 0)
    local prefix = isSideInfo ? "side_" : ""
    return minNumb == maxNumb ?
      loc("worldwar/operation/" + prefix + "clans_number", { numb = maxNumb }) :
      loc("worldwar/operation/" + prefix + "clans_limits", { min = minNumb, max = maxNumb })
  }

  function getClansNumberInQueueText() {
    return ""
  }

  function getBackground() {
    // it is assumed that each map will have its background specified in data
    return this.data?.backgroundImage ?? "#ui/images/worldwar_window_bg_image?P1"
  }

  _cachedUnitsGroupsByCountry = null
  function getUnitsGroupsByCountry() {
    if (this._cachedUnitsGroupsByCountry != null)
      return this._cachedUnitsGroupsByCountry

    let countriesBlk = ::g_world_war.getSetting("unitGroups", null)?[this.name]
    if (countriesBlk == null)
      return null

    let groupsList = {}
    for (local i = 0; i < countriesBlk.blockCount(); i++) {
      let countryBlk = countriesBlk.getBlock(i)
      let countryId = countryBlk.getBlockName()
      let countryGroups = {}
      let groupIdByUnitName = {}
      let defaultUnitsList = {}
      for (local j = 0; j < countryBlk.blockCount(); j++) {
        let groupBlk = countryBlk.getBlock(j)
        let groupId = groupBlk.getBlockName()
        let units = {}
        foreach (unitName in groupBlk.unitList % "unit") {
          units[unitName] <- getAircraftByName(unitName)
          groupIdByUnitName[unitName] <- groupId
        }
        let defaultUnit = getAircraftByName(groupBlk.defaultUnit)
        defaultUnitsList[groupId] <- defaultUnit
        countryGroups[groupId] <- {
          id = groupId
          name = groupBlk.name
          defaultUnit = defaultUnit
          units = units
        }
      }
      groupsList[countryId] <- {
        groups = countryGroups
        defaultUnitsListByGroups = defaultUnitsList
        groupIdByUnitName = groupIdByUnitName
      }
    }

    this._cachedUnitsGroupsByCountry = groupsList
    return this._cachedUnitsGroupsByCountry
  }

  function isClanQueueAvaliable() {
    let reasonData = ::WwQueue.getCantJoinAnyQueuesReasonData()
    return hasFeature("WorldWarClansQueue") &&
           hasFeature("Clans") &&
           ::is_in_clan() && this.isActive() &&
           (reasonData.canJoin || reasonData.hasRestrictClanRegister)
  }
}

return { WwMap }