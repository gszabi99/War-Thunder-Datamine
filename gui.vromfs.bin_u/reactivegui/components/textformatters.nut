let fontsState = require("%rGui/style/fontsState.nut")
let colors = require("%rGui/style/colors.nut")
let {toIntegerSafe} = require("%sqstd/string.nut")

let blockInterval = ::fpx(6)
let headerMargin = 2*blockInterval
let borderWidth = ::dp(1)

let defStyle = {
  defTextColor = colors.menu.commonTextColor
  ulSpacing = ::fpx(15)
  ulGap = blockInterval
  ulBullet = {rendObj = ROBJ_TEXT, font = fontsState.get("normal"), text=" • "}
  ulNoBullet= { rendObj = ROBJ_TEXT, font = fontsState.get("normal"), text="   " }
  h1Font = fontsState.get("bigBold")
  h2Font = fontsState.get("medium")
  h3Font = fontsState.get("normal")
  textFont = fontsState.get("normal")
  noteFont = fontsState.get("small")
  h1Color = Color(220,220,250)
  h2Color = Color(200,250,200)
  h3Color = Color(200,250,250)
  urlColor = colors.menu.linkTextColor
  emphasisColor = colors.menu.activeTextColor
  urlHoverColor = colors.menu.linkTextHoverColorLight
  noteColor = colors.menu.chatTextBlockedColor
  padding = blockInterval
}

let noTextFormatFunc = @(object, _style=defStyle) object

let function textArea(params, _formatTextFunc=noTextFormatFunc, style=defStyle){
  return {
    rendObj = ROBJ_TEXTAREA
    text = params?.v
    behavior = Behaviors.TextArea
    color = style?.defTextColor ?? defStyle.defTextColor
    font = defStyle.textFont
    size = [flex(), SIZE_TO_CONTENT]
  }.__update(params)
}

let function url(data, fmtFunc=noTextFormatFunc, style=defStyle){
  if (data?.url==null)
    return textArea(data, fmtFunc, style)
  let stateFlags = Watched(0)
  let onClick = @() ::cross_call.openUrl(data.url)
  return function() {
    let color = stateFlags.value & S_HOVER ? style.urlHoverColor : style.urlColor
    return {
      rendObj = ROBJ_TEXT
      text = data?.v ?? data.url
      behavior = Behaviors.Button
      color = color
      font = defStyle.textFont
      watch = stateFlags
      onElemState = @(sf) stateFlags(sf)
      children = [
        {rendObj=ROBJ_FRAME borderWidth = [0,0,borderWidth,0] color=color, size = flex()},
      ]
      onClick = onClick
    }.__update(data)
  }
}

let function mkUlElement(bullet){
  return function (elem, formatTextFunc=noTextFormatFunc, _style=defStyle) {
    local res = formatTextFunc(elem)
    if (res==null)
      return null
    if (type(res)!="array")
      res = [res]
    return {
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      children = [bullet].extend(res)
    }
  }
}
let function mkList(elemFunc){
  return function(obj, formatTextFunc=noTextFormatFunc, style=defStyle) {
    return obj.__merge({
      flow = FLOW_VERTICAL
      size = [flex(), SIZE_TO_CONTENT]
      children = obj.v.map(@(elem) elemFunc(elem, formatTextFunc, style))
    })
  }
}
let function horizontal(obj, formatTextFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    children = obj.v.map(@(elem) formatTextFunc(elem))
  })
}

let function accent(obj, formatTextFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_SOLID
    color = Color(0,30,50,30)
    children = obj.v.map(@(elem) formatTextFunc(elem))
  })
}

let function vertical(obj, formatTextFunc=noTextFormatFunc, _style=defStyle){
  return obj.__merge({
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    children = obj.v.map(@(elem) formatTextFunc(elem))
  })
}

let hangingIndent = calc_comp_size(defStyle.ulNoBullet)[0]

let bullets = mkList(mkUlElement(defStyle.ulBullet))
let indent = mkList(mkUlElement(defStyle.ulNoBullet))
let separatorCmp = {rendObj = ROBJ_FRAME borderWidth = [0,0,borderWidth, 0] size = [flex(),blockInterval], opacity=0.2, margin=[blockInterval, blockInterval, ::fpx(20), 0]}

let function textParsed(params, formatTextFunc=noTextFormatFunc, style=defStyle){
  if (params?.v == "----")
    return separatorCmp
  return textArea(params, formatTextFunc, style)
}

let function column(obj, formatTextFunc=noTextFormatFunc, _style=defStyle){
  return {
    flow = FLOW_VERTICAL
    size = [flex(), SIZE_TO_CONTENT]
    children = obj.v.map(@(elem) formatTextFunc(elem))
  }
}

let getColWeightByPresetAndIdx = @(idx, preset) toIntegerSafe(preset?[idx+1], 100, false)

let function columns(obj, formatTextFunc=noTextFormatFunc, _style=defStyle){
  local preset = obj?.preset ?? "single"
  preset = preset.split("_")
  local cols = obj.v.filter(@(v) v?.t=="column")
  cols = cols.slice(0, preset.len())
  return {
    flow = FLOW_HORIZONTAL
    size = [flex(), SIZE_TO_CONTENT]
    children = cols.map(function(col, idx) {
      return {
        flow = FLOW_VERTICAL
        size = [flex(getColWeightByPresetAndIdx(idx, preset)), SIZE_TO_CONTENT]
        children = formatTextFunc(col.v)
        clipChildren = true
      }
    })
  }
}

let function video(obj, _formatTextFunc, style=defStyle) {
  let stateFlags = Watched(0)
  let width = ::fpx(obj?.imageWidth ?? 300)
  let height = ::fpx(obj?.imageHeight ?? 80)
  return @() {
    borderColor = stateFlags.value & S_HOVER ? style.urlHoverColor : Color(25,25,25)
    borderWidth = ::fpx(1)
    watch = stateFlags
    onElemState = @(sf) stateFlags(sf)
    behavior = Behaviors.Button
    fillColor = Color(12,12,12,255)
    rendObj = ROBJ_BOX
    size = [width, height]
    padding= ::fpx(1)
    margin = ::fpx(5)
    valign = ALIGN_BOTTOM
    hplace = ALIGN_CENTER
    keepAspect = true image = obj?.image
    children = freeze({
      rendObj = ROBJ_SOLID
      color = Color(0,0,0,150)
      halign = ALIGN_CENTER
      size = [flex(), SIZE_TO_CONTENT]
      children = {rendObj = ROBJ_TEXT text = obj?.caption
        ?? ::loc("Watch video") padding = ::fpx(5)}
    })
    onClick = function() {
      if (obj?.v)
        ::cross_call.openUrl(obj.v)
    }
  }.__update(obj)
}

let function image(obj, _formatTextFunc=noTextFormatFunc, style=defStyle) {
  return {
    rendObj = ROBJ_IMAGE
    image=::Picture(obj.v)
    maxWidth = pw(100)
    size = [obj?.width!=null
      ? ::fpx(obj.width) : flex(), obj?.height != null
        ? ::fpx(obj.height) : ::fpx(200)]
    keepAspect=true padding=style.padding
    children = {
      rendObj = ROBJ_TEXT text = obj?.caption vplace = ALIGN_BOTTOM
      fontFxColor = Color(0,0,0,150)
      fontFxFactor = min(64, ::fpx(64))
      fontFx = FFT_GLOW
    }
    hplace = ALIGN_CENTER
  }.__update(obj)
}

let formatters = {
  defStyle//for modification, fixme, make instances
  def=textArea
  string=@(string, fmtFunc, style=defStyle) textParsed({v=string}, fmtFunc, style),
  textParsed
  textArea
  text=textArea
  paragraph=textArea
  hangingText=@(obj, fmtFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({ hangingIndent = hangingIndent }), fmtFunc, style)
  h1 = @(text, fmtFunc=noTextFormatFunc, style=defStyle)
    textArea(text.__merge({font=style.h1Font, color=style.h1Color, margin = [headerMargin,0]}), fmtFunc, style)
  h2 = @(text, fmtFunc=noTextFormatFunc, style=defStyle)
    textArea(text.__merge({font=style.h2Font, color=style.h2Color, margin = [headerMargin,0]}), fmtFunc, style)
  h3 = @(text, fmtFunc=noTextFormatFunc, style=defStyle)
    textArea(text.__merge({fontStyle=style.h3Font, color=style.h3Color, margin = [headerMargin,0]}), fmtFunc, style)
  emphasis = @(text, fmtFunc=noTextFormatFunc, style=defStyle)
    textArea(text.__merge({color=style.emphasisColor, margin = [headerMargin,0]}), fmtFunc, style)
  columns
  column
  image
  url
  note = @(obj, fmtFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({font=style.noteFont, color=style.noteColor}), fmtFunc, style)
  preformat = @(obj, fmtFunc=noTextFormatFunc, style=defStyle) textArea(obj.__merge({preformatted=FMT_KEEP_SPACES | FMT_NO_WRAP}), fmtFunc, style)
  bullets
  list = bullets
  indent
  sep = @(obj, _formatTextFunc=noTextFormatFunc, _style=defStyle) separatorCmp.__merge(obj)
  horizontal
  vertical
  accent
  video
}

return formatters
