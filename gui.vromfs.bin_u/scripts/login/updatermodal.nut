local statsd = require("statsd")
local time = require("scripts/time.nut")
local { animBgLoad } = require("scripts/loading/animBg.nut")

class ::gui_handlers.UpdaterModal extends ::BaseGuiHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/login/updaterModal.blk"
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
  eta_sec = 0

  isCancel = false
  isCancelButtonVisible = false
  wasCancelButtonShownOnce = false
  isFinished = false

  onFinishCallback = null

  function initScreen()
  {
    showSceneBtn(buttonOkId, false)
    showSceneBtn(buttonCancelId, false)

    scene.findObject("updater_timer").setUserData(this)

    resetTimer()
    onUpdate(null, 0.0)

    updateText()

    if ( ! ::start_content_updater(configPath, this, onUpdaterCallback))
      onFinish()
  }

  function changeBg()
  {
    local dynamicBgContainer = scene.findObject("animated_bg_picture")
    if (::check_obj(dynamicBgContainer))
      animBgLoad("", dynamicBgContainer)
  }

  function resetTimer()
  {
    timer = timeToShowCancel
    showSceneBtn(buttonCancelId, false)
  }

  function onUpdaterCallback(cbType, p0, p1, p2)
  {
    if (isFinished || !isValid())
      return

    switch(cbType)
    {
    case ::UPDATER_CB_STAGE:
      stage = p0
      updateText()
      updateProgressbar()
      break;
    case ::UPDATER_CB_PROGRESS:
      percent = p0
      dspeed = p1
      eta_sec = p2
      updateText()
      updateProgressbar()
      break;
    case ::UPDATER_CB_ERROR:
      errorCode = p0
      break;
    case ::UPDATER_CB_FINISH:
      onFinish();
      break;
    }
  }

  function allowCancelCurrentStage()
  {
    if (stage == ::UPDATER_DOWNLOADING || stage == ::UPDATER_DOWNLOADING_YUP)
    {
      if (!isCancelButtonVisible)
      {
        showSceneBtn(buttonCancelId, true)
        isCancelButtonVisible = true
      }
      return true
    }

    if (isCancelButtonVisible)
    {
      showSceneBtn(buttonCancelId, false)
      isCancelButtonVisible = false
    }
    return false
  }

  function onUpdate(obj, dt)
  {
    bgTimer -= dt
    if(bgTimer <= 0)
    {
      changeBg()
      bgTimer = bgChangeInterval
    }

    timer -= dt
    if (timer < 0 && allowCancelCurrentStage())
    {
      if (!wasCancelButtonShownOnce)
      {
        statsd.send_counter("sq.updater.longdownload", 1)
        wasCancelButtonShownOnce = true
      }
    }
  }

  function updateProgressbar()
  {
    local blockObj = scene.findObject("loading_progress_box")
    if (!::checkObj(blockObj))
      return
    blockObj.setValue(100 * percent)
  }

  function onFinish()
  {
    isFinished = true

    if (errorCode < 0)
      goBack()
    else
    {
      local errorText = ::loc("updater/error/" + errorCode.tostring())
      msgBox("updater_error", errorText, [["ok", goBack ]], "ok")
    }
  }

  function updateText()
  {
    local text = ""
    local textSub = ""
    if (stage == ::UPDATER_DOWNLOADING)
      text = ::loc("updater/downloading")
    else
      text = ::loc("pl1/check_profile") //because we have all localizations

    if (stage == ::UPDATER_CHECKING_FAST || stage == ::UPDATER_CHECKING
      || stage == ::UPDATER_RESPATCH || stage == ::UPDATER_DOWNLOADING
      || stage == ::UPDATER_COPYING)
    {
      text += ": ";
      text += ::floor(percent)
      text += "%"
    }
    if (stage == ::UPDATER_DOWNLOADING)
    {
      if (dspeed > 0)
      {
        local meas = 0.0;
        local desc = ::loc("updater/dspeed/b");
        meas = dspeed / 1073741824.0; //GB
        if (meas > 0.5)
          desc = ::loc("updater/dspeed/gb");
        else
        {
          meas = dspeed / 1048576.0; //MB
          if (meas > 0.5)
            desc = ::loc("updater/dspeed/mb");
          else
          {
            meas = dspeed / 1024.0; //KB
            desc = meas > 0.5 ? ::loc("updater/dspeed/kb") : ::loc("updater/dspeed/b");
          }
        }
        textSub += time.secondsToString(eta_sec);
        textSub += ::format(" ( %.1f%s )", meas, desc);
      }
    }

    scene.findObject("msgText").setValue(text)
    scene.findObject("msgTextSub").setValue(textSub)
  }

  function onCancel()
  {
    isCancel = true
    statsd.send_counter("sq.updater.cancelled", 1)
    ::stop_content_updater()
    showSceneBtn(buttonCancelId, false)
  }

  function onEventSignOut()
  {
    ::stop_content_updater()
    statsd.send_counter("sq.updater.signedout", 1)
  }

  function afterModalDestroy()
  {
    if (onFinishCallback)
      onFinishCallback()
    ::g_login.addState(LOGIN_STATE.AUTHORIZED)
  }
}
