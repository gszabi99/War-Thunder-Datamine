let stdMath = require("%sqstd/math.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { checkDiffTutorial } = require("%scripts/tutorials/tutorialsData.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")

::EventJoinProcess <- class
{
  event = null // Event to join.
  room = null
  onComplete = null
  cancelFunc = null

  static PROCESS_TIME_OUT = 60000

  static activeEventJoinProcess = []   //cant modify staic self
  processStartTime = -1

  constructor (v_event, v_room = null, v_onComplete = null, v_cancelFunc = null)
  {
    if (!v_event)
      return

    if (activeEventJoinProcess.len())
      if (::dagor.getCurTime() - activeEventJoinProcess[0].processStartTime < PROCESS_TIME_OUT)
        return ::dagor.assertf(false, "Error: trying to use 2 join event processes at once")
      else
        activeEventJoinProcess[0].remove()

    activeEventJoinProcess.append(this)
    processStartTime = ::dagor.getCurTime()

    event = v_event
    room = v_room
    onComplete = v_onComplete
    cancelFunc = v_cancelFunc
    joinStep1_squadMember()
  }

  function remove(needCancelFunc = true)
  {
    foreach(idx, process in activeEventJoinProcess)
      if (process == this)
        activeEventJoinProcess.remove(idx)

    if (needCancelFunc && cancelFunc != null)
      cancelFunc()
  }

  function onDone()
  {
    if (onComplete != null)
      onComplete(event)
    remove(false)
  }

  function joinStep1_squadMember()
  {
    if (::g_squad_manager.isSquadMember())
    {
      //Don't allow to change ready status, leader don't know about members balance
      if (!::events.haveEventAccessByCost(event))
        ::showInfoMsgBox(::loc("events/notEnoughMoney"))
      else if (::events.eventRequiresTicket(event) && ::events.getEventActiveTicket(event) == null)
        ::events.checkAndBuyTicket(event)
      else
        ::g_squad_manager.setReadyFlag()
      return remove()
    }
    if (!antiCheat.showMsgboxIfEacInactive(event)||
        !showMsgboxIfSoundModsNotAllowed(event))
      return remove()
    // Same as checkedNewFlight in gui_handlers.BaseGuiHandlerWT.
    ::queues.checkAndStart(
                    ::Callback(joinStep2_external, this),
                    ::Callback(remove, this),
                    "isCanNewflight",
                    { isSilentLeaveQueue = !!room }
                   )
  }

  function joinStep2_external()
  {
    if (::events.getEventDiffCode(event) == ::DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return remove()

    if (!::events.checkEventFeature(event))
      return remove()

    if (!::events.isEventAllowedByComaptibilityMode(event))
    {
      ::showInfoMsgBox(::loc("events/noCompatibilityMode/msg"))
      remove()
      return
    }

    if (!::g_squad_utils.isEventAllowedForAllMembers(::events.getEventEconomicName(event)))
      return remove()

    if (!::events.checkEventFeaturePacks(event))
      return remove()

    if (!::is_loaded_model_high_quality())
    {
      ::check_package_and_ask_download("pkg_main", null, joinStep3_internal, this, "event", remove)
      return
    }

    joinStep3_internal()
  }

  function joinStep3_internal()
  {
    let mGameMode = ::events.getMGameMode(event, room)
    if (::events.isEventTanksCompatible(event.name) && !::check_tanks_available())
      return remove()
    if (::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.EVENT) ||
        !::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true, showOfflineSquadMembersPopup = true }))
      return remove()
    if (::events.checkEventDisableSquads(this, event.name))
      return remove()
    if (!checkEventTeamSize(mGameMode))
      return remove()
    let diffCode = ::events.getEventDiffCode(event)
    let unitTypeMask = ::events.getEventUnitTypesMask(event)
    let checkTutorUnitType = (stdMath.number_of_set_bits(unitTypeMask)==1) ? stdMath.number_of_set_bits(unitTypeMask - 1) : null
    if(checkDiffTutorial(diffCode, checkTutorUnitType))
      return remove()

    joinStep4_cantJoinReason()
  }

  function joinStep4_cantJoinReason()
  {
    let reasonData = ::events.getCantJoinReasonData(event, room,
                          { continueFunc = function() { if (this) joinStep5_repairInfo() }.bindenv(this)
                            isFullText = true
                          })
    if (reasonData.checkStatus)
      return joinStep5_repairInfo()

    reasonData.actionFunc(reasonData)
    remove()
  }

  function joinStep5_repairInfo()
  {
    let repairInfo = ::events.getCountryRepairInfo(event, room, ::get_profile_country_sq())
    ::checkBrokenAirsAndDo(repairInfo, this, joinStep6_membersForQueue, false, remove)
  }

  function joinStep6_membersForQueue()
  {
    ::events.checkMembersForQueue(event, room,
      ::Callback(@(membersData) joinStep7_joinQueue(membersData), this),
      ::Callback(remove, this)
    )
  }

  function joinStep7_joinQueue(membersData = null)
  {
    //join room
    if (room)
      ::SessionLobby.joinRoom(room.roomId)
    else
    {
      let joinEventParams = {
        mode    = event.name
        //team    = team //!!can choose team correct only with multiEvents support
        country = ::get_profile_country_sq()
      }
      if (membersData)
        joinEventParams.members <- membersData
      ::queues.joinQueue(joinEventParams)
    }

    onDone()
  }

  //
  // Helpers
  //

  function checkEventTeamSize(ev)
  {
    let squadSize = ::g_squad_manager.getSquadSize()
    let maxTeamSize = ::events.getMaxTeamSize(ev)
    if (squadSize > maxTeamSize)
    {
      let locParams = {
        squadSize = squadSize.tostring()
        maxTeamSize = maxTeamSize.tostring()
      }
      this.msgBox("squad_is_too_big", ::loc("events/squad_is_too_big", locParams),
        [["ok", function() {}]], "ok")
      return false
    }
    return true
  }

  //
  // Delegates from current base gui handler.
  //

  function msgBox(id, text, buttons, def_btn, options = {})
  {
    ::scene_msg_box(id, null, text, buttons, def_btn, options)
  }
}
