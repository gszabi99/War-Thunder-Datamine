

from "%rGui/globals/ui_library.nut" import *

let mkText = @[pure, nodiscard] (text, font, color, ovr = {}) { rendObj = ROBJ_TEXT, text, font, color }.__update(ovr)


let scaleChannel = @(color, shift, alpha) (((color >> shift) & 0xFF) * alpha / 255) << shift
let mulAlpha = @[pure, nodiscard] (color, alpha) alpha >= 255 ? color
  : scaleChannel(color, 24, alpha) | scaleChannel(color, 16, alpha) | scaleChannel(color, 8, alpha)
    | scaleChannel(color, 0, alpha)
let pictureName = @[pure, nodiscard] (image) image.startswith("#") ? image.slice(1)
  : image.startswith("!#") ? $"!{image.slice(2)}"
  : image

return freeze({
  mkText
  mulAlpha
  pictureName
})
