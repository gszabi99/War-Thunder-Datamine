local function textarea(txt, params={}) {
  if (::type(txt)=="table")
    txt = params?.text ?? ""
  return {
    size = [flex(), SIZE_TO_CONTENT]
    font = Fonts.small_text
    halign = ALIGN_LEFT
  }.__update(params).__update({rendObj=ROBJ_TEXTAREA behavior = Behaviors.TextArea text=txt})
}

return textarea