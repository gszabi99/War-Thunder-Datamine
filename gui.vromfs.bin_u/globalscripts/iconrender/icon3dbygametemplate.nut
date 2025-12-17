let mkIcon3d = require("%globalScripts/iconRender/icon3d.nut")
let { getLocalLanguage } = require("language")
let { getTemplate, getTemplateCompValue } = require("%globalScripts/templates.nut")
let sharedWatched = require("%globalScripts/sharedWatched.nut")
let forceRealTimeRenderIcon = require("%globalScripts/iconRender/forceRealTimeRenderIcon.nut")

let cachedRendered3dIcons = sharedWatched("cachedRendered3dIcons", @() {})

forceRealTimeRenderIcon.subscribe(@(_) cachedRendered3dIcons.set({}))

function applyHarmonizationImpl(gametemplate, objTexReplace, objTexSet) {
  let objTexHarmonize = getTemplateCompValue(gametemplate, "animchar__objTexHarmonize")
  if (objTexHarmonize == null)
    return

  objTexReplace.append(objTexHarmonize?["animchar__objTexReplace"] ?? {})
  objTexSet.append(objTexHarmonize?["animchar__objTexSet"] ?? {})
}

let applyHarmonization = getLocalLanguage() == "HChinese" ? applyHarmonizationImpl : @(...) null

function mkDecorAnimchar(decor) {
  if (decor?.template == null)
    return decor

  let animchar = getTemplateCompValue(decor.template, "animchar__res")
  if (animchar == null)
    return decor

  return decor.__update({ animchar })
}

function getIconInfoByGameTemplate(gametemplate, params = {}) {
  let decorators = getTemplateCompValue(
    gametemplate, "attach_decorators__templates", {}).map(mkDecorAnimchar)

  let objTexReplace = [getTemplateCompValue(gametemplate, "animchar__objTexReplace", {})]
  let objTexSet = [getTemplateCompValue(gametemplate, "animchar__objTexSet", {})]

  applyHarmonization(gametemplate, objTexReplace, objTexSet)
  let renderIconSettings = params?.renderSettingsPlace
    ? getTemplateCompValue(gametemplate, params.renderSettingsPlace, {})
    : {}

  let renderIconSettingsOverride = params?.renderSettingsPlace
    ? getTemplateCompValue(gametemplate, $"{params.renderSettingsPlace}_override", {})
    : {}

  let getTemplateParam = @(paramName) getTemplateCompValue(gametemplate, paramName)
    ?? renderIconSettingsOverride?[paramName]
    ?? renderIconSettings?[paramName]

  return {
    iconName = getTemplateCompValue(gametemplate, "animchar__res")
    itemTemplate = getTemplateCompValue(gametemplate, "item__weapTemplate", "")
    objTexReplace
    objTexSet
    decorators
    hideNodes = getTemplateCompValue(gametemplate, "disableDMParts", [])
    blendFactor = getTemplateParam("item__blendFactor")

    iconPitch = params?.itemPitch ?? getTemplateParam("item__iconPitch")
    iconYaw = params?.itemYaw ?? getTemplateParam("item__iconYaw")
    iconRoll = params?.itemRoll ?? getTemplateParam("item__iconRoll")
    iconOffsX = params?.itemOfsX ?? getTemplateParam("item__iconOffset")?.x
    iconOffsY = params?.itemOfsY ?? getTemplateParam("item__iconOffset")?.y
    iconScale = params?.itemScale ?? getTemplateParam("item__iconScale")
    distance = params?.distance ?? getTemplateParam("item__distance")

    ssaaX = params?.ssaaX ?? getTemplateParam("item__ssaaX")
    ssaaY = params?.ssaaY ?? getTemplateParam("item__ssaaY")

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

    contrast = params?.contrast ?? getTemplateParam("item__contrast")

    iconAttachments = params?.iconAttachments ?? getTemplateParam("iconAttachments")
    sharpening = params?.sharpening ?? getTemplateParam("item__sharpening")
  }
}

function getPicture(source, gametemplate, params) {
  let cachedPic = cachedRendered3dIcons.get()?[source]
  if (cachedPic)
    return cachedPic

  let template = getTemplate(gametemplate)
  if (template == null)
    return null

  let itemInfo = getIconInfoByGameTemplate(gametemplate, params)
  if (params?.genOverride != null)
    itemInfo.__update(params.genOverride)
  let pic = mkIcon3d(itemInfo, params)
  cachedRendered3dIcons.mutate(@(v) v[source] <- pic)
  return pic
}

function icon3dByGameTemplate(gametemplate, params = {}) {
  if (gametemplate == null)
    return null

  let placeKey = params?.renderSettingsPlace ? $"_{params?.renderSettingsPlace}" : ""
  let cacheKey = $"{gametemplate}{placeKey}"
  return getPicture(cacheKey, gametemplate, params)
}

return icon3dByGameTemplate