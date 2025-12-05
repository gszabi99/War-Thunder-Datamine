import "%sqstd/ecs.nut" as ecs

let cacheCompValues = {}
let db = ecs.g_entity_mgr.getTemplateDB()
let getTemplate = @(templateName) db.buildTemplateByName(templateName)

function getTemplateCompValue(templateName, compName, defValue = null) {
  if (templateName not in cacheCompValues)
    cacheCompValues[templateName] <- {}

  if (compName not in cacheCompValues[templateName]) {
    let tpl = getTemplate(templateName)
    let compValue = tpl?.getCompValNullable(compName)
    cacheCompValues[templateName][compName] <- compValue?.getAll() ?? compValue
  }

  return cacheCompValues[templateName][compName] ?? defValue
}

return {
  getTemplateCompValue
  getTemplate
}