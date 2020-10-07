local nativeApi = require("sony.webapi")
return require($"scripts/onlineShop/psnStoreItemV{nativeApi.getPreferredVersion()}.nut")