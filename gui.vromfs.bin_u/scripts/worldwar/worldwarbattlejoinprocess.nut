import "%scripts/queue/queueTypeBit.nut" as QUEUE_TYPE_BIT
from "%scripts/instantAction.nut" import checkBrokenAirsAndDo
from "%scripts/unit/brokenAirsInfo.nut" import getBrokenAirsInfo
from "%scripts/queue/queueState.nut" import isAnyQueuesActive
from "%scripts/queue/queueManager.nut" import joinQueue, checkQueueAndStart
from "%scripts/clientState/contentPacks.nut" import checkPackageAndAskDownloadByTimes
from "%scripts/squads/squadUtils.nut" import canJoinFlightMsgBox
from "%scripts/unit/unitInfo.nut" import isLoadedModelHighQuality
from "dagor.time" import get_time_msec
from "worldwar" import wwGetOperationId
from "%globalScripts/wwNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let WwBattleJoinProcess = class {
  wwBattle = null
  side = SIDE_NONE

  static PROCESS_TIME_OUT = 60000

  static activeJoinProcesses = []   
  processStartTime = -1

  constructor (v_wwBattle, v_side) {
    if (!v_wwBattle || !v_wwBattle.isValid())
      return

    if (this.activeJoinProcesses.len())
      if (get_time_msec() - this.activeJoinProcesses[0].processStartTime < this.PROCESS_TIME_OUT)
        return assert(false, "Error: trying to use 2 join world war operation battle processes at once")
      else
        this.activeJoinProcesses[0].remove()

    this.activeJoinProcesses.append(this)
    this.processStartTime = get_time_msec()

    this.wwBattle = v_wwBattle
    this.side = v_side
    this.joinStep1_squad()
  }

  function remove() {
    let ajp = this.activeJoinProcesses
    let l = ajp.len()
    for (local idx=l-1; idx>=0; --idx) {
      if (ajp[idx] == this)
        ajp.remove(idx)
    }
  }

  function onDone() {
    this.remove()
  }

  function joinStep1_squad() {
    if (!canJoinFlightMsgBox(
          {
            isLeaderCanJoin = true,
            showOfflineSquadMembersPopup = true
          }
        )
      )
      return this.remove()

    this.joinStep2_external()
  }

  function joinStep2_external() {
    if (!isLoadedModelHighQuality()) {
      checkPackageAndAskDownloadByTimes("pkg_main", this.joinStep3_internal, this, this.remove, true)
      return
    }

    this.joinStep3_internal()
  }

  function joinStep3_internal() {
    if (isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE))
      return this.remove()

    checkQueueAndStart(
      Callback(this.joinStep4_repairInfo, this),
      Callback(this.remove, this),
      "isCanNewflight"
    )
  }

  function joinStep4_repairInfo() {
    if (this.wwBattle.isBattleByUnitsGroup())
      return this.joinStep5_paramsForQueue()

    let team = this.wwBattle.getTeamBySide(this.side)
    let battleUnits = this.wwBattle.getTeamRemainUnits(team)
    let requiredUnits = this.wwBattle.getUnitsRequiredForJoin(team, this.side)
    let repairInfo = getBrokenAirsInfo([team.country], true,
      @(unit) unit.name in battleUnits || unit.name in requiredUnits)

    if (!requiredUnits)
      repairInfo.canFlyout = true
    checkBrokenAirsAndDo(repairInfo, this, this.joinStep5_paramsForQueue, false, this.remove)
  }

  function joinStep5_paramsForQueue() {
    joinQueue({
      operationId = wwGetOperationId()
      battleId = this.wwBattle.id
      wwBattle = this.wwBattle
      side = this.side
    })
    this.onDone()
  }
}
return { WwBattleJoinProcess }