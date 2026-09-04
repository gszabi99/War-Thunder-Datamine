let clanNativeConsts = require_optional("clanNativeConsts")
let consttable = getconsttable()

let fields = [
  "ULC_REJECT_MEMBERSHIP",
  "ULC_DISMISS",
  "ULC_CREATE",
  "ULC_REQUEST_MEMBERSHIP",
  "ULC_CHANGE_ROLE",
  "ULC_ADD_TO_BLACKLIST",
  "ULC_DEL_FROM_BLACKLIST",
  "ULC_ACCEPT_MEMBERSHIP",
  "ULC_DISBAND",
  "ULC_LEAVE",
  "ULC_DISBANDED_BY_LEADER",
  "ULC_CANCEL_MEMBERSHIP",
  "ULC_CHANGE_CLAN_INFO",
  "ULC_DISBANDED_BY_ADMIN",
  "ULC_CLAN_INFO_WAS_CHANGED",
  "ULC_CHANGE_ROLE_AUTO",
  "ULC_UPGRADE_CLAN",
  "ULC_UPGRADE_MEMBERS",
  "ECMR_LEADER",
  "ECMR_CLANADMIN",
  "ECMR_MAX_TOTAL",
  "ECT_UNKNOWN",
  "ECT_NORMAL",
  "ECT_BATTALION",
  "ECT_COUNT",
]

let export = {}
foreach (k in fields)
  export[k] <- clanNativeConsts?[k] ?? consttable[k]

return freeze(export)
