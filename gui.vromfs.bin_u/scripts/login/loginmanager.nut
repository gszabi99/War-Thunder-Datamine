import "samsung" as samsung
import "statsd" as statsd
import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/login/loginState.nut" import loginState, isLoggedIn, isAuthorized
from "%globalScripts/systemConfig.nut" import getSystemConfigOption
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "%sqstd/platform.nut" import is_windows, platformId, is_gdk
from "steam" import steam_is_running
from "guiMission" import get_meta_missions_info
from "blkGetters" import get_user_skins_blk, get_user_skins_profile_blk
from "scriptRespondent" import registerRespondent
from "contentpacks" import getContentPackStatus, ContentPackStatus
from "%scripts/dagui_natives.nut" import epic_is_running, ps4_is_chat_enabled, ps4_is_ugc_enabled, get_localization_blk_copy, dgs_get_argv, is_eac_inited
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE
from "types" import String

let gfn = require_optional("gfn")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { WaitForLoginWnd } = require("%scripts/login/waitForLoginWnd.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { bqSendLoginState } = require("%scripts/bigQuery/bigQueryClient.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { is_user_mission } = require("%scripts/missions/missionsStates.nut")
let { destroyLoginProgress } = require("%scripts/login/loginStates.nut")

let cachedLoginData = persist("cachedLoginData", @() { use_dmm_login = null })

function useDmmLogin() {
  if (cachedLoginData.use_dmm_login == null) {
    cachedLoginData.use_dmm_login = dgs_get_argv("dmm_user_id") && dgs_get_argv("dmm_token")
  }
  return cachedLoginData.use_dmm_login
}

function loadLoginHandler() {
  local hClass = get_gui_handler("LoginWndHandler")
  if (isPlatformSony)
    hClass = get_gui_handler("LoginWndHandlerPs4")
  else if (is_gdk)
    hClass = get_gui_handler("LoginWndHandlerXboxOne")
  else if (useDmmLogin())
    hClass = get_gui_handler("LoginWndHandlerDMM")
  else if (steam_is_running())
    hClass = get_gui_handler("LoginWndHandlerSteam")
  else if (epic_is_running())
    hClass = get_gui_handler("LoginWndHandlerEpic")
  else if (samsung.is_running())
    hClass = get_gui_handler("LoginWndHandlerSamsung")
  else if (gfn?.is_running())
    hClass = get_gui_handler("LoginWndHandlerGfn")

  loadHandler(hClass)
}

function onAuthorizeChanged() {
  if (!isAuthorized.get()) {
    broadcastEvent("SignOut")
    return
  }

  if (!disableNetwork)
    handlersManager.animatedSwitchScene(function() {
      loadHandler(WaitForLoginWnd)
    })
}

function getUsedTexturePacks() {
  let packs = ["pkg_main", "pkg_uhq_aircraft", "pkg_uhq_environment", "pkg_uhq_vehicles"]
  return ";".join(packs.filter(@(pack) getContentPackStatus(pack) == ContentPackStatus.OK))
}

function bigQueryOnLogin() {
  local params = platformId
  if (getSystemConfigOption("launcher/bg_update", true))
    params = " ".concat(params, "bg_update")
  let data = {
    params = params
    haveAntiCheat = is_eac_inited()
  }

  let hangarBlk = getSystemConfigOption("hangarBlk", "")
  if(hangarBlk != "")
    data.hangarBlk <- hangarBlk

  let usedTexturePacks = getUsedTexturePacks()
  if(usedTexturePacks != "")
    data.usedTexturePacks <- usedTexturePacks

  data.bvhMode <- getSystemConfigOption("graphics/bvhMode", "off")

  sendBqEvent("CLIENT_SETTINGS_1", "login", data)
}

function statsdOnLogin() {
  statsd.send_counter("sq.game_start.login", 1)

  if (isPlatformSony) {
    if (!ps4_is_chat_enabled())
      sendBqEvent("CLIENT_GAMEPLAY_1", "ps4.restrictions.chat", {})
    if (!ps4_is_ugc_enabled())
      sendBqEvent("CLIENT_GAMEPLAY_1", "ps4.restrictions.ugc", {})
  }

  if (is_windows) {
    local anyUG = false

    let mis_array = get_meta_missions_info(GM_SINGLE_MISSION)
    foreach (misBlk in mis_array)
      if (is_user_mission(misBlk)) {
        statsd.send_counter("sq.ug.goodum", 1)
        anyUG = true
        log($"statsd_on_login ug.goodum {(misBlk?.name ?? "null")}")
        break
      }

    let userSkins = get_user_skins_blk()
    local haveUserSkin = false
    for (local i = 0; i < userSkins.blockCount(); i++) {
      let air = userSkins.getBlock(i)
      let skins = air % "skin"
      foreach (skin in skins) {
        let folder = skin.name
        if (folder.indexof("template") == null) {
          haveUserSkin = true
          anyUG = true
          log($"statsd_on_login ug.haveus {folder} for {air.getBlockName()}")
          break
        }
      }
      if (haveUserSkin)
        break
    }
    if (haveUserSkin)
      statsd.send_counter("sq.ug.haveus", 1)

    let cdb = get_user_skins_profile_blk()
    for (local i = 0; i < cdb.paramCount(); i++) {
      let skin = cdb.getParamValue(i)
      if ((skin instanceof String) && (skin != "") && (skin.indexof("template") == null)) {
        anyUG = true
        statsd.send_counter("sq.ug.useus", 1)
        log($"statsd_on_login ug.useus {skin}")
        break;
      }
    }

    let lcfg = DataBlock()
    get_localization_blk_copy(lcfg)
    if (lcfg.locTable != null) {
      let files = lcfg.locTable % "file"
      foreach (file in files)
        if (file.indexof("usr_") != null) {
          anyUG = true
          log($"statsd_on_login ug.langum {file}")
          statsd.send_counter("sq.ug.langum", 1)
          break
        }
    }

    if (anyUG) {
      log("statsd_on_login ug.any")
      statsd.send_counter("sq.ug.any", 1)
    }
  }
}

function onLoggedInChanged() {
  if (!isLoggedIn.get())
    return

  statsdOnLogin()
  bigQueryOnLogin()
  broadcastEvent("LoginComplete")
}

function setLoginState(newState) {
  let wasState = loginState.get()
  if (wasState == newState)
    return

  let wasAuthorized = isAuthorized.get()
  let wasLoggedIn   = isLoggedIn.get()

  loginState.set(newState)

  if (wasAuthorized != isAuthorized.get())
    onAuthorizeChanged()
  if (wasLoggedIn != isLoggedIn.get())
    onLoggedInChanged()

  broadcastEvent("LoginStateChanged")

  bqSendLoginState(
  {
    "was"  : wasState,
    "new"  : newState,
    "auth" : isAuthorized.get(),
    "login" : isLoggedIn.get()
  })
}

function addLoginState(statePart) {
  setLoginState(loginState.get() | statePart)
}

function resetLogin() {
  destroyLoginProgress()
  setLoginState(LOGIN_STATE.NOT_LOGGED_IN)
}

function onProfileReceived() {
  addLoginState(LOGIN_STATE.PROFILE_RECEIVED | LOGIN_STATE.CONFIGS_RECEIVED)
  broadcastEvent("ProfileReceived")
}

registerRespondent("is_logged_in", function is_logged_in() {
  return isLoggedIn.get()
})

return {
  loadLoginHandler
  setLoginState
  addLoginState
  resetLogin
  onProfileReceived
}