enum USERLOG_POPUP {
  UNLOCK                = 0x0001
  FINISHED_RESEARCHES   = 0x0002
  OPEN_TROPHY           = 0x0004

  
  ALL                   = 0xFFFF
  NONE                  = 0x0000
}

let hiddenUserlogs = [
  EULT_NEW_STREAK,
  EULT_SESSION_START,
  EULT_WW_START_OPERATION,
  EULT_WW_CREATE_OPERATION,
  EULT_WW_END_OPERATION,
  EULT_WW_AWARD
]

return {
  USERLOG_POPUP
  hiddenUserlogs
}