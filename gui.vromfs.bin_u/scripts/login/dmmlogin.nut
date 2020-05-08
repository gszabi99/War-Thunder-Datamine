local statsd = require("statsd")
local { animBgLoad } = require("scripts/loading/animBg.nut")

class ::gui_handlers.LoginWndHandlerDMM extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"

  function initScreen()
  {
    animBgLoad()
    ::setVersionText()
    ::setProjectAwards(this)

    guiScene.performDelayed(this, function() { doLogin() })
  }

  function doLogin()
  {
    ::dagor.debug("DMM Login: check_login_pass")
    ::dagor.debug("DMM Login: dmm_user_id " + ::dgs_get_argv("dmm_user_id"))
    ::dagor.debug("DMM Login: dmm_token " + ::dgs_get_argv("dmm_token"))
    statsd.send_counter("sq.game_start.request_login", 1, {login_type = "dmm"})
    local ret = ::check_login_pass(::dgs_get_argv("dmm_user_id"),
      ::dgs_get_argv("dmm_token"), "749130", "dmm", false, false)
    proceedAuthorizationResult(ret)
  }

  function proceedAuthorizationResult(result)
  {
    if (!::checkObj(scene)) //check_login_pass is not instant
      return

    switch (result)
    {
      case ::YU2_OK:
        ::set_login_pass("", "", 0)
        ::g_login.addState(LOGIN_STATE.AUTHORIZED)
        break
      case ::YU2_NOT_FOUND:
        msgBox("dmm_error_not_found_user", ::loc("yn1/error/DMM_NOT_FOUND", {link = ::loc("warthunder_dmm_link")}),
        [
          ["exit", ::exit_game ],
          ["tryAgain", ::Callback(doLogin, this)]
        ], "tryAgain")
        break
      default:
        ::error_message_box("yn1/connect_error", result,
        [
          ["exit", ::exit_game],
          ["tryAgain", ::Callback(doLogin, this)]
        ], "tryAgain")
    }
  }

  function goBack(obj) {}
}
