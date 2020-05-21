local fontsState = require("reactiveGui/style/fontsState.nut")
local colors = require("reactiveGui/style/colors.nut")
local JB = require("reactiveGui/control/gui_buttons.nut")

local blockInterval = ::fpx(6)
local borderWidth = ::dp(1)

local defStyle = {
  defTextColor = colors.menu.commonTextColor
  ulSpacing = ::fpx(15)
  ulGap = blockInterval
  ulBullet = {rendObj = ROBJ_DTEXT, font = fontsState.get("normal"), text=" • "}
  ulNoBullet= { rendObj = ROBJ_DTEXT, font = fontsState.get("normal"), text="   " }
  h1Font = fontsState.get("bigBold")
  h2Font = fontsState.get("medium")
  textFont = fontsState.get("normal")
  noteFont = fontsState.get("small")
  h1Color = Color(220,220,250)
  h2Color = Color(200,250,200)
  urlColor = colors.menu.linkTextColor
  emphasisColor = colors.menu.activeTextColor
  urlHoverColor = colors.menu.linkTextHoverColorLight
  noteColor = colors.menu.chatTextBlockedColor
  padding = blockInterval
}

local noTextFormatFunc = @(object, style=defStyle) object

local function textArea(params, formatTextFunc=noTextFormatFunc, style=defStyle){
  return {
    rendObj = ROBJ_TEXTAREA
    text = params?.v
    behavior = Behaviors.TextArea
    color = style?.defTextColor ?? defStyle.defTextColor
    font = defStyle.textFont
    size = [flex(), SIZE_TO_CONTENT]
  }.__update(params)
}

local function url(data, formatTextFunc=noTextFormatFunc, style=defStyle){
  if (data?.url==null)
    return textArea(data, style)
  local stateFlags = Watched(0)
  local onClick = @() ::cross_call.openUrl(data.url)
  return function() {
    local color = stateFlags.value & S_HOVER ? style.urlHoverColor : style.urlColor
    return {
      rendObj = ROBJ_DTEXT
      text = data?.v ?? data.url
      behavior = Behaviors.Button
      color = color
      font = defStyle.textFont
      watch = stateFlags
      onElemState = @(sf) stateFlags(sf)
      children = [
        {rendObj=ROBJ_FRAME borderWidth = [0,0,borderWidth,0] color=color, size = flex()},
        stateFlags.value & S_HOVER ? { hotkeys = [["{0}".subst(JB.A), onClick]] } : null
      ]
      onClick = onClick
    }.__update(data)
  }
}

local function mkUlElement(bullet){
  return function (elem, formatTextFunc=noTextFormatFunc, style=defStyle) {
    local res = formatTextFunc(elem)
    if (res==null)
      return null
    if (::type(res)!="array")
      res = [res]
    return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      children = [bullet].extend(res)
    }
  }
}
local function mkList(elemFunc){
  return function(obj, formatTextFunc=noTextFormatFunc, style=defStyle) {
    return obj.__merge({
      flow = FLOW_VERTICAL
      size = [flex(), SIZE_TO_CONTENT]
      children = obj.v.map(@(elem) elemFunc(elem, formatTextFunc, style))
    })
  }
}
local function horizontal(obj, formatTextFunc=noTextFormatFunc, style=defStyle){
  return obj.__merge({
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    children = obj.v.map(@(elem) formatTextFunc(elem))
  })
}

local function vertical(obj, formatTextFunc=noTextFormatFunc, style=defStyle){
  return obj.__merge({
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    children = obj.v.map(@(elem) formatTextFunc(elem))
  })
}

local hangingIndent = calc_comp_size(defStyle.ulNoBullet)[0]

local bullets = mkList(mkUlElement(defStyle.ulBullet))
local indent = mkList(mkUlElement(defStyle.ulNoBullet))
local separatorCmp = {rendObj = ROBJ_FRAME borderWidth = [0,0,borderWidth, 0] size = [flex(),blockInterval], opacity=0.2, margin=[blockInterval, blockInterval, ::fpx(20), 0]}

local function textParsed(params, formatTextFunc=noTextFormatFunc, style=defStyle){
  if (params?.v == "----")
    return separatorCmp
  return textArea(params, formatTextFunc, style)
}

local formatters = {
  defStyle = defStyle//for modification, fixme, make instances
  def=textArea,
  string=@(string, formatTextFunc, style=defStyle) textParsed({v=string}, style),
  textParsed = textParsed,
  textArea = textArea,
  text=textArea,
  hangingText=@(obj, formatTextFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({ hangingIndent = hangingIndent }), style)
  h1 = @(text, formatTextFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge({font=style.h1Font, color=style.h1Color, margin = [0, 0, ::fpx(25), 0]}), style)
  h2 = @(text, formatTextFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge({font=style.h2Font, color=style.h2Color, margin = [0, 0, ::fpx(15), 0]}), style)
  emphasis = @(text, formatTextFunc=noTextFormatFunc, style=defStyle) textArea(text.__merge({color=style.emphasisColor, margin = [blockInterval,0]}), style)
  image = @(obj, formatTextFunc=noTextFormatFunc, style=defStyle) {rendObj = ROBJ_IMAGE image=::Picture(obj.v) size = [flex(), ::fpx(200)], keepAspect=true padding=style.padding, hplace = ALIGN_CENTER}.__update(obj)
  url = url
  note = @(obj, formatTextFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({font=style.noteFont, color=style.noteColor}), style)
  preformat = @(obj, formatTextFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({preformatted=FMT_KEEP_SPACES | FMT_NO_WRAP}), style)
  bullets = bullets
  indent = indent
  sep = @(obj, formatTextFunc=noTextFormatFunc, style=defStyle) separatorCmp.__merge(obj)
  horizontal = horizontal
  vertical = vertical
}

return formatters
