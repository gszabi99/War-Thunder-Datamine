import "%scripts/penitentiary/antiCheat.nut" as antiCheat
import "%scripts/queue/queueTypeBit.nut" as QUEUE_TYPE_BIT
import "%scripts/captcha/captchaHandler.nut" as tryOpenCaptchaHandler
import "%sqstd/math.nut" as stdMath
from "%scripts/squads/squadManager.nut" import g_squad_manager
from "%scripts/events/eventsManager.nut" import events
from "%scripts/tutorials/tutorialsData.nut" import checkDiffTutorial
from "%scripts/penitentiary/soundMods.nut" import showMsgboxIfSoundModsNotAllowed
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/events/eventInfo.nut" import getEventEconomicName, checkEventFeaturePacks, isEventForNewbies, canJoinWithoutRequireCrafts, isEventAllowedByPackage
from "%scripts/user/antiAddictSystem.nut" import checkShowMultiplayerAasWarningMsg
from "%scripts/myStats.nut" import isMeNewbieOnUnitType
from "%scripts/user/myStatsState.nut" import getUnitTypeByNewbieEventId
from "%scripts/matchingRooms/sessionLobbyActions.nut" import joinSessionRoom
from "%scripts/queue/queueManager.nut" import checkQueueAndStart, joinQueue
from "%scripts/instantAction.nut" import checkBrokenAirsAndDo
from "%scripts/queue/queueState.nut" import isAnyQueuesActive
from "%scripts/clientState/contentPacks.nut" import checkPackageAndAskDownload, checkPackageAndAskDownloadByTimes
from "%scripts/squads/squadUtils.nut" import isEventAllowedForAllSquadMembers, canJoinFlightMsgBox
from "%scripts/unit/unitInfo.nut" import isLoadedModelHighQuality
from "%scripts/options/systemOptions.nut" import disableVrModeValue
from "dagor.time" import get_time_msec
from "%scripts/dagui_library.nut" import *
from "%globalScripts/difficultyConsts.nut" import *

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
        !checkPackageAndAskDownload(["pkg_main"]))
      return this.remove()

    if (!isEventAllowedByPackage(this.event)) {
      
      checkPackageAndAskDownload(this.event.reqPacks, null,
        this.joinStep3_afterPacks, this, Callback(this.remove, this))
      return
    }

    this.joinStep3_afterPacks()
  }

  function joinStep3_afterPacks() {
    this.processStepName = "joinStep3_afterPacks"
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
      checkPackageAndAskDownloadByTimes("pkg_main", this.joinStep4_internal, this, this.remove, true)
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

    if (!events.isEventAllowedByVrMode(this.event)) {
      let onDisable = Callback(this.joinStep5_cantJoinReason, this)
      let onCancel = Callback(this.remove, this)
      this.msgBox("suggestion_to_disable_vr_mode", loc("events/noVrMode/msg"),
        [
          ["cancel", onCancel ],
          ["disable", function() {
            disableVrModeValue()
            onDisable()
          }]
        ], "disable")
      return
    }

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
    if (canJoinWithoutRequireCrafts(this.event)) {
      this.joinStep7_membersForQueue()
      return
    }
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


return freeze({
  hasAlredyActiveJoinProcess
  EventJoinProcess
})