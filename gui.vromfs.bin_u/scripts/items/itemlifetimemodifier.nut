local ItemLifetimeModifier = class {
  static dependenciesRe = ::regexp2("\\bs\\.count_([0-9]+)")

  modifierFunction = null
  dependencies = null

  constructor(formulaStr)
  {
    if (typeof formulaStr != "string" || u.isEmpty(formulaStr))
      return

    // for compatibility
    if (dependenciesRe?.multiExtract == null)
      return

    local parsedDependencies = dependenciesRe.multiExtract("\\1", formulaStr)
    dependencies = []
    foreach (dependencyStr in parsedDependencies)
    {
      dependencies.append(dependencyStr.tointeger())
    }
    local body = "return @(s) (" + formulaStr + ")"
    modifierFunction = compilestring(body)()
  }

  function calculate()
  {
    if (modifierFunction == null)
      return 1.0

    local params = {}
    foreach (dependency in dependencies)
    {
      params["count_" + dependency.tostring()] <- ::ItemsManager.getRawInventoryItemAmount(dependency)
    }
    return modifierFunction(params)
  }
}

return @(formula) ItemLifetimeModifier(formula)
