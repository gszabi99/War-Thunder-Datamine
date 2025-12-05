from "%rGui/globals/ui_library.nut" import *

let { hudBlurPanel } = require("%rGui/components/blurPanel.nut")
let { actionBarItemHeight, actionBarItemWidth
} = require("%rGui/hud/humanSquad/humanConst.nut")
let { selfHealMedkits } = require("%rGui/hud/state/medkits_es.nut")
let { hp, maxHp } = require("%rGui/hud/state/health_es.nut")
let { grenades } = require("%rGui/hud/state/grenades_es.nut")
let { grenadeIconColored, getGrenadeType } = require("%rGui/hud/humanSquad/grenadeIcon.nut")
let { white, hud } = require("%rGui/style/colors.nut")
let { disabledHudColor } = hud
let hints = require("%rGui/hints/hints.nut")

let internalPadding = evenPx(11)
let iconSize = const [ shHud(3), shHud(3) ]

let mkSmallText = @(text, color) {
  rendObj = ROBJ_TEXT
  text
  color
  font = Fonts.tiny_text_hud
}

let mkIcon = @(image, color) {
  size = iconSize
  rendObj = ROBJ_IMAGE
  color
  image
}

let getShortcutText = @(text, color) hints( text, {
  place = "actionItemInfantry"
  bgImageColor = color
  shColor = color
})

function medkitsBlock() {
  let icon = Picture($"!ui/gameuiskin#first_aid_kit.avif:{iconSize[0]}:{iconSize[1]}")

  return {
    watch = [ selfHealMedkits, hp, maxHp ]
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    children = [
      mkIcon(icon, selfHealMedkits.get() > 0 ? white : disabledHudColor)
      mkSmallText($"x{selfHealMedkits.get()} ",
      selfHealMedkits.get() > 0 ? white : disabledHudColor)
      getShortcutText("{{ID_HUMAN_USE_MEDKIT}}", hp.get() < maxHp.get() && selfHealMedkits.get() > 0
        ? null : disabledHudColor)
    ]
  }
}

function grenadesBlock() {
  let grenadeType = Computed(function() {
    let t = getGrenadeType(grenades.get().keys())
    return t == null || t == "wall_bomb" ? null : t
  })
  let grenadesCount = Computed(@() grenades.get()?[grenadeType.get()] ?? 0)

  return @() {
    watch = [ grenadeType, grenadesCount ]
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    children = [
      mkIcon(
        grenadeIconColored(grenadeType.get(), iconSize[0]),
        grenadesCount.get() > 0 ? white : disabledHudColor
      )
      mkSmallText($"x{grenadesCount.get()} ",
        grenadesCount.get() > 0 ? white : disabledHudColor)
      getShortcutText("{{ID_HUMAN_THROW}}", grenadesCount.get() > 0 ? null : disabledHudColor)
    ]
  }
}

return function() {
  return {
    size = [ actionBarItemWidth, actionBarItemHeight ]
    children = [
      hudBlurPanel
      {
        size = flex()
        valign = ALIGN_CENTER
        halign = ALIGN_CENTER
        flow = FLOW_VERTICAL
        padding = internalPadding
        children = [
          medkitsBlock
          {
            size = flex()
          }
          grenadesBlock()
        ]
      }
    ]
  }
}