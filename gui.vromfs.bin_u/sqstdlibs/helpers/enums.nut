local u = require("u.nut")
global const PERSISTENT_DATA_PARAMS = "PERSISTENT_DATA_PARAMS"
local function isTable(v) {return type(v)=="table"}
local function isArray(v) {return type(v)=="array"}
local function isString(v) {return type(v)=="string"}
local function isFunction(v) {return type(v)=="function"}


/**
 * Contains all utility functions related to creation
 * of and managing in-game type enumerations.
 */

local assertOnce = function(uniqId, errorText) { throw(errorText) }

local function getPropValue(propName, typeObject) {
  local value = typeObject?[propName]

  // Calling 'value()' instead of 'typeObject[propName]()'
  // caused function to be called in a wrong environment.
  return isFunction(value) ? typeObject[propName]() : value
}

//caseSensitive work only with string propValues
local function getCachedType(propName, propValue, cacheTable, enumTable, defaultVal, caseSensitive = true) {
  if (!caseSensitive) {
    if (isString(propValue))
      propValue = propValue.tolower()
    else {
      assertOnce("bad propValue type",
        "enums: Bad value type for getCachedType with no caseSensitive:\n" +
        "propName = " + propName + ", propValue = " + propValue + ", propValueType = " + (typeof propValue))
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
      ::format("Unable to get cached enum by property: '%s'. No 'types' array found.", propName))
    enumTable.types <- []
  }

  foreach (typeTbl in enumTable.types) {
    if (!isTable(typeTbl))
      continue

    local valueArr = getPropValue(propName, typeTbl)
    if (!isArray(valueArr))
      valueArr = [valueArr]
    foreach (value in valueArr) {
      if (!caseSensitive)
        if (isString(value))
          value = value.tolower()
        else {
          assertOnce("bad value type",
            "enums: Bad value in type for no caseSensitive cache:\n" +
            "propName = " + propName + ", propValue = " + value + ", propValueType = " + (typeof value))
          continue
        }

      cacheTable[value] <- typeTbl
    }
  }
  return cacheTable?[propValue] ?? defaultVal
}

local function addType(enumTable, typeTemplate, typeName, typeDefinition, enumTablePersistId) {
  local typeTbl = enumTablePersistId != null
    ? persist($"{enumTablePersistId}/{typeName}", @() {})
    : (enumTable?[typeName] ?? {})

  typeTbl.clear()
  if (typeTemplate)
    foreach(key, value in typeTemplate)
      typeTbl[key] <- value

  foreach (key, value in typeDefinition)
    typeTbl[key] <- value

  enumTable[typeName] <- typeTbl

  local types = enumTable?.types
  if (isArray(types))
    u.appendOnce(typeTbl, types)
  else {
    assertOnce(
      "Not found types array",
      ::format("Unable to find 'types' array in enum table (type: %s).", typeName))
  }
  return typeTbl
}

/**
 * Adds multiple types to a given type enumeration.
 * @param {table} enumTable  - Type enumeration table, where new types should be added.
 * @param {table} typesToAdd - Table of types to add.
 * @param {string|null} [typeConstructor] - Optional type contrtuctor func, takes no params.
 *        It will be called for each type, using the type itself as an environment.
 * @param {string|null} [addTypeNameKey] - Optional key name for storing enumTable's key of a type
          in the type itself. This is a recommended way of creating unique ID for every type.
 * @param {string|null} [enumTablePersistId] - unique string ID for enumTable, to persist all types
 *        in typesToAdd, to preserve the existing links on type tables during scripts reloads.
 *        On reload, each type's table is preserved (as a container), cleared, and refilled.
 */
local function addTypes(enumTable, typesToAdd, typeConstructor = null, addTypeNameKey = null, enumTablePersistId = null) {
  local typeTemplate = enumTable?.template
  foreach (typeName, typeDefinition in typesToAdd) {
    local typeTbl = addType(enumTable, typeTemplate, typeName, typeDefinition, enumTablePersistId)
    if (addTypeNameKey)
      typeTbl[addTypeNameKey] <- typeName
    if (typeConstructor != null)
      typeConstructor.call(typeTbl)
  }
}

/**
 * Adds multiple types to a global type enumeration.
 * @param {string} enumTableName - Global variable name of type enumeration table.
 * @param {table} typesToAdd              - see addTypes().
 * @param {string|null} [typeConstructor] - see addTypes().
 * @param {string|null} [addTypeNameKey]  - see addTypes().
 * @param {bool} [shouldPersistTypes] - true if need to persist all types in typesToAdd,
          to preserve the existing links on type tables during scripts reloads. True by default.
 */
local function addTypesByGlobalName(enumTableName, typesToAdd, typeConstructor = null, addTypeNameKey = null,
                                    shouldPersistTypes = true) {

  local enumTable = ::getroottable()?[enumTableName]
  if (!isTable(enumTable)) {
    assertOnce("not found enum table", "enums: not found enum table '" + enumTableName + "'")
    return
  }

  local enumTablePersistId = shouldPersistTypes ? enumTableName : null
  addTypes(enumTable, typesToAdd, typeConstructor, addTypeNameKey, enumTablePersistId)
}

return {
  getCachedType = getCachedType
  addTypes = addTypes
  addTypesByGlobalName = addTypesByGlobalName

  setAssertFunction = @(func) assertOnce = func  //void func(uniqId, assertText)
}