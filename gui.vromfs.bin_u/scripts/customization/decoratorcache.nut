from "%scripts/dagui_library.nut" import *

let decoratorCache = {}
let waitingItemdefs = persist("waitingItemdefs", @() {})
let liveDecoratorsCache = {}

return {
  decoratorCache
  waitingItemdefs
  liveDecoratorsCache
}