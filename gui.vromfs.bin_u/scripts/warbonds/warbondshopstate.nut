from "%scripts/dagui_natives.nut" import warbonds_get_purchase_limit
from "%scripts/dagui_library.nut" import *

let getPurchaseLimitWb = @(warbond) warbonds_get_purchase_limit(warbond.id, warbond.listId)

let leftSpecialTasksBoughtCount = Watched(-1)

return {
  leftSpecialTasksBoughtCount
  getPurchaseLimitWb
}
