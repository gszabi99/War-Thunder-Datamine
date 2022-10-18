let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { checkDiffTutorial } = require("%scripts/tutorials/tutorialsData.nut")

::WwBattleJoinProcess <- class
{
  wwBattle = null
  side = ::SIDE_NONE

  static PROCESS_TIME_OUT = 60000

  static activeJoinProcesses = []   //cant modify staic self
  processStartTime = -1

  constructor (v_wwBattle, v_side)
  {
    if (!v_wwBattle || !v_wwBattle.isValid())
      return

    if (activeJoinProcesses.len())
      if (::dagor.getCurTime() - activeJoinProcesses[0].processStartTime < PROCESS_TIME_OUT)
        return ::dagor.assertf(false, "Error: trying to use 2 join world war operation battle processes at once")
      else
        activeJoinProcesses[0].remove()

    activeJoinProcesses.append(this)
    processStartTime = ::dagor.getCurTime()

    wwBattle = v_wwBattle
    side = v_side
    joinStep1_squad()
  }

  function remove()
  {
    foreach(idx, process in activeJoinProcesses)
      if (process == this)
        activeJoinProcesses.remove(idx)
  }

  function onDone()
  {
    remove()
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
      return remove()

    joinStep2_external()
  }

  function joinStep2_external()
  {
    if (!::is_loaded_model_high_quality())
    {
      ::check_package_and_ask_download("pkg_main", null, joinStep3_internal, this, "event", remove)
      return
    }

    joinStep3_internal()
  }

  function joinStep3_internal()
  {
    if (wwBattle.isTanksCompatible() && !::check_tanks_available())
      return remove()

    if (::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE))
      return remove()

    let availableUnitTypes = wwBattle.getAvailableUnitTypes()
    if (availableUnitTypes.len() > 0)
    {
      foreach(idx, unitType in availableUnitTypes)
        if (checkDiffTutorial(::DIFFICULTY_REALISTIC, unitType))
          return remove()
    }

    ::queues.checkAndStart(
      ::Callback(joinStep4_repairInfo, this),
      ::Callback(remove, this),
      "isCanNewflight"
    )
  }

  function joinStep4_repairInfo()
  {
    if (wwBattle.isBattleByUnitsGroup())
      return joinStep5_paramsForQueue()

    let team = wwBattle.getTeamBySide(side)
    let battleUnits = wwBattle.getTeamRemainUnits(team)
    let requiredUnits = wwBattle.getUnitsRequiredForJoin(team, side)
    let repairInfo = ::getBrokenAirsInfo([team.country], true,
      @(unit) unit.name in battleUnits || unit.name in requiredUnits)

    if (!requiredUnits)
      repairInfo.canFlyout = true
    ::checkBrokenAirsAndDo(repairInfo, this, joinStep5_paramsForQueue, false, remove)
  }

  function joinStep5_paramsForQueue()
  {
    ::queues.joinQueue({
      operationId = ::ww_get_operation_id()
      battleId = wwBattle.id
      wwBattle = wwBattle
      side = side
    })
    onDone()
  }
}
