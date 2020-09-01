::error_message_box <- function error_message_box(header, error_code, buttons, def_btn, options = {}, message=null)
{
  local guiScene = ::get_gui_scene()
  if (::checkObj(guiScene["errorMessageBox"]))
    return

  local errData = ::get_error_data(header, error_code)

  if (!::is_platform_xboxone)
  {
    errData.text += "\n\n" + (::is_platform_ps4? "" : (::loc("msgbox/error_link_format_game") + ::loc("ui/colon")))
    local knoledgebaseSuffix = ::is_vendor_tencent()? "/Tencent" : ""
    local link = ::loc("url/knowledgebase" + knoledgebaseSuffix) + errData.errCode
    local linkText = ::is_platform_ps4? ::loc("msgbox/error_link_format_game") : link
    errData.text += ::format("<url=%s>%s</url>", link, linkText)
  }

  if (message != null)
    errData.text += message

  if ("LAST_SESSION_DEBUG_INFO" in getroottable())
  {
    options = options || {}
    options["debug_string"] <- ::LAST_SESSION_DEBUG_INFO
  }

  return ::scene_msg_box("errorMessageBox", guiScene, errData.text, buttons, def_btn, options)
}

::error_code_tostring <- function error_code_tostring(error_code)
{
  switch (error_code)
  {
    case ::YU2_TIMEOUT:
    case ::YU2_HOST_RESOLVE:
    case ::YU2_SSL_ERROR:
    case ::YU2_FAIL: // auth server is not available
      return "80130182"

    case ::YU2_WRONG_LOGIN:
    case ::YU2_WRONG_PARAMETER:
      return "80130183"

    case ::YU2_FROZEN: // account is frozen
      return "8111000E"

    case ::YU2_FROZEN_BRUTEFORCE:
      return "8111000F" // ERRCODE_AUTH_ACCOUNT_FROZEN_BRUTEFORCE

    case ::YU2_SSL_CACERT:
      return "80130184" // special error for this
  }

  return ::format("%X", error_code)
}

::get_error_data <- function get_error_data(header, error_code)
{
  local res = {
    errCode = null
    text = null
  }
  if (typeof error_code != "string")
  {
    error_code = error_code & 0xFFFFFFFF // Temporary fix for 1.67.2.X

    res.errCode = error_code_tostring(error_code)
    if (is_matching_error(error_code))
      res.text = ::matching_err_msg(header, matching_error_string(error_code))
    else
      res.text = ::psn_err_msg(header, res.errCode);
  }
  else
  {
    res.errCode = error_code
    res.text = ::psn_err_msg(header, res.errCode);
  }
  return res
}

::psn_err_msg <- function psn_err_msg(text, res)
{
  local errCode = res
  if (errCode == "0")
    errCode = ""
  local errMsg = ::loc("yn1/error/"+errCode, "")
  if (!errMsg.len())
  {
    errMsg = "0x" + errCode
    errCode = ""
  }

  local errText = ""
  if (::is_platform_ps4)
    errText = ::loc("yn1/error/" + errCode, loc("msgbox/appearError"))
  else
    errText = ::loc("yn1/error/fmt", {text=::loc(text == "" ? "msgbox/error_header" : text, ""), err_msg=errMsg, err_code=errCode})
  return errText
}

::matching_err_msg <- function matching_err_msg(text, error_text)
{
  local errMsg = ::loc("matching/" + error_text)
  if (errMsg.len() == 0)
    errMsg = error_text

  local errText = ::loc("yn1/error/fmt", {text=::loc(text == "" ? "msgbox/error_header" : text, ""), err_msg=errMsg, err_code=""})
  return errText
}

::get_yu2_error_text <- function get_yu2_error_text(response) //used only in online shop yet, but beeter to upgrade it and use for all yu2 errors
{
  if (response == ::YU2_OK)
    return ""
  if (response == ::YU2_PSN_RESTRICTED)
    return ::loc("yn1/error/PSN_RESTRICTED")
  if (response == ::YU2_NO_MONEY)
    return ::loc("YU2/error/NOMONEY")
  if (response == ::YU2_FORBIDDEN_NEED_2STEP)
    return ::loc("YU2/error/NEED_2STEP")
  return ::loc("charServer/notAvailableYet")
}