local nativeApi = require("sony.webapi")
return require($"sonyLib/store/storeDataV{nativeApi.getPreferredVersion()}.nut")