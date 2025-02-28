from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { isMatchingError, matchingErrorString } = require("%scripts/matching/api.nut")
let { get_last_session_debug_info } = require("%scripts/matchingRooms/sessionDebugInfo.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { getBannedMessage } = require("%scripts/penitentiary/penalties.nut")
let { SERVER_ERROR_PLAYER_BANNED } = require("matching.errors")

let errCodeToStringMap = {
  [YU2_TIMEOUT] = "80130182",
  [YU2_HOST_RESOLVE] = "80130182",
  [YU2_SSL_ERROR] = "80130182",
  [YU2_FAIL] = "80130182", // auth server is not available
  [YU2_WRONG_LOGIN] = "80130183",
  [YU2_WRONG_PARAMETER] = "80130183",
  [YU2_FROZEN] = "8111000E", // account is frozen
  [YU2_FROZEN_BRUTEFORCE] = "8111000F", // ERRCODE_AUTH_ACCOUNT_FROZEN_BRUTEFORCE
  [YU2_SSL_CACERT] = "80130184" // special error for this
}

function error_code_tostring(error_code) {
  return errCodeToStringMap?[error_code] ?? format("%X", error_code)
}

function psn_err_msg(text, res) {
  local errCode = res
  if (errCode == "0")
    errCode = ""
  local errMsg = loc($"yn1/error/{errCode}", "")
  if (errMsg.len()==0) {
    errMsg = $"0x{errCode}"
    errCode = ""
  }

  local errText = ""
  if (isPlatformSony)
    errText = loc($"yn1/error/{errCode}", loc("msgbox/appearError"))
  else
    errText = loc("yn1/error/fmt", { text = loc(text == "" ? "msgbox/error_header" : text, ""), err_msg = errMsg, err_code = errCode })
  return errText
}

function matching_err_msg(text, error_text) {
  local errMsg = loc($"matching/{error_text}")
  if (errMsg.len() == 0)
    errMsg = error_text

  let errText = loc("yn1/error/fmt", { text = loc(text == "" ? "msgbox/error_header" : text, ""), err_msg = errMsg, err_code = "" })
  return errText
}

function get_yu2_error_text(response) { //used only in online shop yet, but beeter to upgrade it and use for all yu2 errors
  if (response == YU2_OK)
    return ""
  if (response == YU2_PSN_RESTRICTED)
    return loc("yn1/error/PSN_RESTRICTED")
  if (response == YU2_NO_MONEY)
    return loc("YU2/error/NOMONEY")
  if (response == YU2_FORBIDDEN_NEED_2STEP)
    return loc("YU2/error/NEED_2STEP")
  return loc("charServer/notAvailableYet")
}

function get_error_data(header, error_code) {
  let res = {
    errCode = null
    text = null
  }
  if (type(error_code) != "string") {
    error_code = error_code & 0xFFFFFFFF // Temporary fix for 1.67.2.X

    res.errCode = error_code_tostring(error_code)
    if (isMatchingError(error_code))
      res.text = matching_err_msg(header, matchingErrorString(error_code))
    else
      res.text = psn_err_msg(header, res.errCode);
  }
  else {
    res.errCode = error_code
    res.text = psn_err_msg(header, res.errCode);
  }
  return res
}

::error_message_box <- function error_message_box(header, error_code, buttons, def_btn, options = {}, message = null) {
  let guiScene = get_gui_scene()
  if (checkObj(guiScene["errorMessageBox"]))
    return

  if (error_code == SERVER_ERROR_PLAYER_BANNED) {
    let banMessage = getBannedMessage()
    if (banMessage != "") {
      scene_msg_box("errorMessageBox", guiScene, banMessage, buttons, def_btn, options)
      return
    }
  }

  let errData = get_error_data(header, error_code)

  if (!isPlatformXboxOne) {
    let errorLinkFormatText = loc(getCurCircuitOverride($"errorLinkFormatLocId_{errData.errCode}", "msgbox/error_link_format_game"))
    errData.text = "".concat(errData.text, "\n\n",
      (isPlatformSony ? "" : ("".concat(errorLinkFormatText, loc("ui/colon")))))
    let link = getCurCircuitOverride($"knowledgebaseUrl_{errData.errCode}")
      ?? "".concat(getCurCircuitOverride("knowledgebaseUrl") ?? loc("url/knowledgebase"), errData.errCode)
    let linkText = isPlatformSony ? errorLinkFormatText : link
    errData.text = "".concat(errData.text, $"<url={link}>{linkText}</url>")
  }

  if (message != null)
    errData.text = "".concat(errData.text, message)

  options = options ?? {}
  options["debug_string"] <- get_last_session_debug_info()

  return scene_msg_box("errorMessageBox", guiScene, errData.text, buttons, def_btn, options)
}

return {
  get_yu2_error_text
}