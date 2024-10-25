from "%rGui/globals/ui_library.nut" import *

let { getSettings } = require("%rGui/wwMap/wwSettings.nut")
let { sectorSprites } = require("%rGui/wwMap/wwMapStates.nut")
let { getZoneById, getZoneSize } = require("%rGui/wwMap/wwMapZonesData.nut")
let { convertColor4 } = require("%rGui/wwMap/wwMapUtils.nut")
let { get_time_msec } = require("dagor.time")
let { activeAreaBounds } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { setTimeout } = require("dagor.workcycle")
let { even } = require("%rGui/wwMap/wwUtils.nut")

let mkSectorSprite = @(sectorSpriteData, sectorSpriteSettings, areaBounds) function() {
  let { spriteColor, blinkColor, blinkPeriod, iconName, iconRotate = 0 } = sectorSpriteSettings
  let { areaWidth, areaHeight } = areaBounds

  let blinkDuration = (sectorSpriteData.endBlinkTime - get_time_msec()) / 1000
  let isActive = blinkDuration > 0
  let ownedZone = getZoneById(sectorSpriteData.zoneIdx)

  let zoneSize = getZoneSize()
  let spriteIconSize = even(zoneSize.w * areaWidth * 0.22)
  let pos = [areaWidth * ownedZone.center.x - spriteIconSize / 2, areaHeight * ownedZone.center.y - spriteIconSize / 2]
  setTimeout(blinkDuration, @() anim_request_stop($"sectorSprite_{sectorSpriteData.zoneIdx}"))

  return {
    rendObj = ROBJ_IMAGE
    pos
    size = [spriteIconSize, spriteIconSize]
    keepAspect = true
    image = Picture($"{iconName}:{spriteIconSize}:{spriteIconSize}")
    color = convertColor4(spriteColor)
    transform = {
      rotate = iconRotate
    }

    animations = [{ prop = AnimProp.color, from = convertColor4(blinkColor), to = convertColor4(spriteColor), duration = blinkPeriod,
      loop = true, easing = CosineFull, play = isActive, trigger = $"sectorSprite_{sectorSpriteData.zoneIdx}", globalTimer = true }]
  }
}

function mkSectorSprites() {
  let ssArray = sectorSprites.get()
  if (ssArray.len() == 0)
    return {
      watch = [sectorSprites, activeAreaBounds]
    }

  return {
    watch = [sectorSprites, activeAreaBounds]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = ssArray.map(function(ss) {
      let sectorSpriteSettings = getSettings("sectorSpritesSettings").getBlock(ss.type)
      return mkSectorSprite(ss, sectorSpriteSettings, activeAreaBounds.get())
    })
  }
}

return {
 mkSectorSprites
}