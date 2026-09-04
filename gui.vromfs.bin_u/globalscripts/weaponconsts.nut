let weaponConsts = require_optional("weaponConsts")
let consttable = getconsttable()

let fields = [
  "TRIGGER_GROUP_PRIMARY",
  "TRIGGER_GROUP_SECONDARY",
  "TRIGGER_GROUP_COAXIAL_GUN",
  "TRIGGER_GROUP_MACHINE_GUN",
  "TRIGGER_GROUP_SPECIAL_GUN",
  "TRIGGER_GROUP_EXTRA_GUN_1",
  "TRIGGER_GROUP_EXTRA_GUN_2",
  "TRIGGER_GROUP_EXTRA_GUN_3",
  "TRIGGER_GROUP_EXTRA_GUN_4",
]

let export = {}
foreach (k in fields)
  export[k] <- weaponConsts?[k] ?? consttable[k]

return freeze(export)
