from "%appGlobals/user/nickTools.nut" import PSN_ICON
from "%rGui/globals/ui_library.nut" import *

let psnIconToEmbed = @[pure, nodiscard](text) text.replace(PSN_ICON, "<psnIcon/>")

function mkPsnIconEmbed(font, fontSize = 0) {
  let { ascent, descent } = get_font_metrics(font, fontSize)
  let size = (ascent + descent).tointeger()
  return {
    psnIcon = {
      size = [size, ascent.tointeger()]
      children = {
        size
        rendObj = ROBJ_IMAGE
        vplace = ALIGN_TOP
        image = Picture($"ui/gameuiskin#psn_icon.svg:{size}:{size}:P")
      }
    }
  }
}

return {
  psnIconToEmbed
  mkPsnIconEmbed
}
