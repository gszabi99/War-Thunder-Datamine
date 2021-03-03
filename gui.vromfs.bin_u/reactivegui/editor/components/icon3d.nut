local iconWidgetDef = {
  width = hdpx(64)
  height = hdpx(64)
  outline = [0,0,0,0]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  shading = "full" //shading = silhouette|full
  silhouette = [192,192,192,200]
}

local cachedPictures = {}

local function getPicture(source) {
  local pic = cachedPictures?[source]
  if (pic)
    return pic
  pic = ::Picture(source)
  cachedPictures[source] <- pic
  return pic
}

local function iconWidget(item, params=iconWidgetDef) {
  local children = params?.children
  local iconName = item?.iconName ?? ""
  if (iconName == "") {
    return {
      children=children
    }
  }

  local itemName = item?.itemName ?? ""
  local outlineColor = ",".join(params?.outline ?? iconWidgetDef.outline)
  local outlineColorInactive = ",".join(params?.outlineInactive ?? iconWidgetDef.outline)
  local width = params?.width ?? iconWidgetDef.width
  local height = params?.height ?? iconWidgetDef.height
  local vplace = params?.vplace ?? iconWidgetDef.vplace
  local hplace = params?.hplace ?? iconWidgetDef.hplace
  local shading = params?.shading ?? iconWidgetDef.shading
  local silhouetteColor = ",".join(params?.silhouette ?? iconWidgetDef.silhouette)
  local silhouetteColorInactive = ",".join(params?.silhouetteInactive ?? iconWidgetDef.silhouette)
  local imageHeight = height.tointeger()
  local imageWidth = width.tointeger()
  local zenith = "lightZenith" in item ? $"zenith:r={item.lightZenith};" : ""
  local azimuth = "lightAzimuth" in item ? $"azimuth:r={item.lightAzimuth};" : ""
  local objTexReplace = item?.objTexReplace ?? ""
  local attachments = [];
  local haveActiveAttachments = false
  foreach (i, attachment in item?.iconAttachments ?? []) {
    local active = attachment?.active ?? false
    if ((shading == "full") && !active) {
      // Full shading and attachment is inactive, just hide it.
      continue
    }
    haveActiveAttachments = haveActiveAttachments || active
    local attOutlineColor = active ? outlineColor : outlineColorInactive
    local attSilhouetteColor = active ? silhouetteColor : silhouetteColorInactive
    attachments.append($"a{i}")
    attachments.append("{")
    attachments.append($"animchar:t={attachment?.animchar};slot:t={attachment?.slot};scale:r={attachment?.scale ?? 1.0};")
    attachments.append($"outline:c={attOutlineColor};shading:t={shading};silhouette:c={attSilhouetteColor};")
    attachments.append("}")
  }

  local hideNodes = (item?.hideNodes ?? []).map(@(node) $"node:t={node};")

  local tbl = {
    itemName = itemName
    animchar = iconName
    yaw = item?.iconYaw ?? 0
    pitch = item?.iconPitch ?? 0
    roll = item?.iconRoll ?? 0
    width = imageWidth
    height = imageHeight
    offset_x = item?.iconOffsX ?? 0
    offset_y = item?.iconOffsY ?? 0
    scale = item?.iconScale ?? 1
    outlineColor = haveActiveAttachments ? outlineColorInactive : outlineColor
    silhouetteColor = haveActiveAttachments ? silhouetteColorInactive : silhouetteColor
    shading = shading
    zenith = zenith
    azimuth = azimuth
    objTexReplace = objTexReplace
    attachments = attachments.len() > 0 ? @"attachments{{0}}".subst("".join(attachments)) : ""
    hideNodes = hideNodes.len() > 0 ? @"hideNodes{{0}}".subst("".join(hideNodes)) : ""
  }

  local imageSource = @"ui/skin#render{
    itemName:t={itemName};
    animchar:t={animchar};
    autocrop:b=false;{attachments}{hideNodes}
    yaw:r={yaw};pitch:r={pitch};roll:r={roll};
    w:i={width};h:i={height};offset:p2={offset_x},{offset_y};scale:r={scale};
    outline:c={outlineColor};shading:t={shading};silhouette:c={silhouetteColor};
    {zenith}{azimuth}{objTexReplace}}.render".subst(tbl)

  local image = getPicture(imageSource)

  return {
    rendObj = ROBJ_IMAGE
    image = image
    key = image
    vplace = vplace
    hplace = hplace
    children = children
    size = [width,height]
    keepAspect = true
  }.__update(params)
}

return iconWidget
