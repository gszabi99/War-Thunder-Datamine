//checked for plus_string
from "%scripts/dagui_library.nut" import *

let nativeApi = require("sony.webapi")
return require($"%scripts/onlineShop/psnStoreItemV{nativeApi.getPreferredVersion()}.nut")