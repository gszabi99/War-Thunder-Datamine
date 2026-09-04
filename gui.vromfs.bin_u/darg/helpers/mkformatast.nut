from "%darg/ui_imports.nut" import *
from "types" import String, Table, Array






































let unknownTag = @(...) {rendObj=ROBJ_SOLID opacity=0.2 size=const [flex(), hdpx(2)], margin=const [0, hdpx(5)], color = Color(255,120,120)}
function defTextArea(params, _formatAstFunc, style={}){
  return {
    rendObj = ROBJ_TEXTAREA
    text = params?.v
    behavior = Behaviors.TextArea
    color = style?.defTextColor
    size = FLEX_H
  }.__update(params)
}

let defFormatters = {
  string = @(text, formatAstFunc, style={}) defTextArea({v=text}, formatAstFunc, style)
  def = defTextArea
}

let defStyle = {
  lineGaps = hdpx(5)
}

let mkFormatAst = kwarg(function mkFormatAstImpl(formatters = defFormatters, filter = @(_obj) false, style = defStyle){
  if (formatters != defFormatters)
    formatters=defFormatters.__merge(formatters)
  if (style != defStyle)
    style = defStyle.__merge(style)

  return function formatAst(object, params={}){
    let formatAstFunc = callee()
    if (object instanceof String)
      return formatters["string"](object, formatAstFunc, style)
    if (object==null)
      return null

    if (object instanceof Table) {
      if (filter(object))
        return null

      let tag = object?.t ?? object?.tag
      if (!("v" in object))
        object = object.__merge({v=null})

      if (tag==null)
        return formatters["def"](object, formatAstFunc, style)
      if (tag in formatters)
        return formatters[tag](object, formatAstFunc, style)
      return unknownTag(object)
    }
    let ret = []
    if (object instanceof Array) {
      foreach (t in object)
        ret.append(formatAstFunc(t))
    }
    return {
      children = ret
      size = FLEX_H
      flow = FLOW_VERTICAL
      gap = style?.lineGaps
    }.__update(params ?? {})
  }
})

return mkFormatAst
