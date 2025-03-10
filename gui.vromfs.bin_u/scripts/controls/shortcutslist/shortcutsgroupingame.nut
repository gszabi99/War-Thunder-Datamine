from "%scripts/dagui_natives.nut" import gchat_is_voice_enabled
from "%scripts/dagui_library.nut" import *

let { chatStatesCanUseVoice } = require("%scripts/chat/chatStates.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let { USEROPT_HOLD_BUTTON_FOR_TACTICAL_MAP } = require("%scripts/options/optionsExtNames.nut")

return [

  {
    id = "ID_COMMON_BASIC_HEADER"
    type = CONTROL_TYPE.SECTION
    needShowInHelp = true
  }
  {
    id = "ID_TACTICAL_MAP"
    needShowInHelp = true
  }
  {
    id = "hold_button_for_tactical_map"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = USEROPT_HOLD_BUTTON_FOR_TACTICAL_MAP
  }
  {
    id = "ID_MPSTATSCREEN"
    needShowInHelp = true
  }
  {
    id = "ID_SHOW_MULTIFUNC_WHEEL_MENU"
    checkAssign = is_platform_pc
    needShowInHelp = true
  }
  {
    id = "ID_BAILOUT"
    checkAssign = false
  }
  {
    id = "ID_SHOW_HERO_MODULES"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_LOCK_TARGET"
    needShowInHelp = true
  }
  {
    id = "ID_PREV_TARGET"
    checkAssign = false
    needShowInHelp = true
  }
  {
    id = "ID_NEXT_TARGET"
    checkAssign = false
    needShowInHelp = true
  }
  
  {
    id = "ID_TOGGLE_CHAT_TEAM"
    checkAssign = is_platform_pc
    needShowInHelp = true
  }
  
  {
    id = "ID_TOGGLE_CHAT"
    checkAssign = is_platform_pc
  }
  {
    id = "ID_TOGGLE_CHAT_PARTY"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CHAT_SQUAD"
    checkAssign = false
  }
  {
    id = "ID_TOGGLE_CHAT_MODE"
    checkAssign = false
  }
  {
    id = "ID_PTT"
    checkAssign = false
    condition = @() gchat_is_voice_enabled()
    showFunc = chatStatesCanUseVoice
  }
  {
    id = "ID_GAMEPAD_RESET_GYRO_TILT"
    showFunc = @() isPlatformSony
    checkAssign = false
  }
  {
    id = "ID_SQUAD_TARGET_DESIGNATION"
    checkAssign = false
  }
]
