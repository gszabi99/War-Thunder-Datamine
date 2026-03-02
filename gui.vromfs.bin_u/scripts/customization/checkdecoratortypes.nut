from "%scripts/dagui_library.nut" import *

let { decoratorTypes } = require("%scripts/customization/decoratorBaseType.nut")
let { decoratorViewTypes } = require("%scripts/customization/decoratorViewType.nut")

function checkDecoratorTypes() {
  let checkList = {}
  foreach(decType in decoratorTypes.types)
    checkList[decType.resourceType] <- 1
  foreach(decType in decoratorViewTypes.types)
    checkList[decType.resourceType] <- (checkList?[decType.resourceType] ?? 0) - 1

  foreach(resourceType, count in checkList) {
    if (count == 0)
      continue
    logerr($"Error during checking decorator types: decorator type with '{resourceType}' resourceType exist only in one table!")
  }
}

checkDecoratorTypes()