local time = require("scripts/time.nut")
local { openOptionsWnd } = require("scripts/options/handlers/optionsWnd.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")

::uploadLimit <- 3
::on_screenshot_saved <- null
::after_facebook_login <- null

const FACEBOOK_UPLOADS_SAVE_ID = "facebook/uploads"

::make_screenshot_and_do <- function make_screenshot_and_do(func, handler)
{
  on_screenshot_saved = (@(func, handler) function(saved_screenshot_filename) {
      if(handler)
      {
        ::fill_gamer_card(::get_profile_info(), "gc_", ::getLastGamercardScene())
        func.call(handler, saved_screenshot_filename)
      }
      on_screenshot_saved = null
    })(func, handler)
  ::fill_gamer_card({gold = ""}, "gc_", ::getLastGamercardScene())
  ::make_screenshot()
}

::make_facebook_login_and_do <- function make_facebook_login_and_do(func, handler)
{
  after_facebook_login = (@(func, handler) function() {
        if(handler && func)
          func.call(handler)
        after_facebook_login = null
      })(func, handler)
  if(!::facebook_is_logged_in())
    ::start_facebook_login()
  else
    after_facebook_login()
}

::on_facebook_link_finished <- function on_facebook_link_finished(result)
{
  ::on_facebook_destroy_waitbox()
  if (result == "")
    ::showInfoMsgBox(::loc("facebook/postFail"), "facebook_post_fail")

  return
}

::start_facebook_upload_screenshot <- function start_facebook_upload_screenshot(path)
{
  if (path == "")
    return
  dagor.debug("FACEBOOK UPLOAD: " + path)

  local uploadsBlk = ::load_local_account_settings(FACEBOOK_UPLOADS_SAVE_ID) ?? ::DataBlock()
  if (uploadsBlk?.postDate == time.getUtcDays())
  {
    local uploads = uploadsBlk % "path"
    if (uploads.len() >= uploadLimit)
    {
      local msgText = format(::loc("facebook/error_upload_limit"), uploadLimit);
      ::showInfoMsgBox(msgText, "facebook_upload_limit")
      return;
    }
    else
      foreach (p in uploads)
        if (path == p)
        {
          ::showInfoMsgBox(::loc("facebook/error_upload_once"), "facebook_upload")
          return;
        }
  }
  else
    ::save_local_account_settings(FACEBOOK_UPLOADS_SAVE_ID, null)

  ::scene_msg_box("facebook_login", null, ::loc("facebook/uploading"),
    [["cancel", function() {}]], "cancel", {cancel_fn = function() {}, waitAnim=true, delayedButtons = 10})
  ::facebook_upload_screenshot(path)
}

::on_facebook_upload_finished <- function on_facebook_upload_finished(path)
{
  on_facebook_destroy_waitbox()
  if (path == "")
    return

  local uploadsBlk = ::load_local_account_settings(FACEBOOK_UPLOADS_SAVE_ID) ?? ::DataBlock()
  uploadsBlk.path <- path // adding new slot
  if (type(uploadsBlk?.postDate) != "integer")
    uploadsBlk.postDate = time.getUtcDays()
  ::save_local_account_settings(FACEBOOK_UPLOADS_SAVE_ID, uploadsBlk)

  if (::current_base_gui_handler)
    ::current_base_gui_handler.msgBox("facebook_finish_upload_screenshot", ::loc("facebook/successUpload"), [["ok"]], "ok")
}

::on_facebook_destroy_waitbox <- function on_facebook_destroy_waitbox(unusedEventParams=null)
{
  local guiScene = ::get_gui_scene()
  if (!guiScene)
    return
  local facebook_obj = guiScene["facebook_login"]
  if (::checkObj(facebook_obj))
    guiScene.destroyElement(facebook_obj)

  ::broadcastEvent("CheckFacebookLoginStatus")
}

::on_facebook_login_finished <- function on_facebook_login_finished()
{
  if(::facebook_is_logged_in() && after_facebook_login)
      after_facebook_login()
  on_facebook_destroy_waitbox()

  if (::is_builtin_browser_active)
    ::close_browser_modal()
}

::start_facebook_login <- function start_facebook_login()
{
  if (isPlatformSony)
    return

  ::scene_msg_box("facebook_login", null, ::loc("facebook/connecting"),
                  [["cancel", function() {::facebook_cancel_login()}]],
                  "cancel",
                  {waitAnim=true, delayedButtons = 10}
                 )
  ::facebook_login()
}

::show_facebook_login_reminder <- function show_facebook_login_reminder()
{
  if (::is_unlocked(::UNLOCKABLE_ACHIEVEMENT, "facebook_like")
    || ::disable_network())
    return;

  local gmBlk = ::get_game_settings_blk()
  local daysCounter = gmBlk?.reminderFacebookLikeDays ?? 0
  local lastDays = ::loadLocalByAccount("facebook/lastDayFacebookLikeReminder", 0)
  local days = time.getUtcDays()
  if ( !lastDays || (daysCounter > 0 && days - lastDays > daysCounter) )
  {
    ::gui_start_modal_wnd(::gui_handlers.facebookReminderModal);
    ::saveLocalByAccount( "facebook/lastDayFacebookLikeReminder", days )
  }
}

::show_facebook_screenshot_button <- function show_facebook_screenshot_button(scene, show = true, id = "btn_upload_facebook_scrn")
{
  show = show && !isPlatformSony && ::has_feature("FacebookScreenshots")
  local fbObj = ::showBtn(id, show, scene)
  if (!::checkObj(fbObj))
    return

  fbObj.tooltip = ::format(::loc("mainmenu/facebookShareLimit"), ::uploadLimit)
}

class ::gui_handlers.facebookReminderModal extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    scene.findObject("award_name").setValue(::loc("options/facebookTitle"));
    scene.findObject("award_desc").setValue(format(::loc("facebook/reminderText"), ::get_unlock_reward("facebook_like")));
    scene.findObject("award_image")["background-image"] = "#ui/images/facebook_like.jpg?P1";
    scene.findObject("award_image")["height"] = "0.5w"
    scene.findObject("btn_ok").setValue(::loc("options/facebookLogin"));
    showSceneBtn("btn_upload_facebook_scrn", false)
  }

  function onOk()
  {
    openOptionsWnd("social")
    ::start_facebook_login()
  }

  function onUseDecorator() {}

  wndType = handlerType.MODAL
  sceneBlkName = "gui/showUnlock.blk"
}

::add_event_listener("DestroyEmbeddedBrowser", on_facebook_destroy_waitbox)
