from "%scripts/dagui_natives.nut" import get_difficulty_name, has_entitlement, ps4_update_gui
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import call_for_handler

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { getLocalLanguage } = require("language")
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { format } = require("string")
let contentStateModule = require("%scripts/clientState/contentState.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { is_fully_translated } = require("acesInfo")
let DataBlock = require("DataBlock")
let { stripTags } = require("%sqstd/string.nut")
let { get_game_settings_blk } = require("blkGetters")
let { langsById } = require("%scripts/langUtils/language.nut")
let { getShopPriceBlk } = require("%scripts/onlineShop/onlineShopState.nut")
let { getContentPackStatus, requestContentPack, ContentPackStatus } = require("contentpacks")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

function getPkgLocName(pack, isShort = false) {
  return loc(isShort ? $"package/{pack}/short" : $"package/{pack}")
}


function check_members_pkg(pack) {
  let members = g_squad_manager.checkMembersPkg(pack)
  if (!members.len())
    return true

  let mText = ", ".join(members.reduce(@(acc, m) acc.append(m.name), []))
  local msg = loc("msgbox/members_no_package", {
                      members = colorize("userlogColoredText", mText)
                      package = colorize("activeTextColor", getPkgLocName(pack))
                    })
  showInfoMsgBox(msg, "members_req_new_content")
}

function have_package(packName) {
  if (!contentStateModule.isConsoleClientFullyDownloaded())
    return false
  return getContentPackStatus(packName) == ContentPackStatus.OK
}

function checkPackageFull(pack, silent = false) {
  local res = true
  if (silent)
    res = have_package(pack)
  else
    res = ::check_package_and_ask_download(pack)

  res = res && (silent || check_members_pkg(pack))
  return res
}

function check_gamemode_pkg(gm, silent = false) {
  if (isInArray(gm, [GM_SINGLE_MISSION, GM_SKIRMISH, GM_DYNAMIC, GM_USER_MISSION]))
    return checkPackageFull("pkg_main", silent)

  return true
}

function check_diff_pkg(diff, silent = false) {
  foreach (d in [DIFFICULTY_HARDCORE, DIFFICULTY_CUSTOM])
    if (diff == d || get_difficulty_name(d) == diff)
      return checkPackageFull("pkg_main", silent)
  return true
}

function checkReqContentByName(ename, pack) {
  if (has_entitlement(ename) || hasFeature(ename)) {
    log($"[PACK] has entitlement {ename }, checking for pack {pack}");
    let status = getContentPackStatus(pack)
    if (status == ContentPackStatus.MISSING)
      return pack
  }
  else
    log($"[PACK] don't have entitlement {ename}, ignoring pack {pack}");

  return null
}

function checkReqContent(ename, blk) {
  if ("reqPack" in blk)
    return checkReqContentByName(ename, blk.reqPack)
  return null
}

function request_packages(packList) {
  foreach (pack in packList)
    requestContentPack(pack)
}

function request_packages_and_restart(packList) {
  request_packages(packList)
  if (platformId == "linux64")
    return ::quit_and_run_cmd("./launcher -silentupdate")
  else if (platformId == "macosx")
    return ::quit_and_run_cmd("../../../../MacOS/launcher -silentupdate")
  if (is_platform_windows) {
    let exec = "launcher.exe -silentupdate";

    return ::quit_and_run_cmd(exec)
  }

  log("ERROR: new_content action not implemented");
}


::updateContentPacks <- function updateContentPacks() {
  if (isPlatformSony || isPlatformXboxOne)
    return //no launcher there!

  if (!isLoggedIn.get())
    return

  log("[PACK] updateContentPacks called");

  let reqPacksList = []
  for (local i = reqPacksList.len() - 1; i >= 0; i--)
    if (have_package(reqPacksList[i]))
      reqPacksList.remove(i)

  eachBlock(getShopPriceBlk(),
    @(b, n) u.appendOnce(checkReqContent(n, b), reqPacksList, true))
  eachBlock(get_game_settings_blk()?.features,
    @(b, n) u.appendOnce(checkReqContent(n, b), reqPacksList, true))

  //workaround - reqPack is missing again in ents
  u.appendOnce(checkReqContentByName("usa_pacific_41_43", "hc_pacific"), reqPacksList, true)
  u.appendOnce(checkReqContentByName("jpn_pacific_41_43", "hc_pacific"), reqPacksList, true)

  local text = ""
  let langId = getLocalLanguage()
  let langPack = $"pkg_{langId}"
  if (!have_package(langPack) && is_fully_translated(langId)) {
    if (!reqPacksList.len())
      text = loc("yn1/have_new_content_lang")
    u.appendOnce(langPack, reqPacksList)
  }

  let canceledBlk = loadLocalByAccount("canceledPacks")
  if (canceledBlk)
    for (local i = reqPacksList.len() - 1; i >= 0; i--)
      if (reqPacksList[i] in canceledBlk)
        reqPacksList.remove(i)

  if (!reqPacksList.len())
    return

  if (!hasFeature("Packages"))
    return request_packages(reqPacksList)

  if (text == "") {
    text = loc("yn1/have_new_content")
    let pText = ", ".join(reqPacksList.reduce(@(acc, pack) acc.append(colorize("activeTextColor", getPkgLocName(pack))), []))
    text = "".concat(text, "\n", pText)
  }

  scene_msg_box("new_content", null, text,
    [["ok",
      function() {
        request_packages_and_restart(reqPacksList)
      }],
     ["cancel",
       function() {
         let canceledPacks = loadLocalByAccount("canceledPacks") ?? DataBlock()
         foreach (pack in reqPacksList)
           if (!(pack in canceledPacks))
             canceledPacks[pack] = true
         saveLocalByAccount("canceledPacks", canceledPacks)
       }]
    ],
    "ok")
}


let asked_packages = {}
function is_asked_pack(pack, askTag = null) {
  let checkName = askTag!=null ? $"{pack}/{askTag}" : pack
  return checkName in asked_packages
}

function set_asked_pack(pack, askTag = null) {
  asked_packages[pack] <- true
  if (askTag)
    asked_packages[$"{pack}/{askTag}" ] <- true
}

::check_package_and_ask_download <- function check_package_and_ask_download(pack, msg = null, continueFunc = null, owner = null, askTag = null, cancelFunc = null) {
  if (have_package(pack)
      || (continueFunc && is_asked_pack(pack, askTag))) {
    if (continueFunc)
      call_for_handler(owner, continueFunc)
    return true
  }

  local _msg = msg
  let isFullClient = contentStateModule.getConsoleClientDownloadStatusOnStart()
  if (isPlatformSony || isPlatformXboxOne) {
    if (!isFullClient)
      _msg = contentStateModule.getClientDownloadProgressText()
  }
  else {
    if (u.isEmpty(_msg)) {
      let ending = continueFunc ? "/continue" : ""
      _msg = loc($"msgbox/no_package{ending}")
    }
    _msg = format(_msg, colorize("activeTextColor", getPkgLocName(pack)))
  }

  local defButton = "cancel"
  let buttons = [[defButton,  function() {
                     if (cancelFunc)
                       call_for_handler(owner, cancelFunc)
                   }]
                  ]

  if (isPlatformSony) {
    if (!isFullClient && contentStateModule.isConsoleClientFullyDownloaded()) {
      buttons.insert(0, ["apply", function() { ps4_update_gui() }])
      defButton = "apply"
    }
  }
  else if (!is_platform_xbox) {
    buttons.insert(0, ["download",  function() {
                       request_packages_and_restart([pack])
                     }])
  }

  if (continueFunc) {
    defButton = "continue"
    buttons.append(["continue",  function() {
                     call_for_handler(owner, continueFunc)
                   }])
  }
  scene_msg_box("req_new_content", null, _msg, buttons, defButton)
  set_asked_pack(pack, askTag)
  return false
}

function checkPackageAndAskDownloadOnce(pack, askTag = null, msg = null) {
  if (!is_asked_pack(pack, askTag))
    ::check_package_and_ask_download(pack, msg, null, null, askTag)
}

::check_localization_package_and_ask_download <- function check_localization_package_and_ask_download(langId = null) {
  langId = langId ?? getLocalLanguage()
  let pack = $"pkg_{langId}"
  if (have_package(pack) || !is_fully_translated(langId))
    return

  local params = null
  if (langId != "English") {
    let messageEn = stripTags(loc("yn1/have_new_content_lang/en"))
    let buttonsEn = stripTags(format("[%s] = %s, [%s] = %s",
      loc("msgbox/btn_download"), loc("msgbox/btn_download/en"),
      loc("msgbox/btn_cancel"), loc("msgbox/btn_cancel/en")))
    params = {
      data_below_text = "".concat("tdiv { flow:t='vertical' textarea {left:t='pw/2-w/2' position:t='relative' text:t='",
        messageEn, "'} textarea {left:t='pw/2-w/2' position:t='relative' text:t='", buttonsEn, "'} }")
    }
  }

  scene_msg_box("req_pkg_locatization", null, loc("yn1/have_new_content_lang"),
    [["download", function() { request_packages_and_restart([pack]) }], ["cancel"]], "cancel", params)
}

function checkSpeechCountryUnitLocalizationPackageAndAskDownload() {
  let reqPacksList = []

  foreach (langId, langData in langsById) {
    if (!langData.hasUnitSpeech)
      continue

    let langPack = $"pkg_{langId}"
    if (!have_package(langPack))
      reqPacksList.append(langPack)
  }

  if (reqPacksList.len() == 0)
    return

  scene_msg_box(
    "new_content",
    null,
    loc("yn1/have_new_crews_content_lang"),
    [
      [
        "ok",
        @() request_packages_and_restart(reqPacksList)
      ],
      ["cancel", function() {}]
    ],
    "ok"
  )
}

function restart_to_launcher() {
  if (isPlatformSony)
    return startLogout()
  else if (is_platform_xbox)
    return exitGame()
  else if (platformId == "linux64")
    return ::quit_and_run_cmd("./launcher -silentupdate")
  else if (platformId == "macosx")
    return ::quit_and_run_cmd("../../../../MacOS/launcher -silentupdate")
  if (is_platform_windows) {
    let exec = "launcher.exe -silentupdate";

    return ::quit_and_run_cmd(exec)
  }

  log("ERROR: restart_to_launcher action not implemented");
}


::error_load_model_and_restart <- function error_load_model_and_restart(model) {
  local _msg = loc("msgbox/no_package/info")
  _msg = format(_msg, colorize("activeTextColor", model))

  scene_msg_box(
    "new_content",
    null,
    _msg,
    [
      [
        "exit",
        (function() {
          restart_to_launcher()
        })
      ]
    ],
    "exit"
  )

}
addPromoAction("content_pack", @(_handler, params, _obj) ::check_package_and_ask_download(params?[0] ?? ""),
  @(params) hasFeature("Packages") && !have_package(params?[0] ?? ""))

::have_package <- have_package
::check_gamemode_pkg <- check_gamemode_pkg
::check_diff_pkg <- check_diff_pkg

return {
  getPkgLocName
  have_package
  checkPackageFull
  check_gamemode_pkg
  check_diff_pkg
  checkSpeechCountryUnitLocalizationPackageAndAskDownload
  checkPackageAndAskDownloadOnce
}