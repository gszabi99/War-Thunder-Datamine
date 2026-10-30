import "%rGui/style/teamColors.nut" as teamColors
import "%rGui/hud/hudMessageStack.nut" as mkHudMessageStack
from "%appGlobals/hud/hudMessageStacks.nut" import killFeed
from "%rGui/globals/ui_library.nut" import *

let feedFontSize = getFontDefHt("tiny_text_hud")

let mkKillText = @(entry) @() {
  watch = teamColors
  size = FLEX_H
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  halign = ALIGN_RIGHT
  text = entry.text
  font = Fonts.tiny_text_hud
  fontSize = feedFontSize
  lineSpacing = 2
  color = 0xFFFFFFFF
  colorTable = teamColors.get()
  fontFx = FFT_SHADOW
  fontFxColor = 0x80000000
  fontFxFactor = 24
  fontFxOffsX = 1
  fontFxOffsY = 1
}

let feed = mkHudMessageStack(killFeed, mkKillText, {
  vplace = ALIGN_BOTTOM
  entryPadding = const [1, 0]
  transform = const { pivot = 1 }
  appearAnim = [{ prop = AnimProp.scale, from = [1, 0], to = [1, 1], duration = killFeed.appearSec, easing = InCubic, play = true }]
  fadeAnim = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = killFeed.fadeSec, easing = OutQuad, play = true }]
  faded = const { opacity = 0 }
})

return freeze({
  size = FLEX
  clipChildren = true
  children = feed
})
