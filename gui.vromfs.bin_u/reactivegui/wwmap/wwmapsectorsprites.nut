from "%appGlobals/worldWar/wwSettings.nut" import getSettings
from "%rGui/wwMap/wwMapStates.nut" import sectorSprites
from "%rGui/wwMap/wwMapZonesData.nut" import getZoneById, getZoneSize
from "%rGui/wwMap/wwMapUtils.nut" import convertColor4
from "%rGui/wwMap/wwOperationConfiguration.nut" import activeAreaBounds
from "%rGui/wwMap/wwUtils.nut" import even
from "dagor.time" import get_time_msec
from "dagor.workcycle" import setTimeout
from "math" import floor
from "%rGui/globals/ui_library.nut" import *

let mkSectorSprite = @(sectorSpriteData, sectorSpriteSettings, areaBounds) function() {
  let { spriteColor, blinkColor, blinkPeriod, iconName, iconRotate = 0 } = sectorSpriteSettings
  let { areaWidth, areaHeight } = areaBounds

  let blinkDuration = (sectorSpriteData.endBlinkTime - get_time_msec()) / 1000
  let isActive = blinkDuration > 0
  let ownedZone = getZoneById(sectorSpriteData.zoneIdx)

  let zoneSize = getZoneSize()
  let spriteIconSize = even(zoneSize.w * areaWidth * 0.22)
  let pos = [floor(areaWidth * ownedZone.center.x - spriteIconSize / 2), floor(areaHeight * ownedZone.center.y - spriteIconSize / 2)]
  setTimeout(blinkDuration, @() anim_request_stop($"sectorSprite_{sectorSpriteData.zoneIdx}"))

  return {
    rendObj = ROBJ_IMAGE
    pos
    size = [spriteIconSize, spriteIconSize]
    keepAspect = true
    image = Picture($"{iconName}:{floor(spriteIconSize)}:{floor(spriteIconSize)}")
    color = convertColor4(spriteColor)
    subPixel = true
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