from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import px
from "%rGui/hints/shortcuts.nut" import getShortcut
from "%appGlobals/controls/assignShortcutState.nut" import assignShortcut
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/components/gamepadImgByKey.nut" import mkImageCompByDargKey
from "eventbus" import eventbus_send
import "%rGui/components/button.nut" as button
import "%rGui/control/gui_buttons.nut" as JB
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors



let fontMedium = fontsState.get("medium")
let stepGap = px("30@sf/@pf")
let radioSize = px("@checkboxSize")
let radioH = px("1.2@checkboxSize")
let navPad = px("1@blockInterval")

let bottomPanelH = px("@bottomMenuPanelHeight")
let shortcutPlace = freeze({ place = "controlsCell" })


const WHEEL_UP = 5
const WHEEL_DOWN = 6


let DEVICE_NAME_BY_DEVID = freeze({
  [DEVID_KEYBOARD] = "keyboard",
  [DEVID_MOUSE] = "mouse",
  [DEVID_JOYSTICK] = "joystick",
})

let sendAction = @(action, p = {}) eventbus_send("assignShortcut.action", p.__merge({ action }))

function sendInput(devId, btn, isDown) {
  let device = DEVICE_NAME_BY_DEVID?[devId]
  if (device != null)
    sendAction("input", { device, btn, isDown })
  return R_PROCESSED
}

function sendWheel(delta) {
  if (delta == 0)
    return
  let btn = delta > 0 ? WHEEL_UP : WHEEL_DOWN
  sendInput(DEVID_MOUSE, btn, true)
  sendInput(DEVID_MOUSE, btn, false)
}

let mkText = @(text, color = cssColors.activeTextColor) { rendObj = ROBJ_TEXT, font = fontMedium, color, text }

let navBar = freeze({
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  margin = [0, navPad, bottomPanelH + navPad, 0]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_CENTER
  gap = navPad
})

let pressKeyText = mkText(loc("hotkeys/msg/press_a_key"))
let activationTypeText = mkText(loc("controls/activationType/name"))
let activationHotkeys = freeze([
  ["^Esc | J:Start", @() sendAction("cancel")],
  [JB.B, @() sendAction("back")],
])

let activationButtons = navBar.__merge({ children = [
  { id = "btn_back", locId = "mainmenu/btnBack", action = "back" }
  { id = "btn_apply", locId = "mainmenu/btnApply", action = "apply" }
  { id = "btn_cancel", locId = "msgbox/btn_cancel", action = "cancel" }
].map(@(b) button({ id = b.id, text = loc(b.locId) }, @() sendAction(b.action))) })


let startImg = mkImageCompByDargKey("J:Start", null, { height = px("@cIco"), vplace = ALIGN_CENTER })
let escText = mkText("Esc")
let cancelText = mkText(loc("msgbox/btn_cancel"), cssColors.commonTextColor)
let cancelHint = @() navBar.__merge({
  watch = showConsoleButtons
  children = [showConsoleButtons.get() ? startImg : escText, cancelText]
})

let inputStep = @() {
  watch = assignShortcut
  size = flex()
  cursor = null
  behavior = [Behaviors.ProcessKeyInput, Behaviors.ProcessPointingInput, Behaviors.WheelScroll]
  onKeyPress = @(evt) sendInput(evt.devId, evt.btnId, true)
  onKeyRelease = @(evt) sendInput(evt.devId, evt.btnId, false)
  onPointerPress = @(evt) sendInput(evt.devId, evt.btnId, true)
  onPointerRelease = @(evt) sendInput(evt.devId, evt.btnId, false)
  onWheelScroll = sendWheel
  children = [
    {
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      children = [
        pressKeyText
        mkText(assignShortcut.get()?.inputText ?? "")
      ]
    }
    cancelHint
  ]
}

function radioItem(text, idx, isSelected) {
  let onClick = @() sendAction("activationType", { idx })
  return watchElemState(@(sf) {
    size = [SIZE_TO_CONTENT, radioH]
    behavior = Behaviors.Button
    onClick
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = radioSize / 4
    children = [
      {
        size = radioSize
        rendObj = ROBJ_IMAGE
        image = Picture(isSelected ? $"ui/gameuiskin#radiobutton_checked_.svg:{radioSize}:{radioSize}:K"
          : (sf & S_HOVER) != 0 ? $"ui/gameuiskin#radiobutton_unchecked_hover.svg:{radioSize}:{radioSize}:K"
          : $"ui/gameuiskin#radiobutton_unchecked_.svg:{radioSize}:{radioSize}:K")
      }
      mkText(text)
    ]
  })
}

function activationStep() {
  let { shortcutName = "", combination = null, activationTypes = [], activationIdx = 0 } = assignShortcut.get()
  return {
    watch = assignShortcut
    size = flex()
    hotkeys = activationHotkeys
    children = [
      {
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        gap = stepGap
        children = [
          mkText(shortcutName)
          getShortcut(combination, shortcutPlace)
          {
            flow = FLOW_HORIZONTAL
            gap = stepGap / 2
            children = [
              activationTypeText
              {
                flow = FLOW_VERTICAL
                children = activationTypes.map(@(text, idx) radioItem(text, idx, idx == activationIdx))
              }
            ]
          }
        ]
      }
      activationButtons
    ]
  }
}

let stepComp = Computed(@() assignShortcut.get()?.step)


let dropKbFocus = @() set_kb_focus(null)

let assignShortcutWnd = @() {
  watch = stepComp
  size = flex()
  children = stepComp.get() == null ? null : {
    size = flex()
    rendObj = ROBJ_SOLID
    color = cssColors.shadeBackgroundColor
    behavior = Behaviors.Button
    stopMouse = true
    stopHotkeys = true
    onAttach = dropKbFocus
    children = stepComp.get() == "input" ? inputStep : activationStep
  }
}

return assignShortcutWnd
