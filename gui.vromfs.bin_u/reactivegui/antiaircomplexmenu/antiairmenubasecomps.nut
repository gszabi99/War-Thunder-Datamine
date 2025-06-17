from "%rGui/globals/ui_library.nut" import *
let hints = require("%rGui/hints/hints.nut")
let { toggleShortcut, setShortcutOn, setShortcutOff
} = require("%globalScripts/controls/shortcutActions.nut")
let { antiAirMenuShortcutHeight, getShortcut } = require("%rGui/hints/shortcuts.nut")
let { showConsoleButtons } = require("%rGui/ctrlsState.nut")

let frameHeaderPadding = hdpx(8)
let frameHeaderHeight = evenPx(32)
let borderWidth = dp(1)
let shortcutButtonPadding = hdpx(2)
let shortcutButtonGap = hdpx(8)
let shortcutButtonHeight = antiAirMenuShortcutHeight + 2*shortcutButtonPadding

let mkText = @(ovr) {
  rendObj = ROBJ_TEXT
  color = 0xFFFFFFFF
  font = Fonts.tiny_text_hud
}.__update(ovr)

let mkFrameHeader = @(headerText) {
  size = [flex(), frameHeaderHeight]
  rendObj = ROBJ_SOLID
  color = 0xFF2D343C
  padding = frameHeaderPadding
  valign = ALIGN_CENTER
  children = mkText({ text = headerText })
}

let mkFrame = @(content, headerText, ovr = {}) {
  rendObj = ROBJ_BOX
  fillColor = 0xFF182029
  borderColor = 0xFF37454D
  borderWidth
  padding = borderWidth
  flow = FLOW_VERTICAL
  children = [
    mkFrameHeader(headerText)
    content
  ]
}.__update(ovr)

let mkHint = @(shortcutId) hints(shortcutId.concat("{{", "}}"), { place = "antiAirMenu" })

let isActive = @(sf) (sf & S_ACTIVE) != 0

let getShortcutButtonColor = @(sf)
  isActive(sf) ? 0x99020509
    : (sf & S_HOVER) ? 0xFF3A474F
    : 0

function mkShortcutButtonContinued(shortcutId, textComp, hintComp = null, ovr = {}) {
  let stateFlags = Watched(0)
  hintComp = hintComp ?? mkHint(shortcutId)
  return @() {
    watch = stateFlags
    size = [SIZE_TO_CONTENT, shortcutButtonHeight]
    behavior = Behaviors.Button
    rendObj = ROBJ_SOLID
    color = getShortcutButtonColor(stateFlags.get())
    function onElemState(sf) {
      let prevSf = stateFlags.get()
      stateFlags(sf)
      let active = isActive(sf)
      if (active != isActive(prevSf))
        if (active)
          setShortcutOn(shortcutId)
        else
          setShortcutOff(shortcutId)
    }
    onDetach = @() setShortcutOff(shortcutId)
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    padding = shortcutButtonPadding
    gap = shortcutButtonGap
    children = [
      hintComp
      textComp
    ]
  }.__update(ovr)
}

function mkShortcutButton(shortcutId, textComp, hintComp = null, ovr = {}) {
  hintComp = hintComp ?? mkHint(shortcutId)
  return watchElemState(@(sf) {
    size = [SIZE_TO_CONTENT, shortcutButtonHeight]
    behavior = Behaviors.Button
    rendObj = ROBJ_SOLID
    color = getShortcutButtonColor(sf)
    onClick = @() toggleShortcut(shortcutId)
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    padding = shortcutButtonPadding
    gap = shortcutButtonGap
    children = [
      hintComp
      textComp
    ]
  }.__update(ovr))
}

let mkShortcutText = @(text) mkText({ color = 0x99999999, font = Fonts.very_tiny_text_hud, text })

let fireButtonShortcutHint = @() {
  watch = showConsoleButtons
  children = showConsoleButtons.get() ? null
    : getShortcut(
        { inputName = "inputImage", buttonImage = "ui/gameuiskin#mouse_right" },
        { place = "antiAirMenu" })
}

return {
  mkFrame
  mkShortcutButton
  mkShortcutButtonContinued
  mkShortcutText
  shortcutButtonPadding
  frameHeaderHeight
  fireButtonShortcutHint
}
