let charActionConsts = require_optional("charActionConsts")
let consttable = getconsttable()

let fields = [
  "EATT_SAVING",
  "EATT_LOADING",
  "EATT_CLANSYNCPROFILE",
  "EATT_BUYING_AIRCRAFT",
  "EATT_BUYING_SLOT",
  "EATT_TRAINING_AIRCRAFT",
  "EATT_BUYING_WEAPON",
  "EATT_BUYING_MODIFICATION",
  "EATT_BUYING_AIRCRAFT_CREW",
  "EATT_CLAN_TRANSACTION",
  "EATT_ENABLE_MODIFICATIONS",
  "EATT_REPAIR_AIRCRAFT",
  "EATT_SEND_BLK",
  "EATT_BUY_ENTITLEMENT",
  "EATT_UPDATE_ENTITLEMENTS",
  "EATT_SET_EXTERNAL_ID",
  "EATT_BUYING_UNLOCK",
  "EATT_COMPLAINT",
  "EATT_JSON_REQUEST",
  "EATT_SIMPLE_OK",
]

let export = {}
foreach (k in fields)
  export[k] <- charActionConsts?[k] ?? consttable[k]

return freeze(export)
