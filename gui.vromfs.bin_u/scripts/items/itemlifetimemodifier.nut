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

    let parsedDependencies = dependenciesRe.multiExtract("\\1", formulaStr)
    dependencies = []
    foreach (dependencyStr in parsedDependencies)
    {
      dependencies.append(dependencyStr.tointeger())
    }
    let body = "return @(s) (" + formulaStr + ")"
    modifierFunction = compilestring(body)()
  }

  function calculate()
  {
    if (modifierFunction == null)
      return 1.0

    let params = {}
    foreach (dependency in dependencies)
    {
      params["count_" + dependency.tostring()] <- ::ItemsManager.getRawInventoryItemAmount(dependency)
    }
    return modifierFunction(params)
  }
}

return @(formula) ItemLifetimeModifier(formula)
