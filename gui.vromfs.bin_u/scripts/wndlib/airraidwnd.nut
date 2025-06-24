from "%scripts/dagui_natives.nut" import start_dynamic_lut_texture
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { secondsToTime, millisecondsToSecondsInt } = require("%scripts/time.nut")
let { buildTimeStr } = require("%appGlobals/timeLoc.nut")
let { set_siren_state, set_nuclear_explosion_sound_active, set_seen_nuclear_event,
point_camera_to_event, play_background_nuclear_explosion } = require("hangarEventCommand")
let { get_time_msec } = require("dagor.time")
let exitGamePlatform = require("%scripts/utils/exitGamePlatform.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { addDelayedAction } = require("%scripts/utils/delayedActions.nut")

const TIME_TO_EXPLOSION = 11000
const TIME_TO_SERENA_ACTIVATION = 1000
const TIME_TO_EXIT_AFTER_EXPLOSION = 6000

const TIME_TO_POINT_CAMERA_TO_EVENT = 1000
const TIME_TO_BACKGROUND_NUCLEAR_EVENT = 5000
const TIME_TO_BACKGROUND_NUCLEAR_EVENT_END = 10000

local class airRaidWndScene (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/wndLib/airRaidTimerScene.blk"

  countdownStartedTime = 0
  isExplosionStarted = false
  isSirenActive = false
  hasVisibleNuclearTimer = true

  function initScreen() {
    showObjById("window", this.hasVisibleNuclearTimer, this.scene)
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
        showObjById("window", false, this.scene)

        set_nuclear_explosion_sound_active()
        start_dynamic_lut_texture("nuclear_explosion")

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

    scene_msg_box("show_message_from_matching",
      null,
      "\n".join([colorize("warningTextColor",
        loc("NEW_CLIENT/EXIT_TITLE")),
        loc("NEW_CLIENT/EXIT_MESSAGE")], true),
        [["ok", @() exitGamePlatform() ]],
        "ok",
        { cancel_fn = @() exitGamePlatform() })

    let timerObj = this.scene.findObject("nuclear_explosion_timer")
    if (checkObj(timerObj))
      timerObj.setUserData(null)
  }

  function updateMainNuclearExplosionEvent() {
    addDelayedAction(@() point_camera_to_event(), TIME_TO_POINT_CAMERA_TO_EVENT)
    addDelayedAction(@() play_background_nuclear_explosion(), TIME_TO_BACKGROUND_NUCLEAR_EVENT)
    addDelayedAction(Callback(@() this.goForward(gui_start_mainmenu), this), TIME_TO_BACKGROUND_NUCLEAR_EVENT_END)
  }
}
gui_handlers.airRaidWndScene <- airRaidWndScene

return @(params) handlersManager.loadHandler(airRaidWndScene, params)
