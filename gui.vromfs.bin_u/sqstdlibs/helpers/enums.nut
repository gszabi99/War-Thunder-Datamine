from "%sqStdLibs/helpers/toString.nut" import toString
from "types" import Table, Array, String, Function

function isTable(v) {return v instanceof Table}
function isInstance(v) {return type(v) == "instance"}
function isArray(v) {return v instanceof Array}
function isString(v) {return v instanceof String}
function isFunction(v) {return v instanceof Function}







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
    if (!isTable(typeTbl) && !isInstance(typeTbl))
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
  if (enumTable?[typeName] == typeTbl) 
    return typeTbl

  enumTable[typeName] <- typeTbl
  enumTable.types.append(typeTbl)
  return typeTbl
}













function addTypes(enumTable, typesToAdd, typeConstructor = null, addTypeNameKey = null, enumTablePersistId = null) {
  let { template = null, types = null } = enumTable
  if (!(types instanceof Array)) {
    assertOnce(
      "Not found types array",
      $"Unable to find 'types' array in enum table /*typesToAdd = {toString(typesToAdd, 2)}*/")
    return
  }

  foreach (typeName, typeDefinition in typesToAdd) {
    local typeTbl = addType(enumTable, template, typeName, typeDefinition, enumTablePersistId)
    if (addTypeNameKey)
      typeTbl[addTypeNameKey] <- typeName
    if (typeConstructor != null)
      typeConstructor.call(typeTbl)
  }
}





function addTypesAsInstances(enumTable, typesToAdd, typeConstructor = null, addTypeNameKey = null) {
  let { template = {}, types = null } = enumTable
  if (!(types instanceof Array)) {
    assertOnce(
      "Not found types array",
      $"Unable to find 'types' array in enum table /*typesToAdd = {toString(typesToAdd, 2)}*/")
    return
  }

  let typeClass = class {}
  foreach (key, value in template) {
    typeClass[key] <- null 
    typeClass[key] <- value
  }
  foreach (typeDefinition in typesToAdd)
    foreach (key, _ in typeDefinition)
      if (key not in typeClass)
        typeClass[key] <- null
  if (addTypeNameKey != null && addTypeNameKey not in typeClass)
    typeClass[addTypeNameKey] <- null

  foreach (typeName, typeDefinition in typesToAdd) {
    let typeObj = typeClass()
    foreach (key, value in typeDefinition)
      typeObj[key] = value
    enumTable[typeName] <- typeObj
    types.append(typeObj)
    if (addTypeNameKey)
      typeObj[addTypeNameKey] = typeName
    if (typeConstructor != null)
      typeConstructor.call(typeObj)
  }
}

return freeze({
  enumsGetCachedType = getCachedType
  enumsAddTypes = addTypes
  enumsAddTypesAsInstances = addTypesAsInstances

  
  getCachedType
  addTypes

  setAssertFunction = @(func) assertOnce = func  
})