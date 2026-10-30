from "%scripts/dagui_library.nut" import *

let convertExpWndOpenParams = mkWatchedClearedOnReload(null) 

let openConvertExpModalWnd = @(unit = null) convertExpWndOpenParams.set({ unit })
let closeConvertExpModalWnd = @() convertExpWndOpenParams.set(null)

return freeze({
  convertExpWndOpenParams

  openConvertExpModalWnd
  closeConvertExpModalWnd
})