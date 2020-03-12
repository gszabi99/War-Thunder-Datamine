/*
  Here we 'format' 'AST' - array of objects (AST) and return it as one darg Component as result of applying formatters, style and filters
  objects should be {t=[name_of_formatter], v=<value>} and any other fields

  By default we format all strings and objects without tag as textarea, everything else as horizontal separator
  formatters are pattern matched by 't' field in object to show
  this is poorman's markdown-like - without parsing text any how we expect that parsing would be done by man. Or it would be just textArea\preformat textArea
  however subset(?) of real markdown can be done by implemening parser of markdown text into result syntax tree

  I'm not sure 100% that it can be done now, cause we need to implement or use whole textArea behavior - split text into strings and objects and put it on baseline
  But probably it can.
  As once was said - do this part as your homework
  PS Not sure that tail recursion work here

  Example:
  formatText([
    {t="h1" v="BIG UPDATE (this is header1)"}
    {t="h2" v= "This is header level 2"}
    {t="bullets" v = [
      "bullet1", "bullet2"
    ]}
    {t="indent" v = [
      "* point1",
      "* point2"]
    }
    {t="sep" v="----"}
    {t="url" url = "http://gaijin.net", v = "(visit site)"}
    {t="sep"}
    {t="preformat" v =
    @"  • Feature1
        • Feature2 <color=#ff9999> colored text</color>
          • Feature2.1
    "}
    {platforms = "ps4" v="• PS4 feature"}
  ])

*/
local unknownTag = @(...) {rendObj=ROBJ_SOLID opacity=0.2 size=[flex(), hdpx(2)], margin=[0, hdpx(5)], color = Color(255,120,120)}
local function defTextArea(params, formatAstFunc, style={}){
  return {
    rendObj = ROBJ_TEXTAREA
    text = params?.v
    behavior = Behaviors.TextArea
    color = style?.defTextColor
    size = [flex(), SIZE_TO_CONTENT]
  }.__update(params)
}

local defFormatters = {
  string = @(text, formatAstFunc, style={}) defTextArea({v=text}, formatAstFunc, style)
  def = defTextArea
}

local defStyle = {
  lineGaps = hdpx(5)
}

local mkFormatAst = ::kwarg(function mkFormatAstImpl(formatters = defFormatters, filter = @(obj) false, style = defStyle){
  if (formatters != defFormatters)
    formatters=defFormatters.__merge(formatters)
  if (style != defStyle)
    style = defStyle.__merge(style)

  return function formatAst(object, params={}){
    local formatAstFunc = ::callee()
    if (::type(object) == "string")
      return formatters["string"](object, formatAstFunc, style)
    if (object==null)
      return null

    if (::type(object) == "table") {
      if (filter(object))
        return null

      local tag = object?.t ?? object?.tag
      if (!("v" in object))
        object = object.__merge({v=null})

      if (tag==null)
        return formatters["def"](object, formatAstFunc, style)
      if (tag in formatters)
        return formatters[tag](object, formatAstFunc, style)
      return unknownTag(object)
    }
    local ret = []
    if (::type(object) == "array") {
      foreach (t in object)
        ret.append(formatAstFunc(t))
    }
    return {
      children = ret
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      gap = style?.lineGaps
    }.__update(params ?? {})
  }
})

return mkFormatAst
