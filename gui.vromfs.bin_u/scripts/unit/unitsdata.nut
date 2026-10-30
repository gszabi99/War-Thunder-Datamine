import "packed" as packed

let allUnits = persist("allUnits", @() {})
let packedFields = persist("unitPackedFields", @() { root = packed.pack({}) })

let emptyTable = freeze({})
let unitPackedFieldNames = freeze(["shop", "info"])

let getAllUnits = @() allUnits

function setUnitsPackedFields(unitTbls) {
  let res = {}
  foreach (unitTbl in unitTbls) {
    let { name, shop, info = null } = unitTbl
    res[name] <- info == null ? { shop } : { shop, info }
  }
  packedFields.root = packed.pack(res)
}

let getUnitPackedFieldValue = @(unitName, key) packed.get(packedFields.root, unitName, key) ?? emptyTable

return freeze({
  unitPackedFieldNames
  getAllUnits
  getUnitPackedFieldValue
  setUnitsPackedFields
  hasUnitsPackedFields = @() packed.len(packedFields.root) > 0
})
