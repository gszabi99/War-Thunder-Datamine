//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let nativeApi = require("sony.webapi")
return require($"%scripts/onlineShop/psnStoreItemV{nativeApi.getPreferredVersion()}.nut")