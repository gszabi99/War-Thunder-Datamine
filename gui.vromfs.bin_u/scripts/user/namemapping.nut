from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%scripts/dagui_library.nut" import *





let nameMapping = Watched(null)

local resetNameMapping = @() nameMapping.set({ f = {}, r = {} })
resetNameMapping()

addListenersWithoutEnv({
  MainMenuReturn = @(_) resetNameMapping()
})

return {
  updateNameMapping = @(r, f) nameMapping.mutate(function(v) {
    v.r[f] <- r
    v.f[r] <- f
  })
  getRealName = @(n) nameMapping.get().r?[n]
  getFakeName = @(n) nameMapping.get().f?[n]
}