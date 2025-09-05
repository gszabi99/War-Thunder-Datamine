from "%scripts/dagui_natives.nut" import clan_can_register_to_ww, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { getMyClanOperation, isMyClanInQueue
} = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { actionWithGlobalStatusRequest,
  getGlobalStatusData } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let DataBlock  = require("DataBlock")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getWwSetting } = require("%scripts/worldWar/worldWarStates.nut")
let { getMyClanType } = require("%scripts/clans/clanTextInfo.nut")
let { hasRightsToQueueWWar } = require("%scripts/clans/clanInfo.nut")

let WwQueue = class {
  map = null
  data = null

  myClanCountries = null
  myClanQueueTime = -1
  cachedClanId = -1 

  constructor(v_map, v_data = null) {
    this.map = v_map
    this.data = v_data
  }

  function isMapActive() {
    return this.map.isActive() || this.map.getOpGroup().hasActiveOperations()
  }

  function getArmyGroupsByCountry(country, defValue = null) {
    return getTblValue(country, this.data, defValue)
  }

  function isMyClanJoined(country = null) {
    let countries = this.getMyClanCountries()
    return country ? isInArray(country, countries) : countries.len() != 0
  }

  function getMyClanCountries() {
    this.gatherMyClanDataOnce()
    return this.myClanCountries ?? []
  }

  function getMyClanQueueJoinTime() {
    this.gatherMyClanDataOnce()
    return max(0, this.myClanQueueTime)
  }

  function resetCache() {
    this.myClanCountries = null
    this.myClanQueueTime = -1
    this.cachedClanId = -1
  }

  function gatherMyClanDataOnce() {
    let myClanId = clan_get_my_clan_id().tointeger()
    if (myClanId == this.cachedClanId)
      return

    this.cachedClanId = myClanId
    if (!this.data)
      return

    this.myClanCountries = []
    foreach (country in shopCountriesList) {
      let groups = this.getArmyGroupsByCountry(country)
      let myGroup = groups && u.search(groups, @(ag) getTblValue("clanId", ag) == myClanId)
      if (myGroup) {
        this.myClanCountries.append(country)
        this.myClanQueueTime = max(this.myClanQueueTime, getTblValue("at", myGroup, -1))
      }
    }

    if (!this.myClanCountries.len()) {
      this.myClanCountries = null
      this.myClanQueueTime = -1
    }
  }

  function getArmyGroupsAmountByCountries() {
    let res = {}
    foreach (country in shopCountriesList) {
      let groups = this.getArmyGroupsByCountry(country)
      res[country] <- groups ? groups.len() : 0
    }
    return res
  }

  function getClansNumberInQueueText() {
    let clansInQueue = {}
    foreach (country in shopCountriesList) {
      let groups = this.getArmyGroupsByCountry(country)
      if (groups)
        foreach (memberData in groups)
          clansInQueue[memberData.clanId] <- true
    }
    let clansInQueueNumber = clansInQueue.len()
    return !clansInQueueNumber ? "" :
      loc("worldwar/clansInQueueTotal", { number = clansInQueueNumber })
  }

  function getArmyGroupsAmountTotal() {
    local res = 0
    foreach (country in shopCountriesList) {
      let groups = this.getArmyGroupsByCountry(country)
      if (groups)
        res += groups.len()
    }
    return res
  }

  function getNameText() {
    return this.map.getNameText()
  }

  function getGeoCoordsText() {
    return  this.map.getGeoCoordsText()
  }

  function getCountriesByTeams() {
    return this.map.getCountriesByTeams()
  }

  function getCantJoinQueueReasonData(country = null) {
    let res = this.getCantJoinAnyQueuesReasonData()
    if (! res.canJoin)
      return res

    res.canJoin = false

    if (country && !this.map.canJoinByCountry(country))
      res.reasonText = loc("worldWar/chooseAvailableCountry")
    else
      res.canJoin = true

    return res
  }

  static function getCantJoinAnyQueuesReasonData() {
    let res = {
      canJoin = false
      reasonText = ""
      hasRestrictClanRegister = false
    }

    if (getMyClanOperation())
      res.reasonText = loc("worldwar/squadronAlreadyInOperation")
    else if (isMyClanInQueue())
      res.reasonText = loc("worldwar/mapStatus/yourClanInQueue")
    else if (!hasRightsToQueueWWar())
      res.reasonText = loc("worldWar/onlyLeaderCanQueue")
    else {
      let myClanType = getMyClanType()
      if (!clan_can_register_to_ww()) {
        res.reasonText = loc("clan/wwar/lacksMembers", {
          clanType = myClanType.getTypeNameLoc()
          count = myClanType.getMinMemberCountToWWar()
          minRankRequired = get_roman_numeral(getWwSetting("minCraftRank", 0))
        })
        res.hasRestrictClanRegister = true
      }
      else
        res.canJoin = true
    }

    return res
  }

  function joinQueue(country, isSilence = true, clusters = null) {
    let cantJoinReason = this.getCantJoinQueueReasonData(country)
    if (!cantJoinReason.canJoin) {
      if (!isSilence)
        showInfoMsgBox(cantJoinReason.reasonText)
      return false
    }

    return this._joinQueue(country, clusters)
  }

  function _joinQueue(country, clusters = null) {
    let requestBlk = DataBlock()
    requestBlk.mapName = this.map.name
    requestBlk.country = country
    requestBlk.clusters = clusters
    if (checkBalanceMsgBox(Cost(getGlobalStatusData()?.operationCreationFeeWp ?? 0)))
      actionWithGlobalStatusRequest("cln_clan_register_ww_army_group", requestBlk,
        { showProgressBox = true })

  }

  function getCantLeaveQueueReasonData() {
    let res = {
      canLeave = false
      reasonText = ""
    }

    if (!hasRightsToQueueWWar())
      res.reasonText = loc("worldWar/onlyLeaderCanQueue")
    else if (!this.isMyClanJoined())
      res.reasonText = loc("matching/SERVER_ERROR_NOT_IN_QUEUE")
    else
      res.canLeave = true

    return res
  }

  function leaveQueue(isSilence = true) {
    let cantLeaveReason = this.getCantLeaveQueueReasonData()
    if (!cantLeaveReason.canLeave) {
      if (!isSilence)
        showInfoMsgBox(cantLeaveReason.reasonText)
      return false
    }

    return this._leaveQueue()
  }

  function _leaveQueue() {
    let requestBlk = DataBlock()
    requestBlk.mapName = this.map.name
    actionWithGlobalStatusRequest("cln_clan_unregister_ww_army_group", requestBlk, { showProgressBox = true })
  }

  function getMapChangeStateTimeText() {
    return this.map.getMapChangeStateTimeText()
  }

  function getMinClansCondition() {
    return this.map.getMinClansCondition()
  }

  function getClansConditionText() {
    return this.map.getClansConditionText()
  }

  getId = @() this.map.getId()
}

return WwQueue