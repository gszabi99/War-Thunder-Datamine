let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")

::queue_classes.WwBattle <- class extends ::queue_classes.Base
{
  function init()
  {
    name = getName(params)
  }

  function join(successCallback, errorCallback)
  {
    ::request_matching(
      "worldwar.join_battle",
      successCallback,
      errorCallback,
      getQueryParams()
    )
  }

  function leave(successCallback, errorCallback, needShowError = false)
  {
    leaveAll(successCallback, errorCallback, needShowError)
  }

  static function leaveAll(successCallback, errorCallback, needShowError = false)
  {
    ::request_matching(
      "worldwar.leave_battle",
      successCallback,
      errorCallback,
      null,
      { showError = needShowError }
    )
  }

  static function getName(params)
  {
    return ::getTblValue("operationId", params, "") + "_" + ::getTblValue("battleId", params, "")
  }

  function getBattleName()
  {
    return ::loc("mainmenu/btnWorldwar")
  }

  function getQueueWwBattleId()
  {
    return params?.battleId ?? ""
  }

  getQueueWwOperationId = @() params?.operationId ?? -1

  function getQueryParams() {
    let qp = {
      clusters     = params.clusters
      operationId  = params.operationId
      battleId     = params.battleId
      country      = params.country
      team         = params.team
    }

    if (!(params?.isBattleByUnitsGroup ?? false))
      return qp

    let queueMembersParams = ::g_squad_manager.isSquadLeader()
      ? ::g_squad_utils.getMembersFlyoutDataByUnitsGroups()
      : {
        [::my_user_id_str] = { crafts_info = slotbarPresets.getCurCraftsInfo() }
      }

    foreach (member in queueMembersParams)
    {
      member.crafts_info = createCraftsInfoConfig(member.crafts_info)
    }

    return qp.__merge({ players = queueMembersParams })
  }

  function createCraftsInfoConfig(craftsInfo) {
    let res = []
    foreach(idx, unitName in craftsInfo)
    {
      let unit = ::getAircraftByName(unitName)
      if (unit == null)
        continue

      res.append({
        name       = unitName
        slot       = idx
        type       = unit.expClass.expClassName
        mrank      = unit.getEconomicRank(::g_world_war.defaultDiffCode)
        rank       = unit?.rank ?? -1
      })
    }
    return res
  }
}
