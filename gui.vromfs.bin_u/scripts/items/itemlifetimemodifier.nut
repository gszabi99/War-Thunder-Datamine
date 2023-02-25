//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let regexp2 = require("regexp2")

let class ItemLifetimeModifier {
  static dependenciesRe = regexp2("\\bs\\.count_([0-9]+)")

  modifierFunction = null
  dependencies = null

  constructor(formulaStr) {
    if (type(formulaStr) != "string" || ::u.isEmpty(formulaStr))
      return

    // for compatibility
    if (this.dependenciesRe?.multiExtract == null)
      return

    let parsedDependencies = this.dependenciesRe.multiExtract("\\1", formulaStr)
    this.dependencies = []
    foreach (dependencyStr in parsedDependencies) {
      this.dependencies.append(dependencyStr.tointeger())
    }
    let body = "return @(s) (" + formulaStr + ")"
    this.modifierFunction = compilestring(body)()
  }

  function calculate() {
    if (this.modifierFunction == null)
      return 1.0

    let params = {}
    foreach (dependency in this.dependencies) {
      params["count_" + dependency.tostring()] <- ::ItemsManager.getRawInventoryItemAmount(dependency)
    }
    return this.modifierFunction(params)
  }
}

return @(formula) ItemLifetimeModifier(formula)
