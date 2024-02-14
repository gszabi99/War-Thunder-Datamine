//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "hudMessages" import *
from "%scripts/hud/hudConsts.nut" import REWARD_PRIORITY, HUD_VIS_PART

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { GO_NONE, GO_FAIL, GO_WIN, GO_EARLY, GO_WAITING_FOR_RESULT, MISSION_CAPTURED_ZONE,
  MISSION_TEAM_LEAD_ZONE
} = require("guiMission")
let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let { get_time_msec } = require("dagor.time")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { get_game_mode, get_game_type } = require("mission")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_HUD_VISIBLE_KILLLOG, USEROPT_HUD_VISIBLE_REWARDS_MSG
} = require("%scripts/options/optionsExtNames.nut")
let { create_ObjMoveToOBj } = require("%sqDagui/guiBhv/bhvAnim.nut")

local heightPID = dagui_propid_add_name_id("height")

::g_hud_messages <- {
  types = []
}
let misResultsMap = {
  [ GO_NONE ] = "",
  [ GO_WIN ] = "MISSION_SUCCESS",
  [ GO_FAIL ] = "MISSION_FAIL",
  [ GO_EARLY ] = "MISSION_IN_PROGRESS",
  [ GO_WAITING_FOR_RESULT ] = "FINALIZING",
}

::g_hud_messages.template <- {
  nestId = ""
  nest = null
  messagesMax = 0
  showSec = 0
  stack = null //[] in constructor
  messageEvent = ""
  hudEvents = null

  scene = null
  guiScene = null
  timers = null

  setScene = function(inScene, inTimers) {
    this.scene = inScene
    this.guiScene = this.scene.getScene()
    this.timers = inTimers
    this.nest = this.scene.findObject(this.nestId)
  }
  reinit  = @(inScene, inTimers) this.setScene(inScene, inTimers)
  clearStack    = @() this.stack.clear()
  onMessage     = function() {}
  removeMessage = function(inMessage) {
    foreach (idx, message in this.stack)
      if (inMessage == message)
        return this.stack.remove(idx)
  }

  findMessageById = function(id) {
    return u.search(this.stack,  function(m) { return getTblValue("id", m.messageData, -1) == id })
  }

  subscribeHudEvents = function() {
    ::g_hud_event_manager.subscribe(this.messageEvent, this.onMessage, this)
    if (this.hudEvents)
      foreach (name, func in this.hudEvents)
        ::g_hud_event_manager.subscribe(name, func, this)
  }

  getCleanUpId = @(_total) 0

  cleanUp = function() {
    if (this.stack.len() < this.messagesMax)
      return

    let lastId = this.getCleanUpId(this.stack.len())
    let obj = this.stack[lastId].obj
    if (checkObj(obj)) {
      if (obj.isVisible())
        this.stack[lastId].obj.remove = "yes"
      else
        obj.getScene().destroyElement(obj)
    }
    if (this.stack[lastId].timer)
      this.timers.removeTimer(this.stack[lastId].timer)
    this.stack.remove(lastId)
  }
}

enums.addTypesByGlobalName("g_hud_messages", {
  MAIN_NOTIFICATIONS = {
    nestId = "hud_message_center_main_notification"
    messagesMax = 2
    showSec = 8
    messageEvent = "HudMessage"

    getCleanUpId = @(total) total - 1

    onMessage = function(messageData) {
      if (messageData.type != HUD_MSG_OBJECTIVE)
        return

      let curMsg = this.findMessageById(messageData.id)
      if (curMsg)
        this.updateMessage(curMsg, messageData)
      else
        this.createMessage(messageData)
    }

    getMsgObjId = function(messageData) {
      return "main_msg_" + messageData.id
    }

    createMessage = function(messageData) {
      if (!getTblValue("show", messageData, true))
        return

      this.cleanUp()
      let mainMessage = {
        obj         = null
        messageData = messageData
        timer       = null
        needShowAfterReinit = false
      }
      this.stack.insert(0, mainMessage)

      if (!checkObj(this.nest)) {
        this.stack[0].needShowAfterReinit <- true
        return
      }

      this.showNest(true)
      let view = {
        id = this.getMsgObjId(messageData)
        text = messageData.text
      }
      let blk = handyman.renderCached("%gui/hud/messageStack/mainCenterMessage.tpl", view)
      this.guiScene.prependWithBlk(this.nest, blk, this)
      mainMessage.obj = this.nest.getChild(0)

      if (this.nest.isVisible()) {
        mainMessage.obj["height-end"] = mainMessage.obj.getSize()[1]
        mainMessage.obj.setIntProp(heightPID, 0)
        mainMessage.obj.slideDown = "yes"
        this.guiScene.setUpdatesEnabled(true, true)
      }

      if (!getTblValue("alwaysShow", mainMessage.messageData, false))
        this.setDestroyTimer(mainMessage)
    }

    updateMessage = function(message, messageData) {
      if (!getTblValue("show", messageData, true)) {
        this.animatedRemoveMessage(message)
        return
      }

      let msgObj = message.obj
      if (!checkObj(msgObj)) {
        this.removeMessage(message)
        this.createMessage(messageData)
        return
      }

      message.messageData = messageData
      message.needShowAfterReinit <- false
      msgObj.findObject("text").setValue(messageData.text)
      msgObj.state = "old"
      if (getTblValue("alwaysShow", message.messageData, false)) {
        if (message.timer)
          message.timer.destroy()
      }
      else if (!message.timer)
        this.setDestroyTimer(message)
    }

    showNest = function(show) {
      if (checkObj(this.nest))
        this.nest.show(show)
    }

    setDestroyTimer = function(message) {
      message.timer = this.timers.addTimer(this.showSec,
        (@() this.animatedRemoveMessage(message)).bindenv(this)).weakref()
    }

    animatedRemoveMessage = function(message) {
      this.removeMessage(message)
      this.onNotificationRemoved(message.obj)
      if (checkObj(message.obj))
        message.obj.remove = "yes"
    }

    onNotificationRemoved = function(_obj) {
      if (this.stack.len() || !checkObj(this.nest))
        return

      this.timers.addTimer(0.5, function () {
        if (this.stack.len() == 0)
          this.showNest(false)
      }.bindenv(this))
    }

    reinit = function (inScene, inTimers) {
      this.setScene(inScene, inTimers)
      if (!checkObj(this.nest))
        return
      foreach (message in this.stack) {
        if (message.needShowAfterReinit)
          this.updateMessage(message, message.messageData)
      }
    }
  }

  PLAYER_DAMAGE = {
    nestId = "hud_message_player_damage_notification"
    showSec = 5
    messagesMax = 3
    messageEvent = "HudMessage"

    onMessage = function (messageData) {
      if (messageData.type != HUD_MSG_DAMAGE && messageData.type != HUD_MSG_EVENT)
        return
      if (!checkObj(this.nest))
        return
      if(![HUD_UNIT_TYPE.AIRCRAFT, HUD_UNIT_TYPE.HELICOPTER].contains(getHudUnitType()))
        return

      let checkField = (messageData.id != -1) ? "id" : "text"
      let oldMessage = u.search(this.stack, @(message) message.messageData[checkField] == messageData[checkField])
      if (oldMessage)
        this.refreshMessage(messageData, oldMessage)
      else
        this.addMessage(messageData)
    }

    addMessage = function (messageData) {
      this.cleanUp()
      let message = {
        timer = null
        messageData = messageData
        obj = null
      }
      this.stack.append(message)
      let view = {
        text = messageData.text
      }
      let blk = handyman.renderCached("%gui/hud/messageStack/playerDamageMessage.tpl", view)
      this.guiScene.appendWithBlk(this.nest, blk, blk.len(), this)
      message.obj = this.nest.getChild(this.nest.childrenCount() - 1)

      if (this.nest.isVisible()) {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.slideDown = "yes"
        this.guiScene.setUpdatesEnabled(true, true)
      }

      message.timer = this.timers.addTimer(this.showSec, function () {
        if (checkObj(message.obj))
          message.obj.remove = "yes"
        this.removeMessage(message)
      }.bindenv(this)).weakref()
    }

    refreshMessage = function (messageData, message) {
      let updateText = message.messageData.text != messageData.text
      message.messageData = messageData
      if (message.timer)
        this.timers.setTimerTime(message.timer, this.showSec)
      if (updateText && checkObj(message.obj))
        message.obj.findObject("text").setValue(messageData.text)
    }
  }

  KILL_LOG = {
    nestId = "hud_message_kill_log_notification"
    messagesMax = 5
    showSec = 11
    messageEvent = "HudMessage"

    reinit = function (inScene, inTimers) {
      this.setScene(inScene, inTimers)
      if (!checkObj(this.nest))
        return
      this.nest.deleteChildren()

      let timeDelete = get_time_msec() - this.showSec * 1000
      let killLogNotificationsOld = this.stack
      this.stack = []

      foreach (killLogMessage in killLogNotificationsOld)
        if (killLogMessage.timestamp > timeDelete)
          this.addMessage(killLogMessage.messageData, killLogMessage.timestamp)
    }

    clearStack = function () {
      if (!checkObj(this.nest))
        return
      this.nest.deleteChildren()
    }

    onMessage = function (messageData) {
      if (messageData.type != HUD_MSG_MULTIPLAYER_DMG
        && messageData.type != HUD_MSG_ENEMY_DAMAGE
        && messageData.type != HUD_MSG_ENEMY_CRITICAL_DAMAGE
        && messageData.type != HUD_MSG_ENEMY_FATAL_DAMAGE)
        return
      if (!checkObj(this.nest))
        return
      if (messageData.type == HUD_MSG_MULTIPLAYER_DMG
        && !(messageData?.isKill ?? true) && ::mission_settings.maxRespawns != 1)
        return
      if (!::get_gui_option_in_mode(USEROPT_HUD_VISIBLE_KILLLOG, OPTIONS_MODE_GAMEPLAY, true))
        return
      this.addMessage(messageData)
    }

    addMessage = function (messageData, timestamp = null) {
      this.cleanUp()
      let message = {
        timer = null
        timestamp = timestamp || get_time_msec()
        messageData = messageData
        obj = null
      }
      this.stack.append(message)
      local text = null
      if (messageData.type == HUD_MSG_MULTIPLAYER_DMG)
        text = ::HudBattleLog.msgMultiplayerDmgToText(messageData, true)
      else if (messageData.type == HUD_MSG_ENEMY_CRITICAL_DAMAGE)
        text = colorize("orange", messageData.text)
      else if (messageData.type == HUD_MSG_ENEMY_FATAL_DAMAGE)
        text = colorize("red", messageData.text)
      else
        text = colorize("silver", messageData.text)
      let view = { text = text }

      let timeToShow = timestamp
       ? this.showSec - (get_time_msec() - timestamp) / 1000.0
       : this.showSec

      message.timer = this.timers.addTimer(timeToShow, function () {
        if (checkObj(message.obj))
          message.obj.remove = "yes"
        this.removeMessage(message)
      }.bindenv(this)).weakref()

      if (!checkObj(this.nest))
        return

      let blk = handyman.renderCached("%gui/hud/messageStack/playerDamageMessage.tpl", view)
      this.guiScene.appendWithBlk(this.nest, blk, blk.len(), this)
      message.obj = this.nest.getChild(this.nest.childrenCount() - 1)

      if (this.nest.isVisible() && !timestamp && checkObj(message.obj)) {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.appear = "yes"
        this.guiScene.setUpdatesEnabled(true, true)
      }
    }
  }

  ZONE_CAPTURE = {
    nestId = "hud_message_zone_capture_notification"
    showSec = 3
    messagesMax = 2
    messageEvent = "zoneCapturingEvent"

    getCleanUpId = @(total) total - 1

    onMessage = function (eventData) {
      if (eventData.isHeroAction
        && eventData.eventId != MISSION_CAPTURED_ZONE
        && eventData.eventId != MISSION_TEAM_LEAD_ZONE)
        return

      this.cleanUp()
      this.addNotification(eventData)
    }

    addNotification = function (eventData) {
      if (!checkObj(::g_hud_messages.ZONE_CAPTURE.nest))
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.CAPTURE_ZONE_INFO))
        return

      let message = this.createMessage(eventData)
      let view = {
        text = eventData.text
        team = eventData.isMyTeam ? "ally" : "enemy"
      }

      this.createSceneObjectForMessage(view, message)

      this.setAnimationStartValues(message)
      this.setTimer(message)
    }

    createMessage = function (eventData) {
      let message = {
        obj         = null
        messageData = eventData
        timer       = null
      }
      this.stack.insert(0, message)
      return this.stack[0]
    }

    setTimer = function (message) {
      if (message.timer)
        this.timers.setTimerTime(message.timer, this.showSec)
      else
        message.timer = this.timers.addTimer(this.showSec,
          function () {
            if (checkObj(message.obj))
              message.obj.remove = "yes"
            this.removeMessage(message)
          }.bindenv(this)).weakref()
    }

    function createSceneObjectForMessage(view, message) {
      let blk = handyman.renderCached("%gui/hud/messageStack/zoneCaptureNotification.tpl", view)
      this.guiScene.prependWithBlk(this.nest, blk, this)
      message.obj = this.nest.getChild(0)
    }

    function setAnimationStartValues(message) {
      if (!this.nest.isVisible() || !checkObj(message.obj))
        return

      message.obj["height-end"] = message.obj.getSize()[1]
      message.obj.setIntProp(heightPID, 0)
      message.obj.slideDown = "yes"
      this.guiScene.setUpdatesEnabled(true, true)
    }
  }

  REWARDS = {
    nestId = "hud_messages_reward_messages"
    messagesMax = 5
    showSec = 2
    messageEvent = "InBattleReward"
    hudEvents = {
      LocalPlayerDead  = @(_ed) this.clearRewardMessage()
      ReinitHud        = @(_ed) this.clearRewardMessage()
    }

    rewardWp = 0.0
    rewardXp = 0.0
    rewardClearTimer = null
    curRewardPriority = REWARD_PRIORITY.noPriority

    _animTimerPid = dagui_propid_add_name_id("_transp-timer")

    reinit = function (inScene, inTimers) {
      this.setScene(inScene, inTimers)
      this.timers.removeTimer(this.rewardClearTimer)
      this.clearRewardMessage()
    }

    onMessage = function (messageData) {
      if (!checkObj(::g_hud_messages.REWARDS.nest))
        return
      if (!::get_gui_option_in_mode(USEROPT_HUD_VISIBLE_REWARDS_MSG, OPTIONS_MODE_GAMEPLAY, true))
        return

      let isSeries = this.curRewardPriority != REWARD_PRIORITY.noPriority
      this.rewardWp += messageData.warpoints
      this.rewardXp += messageData.experience

      let newPriority = ::g_hud_reward_message.getMessageByCode(messageData.messageCode).priority
      if (newPriority >= this.curRewardPriority) {
        this.curRewardPriority = newPriority
        this.showNewRewardMessage(messageData)
      }

      this.updateRewardValue(isSeries)

      if (this.rewardClearTimer)
        this.timers.setTimerTime(this.rewardClearTimer, this.showSec)
      else
        this.rewardClearTimer = this.timers.addTimer(this.showSec, this.clearRewardMessage.bindenv(this)).weakref()
    }

    showNewRewardMessage = function (newRewardMessage) {
      let messageObj = showObjById("reward_message", true, this.nest)
      let textObj = messageObj.findObject("reward_message_text")
      let rewardType = ::g_hud_reward_message.getMessageByCode(newRewardMessage.messageCode)

      textObj.setValue(rewardType.getText(newRewardMessage.warpoints, newRewardMessage.counter, newRewardMessage?.expClass, newRewardMessage?.messageModifier))
      textObj.view_class = rewardType.getViewClass(newRewardMessage.warpoints)

      messageObj.setFloatProp(this._animTimerPid, 0.0)
    }

    roundRewardValue = @(val) val > 10 ? (val.tointeger() / 10 * 10) : val.tointeger()

    updateRewardValue = function (isSeries) {
      let reward = Cost(this.roundRewardValue(this.rewardWp), 0, this.roundRewardValue(this.rewardXp))
      this.nest.findObject("reward_message").setFloatProp(this._animTimerPid, 0.0)
      this.nest.findObject("reward_total").setValue(reward.getUncoloredText())

      if (isSeries)
        this.nest.findObject("reward_value_container")._blink = "yes"
    }

    clearRewardMessage = function () {
      if (checkObj(this.nest)) {
        showObjById("reward_message", false, this.nest)
        this.nest.findObject("reward_message_text").setValue("")
        this.nest.findObject("reward_message_text").view_class = ""
        this.nest.findObject("reward_total").setValue("")
        this.nest.findObject("reward_value_container")._blink = "no"
      }
      this.curRewardPriority = REWARD_PRIORITY.noPriority
      this.rewardWp = 0.0
      this.rewardXp = 0.0
      this.timers.removeTimer(this.rewardClearTimer)
      this.rewardClearTimer = null
    }
  }

  RACE_SEGMENT_UPDATE = {
    nestId = "hud_messages_race_messages"
    eventName = "RaceSegmentUpdate"
    messageEvent = "RaceSegmentUpdate"

    onMessage = function (eventData) {
      if (!checkObj(this.nest) || !(get_game_type() & GT_RACE))
        return

      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.RACE_INFO))
        return

      let statusObj = this.nest.findObject("race_status")
      if (checkObj(statusObj)) {
        local text = loc("HUD_RACE_FINISH")
        if (!eventData.isRaceFinishedByPlayer) {
          text = loc("HUD_RACE_CHECKPOINT") + " "
          text += eventData.passedCheckpointsInLap + loc("ui/slash")
          text += eventData.checkpointsPerLap + "  "
          text += loc("HUD_RACE_LAP") + " "
          text += eventData.currentLap + loc("ui/slash") + eventData.totalLaps
        }
        statusObj.setValue(text)
      }

      let playerTime = getTblValue("time", getTblValue("player", eventData, {}), 0.0)

      foreach (blockName in ["beforePlayer", "leader", "afterPlayer", "player"]) {
        let textBlockObj = this.nest.findObject(blockName)
        if (!checkObj(textBlockObj))
          continue

        let data = getTblValue(blockName, eventData)
        let showBlock = data != null
        textBlockObj.show(showBlock)
        if (showBlock) {
          foreach (param, value in data) {
            if (param == "isPlayer")
              textBlockObj.isPlayer = value ? "yes" : "no"
            else {
              let textObj = textBlockObj.findObject(param)
              if (!checkObj(textObj))
                continue

              local text = value
              if (param == "time") {
                local prefix = ""
                let isPlayerBlock = blockName != "player"
                local adjustedTime = value
                if (isPlayerBlock) {
                  adjustedTime -= playerTime
                  if (adjustedTime > 0)
                    prefix = loc("keysPlus")
                }
                text = prefix + time.preciseSecondsToString(adjustedTime, isPlayerBlock)
              }
              else if (param == "place")
                text = value > 0 ? value.tostring() : ""
              else if (param == "name")
                text = getPlayerName(text)

              textObj.setValue(text)
            }
          }
        }
      }
    }
  }

  RACE_TIME_UPDATE = {
    nestId = "hud_messages_race_bonus_time"
    messageEvent = "RaceTimeUpdate"
    showSec = 6
    messagesMax = 1

    onMessage = function (messageData) {
      if (!checkObj(this.nest) || !(get_game_type() & GT_RACE))
        return

      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.RACE_INFO))
        return

      this.addMessage(messageData)
    }

    updatePlayerPlaceAnimation = function(nestObj, animationValue) {
      if (!checkObj(nestObj))
        return

      foreach (objName in ["time"])
        nestObj.findObject(objName)["wink"] = animationValue
    }

    addMessage = function (messageData) {
      this.cleanUp()
      let message = {
        timer = null
        messageData = messageData
        obj = null
      }
      this.stack.append(message)
      let deltaTime = messageData.deltaTime
      let view = {
        text = loc(deltaTime > 0 ? "hints/penalty_time" : "hints/bonus_time", { timeSec = deltaTime })
      }
      let blk = handyman.renderCached("%gui/hud/messageStack/playerDamageMessage.tpl", view)
      this.guiScene.appendWithBlk(this.nest, blk, blk.len(), this)
      message.obj = this.nest.getChild(this.nest.childrenCount() - 1)

      if (this.nest.isVisible()) {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.slideDown = "yes"
        this.guiScene.setUpdatesEnabled(true, true)
      }

      let racePlaceNest = this.scene.findObject("hud_messages_race_messages")
      local playerPlaceObj = null
      if (checkObj(racePlaceNest))
        playerPlaceObj = racePlaceNest.findObject("player")
      this.updatePlayerPlaceAnimation(playerPlaceObj, "fast")

      message.timer = this.timers.addTimer(this.showSec, function () {
        if (checkObj(message.obj))
          message.obj.remove = "yes"
        this.updatePlayerPlaceAnimation(playerPlaceObj, "no")
        this.removeMessage(message)
      }.bindenv(this)).weakref()
    }
  }

  MISSION_RESULT = {
    nestId = "hud_message_center_mission_result"
    messageEvent = "MissionResult"
    hudEvents = {
      MissionContinue = @(_ed) this.destroy()
    }

    clearStack = function () { this.stack = {} }

    onMessage = function (eventData) {
      if (!checkObj(this.nest)
          || get_game_mode() == GM_TEST_FLIGHT)
        return

      let oldResultIdx = getTblValue("resultIdx", this.stack, GO_NONE)

      let resultIdx = getTblValue("resultNum", eventData, GO_NONE)
      let checkResending = eventData?.checkResending ?? eventData?.waitingForResult ?? false //!!! waitingForResult need only for compatibiliti with 1.99.0.X

      /*Have to check this, because, on guiStateChange GUI_STATE_FINISH_SESSION
        send checkResending=true after real mission result sended.
        But call saved in code, if it'll be needed to use somewhere else.
        For now it's working as if we already receive result WIN OR FAIL.
      */
      if (checkResending && (oldResultIdx == GO_WIN || oldResultIdx == GO_FAIL))
        return

      let noLives = getTblValue("noLives", eventData, false)
      let place = getTblValue("place", eventData, -1)
      let total = getTblValue("total", eventData, -1)

      let resultLocId = this.getMissionResultLocId(resultIdx, checkResending, noLives)
      local text = loc(resultLocId)
      if (place >= 0 && total >= 0)
        text += "\n" + loc("HUD_RACE_PLACE", { place = place, total = total })

      this.stack = {
        text = text
        resultIdx = resultIdx
        useMoveOut = resultIdx == GO_WIN || resultIdx == GO_FAIL
      }

      let blk = handyman.renderCached("%gui/hud/messageStack/missionResultMessage.tpl", this.stack)
      this.guiScene.replaceContentFromText(this.nest, blk, blk.len(), this)

      let objTarget = this.nest.findObject("mission_result_box")
      if (!checkObj(objTarget))
        return
      objTarget.show(true)

      if (this.stack.useMoveOut && this.nest.isVisible()) { //no need animation when scene invisible
        let objStart = this.scene.findObject("mission_result_box_start")
        create_ObjMoveToOBj(this.scene, objStart, objTarget, { time = 0.5, bhvFunc = "elasticSmall" })
      }
    }

    getMissionResultLocId = function (resultNum, _checkResending, noLives) {
      if (noLives)
        return "MF_NoAttempts"

      return misResultsMap?[resultNum] ?? getTblValue("result", this.stack, "")
    }

    destroy = function() {
      if (!checkObj(this.nest))
        return
      let msgObj = this.nest.findObject("mission_result_box")
      if (!checkObj(msgObj))
        return

      msgObj["_transp-timer"] = "1"
      msgObj["color-factor"] = "255"
      msgObj["move_out"] = "yes"
      msgObj["anim_transparency"] = "yes"
    }
  }

  HUD_DEATH_REASON_MESSAGE = {
    nestId = "hud_messages_death_reason_notification"
    showSec = 5
    messagesMax = 2
    messageEvent = "HudMessage"
    hudEvents = {
      HudMessageHide = @(_ed) this.destroy()
    }

    onMessage = function (messageData) {
      if (messageData.type != HUD_MSG_UNDER_RADAR && messageData.type != HUD_MSG_DEATH_REASON)
        return
      if (!checkObj(this.nest))
        return

      let oldMessage = this.findMessageById(messageData.id)
      if (oldMessage)
        this.refreshMessage(messageData, oldMessage)
      else
        this.addMessage(messageData)
    }

    addMessage = function (messageData, timestamp = null, needAnimations = true) {
      this.cleanUp()
      let message = {
        timer = null
        timestamp = timestamp || get_time_msec()
        messageData = messageData
        obj = null
      }
      this.stack.append(message)
      let view = {
        text = messageData.text
      }
      let blk = handyman.renderCached("%gui/hud/messageStack/deathReasonMessage.tpl", view)
      this.guiScene.appendWithBlk(this.nest, blk, blk.len(), this)
      message.obj = this.nest.getChild(this.nest.childrenCount() - 1)

      if (this.nest.isVisible() && needAnimations) {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.slideDown = "yes"
        this.guiScene.setUpdatesEnabled(true, true)
      }

      let timeToShow = timestamp
       ? this.showSec - (get_time_msec() - timestamp) / 1000.0
       : this.showSec

      message.timer = this.timers.addTimer(timeToShow, function () {
        if (checkObj(message.obj))
          message.obj.remove = "yes"
        this.removeMessage(message)
      }.bindenv(this)).weakref()
    }

    refreshMessage = function (messageData, message) {
      let shouldUpdateText = message.messageData.text != messageData.text
      message.messageData = messageData
      if (message.timer)
        this.timers.setTimerTime(message.timer, this.showSec)
      if (shouldUpdateText && checkObj(message.obj))
        message.obj.findObject("text").setValue(messageData.text)
    }

    clearStack = function () {}

    destroy = function () {
      this.stack.clear()
      if (!checkObj(this.nest))
        return
      this.nest.deleteChildren()
    }

    reinit = function (inScene, inTimers) {
      this.setScene(inScene, inTimers)
      if (!checkObj(this.nest))
        return
      this.nest.deleteChildren()

      let timeDelete = get_time_msec() - this.showSec * 1000
      let oldStack = this.stack
      this.stack = []

      foreach (message in oldStack)
        if (message.timestamp > timeDelete)
          this.addMessage(message.messageData, message.timestamp, false)
    }
  }
},
function() {
  this.stack = []
})
