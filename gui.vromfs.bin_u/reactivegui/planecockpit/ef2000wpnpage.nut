from "%rGui/globals/ui_library.nut" import *

let string = require("string")

let { CannonCount, FlaresCount, ChaffsCount } = require("%rGui/airState.nut")
let { WeaponSlots, WeaponSlotsTrigger, WeaponSlotsCnt,
 SelectedWeapSlot, WeaponSlotsTotalCnt, CurWeaponName,
 WeaponSlotsName, WeaponSlotsJettisoned } = require("%rGui/planeState/planeWeaponState.nut")
let { weaponTriggerName } = require("%rGui/planeIlses/ilsConstants.nut")

let baseColor = Color(255, 255, 255, 255)
let baseFontSize = 22
let baseLineWidth = 2
let baseSpacing = 4.5

let wpnName = @(fullWpnName) fullWpnName.replace("_default", "")

let posWeapons = [
  [50.0 + 0.0,   0.0   ], 

  [50.0 - 33.0,  65.0  ], 
  [50.0 - 27.0,  57.0  ], 
  [50.0 - 19.0,  52.0  ], 
  [50.0 - 12.0,  37.0  ], 
  [50.0 - 5.0,   67.0  ], 
  [50.0 - 5.0,   37.0  ], 
  [50.0 + 0.0,   52.0  ], 
  [50.0 + 5.0,   37.0  ], 
  [50.0 + 5.0,   67.0  ], 
  [50.0 + 12.0,  37.0  ], 
  [50.0 + 19.0,  52.0  ], 
  [50.0 + 27.0,  57.0  ], 
  [50.0 + 33.0,  65.0  ], 
]

let posLabels = [
  [50.0 + 0.0,   0.0   ], 

  [50.0 - 35.0,  80.0  ], 
  [50.0 - 29.0,  74.0  ], 
  [50.0 - 19.0 + 1.0,  62.0  ], 
  [50.0 - 14.0,  47.0  ], 
  [50.0 - 8.0,   83.0  ], 
  [50.0 - 8.0,   53.0  ], 
  [50.0 + 0.0,   65.0  ], 
  [50.0 + 8.0,   53.0  ], 
  [50.0 + 8.0,   83.0  ], 
  [50.0 + 14.0,  47.0  ], 
  [50.0 + 19.0 + 1.0,  62.0  ], 
  [50.0 + 29.0,  74.0  ], 
  [50.0 + 35.0,  80.0  ], 
]

let aircraftOutline = {
  size = const [pw(76), ph(94)]
  pos = [pw(12), ph(1)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = Color(0, 0, 255, 255)
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_POLY,
      50.0,    0.0,

      42.0,    30.1,
      41.9,    41.3,
      2.9,     81.3,
      2.9,     78.7,
      0.0,     78.7,
      0.0,     92.1,
      1.6,     93.5,
      3.1,     92.3,
      40.7,    96.4,
      41.7,    100.0,

      50.0,    100.0,

      58.3,    100.0,
      59.3,    96.4,
      96.9,    92.3,
      98.4,    93.5,
      100.0,   92.1,
      100.0,   78.7,
      97.1,    78.7,
      97.1,    81.3,
      58.1,    41.3,
      58,      30.1,
    ],
    [VECTOR_LINE,
      45.8,    15.8,
      35.6,    26.4,
      35.6,    31.0,
      42.4,    28.6,
    ],
    [VECTOR_LINE,
      54.2,    15.8,
      64.4,    26.4,
      64.4,    31.0,
      57.6,    28.6,
    ]
  ]
}

let counterMeasures = {
  size = flex()
  pos = [pw(5), ph(5)]
  flow = FLOW_VERTICAL
  halign = ALIGN_LEFT
  children = [
    @() {
      watch = [ChaffsCount, FlaresCount]
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXTAREA
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      behavior = Behaviors.TextArea
      spacing = baseSpacing
      text = string.format(
        "CHAFF %d\nFLARE %d\nDECOY",
        ChaffsCount.get(),
        FlaresCount.get()
      )
    }
  ]
}

let status = {
  size = flex()
  pos = [pw(85), ph(15)]
  flow = FLOW_VERTICAL
  halign = ALIGN_LEFT
  children = [
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXTAREA
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      behavior = Behaviors.TextArea
      spacing = baseSpacing
      text = "MASS"
    }
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXTAREA
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      behavior = Behaviors.TextArea
      text = "LIVE"
    }
  ]
}

let CannonAmmoCount = CannonCount[0]
let cannon = @() {
  pos = [pw(45.3), ph(22)]
  size = const [pw(10), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_POLY,
      0.0,    50.0,
      0.0,    100.0,
      100.0,  100.0,
      100.0,  50.0,
      90.0,   50.0,
      90.0,   0.0,
      85.0,   0.0,
      85.0,   50.0,
    ]
  ]
  children = [
    @() {
      watch = CannonAmmoCount
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      pos = [pw(0), ph(32)]
      rendObj = ROBJ_TEXTAREA
      color = baseColor
      font = Fonts.hud
      fontSize = baseFontSize
      spacing = baseSpacing
      behavior = Behaviors.TextArea
      text = string.format("%d", CannonAmmoCount.get())
    }
  ]
}

let sraam = @(pos, selected = false, size = const [5, 22]) {
  size = [pw(size[0]), ph(size[1])]
  pos = [pw(pos[0]), ph(pos[1])]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = (selected) ? Color(0, 255, 255, 255) : Color(0, 0, 0, 255)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_POLY,
      -13.0,  2.6,
      -13.0,  13.6,
      -24.5,  19.3,
      -13.0,  20.5,
      -13.0,  80.2,
      -32.0,  87.3,
      -32.0,  100.0,

      32.0,   100.0,
      32.0,   87.3,
      13.0,   80.2,
      13.0,   20.5,
      24.5,   19.3,
      13.0,   13.6,
      13.0,   2.6,
      
      11.7,   1.8,
      9.3,    1.1,
      6.0,    0.7,
      2.1,    0.4,

      -2.1,   0.4,
      -6.0,   0.7,
      -9.3,   1.1,
      -11.7,  1.8,
    ],
  ]
}

let sraamDual = @(pos, amount, selected = false) {
  size = flex()
  pos = [pw(0), ph(0)]
  children = [
    (amount >= 1)
      ? sraam([pos[0] - 1.6, pos[1] + 3.0], selected, [4.5, 19])
      : null,
    (amount > 1 )
      ? sraam([pos[0] + 1.6, pos[1] + 3.0], selected, [4.5, 19])
      : null
  ]
}

let mraam = @(pos, selected = false) {
  size = const [pw(5), ph(25)]
  pos = [pw(pos[0]), ph(pos[1])]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = (selected) ? Color(0, 255, 255, 255) : Color(0, 0, 0, 255)
  lineWidth = baseLineWidth
  commands = [
  [VECTOR_POLY,
    0.0,     0.0,

    -18.5,   15.5,
    -18.5,   43.3,
    -42.0,   52.4,
    -18.5,   52.4,
    -18.5,   87.4,
    -42.0,   100.0,

    42.0,    100.0,
    18.5,    87.4,
    18.5,    52.4,
    42.0,    52.4,
    18.5,    43.3,
    18.5,    15.5,
  ],
  ]
}

let agml3 = @(pos) {
  size = const [pw(8), ph(16)]
  pos = [pw(pos[0]), ph(pos[1])]
  rendObj = ROBJ_VECTOR_CANVAS
  color = baseColor
  fillColor = Color(0, 0, 0, 255)
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_POLY,
      0.0,    0.0,

      -27.5,  7.5,
      -40.0,  23.0,
      -40.0,  77.0,
      -27.5,  92.5,

      0.0,    100.0,

      27.5,   92.5,
      40.0,   77.0,
      40.0,   23.0,
      27.5,   7.5,
    ]
  ]
}

let brimstone = @(pos, selected = false) function() {
  return {
    size = const [pw(3.3), ph(14)]
    pos = [pw(pos[0]), ph(pos[1])]
    rendObj = ROBJ_VECTOR_CANVAS
    fillColor = (selected) ? Color(0, 255, 255, 255) : Color(0, 0, 0, 255)
    color = baseColor
    lineWidth = baseLineWidth
    commands = [
      [VECTOR_POLY,
        -22.5,   5.5,
        -22.5,   67.7,
        -36.0,   74.2,
        -36.0,   95.0,
        -31.0,   98.3,
        -20.0,   100.0,

        20.0,    100.0,
        31.0,    98.3,
        36.0,    95.0,
        36.0,    74.2,
        22.5,    67.7,
        22.5,    5.5,
      ],
      [VECTOR_SECTOR,
        0.0,    5.5, 
        22.0,   7.0, 
        180.0,  0.0, 
      ]
    ]
  }
}

let brimstoneTri = @(pos, amount, selected = false, jettisoned = false) function() {
  let offset = 5.5
  return {
    rendObj = ROBJ_TEXT
    size = flex()
    children = [
      (!jettisoned) ? agml3([pos[0], pos[1] + offset]) : null,
      (amount > 2)
        ? brimstone([pos[0] - 2.4, pos[1] + offset + 2.0], selected)
        : null,
      (amount > 0)
        ? brimstone([pos[0] + 2.4, pos[1] + offset + 2.0], selected)
        : null,
      (amount > 1)
        ? brimstone([pos[0], pos[1] + offset - 2.0], selected)
        : null,
    ]
  }
}

let targetingPod = @(pos, size = const [25, 20]) {
  size = [pw(size[0]), ph(size[1])]
  pos = [pw(pos[0]), ph(pos[1])]
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = Color(0, 0, 0, 255)
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_POLY,
      -4.2,   7.0,
      -4.2,   84.0,
      -2.8,   100.0,

      2.8,    100.0,
      4.2,    84.0,
      4.2,    7.0,
    ],
    [VECTOR_FILL_COLOR, Color(255, 255, 255, 255)],
    [VECTOR_ELLIPSE,
      0.0,    7.0,  
      4.2,    5.5   
    ],
  ]
}

let bomb = @(pos, selected = false, size = const [4, 20]) {
  size = [pw(size[0]), ph(size[1])]
  pos = [pw(pos[0]), ph(pos[1])]
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = (selected) ? Color(0, 255, 255, 255) : Color(0, 0, 0, 255)
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_POLY,
      0.0,     84.0,

      -43.5,   88.5,
      -43.5,   95.0,

      43.5,    95.0,
      43.5,    88.5,
    ],
    [VECTOR_POLY,
      -11.0,   16.4,
      -16.5,   17.5,
      -22.0,   19.1,
      -30.0,   22.8,
      -37.0,   27.6,
      -42.5,   33.4,
      -46.5,   39.8,
      -49.0,   46.7,
      -50.0,   53.9,
      -46.0,   62.4,
      -39.5,   70.2,
      -30.5,   79.6,
      -17.5,   90.2,
      -9.0,    96.6,

      9.0,     96.6,
      17.5,    90.2,
      30.5,    79.6,
      39.5,    70.2,
      46.0,    62.4,
      50.0,    53.9,
      49.0,    46.7,
      46.5,    39.8,
      42.5,    33.4,
      37.0,    27.6,
      30.0,    22.8,
      22.0,    19.1,
      16.5,    17.5,
      11.0,    16.4,
    ],
  ]
}

let lgb = @(pos, selected = false, size = const [4, 20]) {
  size = [pw(size[0]), ph(size[1])]
  pos = [pw(pos[0]), ph(pos[1])]
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = (selected) ? Color(0, 255, 255, 255) : Color(0, 0, 0, 255)
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_POLY, 
      -11.0,   16.4,
      -16.5,   17.5,
      -22.0,   19.1,
      -30.0,   22.8,
      -37.0,   27.6,
      -42.5,   33.4,
      -46.5,   39.8,
      -49.0,   46.7,
      -50.0,   53.9,
      -46.0,   62.4,
      -39.5,   70.2,
      -30.5,   79.6,
      -17.5,   90.2,
      -9.0,    96.6,

      9.0,     96.6,
      17.5,    90.2,
      30.5,    79.6,
      39.5,    70.2,
      46.0,    62.4,
      50.0,    53.9,
      49.0,    46.7,
      46.5,    39.8,
      42.5,    33.4,
      37.0,    27.6,
      30.0,    22.8,
      22.0,    19.1,
      16.5,    17.5,
      11.0,    16.4,
    ],
    [VECTOR_FILL_COLOR, Color(255, 255, 255, 255)],
    [VECTOR_POLY, 
      0.0,     0.0,
      -17.5,   5.5,
      -17.5,   9.3,
      -50.0,   15.1,
      -50.0,   18.7,

      50.0,    18.7,
      50.0,    15.1,
      17.5,    9.3,
      17.5,    5.5,
    ],
    [VECTOR_POLY, 
      -30.5,   79.6,
      -57.0,   86.6,
      -57.0,   95.8,
      -25.0,   95.8,
      -25.0,   96.6,

      25.0,   96.6,
      25.0,   95.8,
      57.0,   95.8,
      57.0,   86.6,
      30.5,   79.6,
    ],
  ]
}

let lgbDual = @(pos, amount, selected = false, jettisoned = false) function() {
  let offset = 5.5
  return {
    rendObj = ROBJ_TEXT
    size = flex()
    children = [
      (!jettisoned) ? agml3([pos[0], pos[1] + offset]) : null,
      (amount > 1)
        ? lgb([pos[0] - 2.0, pos[1] + offset], selected, [3, 18])
        : null,
      (amount > 0)
        ? lgb([pos[0] + 2.0, pos[1] + offset], selected, [3, 18])
        : null,
    ]
  }
}

let fuelTank = @(pos, size = const [8, 40]) {
  size = [pw(size[0]), ph(size[1])]
  pos = [pw(pos[0]), ph(pos[1] - 12.0)]
  rendObj = ROBJ_VECTOR_CANVAS
  fillColor = Color(0, 255, 255, 255)
  color = baseColor
  lineWidth = baseLineWidth
  commands = [
    [VECTOR_POLY, 
      -1.0,    0.0,
      -5.0,    0.2,
      -9.0,    0.6,
      -12.5,   1.3,
      -15.0,   2.0,
      -16.5,   2.7,
      -17.5,   3.5,
      -29.5,   25.6,
      -31.0,   32.3,
      -34.0,   58.4,
      -34.0,   68.3,
      -26.5,   95.5,
      -25.5,   96.6,
      -23.0,   97.5,
      -19.5,   98.2,
      -15.0,   98.0,
      -11.0,   99.5,
      -6.5,    99.8,
      -1.5,    100.0,

      1.5,    100.0,
      6.5,    99.8,
      11.0,   99.5,
      15.0,   98.0,
      19.5,   98.2,
      23.0,   97.5,
      25.5,   96.6,
      26.5,   95.5,
      34.0,   68.3,
      34.0,   58.4,
      31.0,   32.3,
      29.5,   25.6,
      17.5,   3.5,
      16.5,   2.7,
      15.0,   2.0,
      12.5,   1.3,
      9.0,    0.6,
      5.0,    0.2,
      1.0,    0.0,
    ],
  ]
}

let label = @(text, pos) function() {
  local labelText = {
    size = SIZE_TO_CONTENT
    children = [
      {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXTAREA
        color = baseColor
        font = Fonts.hud
        fontSize = baseFontSize
        text = text
        margin = const [2.5, 5]
        spacing = baseSpacing
        behavior = Behaviors.TextArea
    }
    ]
  }

  let size = calc_comp_size(labelText).map(@(v) v * 0.17)

  pos = [
    pos[0] - (size[0]/2),
    pos[1] - (size[1]/2)
  ]

  let borders = {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    color = baseColor
    lineWidth = baseLineWidth
    commands = [
      [VECTOR_LINE,
        0.0,    20.0,
        0.0,    0.0,
        100.0,  0.0,
        100.0,  20.0,
      ],
      [VECTOR_LINE,
        0.0,    80.0,
        0.0,    100.0,
        100.0,  100.0,
        100.0,  80.0,
      ]
    ]
  }

  return {
    size = [pw(size[0]), ph(size[1])]
    pos = [pw(pos[0]), ph(pos[1])]
    rendObj = ROBJ_SOLID
    color = Color(0, 255, 0, 255)
    halign = ALIGN_CENTER
    children = [labelText, borders]
  }
}

let weapons = function() {
  let weaponsChildren = []
  let weaponsLabels = []
  let curWpn = wpnName(CurWeaponName.get() ?? "")

  foreach (i, weaponSlot in WeaponSlots.get()) {
    if (weaponSlot == null)
      continue
    let weaponSlotCnt = WeaponSlotsCnt.get()?[i] ?? 0
    let weaponSlotName = wpnName(WeaponSlotsName.get()?[i] ?? "")
    if (weaponSlotName == "")
      continue
    let weaponSlotTotalCnt = WeaponSlotsTotalCnt.get()[i]
    let triggerName = WeaponSlotsTrigger.get()?[i]
    let jettisoned = WeaponSlotsJettisoned.get()[i]
    let selected = (weaponSlotName == curWpn)

    
    
    

    
    if (weaponSlotName.contains("aim_120") && weaponSlotCnt > 0) {
      weaponsChildren.append(mraam(posWeapons[weaponSlot], selected))
      weaponsLabels.append(label("MRAAM", posLabels[weaponSlot]))
      continue
    }
    
    if (weaponSlotName.contains("aim9") && weaponSlotCnt > 0) {
      if (weaponSlotTotalCnt == 1 && weaponSlotCnt == 1)
        weaponsChildren.append(sraam(posWeapons[weaponSlot], selected))
      else if (weaponSlotTotalCnt > 1) {
        weaponsChildren.append(sraamDual(
          posWeapons[weaponSlot],
          weaponSlotCnt,
          selected,
        ))
      }
      weaponsLabels.append(label("SRAAM", posLabels[weaponSlot]))
      continue
    }
    
    if (weaponSlotName.contains("brimstone")) {
      weaponsChildren.append(brimstoneTri(
        posWeapons[weaponSlot], weaponSlotCnt, selected,
        jettisoned
      ))
      if (weaponSlotCnt > 0)
        weaponsLabels.append(label("BRMST", posLabels[weaponSlot]))
      continue
    }
    
    if (weaponSlotName.contains("targeting_pod")) {
      weaponsChildren.append(targetingPod(posWeapons[weaponSlot]))
      weaponsLabels.append(label("TDP", posLabels[weaponSlot]))
      continue
    }
    
    if (weaponSlotName.contains("paveway") || weaponSlotName.contains("mk18")) {
      if (weaponSlotTotalCnt == 1 && weaponSlotCnt == 1) {
        weaponsChildren.append(lgb(posWeapons[weaponSlot], selected))
        weaponsLabels.append(label("PVWY", posLabels[weaponSlot]))
      }
      else if (weaponSlotTotalCnt > 1) {
        weaponsChildren.append(lgbDual(
          posWeapons[weaponSlot], weaponSlotCnt, selected,
          jettisoned
        ))
        if (weaponSlotCnt > 0)
          weaponsLabels.append(label("PVWY", posLabels[weaponSlot]))
      }
      continue
    }
    
    if (weaponSlotName.contains("gbu_54b") && weaponSlotCnt > 0) {
      weaponsChildren.append(lgb(posWeapons[weaponSlot], selected))
      weaponsLabels.append(label("LJDAM", posLabels[weaponSlot]))
      continue
    }
    
    if (weaponSlotName.contains("mk_83") && weaponSlotCnt > 0) {
      weaponsChildren.append(bomb(posWeapons[weaponSlot], selected))
      weaponsLabels.append(label("MK83", posLabels[weaponSlot]))
      continue
    }
    
    if (weaponSlotName.contains("mk_84") && weaponSlotCnt > 0) {
      weaponsChildren.append(bomb(posWeapons[weaponSlot], selected))
      weaponsLabels.append(label("MK84", posLabels[weaponSlot]))
      continue
    }
    
    if (weaponSlotName.contains("1000l_ef_2000") && weaponSlotCnt > 0) {
      weaponsChildren.append(fuelTank(posWeapons[weaponSlot]))
      weaponsLabels.append(label("1000L", posLabels[weaponSlot]))
      continue
    }

    
    
    

    if (triggerName == weaponTriggerName.BOMBS_TRIGGER && weaponSlotCnt > 0) {
      weaponsChildren.append(bomb(posWeapons[weaponSlot], selected))
      weaponsLabels.append(label("BOMB", posLabels[weaponSlot]))
      continue
    }
    if (triggerName == weaponTriggerName.AGM_TRIGGER && weaponSlotCnt > 0) {
      weaponsChildren.append(brimstone(posWeapons[weaponSlot], selected))
      weaponsLabels.append(label("AGM", posLabels[weaponSlot]))
      continue
    }
    if (triggerName == weaponTriggerName.AAM_TRIGGER && weaponSlotCnt > 0) {
      weaponsChildren.append(bomb(posWeapons[weaponSlot], selected))
      weaponsLabels.append(label("AAM", posLabels[weaponSlot]))
      continue
    }
    if (triggerName == weaponTriggerName.GUIDED_BOMBS_TRIGGER && weaponSlotCnt > 0) {
      weaponsChildren.append(lgb(posWeapons[weaponSlot], selected))
      weaponsLabels.append(label("GBU", posLabels[weaponSlot]))
      continue
    }
  }


  weaponsChildren.extend(weaponsLabels)

  return {
    watch = [WeaponSlots, WeaponSlotsCnt, WeaponSlotsTotalCnt, SelectedWeapSlot]
    size = flex()
    children = weaponsChildren
  }
}

function wpnPage(pos, size) {
  return {
    size
    pos
    children = [
      aircraftOutline,
      cannon,
      counterMeasures,
      weapons,
      label("STORE", [10, 50]),
      status,
    ]
  }
}

return wpnPage