//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { secondsToTime, millisecondsToSecondsInt } = require("%scripts/time.nut")
let { buildTimeStr } = require("%scripts/timeLoc.nut")
let { set_siren_state, set_nuclear_explosion_sound_active, set_seen_nuclear_event,
point_camera_to_event, play_background_nuclear_explosion } = require("hangarEventCommand")
let { get_time_msec } = require("dagor.time")
let exitGame = require("%scripts/utils/exitGame.nut")

const TIME_TO_EXPLOSION = 11000
const TIME_TO_SERENA_ACTIVATION = 1000
const TIME_TO_EXIT_AFTER_EXPLOSION = 6000

const TIME_TO_POINT_CAMERA_TO_EVENT = 1000
const TIME_TO_BACKGROUND_NUCLEAR_EVENT = 5000
const TIME_TO_BACKGROUND_NUCLEAR_EVENT_END = 10000

local class airRaidWndScene extends ::gui_handlers.BaseGuiHandlerWT {
  sceneBlkName = "%gui/wndLib/airRaidTimerScene.blk"

  countdownStartedTime = 0
  isExplosionStarted = false
  isSirenActive = false
  hasVisibleNuclearTimer = true

  function initScreen() {
    ::enableHangarControls(this.hasVisibleNuclearTimer)
    this.showSceneBtn("window", this.hasVisibleNuclearTimer)
    if (this.hasVisibleNuclearTimer)
      this.initTimer()
    else
      this.updateMainNuclearExplosionEvent()
  }

  function onNuclearExplosionTimer(_obj, _dt) {
    this.updateNuclearExplosionTimer()
  }

  function initTimer() {
    let timerObj = this.scene.findObject("nuclear_explosion_timer")
    if (checkObj(timerObj))
      timerObj.setUserData(this)

    this.countdownStartedTime = get_time_msec()
    this.updateNuclearExplosionTimer()
  }

  function updateNuclearExplosionTimer() {
    let activeTime = get_time_msec() - this.countdownStartedTime

    if (activeTime > TIME_TO_SERENA_ACTIVATION && !this.isSirenActive)
      this.isSirenActive = set_siren_state(true)

    if (activeTime > TIME_TO_EXPLOSION) {
      if (!this.isExplosionStarted) {
        this.showSceneBtn("window", false)

        set_nuclear_explosion_sound_active()
        ::start_dynamic_lut_texture("nuclear_explosion")

        set_seen_nuclear_event(true)

        this.isExplosionStarted = true
      }
    }
    else {
      let countdownSeconds = millisecondsToSecondsInt(TIME_TO_EXPLOSION - activeTime)
      let countdownTime = secondsToTime(countdownSeconds)

      let textObj = this.scene.findObject("nuclear_explosion_timer_text")
      if (checkObj(textObj)) {
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
      ::g_string.implode([colorize("warningTextColor",
        loc("NEW_CLIENT/EXIT_TITLE")),
        loc("NEW_CLIENT/EXIT_MESSAGE")], "\n"),
        [["ok", @() exitGame() ]],
        "ok",
        { cancel_fn = @() exitGame() })

    let timerObj = this.scene.findObject("nuclear_explosion_timer")
    if (checkObj(timerObj))
      timerObj.setUserData(null)
  }

  function updateMainNuclearExplosionEvent() {
    ::g_delayed_actions.add(@() point_camera_to_event(), TIME_TO_POINT_CAMERA_TO_EVENT)
    ::g_delayed_actions.add(@() play_background_nuclear_explosion(), TIME_TO_BACKGROUND_NUCLEAR_EVENT)
    ::g_delayed_actions.add(Callback(@() this.goForward(::gui_start_mainmenu), this), TIME_TO_BACKGROUND_NUCLEAR_EVENT_END)
  }
}
::gui_handlers.airRaidWndScene <- airRaidWndScene

return @(params) ::handlersManager.loadHandler(airRaidWndScene, params)
