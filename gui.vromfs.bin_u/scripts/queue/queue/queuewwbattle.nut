from "%scripts/dagui_library.nut" import *

let { request_matching } = require("%scripts/matching/api.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { defaultDiffCode } = require("%scripts/globalWorldwarUtils.nut")
let BaseQueue = require("%scripts/queue/queue/queueBase.nut")
let { registerQueueClass } = require("%scripts/queue/queue/queueClasses.nut")
let { getSquadMembersFlyoutDataByUnitsGroups } = require("%scripts/squads/squadUtils.nut")

let WwBattle = class (BaseQueue) {
  function init() {
    this.name = this.getName(this.params)
  }

  function join(successCallback, errorCallback) {
    request_matching(
      "worldwar.join_battle",
      successCallback,
      errorCallback,
      this.getQueryParams()
    )
  }

  function leave(successCallback, errorCallback, needShowError = false) {
    this.leaveAll(successCallback, errorCallback, needShowError)
  }

  static function leaveAll(successCallback, errorCallback, needShowError = false) {
    request_matching(
      "worldwar.leave_battle",
      successCallback,
      errorCallback,
      null,
      { showError = needShowError }
    )
  }

  static function getName(params) {
    return "".concat(getTblValue("operationId", params, ""), "_", getTblValue("battleId", params, ""))
  }

  function getBattleName() {
    return loc("mainmenu/btnWorldwar")
  }

  function getQueueWwBattleId() {
    return this.params?.battleId ?? ""
  }

  getQueueWwOperationId = @() this.params?.operationId ?? -1

  function getQueryParams() {
    let qp = {
      clusters     = this.params.clusters
      operationId  = this.params.operationId
      battleId     = this.params.battleId
      country      = this.params.country
      team         = this.params.team
    }

    if (!(this.params?.isBattleByUnitsGroup ?? false))
      return qp

    let queueMembersParams = g_squad_manager.isSquadLeader()
      ? getSquadMembersFlyoutDataByUnitsGroups()
      : {
        [userIdStr.get()] = { crafts_info = slotbarPresets.getCurCraftsInfo() }
      }

    foreach (member in queueMembersParams) {
      member.crafts_info = this.createCraftsInfoConfig(member.crafts_info)
    }

    return qp.__merge({ players = queueMembersParams })
  }

  function createCraftsInfoConfig(craftsInfo) {
    let res = []
    foreach (idx, unitName in craftsInfo) {
      let unit = getAircraftByName(unitName)
      if (unit == null)
        continue

      res.append({
        name       = unitName
        slot       = idx
        type       = unit.expClass.expClassName
        mrank      = unit.getEconomicRank(defaultDiffCode)
        rank       = unit?.rank ?? -1
      })
    }
    return res
  }
}

registerQueueClass("WwBattle", WwBattle)
