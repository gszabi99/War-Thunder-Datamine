from "%rGui/globals/ui_library.nut" import *
let hints = require("%rGui/hints/hints.nut")
let { toggleShortcut } = require("%globalScripts/controls/shortcutActions.nut")
let { antiAirMenuShortcutHeight } = require("%rGui/hints/shortcuts.nut")

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

function mkShortcutButton(shortcutId, textComp) {
  return watchElemState(@(sf) {
    size = [SIZE_TO_CONTENT, shortcutButtonHeight]
    behavior = Behaviors.Button
    rendObj = ROBJ_SOLID
    color = (sf & S_ACTIVE) ? 0x99020509
      : (sf & S_HOVER) ? 0xFF3A474F
      : 0
    onClick = @() toggleShortcut(shortcutId)
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    padding = shortcutButtonPadding
    gap = shortcutButtonGap
    children = [
      hints(shortcutId.concat("{{", "}}"), { place = "antiAirMenu" })
      textComp
    ]
  })
}

let mkShortcutText = @(text) mkText({ color = 0x99999999, font = Fonts.very_tiny_text_hud, text })

return {
  mkFrame
  mkShortcutButton
  mkShortcutText
  shortcutButtonPadding
  frameHeaderHeight
}
