local LAST_SESSION_DEBUG_INFO = ""

return {
  get_last_session_debug_info = @() LAST_SESSION_DEBUG_INFO
  set_last_session_debug_info = @(v) LAST_SESSION_DEBUG_INFO = v
}