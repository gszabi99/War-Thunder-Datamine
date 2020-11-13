local colors = require("reactiveGui/style/colors.nut")
local voiceChatState = require("voiceChatState.nut")
local fontsState = require("reactiveGui/style/fontsState.nut")

local voiceChatElements = function() {
  local children = []
  foreach(idx, member in voiceChatState.voiceChatMembers.value) {
    local voiceChatMember = member

    voiceChatMember.needShow.subscribe(function(newVal) {
      ::gui_scene.clearTimer(callee())
      if (newVal)
      {
        anim_start("voiceChatShow" + voiceChatMember.id)
        return
      }

      anim_start("voiceChatHide" + voiceChatMember.id)
    })

    local prevVisIdx = voiceChatMember.visibleIdx
    local curVisIdx = idx
    voiceChatMember.visibleIdx = curVisIdx
    if (prevVisIdx != curVisIdx)
    {
      local prefix = curVisIdx < prevVisIdx ? "voiceChatMoveBottom" : "voiceChatMoveTop"
      anim_start(prefix + voiceChatMember.id)
    }

    children.insert(0, {
      size = [::fpx(400), SIZE_TO_CONTENT]
      flow = FLOW_HORIZONTAL
      gap = ::fpx(6)

      children = [
        {
          rendObj = ROBJ_IMAGE
          size = [::fpx(18), ::fpx(26)]
          image = ::Picture("!ui/gameuiskin#voip_status.svg:"
            + (::fpx(18)) + ":" + ::fpx(26) + ":K")
          color = colors.menu.voiceChatIconActiveColor
        }
        @(){
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          text = voiceChatMember.name
          size = [flex(15), SIZE_TO_CONTENT]
          font = fontsState.get("normal")
          color = colors.menu.activeTextColor
        }
      ]
      key = "voice_chat_" + voiceChatMember.id
      transform = {}
      animations = [
        { prop=AnimProp.opacity, from=0.0, to=1.0, duration=voiceChatMember.animTime,
          easing=OutCubic, trigger = "voiceChatShow" + voiceChatMember.id }
        { prop=AnimProp.opacity, from=1.0, to=0.0, duration=voiceChatMember.animTime,
          easing=OutCubic, trigger = "voiceChatHide" + voiceChatMember.id }
        { prop=AnimProp.translate, from=[0, 28], to=[0, 0], duration=0.2,
          trigger = "voiceChatMoveTop" + voiceChatMember.id }
        { prop=AnimProp.translate, from=[0, -28], to=[0, 0], duration=0.2,
          trigger = "voiceChatMoveBottom" + voiceChatMember.id }
      ]
    })
  }

  return children
}

local voiceChatWidget = @() {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    valign = ALIGN_BOTTOM
    gap = ::fpx(2)
    children = voiceChatElements()
    watch = voiceChatState.voiceChatMembers
  }


return voiceChatWidget
