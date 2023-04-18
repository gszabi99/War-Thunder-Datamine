//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")

let function error_code_tostring(error_code) {
  switch (error_code) {
    case YU2_TIMEOUT:
    case YU2_HOST_RESOLVE:
    case YU2_SSL_ERROR:
    case YU2_FAIL: // auth server is not available
      return "80130182"

    case YU2_WRONG_LOGIN:
    case YU2_WRONG_PARAMETER:
      return "80130183"

    case YU2_FROZEN: // account is frozen
      return "8111000E"

    case YU2_FROZEN_BRUTEFORCE:
      return "8111000F" // ERRCODE_AUTH_ACCOUNT_FROZEN_BRUTEFORCE

    case YU2_SSL_CACERT:
      return "80130184" // special error for this
  }

  return format("%X", error_code)
}

let function psn_err_msg(text, res) {
  local errCode = res
  if (errCode == "0")
    errCode = ""
  local errMsg = loc("yn1/error/" + errCode, "")
  if (!errMsg.len()) {
    errMsg = "0x" + errCode
    errCode = ""
  }

  local errText = ""
  if (isPlatformSony)
    errText = loc("yn1/error/" + errCode, loc("msgbox/appearError"))
  else
    errText = loc("yn1/error/fmt", { text = loc(text == "" ? "msgbox/error_header" : text, ""), err_msg = errMsg, err_code = errCode })
  return errText
}

let function matching_err_msg(text, error_text) {
  local errMsg = loc("matching/" + error_text)
  if (errMsg.len() == 0)
    errMsg = error_text

  let errText = loc("yn1/error/fmt", { text = loc(text == "" ? "msgbox/error_header" : text, ""), err_msg = errMsg, err_code = "" })
  return errText
}

::get_yu2_error_text <- function get_yu2_error_text(response) { //used only in online shop yet, but beeter to upgrade it and use for all yu2 errors
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

let function get_error_data(header, error_code) {
  let res = {
    errCode = null
    text = null
  }
  if (type(error_code) != "string") {
    error_code = error_code & 0xFFFFFFFF // Temporary fix for 1.67.2.X

    res.errCode = error_code_tostring(error_code)
    if (::is_matching_error(error_code))
      res.text = matching_err_msg(header, ::matching_error_string(error_code))
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
  let guiScene = ::get_gui_scene()
  if (checkObj(guiScene["errorMessageBox"]))
    return

  let errData = get_error_data(header, error_code)

  if (!isPlatformXboxOne) {
    errData.text += "\n\n" + (isPlatformSony ? "" : (loc("msgbox/error_link_format_game") + loc("ui/colon")))
    let knoledgebaseSuffix = ::is_vendor_tencent() ? "/Tencent" : ""
    let link = loc($"url/knowledgebase{knoledgebaseSuffix}") + errData.errCode
    let linkText = isPlatformSony ? loc("msgbox/error_link_format_game") : link
    errData.text += $"<url={link}>{linkText}</url>"
  }

  if (message != null)
    errData.text += message

  if ("LAST_SESSION_DEBUG_INFO" in getroottable()) {
    options = options || {}
    options["debug_string"] <- ::LAST_SESSION_DEBUG_INFO
  }

  return ::scene_msg_box("errorMessageBox", guiScene, errData.text, buttons, def_btn, options)
}

