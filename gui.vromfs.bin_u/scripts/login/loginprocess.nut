local exitGame = require("scripts/utils/exitGame.nut")

enum LOGIN_PROGRESS
{
  NOT_STARTED
  IN_LOGIN_WND
  INIT_ONLINE_BINARIES
  INIT_CONFIGS
  FINISHED
}

local matchingStageToLoginState = {
  [ONLINE_BINARIES_INITED] = LOGIN_STATE.ONLINE_BINARIES_INITED,
  [HANGAR_ENTERED] = LOGIN_STATE.HANGAR_LOADED
}

::online_init_stage_finished <- function online_init_stage_finished(stage, ...)
{
  if (stage in matchingStageToLoginState)
    ::g_login.addState(matchingStageToLoginState[stage])
}

class ::LoginProcess
{
  curProgress = LOGIN_PROGRESS.NOT_STARTED

  constructor(shouldCheckScriptsReload)
  {
    if (shouldCheckScriptsReload)
      restoreStateAfterScriptsReload()
    if (::g_login.isAuthorized())
      curProgress = LOGIN_PROGRESS.IN_LOGIN_WND

    ::subscribe_handler(this, ::g_listener_priority.LOGIN_PROCESS)
    nextStep()
  }

  function restoreStateAfterScriptsReload()
  {
    local curMState = ::get_online_client_cur_state()
    foreach(mState, lState in matchingStageToLoginState)
      if (mState & curMState)
        ::g_login.addState(lState)
  }

  function isValid()
  {
    return curProgress != LOGIN_PROGRESS.NOT_STARTED
        && curProgress < LOGIN_PROGRESS.FINISHED
  }

  function nextStep()
  {
    if (showVersionMsgBox())
      return
    curProgress++

    if (curProgress == LOGIN_PROGRESS.IN_LOGIN_WND)
      ::g_login.loadLoginHandler()
    else if (curProgress == LOGIN_PROGRESS.INIT_ONLINE_BINARIES)
    {
      //connect to matching
      local successCb = ::Callback(function()
                        {
                          ::g_login.addState(LOGIN_STATE.MATCHING_CONNECTED)
                        }, this)
      local errorCb   = ::Callback(function()
                        {
                          destroy()
                        }, this)

      ::g_matching_connect.connect(successCb, errorCb, false)
    }
    else if (curProgress == LOGIN_PROGRESS.INIT_CONFIGS)
    {
      ::g_login.initConfigs(
        ::Callback(function()
        {
          ::g_login.addState(LOGIN_STATE.CONFIGS_INITED)
        },
        this))
    }

    checkNextStep()
  }

  function checkNextStep()
  {
    if (curProgress == LOGIN_PROGRESS.IN_LOGIN_WND)
    {
      if (::g_login.isAuthorized())
        nextStep()
    }
    else if (curProgress == LOGIN_PROGRESS.INIT_ONLINE_BINARIES)
    {
      if (::g_login.isReadyToFullLoad())
        nextStep()
    }
    else if (curProgress == LOGIN_PROGRESS.INIT_CONFIGS)
    {
      if (::g_login.isLoggedIn())
        nextStep()
    }
  }

  function onEventLoginStateChanged(p)
  {
    checkNextStep()
  }

  function destroy()
  {
    if (isValid())
      curProgress = LOGIN_PROGRESS.NOT_STARTED
  }

  function showVersionMsgBox()
  {
    if (::is_version_equals_or_newer("1.77.0.0"))
      return false

    ::scene_msg_box("old exe version", null, ::loc("charServer/updateError/75"),
      [["exit", exitGame ]], "exit",
      { saved = true })
    return true
  }
}
