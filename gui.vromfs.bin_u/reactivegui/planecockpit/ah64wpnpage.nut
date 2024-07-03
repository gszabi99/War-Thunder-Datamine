from "%rGui/globals/ui_library.nut" import *

let { CannonCount, FlaresCount, ChaffsCount, CannonMode, RocketsCount, RocketsSalvo,
 IsLaserDesignatorEnabled } = require("%rGui/airState.nut")
let { WeaponSlots, WeaponSlotsTrigger, WeaponSlotsCnt, SelectedTrigger,
 SelectedWeapSlot, WeaponSlotsTotalCnt, LaunchImpossible } = require("%rGui/planeState/planeWeaponState.nut")
let { weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")

let baseColor = Color(0, 255, 0, 255)
let baseFontSize = 16
let baseLineWidth = 1

let arrow = {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth
  color = baseColor
  commands = [
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 80, 0, 100, 50],
    [VECTOR_LINE, 80, 100, 100, 50]
  ]
}

let silhouette = {
  size = [pw(64), ph(50)]
  pos = [pw(18), ph(25)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_LINE, 37.2, 100, 62.8, 100],
    [VECTOR_LINE, 37.2, 66.3, 37.2, 100],
    [VECTOR_LINE, 0, 63.2, 37.2, 66.3],
    [VECTOR_LINE, 0, 44.2, 0, 63.2],
    [VECTOR_LINE, 0, 44.2, 37.2, 42],
    [VECTOR_LINE, 37.2, 42, 37.2, 11],
    [VECTOR_SECTOR, 44.2, 11, 7, 6.2, 180, 270],
    [VECTOR_SECTOR, 49, 4.8, 4.8, 4.8, 180, 270],
    [VECTOR_LINE, 49, 0, 51, 0],
    [VECTOR_SECTOR, 51, 4.8, 4.8, 4.8, -90, 0],
    [VECTOR_SECTOR, 55.8, 11, 7, 6.2, -90, 0],
    [VECTOR_LINE, 62.8, 42, 62.8, 11],
    [VECTOR_LINE, 100, 44.2, 62.8, 42],
    [VECTOR_LINE, 100, 44.2, 100, 63.2],
    [VECTOR_LINE, 100, 63.2, 62.8, 66.3],
    [VECTOR_LINE, 62.8, 66.3, 62.8, 100]
  ]
}

let buttons = @(){
  watch = SelectedTrigger
  size = flex()
  children = [
    {
      pos = [pw(14), ph(1)]
      size = [pw(8), ph(4.2)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
            size = SIZE_TO_CONTENT
            pos = [pw(5), ph(1)]
            rendObj = ROBJ_TEXT
            color = baseColor
            font = Fonts.ah64
            fontSize = baseFontSize
            text = "CHAN"
        }
      ]
    },
    {
      pos = [pw(29), ph(1)]
      size = [pw(5), ph(4.2)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
            size = SIZE_TO_CONTENT
            pos = [pw(5), ph(1)]
            rendObj = ROBJ_TEXT
            color = baseColor
            font = Fonts.ah64
            fontSize = baseFontSize
            text = "ASE"
        }
      ]
    },
    {
      pos = [pw(53), ph(1)]
      size = [pw(8), ph(4.2)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
            size = SIZE_TO_CONTENT
            pos = [pw(5), ph(1)]
            rendObj = ROBJ_TEXT
            color = baseColor
            font = Fonts.ah64
            fontSize = baseFontSize
            text = "CODE"
        }
      ]
    },
    {
      pos = [pw(64), ph(1)]
      size = [pw(10), ph(4.2)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
            size = SIZE_TO_CONTENT
            pos = [pw(5), ph(1)]
            rendObj = ROBJ_TEXT
            color = baseColor
            font = Fonts.ah64
            fontSize = baseFontSize
            text = "COORD"
        }
      ]
    },
    {
      pos = [pw(80), ph(1)]
      size = [pw(7), ph(4.2)]
      flow = FLOW_VERTICAL
      children = [
        arrow
        {
            size = SIZE_TO_CONTENT
            pos = [pw(5), ph(1)]
            rendObj = ROBJ_TEXT
            color = baseColor
            font = Fonts.ah64
            fontSize = baseFontSize
            text = "UTIL"
        }
      ]
    },
    {
      rendObj = ROBJ_FRAME
      pos = [pw(14), ph(94)]
      size = [pw(8), ph(5)]
      color = baseColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.ah64
        fontSize = baseFontSize
        text = "WPN"
      }
    },
    {
      size = SIZE_TO_CONTENT
      pos = [pw(28), ph(94.5)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "GUN"
    },
    {
      size = SIZE_TO_CONTENT
      pos = [pw(40), ph(94.5)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "MSL"
      children = SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
        rendObj = ROBJ_FRAME
        size = [pw(120), ph(120)]
        pos = [pw(-10), ph(-10)]
        color = baseColor
      } : null
    },
    @(){
      watch = SelectedTrigger
      size = SIZE_TO_CONTENT
      pos = [pw(66), ph(94.5)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "RKT"
      children = SelectedTrigger.get() == weaponTriggerName.ROCKETS_TRIGGER ? {
        rendObj = ROBJ_FRAME
        size = [pw(120), ph(120)]
        pos = [pw(-10), ph(-10)]
        color = baseColor
      } : null
    },
    {
      pos = [pw(1), ph(65)]
      size = [pw(16), ph(4.2)]
      flow = FLOW_VERTICAL
      children = SelectedTrigger.get() < 0 ? [
        arrow
        {
            size = SIZE_TO_CONTENT
            pos = [pw(5), ph(1)]
            rendObj = ROBJ_TEXT
            color = baseColor
            font = Fonts.ah64
            fontSize = baseFontSize
            text = "BORESIGHT"
        }
      ] : null
    },
    (SelectedTrigger.get() < 0 ? {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(77)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "GRAYSCALE"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(16)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "PRI"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(20)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "B  PRF"
      children = {
        rendObj = ROBJ_FRAME
        color = baseColor
        pos = [-3, 0]
        size = [baseFontSize, baseFontSize * 1.1]
      }
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(29)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "ALT"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(33)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "C  PRF"
      children = {
        rendObj = ROBJ_FRAME
        color = baseColor
        pos = [-3, 0]
        size = [baseFontSize, baseFontSize * 1.1]
      }
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(40)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "SAL  SEL"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(1), ph(44)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "AUTO"
      children = {
        rendObj = ROBJ_FRAME
        color = baseColor
        size = [flex(), baseFontSize * 1.1]
      }
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [0, ph(66)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "DEICE"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [0, ph(78)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "MSL CCM"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(91), ph(16)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "TYPE"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      rendObj = ROBJ_FRAME
      pos = [pw(92), ph(20)]
      size = [pw(7), ph(4)]
      color = baseColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.ah64
        fontSize = baseFontSize
        text = "SAL"
      }
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(90), ph(30)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "MODE"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      rendObj = ROBJ_FRAME
      pos = [pw(89), ph(34)]
      size = [pw(10), ph(4)]
      color = baseColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.ah64
        fontSize = baseFontSize
        text = "NORM"
      }
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(92), ph(41)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "TRAJ"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ? {
      rendObj = ROBJ_FRAME
      pos = [pw(93), ph(45)]
      size = [pw(6), ph(4)]
      color = baseColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.ah64
        fontSize = baseFontSize
        text = "HI"
      }
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.ROCKETS_TRIGGER ? {
      size = SIZE_TO_CONTENT
      pos = [pw(92), ph(15)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "QTY"
    } : null),
    (SelectedTrigger.get() == weaponTriggerName.ROCKETS_TRIGGER ? @(){
      watch = RocketsSalvo
      size = [pw(5), ph(4)]
      pos = [pw(92), ph(20)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      halign = ALIGN_RIGHT
      text = RocketsSalvo.get() < 0 ? "ALL" : (RocketsSalvo.get() < 1 ? "1" : RocketsSalvo.get().tostring())
      children = {
        rendObj = ROBJ_FRAME
        size = [RocketsSalvo.get() < 0 ? pw(125) : (RocketsSalvo.get() > 9 ? pw(90) : pw(60)), ph(100)]
        pos = [pw(10), 0]
        color = baseColor
      }
    } : null),
    {
      size = SIZE_TO_CONTENT
      pos = [pw(89), ph(54)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "TRAIN"
    },
    {
      size = SIZE_TO_CONTENT
      pos = [pw(90), ph(63)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "LRFD"
    },
    {
      rendObj = ROBJ_FRAME
      pos = [pw(88), ph(67)]
      size = [pw(10), ph(4)]
      color = baseColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.ah64
        fontSize = baseFontSize
        text = "FIRST"
      }
    },
    {
      size = SIZE_TO_CONTENT
      pos = [pw(92), ph(75)]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize
      text = "ACQ"
    },
    {
      rendObj = ROBJ_FRAME
      pos = [pw(89), ph(79)]
      size = [pw(9), ph(4)]
      color = baseColor
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = baseColor
        font = Fonts.ah64
        fontSize = baseFontSize
        text = "TADS"
      }
    },
    @(){
      watch = SelectedTrigger
      size = [pw(10), ph(60)]
      pos = [-1, ph(15)]
      children = SelectedTrigger.get() == weaponTriggerName.ROCKETS_TRIGGER ? [
        {
          rendObj = ROBJ_FRAME
          color = baseColor
          size = flex()
        }
        {
          rendObj = ROBJ_SOLID
          size = [pw(20), ph(40)]
          color = Color(0, 0, 0, 255)
          pos = [pw(90), ph(30)]
        }
        {
          rendObj = ROBJ_TEXTAREA
          size = SIZE_TO_CONTENT
          pos = [pw(92), ph(31)]
          color = baseColor
          fillColor = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize * 0.8
          text = "I\nN\nV\nE\nN\nT\nO\nR\nY"
          behavior = Behaviors.TextArea
        }
        {
          rendObj = ROBJ_FRAME
          size = [pw(70), ph(12)]
          pos = [pw(10), ph(5)]
          flow = FLOW_VERTICAL
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          color = baseColor
          children = [
            {
              rendObj = ROBJ_TEXT
              size = SIZE_TO_CONTENT
              color = baseColor
              font = Fonts.ah64
              fontSize = baseFontSize
              text = "6PD"
            }
            @(){
              watch = RocketsCount
              rendObj = ROBJ_TEXT
              size = SIZE_TO_CONTENT
              color = baseColor
              font = Fonts.ah64
              fontSize = baseFontSize
              text = RocketsCount.get().tostring()
            }
          ]
        }
      ] : null
    }
  ]
}

let MachineGunsCnt = CannonCount[0]
let gun = {
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(12), ph(20)]
  pos = [pw(44), ph(26)]
  color = baseColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_RECTANGLE, 0, 80, 100, 20],
    [VECTOR_LINE, 32, 80, 32, 55],
    [VECTOR_LINE, 68, 80, 68, 55],
    [VECTOR_SECTOR, 37, 55, 5, 5, 180, 270],
    [VECTOR_SECTOR, 63, 55, 5, 5, -90, 0],
    [VECTOR_LINE, 63, 50, 37, 50],
    [VECTOR_LINE, 45, 50, 45, 15],
    [VECTOR_LINE, 55, 50, 55, 15],
    [VECTOR_RECTANGLE, 42, 3, 16, 12],
  ]
  children = @(){
    watch = MachineGunsCnt
    rendObj = ROBJ_TEXT
    size = [pw(100), ph(20)]
    pos = [0, ph(80)]
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    color = baseColor
    font = Fonts.ah64
    fontSize = baseFontSize * 1.1
    text = MachineGunsCnt.get().tostring()
  }
}

let gunArm = @(){
  watch = [SelectedTrigger, LaunchImpossible]
  rendObj = ROBJ_BOX
  size = [pw(14), ph(10)]
  pos = [pw(43), ph(11)]
  fillColor = SelectedTrigger.get() != -1 && LaunchImpossible.get() ? Color(0, 0, 0, 255) : Color(255, 255, 0, 255)
  borderColor = SelectedTrigger.get() != -1 && LaunchImpossible.get() ? baseColor : Color(255, 255, 0, 255)
  borderWidth = baseLineWidth
  borderRadius = hdpx(5)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      color = SelectedTrigger.get() != -1 && LaunchImpossible.get() ? baseColor : Color(0, 0, 0, 255)
      font = Fonts.ah64
      fontSize = baseFontSize * (SelectedTrigger.get() != -1 && LaunchImpossible.get() ? 1.2 : 1.4)
      text = SelectedTrigger.get() != -1 && LaunchImpossible.get() ? "SAFE" : "ARM"
      fontFx = FFT_BLUR
      fontFxColor = Color(0, 0, 0, 255)
      fontFxFactor = 1
    }
    SelectedTrigger.get() != -1 ? {
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = LaunchImpossible.get() ? baseColor : Color(0, 0, 0, 255)
      fillColor = LaunchImpossible.get() ? baseColor : Color(0, 0, 0, 255)
      lineWidth = baseLineWidth
      commands = [
        [VECTOR_RECTANGLE, 5, 25, 12, 15],
        [VECTOR_RECTANGLE, 5, 55, 12, 15],
        [VECTOR_RECTANGLE, 20, 5, 12, 15],
        [VECTOR_RECTANGLE, 45, 5, 12, 15],
        [VECTOR_RECTANGLE, 70, 5, 12, 15],
        [VECTOR_RECTANGLE, 83, 25, 12, 15],
        [VECTOR_RECTANGLE, 83, 55, 12, 15],
        [VECTOR_RECTANGLE, 20, 80, 12, 15],
        [VECTOR_RECTANGLE, 45, 80, 12, 15],
        [VECTOR_RECTANGLE, 70, 80, 12, 15],
      ]
    } : null
  ]
}

let chaff = {
  rendObj = ROBJ_BOX
  size = [pw(14), ph(13)]
  pos = [pw(43), ph(61)]
  fillColor = Color(0, 0, 0, 0)
  borderColor = baseColor
  borderWidth = baseLineWidth
  borderRadius = hdpx(10)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize * 1.1
      text = "CHAFF"
    }
    @(){
      watch = [ChaffsCount, FlaresCount]
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize * 1.1
      text = (ChaffsCount.get() + FlaresCount.get()).tostring()
    }
    {
      rendObj = ROBJ_SOLID
      color = Color(255, 255, 0)
      size = [pw(50), ph(25)]
      halign = ALIGN_CENTER
      children = {
        rendObj = ROBJ_TEXT
        color = Color(0, 0, 0, 255)
        font = Fonts.ah64
        fontSize = baseFontSize * 1.1
        fontFx = FFT_BLUR
        fontFxColor = Color(0, 0, 0, 255)
        fontFxFactor = 1
        text = "ARM"
      }
    }
  ]
}

let gunsModeLocal = CannonMode[0]
let gunModeWatched = Computed(@() (gunsModeLocal.get() & (1 << WeaponMode.CCRP_MODE)) ? "TADS" : "FXD")
let acqBox = {
  rendObj = ROBJ_BOX
  size = [pw(14), ph(9)]
  pos = [pw(60), ph(12)]
  fillColor = Color(0, 0, 0, 0)
  borderColor = baseColor
  borderWidth = baseLineWidth
  borderRadius = hdpx(5)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize * 1.1
      text = "ACQ"
    }
    @(){
      watch = gunModeWatched
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize * 1.1
      text = gunModeWatched.get()
    }
  ]
}

let sightBox = {
  rendObj = ROBJ_BOX
  size = [pw(14), ph(9)]
  pos = [pw(26), ph(12)]
  fillColor = Color(0, 0, 0, 0)
  borderColor = baseColor
  borderWidth = baseLineWidth
  borderRadius = hdpx(5)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize * 1.1
      text = "SIGHT"
    }
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize * 1.1
      text = "TADS"
    }
  ]
}

let symbolB = {
  rendObj = ROBJ_TEXT
  color = baseColor
  font = Fonts.ah64
  fontSize = baseFontSize * 1.1
  text = "B"
}

let lrfdBox = {
  rendObj = ROBJ_BOX
  size = [pw(10), ph(8)]
  pos = [pw(64), ph(25)]
  fillColor = Color(0, 0, 0, 0)
  borderColor = baseColor
  borderWidth = baseLineWidth
  borderRadius = hdpx(5)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize * 1.1
      text = "LRFD"
    }
    symbolB
  ]
}

let lstBox = lrfdBox.__merge({
  pos = [pw(26), ph(25)]
  children = [
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      font = Fonts.ah64
      fontSize = baseFontSize * 1.1
      text = "LST"
    }
    symbolB
  ]
})

let pods = @(width, height, pos) function() {
  let childrens = []

  for (local i = 0; i < WeaponSlots.get().len(); ++i) {
    if (WeaponSlots.get()[i] != null && WeaponSlotsTrigger.get().len() > i && WeaponSlotsTotalCnt.get().len() > i) {
      if (WeaponSlotsTrigger.get()[i] == weaponTriggerName.AGM_TRIGGER && WeaponSlotsTotalCnt.get()[i] <= 4) {
        let cnt = WeaponSlotsCnt.get()[i]
        let idx = WeaponSlots.get()[i] - 2
        if (idx < 0)
          continue
        let shows = [
          cnt > 1,
          cnt > 0,
          cnt > 3,
          cnt > 2
        ]
        let next = [
          cnt == 2,
          cnt == 1,
          cnt == 4,
          cnt == 3
        ]
        let rocketsSymbol = []
        for (local j = 0; j < 4; ++j) {
          let show = shows[j]
          let row = j / 2
          let col = j % 2
          let isNext = SelectedWeapSlot.get() == WeaponSlots.get()[i] && next[j] && SelectedTrigger.get() >= 0
          let isReady = next[j]
          rocketsSymbol.append(@(){
            key = $"{i}{j}{isNext}"
            watch = [SelectedTrigger, WeaponSlotsCnt]
            rendObj = ROBJ_VECTOR_CANVAS
            size = flex()
            color = SelectedTrigger.value != weaponTriggerName.AGM_TRIGGER ? baseColor : (isNext ? Color(255, 255, 255) : Color(0, 0, 0, 255))
            fillColor = SelectedTrigger.value == weaponTriggerName.AGM_TRIGGER && !isNext ? baseColor : Color(0, 0, 0, 255)
            lineWidth = baseLineWidth
            commands = [
              (show ? [VECTOR_RECTANGLE, 0 + 60 * col, 0 + 60 * row, 40, 40] : [VECTOR_RECTANGLE, 14 + 60 * col, 0 + 60 * row, 12, 40]),
              (show ? [VECTOR_SECTOR, 20 + 60 * col, 0 + 60 * row, 20, 7, -180, 0] : []),
              (show ? [VECTOR_LINE, 0 + 60 * col, 6 + 60 * row, 40 + 60 * col, 6 + 60 * row] : [])
            ]
            animations = [
              { prop = AnimProp.color, from = Color(255, 255, 255, 255), to = Color(10, 10, 10, 255), duration = 0.5, loop = true, easing = CosineFull, play = isNext }
            ]
            children = show ? {
              size = [pw(40), ph(40)]
              pos = [pw(0 + 60 * col), ph(5 + 60 * row)]
              flow = FLOW_VERTICAL
              valign = ALIGN_CENTER
              halign = ALIGN_CENTER
              children = SelectedTrigger.value == weaponTriggerName.AGM_TRIGGER ? [
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = SelectedTrigger.value != weaponTriggerName.AGM_TRIGGER ? baseColor : (isNext ? Color(255, 255, 255) : Color(0, 0, 0, 255))
                  font = Fonts.ah64
                  fontSize = baseFontSize * 0.9
                  text = isReady ? "B" : "L"
                  fontFx = FFT_BLUR
                  fontFxColor = Color(0, 0, 0, 255)
                  fontFxFactor = 1
                }
                @(){
                  watch = IsLaserDesignatorEnabled
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = SelectedTrigger.value != weaponTriggerName.AGM_TRIGGER ? baseColor : (isNext ? Color(255, 255, 255) : Color(0, 0, 0, 255))
                  font = Fonts.ah64
                  fontSize = baseFontSize * 0.9
                  text = isReady ? (IsLaserDesignatorEnabled.get() ? "T" : "R") : "S"
                  fontFx = FFT_BLUR
                  fontFxColor = Color(0, 0, 0, 255)
                  fontFxFactor = 1
                }
              ] : {
                rendObj = ROBJ_TEXT
                size = SIZE_TO_CONTENT
                color = baseColor
                font = Fonts.ah64
                fontSize = baseFontSize * 0.9
                text = "L"
              }
            } : null
          })
        }
        childrens.append(@(){
          size = [width * 0.13, height * 0.4]
          pos = [idx < 2 ? (width * 0.05 + idx * width * 0.17) : (width * 0.66 + (idx-2) * width * 0.17), height * 0.35]
          children = rocketsSymbol
        })
      }
      else if (WeaponSlotsTrigger.get()[i] == weaponTriggerName.ROCKETS_TRIGGER || (WeaponSlotsTrigger.get()[i] == weaponTriggerName.AGM_TRIGGER && WeaponSlotsTotalCnt.get()[i] > 4)) {
        let idx = WeaponSlots.get()[i] - 2
        let slot = WeaponSlots.get()[i]
        let trigger = WeaponSlotsTrigger.get()[i]
        childrens.append(@(){
          watch = SelectedWeapSlot
          rendObj = ROBJ_VECTOR_CANVAS
          size = [width * 0.13, height * 0.3]
          pos = [idx < 2 ? (width * 0.05 + idx * width * 0.17) : (width * 0.66 + (idx-2) * width * 0.17), height * 0.4]
          color = baseColor
          fillColor = SelectedWeapSlot.get() == slot ? baseColor : Color(0, 0, 0, 255)
          lineWidth = baseColor
          commands = [
            [VECTOR_RECTANGLE, 0, 0, 100, 100],
            [VECTOR_SECTOR, 10, 0, 10, 5, -180, 0],
            [VECTOR_SECTOR, 30, 0, 10, 5, -180, 0],
            [VECTOR_SECTOR, 50, 0, 10, 5, -180, 0],
            [VECTOR_SECTOR, 70, 0, 10, 5, -180, 0],
            [VECTOR_SECTOR, 90, 0, 10, 5, -180, 0]
          ]
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          children = {
            rendObj = ROBJ_TEXT
            size = SIZE_TO_CONTENT
            color = SelectedWeapSlot.get() != slot ? baseColor : Color(0, 0, 0, 255)
            font = Fonts.ah64
            fontSize = baseFontSize
            text = trigger == weaponTriggerName.ROCKETS_TRIGGER ? "6PD" : "ASR"
            fontFx = FFT_BLUR
            fontFxColor = Color(0, 0, 0, 255)
            fontFxFactor = 1
          }
        })
      }
    }
  }

  return {
    watch = [WeaponSlots, WeaponSlotsCnt, SelectedWeapSlot, SelectedTrigger, WeaponSlotsTotalCnt]
    size = [width, height]
    pos
    children = childrens
  }
}

let channels = @(){
  watch = SelectedTrigger
  size = flex()
  children = SelectedTrigger.get() == weaponTriggerName.AGM_TRIGGER ?
    {
      rendObj = ROBJ_BOX
      size = [pw(50), ph(14)]
      pos = [pw(25), ph(77)]
      fillColor = Color(0, 0, 0, 0)
      borderColor = baseColor
      borderWidth = baseLineWidth
      borderRadius = 10
      halign = ALIGN_CENTER
      children = [
        {
          rendObj = ROBJ_TEXT
          size = SIZE_TO_CONTENT
          pos = [0, ph(5)]
          color = baseColor
          font = Fonts.ah64
          fontSize = baseFontSize
          text = "CHANNELS"
        }
        {
          size = flex()
          children = [
            {
              size = [pw(15), pw(15)]
              rendObj = ROBJ_FRAME
              color = baseColor
              pos = [pw(5), ph(35)]
              flow = FLOW_VERTICAL
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              children = [
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = baseColor
                  font = Fonts.ah64
                  fontSize = baseFontSize
                  text = "PRI"
                }
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = baseColor
                  font = Fonts.ah64
                  fontSize = baseFontSize
                  text = "B"
                }
              ]
            }
            {
              size = [pw(15), pw(15)]
              rendObj = ROBJ_FRAME
              color = baseColor
              pos = [pw(30), ph(35)]
              flow = FLOW_VERTICAL
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              children = [
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = baseColor
                  font = Fonts.ah64
                  fontSize = baseFontSize
                  text = "ALT"
                }
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = baseColor
                  font = Fonts.ah64
                  fontSize = baseFontSize
                  text = "C"
                }
              ]
            }
            {
              size = [pw(15), pw(15)]
              pos = [pw(55), ph(35)]
              flow = FLOW_VERTICAL
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              children = [
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = baseColor
                  font = Fonts.ah64
                  fontSize = baseFontSize
                  text = "3"
                }
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = baseColor
                  font = Fonts.ah64
                  fontSize = baseFontSize
                  text = "D"
                }
              ]
            }
            {
              size = [pw(15), pw(15)]
              pos = [pw(80), ph(35)]
              flow = FLOW_VERTICAL
              halign = ALIGN_CENTER
              valign = ALIGN_CENTER
              children = [
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = baseColor
                  font = Fonts.ah64
                  fontSize = baseFontSize
                  text = "4"
                }
                {
                  rendObj = ROBJ_TEXT
                  size = SIZE_TO_CONTENT
                  color = baseColor
                  font = Fonts.ah64
                  fontSize = baseFontSize
                  text = "G"
                }
              ]
            }
          ]
        }
      ]
    } : null
}

function wpnPage(pos, size) {
  return {
    size
    pos
    children = [
      silhouette
      buttons
      gunArm
      gun
      chaff
      acqBox
      sightBox
      lrfdBox
      lstBox
      pods(size[0] * 0.64, size[1] * 0.5, [size[0] * 0.18, size[1] * 0.25])
      channels
    ]
  }
}

return wpnPage