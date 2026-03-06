from "%scripts/dagui_library.nut" import *

enum xrayOrder {
  HP,
  GROIN,
  VEST,
  HELMET,
  SHOULDER_L,
  READ_PLATE,
  SIDE_PLATE_R,
  SIDE_PLATE_L,
  FRONT_PLATE,
  GROIN_PLATE,
  SHOULDER_R,
  NECK

  LENGTH
}

let mkXrayColor = {
  [0] = @(hpRatioVal) hpRatioVal > 0 ? "#00000000" : "#FFD80F18",

  [1] = @(hpRatioVal) hpRatioVal >= 1.0   ? "#FF48585C"
    : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? "#FF92731E"
    : hpRatioVal > 0 && hpRatioVal < 0.5    ? "#FF8D4D1D"
    : "#FF445364",

  [2] = @(hpRatioVal) hpRatioVal >= 1.0   ? "#FF192327"
    : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? "#FF423312"
    : hpRatioVal > 0 && hpRatioVal < 0.5    ? "#FF371D0C"
    : "#FF090607"
}

let mkXrayBodyArmorColor = {
  [0] = @(hpRatioVal) hpRatioVal > 0 ? "#00000000" : "#FFD80F18",

  [1] = @(hpRatioVal) hpRatioVal >= 1.0   ? "#FF657480"
    : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? "#FFB48E25"
    : hpRatioVal > 0 && hpRatioVal < 0.5    ? "#FF9E5621"
    : "#FF445364",

  [2] = @(hpRatioVal) hpRatioVal >= 1.0   ? "#FF203138"
    : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? "#FF543F13"
    : hpRatioVal > 0 && hpRatioVal < 0.5    ? "#FF492209"
    : "#FF090607"
}

let mkXrayArmorPlateColor = {
  [0] = @(hpRatioVal) hpRatioVal > 0 ? "#00000000" : "#FFAF0C13",

  [1] = @(hpRatioVal) hpRatioVal >= 1.0   ? "#00000000"
    : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? "#00000000"
    : hpRatioVal > 0 && hpRatioVal < 0.5    ? "#00000000"
    : "#FF445364",

  [2] = @(hpRatioVal) hpRatioVal >= 1.0   ? "#FF657480"
    : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? "#FFC69C29"
    : hpRatioVal > 0 && hpRatioVal < 0.5    ? "#FFBF6827"
    : "#FF1C1216"
}

let xrayDataMapping = {
  [xrayOrder.HP] = "hp",
  [xrayOrder.GROIN] = "groin",
  [xrayOrder.VEST] = "vest",
  [xrayOrder.HELMET] = "helmet",
  [xrayOrder.SHOULDER_L] = "shoulder_L",
  [xrayOrder.READ_PLATE] = "rear_plate",
  [xrayOrder.SIDE_PLATE_R] = "side_plate_R",
  [xrayOrder.SIDE_PLATE_L] = "side_plate_L",
  [xrayOrder.FRONT_PLATE] = "front_plate",
  [xrayOrder.GROIN_PLATE] = "groin_plate",
  [xrayOrder.SHOULDER_R] = "shoulder_R",
  [xrayOrder.NECK] = "neck"
}

let xrayBodyData = {
  hp = {
    image = "ui/gameuiskin#inf_xray_body_{0}.svg:P"
    color = mkXrayColor
    order = xrayOrder.HP
  }
  groin = {
    image = "ui/gameuiskin#inf_xray_armor_bottom_{0}.svg:P"
    color = mkXrayBodyArmorColor
    order = xrayOrder.GROIN
  }
  vest = {
    image = "ui/gameuiskin#inf_xray_armor_front_{0}.svg:P"
    color = mkXrayBodyArmorColor
    order = xrayOrder.VEST
  }
  helmet = {
    image = "ui/gameuiskin#inf_xray_helmet_{0}.svg:P"
    color = mkXrayBodyArmorColor
    order = xrayOrder.HELMET
  }
  shoulder_L = {
    image = "ui/gameuiskin#inf_xray_armor_right_{0}.svg:P"
    color = mkXrayBodyArmorColor
    order = xrayOrder.SHOULDER_L
  }
  rear_plate = {
    image = "ui/gameuiskin#inf_xray_armor_plate_back_{0}.svg:P"
    color = mkXrayArmorPlateColor
    order = xrayOrder.READ_PLATE
  }
  side_plate_R = {
    image = "ui/gameuiskin#inf_xray_armor_plate_left_{0}.svg:P"
    color = mkXrayArmorPlateColor
    order = xrayOrder.SIDE_PLATE_R
  }
  side_plate_L = {
    image = "ui/gameuiskin#inf_xray_armor_plate_right_{0}.svg:P"
    color = mkXrayArmorPlateColor
    order = xrayOrder.SIDE_PLATE_L
  }
  front_plate = {
    image = "ui/gameuiskin#inf_xray_armor_plate_front_{0}.svg:P"
    color = mkXrayArmorPlateColor
    order = xrayOrder.FRONT_PLATE
  }
  groin_plate = {
    image = "ui/gameuiskin#inf_xray_armor_plate_bottom_{0}.svg:P"
    color = mkXrayArmorPlateColor
    order = xrayOrder.GROIN_PLATE
  }
  shoulder_R = {
    image = "ui/gameuiskin#inf_xray_armor_left_{0}.svg:P"
    color = mkXrayBodyArmorColor
    order = xrayOrder.SHOULDER_R
  }
  neck = {
    image = "ui/gameuiskin#inf_xray_neck_{0}.svg:P"
    color = mkXrayBodyArmorColor
    order = xrayOrder.NECK
  }
}

return function(hpScale, hitsInfo) {
  let res = []
  for (local j = 0; j < 3; j++)
    res.append({
      xrayImage = xrayBodyData.hp.image.subst(j)
      xrayColor = xrayBodyData.hp.color[j](hpScale)
    })

  for (local i = xrayOrder.GROIN; i < xrayOrder.LENGTH; i++) {
    let xrayInfoId = xrayDataMapping[i]
    if (hitsInfo?[xrayInfoId] == null)
      continue

    let xrayInfo = xrayBodyData[xrayInfoId]
    for (local j = 0; j < 3; j++)
      res.append({
        xrayImage = xrayInfo.image.subst(j)
        xrayColor = xrayInfo.color[j](hitsInfo[xrayInfoId])
      })
  }
  return res
}