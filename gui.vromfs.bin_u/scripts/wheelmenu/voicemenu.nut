//-file:plus-string
from "%scripts/dagui_natives.nut" import get_option_favorite_voice_message, switch_voice_message_list_in_squad
from "%scripts/dagui_library.nut" import *


let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getVoiceMessageNames, getCategoryLoc } = require("%scripts/wheelmenu/voiceMessages.nut")
let { KWARG_NON_STRICT } = require("%sqstd/functools.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

gui_handlers.voiceMenuHandler <- class (gui_handlers.wheelMenuHandler) {
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

    let canUseButtons = this.mouseEnabled || showConsoleButtons.value
    showObjById("btnSwitchChannel", canUseButtons && g_squad_manager.isInSquad(true), this.scene)
  }

  function getChatMode() {
    return this.squadMsg ? "squad" : "team"
  }

  function updateFastVoiceMessagesTable() {
    showObjById("fast_shortcuts_block", true, this.scene)
    let isConsoleMode = ::get_is_console_mode_enabled()
    let textRawParam = format("chatMode:t='%s'; padding-left:t='1@bw'", this.getChatMode())
    let messagesArray = []
    for (local i = 0; i < NUM_FAST_VOICE_MESSAGES; i++) {
      let messageIndex = get_option_favorite_voice_message(i)
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

    showObjById("empty_messages_warning", messagesArray.len() == 0, this.scene)
    let data = "\n".join(messagesArray, true)
    let tblObj = this.scene.findObject("fast_voice_messages_table")
    if (checkObj(tblObj))
      this.guiScene.replaceContentFromText(tblObj, data, data.len(), this)
  }

  function onVoiceMessageSwitchChannel(_obj) {
    switch_voice_message_list_in_squad()
  }

  function onWheelmenuSwitchPage(_obj) {}
}
