from "%rGui/globals/ui_library.nut" import *

let colors = require("style/colors.nut")

const MAX_DOST = 5

let images = {
  dotHole = Picture("!ui/gameuiskin#dot_hole")
  dotFilled = Picture("!ui/gameuiskin#dot_filled")
}


let moduleIconConstructor = function (params) {
  let icon = type(params.icon) == "function"
               ? @() params.icon(params.iconWatch.value)
               : @() params.icon
  return @(color) @() {
    rendObj = ROBJ_IMAGE
    color =  color
    watch = params?.iconWatch
    image = icon()
    size = [hdpx(params.iconSize[0]), hdpx(params.iconSize[1])]

    transform = {}
    animations = [
      {
        prop = AnimProp.color
        from = colors.hud.damageModule.alertHighlight
        easing = Linear
        duration = 0.15
        trigger = params.brokenCountState
      }
      {
        prop = AnimProp.scale
        from = [1.3, 1.3]
        easing = InOutCubic
        duration = 0.15
        trigger = params.brokenCountState
      }
    ]
  }
}


let dotAlive = @(broken_count) {
  rendObj = ROBJ_IMAGE
  image = images.dotFilled
  color = broken_count > 0 ? colors.hud.damageModule.active : colors.hud.damageModule.inactive
  size = hdpx(10)
  margin = hdpx(2)
}


let dotDead = {
  rendObj = ROBJ_IMAGE
  image = images.dotHole
  color = colors.hud.damageModule.dmModuleDestroyed
  size = hdpx(10)
  margin = hdpx(2)
  transform = {}
  animations = [
    {
      prop = AnimProp.scale
      from = [1.3, 1.3]
      easing = InOutCubic
      play = true
      duration = 0.25
    }
  ]
}

let dots = function (total_count, broken_count) {
  let aliveCount = total_count - broken_count
  let children = []
  if (aliveCount > 0 && total_count > 0) {
    children.resize(aliveCount, dotAlive(broken_count))
    children.resize(total_count, dotDead)
  }

  return {
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    halign = ALIGN_CENTER
    children = children
  }
}


let text = @(total_count, broken_count) {
  rendObj = ROBJ_TEXT
  color = broken_count > 0 ? colors.hud.damageModule.active : colors.hud.damageModule.inactive
  halign = ALIGN_CENTER
  text = str((total_count - broken_count), "/", total_count)
}






let dmModule = function (params) {
  let totalCountState = params.totalCountState
  let brokenCountState = params.brokenCountState
  let cooldownState = params?.cooldownState

  let moduleIcon = moduleIconConstructor(params)

  return function () {
    if (totalCountState.value == 0) {
      return {
        watch = totalCountState
      }
    }

    local color = colors.hud.damageModule.dmModuleNormal
    if (cooldownState && cooldownState.value)
      color = colors.hud.componentFill
    else if (totalCountState.value == brokenCountState.value)
      color = colors.hud.damageModule.dmModuleDestroyed
    else if (brokenCountState.value > 0)
      color = colors.hud.damageModule.dmModuleDamaged
    anim_start(brokenCountState)

    let children = [moduleIcon(color)]
    if (totalCountState.value > 1) {
      if (totalCountState.value < MAX_DOST) {
        children.append(dots(totalCountState.value, brokenCountState.value))
      }
      else {
        children.append(text(totalCountState.value, brokenCountState.value))
      }
    }

    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_VERTICAL
      halign = ALIGN_CENTER
      watch = [
        totalCountState
        brokenCountState
        cooldownState
      ]

      children = children
    }
  }
}

let export = class {
  _call = @(_self, params) dmModule(params)
}()

return export
