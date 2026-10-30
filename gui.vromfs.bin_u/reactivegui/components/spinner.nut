from "%rGui/globals/ui_library.nut" import *

return kwarg(function mkSpinner(height = fpx(44), color = Color(0, 0, 0, 0), duration = 3) {
  return {
    rendObj = ROBJ_SOLID
    color = color
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    children = {
      size = height
      rendObj = ROBJ_IMAGE
      image = Picture($"ui/gameuiskin#throbber.svg:{fpx(44)}:{fpx(44)}:K")
      key = "spinner"
      keepAspect = true

      transform = true

      animations = [
        { prop = AnimProp.rotate, from = 0, to = 360, duration = duration,
          play = true, loop = true, easing = Discrete8 }
      ]
    }
  }
})