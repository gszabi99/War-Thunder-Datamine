let u = require("u.nut")

function isTable(v) {return type(v)=="table"}
function isArray(v) {return type(v)=="array"}
function isString(v) {return type(v)=="string"}
function isFunction(v) {return type(v)=="function"}







local assertOnce = function(_uniqId, errorText) { throw(errorText) }

function getPropValue(propName, typeObject) {
  let value = typeObject?[propName]

  
  
  return isFunction(value) ? typeObject[propName]() : value
}


function getCachedType(propName, propValue, cacheTable, enumTable, defaultVal, caseSensitive = true) {
  if (!caseSensitive) {
    if (isString(propValue))
      propValue = propValue.tolower()
    else {
      assertOnce("bad propValue type",
        "".concat("enums: Bad value type for getCachedType with no caseSensitive:\n",
            $"propName = {propName}, propValue = {propValue}, propValueType = {(type(propValue))}"))
      return defaultVal
    }
  }

  local val = cacheTable?[propValue]
  if (val != null)
    return val
  if (cacheTable.len())
    return defaultVal

  if (!("types" in enumTable)) {
    assertOnce("!types",
      $"Unable to get cached enum by property: '{propName}'. No 'types' array found.")
    enumTable.types <- []
  }

  foreach (typeTbl in enumTable.types) {
    if (!isTable(typeTbl))
      continue

    local valueArr = getPropValue(propName, typeTbl)
    if (!isArray(valueArr))
      valueArr = [valueArr]

    foreach (value in valueArr) {
      local key
      if (caseSensitive)
        key = value
      else if (isString(value))
        key = value.tolower()
      else {
        assertOnce("bad value type",
          "".concat("enums: Bad value in type for no caseSensitive cache:\n",
          $"propName = {propName}, propValue = {value}, propValueType = {(type(value))}"))
        continue
      }

      cacheTable[key] <- typeTbl
    }
  }
  return cacheTable?[propValue] ?? defaultVal
}

function addType(enumTable, typeTemplate, typeName, typeDefinition, enumTablePersistId) {
  let typeTbl = enumTablePersistId != null
    ? persist($"{enumTablePersistId}/{typeName}", @() {})
    : (enumTable?[typeName] ?? {})

  typeTbl.clear()
  typeTbl.__update(typeTemplate ?? {}, typeDefinition)

  enumTable[typeName] <- typeTbl

  local types = enumTable?.types
  if (isArray(types))
    u.appendOnce(typeTbl, types)
  else {
    assertOnce(
      "Not found types array",
      $"Unable to find 'types' array in enum table (type: {typeName})." )
  }
  return typeTbl
}













function addTypes(enumTable, typesToAdd, typeConstructor = null, addTypeNameKey = null, enumTablePersistId = null) {
  let typeTemplate = enumTable?.template
  foreach (typeName, typeDefinition in typesToAdd) {
    local typeTbl = addType(enumTable, typeTemplate, typeName, typeDefinition, enumTablePersistId)
    if (addTypeNameKey)
      typeTbl[addTypeNameKey] <- typeName
    if (typeConstructor != null)
      typeConstructor.call(typeTbl)
  }
}

return freeze({
  enumsGetCachedType = getCachedType
  enumsAddTypes = addTypes

  
  getCachedType
  addTypes

  setAssertFunction = @(func) assertOnce = func  
})