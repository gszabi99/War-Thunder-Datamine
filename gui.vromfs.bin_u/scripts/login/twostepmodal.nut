from "%scripts/dagui_natives.nut" import check_login_pass
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let { set_disable_autorelogin_once } = require("loginState.nut")
let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { select_editbox, getObjValue } = require("%sqDagui/daguiUtil.nut")
let time = require("%scripts/time.nut")
let statsd = require("statsd")
let exitGamePlatform = require("%scripts/utils/exitGamePlatform.nut")
let { get_charserver_time_sec } = require("chard")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { isExternalApp2StepAllowed, isHasEmail2StepTypeSync, isHasWTAssistant2StepTypeSync, isHasGaijinPass2StepTypeSync } = require("auth_wt")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { addLoginState } = require("%scripts/login/loginManager.nut")
let { showErrorMessageBox } = require("%scripts/utils/errorMsgBox.nut")

local authDataByTypes = {
  mail = { text = "#mainmenu/2step/confirmMail", img = "#ui/images/two_step_email" }
  ga = { text = "#mainmenu/2step/confirmGA", img = "#ui/images/two_step_phone_ga" }
  gp = {
    getText = @() loc("mainmenu/2step/confirmPass", { passName = getCurCircuitOverride("passName", "Gaijin Pass") })
    img = "#ui/images/two_step_phone_gp"
  }
  unknown = { text = "#mainmenu/2step/confirmUnknown", img = "" }
}

gui_handlers.twoStepModal <- class (BaseGuiHandler) {
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/login/twoStepModal.tpl"
  loginScene           = null
  continueLogin        = null
  curTimeTimer         = null

  function getSceneTplView() {
    let isExt2StepAllowed = isExternalApp2StepAllowed()
    let data = !isExt2StepAllowed && isHasEmail2StepTypeSync() ? authDataByTypes.mail
      : isExt2StepAllowed && isHasWTAssistant2StepTypeSync() ? authDataByTypes.ga
      : isExt2StepAllowed && isHasGaijinPass2StepTypeSync() ? authDataByTypes.gp
      : authDataByTypes.unknown

    return {
      verStatusText = data?.getText() ?? data.text
      authTypeImg = data.img
      backgroundImg = "#ui/images/two_step_form_bg"
      isShowRestoreLink = isExt2StepAllowed
      isRememberDevice = getObjValue(this.loginScene, "loginbox_code_remember_this_device", false)
      timerWidth = daguiFonts.getStringWidthPx("99:99:99", "fontNormal", this.guiScene)
      signInTroublesURL = getCurCircuitOverride("signInTroublesURL", "#url/2step/signInTroubles")
      restoreProfileURL = "".concat(getCurCircuitOverride("restoreProfileURL", loc("url/2step/restoreProfile")), "?from=warthunder")
    }
  }

  function initScreen() {
    this.reinitCurTimeTimer()
    select_editbox(this.getObj("loginbox_code"))
  }

  function reinitCurTimeTimer() {
    this.curTimeTimer = null
    let timerObj = this.scene.findObject("currTimeText")
    if (!checkObj(timerObj))
      return

    let timerCb = @() timerObj.setValue(time.buildTimeStr(get_charserver_time_sec(), true))
    this.curTimeTimer = Timer(timerObj, 1, timerCb, this, true)
    timerCb()
  }

  function onSubmit(_obj) {
    set_disable_autorelogin_once(false)
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "regular" })
    log("Login: check_login_pass")
    addLoginState(LOGIN_STATE.LOGIN_STARTED)
    let result = check_login_pass(
      getObjValue(this.loginScene, "loginbox_username", ""),
      getObjValue(this.loginScene, "loginbox_password", ""), "",
      getObjValue(this.scene, "loginbox_code", ""),
      getObjValue(this.scene, "loginbox_code_remember_this_device", false),
      true)
    this.proceedAuth(result)
  }

  function showErrorMsg() {
    let txtObj = this.scene.findObject("verStatus")
    if (!checkObj(txtObj))
      return

    let errorText = "".concat(loc("mainmenu/2step/wrongCode"), loc("ui/colon"))
    let errorTimerCb = @() txtObj.setValue(colorize("badTextColor", "".concat(errorText,
        time.buildTimeStr(get_charserver_time_sec(), true))))
    Timer(txtObj, 1, errorTimerCb, this, true)
    errorTimerCb()

    
    this.reinitCurTimeTimer()
  }

  function proceedAuth(result) {
    if (YU2_OK == result) {
      this.continueLogin(getObjValue(this.loginScene, "loginbox_username", ""))
    }

    else if ( result == YU2_2STEP_AUTH || result == YU2_WRONG_2STEP_CODE) {
      this.showErrorMsg()
     }

    else {
      showErrorMessageBox("yn1/connect_error", result,
      [
        ["exit", exitGamePlatform],
        ["tryAgain", null]
      ], "tryAgain", { cancel_fn = function() {} })
    }
  }
}

return {
  open = @(p) handlersManager.loadHandler(gui_handlers.twoStepModal, p)
}