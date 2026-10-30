from "%scripts/dagui_library.nut" import *

return freeze({
  getTitleLogo = @(logoHeight = 64) "ui/{0}{1}.ddsx".subst(loc("id_full_title"), logoHeight)
})