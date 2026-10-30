import "%rGui/hud/hudMessageStack.nut" as mkHudMessageStack
import "%rGui/hints/hints.nut" as getHintContent
from "%appGlobals/hud/hudMessageStacks.nut" import playerDamage, tankNotifications, shipNotifications, hintMessagesHeight
from "%rGui/style/hudTextStyle.nut" import hudTextShade
from "%rGui/globals/ui_library.nut" import *

let textFontSize = getFontDefHt("tiny_text_hud")

let textStyle = freeze({
  font = Fonts.tiny_text_hud
  color = 0xFFFFFFFF
  ...hudTextShade
})

let mkNotificationText = @(entry) {
  size = FLEX_H
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  text = entry.text
  fontSize = textFontSize
  lineSpacing = 2
  ...textStyle
}

let damageHintStyle = freeze({
  ...textStyle
  place = "hudMessage"
  rowHeight = shHud(4) * 2 / 3
})

let mkDamageHint = @(entry) getHintContent(entry.text, damageHintStyle)

let mkLineStyle = @(stack, entryPadding) {
  entryPadding
  transform = const { pivot = 0 }
  appearAnim = [{ prop = AnimProp.scale, from = [1, 0], to = [1, 1], duration = stack.appearSec, easing = InCubic, play = true }]
  fadeAnim = [{ prop = AnimProp.scale, from = [1, 1], to = [1, 0], duration = stack.fadeSec, easing = OutCubic, play = true }]
  faded = const { transform = { pivot = 0, scale = [1, 0] } }
}

let onRecalcLayout = @(_initial, elem) hintMessagesHeight.set(elem.getHeight().tointeger())

return freeze({
  size = flex()
  clipChildren = true
  children = {
    size = FLEX_H
    vplace = ALIGN_BOTTOM
    flow = FLOW_VERTICAL
    behavior = Behaviors.RecalcHandler
    onRecalcLayout
    children = [
      mkHudMessageStack(playerDamage, mkDamageHint, mkLineStyle(playerDamage, null))
      mkHudMessageStack(tankNotifications, mkNotificationText, mkLineStyle(tankNotifications, const [1, 0]))
      mkHudMessageStack(shipNotifications, mkNotificationText, mkLineStyle(shipNotifications, const [1, 0]))
    ]
  }
})
