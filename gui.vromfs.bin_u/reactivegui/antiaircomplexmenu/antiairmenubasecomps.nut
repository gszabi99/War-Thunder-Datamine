from "%rGui/globals/ui_library.nut" import *
let hints = require("%rGui/hints/hints.nut")
let { toggleShortcut, setShortcutOn, setShortcutOff
} = require("%globalScripts/controls/shortcutActions.nut")
let { antiAirMenuShortcutHeight } = require("%rGui/hints/shortcuts.nut")
let { MOUSE, JOYSTICK } = require("controls").DeviceType

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
  fontSize = getFontDefHt("tiny_text_hud") * (ovr?.scale ?? 1)
}.__update(ovr)

let mkFrameHeader = @(headerParams) {
  size = [flex(), frameHeaderHeight * (headerParams?.scale ?? 1)]
  rendObj = ROBJ_SOLID
  color = 0xFF2D343C
  padding = frameHeaderPadding
  valign = ALIGN_CENTER
  flow = FLOW_HORIZONTAL
  children = [
    mkText({ text = headerParams.text, scale = headerParams?.scale })
    { size = flex() }
    headerParams?.rightBlock
  ]
}

let mkFrame = @(content, headerParams = null, ovr = {}) {
  rendObj = ROBJ_BOX
  fillColor = 0xFF182029
  borderColor = 0xFF37454D
  borderWidth
  padding = borderWidth
  flow = FLOW_VERTICAL
  children = [
    headerParams != null ? mkFrameHeader(headerParams) : null
    content
  ]
}.__update(ovr)

let mkShortcutHint = @(shortcutId, scale = 1) hints(shortcutId.concat("{{", "}}"),
  { place = "antiAirMenu", scale, skipDeviceIds = { [MOUSE] = true, [JOYSTICK] = true } })

let isActive = @(sf) (sf & S_ACTIVE) != 0

let getShortcutButtonColor = @(sf)
  isActive(sf) ? 0x99020509
    : (sf & S_HOVER) ? 0xFF3A474F
    : 0

function mkShortcutButtonContinued(shortcutId, content, ovr = {}) {
  let stateFlags = Watched(0)
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
    children = content
  }.__update(ovr)
}

function mkShortcutButton(shortcutId, content, ovr = {}) {
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
    children = content
  }.__update(ovr))
}

let mkShortcutText = @(text, scale = 1) mkText({
  minWidth = antiAirMenuShortcutHeight
  color = 0x99999999
  font = Fonts.very_tiny_text_hud
  fontSize = getFontDefHt("very_tiny_text_hud") * scale
  text
  halign = ALIGN_CENTER
})

let mkTargetCell = @(size, fontSize, text) {
  size
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  rendObj = ROBJ_TEXT
  fontSize
  text
}

local targetStatusGetterForSort = {
  order = 1
  func = null
}
let targetSortFunctionWatched = Watched(0)
function targetsSortFunction(l, r) {
  let result = targetStatusGetterForSort.func(l) <=> targetStatusGetterForSort.func(r)
  return result * targetStatusGetterForSort.order
}

function makeTargetStatusEllementFactory(size, header_name, status_getter_compairable, status_to_text = @(status, _) status, upd = {}) {
  if (targetStatusGetterForSort.func == null) {
      targetStatusGetterForSort.func = status_getter_compairable
  }

  return {
    function construct_header(font_size) {
      let stateFlags = Watched(0)

      return function(){
        let isSortedByThis = targetStatusGetterForSort.func == status_getter_compairable
        local text = header_name
        if (isSortedByThis) {
          text += targetStatusGetterForSort.order > 0 ? "+" : "-"
        }

        return {
          watch = [targetSortFunctionWatched, stateFlags]
          rendObj = ROBJ_SOLID
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          size
          behavior = Behaviors.Button
          color = getShortcutButtonColor(stateFlags.get())

          onClick = function() {
            let changeOrder = targetStatusGetterForSort.func == status_getter_compairable
            targetStatusGetterForSort.order = changeOrder ? targetStatusGetterForSort.order * -1 : 1
            targetStatusGetterForSort.func = status_getter_compairable
            targetSortFunctionWatched.trigger()
          }

          function onElemState(sf) {
            stateFlags(sf)
          }

          children = mkTargetCell(flex(), font_size, text)
        }
      }
    }
    construct_ellement = @(target, font_size) @() mkTargetCell(size, font_size, status_to_text(status_getter_compairable(target), target)).__update(upd)
  }
}

return {
  mkFrame
  mkShortcutButton
  mkShortcutButtonContinued
  mkShortcutText
  mkShortcutHint
  shortcutButtonPadding
  frameHeaderHeight
  borderWidth
  makeTargetStatusEllementFactory
  targetsSortFunction
  targetSortFunctionWatched
}
