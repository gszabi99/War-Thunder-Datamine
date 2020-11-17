local contentStateModule = require("scripts/clientState/contentState.nut")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local { startLogout } = require("scripts/login/logout.nut")
local exitGame = require("scripts/utils/exitGame.nut")

::check_package_full <- function check_package_full(pack, silent = false)
{
  local res = true
  if (silent)
    res = ::have_package(pack)
  else
    res = ::check_package_and_ask_download(pack)

  res = res && (silent || ::check_members_pkg(pack))
  return res
}

::check_gamemode_pkg <- function check_gamemode_pkg(gm, silent = false)
{
  if (::isInArray(gm, [::GM_SINGLE_MISSION, ::GM_SKIRMISH, ::GM_DYNAMIC, ::GM_USER_MISSION]))
    return ::check_package_full("pkg_main", silent)

  return true
}

::check_diff_pkg <- function check_diff_pkg(diff, silent = false)
{
  foreach(d in [::DIFFICULTY_HARDCORE, ::DIFFICULTY_CUSTOM])
    if (diff == d || ::get_difficulty_name(d) == diff)
      return ::check_package_full("pkg_main", silent)
  return true
}

::get_pkg_loc_name <- function get_pkg_loc_name(pack, isShort = false)
{
  return ::loc("package/" + pack + (isShort ? "/short" : ""))
}

::checkReqContentByName <- function checkReqContentByName(ename, pack)
{
  if (::has_entitlement(ename) || ::has_feature(ename))
  {
    dagor.debug("[PACK] has entitlement "+ename+", checking for pack "+pack);
    local status = ::package_get_status(pack)
    if (status == ::PACKAGE_STATUS_NOT_EXIST)
      return pack
  }
  else
    dagor.debug("[PACK] don't have entitlement "+ename+", ignoring pack "+pack);

  return null
}

::checkReqContent <- function checkReqContent(ename, blk)
{
  if ("reqPack" in blk)
    return checkReqContentByName(ename, blk.reqPack)
  return null
}

::have_package <- function have_package(packName)
{
  if (!contentStateModule.isConsoleClientFullyDownloaded())
    return false
  return ::package_get_status(packName) == ::PACKAGE_STATUS_OK
}

::updateContentPacks <- function updateContentPacks()
{
  if (isPlatformSony || isPlatformXboxOne)
    return //no launcher there!

  if (!::g_login.isLoggedIn())
    return

  dagor.debug("[PACK] updateContentPacks called");

  local reqPacksList = []
  for(local i = reqPacksList.len() - 1; i >= 0; i--)
    if (::have_package(reqPacksList[i]))
      reqPacksList.remove(i)

  local pblk = ::DataBlock()
  ::get_shop_prices(pblk)
  foreach (ename, ent in pblk)
    ::u.appendOnce(checkReqContent(ename, ent), reqPacksList, true)

  local fBlk = ::get_game_settings_blk()?.features
  if (fBlk)
    foreach (fname, fdata in fBlk)
      ::u.appendOnce(checkReqContent(fname, fdata), reqPacksList, true)

  //workaround - reqPack is missing again in ents
  ::u.appendOnce(checkReqContentByName("usa_pacific_41_43", "hc_pacific"), reqPacksList, true)
  ::u.appendOnce(checkReqContentByName("jpn_pacific_41_43", "hc_pacific"), reqPacksList, true)

  local text = ""
  local langPack = "pkg_" + ::get_current_language()
  if (!::have_package(langPack))
  {
    if (!reqPacksList.len())
      text = ::loc("yn1/have_new_content_lang")
    ::u.appendOnce(langPack, reqPacksList)
  }

  local canceledBlk = ::loadLocalByAccount("canceledPacks")
  if (canceledBlk)
    for(local i = reqPacksList.len() - 1; i >= 0; i--)
      if (reqPacksList[i] in canceledBlk)
        reqPacksList.remove(i)

  if (!reqPacksList.len())
    return

  if (!::has_feature("Packages"))
    return request_packages(reqPacksList)

  if (text=="")
  {
    text = ::loc("yn1/have_new_content")
    local pText = ""
    foreach(pack in reqPacksList)
      pText += ((pText=="")? "" : ", ") + ::colorize("activeTextColor", ::get_pkg_loc_name(pack))
    text += "\n" + pText
  }

  ::scene_msg_box("new_content", null, text,
    [["ok",
      (@(reqPacksList) function() {
        ::request_packages_and_restart(reqPacksList)
      })(reqPacksList)],
     ["cancel",
       (@(reqPacksList) function() {
         local canceledPacks = ::loadLocalByAccount("canceledPacks") ?? ::DataBlock()
         foreach(pack in reqPacksList)
           if (!(pack in canceledPacks))
             canceledPacks[pack] = true
         ::saveLocalByAccount("canceledPacks", canceledPacks)
       })(reqPacksList)]
    ],
    "ok")
}

::request_packages <- function request_packages(packList)
{
  foreach(pack in packList)
    ::package_request(pack)
}

::request_packages_and_restart <- function request_packages_and_restart(packList)
{
  ::request_packages(packList)
  if (::target_platform == "linux64")
    return ::quit_and_run_cmd("./launcher -silentupdate")
  else if (::target_platform == "macosx")
    return ::quit_and_run_cmd("../../../../MacOS/launcher -silentupdate")
  if (::is_platform_windows)
  {
    local exec = "launcher.exe -silentupdate";

    return ::quit_and_run_cmd(exec)
  }

  dagor.debug("ERROR: new_content action not implemented");
}

::asked_packages <- {}
::is_asked_pack <- function is_asked_pack(pack, askTag = null)
{
  local checkName = pack + (askTag? ("/" + askTag) : "")
  return checkName in ::asked_packages
}
::set_asked_pack <- function set_asked_pack(pack, askTag = null)
{
  ::asked_packages[pack] <- true
  if (askTag)
    ::asked_packages[pack + "/" + askTag] <- true
}

::check_package_and_ask_download <- function check_package_and_ask_download(pack, msg = null, continueFunc = null, owner = null, askTag = null, cancelFunc = null)
{
  if (::have_package(pack)
      || (continueFunc && ::is_asked_pack(pack, askTag)))
  {
    if (continueFunc)
      ::call_for_handler(owner, continueFunc)
    return true
  }

  if (continueFunc && !::can_download_package())
  {
    ::call_for_handler(owner, continueFunc)
    return true
  }

  local _msg = msg
  local isFullClient = contentStateModule.getConsoleClientDownloadStatusOnStart()
  if (isPlatformSony || isPlatformXboxOne)
  {
    if (!isFullClient)
      _msg = contentStateModule.getClientDownloadProgressText()
  }
  else
  {
    if (::u.isEmpty(_msg))
    {
      local ending = ""
      if (!::can_download_package())
        ending = "/info"
      else if (continueFunc)
        ending = "/continue"
      _msg = ::loc("msgbox/no_package" + ending)
    }
    _msg = ::format(_msg, ::colorize("activeTextColor", ::get_pkg_loc_name(pack)))
  }

  local defButton = ::can_download_package()? "cancel" : "ok"
  local buttons = [[defButton, (@(cancelFunc, owner) function() {
                     if (cancelFunc)
                       ::call_for_handler(owner, cancelFunc)
                   })(cancelFunc, owner)]
                  ]

  if (isPlatformSony)
  {
    if (!isFullClient && contentStateModule.isConsoleClientFullyDownloaded())
    {
      buttons.insert(0, ["apply", function() { ::ps4_update_gui() }])
      defButton = "apply"
    }
  }
  else if (::can_download_package() && !::is_platform_xbox)
  {
    buttons.insert(0, ["download", (@(pack) function() {
                       ::request_packages_and_restart([pack])
                     })(pack)])
  }

  if (continueFunc)
  {
    defButton = "continue"
    buttons.append(["continue", (@(continueFunc, owner) function() {
                     ::call_for_handler(owner, continueFunc)
                   })(continueFunc, owner)])
  }
  ::scene_msg_box("req_new_content", null, _msg, buttons, defButton)
  ::set_asked_pack(pack, askTag)
  return false
}

::can_download_package <- function can_download_package()
{
  return !::is_vendor_tencent()
}

::check_package_and_ask_download_once <- function check_package_and_ask_download_once(pack, askTag = null, msg = null)
{
  if (!::is_asked_pack(pack, askTag))
    ::check_package_and_ask_download(pack, msg, null, null, askTag)
}

::check_members_pkg <- function check_members_pkg(pack)
{
  local members = ::g_squad_manager.checkMembersPkg(pack)
  if (!members.len())
    return true

  local mText = ""
  foreach(m in members)
    mText += ((mText == "")? "" : ", ") + m.name
  local msg = ::loc("msgbox/members_no_package", {
                      members = ::colorize("userlogColoredText", mText)
                      package = ::colorize("activeTextColor", ::get_pkg_loc_name(pack))
                    })
  ::showInfoMsgBox(msg, "members_req_new_content")
}

::check_localization_package_and_ask_download <- function check_localization_package_and_ask_download(langId = null)
{
  langId = langId || ::get_current_language()
  local pack = "pkg_" + langId
  if (::have_package(pack))
    return

  local params = null
  if (langId != "English")
  {
    local messageEn = ::g_string.stripTags(::loc("yn1/have_new_content_lang/en"))
    local buttonsEn = ::g_string.stripTags(::format("[%s] = %s, [%s] = %s",
      ::loc("msgbox/btn_download"), ::loc("msgbox/btn_download/en"),
      ::loc("msgbox/btn_cancel"), ::loc("msgbox/btn_cancel/en")))
    params = {
      data_below_text = "tdiv { flow:t='vertical' textarea {left:t='pw/2-w/2' position:t='relative' text:t='" +
        messageEn + "'} textarea {left:t='pw/2-w/2' position:t='relative' text:t='" + buttonsEn + "'} }"
    }
  }

  ::scene_msg_box("req_pkg_locatization", null, ::loc("yn1/have_new_content_lang"),
    [["download", (@(pack) function() { ::request_packages_and_restart([pack]) })(pack)], ["cancel"]], "cancel", params)
}

::check_speech_country_unit_localization_package_and_ask_download <- function check_speech_country_unit_localization_package_and_ask_download()
{
  local reqPacksList = []

  foreach(langId, langData in ::g_language.langsById)
  {
    if (!langData.hasUnitSpeech)
      continue

    local langPack = "pkg_" + langId
    if (!::have_package(langPack))
      reqPacksList.append(langPack)
  }

  if (reqPacksList.len() == 0)
    return

  ::scene_msg_box(
    "new_content",
    null,
    ::loc("yn1/have_new_crews_content_lang"),
    [
      [
        "ok",
        (@(reqPacksList) function() {
          ::request_packages_and_restart(reqPacksList)
        })(reqPacksList)
      ],
      ["cancel", function() {}]
    ],
    "ok"
  )
}

::restart_to_launcher <- function restart_to_launcher()
{
  if (isPlatformSony)
    return startLogout()
  else if (::is_platform_xbox)
    return exitGame()
  else if (::target_platform == "linux64")
    return ::quit_and_run_cmd("./launcher -silentupdate")
  else if (::target_platform == "macosx")
    return ::quit_and_run_cmd("../../../../MacOS/launcher -silentupdate")
  if (::is_platform_windows)
  {
    local exec = "launcher.exe -silentupdate";

    return ::quit_and_run_cmd(exec)
  }

  dagor.debug("ERROR: restart_to_launcher action not implemented");
}


::error_load_model_and_restart <- function error_load_model_and_restart(model)
{
  local _msg = ::loc("msgbox/no_package/info")
  _msg = ::format(_msg, ::colorize("activeTextColor", model))

  ::scene_msg_box(
    "new_content",
    null,
    _msg,
    [
      [
        "exit",
        (function() {
          ::restart_to_launcher()
        })
      ]
    ],
    "exit"
  )

}
