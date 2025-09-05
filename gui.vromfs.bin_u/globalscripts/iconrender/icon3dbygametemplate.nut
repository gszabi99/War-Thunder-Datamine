import "%sqstd/ecs.nut" as ecs

let mkIcon3d = require("%globalScripts/iconRender/icon3d.nut")
let { getLocalLanguage } = require("language")


function applyHarmonizationImpl(template, objTexReplace, objTexSet) {
  let objTexHarmonize = template.getCompValNullable("animchar__objTexHarmonize")
  if (objTexHarmonize == null)
    return

  objTexReplace.append(objTexHarmonize?["animchar__objTexReplace"]?.getAll() ?? {})
  objTexSet.append(objTexHarmonize?["animchar__objTexSet"]?.getAll() ?? {})
}

let applyHarmonization = getLocalLanguage() == "HChinese" ? applyHarmonizationImpl : @(...) null

let DB = ecs.g_entity_mgr.getTemplateDB()

function mkDecorAnimchar(decor) {
  let animchar = DB.getTemplateByName(decor?.template)?.getCompValNullable("animchar__res")
  return decor.__merge(animchar ? { animchar } : {})
}

function getIconInfoByGameTemplate(template, params = {}) {
  let decorators = template.getCompValNullable("attach_decorators__templates")?.getAll().map(mkDecorAnimchar)

  let objTexReplace = [template.getCompValNullable("animchar__objTexReplace")?.getAll() ?? {}]
  let objTexSet = [template.getCompValNullable("animchar__objTexSet")?.getAll() ?? {}]

  applyHarmonization(template, objTexReplace, objTexSet)
  let renderIconSettings = params?.renderSettingsPlace
    ? template.getCompValNullable(params?.renderSettingsPlace)?.getAll() ?? {}
    : {}

  let getTemplateParam = @(paramName) template.getCompValNullable(paramName)
    ?? renderIconSettings?[paramName]

  return {
    iconName = template.getCompValNullable("animchar__res")
    itemTemplate = template.getCompValNullable("item__weapTemplate") ?? ""
    objTexReplace
    objTexSet
    decorators
    hideNodes = template.getCompValNullable("disableDMParts")?.getAll() ?? []
    blendFactor = getTemplateParam("item__blendFactor")

    iconPitch = params?.itemPitch ?? getTemplateParam("item__iconPitch")
    iconYaw = params?.itemYaw ?? getTemplateParam("item__iconYaw")
    iconRoll = params?.itemRoll ?? getTemplateParam("item__iconRoll")
    iconOffsX = params?.itemOfsX ?? getTemplateParam("item__iconOffset")?.x
    iconOffsY = params?.itemOfsY ?? getTemplateParam("item__iconOffset")?.y
    iconScale = params?.itemScale ?? getTemplateParam("item__iconScale")
    distance = params?.distance ?? getTemplateParam("item__distance")

    brightness = params?.brightness ?? getTemplateParam("item__brightness")
    paintColor = params?.paintColor ?? getTemplateParam("item__paintColor")

    silhouetteColor = params?.silhouetteColor ?? getTemplateParam("item__silhouetteColor")
    silhouetteInactiveColor = params?.silhouetteInactiveColor
      ?? getTemplateParam("item__silhouetteInactiveColor")
    silhouetteHasShadow = params?.silhouetteHasShadow ?? getTemplateParam("item__silhouetteHasShadow")
    silhouetteMinShadow = params?.silhouetteMinShadow ?? getTemplateParam("item__silhouetteMinShadow")

    outlineColor = params?.outlineColor ?? getTemplateParam("item__outlineColor")
    outlineInactiveColor = params?.outlineInactiveColor
      ?? getTemplateParam("item__outlineInactiveColor")
    sunColor = params?.sunColor ?? getTemplateParam("item__sunColor")

    lightZenith = params?.lightZenith ?? getTemplateParam("item__lightZenith")
    lightAzimuth = params?.lightAzimuth ?? getTemplateParam("item__lightAzimuth")
    shading = params?.shading ?? getTemplateParam("item__shading")

    swapYZ = params?.swapYZ ?? getTemplateParam("item__swapYZ")
  }
}

function icon3dByGameTemplate(gametemplate, params = {}) {
  if (gametemplate == null)
    return null
  let template = DB.getTemplateByName(gametemplate)
  if (template == null)
    return null
  let itemInfo = getIconInfoByGameTemplate(template, params)
  itemInfo.__update(params?.genOverride ?? {})
  return mkIcon3d(itemInfo, params, itemInfo?.iconAttachments)
}

return icon3dByGameTemplate