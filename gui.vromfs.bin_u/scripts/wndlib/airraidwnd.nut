local { secondsToTime, millisecondsToSecondsInt } = require("scripts/time.nut")
local { buildTimeStr } = require("std/timeLoc.nut")
local { set_siren_state, set_nuclear_explosion_sound_active, set_seen_nuclear_event,
point_camera_to_event, play_background_nuclear_explosion } = ::require_native("hangarEventCommand")
local exitGame = require("scripts/utils/exitGame.nut")

const TIME_TO_EXPLOSION = 11000
const TIME_TO_SERENA_ACTIVATION = 1000
const TIME_TO_EXIT_AFTER_EXPLOSION = 6000

const TIME_TO_POINT_CAMERA_TO_EVENT = 1000
const TIME_TO_BACKGROUND_NUCLEAR_EVENT = 5000
const TIME_TO_BACKGROUND_NUCLEAR_EVENT_END = 10000

local class airRaidWndScene extends ::gui_handlers.BaseGuiHandlerWT {
  sceneBlkName = "gui/wndLib/airRaidTimerScene.blk"

  countdownStartedTime = 0
  isExplosionStarted = false
  isSirenActive = false
  hasVisibleNuclearTimer = true

  function initScreen() {
    ::enableHangarControls(hasVisibleNuclearTimer)
    showSceneBtn("window", hasVisibleNuclearTimer)
    if (hasVisibleNuclearTimer)
      initTimer()
    else
      updateMainNuclearExplosionEvent()
  }

  function onNuclearExplosionTimer(obj, dt) {
    updateNuclearExplosionTimer()
  }

  function initTimer() {
    local timerObj = scene.findObject("nuclear_explosion_timer")
    if (::check_obj(timerObj))
      timerObj.setUserData(this)

    countdownStartedTime = ::dagor.getCurTime()
    updateNuclearExplosionTimer()
  }

  function updateNuclearExplosionTimer() {
    local activeTime = ::dagor.getCurTime() - countdownStartedTime

    if (activeTime > TIME_TO_SERENA_ACTIVATION && !isSirenActive)
      isSirenActive = set_siren_state(true)

    if (activeTime > TIME_TO_EXPLOSION) {
      if (!isExplosionStarted) {
        showSceneBtn("window", false)

        set_nuclear_explosion_sound_active()
        ::start_dynamic_lut_texture("nuclear_explosion")

        set_seen_nuclear_event(true)

        isExplosionStarted = true
      }
    } else {
      local countdownSeconds = millisecondsToSecondsInt(TIME_TO_EXPLOSION - activeTime)
      local countdownTime = secondsToTime(countdownSeconds)

      local textObj = scene.findObject("nuclear_explosion_timer_text")
      if (::check_obj(textObj)) {
        textObj.setValue(buildTimeStr({
            hour = countdownTime.hours,
            min = countdownTime.minutes,
            sec = countdownTime.seconds
          }, true)
        )
      }
    }

    if (activeTime <= TIME_TO_EXPLOSION + TIME_TO_EXIT_AFTER_EXPLOSION)
      return

    ::scene_msg_box("show_message_from_matching",
      null,
      ::g_string.implode([::colorize("warningTextColor",
        ::loc("NEW_CLIENT/EXIT_TITLE")),
        ::loc("NEW_CLIENT/EXIT_MESSAGE")], "\n"),
        [["ok", @() exitGame() ]],
        "ok",
        { cancel_fn = @() exitGame() })

    local timerObj = scene.findObject("nuclear_explosion_timer")
    if (::check_obj(timerObj))
      timerObj.setUserData(null)
  }

  function updateMainNuclearExplosionEvent() {
    ::g_delayed_actions.add(@() point_camera_to_event(), TIME_TO_POINT_CAMERA_TO_EVENT)
    ::g_delayed_actions.add(@() play_background_nuclear_explosion(), TIME_TO_BACKGROUND_NUCLEAR_EVENT)
    ::g_delayed_actions.add(::Callback(@() goForward(::gui_start_mainmenu), this), TIME_TO_BACKGROUND_NUCLEAR_EVENT_END)
  }
}
::gui_handlers.airRaidWndScene <- airRaidWndScene

return @(params) ::handlersManager.loadHandler(airRaidWndScene, params)
