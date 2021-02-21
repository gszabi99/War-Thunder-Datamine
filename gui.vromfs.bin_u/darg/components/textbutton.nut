local defStyle = require("textButton.style.nut")
local fa = require("fontawesome.map.nut")
local Fonts = ::Fonts
local hdpx = ::hdpx
local pw = ::pw

local function textColor(sf, style=null, isEnabled = true) {
  local styling = defStyle.__merge(style ?? {})
  if (!isEnabled) return styling.TextDisabled
  if (sf & S_ACTIVE)    return styling.TextActive
  if (sf & S_HOVER)     return styling.TextHover
  if (sf & S_KB_FOCUS)  return styling.TextFocused
  return styling.TextNormal
}

local function borderColor(sf, style=null, isEnabled = true) {
  local styling = defStyle.__merge(style ?? {})
  if (!isEnabled) return styling.BdDisabled
  if (sf & S_ACTIVE)    return styling.BdActive
  if (sf & S_HOVER)     return styling.BdHover
  if (sf & S_KB_FOCUS)  return styling.BdFocused
  return styling.BdNormal
}

local function fillColor(sf, style=null, isEnabled = true) {
  local styling = defStyle.__merge(style ?? {})
  if (!isEnabled) return styling.BgDisabled
  if (sf & S_ACTIVE)    return styling.BgActive
  if (sf & S_HOVER)     return styling.BgHover
  if (sf & S_KB_FOCUS)  return styling.BgFocused
  return styling.BgNormal
}

local function fillColorTransp(sf, style=null, isEnabled = true) {
  local styling = defStyle.__merge(style ?? {})
  if (sf & S_ACTIVE)    return styling.BgActive
  if (sf & S_HOVER)     return styling.BgHover
  if (sf & S_KB_FOCUS)  return styling.BgFocused
  return 0
}

local defTextCtor = @(text, params, handler, group, sf) text
local textButton = @(fill_color, border_width) function(text, handler, params={}) {
  local isEnabled = params?.isEnabled ?? true
  local group = ::ElemGroup()
  local stateFlags = params?.stateFlags ?? ::Watched(0)
  local style = params?.style ?? defStyle
  local btnMargin =  params?.margin ?? defStyle.btnMargin
  local textMargin = params?.textMargin ?? defStyle.textMargin

  local font = params?.font ?? Fonts.medium_text //!!FIX ME: why real font name in general library?
  local size = params?.size ?? SIZE_TO_CONTENT
  local {halign = ALIGN_LEFT, valign = ALIGN_CENTER} = params
  local sound = params?.style.sound
  local textCtor = params?.textCtor ?? defTextCtor

  local function builder(sf) {
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
        rendObj = ROBJ_DTEXT
        text = (::type(text)=="function") ? text() : text
        scrollOnHover=true
        delay = 0.5
        speed = [hdpx(100),hdpx(700)]
        size = SIZE_TO_CONTENT
        maxWidth = pw(100)
        ellipsis = false
        margin = textMargin
        font
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


local export = class{
  Bordered = textButton(fillColor, hdpx(1))
  Underline = textButton(fillColor, [0,0,hdpx(1),0])
  Flat = textButton(fillColor, 0)
  Transp = textButton(fillColorTransp, 0)
  FA =          @(fa_key, handler, params={}) Flat     ((fa?[fa_key] ?? "N"), handler, {margin = 0 font = Fonts.fontawesome halign = ALIGN_CENTER valign=ALIGN_CENTER}.__update(params))
  FA_Bordered = @(fa_key, handler, params={}) Bordered ((fa?[fa_key] ?? "N"), handler, {margin = 0 font = Fonts.fontawesome halign = ALIGN_CENTER valign=ALIGN_CENTER}.__update(params))
  FA_Transp   = @(fa_key, handler, params={}) Transp   ((fa?[fa_key] ?? "N"), handler, {margin = 0 font = Fonts.fontawesome halign = ALIGN_CENTER valign=ALIGN_CENTER}.__update(params))

  _call = @(self, text, handler, params={}) Flat(text, handler, params)
}()


return export
