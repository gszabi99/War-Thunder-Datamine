from "%scripts/dagui_library.nut" import *
let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")

let isWorldWarEnabled = @() hasFeature("WorldWar")
  && (!isPlatformSony || isCrossPlayEnabled())

return {
  isWorldWarEnabled
}
