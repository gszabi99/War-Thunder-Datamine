local { chatStatesCanUseVoice } = require("scripts/chat/chatStates.nut")
local { isMultifuncMenuAvailable } = require("scripts/wheelmenu/multifuncmenuShared.nut")

return [
//-------------------------------------------------------
  {
    id = "ID_COMMON_BASIC_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "ID_TACTICAL_MAP"
    checkGroup = ctrlGroups.COMMON
    needShowInHelp = true
  }
  {
    id = "ID_MPSTATSCREEN"
    checkGroup = ctrlGroups.COMMON
    needShowInHelp = true
  }
  {
    id = "ID_SHOW_MULTIFUNC_WHEEL_MENU"
    checkGroup = ctrlGroups.COMMON
    checkAssign = ::is_platform_pc
    needShowInHelp = true
    showFunc = isMultifuncMenuAvailable
  }
  {
    id = "ID_BAILOUT"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_SHOW_HERO_MODULES"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_LOCK_TARGET"
    checkGroup = ctrlGroups.COMMON
    needShowInHelp = true
  }
  {
    id = "ID_PREV_TARGET"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_NEXT_TARGET"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    needShowInHelp = true
  }
  // Use last chat mode, but can not be renamed to "ID_TOGGLE_CHAT" for compatibility reasons
  {
    id = "ID_TOGGLE_CHAT_TEAM"
    checkGroup = ctrlGroups.COMMON
    checkAssign = ::is_platform_pc
    needShowInHelp = true
  }
  // Use CO_ALL chat mode, but can not be renamed to "ID_TOGGLE_CHAT_ALL" for compatibility reasons
  {
    id = "ID_TOGGLE_CHAT"
    checkGroup = ctrlGroups.COMMON
    checkAssign = ::is_platform_pc
  }
  {
    id = "ID_TOGGLE_CHAT_PARTY"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CHAT_SQUAD"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CHAT_MODE"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
  {
    id = "ID_PTT"
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
    condition = @() ::gchat_is_voice_enabled()
    showFunc = chatStatesCanUseVoice
  }
  {
    id = "ID_GAMEPAD_RESET_GYRO_TILT"
    showFunc = @() ::is_platform_ps4
    checkGroup = ctrlGroups.COMMON
    checkAssign = false
  }
]
