from "%rGui/globals/ui_library.nut" import *

let { hp, maxHp, totalDotAmount, showHpUi
} = require("%rGui/hud/state/health_es.nut")
let { hpColor, bleedingColor, transparent } = require("%rGui/style/colors.nut")
let { heroStateWidth } = require("%rGui/hud/humanSquad/humanConst.nut")
let { armorState } = require("%rGui/hud/state/armor_es.nut")
let { ticketHudBlurPanel, hudBlurPanel } = require("%rGui/components/blurPanel.nut")


const bleedImgSize = shHud(2)

let hpBarHeight = hdpxi(6)
let xrayGap = hdpxi(7)
let xrayOpacity = 0.75

let xrayImageSize = [hdpxi(81), hdpxi(152)]

let bleedingImage = {
  size = const [bleedImgSize, bleedImgSize]
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/gameuiskin#icon_bleeding.svg:{bleedImgSize}:{bleedImgSize}:P")
  color = bleedingColor
  animations = [
      { prop = AnimProp.opacity, from=0.7, to=1,
    duration = 1.5, play = true, loop = true, easing = OutSine }
  ]
}

let mkXrayColor0 = @(hpRatioVal) hpRatioVal > 0 ? transparent : 0xFFD80F18
let mkXrayColor1 = @(hpRatioVal)
  hpRatioVal >= 1.0                       ? 0xFF48585C
  : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? 0xFF92731E
  : hpRatioVal > 0 && hpRatioVal < 0.5    ? 0xFF8D4D1D
                                          : 0xFF445364
let mkXrayColor2 = @(hpRatioVal)
  hpRatioVal >= 1.0                       ? 0xFF192327
  : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? 0xFF423312
  : hpRatioVal > 0 && hpRatioVal < 0.5    ? 0xFF371D0C
                                          : 0xFF090607

let mkXrayBodyArmorColor0 = @(hpRatioVal) hpRatioVal > 0 ? transparent : 0xFFD80F18
let mkXrayBodyArmorColor1 = @(hpRatioVal)
  hpRatioVal >= 1.0                       ? 0xFF657480
  : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? 0xFFB48E25
  : hpRatioVal > 0 && hpRatioVal < 0.5    ? 0xFF9E5621
                                          : 0xFF445364
let mkXrayBodyArmorColor2 = @(hpRatioVal)
  hpRatioVal >= 1.0                       ? 0xFF203138
  : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? 0xFF543F13
  : hpRatioVal > 0 && hpRatioVal < 0.5    ? 0xFF492209
                                          : 0xFF090607

let mkXrayArmorPlateColor0 = @(hpRatioVal) hpRatioVal > 0 ? transparent : 0xFFAF0C13
let mkXrayArmorPlateColor1 = @(hpRatioVal)
  hpRatioVal >= 1.0                       ? transparent
  : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? transparent
  : hpRatioVal > 0 && hpRatioVal < 0.5    ? transparent
                                          : 0xFF445364
let mkXrayArmorPlateColor2 = @(hpRatioVal)
  hpRatioVal >= 1.0                       ? 0xFF657480
  : hpRatioVal >= 0.5 && hpRatioVal < 1.0 ? 0xFFC69C29
  : hpRatioVal > 0 && hpRatioVal < 0.5    ? 0xFFBF6827
                                          : 0xFF1C1216

let getXrayDollImageByHP = @(hpRatioVal) [
  {
    size = xrayImageSize
    rendObj = ROBJ_IMAGE
    color = mkXrayColor0(hpRatioVal)
    opacity = xrayOpacity
    image = Picture($"ui/gameuiskin#inf_xray_body_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
  }
  {
    size = xrayImageSize
    rendObj = ROBJ_IMAGE
    color = mkXrayColor1(hpRatioVal)
    opacity = xrayOpacity
    image = Picture($"ui/gameuiskin#inf_xray_body_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
  }
  {
    size = xrayImageSize
    rendObj = ROBJ_IMAGE
    color = mkXrayColor2(hpRatioVal)
    opacity = xrayOpacity
    image = Picture($"ui/gameuiskin#inf_xray_body_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
  }
]


function getXrayDollHeavyHelmet(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_helmet_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_helmet_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_helmet_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollNeckArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_neck_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_neck_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_neck_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollHeavyBodyArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_front_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_front_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_front_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollBeltArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_bottom_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_bottom_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_bottom_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollLeftShoulderArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_left_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_left_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_left_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollRightShoulderArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_right_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_right_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayBodyArmorColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_right_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}



function getXrayDollFrontPlateArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_front_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_front_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_front_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollBackPlateArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_back_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_back_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_back_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollLeftPlateArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_left_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_left_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_left_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollRightPlateArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_right_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_right_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_right_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

function getXrayDollBeltPlateArmor(armorRatioVal) {
  return [
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor0(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_bottom_0.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor1(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_bottom_1.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
    {
      size = xrayImageSize
      rendObj = ROBJ_IMAGE
      color = mkXrayArmorPlateColor2(armorRatioVal)
      opacity = xrayOpacity
      image = Picture($"ui/gameuiskin#inf_xray_armor_plate_bottom_2.svg:{xrayImageSize[0]}:{xrayImageSize[1]}:P")
    }
  ]
}

let mkArmorPart = @(valWatch, xrayPartCtor) function() {
  if (valWatch.get() < 0)
    return { watch = valWatch }
  return {
    watch = valWatch
    children = xrayPartCtor(valWatch.get())
  }
}

let mkHeavyArmor = @() [
  mkArmorPart(
    Computed(@() armorState.get()?.groin.value ?? -1.0),
    getXrayDollBeltArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.vest.value ?? -1.0),
    getXrayDollHeavyBodyArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.helmet.value ?? -1.0),
    getXrayDollHeavyHelmet)
  mkArmorPart(
    Computed(@() armorState.get()?.shoulder_L.value ?? -1.0),
    getXrayDollRightShoulderArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.rear_plate.value ?? -1.0),
    getXrayDollBackPlateArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.side_plate_R.value ?? -1.0),
    getXrayDollLeftPlateArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.side_plate_L.value ?? -1.0),
    getXrayDollRightPlateArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.front_plate.value ?? -1.0),
    getXrayDollFrontPlateArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.groin_plate.value ?? -1.0),
    getXrayDollBeltPlateArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.shoulder_R.value ?? -1.0),
    getXrayDollLeftShoulderArmor)
  mkArmorPart(
    Computed(@() armorState.get()?.neck.value ?? -1.0),
    getXrayDollNeckArmor)
]

let haveAnyArmorPieceDamaged = Computed(@() armorState.get().filter(@(v) v.value < 1.0).len() > 0)

let needHideBlock = Computed(@() (hp.get() == maxHp.get() 
  || maxHp.get() <= 0
  || (hp.get() >= maxHp.get() && !showHpUi.get()))
  && (!haveAnyArmorPieceDamaged.get() || !showHpUi.get())
)

return function() {
  let hpRatio = Computed(@() maxHp.get() == 0
    ? 0
    : clamp(hp.get().tofloat() / maxHp.get().tofloat(), 0.0, 1.0))
  let dotRatio = Computed(@() maxHp.get() == 0
    ? 0
    : clamp(totalDotAmount.get().tofloat() / maxHp.get().tofloat(), 0.0, hpRatio.get()))

  return needHideBlock.get() ? { watch = needHideBlock } : {
    watch = needHideBlock
    size = [ heroStateWidth, SIZE_TO_CONTENT]
    flow = FLOW_VERTICAL
    gap = xrayGap
    children = [
      {
        size = FLEX_H
        valign = ALIGN_BOTTOM
        halign = ALIGN_RIGHT
        children = [
          {
            size = xrayImageSize
            margin = [0, bleedImgSize/2, 0,0]
            children = [
              @() {
                watch = hpRatio
                size = xrayImageSize
                children = getXrayDollImageByHP(hpRatio.get())
              }
              {
                size = xrayImageSize
                children = mkHeavyArmor()
              }
            ]
          }
          @() {
            watch = dotRatio
            size = bleedImgSize
            children = dotRatio.get() == 0 ? null : [
              hudBlurPanel
              bleedingImage
            ]
          }
        ]
      }
      {
        size = [ flex(), hpBarHeight ]
        children = [
          ticketHudBlurPanel
          @() {
            watch = hpRatio
            rendObj = ROBJ_BOX
            size = [ pw(hpRatio.get()*100), flex() ]
            fillColor = hpColor
            hplace = ALIGN_RIGHT
            children = @() dotRatio.get() == 0
              ? { watch = dotRatio }
              : {
                  watch = dotRatio
                  rendObj = ROBJ_BOX
                  size = [ pw(dotRatio.get()*100), flex() ]
                  fillColor = bleedingColor
                  hplace = ALIGN_LEFT
                }
          }
        ]
      }
    ]
  }
}