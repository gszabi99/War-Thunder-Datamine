from "%rGui/globals/ui_library.nut" import *

let { shellHitDamageEvents } = require("shipState.nut")
let { eventbus_subscribe } = require("eventbus")
let { cursorVisible } = require("%rGui/ctrlsState.nut")
let DataBlock = require("DataBlock")
let { shipHitIconsVisibilityStateFlags } = require("options/options.nut")
let { ShipHitIconId, ShipHitIconVisibilityMask,
  IS_SHIP_HIT_NOTIFICATIONS_VISIBLE } = require("%globalScripts/shipHitIconsConsts.nut")


const SHOW_RESET_DEFAULT_DURATION = 10
const DEFAULT_ICON_SIZE = 40
const DEFAULT_ICON_FONT = "very_tiny_text_hud"


const ICONHIT_MAX_SCALE = 1.25
const ICONHIT_SHOW_TIME = 0.2


const HITBOX_FADE_OUT_TIME = 1

function mkAppearAnim(trigger) {
  return [
    { prop = AnimProp.scale, from = [0, 0] to = [ICONHIT_MAX_SCALE, ICONHIT_MAX_SCALE], duration = 0.35, trigger = trigger }
    { prop = AnimProp.opacity, from = 1, to = 1, duration = ICONHIT_SHOW_TIME, trigger = trigger }
    { prop = AnimProp.opacity, delay = ICONHIT_SHOW_TIME, from = 1, to = 0, easing = OutQuad, duration = 0.25, trigger = trigger }
  ]
}

function mkIconHint(hintText) {
  return {
    pos = [0, ph(150)]
    margin = [0, hdpx(12), 0, 0]
    padding = [hdpx(5), hdpx(10)]
    minWidth = hdpx(50)
    zOrder = Layers.Tooltip
    fillColor = 0xFF2D343C
    borderColor = 0xFF3A434E
    borderWidth = hdpx(1)
    rendObj = ROBJ_BOX
    flow = FLOW_HORIZONTAL
    hplace = ALIGN_RIGHT
    halign = ALIGN_CENTER

    children = {
      rendObj = ROBJ_TEXT
      text = loc(hintText)
      color = 0xFFC0C0C0
    }
  }
}


function mkIcon(baseCfg, iconCfg, watched) {
  let text = Computed(@() $"x{watched.get()}")
  let size = [baseCfg.iconSize, baseCfg.iconSize]
  let animTrigger = {}
  let stateFlags = Watched(0)
  return {
    icon = @() {
      watch = [cursorVisible, stateFlags]
      rendObj = ROBJ_IMAGE
      size = size
      valign = ALIGN_CENTER
      behavior = Behaviors.Button
      onElemState = @(v) stateFlags(v)
      image = iconCfg.pic

      children = [
        cursorVisible.get() && (stateFlags.get() & S_HOVER) ? mkIconHint(iconCfg.hintLoc) : null
        {
          rendObj = ROBJ_IMAGE
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          size = size
          opacity = 0
          image = iconCfg.pic
          transform = {
            scale = [1, 1]
          }
          animations = mkAppearAnim(animTrigger)
          onAttach = @() anim_start(animTrigger)
        }
        iconCfg.text.enabled ? @() {
          rendObj = ROBJ_TEXT
          pos = [0, ph(48)]
          watch = text
          padding = [0, 0, hdpx(10), 0]
          text = text.get()
          size = flex()
          font = baseCfg.iconFont
          color = iconCfg.text.color
          halign = ALIGN_RIGHT
          valign = ALIGN_BOTTOM
          fontFx = FFT_GLOW
          fontFxColor = 0xFF40515C
          fontFxFactor = 40
        } : null
      ]
    }
    animTrigger
  }
}



local scriptConfig = null

function readIconConfig(baseCfg, iconBlk, ico, watched, params) {
  let config = {
    hintLoc = params.hintLoc
    enabled = iconBlk?.enabled ?? true
    text = {
      enabled = iconBlk?.text.enabled ?? true
      color = iconBlk?.text.color ?? 0xACACACAC
    }
    pic = ico
  }
  return config.__merge({
    iconObj = mkIcon(baseCfg, config, watched)
  })
}

function getConfig() {
  if (scriptConfig != null) {
    return scriptConfig
  }

  let res = {
    resetDuration = null
    iconsConfig = null
    iconSize = null
    iconFont = null
    alignHitCamera = null
  }

  let hudBlk = DataBlock()
  let gameplayBlk = DataBlock()

  hudBlk.tryLoad("config/hud.blk")
  let iconsParams = hudBlk?.shipHitNotification

  let size = iconsParams?.size ?? DEFAULT_ICON_SIZE
  res.iconSize = hdpx(size)

  let hitPic = Picture($"ui/gameuiskin#dm_ship_armor_hit.svg:{res.iconSize}:{res.iconSize}:P")
  let effectiveHitPic = Picture($"ui/gameuiskin#dm_ship_armor_breach.svg:{res.iconSize}:{res.iconSize}:P");
  let ineffectiveHitPic = Picture($"ui/gameuiskin#dm_ship_armor_unbroken.svg:{res.iconSize}:{res.iconSize}:P");
  let pierceThroughHitPic = Picture($"ui/gameuiskin#dm_ship_armor_breach_through.svg:{res.iconSize}:{res.iconSize}:P");

  let font = iconsParams?.font ?? DEFAULT_ICON_FONT
  res.iconFont = Fonts[font]

  res.alignHitCamera = iconsParams?.alignHitCamera ?? true
  res.iconsConfig = {
    [ShipHitIconId.HIT] = readIconConfig(
      res, iconsParams?.simpleHit, hitPic, shellHitDamageEvents.hitEventsCount, {id = ShipHitIconId.HIT, hintLoc = "shipHitHint/simpleHit"}),
    [ShipHitIconId.HIT_EFFECTIVE] = readIconConfig(
      res, iconsParams?.effectiveHit, effectiveHitPic, shellHitDamageEvents.critEventCount, {hintLoc = "shipHitHint/effectiveHit"}),
    [ShipHitIconId.HIT_INEFFECTIVE] = readIconConfig(
      res, iconsParams?.ineffectiveHit, ineffectiveHitPic, shellHitDamageEvents.armorBlockedEventCount, {hintLoc = "shipHitHint/ineffectiveHit"}),
    [ShipHitIconId.HIT_PIERCE_THROUGH] = readIconConfig(
      res, iconsParams?.pierceThroughHit, pierceThroughHitPic, shellHitDamageEvents.pierceThroughCount, {hintLoc = "shipHitHint/pierceThroughHit"}),
  }

  gameplayBlk.tryLoad("config/gameplay.blk")
  res.resetDuration = gameplayBlk?.hudShowHitInfoTime ?? SHOW_RESET_DEFAULT_DURATION

  scriptConfig = res
  return res
}

let getIconConfig = @(id) getConfig().iconsConfig[id]
let getIconObj = @(id) getIconConfig(id).iconObj

local showBitmask = 0

let hitBoxShowAnimTrigger = {}
let hitNotificationVisible = Watched(false)
let hudHitCameraState = mkWatched(persist, "hudHitCameraState", null)
let hits = Watched([])

function resetHitBox() {
  hitNotificationVisible(false)
  anim_request_stop(hitBoxShowAnimTrigger)
  showBitmask = 0
  hits.mutate(@(arr) arr.clear())
}

function showHitBox() {
  hitNotificationVisible(true)
  anim_start(hitBoxShowAnimTrigger)
}


function pushIndicator(items, id) {
  items.append(id)
  items.sort(@(a, b) a <=> b)
}

function popIndicator(items, popId) {
  foreach(idx, id in items) {
    if (id == popId) {
      items.remove(idx)
      items.sort(@(a, b) a <=> b)
      break
    }
  }
}

function appendHitIndicator(v, id) {
  let { enabled, iconObj } = getIconConfig(id)
  let mask = 1 << id
  let isEnabledInUseropts = !!(ShipHitIconVisibilityMask[id]
    & shipHitIconsVisibilityStateFlags.get())

  if (!enabled || !isEnabledInUseropts)
    return

  if (v > 0) {
    if ((showBitmask & mask) == 0) {
      showBitmask = showBitmask | mask
      hits.mutate(@(arr) pushIndicator(arr, id))
    }
    anim_start(iconObj.animTrigger)
    showHitBox()
  } else {
    showBitmask = showBitmask & ~mask
    hits.mutate(@(arr) popIndicator(arr, id))
  }
}

shellHitDamageEvents.hitEventsCount.subscribe(@(v) appendHitIndicator(v, ShipHitIconId.HIT))
shellHitDamageEvents.critEventCount.subscribe(@(v) appendHitIndicator(v, ShipHitIconId.HIT_EFFECTIVE))
shellHitDamageEvents.armorBlockedEventCount.subscribe(@(v) appendHitIndicator(v, ShipHitIconId.HIT_INEFFECTIVE))
shellHitDamageEvents.pierceThroughCount.subscribe(@(v) appendHitIndicator(v, ShipHitIconId.HIT_PIERCE_THROUGH))

eventbus_subscribe("setHudHitCameraState", function(params) {
  hudHitCameraState.set(params ? {
    pos = params.pos
    size = params.size
  } : null)
})

let isHitcamSet = Computed(@() hudHitCameraState.get() != null)
let hitboxY = Computed(@() isHitcamSet.get()
  ? hudHitCameraState.get().pos[1] + hudHitCameraState.get().size[1] + hdpx(35)
  : 0)
let hitboxX = Computed(@() isHitcamSet.get()
  ? hudHitCameraState.get().pos[0]
  : 0)

let hitNotifications = function() {
  let { resetDuration, alignHitCamera } = getConfig()
  let res = {
    watch = [hitNotificationVisible, hits, hitboxX, hitboxY, isHitcamSet]
    gap = hdpx(7)
    opacity = 0
    pos = [hitboxX.get(), hitboxY.get()]
    flow = FLOW_HORIZONTAL
    children = hitNotificationVisible.get() ? hits.get().map(@(v) getIconObj(v).icon ) : null
    onDetach = @() resetHitBox()
    animations = [
      {
        prop = AnimProp.opacity
        from = 1
        to = 1
        duration = resetDuration - HITBOX_FADE_OUT_TIME
        trigger = hitBoxShowAnimTrigger
      }
      {
        prop = AnimProp.opacity
        from = 1
        to = 0
        delay = resetDuration - HITBOX_FADE_OUT_TIME
        duration = HITBOX_FADE_OUT_TIME
        trigger = hitBoxShowAnimTrigger
        onFinish = @() resetHitBox()
      }
    ]
  }
    
  if (!alignHitCamera || !isHitcamSet.get()) {
    return res.__merge({
      hplace = ALIGN_CENTER
      size = [SIZE_TO_CONTENT, flex()]
      pos = isHitcamSet.get()
        ? [0, hudHitCameraState.get().pos[1] + hudHitCameraState.get().size[1]/1.15]
        : [0, hdpx(-140)]
    })
  }

  return res
}

return {
  hitNotifications = IS_SHIP_HIT_NOTIFICATIONS_VISIBLE ? hitNotifications : null
}