import "%rGui/style/colors.nut" as colors
import "%rGui/chat/voiceChatState.nut" as voiceChatState
import "%rGui/style/fontsState.nut" as fontsState
from "%rGui/globals/ui_library.nut" import *

voiceChatState.voiceChatMembers.subscribe(function(members) {
  foreach (idx, member in members) {
    let prevVisIdx = member.visibleIdx
    member.visibleIdx = idx
    if (prevVisIdx != idx) {
      let prefix = idx < prevVisIdx ? "voiceChatMoveBottom" : "voiceChatMoveTop"
      anim_start($"{prefix}{member.id}")
    }
  }
})

let voiceChatElements = function() {
  let children = []
  foreach (voiceChatMember in voiceChatState.voiceChatMembers.get()) {
    children.insert(0, @() {
      watch = voiceChatMember.needShow
      size = [fpx(400), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = fpx(6)

      children = [
        {
          rendObj = ROBJ_IMAGE
          size = [fpx(18), fpx(26)]
          image = Picture($"!ui/gameuiskin#voip_status.svg:{fpx(18)}:{fpx(26)}:K")
          color = colors.menu.voiceChatIconActiveColor
        }
        @() {
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          text = voiceChatMember.name
          size = const [flex(15), SIZE_TO_CONTENT]
          font = fontsState.get("normal")
          color = colors.menu.activeTextColor
        }
      ]
      key = $"voice_chat_{voiceChatMember.id}"
      opacity = voiceChatMember.needShow.get() ? 1.0 : 0.0
      transform = {}
      transitions = [{ prop = AnimProp.opacity, duration = voiceChatMember.animTime, easing = OutCubic }]
      animations = [
        { prop = AnimProp.translate, from = const [0, 28], to = const [0, 0], duration = 0.2,
          trigger = $"voiceChatMoveTop{voiceChatMember.id}" }
        { prop = AnimProp.translate, from = const [0, -28], to = const [0, 0], duration = 0.2,
          trigger = $"voiceChatMoveBottom{voiceChatMember.id}" }
      ]
    })
  }

  return children
}

let voiceChatWidget = @() {
    size = FLEX_H
    flow = FLOW_VERTICAL
    valign = ALIGN_BOTTOM
    gap = fpx(2)
    children = voiceChatElements()
    watch = voiceChatState.voiceChatMembers
  }


return voiceChatWidget
