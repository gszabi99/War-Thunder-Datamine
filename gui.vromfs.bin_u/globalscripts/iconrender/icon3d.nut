let {getTexReplaceString, getTexSetString} = require("%globalScripts/iconRender/itemTexReplace.nut")
let { Color4 } = require("dagor.math")

























































let RENDER_PARAMS = @"ui/gameuiskin#render{
  itemName:t={itemName};animchar:t={animchar};autocrop:b=false;
  yaw:r={yaw};pitch:r={pitch};roll:r={roll};
  w:i={width};h:i={height};offset:p2={offset_x},{offset_y};scale:r={scale};
  calcBBox:b={calcBBox};
  outline:c={outlineColor};shading:t={shading};silhouette:c={silhouetteColor};
  silhouetteHasShadow:b={silhouetteHasShadow};silhouetteMinShadow:r={silhouetteMinShadow};
  distance:r={distance};
  {ssaa}
  attachType:t={attachType};
  brightness:r={brightness};
  sun:c={sunColor};
  zenith:r={zenith};
  azimuth:r={azimuth};
  {forceRealTimeRenderIcon}
  {attachments}
  {hideNodes}
  {objTexReplaceRules}
  {objTexSetRules}
  {paintColor}
  {shaderColors}
  contrast:r={contrast}
  sharpening:r={sharpening}
}.render"

let ATTACHMENT_PARAMS = @"a{idx}{
  animchar:t={animchar};
  slot:t={slot};
  scale:r={scale};
  outline:c={attOutlineColor};
  shading:t={attrShading};
  silhouette:c={attSilhouetteColor};
  {attAttachType}
  {hideNodesAtt}
  {shaderColorsString}
  {objTexReplaceRules}
}"

let DECORATOR_PARAMS = @"a{
  relativeTm:m={tmatrixString};
  animchar:t={animchar};
  parentNode:t={nodeName};
  shading:t=same;
  attachType:t=node;
  swapYZ:b={swapYZ};
}"

let getTMatrixString = @(m)
  "[{0}]".subst(" ".join(array(4).map(@(_, i) $"[{m[i].x}, {m[i].y}, {m[i].z}]")))

function getShaderColorsString(item) {
  let { shaderColors = null } = item
  if (shaderColors == null || type(shaderColors) != "table")
    return ""
  let list = []
  list.append("shaderColors{")
  foreach (name, value in shaderColors){
    if (type(value) == "array" && value.len() > 3)
      list.append($"{name}:p4={value[0]},{value[1]},{value[2]},{value[3]};")
  }
  list.append("}")
  return "".join(list)
}

let getColor4String = @(col) $"{col.r},{col.g},{col.b},{col.a}"
let getPoint4String = @(col) $"{col.x},{col.y},{col.z},{col.w}"


let transparentTxt = getColor4String(Color4(0,0,0,0))
let whiteTxt = getColor4String(Color4(255, 255, 255, 255))

function iconWidget(item, params = {}) {
  let { iconName = "" } = item
  if (iconName == "")
    return ""

  let {
    width = 64
    height = 64
    forceRealTimeRenderIcon = null
  } = params

  let shading = item?.shading ?? params?.shading ?? "full"

  let {
    itemTemplate = "",
    paintColor = null,
    hideNodes = []
    iconAttachments = []
    iconAttachmentShading = "same"
  } = item

  let outlineColor = item?.outlineColor ? getColor4String(item.outlineColor) : transparentTxt
  let outlineColorInactive = item?.outlineInactiveColor
    ? getColor4String(item.outlineInactiveColor) : transparentTxt
  let silhouetteColor = item?.silhouetteColor ? getColor4String(item.silhouetteColor)
    : params?.silhouetteColor ? getColor4String(params.silhouetteColor)
    : whiteTxt
  let silhouetteColorInactive = item?.silhouetteInactiveColor
    ? getColor4String(item.silhouetteInactiveColor)
    : params?.silhouetteInactiveColor ? getColor4String(params.silhouetteInactiveColor)
    : whiteTxt

  let imageHeight = height.tointeger()
  let imageWidth = width.tointeger()
  let zenith = item?.lightZenith ?? 65
  let azimuth = item?.lightAzimuth ?? -40
  let objTexReplace = getTexReplaceString(item)
  let objTexSet = getTexSetString(item)
  let shaderColors = getShaderColorsString(item)

  let sunColor = item?.sunColor ? getColor4String(item.sunColor) : whiteTxt
  let itemScale = item?.iconScale ?? 1

  local haveActiveAttachments = false
  let attachments = []
  foreach (i, attachment in iconAttachments ?? []) {
    let active = attachment?.active ?? false
    if (shading == "full" && !active) {
      
      continue
    }
    haveActiveAttachments = haveActiveAttachments || active

    let { animchar = null, slot = -1, scale = itemScale, attachType = null } = attachment

    let attAttachType = attachType != null ? $"attachType:t={attachType};" : ""

    local hideNodesAtt = (attachment?.hideNodes ?? []).map(@(node) $"node:t={node};")
    hideNodesAtt = hideNodesAtt.len() > 0 ? "hideNodes{{0}};".subst("".join(hideNodesAtt)) : ""

    let attOutlineColor = active ? outlineColor : outlineColorInactive
    let attSilhouetteColor = active ? silhouetteColor : silhouetteColorInactive
    let attrShading = attachment?.shading ?? iconAttachmentShading
    let attrObjTexReplaceRules = getTexReplaceString(attachment)

    attachments.append(ATTACHMENT_PARAMS.subst({
      idx = i
      animchar
      slot
      scale
      attAttachType
      hideNodesAtt
      attOutlineColor
      attrShading
      attSilhouetteColor
      objTexReplaceRules = "objTexReplaceRules{{0}}".subst(attrObjTexReplaceRules)
      shaderColorsString = getShaderColorsString(attachment)
    }))
  }

  foreach (decorator in item?.decorators ?? []) {
    attachments.append(DECORATOR_PARAMS.subst({
      animchar = decorator?.animchar
      nodeName = decorator?.nodeName
      tmatrixString = getTMatrixString(decorator?.relativeTm)
      swapYZ = decorator?.swapYZ ?? true
    }))
  }

  let hideNodesTex = hideNodes.map(@(node) $"node:t={node};")
  let paintColorParam = paintColor ? $"paintColor:p4={getPoint4String(paintColor)}" : ""
  let needEnableRTRender = forceRealTimeRenderIcon == "" || itemTemplate == forceRealTimeRenderIcon
  
  let ssaa = item?.ssaaX && item?.ssaaY ? $"ssaaX:i={item.ssaaX};ssaaY:i={item.ssaaY};" : ""

  return RENDER_PARAMS.subst({
    itemName = itemTemplate
    animchar = iconName
    yaw = item?.iconYaw ?? 0
    pitch = item?.iconPitch ?? 0
    roll = item?.iconRoll ?? 0
    width = imageWidth
    height = imageHeight
    calcBBox = item?.calcBBox ?? true
    offset_x = item?.iconOffsX ?? 0
    offset_y = item?.iconOffsY ?? 0
    scale = itemScale
    distance = item?.distance ?? 4.0
    ssaa
    outlineColor = haveActiveAttachments ? outlineColorInactive : outlineColor
    silhouetteColor = haveActiveAttachments ? silhouetteColorInactive : silhouetteColor
    shading
    zenith
    azimuth
    sunColor
    brightness = item?.brightness ?? 4.0
    objTexReplaceRules = "objTexReplaceRules{{0}}".subst(objTexReplace)
    objTexSetRules = "objTexSetRules{{0}}".subst(objTexSet)
    attachments = attachments.len() > 0 ? "attachments{{0}}".subst("".join(attachments)) : ""
    hideNodes = hideNodesTex.len() > 0 ? "hideNodes{{0}}".subst("".join(hideNodesTex)) : ""
    paintColor = paintColorParam
    shaderColors
    silhouetteHasShadow = item?.silhouetteHasShadow ?? false
    silhouetteMinShadow = item?.silhouetteMinShadow ?? 1.0
    swapYZ = item?.swapYZ ?? true
    attachType = item?.attachType ?? "slot"
    forceRealTimeRenderIcon = needEnableRTRender ? "forceRenderEveryFrame:b=yes;" : ""
    contrast = item?.contrast ?? 1.0
    sharpening = item?.sharpening ?? 0.0
  })
}

return iconWidget