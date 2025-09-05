from "%rGui/globals/ui_library.nut" import *

let colors = require("%rGui/style/colors.nut")
let voiceChatState = require("%rGui/chat/voiceChatState.nut")
let fontsState = require("%rGui/style/fontsState.nut")

let voiceChatElements = function() {
  let children = []
  foreach (idx, member in voiceChatState.voiceChatMembers.value) {
    let voiceChatMember = member
    let prevVisIdx = voiceChatMember.visibleIdx
    let curVisIdx = idx
    voiceChatMember.visibleIdx = curVisIdx
    if (prevVisIdx != curVisIdx) {
      let prefix = curVisIdx < prevVisIdx ? "voiceChatMoveBottom" : "voiceChatMoveTop"
      anim_start($"{prefix}{voiceChatMember.id}")
    }

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
          size = static [flex(15), SIZE_TO_CONTENT]
          font = fontsState.get("normal")
          color = colors.menu.activeTextColor
        }
      ]
      key = $"voice_chat_{voiceChatMember.id}"
      opacity = voiceChatMember.needShow.value ? 1.0 : 0.0
      transform = {}
      transitions = [{ prop = AnimProp.opacity, duration = voiceChatMember.animTime, easing = OutCubic }]
      animations = [
        { prop = AnimProp.translate, from = [0, 28], to = [0, 0], duration = 0.2,
          trigger = $"voiceChatMoveTop{voiceChatMember.id}" }
        { prop = AnimProp.translate, from = [0, -28], to = [0, 0], duration = 0.2,
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
