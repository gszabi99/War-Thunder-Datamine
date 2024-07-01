from "%rGui/globals/ui_library.nut" import *

let fontsState = require("%rGui/style/fontsState.nut")
let defStyle = require("textButton.style.nut")

function textColor(sf, style = null, isEnabled = true) {
  let styling = defStyle.__merge(style ?? {})
  if (!isEnabled)
    return styling.TextDisabled
  if (sf & S_ACTIVE)
    return styling.TextActive
  if (sf & S_HOVER)
    return styling.TextHover
  if (sf & S_KB_FOCUS)
    return styling.TextFocused
  return styling.TextNormal
}

function borderColor(sf, style = null, isEnabled = true) {
  let styling = defStyle.__merge(style ?? {})
  if (!isEnabled)
    return styling.BdDisabled
  if (sf & S_ACTIVE)
    return styling.BdActive
  if (sf & S_HOVER)
    return styling.BdHover
  if (sf & S_KB_FOCUS)
    return styling.BdFocused
  return styling.BdNormal
}

function fillColor(sf, style = null, isEnabled = true) {
  let styling = defStyle.__merge(style ?? {})
  if (!isEnabled)
    return styling.BgDisabled
  if (sf & S_ACTIVE)
    return styling.BgActive
  if (sf & S_HOVER)
    return styling.BgHover
  if (sf & S_KB_FOCUS)
    return styling.BgFocused
  return styling.BgNormal
}

function fillColorTransp(sf, style = null, _isEnabled = true) {
  let styling = defStyle.__merge(style ?? {})
  if (sf & S_ACTIVE)
    return styling.BgActive
  if (sf & S_HOVER)
    return styling.BgHover
  if (sf & S_KB_FOCUS)
    return styling.BgFocused
  return 0
}

let defTextCtor = @(text, _params, _handler, _group, _sf) text
let textButton = @(fill_color, border_width) function(text, handler, params = {}) {
  let isEnabled = params?.isEnabled ?? true
  let group = ElemGroup()
  let stateFlags = params?.stateFlags ?? Watched(0)
  let style = params?.style ?? defStyle
  let btnMargin =  params?.margin ?? defStyle.btnMargin
  let textMargin = params?.textMargin ?? defStyle.textMargin

  let { halign = ALIGN_LEFT, valign = ALIGN_CENTER, font = fontsState.get("normal"), fontSize = null, size = SIZE_TO_CONTENT } = params
  let sound = params?.style.sound
  let textCtor = params?.textCtor ?? defTextCtor
  function builder(sf) {
    return {
      watch = stateFlags
      onElemState = @(v) stateFlags(v)
      margin = params?.margin ?? btnMargin
      key = ("key" in params) ? params.key : handler

      group

      rendObj = ROBJ_BOX
      size
      fillColor = fill_color(sf, style, isEnabled)
      borderWidth = border_width
      borderRadius = hdpx(4)
      halign
      valign
      clipChildren = true
      borderColor = borderColor(sf, style, isEnabled)
      sound

      children = textCtor({
        rendObj = ROBJ_TEXT
        text = (type(text) == "function") ? text() : text
        scrollOnHover = true
        delay = 0.5
        speed = [hdpx(100), hdpx(700)]
        size = SIZE_TO_CONTENT
        maxWidth = pw(100)
        ellipsis = false
        margin = textMargin
        font
        fontSize
        group
        behavior = [Behaviors.Marquee]
        color = textColor(sf, style, isEnabled)
      }.__update(params?.textParams ?? {}), params, handler, group, sf)

      behavior = Behaviors.Button
      onClick = isEnabled ? handler : null
    }.__update(params)
  }

  return @() builder(stateFlags.value)
}


let export = class{
  Bordered = textButton(fillColor, hdpx(1))
  Underline = textButton(fillColor, [0, 0, hdpx(1), 0])
  Flat = textButton(fillColor, 0)
  Transp = textButton(fillColorTransp, 0)

  _call = @(_self, text, handler, params = {}) this.Flat(text, handler, params)
}()


return export
