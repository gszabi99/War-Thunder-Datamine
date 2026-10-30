import "%scripts/clientState/contentState.nut" as contentStateModule
import "%scripts/utils/exitGamePlatform.nut" as exitGamePlatform
import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%scripts/squads/squadState.nut" import checkMembersPkg
from "%scripts/clientState/localProfileDeprecated.nut" import loadLocalByAccount, saveLocalByAccount
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%sqstd/platform.nut" import is_windows, platformId, is_gdk, isSony, isXbox
from "%scripts/login/logout.nut" import startLogout
from "%scripts/promo/promoActions.nut" import addPromoAction
from "%scripts/langUtils/language.nut" import needCheckLangPack
from "%scripts/onlineShop/onlineShopState.nut" import getShopPriceBlk
from "%scripts/time.nut" import TIME_DAY_IN_SECONDS
from "%scripts/clientState/clientStates.nut" import getFromSettingsBlk
from "%appGlobals/login/loginState.nut" import isLoggedIn, isProfileReceived
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "eventbus" import eventbus_subscribe
from "language" import getLocalLanguage
from "string" import format
from "%sqstd/datablock.nut" import eachBlock, convertBlk
from "acesInfo" import is_fully_translated
from "%sqStdLibs/helpers/daguiString.nut" import stripTags
from "blkGetters" import get_game_settings_blk
from "contentpacks" import getContentPackStatus, requestContentPack, ContentPackStatus
from "chard" import get_charserver_time_sec
from "%scripts/dagui_natives.nut" import get_difficulty_name, has_entitlement, ps4_update_gui, direct_launch
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%globalScripts/difficultyConsts.nut" import *
from "%scripts/utils_sa.nut" import call_for_handler
from "app" import exitGame
from "console" import register_command

let { langsById } = require("%scripts/langUtils/language.nut")
let logC = require("%sqstd/log.nut")().with_prefix("[PACK] ")


let OFFER_DOWNLOAD_PACK_TIME_SEC = 14 * TIME_DAY_IN_SECONDS

let { isConsoleContentPackCanBeChecked, isPackReadyCached, refreshPacks,
  requestConsoleContentPackInstall, gatherConsolePacksProgress } = contentStateModule

function getPkgLocName(pack, isShort = false) {
  return loc(isShort ? $"package/{pack}/short" : $"package/{pack}")
}

function quit_and_run_cmd(cmd) {
  direct_launch(cmd) 
  exitGame()
}
register_command(quit_and_run_cmd, "quit_and_run_cmd")

function check_members_pkg(pack) {
  let members = checkMembersPkg(pack)
  if (!members.len())
    return true

  let mText = ", ".join(members.reduce(@(acc, m) acc.append(m.name), []))
  local msg = loc("msgbox/members_no_package", {
                      members = colorize("userlogColoredText", mText)
                      package = colorize("activeTextColor", getPkgLocName(pack))
                    })
  showInfoMsgBox(msg, "members_req_new_content")
}

function havePackage(packName) {
  if (!contentStateModule.isConsoleClientFullyDownloaded())
    return false

  if (isSony || isXbox) {
    if (isConsoleContentPackCanBeChecked(packName))
      return isPackReadyCached(packName)

    return true
  }

  return getContentPackStatus(packName) == ContentPackStatus.OK
}

local askedPackages = null
function initAskedPackagesOnce() {
  if (askedPackages != null || !isProfileReceived.get())
    return

  let loadedData = loadLocalAccountSettings("askedPackages")
  askedPackages = loadedData != null ? convertBlk(loadedData) : {}
}

function isAskedPack(pack) {
  initAskedPackagesOnce()
  return (askedPackages?[pack] ?? 0) + OFFER_DOWNLOAD_PACK_TIME_SEC > get_charserver_time_sec()
}

function setAskedPack(packs) {
  initAskedPackagesOnce()
  foreach (pack in packs)
    askedPackages[pack] <- get_charserver_time_sec()
  saveLocalAccountSettings("askedPackages", askedPackages)
}

function request_packages(packList) {
  foreach (pack in packList) {
    if (isConsoleContentPackCanBeChecked(pack))
      requestConsoleContentPackInstall(pack)
    else
      requestContentPack(pack)
  }
}

function request_packages_and_restart(packList) {
  request_packages(packList)
  if (platformId == "linux64")
    return quit_and_run_cmd("./launcher -silentupdate")
  else if (platformId == "macosx")
    return quit_and_run_cmd("../../../../MacOS/launcher -silentupdate")
  if (is_windows) {
    let exec = "launcher.exe -silentupdate";

    return quit_and_run_cmd(exec)
  }

  log("ERROR: new_content action not implemented");
}

function checkPackageAndAskDownloadImpl(packs, msg, continueFunc, owner, cancelFunc, progress, allowContinue) {
  packs = packs.filter(@(pack) !havePackage(pack))
  if (packs.len() == 0) {
    if (continueFunc)
      call_for_handler(owner, continueFunc)
    return true
  }

  local defButton = "cancel"
  let buttons = []

  local needShowContinueButton = true
  local _msg = msg
  let isFullClient = contentStateModule.getConsoleClientDownloadStatusOnStart()
  if (isSony || isXbox) {
    if (!isFullClient) {
      needShowContinueButton = false
      _msg = contentStateModule.getClientDownloadProgressText()
    }
    else {
      let requiredPacks = packs.filter(isConsoleContentPackCanBeChecked)
      if (requiredPacks.len() == 0) {
        
        if (continueFunc)
          call_for_handler(owner, continueFunc)
        return true
      }
      needShowContinueButton = false
      if (u.isEmpty(_msg))
        _msg = loc($"msgbox/no_package/info")

      _msg = format(_msg, colorize("activeTextColor", loc("ui/comma").join(requiredPacks.map(@(pack) $"{getPkgLocName(pack)} {progress?[pack] ?? 100}%"))))

      foreach (pack in requiredPacks) {
        if ((progress?[pack] ?? 0) > 0)
          continue

        let btnId = $"download_{pack}"
        let btnCaption = " ".concat(loc("msgbox/btn_download"), getPkgLocName(pack, true))
        buttons.append([btnId, function() {
          
          if (cancelFunc)
            call_for_handler(owner, cancelFunc)
          requestConsoleContentPackInstall(pack, function(res) {
            logC($"install request for pack {pack} is {res}")
            refreshPacks([pack])
          })
        }, true, btnCaption])
        defButton = btnId
      }
    }
  }
  else {
    needShowContinueButton = allowContinue
    if (u.isEmpty(_msg)) {
      let postfix = needShowContinueButton ? "/continue" : ""
      _msg = loc($"msgbox/no_package{postfix}")
    }
    _msg = format(_msg, colorize("activeTextColor", loc("ui/comma").join(packs.map(@(pack) getPkgLocName(pack)))))
  }


  buttons.append(["cancel", function() {
    if (cancelFunc)
      call_for_handler(owner, cancelFunc)
    }
  ])

  if (isSony) {
    if (!isFullClient && contentStateModule.isConsoleClientFullyDownloaded()) {
      buttons.insert(0, ["apply", function() { ps4_update_gui() }])
      defButton = "apply"
    }
  }
  else if (!is_gdk) {
    buttons.insert(0, ["download",  function() {
                       request_packages_and_restart(packs)
                     }])
  }

  if (continueFunc && needShowContinueButton) {
    defButton = "continue"
    buttons.append(["continue",  function() {
                     call_for_handler(owner, continueFunc)
                   }])
  }
  scene_msg_box("req_new_content", null, _msg, buttons, defButton)
  setAskedPack(packs)
  return false
}

function checkPackageAndAskDownload(packs, msg = null, continueFunc = null, owner = null, cancelFunc = null, allowContinue = false) {
  let consolePacks = packs.filter(isConsoleContentPackCanBeChecked)
  if (consolePacks.len() == 0)
    return checkPackageAndAskDownloadImpl(packs, msg, continueFunc, owner, cancelFunc, {}, allowContinue)

  refreshPacks(consolePacks, function() {
    gatherConsolePacksProgress(consolePacks, function(progress) {
      checkPackageAndAskDownloadImpl(packs, msg, continueFunc, owner, cancelFunc, progress, allowContinue)
    })
  })
  return false
}

function checkPackageFull(pack, silent = false) {
  local res = havePackage(pack)
  if (!res && !silent)
    checkPackageAndAskDownload([pack])

  res = res && (silent || check_members_pkg(pack))
  return res
}

function checkPackageAndAskDownloadByTimes(pack, continueFunc = null, owner = null, cancelFunc = null, allowContinue = false) {
  if (!isAskedPack(pack)) {
    checkPackageAndAskDownload([pack], null, continueFunc, owner, cancelFunc, allowContinue)
    return
  }
  if (continueFunc)
    call_for_handler(owner, continueFunc)
}

function checkGamemodePkg(gm, continueFunc) {
  if (gm == GM_SKIRMISH) {
    checkPackageAndAskDownloadByTimes("pkg_main", continueFunc, null, null, true)
    return
  }
  continueFunc()
}

function checkDiffPkg(diff, silent = false) {
  foreach (d in [DIFFICULTY_HARDCORE, DIFFICULTY_CUSTOM])
    if (diff == d || get_difficulty_name(d) == diff)
      return checkPackageFull("pkg_main", silent)
  return true
}

function checkReqContentByName(ename, pack) {
  if (has_entitlement(ename) || hasFeature(ename)) {
    logC($"has entitlement {ename }, checking for pack {pack}");
    let status = getContentPackStatus(pack)
    if (status == ContentPackStatus.MISSING)
      return pack
  }
  else
    logC($"don't have entitlement {ename}, ignoring pack {pack}");

  return null
}

function checkReqContent(ename, blk) {
  if ("reqPack" in blk)
    return checkReqContentByName(ename, blk.reqPack)
  return null
}

function updateContentPacks() {
  if (isSony || isXbox)
    return 

  if (!isLoggedIn.get())
    return

  logC("updateContentPacks called");

  let reqPacksList = []
  for (local i = reqPacksList.len() - 1; i >= 0; i--)
    if (havePackage(reqPacksList[i]))
      reqPacksList.remove(i)

  eachBlock(getShopPriceBlk(),
    @(b, n) u.appendOnce(checkReqContent(n, b), reqPacksList, true))
  eachBlock(get_game_settings_blk()?.features,
    @(b, n) u.appendOnce(checkReqContent(n, b), reqPacksList, true))

  
  u.appendOnce(checkReqContentByName("usa_pacific_41_43", "hc_pacific"), reqPacksList, true)
  u.appendOnce(checkReqContentByName("jpn_pacific_41_43", "hc_pacific"), reqPacksList, true)

  local text = ""
  let langId = getLocalLanguage()
  let langPack = $"pkg_{langId}"
  if (!havePackage(langPack) && is_fully_translated(langId)) {
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

  if (!hasFeature("Packages") || getFromSettingsBlk("debug/skipPopups", false))
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

function checkSpeechCountryUnitLocalizationPackageAndAskDownload() {
  let reqPacksList = []

  foreach (langId, langData in langsById) {
    if (!langData.hasUnitSpeech)
      continue

    let langPack = $"pkg_{langId}"
    if (!havePackage(langPack))
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
  if (isSony)
    return startLogout()
  else if (is_gdk)
    return exitGamePlatform()
  else if (platformId == "linux64")
    return quit_and_run_cmd("./launcher -silentupdate")
  else if (platformId == "macosx")
    return quit_and_run_cmd("../../../../MacOS/launcher -silentupdate")
  if (is_windows) {
    let exec = "launcher.exe -silentupdate";

    return quit_and_run_cmd(exec)
  }

  log("ERROR: restart_to_launcher action not implemented");
}




function refreshPacksOnContentDelivered(_p) {
  refreshPacks()
}

if (isXbox) {
  let { package_installed_event_name } = require("gdk.package")
  eventbus_subscribe(package_installed_event_name, refreshPacksOnContentDelivered)
}

if (isSony) {
  eventbus_subscribe("dng.sony.playgo.chunkAdded", refreshPacksOnContentDelivered)
  eventbus_subscribe("dng.sony.playgo.scenarioUpdate", refreshPacksOnContentDelivered)
}

eventbus_subscribe("error_load_model_and_restart", function(params) {
  let { model } = params
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
})

function checkLocalizationPackageAndAskDownload(langId = null) {
  langId = langId ?? getLocalLanguage()
  let pack = $"pkg_{langId}"
  if (havePackage(pack) || !is_fully_translated(langId))
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

addPromoAction("content_pack", @(_handler, params, _obj) checkPackageAndAskDownload([params?[0] ?? ""]),
  @(params) hasFeature("Packages") && !havePackage(params?[0] ?? ""))

addListenersWithoutEnv({
  NewSceneLoaded = function(_) {
    refreshPacks()
    if (!needCheckLangPack.get())
      return

    checkLocalizationPackageAndAskDownload()
    needCheckLangPack.set(false)
  }
  ProfileReceived = function(_) {
    askedPackages = null
    refreshPacks()
  }
}, g_listener_priority.DEFAULT_HANDLER)

return freeze({
  getPkgLocName
  havePackage
  checkPackageFull
  checkGamemodePkg
  checkDiffPkg
  checkSpeechCountryUnitLocalizationPackageAndAskDownload
  checkPackageAndAskDownload
  checkPackageAndAskDownloadByTimes
  updateContentPacks
})