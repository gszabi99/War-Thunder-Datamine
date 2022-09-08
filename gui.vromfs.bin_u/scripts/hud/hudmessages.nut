let { GO_NONE, GO_FAIL, GO_WIN, GO_EARLY, GO_WAITING_FOR_RESULT } = require_native("guiMission")
let enums = require("%sqStdLibs/helpers/enums.nut")
let time = require("%scripts/time.nut")
let { getPlayerName } = require("%scripts/clientState/platform.nut")

local heightPID = ::dagui_propid.add_name_id("height")

::g_hud_messages <- {
  types = []
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

  setScene = function(inScene, inTimers)
  {
    scene = inScene
    guiScene = scene.getScene()
    timers = inTimers
    nest = scene.findObject(nestId)
  }
  reinit  = @(inScene, inTimers) setScene(inScene, inTimers)
  clearStack    = @() stack.clear()
  onMessage     = function() {}
  removeMessage = function(inMessage)
  {
    foreach (idx, message in stack)
      if (inMessage == message)
        return stack.remove(idx)
  }

  findMessageById = function(id) {
    return ::u.search(stack, (@(id) function(m) { return ::getTblValue("id", m.messageData, -1) == id })(id))
  }

  subscribeHudEvents = function()
  {
    ::g_hud_event_manager.subscribe(messageEvent, onMessage, this)
    if (hudEvents)
      foreach(name, func in hudEvents)
        ::g_hud_event_manager.subscribe(name, func, this)
  }

  getCleanUpId = @(total) 0

  cleanUp = function()
  {
    if (stack.len() < messagesMax)
      return

    let lastId = getCleanUpId(stack.len())
    let obj = stack[lastId].obj
    if (::check_obj(obj))
    {
      if (obj.isVisible())
        stack[lastId].obj.remove = "yes"
      else
        obj.getScene().destroyElement(obj)
    }
    if (stack[lastId].timer)
      timers.removeTimer(stack[lastId].timer)
    stack.remove(lastId)
  }
}

enums.addTypesByGlobalName("g_hud_messages", {
  MAIN_NOTIFICATIONS = {
    nestId = "hud_message_center_main_notification"
    messagesMax = 2
    showSec = 8
    messageEvent = "HudMessage"

    getCleanUpId = @(total) total - 1

    onMessage = function(messageData)
    {
      if (messageData.type != ::HUD_MSG_OBJECTIVE)
        return

      let curMsg = findMessageById(messageData.id)
      if (curMsg)
        updateMessage(curMsg, messageData)
      else
        createMessage(messageData)
    }

    getMsgObjId = function(messageData)
    {
      return "main_msg_" + messageData.id
    }

    createMessage = function(messageData)
    {
      if (!::getTblValue("show", messageData, true))
        return

      cleanUp()
      let mainMessage = {
        obj         = null
        messageData = messageData
        timer       = null
        needShowAfterReinit = false
      }
      stack.insert(0, mainMessage)

      if (!::checkObj(nest))
      {
        stack[0].needShowAfterReinit <- true
        return
      }

      showNest(true)
      let view = {
        id = getMsgObjId(messageData)
        text = messageData.text
      }
      let blk = ::handyman.renderCached("%gui/hud/messageStack/mainCenterMessage", view)
      guiScene.prependWithBlk(nest, blk, this)
      mainMessage.obj = nest.getChild(0)

      if (nest.isVisible())
      {
        mainMessage.obj["height-end"] = mainMessage.obj.getSize()[1]
        mainMessage.obj.setIntProp(heightPID, 0)
        mainMessage.obj.slideDown = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }

      if (!::getTblValue("alwaysShow", mainMessage.messageData, false))
        setDestroyTimer(mainMessage)
    }

    updateMessage = function(message, messageData)
    {
      if (!::getTblValue("show", messageData, true))
      {
        animatedRemoveMessage(message)
        return
      }

      let msgObj = message.obj
      if (!::checkObj(msgObj))
      {
        removeMessage(message)
        createMessage(messageData)
        return
      }

      message.messageData = messageData
      message.needShowAfterReinit <- false
      msgObj.findObject("text").setValue(messageData.text)
      msgObj.state = "old"
      if (::getTblValue("alwaysShow", message.messageData, false))
      {
        if (message.timer)
          message.timer.destroy()
      }
      else if (!message.timer)
        setDestroyTimer(message)
    }

    showNest = function(show)
    {
      if (::checkObj(nest))
        nest.show(show)
    }

    setDestroyTimer = function(message)
    {
      message.timer = timers.addTimer(showSec,
        (@() animatedRemoveMessage(message)).bindenv(this)).weakref()
    }

    animatedRemoveMessage = function(message)
    {
      removeMessage(message)
      onNotificationRemoved(message.obj)
      if (::checkObj(message.obj))
        message.obj.remove = "yes"
    }

    onNotificationRemoved = function(obj)
    {
      if (stack.len() || !::checkObj(nest))
        return

      timers.addTimer(0.5, function () {
        if (stack.len() == 0)
          showNest(false)
      }.bindenv(this))
    }

    reinit = function (inScene, inTimers)
    {
      setScene(inScene, inTimers)
      if (!::checkObj(nest))
        return
      foreach (message in stack)
      {
        if (message.needShowAfterReinit)
          updateMessage(message, message.messageData)
      }
    }
  }

  PLAYER_DAMAGE = {
    nestId = "hud_message_player_damage_notification"
    showSec = 5
    messagesMax = 3
    messageEvent = "HudMessage"

    onMessage = function (messageData)
    {
      if (messageData.type != ::HUD_MSG_DAMAGE && messageData.type != ::HUD_MSG_EVENT)
        return
      if (!::checkObj(nest))
        return

      let checkField = (messageData.id != -1) ? "id" : "text"
      let oldMessage = ::u.search(stack, @(message) message.messageData[checkField] == messageData[checkField])
      if (oldMessage)
        refreshMessage(messageData, oldMessage)
      else
        addMessage(messageData)
    }

    addMessage = function (messageData)
    {
      cleanUp()
      let message = {
        timer = null
        messageData = messageData
        obj = null
      }
      stack.append(message)
      let view = {
        text = messageData.text
      }
      let blk = ::handyman.renderCached("%gui/hud/messageStack/playerDamageMessage", view)
      guiScene.appendWithBlk(nest, blk, blk.len(), this)
      message.obj = nest.getChild(nest.childrenCount() - 1)

      if (nest.isVisible())
      {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.slideDown = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }

      message.timer = timers.addTimer(showSec, function () {
        if (::check_obj(message.obj))
          message.obj.remove = "yes"
        removeMessage(message)
      }.bindenv(this)).weakref()
    }

    refreshMessage = function (messageData, message)
    {
      let updateText = message.messageData.text != messageData.text
      message.messageData = messageData
      if (message.timer)
        timers.setTimerTime(message.timer, showSec)
      if (updateText && ::checkObj(message.obj))
        message.obj.findObject("text").setValue(messageData.text)
    }
  }

  KILL_LOG = {
    nestId = "hud_message_kill_log_notification"
    messagesMax = 5
    showSec = 11
    messageEvent = "HudMessage"

    reinit = function (inScene, inTimers)
    {
      setScene(inScene, inTimers)
      if (!::checkObj(nest))
        return
      nest.deleteChildren()

      let timeDelete = ::dagor.getCurTime() - showSec * 1000
      let killLogNotificationsOld = stack
      stack = []

      foreach (killLogMessage in killLogNotificationsOld)
        if (killLogMessage.timestamp > timeDelete)
          addMessage(killLogMessage.messageData, killLogMessage.timestamp)
    }

    clearStack = function ()
    {
      if (!::checkObj(nest))
        return
      nest.deleteChildren()
    }

    onMessage = function (messageData)
    {
      if (messageData.type != ::HUD_MSG_MULTIPLAYER_DMG
        && messageData.type != ::HUD_MSG_ENEMY_DAMAGE
        && messageData.type != ::HUD_MSG_ENEMY_CRITICAL_DAMAGE
        && messageData.type != ::HUD_MSG_ENEMY_FATAL_DAMAGE)
        return
      if (!::checkObj(nest))
        return
      if (messageData.type == ::HUD_MSG_MULTIPLAYER_DMG
        && !(messageData?.isKill ?? true) && ::mission_settings.maxRespawns != 1)
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.KILLLOG))
        return
      addMessage(messageData)
    }

    addMessage = function (messageData, timestamp = null)
    {
      cleanUp()
      let message = {
        timer = null
        timestamp = timestamp || ::dagor.getCurTime()
        messageData = messageData
        obj = null
      }
      stack.append(message)
      local text = null
      if (messageData.type == ::HUD_MSG_MULTIPLAYER_DMG)
        text = ::HudBattleLog.msgMultiplayerDmgToText(messageData, true)
      else if (messageData.type == ::HUD_MSG_ENEMY_CRITICAL_DAMAGE)
        text = ::colorize("orange", messageData.text)
      else if (messageData.type == ::HUD_MSG_ENEMY_FATAL_DAMAGE)
        text = ::colorize("red", messageData.text)
      else
        text = ::colorize("silver", messageData.text)
      let view = { text = text }

      let timeToShow = timestamp
       ? showSec - (::dagor.getCurTime() - timestamp) / 1000.0
       : showSec

      message.timer = timers.addTimer(timeToShow, function () {
        if (::checkObj(message.obj))
          message.obj.remove = "yes"
        removeMessage(message)
      }.bindenv(this)).weakref()

      if (!::checkObj(nest))
        return

      let blk = ::handyman.renderCached("%gui/hud/messageStack/playerDamageMessage", view)
      guiScene.appendWithBlk(nest, blk, blk.len(), this)
      message.obj = nest.getChild(nest.childrenCount() - 1)

      if (nest.isVisible() && !timestamp && ::checkObj(message.obj))
      {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.appear = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }
    }
  }

  ZONE_CAPTURE = {
    nestId = "hud_message_zone_capture_notification"
    showSec = 3
    messagesMax = 2
    messageEvent = "zoneCapturingEvent"

    getCleanUpId = @(total) total - 1

    onMessage = function (eventData)
    {
      if (eventData.isHeroAction
        && eventData.eventId != ::MISSION_CAPTURED_ZONE
        && eventData.eventId != ::MISSION_TEAM_LEAD_ZONE)
        return

      cleanUp()
      addNotification(eventData)
    }

    addNotification = function (eventData)
    {
      if (!::checkObj(::g_hud_messages.ZONE_CAPTURE.nest))
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.CAPTURE_ZONE_INFO))
        return

      let message = createMessage(eventData)
      let view = {
        text = eventData.text
        team = eventData.isMyTeam ? "ally" : "enemy"
      }

      createSceneObjectForMessage(view, message)

      setAnimationStartValues(message)
      setTimer(message)
    }

    createMessage = function (eventData)
    {
      let message = {
        obj         = null
        messageData = eventData
        timer       = null
      }
      stack.insert(0, message)
      return stack[0]
    }

    setTimer = function (message)
    {
      if (message.timer)
        timers.setTimerTime(message.timer, showSec)
      else
        message.timer = timers.addTimer(showSec,
          function () {
            if (::checkObj(message.obj))
              message.obj.remove = "yes"
            removeMessage(message)
          }.bindenv(this)).weakref()
    }

    function createSceneObjectForMessage(view, message)
    {
      let blk = ::handyman.renderCached("%gui/hud/messageStack/zoneCaptureNotification", view)
      guiScene.prependWithBlk(nest, blk, this)
      message.obj = nest.getChild(0)
    }

    function setAnimationStartValues(message)
    {
      if (!nest.isVisible() || !::checkObj(message.obj))
        return

      message.obj["height-end"] = message.obj.getSize()[1]
      message.obj.setIntProp(heightPID, 0)
      message.obj.slideDown = "yes"
      guiScene.setUpdatesEnabled(true, true)
    }
  }

  REWARDS = {
    nestId = "hud_messages_reward_messages"
    messagesMax = 5
    showSec = 2
    messageEvent = "InBattleReward"
    hudEvents = {
      LocalPlayerDead  = @(ed) clearRewardMessage()
      ReinitHud        = @(ed) clearRewardMessage()
    }

    rewardWp = 0.0
    rewardXp = 0.0
    rewardClearTimer = null
    curRewardPriority = REWARD_PRIORITY.noPriority

    _animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

    reinit = function (inScene, inTimers)
    {
      setScene(inScene, inTimers)
      timers.removeTimer(rewardClearTimer)
      clearRewardMessage()
    }

    onMessage = function (messageData)
    {
      if (!::checkObj(::g_hud_messages.REWARDS.nest))
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.REWARDS_MSG))
        return

      let isSeries = curRewardPriority != REWARD_PRIORITY.noPriority
      rewardWp += messageData.warpoints
      rewardXp += messageData.experience

      let newPriority = ::g_hud_reward_message.getMessageByCode(messageData.messageCode).priority
      if (newPriority >= curRewardPriority)
      {
        curRewardPriority = newPriority
        showNewRewardMessage(messageData)
      }

      updateRewardValue(isSeries)

      if (rewardClearTimer)
        timers.setTimerTime(rewardClearTimer, showSec)
      else
        rewardClearTimer = timers.addTimer(showSec, clearRewardMessage.bindenv(this)).weakref()
    }

    showNewRewardMessage = function (newRewardMessage)
    {
      let messageObj = ::showBtn("reward_message", true, nest)
      let textObj = messageObj.findObject("reward_message_text")
      let rewardType = ::g_hud_reward_message.getMessageByCode(newRewardMessage.messageCode)

      textObj.setValue(rewardType.getText(newRewardMessage.warpoints, newRewardMessage.counter, newRewardMessage?.expClass))
      textObj.view_class = rewardType.getViewClass(newRewardMessage.warpoints)

      messageObj.setFloatProp(_animTimerPid, 0.0)
    }

    roundRewardValue = @(val) val > 10 ? (val.tointeger() / 10 * 10) : val.tointeger()

    updateRewardValue = function (isSeries)
    {
      let reward = ::Cost(roundRewardValue(rewardWp), 0, roundRewardValue(rewardXp))
      nest.findObject("reward_message").setFloatProp(_animTimerPid, 0.0)
      nest.findObject("reward_total").setValue(reward.getUncoloredText())

      if (isSeries)
        nest.findObject("reward_value_container")._blink = "yes"
    }

    clearRewardMessage = function ()
    {
      if (::check_obj(nest))
      {
        ::showBtn("reward_message", false, nest)
        nest.findObject("reward_message_text").setValue("")
        nest.findObject("reward_message_text").view_class = ""
        nest.findObject("reward_total").setValue("")
        nest.findObject("reward_value_container")._blink = "no"
      }
      curRewardPriority = REWARD_PRIORITY.noPriority
      rewardWp = 0.0
      rewardXp = 0.0
      timers.removeTimer(rewardClearTimer)
      rewardClearTimer = null
    }
  }

  RACE_SEGMENT_UPDATE = {
    nestId = "hud_messages_race_messages"
    eventName = "RaceSegmentUpdate"
    messageEvent = "RaceSegmentUpdate"

    onMessage = function (eventData)
    {
      if (!::checkObj(nest) || !(::get_game_type() & ::GT_RACE))
        return

      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.RACE_INFO))
        return

      let statusObj = nest.findObject("race_status")
      if (::check_obj(statusObj))
      {
        local text = ::loc("HUD_RACE_FINISH")
        if (!eventData.isRaceFinishedByPlayer)
        {
          text = ::loc("HUD_RACE_CHECKPOINT") + " "
          text += eventData.passedCheckpointsInLap + ::loc("ui/slash")
          text += eventData.checkpointsPerLap + "  "
          text += ::loc("HUD_RACE_LAP") + " "
          text += eventData.currentLap + ::loc("ui/slash") + eventData.totalLaps
        }
        statusObj.setValue(text)
      }

      let playerTime = ::getTblValue("time", ::getTblValue("player", eventData, {}), 0.0)

      foreach (blockName in ["beforePlayer", "leader", "afterPlayer", "player"])
      {
        let textBlockObj = nest.findObject(blockName)
        if (!::check_obj(textBlockObj))
          continue

        let data = ::getTblValue(blockName, eventData)
        let showBlock = data != null
        textBlockObj.show(showBlock)
        if (showBlock)
        {
          foreach (param, value in data)
          {
            if (param == "isPlayer")
              textBlockObj.isPlayer = value? "yes" : "no"
            else
            {
              let textObj = textBlockObj.findObject(param)
              if (!::check_obj(textObj))
                continue

              local text = value
              if (param == "time")
              {
                local prefix = ""
                let isPlayerBlock = blockName != "player"
                local adjustedTime = value
                if (isPlayerBlock)
                {
                  adjustedTime -= playerTime
                  if (adjustedTime > 0)
                    prefix = ::loc("keysPlus")
                }
                text = prefix + time.preciseSecondsToString(adjustedTime, isPlayerBlock)
              }
              else if (param == "place")
                text = value > 0? value.tostring() : ""
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

    onMessage = function (messageData)
    {
      if (!::checkObj(nest) || !(::get_game_type() & ::GT_RACE))
        return

      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.RACE_INFO))
        return

      addMessage(messageData)
    }

    updatePlayerPlaceAnimation = function(nestObj, animationValue) {
      if (!::check_obj(nestObj))
        return

      foreach (objName in ["time"])
        nestObj.findObject(objName)["wink"] = animationValue
    }

    addMessage = function (messageData)
    {
      cleanUp()
      let message = {
        timer = null
        messageData = messageData
        obj = null
      }
      stack.append(message)
      let deltaTime = messageData.deltaTime
      let view = {
        text = ::loc(deltaTime > 0 ? "hints/penalty_time" : "hints/bonus_time", { timeSec = deltaTime })
      }
      let blk = ::handyman.renderCached("%gui/hud/messageStack/playerDamageMessage", view)
      guiScene.appendWithBlk(nest, blk, blk.len(), this)
      message.obj = nest.getChild(nest.childrenCount() - 1)

      if (nest.isVisible())
      {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.slideDown = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }

      let racePlaceNest = scene.findObject("hud_messages_race_messages")
      local playerPlaceObj = null
      if (::check_obj(racePlaceNest))
        playerPlaceObj = racePlaceNest.findObject("player")
      updatePlayerPlaceAnimation(playerPlaceObj, "fast")

      message.timer = timers.addTimer(showSec, function () {
        if (::check_obj(message.obj))
          message.obj.remove = "yes"
        updatePlayerPlaceAnimation(playerPlaceObj, "no")
        removeMessage(message)
      }.bindenv(this)).weakref()
    }
  }

  MISSION_RESULT = {
    nestId = "hud_message_center_mission_result"
    messageEvent = "MissionResult"
    hudEvents = {
      MissionContinue = @(ed) destroy()
    }

    clearStack = function () { stack = {} }

    onMessage = function (eventData)
    {
      if (!::checkObj(nest)
          || ::get_game_mode() == ::GM_TEST_FLIGHT)
        return

      let oldResultIdx = ::getTblValue("resultIdx", stack, GO_NONE)

      let resultIdx = ::getTblValue("resultNum", eventData, GO_NONE)
      let checkResending = eventData?.checkResending ?? eventData?.waitingForResult ?? false //!!! waitingForResult need only for compatibiliti with 1.99.0.X

      /*Have to check this, because, on guiStateChange GUI_STATE_FINISH_SESSION
        send checkResending=true after real mission result sended.
        But call saved in code, if it'll be needed to use somewhere else.
        For now it's working as if we already receive result WIN OR FAIL.
      */
      if (checkResending && (oldResultIdx == GO_WIN || oldResultIdx == GO_FAIL))
        return

      let noLives = ::getTblValue("noLives", eventData, false)
      let place = ::getTblValue("place", eventData, -1)
      let total = ::getTblValue("total", eventData, -1)

      let resultLocId = getMissionResultLocId(resultIdx, checkResending, noLives)
      local text = ::loc(resultLocId)
      if (place >= 0 && total >= 0)
        text += "\n" + ::loc("HUD_RACE_PLACE", {place = place, total = total})

      stack = {
        text = text
        resultIdx = resultIdx
        useMoveOut = resultIdx == GO_WIN || resultIdx == GO_FAIL
      }

      let blk = ::handyman.renderCached("%gui/hud/messageStack/missionResultMessage", stack)
      guiScene.replaceContentFromText(nest, blk, blk.len(), this)

      let objTarget = nest.findObject("mission_result_box")
      if (!::check_obj(objTarget))
        return
      objTarget.show(true)

      if (stack.useMoveOut && nest.isVisible()) //no need animation when scene invisible
      {
        let objStart = scene.findObject("mission_result_box_start")
        ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = 0.5, bhvFunc = "elasticSmall" })
      }
    }

    getMissionResultLocId = function (resultNum, checkResending, noLives)
    {
      if (noLives)
        return "MF_NoAttempts"

      switch(resultNum)
      {
        case GO_NONE:
          return ""
        case GO_WIN:
          return "MISSION_SUCCESS"
        case GO_FAIL:
          return "MISSION_FAIL"
        case GO_EARLY:
          return "MISSION_IN_PROGRESS"
        case GO_WAITING_FOR_RESULT:
          return "FINALIZING"
        default:
          return ::getTblValue("result", stack, "")
      }
      return ""
    }

    destroy = function()
    {
      if (!::checkObj(nest))
        return
      let msgObj = nest.findObject("mission_result_box")
      if (!::checkObj(msgObj))
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
      HudMessageHide = @(ed) destroy()
    }

    onMessage = function (messageData)
    {
      if (messageData.type != ::HUD_MSG_UNDER_RADAR && messageData.type != ::HUD_MSG_DEATH_REASON)
        return
      if (!::checkObj(nest))
        return

      let oldMessage = findMessageById(messageData.id)
      if (oldMessage)
        refreshMessage(messageData, oldMessage)
      else
        addMessage(messageData)
    }

    addMessage = function (messageData, timestamp = null, needAnimations = true)
    {
      cleanUp()
      let message = {
        timer = null
        timestamp = timestamp || ::dagor.getCurTime()
        messageData = messageData
        obj = null
      }
      stack.append(message)
      let view = {
        text = messageData.text
      }
      let blk = ::handyman.renderCached("%gui/hud/messageStack/deathReasonMessage", view)
      guiScene.appendWithBlk(nest, blk, blk.len(), this)
      message.obj = nest.getChild(nest.childrenCount() - 1)

      if (nest.isVisible() && needAnimations)
      {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.slideDown = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }

      let timeToShow = timestamp
       ? showSec - (::dagor.getCurTime() - timestamp) / 1000.0
       : showSec

      message.timer = timers.addTimer(timeToShow, function () {
        if (::check_obj(message.obj))
          message.obj.remove = "yes"
        removeMessage(message)
      }.bindenv(this)).weakref()
    }

    refreshMessage = function (messageData, message)
    {
      let shouldUpdateText = message.messageData.text != messageData.text
      message.messageData = messageData
      if (message.timer)
        timers.setTimerTime(message.timer, showSec)
      if (shouldUpdateText && ::checkObj(message.obj))
        message.obj.findObject("text").setValue(messageData.text)
    }

    clearStack = function () {}

    destroy = function () {
      stack.clear()
      if (!::checkObj(nest))
        return
      nest.deleteChildren()
    }

    reinit = function (inScene, inTimers)
    {
      setScene(inScene, inTimers)
      if (!::checkObj(nest))
        return
      nest.deleteChildren()

      let timeDelete = ::dagor.getCurTime() - showSec * 1000
      let oldStack = stack
      stack = []

      foreach (message in oldStack)
        if (message.timestamp > timeDelete)
          addMessage(message.messageData, message.timestamp, false)
    }
  }
},
function()
{
  stack = []
})
