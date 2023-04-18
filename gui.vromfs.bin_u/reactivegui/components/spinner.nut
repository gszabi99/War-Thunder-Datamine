from "%rGui/globals/ui_library.nut" import *

let pic = Picture($"ui/gameuiskin#throbber.svg:{fpx(44)}:{fpx(44)}:K")
return kwarg(function mkSpinner(height = fpx(44), color = Color(0, 0, 0, 0), duration = 3) {
  return {
    rendObj = ROBJ_SOLID
    color = color
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER

    children = {
      size = [height, height]
      rendObj = ROBJ_IMAGE
      image = pic
      key = pic
      keepAspect = true

      transform = {
        pivot = [0.5, 0.5]
      }

      animations = [
        { prop = AnimProp.rotate, from = 0, to = 360, duration = duration,
          play = true, loop = true, easing = Discrete8 }
      ]
    }
  }
})