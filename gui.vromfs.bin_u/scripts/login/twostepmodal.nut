local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")
local time = require("scripts/time.nut")
local statsd = require("statsd")

local authDataByTypes = {
  mail = {text = "#mainmenu/2step/confirmMail", img = "#ui/images/two_step_email.tga"}
  ga = {text = "#mainmenu/2step/confirmGA", img = "#ui/images/two_step_phone_ga.tga"}
  gp = {text = "#mainmenu/2step/confirmGP", img = "#ui/images/two_step_phone_gp.tga"}
  unknown = {text = "#mainmenu/2step/confirmUnknown", img = ""}
}

class ::gui_handlers.twoStepModal extends ::BaseGuiHandler
{
  wndType              = handlerType.MODAL
  sceneTplName         = "gui/login/twoStepModal"
  loginScene           = null
  continueLogin        = null
  currTime             = null

  focusArray = [ "loginbox_code" ]

  function getSceneTplView()
  {
    local isExt2StepAllowed = ::is_external_app_2step_allowed()
    local data = !isExt2StepAllowed && ::is_has_email_two_step_type_sync() ? authDataByTypes.mail
      : isExt2StepAllowed && ::is_has_wtassistant_two_step_type_sync() ? authDataByTypes.ga
      : isExt2StepAllowed && ::is_has_gaijin_pass_two_step_type_sync() ? authDataByTypes.gp
      : authDataByTypes.unknown

    return {
      verStatusText = data.text
      authTypeImg = data.img
      isShowRestoreLink = isExt2StepAllowed
      isRememberDevice = ::get_object_value(loginScene,"loginbox_code_remember_this_device", false)
      timerWidth = daguiFonts.getStringWidthPx("99:99:99", "fontNormal", guiScene)
    }
  }

  function initScreen()
  {
    setCurrTime(::get_charserver_time_sec())
    restoreFocus()
  }

  function setCurrTime(utcTime)
  {
    local timerObj = scene.findObject("currTimeText")
    if (!::check_obj(timerObj))
      return

    currTime = ::Timer(timerObj, 1, function(){
      timerObj.setValue(time.buildTimeStr(utcTime++, true))
    }, this, true)
  }

  function onSubmit(obj)
  {
    ::disable_autorelogin_once <- false
    statsd.send_counter("sq.game_start.request_login", 1, {login_type = "regular"})
    ::dagor.debug("Login: check_login_pass")
    local result = ::check_login_pass(
      ::get_object_value(loginScene, "loginbox_username",""),
      ::get_object_value(loginScene, "loginbox_password", ""), "",
      ::get_object_value(scene, "loginbox_code", ""),
      ::get_object_value(scene, "loginbox_code_remember_this_device", false),
      true)
    proceedAuth(result)
  }

  function showErrorMsg()
  {
    local txtObj = scene.findObject("verStatus")
    if (!::check_obj(txtObj))
      return

    local errorText = "".concat(::loc("mainmenu/2step/wrongCode"), ::loc("ui/colon"))
    local utcTime = ::get_charserver_time_sec()
    ::Timer(txtObj, 1, function(){
      txtObj.setValue(::colorize("badTextColor", "".concat(errorText,
        time.buildTimeStr(utcTime++, true))))
    }, this, true)

    currTime = null
    setCurrTime(utcTime)
    restoreFocus()
  }

  function proceedAuth(result)
  {
    switch (result)
    {
      case ::YU2_OK:
        continueLogin(::get_object_value(loginScene, "loginbox_username",""))
        break

      case ::YU2_2STEP_AUTH:
      case ::YU2_WRONG_2STEP_CODE:
        showErrorMsg()
        break

      default:
        ::error_message_box("yn1/connect_error", result,
        [
          ["exit", ::exit_game],
          ["tryAgain", null]
        ], "tryAgain", { cancel_fn = function() {}})
    }
  }
}

return {
  open = @(p) ::handlersManager.loadHandler(::gui_handlers.twoStepModal, p)
}
