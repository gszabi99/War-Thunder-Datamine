//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { floor } = require("math")

let statsd = require("statsd")
let time = require("%scripts/time.nut")
let eventbus = require("eventbus")
let { animBgLoad } = require("%scripts/loading/animBg.nut")

// contentUpdater module is optional and don't available on PC
let contentUpdater = require_optional("contentUpdater")
if (contentUpdater == null)
  return

let { start_updater_with_config_once, stop_updater,
      UPDATER_EVENT_STAGE, UPDATER_EVENT_PROGRESS, UPDATER_EVENT_ERROR, UPDATER_EVENT_FINISH,
      UPDATER_DOWNLOADING, UPDATER_DOWNLOADING_YUP, UPDATER_CHECKING_FAST, UPDATER_CHECKING,
      UPDATER_RESPATCH, UPDATER_COPYING } = contentUpdater

const ContentUpdaterEventId = "contentupdater.modal.event"

eventbus.subscribe(ContentUpdaterEventId, function (evt) {
  let handler = handlersManager.findHandlerClassInScene(gui_handlers.UpdaterModal)
  if ((handler?.isValid() ?? false))
    handler?.onUpdaterCallback(evt)
})

gui_handlers.UpdaterModal <- class extends ::BaseGuiHandler {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/login/updaterModal.blk"
  timeToShowCancel = 600
  timer = -1

  bgChangeInterval = 300
  bgTimer = -1

  buttonCancelId = "btn_cancel"
  buttonOkId = "btn_ok"

  configPath = ""

  stage = -1
  errorCode = -1

  percent = 0
  dspeed = 0
  etaSec = 0

  isCancel = false
  isCancelButtonVisible = false
  wasCancelButtonShownOnce = false
  isFinished = false

  onFinishCallback = null

  function initScreen() {
    this.showSceneBtn(this.buttonOkId, false)
    this.showSceneBtn(this.buttonCancelId, false)

    this.scene.findObject("updater_timer").setUserData(this)

    this.resetTimer()
    this.onUpdate(null, 0.0)

    this.updateText()

    if (!start_updater_with_config_once(this.configPath, ContentUpdaterEventId))
      this.onFinish()
  }

  function changeBg() {
    let dynamicBgContainer = this.scene.findObject("animated_bg_picture")
    if (checkObj(dynamicBgContainer))
      animBgLoad("", dynamicBgContainer)
  }

  function resetTimer() {
    this.timer = this.timeToShowCancel
    this.showSceneBtn(this.buttonCancelId, false)
  }

  function onUpdaterCallback(evt) {
    if (this.isFinished || !this.isValid())
      return
    let { eventType } = evt
    switch (eventType) {
    case UPDATER_EVENT_STAGE:
      this.stage = evt?.stage
      this.updateText()
      this.updateProgressbar()
      break;
    case UPDATER_EVENT_PROGRESS:
      this.percent = evt?.percent
      this.dspeed  = evt?.dspeed
      this.etaSec  = evt?.etaSec
      this.updateText()
      this.updateProgressbar()
      break;
    case UPDATER_EVENT_ERROR:
      this.errorCode = evt?.error
      break;
    case UPDATER_EVENT_FINISH:
      this.onFinish()
      break;
    }
  }

  function allowCancelCurrentStage() {
    if (this.stage == UPDATER_DOWNLOADING || this.stage == UPDATER_DOWNLOADING_YUP) {
      if (!this.isCancelButtonVisible) {
        this.showSceneBtn(this.buttonCancelId, true)
        this.isCancelButtonVisible = true
      }
      return true
    }

    if (this.isCancelButtonVisible) {
      this.showSceneBtn(this.buttonCancelId, false)
      this.isCancelButtonVisible = false
    }
    return false
  }

  function onUpdate(_obj, dt) {
    this.bgTimer -= dt
    if (this.bgTimer <= 0) {
      this.changeBg()
      this.bgTimer = this.bgChangeInterval
    }

    this.timer -= dt
    if (this.timer < 0 && this.allowCancelCurrentStage()) {
      if (!this.wasCancelButtonShownOnce) {
        statsd.send_counter("sq.updater.longdownload", 1)
        this.wasCancelButtonShownOnce = true
      }
    }
  }

  function updateProgressbar() {
    let blockObj = this.scene.findObject("loading_progress_box")
    if (!checkObj(blockObj))
      return
    blockObj.setValue(100 * this.percent)
  }

  function onFinish() {
    if (this.isFinished)
      return
    this.isFinished = true

    if (this.errorCode < 0)
      this.goBack()
    else {
      let errorText = loc("updater/error/" + this.errorCode.tostring())
      this.msgBox("updater_error", errorText, [["ok", this.goBack ]], "ok")
    }
  }

  function updateText() {
    let { stage, dspeed, etaSec } = this //-ident-hides-ident
    local text = ""
    local textSub = ""
    if (stage == UPDATER_DOWNLOADING)
      text = loc("updater/downloading")
    else
      text = loc("pl1/check_profile") //because we have all localizations

    if (stage == UPDATER_CHECKING_FAST || stage == UPDATER_CHECKING
      || stage == UPDATER_RESPATCH || stage == UPDATER_DOWNLOADING
      || stage == UPDATER_COPYING) {
      text += ": ";
      text += floor(this.percent)
      text += "%"
    }
    if (stage == UPDATER_DOWNLOADING) {
      if (dspeed > 0) {
        local meas = 0.0;
        local desc = loc("updater/dspeed/b");
        meas = dspeed / 1073741824.0; //GB
        if (meas > 0.5)
          desc = loc("updater/dspeed/gb");
        else {
          meas = dspeed / 1048576.0; //MB
          if (meas > 0.5)
            desc = loc("updater/dspeed/mb");
          else {
            meas = dspeed / 1024.0; //KB
            desc = meas > 0.5 ? loc("updater/dspeed/kb") : loc("updater/dspeed/b");
          }
        }
        textSub += time.secondsToString(etaSec);
        textSub += format(" ( %.1f%s )", meas, desc);
      }
    }

    this.scene.findObject("msgText").setValue(text)
    this.scene.findObject("msgTextSub").setValue(textSub)
  }

  function onCancel() {
    this.isCancel = true
    statsd.send_counter("sq.updater.cancelled", 1)
    stop_updater()
    this.showSceneBtn(this.buttonCancelId, false)
  }

  function onEventSignOut() {
    stop_updater()
    statsd.send_counter("sq.updater.signedout", 1)
  }

  function afterModalDestroy() {
    if (this.onFinishCallback)
      this.onFinishCallback()
    ::g_login.addState(LOGIN_STATE.AUTHORIZED)
  }
}
