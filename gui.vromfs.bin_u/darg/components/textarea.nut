local function textarea(txt, params={}) {
  if (::type(txt)=="table")
    txt = params?.text ?? ""
  return {
    size = [flex(), SIZE_TO_CONTENT]
    halign = ALIGN_LEFT
  }.__update(params, {rendObj=ROBJ_TEXTAREA behavior = Behaviors.TextArea text=txt})
}

return textarea