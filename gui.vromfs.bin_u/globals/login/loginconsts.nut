const USE_STEAM_LOGIN_AUTO_SETTING_ID = "useSteamLoginAuto"

enum LOGIN_STATE { //bit mask
  AUTHORIZED               = 0x0001 //succesfully connected to auth
  PROFILE_RECEIVED         = 0x0002
  CONFIGS_RECEIVED         = 0x0004
  MATCHING_CONNECTED       = 0x0008
  CONFIGS_INITED           = 0x0010
  ONLINE_BINARIES_INITED   = 0x0020
  HANGAR_LOADED            = 0x0040

  //not required for login
  LOGIN_STARTED            = 0x0100

  //masks
  NOT_LOGGED_IN            = 0x0000
  LOGGED_IN                = 0x003F //logged in to all hosts and all configs are loaded
}

return {
  LOGIN_STATE
  USE_STEAM_LOGIN_AUTO_SETTING_ID
}