from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let events = getGlobalModule("events")
let { get_time_msec } = require("dagor.time")
let stdMath = require("%sqstd/math.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { checkDiffTutorial } = require("%scripts/tutorials/tutorialsData.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let tryOpenCaptchaHandler = require("%scripts/captcha/captchaHandler.nut")
let { getEventEconomicName, checkEventFeaturePacks, isEventForNewbies
} = require("%scripts/events/eventInfo.nut")
let { checkShowMultiplayerAasWarningMsg } = require("%scripts/user/antiAddictSystem.nut")
let { isMeNewbieOnUnitType } = require("%scripts/myStats.nut")
let { getUnitTypeByNewbieEventId } = require("%scripts/user/myStatsState.nut")
let { joinSessionRoom } = require("%scripts/matchingRooms/sessionLobbyActions.nut")
let { checkQueueAndStart, joinQueue } = require("%scripts/queue/queueManager.nut")
let { checkBrokenAirsAndDo } = require("%scripts/instantAction.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")
let { checkPackageAndAskDownload, checkPackageAndAskDownloadByTimes
} = require("%scripts/clientState/contentPacks.nut")
let { isEventAllowedForAllSquadMembers, canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")
let { isLoadedModelHighQuality } = require("%scripts/unit/unitInfo.nut")

const PROCESS_TIME_OUT = 60000

let activeEventJoinProcess = []

let hasAlredyActiveJoinProcess = @() activeEventJoinProcess.len() > 0
  && (get_time_msec() - activeEventJoinProcess[0].processStartTime) < PROCESS_TIME_OUT

function setSquadReadyFlag(event) {
  
  if (!events.haveEventAccessByCost(event))
    showInfoMsgBox(loc("events/notEnoughMoney"))
  else if (events.eventRequiresTicket(event) && events.getEventActiveTicket(event) == null)
    events.checkAndBuyTicket(event)
  else
    g_squad_manager.setReadyFlag()
}

function canJoinEventForNewbies(event) {
  if (!isEventForNewbies(event))
    return true

  let unitType = getUnitTypeByNewbieEventId(event.name)
  if (isMeNewbieOnUnitType(unitType))
    return true

  showInfoMsgBox(loc("events/notAvailableNewbiesMode/msg"))
  return false
}

let EventJoinProcess = class {
  event = null 
  room = null
  onComplete = null
  cancelFunc = null

  processStartTime = -1
  processStepName = ""

  constructor(v_event, v_room = null, v_onComplete = null, v_cancelFunc = null) {
    if (!v_event)
      return

    this.event = v_event
    this.room = v_room
    this.onComplete = v_onComplete
    this.cancelFunc = v_cancelFunc

    if (activeEventJoinProcess.len()) {
      let prevProcessStartTime = activeEventJoinProcess[0].processStartTime
      if (get_time_msec() - prevProcessStartTime < PROCESS_TIME_OUT) {
        let prevProcessStepName = activeEventJoinProcess[0].processStepName
        return assert(false, $"Error: trying to use 2 join event processes at once /*eventName = {v_event.name}, prevProcessStepName = {prevProcessStepName}*/")
      }
      else
        activeEventJoinProcess[0].remove()
    }
    activeEventJoinProcess.append(this)
    this.processStartTime = get_time_msec()
    this.joinStep1_squadMember()
  }

  function remove(needCancelFunc = true) {
    let l = activeEventJoinProcess.len()
    for (local idx=l-1; idx>=0; --idx) {
      if (activeEventJoinProcess[idx] == this)
        activeEventJoinProcess.remove(idx)
    }

    if (needCancelFunc && this.cancelFunc != null)
      this.cancelFunc()
  }

  function onDone() {
    if (this.onComplete != null)
      this.onComplete(this.event)
    this.remove(false)
  }

  function joinStep1_squadMember() {
    this.processStepName = "joinStep1_squadMember"

    if (g_squad_manager.isSquadMember()) {
      if (!g_squad_manager.isMeReady()) {
        let handler = this
        tryOpenCaptchaHandler(@() setSquadReadyFlag(handler.event))
      }
      else
        setSquadReadyFlag(this.event)
      return this.remove()
    }

    let handler = this
    tryOpenCaptchaHandler(
      @() checkQueueAndStart(
        Callback(handler.joinStep2_multiplayer_restriction, handler),
        Callback(handler.remove, handler),
        "isCanNewflight",
        { isSilentLeaveQueue = !!handler.room }
      ),
      @() handler.remove())
  }

  function joinStep2_multiplayer_restriction() {
    this.processStepName = "joinStep2_multiplayer_restriction"
    if (!antiCheat.showMsgboxIfEacInactive(this.event) ||
        !showMsgboxIfSoundModsNotAllowed(this.event))
      return this.remove()


    checkShowMultiplayerAasWarningMsg(Callback(this.joinStep3_external, this),
      Callback(this.remove, this))
  }

  function joinStep3_external() {
    this.processStepName = "joinStep3_external"
    if (events.getEventDiffCode(this.event) == DIFFICULTY_HARDCORE &&
        !checkPackageAndAskDownload("pkg_main"))
      return this.remove()

    if (!events.isEventAllowedByPackage(this.event)
      && !checkPackageAndAskDownload(this.event.reqPack))
      return this.remove()

    if (!events.checkEventFeature(this.event))
      return this.remove()

    if (!events.isEventAllowedByComaptibilityMode(this.event)) {
      showInfoMsgBox(loc("events/noCompatibilityMode/msg"))
      this.remove()
      return
    }

    if (!isEventAllowedForAllSquadMembers(getEventEconomicName(this.event)))
      return this.remove()

    if (!checkEventFeaturePacks(this.event))
      return this.remove()

    if (!isLoadedModelHighQuality()) {
      checkPackageAndAskDownloadByTimes("pkg_main", this.joinStep4_internal, this, this.remove)
      return
    }

    this.joinStep4_internal()
  }

  function joinStep4_internal() {
    this.processStepName = "joinStep4_internal"
    let mGameMode = events.getMGameMode(this.event, this.room)
    if (isAnyQueuesActive(QUEUE_TYPE_BIT.EVENT) ||
        !canJoinFlightMsgBox({ isLeaderCanJoin = true, showOfflineSquadMembersPopup = true }))
      return this.remove()
    if (events.checkEventDisableSquads(this, this.event.name))
      return this.remove()
    if (!this.checkEventTeamSize(mGameMode))
      return this.remove()
    if (!canJoinEventForNewbies(this.event))
      return this.remove()
    let diffCode = events.getEventDiffCode(this.event)
    let unitTypeMask = events.getEventUnitTypesMask(this.event)
    let checkTutorUnitType = (stdMath.number_of_set_bits(unitTypeMask) == 1) ? stdMath.number_of_set_bits(unitTypeMask - 1) : null
    if (checkDiffTutorial(diffCode, checkTutorUnitType))
      return this.remove()

    this.joinStep5_cantJoinReason()
  }

  function joinStep5_cantJoinReason() {
    this.processStepName = "joinStep5_cantJoinReason"
    let reasonData = events.getCantJoinReasonData(this.event, this.room, { isFullText = true })
    if (reasonData.checkStatus)
      return this.joinStep6_repairInfo()

    reasonData.actionFunc(reasonData)
    this.remove()
  }

  function joinStep6_repairInfo() {
    this.processStepName = "joinStep6_repairInfo"
    let repairInfo = events.getCountryRepairInfo(this.event, this.room, profileCountrySq.get())
    checkBrokenAirsAndDo(repairInfo, this, this.joinStep7_membersForQueue, false, this.remove)
  }

  function joinStep7_membersForQueue() {
    this.processStepName = "joinStep7_membersForQueue"
    events.checkMembersForQueue(this.event, this.room,
      Callback(@(membersData) this.joinStep8_joinQueue(membersData), this),
      Callback(this.remove, this)
    )
  }

  function joinStep8_joinQueue(membersData = null) {
    this.processStepName = "joinStep8_joinQueue"
    
    if (this.room)
      joinSessionRoom(this.room.roomId)
    else {
      let joinEventParams = {
        mode    = this.event.name
        
        country = profileCountrySq.get()
      }
      if (membersData)
        joinEventParams.members <- membersData
      joinQueue(joinEventParams)
    }

    this.onDone()
  }

  
  
  

  function checkEventTeamSize(ev) {
    let squadSize = g_squad_manager.getSquadSize()
    let maxTeamSize = events.getMaxTeamSize(ev)
    if (squadSize > maxTeamSize) {
      let locParams = {
        squadSize = squadSize.tostring()
        maxTeamSize = maxTeamSize.tostring()
      }
      this.msgBox("squad_is_too_big", loc("events/squad_is_too_big", locParams),
        [["ok", function() {}]], "ok")
      return false
    }
    return true
  }

  
  
  

  function msgBox(id, text, buttons, def_btn, options = {}) {
    scene_msg_box(id, null, text, buttons, def_btn, options)
  }
}


return {
  hasAlredyActiveJoinProcess
  EventJoinProcess
}