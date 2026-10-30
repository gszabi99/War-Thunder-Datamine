import "%rGui/style/teamColors.nut" as teamColors
from "%rGui/missionState.nut" import localTeam
from "%rGui/hud/plantSites/plantSiteCommon.nut" import blinkAnims, mkBlinkBucketW, siteColor, siteLetter
from "%rGui/globals/ui_library.nut" import *

const letterColor = 0x98000000

const pointSize = hdpxi(22)
const slotHeight = hdpxi(40)

let rhombusIcon = @() Picture($"ui/gameuiskin#basezone_small_rhombus.svg:{pointSize}:{pointSize}:P")
let letterIcon = @(site) Picture($"ui/gameuiskin#basezone_small_mark_no_bg_{siteLetter(site)}.svg:{slotHeight}:{slotHeight}:P")

function mkPlantSiteHudPoint(site) {
  let blinkBucketW = mkBlinkBucketW(site)
  return @() {
    watch = [localTeam, teamColors, blinkBucketW]
    key = site.eid
    size = const [SIZE_TO_CONTENT, slotHeight]
    valign = ALIGN_CENTER
    children = {
      size = pointSize
      children = [
        {
          key = $"plant_site_point_{blinkBucketW.get()}"
          size = FLEX
          rendObj = ROBJ_IMAGE
          image = rhombusIcon()
          keepAspect = true
          color = siteColor(site, localTeam.get(), teamColors.get())
          animations = blinkAnims[blinkBucketW.get()]
        }
        {
          size = FLEX
          rendObj = ROBJ_IMAGE
          image = letterIcon(site)
          keepAspect = true
          color = letterColor
        }
      ]
    }
  }
}

return freeze({
  mkPlantSiteHudPoint
})
