//-file:plus-string
from "%scripts/dagui_library.nut" import *


let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { getVoiceMessageNames, getCategoryLoc } = require("%scripts/wheelmenu/voiceMessages.nut")
let { KWARG_NON_STRICT } = require("%sqstd/functools.nut")

::gui_start_voicemenu <- function gui_start_voicemenu(config) {
  if (::isPlayerDedicatedSpectator())
    return null

  let joyParams = ::joystick_get_cur_settings()
  let params = {
    menu         = config?.menu ?? []
    callbackFunc = getTblValue("callbackFunc", config)
    squadMsg     = getTblValue("squadMsg", config, false)
    category     = getTblValue("category", config, "")
    mouseEnabled = joyParams.useMouseForVoiceMessage || joyParams.useJoystickMouseForVoiceMessage
    axisEnabled  = true
  }

  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.voiceMenuHandler)
  if (handler)
    handler.reinitScreen(params)
  else
    handler = ::handlersManager.loadHandler(::gui_handlers.voiceMenuHandler, params)
  return handler
}

::close_cur_voicemenu <- function close_cur_voicemenu() {
  let handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.voiceMenuHandler)
  if (handler && handler.isActive)
    handler.showScene(false)
}

::gui_handlers.voiceMenuHandler <- class extends ::gui_handlers.wheelMenuHandler {
  wndType = handlerType.CUSTOM
  wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
                                   | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS

  isActive = true
  squadMsg = false
  category = ""

  function initScreen() {
    base.initScreen()
    this.updateChannelInfo()
    this.updateFastVoiceMessagesTable()
  }

  function updateChannelInfo() {
    let objTitle = this.scene.findObject("wheel_menu_category")
    if (checkObj(objTitle)) {
      local text = loc(this.squadMsg ? "hotkeys/ID_SHOW_VOICE_MESSAGE_LIST_SQUAD" : "hotkeys/ID_SHOW_VOICE_MESSAGE_LIST")
        + loc("ui/colon")
      if (this.category != "")
        text += getCategoryLoc(this.category)

      objTitle.chatMode = this.getChatMode()
      objTitle.setValue(text)
    }

    let canUseButtons = this.mouseEnabled || ::show_console_buttons
    this.showSceneBtn("btnSwitchChannel", canUseButtons && ::g_squad_manager.isInSquad(true))
  }

  function getChatMode() {
    return this.squadMsg ? "squad" : "team"
  }

  function updateFastVoiceMessagesTable() {
    this.showSceneBtn("fast_shortcuts_block", true)
    let isConsoleMode = ::get_is_console_mode_enabled()
    let textRawParam = format("chatMode:t='%s'; padding-left:t='1@bw'", this.getChatMode())
    let messagesArray = []
    for (local i = 0; i < NUM_FAST_VOICE_MESSAGES; i++) {
      let messageIndex = ::get_option_favorite_voice_message(i)
      if (messageIndex < 0)
        continue

      let fastShortcutId = "ID_FAST_VOICE_MESSAGE_" + (i + 1)

      let shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(fastShortcutId)
      if (!shortcutType.isAssigned(fastShortcutId))
        continue

      let cells = [
        { id = "name", textType = "text", textRawParam = textRawParam,
         text = format(loc(getVoiceMessageNames()[messageIndex].name + "_0"),
                         loc("voice_message_target_placeholder")) }
      ]

      let shortcutInputs = shortcutType.getInputs({ shortcutId = fastShortcutId }, KWARG_NON_STRICT)
      local shortcutInput = null
      foreach (_idx, input in shortcutInputs) {
        if (!shortcutInput)
          shortcutInput = input

        if (isConsoleMode && input.getDeviceId() == JOYSTICK_DEVICE_0_ID) {
          shortcutInput = input
          break
        }
      }

      if (shortcutInput) {
        if (shortcutInput.getDeviceId() == JOYSTICK_DEVICE_0_ID)
          cells.append({ rawParam = shortcutInput.getMarkup() })
        else
          cells.append({ text = shortcutInput.getText(),
                        textType = "textareaNoTab",
                        textRawParam = "overlayTextColor:t='disabled'" })
      }

      messagesArray.append(::buildTableRow(fastShortcutId, cells))
    }

    this.showSceneBtn("empty_messages_warning", messagesArray.len() == 0)
    let data = "\n".join(messagesArray, true)
    let tblObj = this.scene.findObject("fast_voice_messages_table")
    if (checkObj(tblObj))
      this.guiScene.replaceContentFromText(tblObj, data, data.len(), this)
  }

  function onVoiceMessageSwitchChannel(_obj) {
    ::switch_voice_message_list_in_squad()
  }

  function onWheelmenuSwitchPage(_obj) {}
}
