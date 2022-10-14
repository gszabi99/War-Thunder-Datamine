from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

return {
  getTitleLogo = @(logoHeight = 64) "ui/{0}{1}.ddsx".subst(loc("id_full_title"), logoHeight)
}