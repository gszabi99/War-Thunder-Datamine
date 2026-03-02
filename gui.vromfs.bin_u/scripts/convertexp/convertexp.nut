from "%scripts/dagui_library.nut" import *

let convertExpWndOpenParams = Watched(null) 

let openConvertExpModalWnd = @(unit = null) convertExpWndOpenParams.set({ unit })
let closeConvertExpModalWnd = @() convertExpWndOpenParams.set(null)

return {
  convertExpWndOpenParams

  openConvertExpModalWnd
  closeConvertExpModalWnd
}