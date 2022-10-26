from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { checkDiffTutorial } = require("%scripts/tutorials/tutorialsData.nut")
let { get_time_msec } = require("dagor.time")

::WwBattleJoinProcess <- class
{
  wwBattle = null
  side = SIDE_NONE

  static PROCESS_TIME_OUT = 60000

  static activeJoinProcesses = []   //cant modify staic self
  processStartTime = -1

  constructor (v_wwBattle, v_side)
  {
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

  function remove()
  {
    foreach(idx, process in this.activeJoinProcesses)
      if (process == this)
        this.activeJoinProcesses.remove(idx)
  }

  function onDone()
  {
    this.remove()
  }

  function joinStep1_squad()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox(
          {
            isLeaderCanJoin = true,
            showOfflineSquadMembersPopup = true
          }
        )
      )
      return this.remove()

    this.joinStep2_external()
  }

  function joinStep2_external()
  {
    if (!::is_loaded_model_high_quality())
    {
      ::check_package_and_ask_download("pkg_main", null, this.joinStep3_internal, this, "event", this.remove)
      return
    }

    this.joinStep3_internal()
  }

  function joinStep3_internal()
  {
    if (this.wwBattle.isTanksCompatible() && !::check_tanks_available())
      return this.remove()

    if (::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE))
      return this.remove()

    let availableUnitTypes = this.wwBattle.getAvailableUnitTypes()
    if (availableUnitTypes.len() > 0)
    {
      foreach(_idx, unitType in availableUnitTypes)
        if (checkDiffTutorial(DIFFICULTY_REALISTIC, unitType))
          return this.remove()
    }

    ::queues.checkAndStart(
      Callback(this.joinStep4_repairInfo, this),
      Callback(this.remove, this),
      "isCanNewflight"
    )
  }

  function joinStep4_repairInfo()
  {
    if (this.wwBattle.isBattleByUnitsGroup())
      return this.joinStep5_paramsForQueue()

    let team = this.wwBattle.getTeamBySide(this.side)
    let battleUnits = this.wwBattle.getTeamRemainUnits(team)
    let requiredUnits = this.wwBattle.getUnitsRequiredForJoin(team, this.side)
    let repairInfo = ::getBrokenAirsInfo([team.country], true,
      @(unit) unit.name in battleUnits || unit.name in requiredUnits)

    if (!requiredUnits)
      repairInfo.canFlyout = true
    ::checkBrokenAirsAndDo(repairInfo, this, this.joinStep5_paramsForQueue, false, this.remove)
  }

  function joinStep5_paramsForQueue()
  {
    ::queues.joinQueue({
      operationId = ::ww_get_operation_id()
      battleId = this.wwBattle.id
      wwBattle = this.wwBattle
      side = this.side
    })
    this.onDone()
  }
}
