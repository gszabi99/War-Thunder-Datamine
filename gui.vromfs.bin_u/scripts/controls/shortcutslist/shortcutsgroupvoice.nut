local { getFavoriteVoiceMessagesVariants } = require("scripts/wheelmenu/voiceMessages.nut")

local MAX_VOICE_MESSAGE_BUTTONS = 8

local function getIdVoiceMessageOption(index) {
  return {
    id = "ID_VOICE_MESSAGE_" + index
    checkGroup = ctrlGroups.VOICE
    checkAssign = false
  }
}

local groupList = [
  {
    id = "ID_COMMON_VOICE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_SHOW_VOICE_MESSAGE_LIST"
    checkGroup = ctrlGroups.COMMON
    checkAssign = ::is_platform_pc
    needShowInHelp = true
  }
  {
    id = "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
    checkGroup = ctrlGroups.COMMON
    checkAssign = ::is_platform_pc
    needShowInHelp = true
  }
]

for (local i = 1; i <= MAX_VOICE_MESSAGE_BUTTONS; i++)
  groupList.append(getIdVoiceMessageOption(i))

groupList.append(
  {
    id = "use_joystick_mouse_for_voice_message"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.useJoystickMouseForVoiceMessage
    setValue = function(joyParams, objValue) {
      local old  = joyParams.useJoystickMouseForVoiceMessage
      joyParams.useJoystickMouseForVoiceMessage = objValue
      if (joyParams.useJoystickMouseForVoiceMessage != old)
        ::set_controls_preset("")
    }
  }
  {
    id = "use_mouse_for_voice_message"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.useMouseForVoiceMessage
    showFunc = @() ::has_feature("EnableMouse")
    setValue = function(joyParams, objValue) {
      local old  = joyParams.useMouseForVoiceMessage
      joyParams.useMouseForVoiceMessage = objValue
      if (joyParams.useMouseForVoiceMessage != old)
        ::set_controls_preset("")
    }
  }
)

local function getFavoriteVoiceMessageOption(index) {
  return {
    id = "favorite_voice_message_" + index
    type = CONTROL_TYPE.SPINNER
    options = getFavoriteVoiceMessagesVariants()
    value = (@(index) function(joyParams) { return ::get_option_favorite_voice_message(index - 1) + 1 })(index)
    setValue = (@(index) function(joyParams, objValue) { ::set_option_favorite_voice_message(index - 1, objValue - 1); })(index)
  }
}

local function getFastVoiceMessageOption(index) {
  return {
    id = "ID_FAST_VOICE_MESSAGE_" + index
    checkGroup = ctrlGroups.VOICE
    checkAssign = false
  }
}

for (local i = 1; i <= ::NUM_FAST_VOICE_MESSAGES; i++)
{
  groupList.append(getFastVoiceMessageOption(i))
  groupList.append(getFavoriteVoiceMessageOption(i))
}

return groupList