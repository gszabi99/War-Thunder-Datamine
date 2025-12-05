from "%rGui/globals/ui_library.nut" import *

let math = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")
let { FlaresCount, ChaffsCount} = require("%rGui/airState.nut")

let { color, baseLineWidth, rwrTargetsComponent } = require("%rGui/planeRwrs/rwrAnApr39Components.nut")

function makeGridCommands() {
  let commands = [
    [VECTOR_ELLIPSE, 0, 0, 100, 100],
    [VECTOR_ELLIPSE, 0, 0, 5, 5],
    [VECTOR_LINE, -5, 0, 5, 0],
    [VECTOR_LINE, 0, -5, 0, 5]  ]
  local azimuthMarkIndex =  0
  let middleMarkLen = 0.05
  for (local az = 0.0; az < 360.0; az += 30) {
    let sinAz = math.sin(degToRad(az))
    let cosAz = math.cos(degToRad(az))
    let azimuthMarkLen = azimuthMarkIndex % 3 == 0 ? 0.25 : 0.15
    commands.append([ VECTOR_LINE,
                      sinAz * 100.0,
                      cosAz * 100.0,
                      sinAz * (1.0 - azimuthMarkLen) * 100.0,
                      cosAz * (1.0 - azimuthMarkLen) * 100.0])
    commands.append([ VECTOR_LINE,
                      sinAz * 50.0 + cosAz * middleMarkLen * 100.0,
                      cosAz * 50.0 - sinAz * middleMarkLen * 100.0,
                      sinAz * 50.0 - cosAz * middleMarkLen * 100.0,
                      cosAz * 50.0 + sinAz * middleMarkLen * 100.0])
    ++azimuthMarkIndex
  }
  return commands
}

let gridCommands = makeGridCommands()

function createGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)]
    size = flex()
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = 0
    commands = gridCommands
  }
}

function scope(scale, style) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createGrid(style.grid),
      rwrTargetsComponent(style.object),
    ]
  }
}

let buttons = {
  size = flex()
  children = [
    {
      rendObj = ROBJ_FRAME
      pos = [pw(-63), ph(-50)]
      size = const [pw(20), ph(12)]
      color = color
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = color
            font = Fonts.ah64
            fontSize = getFontDefHt("hud") * 0.7
            text = "MENU"
        }
      }
    {
      rendObj = ROBJ_FRAME
      pos = [pw(-63), ph(-18)]
      size = const [pw(22), ph(12)]
      color = color
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = color
            font = Fonts.ah64
            fontSize = getFontDefHt("hud") * 0.7
            text = "CHAFF"
        }
      }
    {
      rendObj = ROBJ_FRAME
      pos = [pw(-63), ph(17)]
      size = const [pw(22), ph(12)]
      color = color
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = color
            font = Fonts.ah64
            fontSize = getFontDefHt("hud") * 0.7
            text = "FLARE"
        }
      }
    {
      rendObj = ROBJ_FRAME
      pos = [pw(-63), ph(52)]
      size = const [pw(22), ph(12)]
      color = color
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = color
            font = Fonts.ah64
            fontSize = getFontDefHt("hud") * 0.7
            text = "OTH1"
        }
      }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(-63), ph(88)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "OTH2"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(-22), ph(-58)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "MAN"
    }
    {
      rendObj = ROBJ_FRAME
      pos = [pw(-1), ph(-62)]
      size = const [pw(28), ph(12)]
      color = color
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = {
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = color
            font = Fonts.ah64
            fontSize = getFontDefHt("hud") * 0.7
            text = "M+SEMI"
        }
      }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(76), ph(-58)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "M+AUTO"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(108), ph(-58)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "ALEM"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(130), ph(-58)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "SOURC"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(147), ph(-22)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "CHAFF"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(147), ph(-15)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "BINGO"
    }
    {
      rendObj = ROBJ_FRAME
      pos = [pw(149), ph(-7)]
      size = const [pw(15), ph(12)]
      borderColor = color
      borderWidth = baseLineWidth
      borderRadius = hdpx(10)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      children = {
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = color
            font = Fonts.ah64
            fontSize = getFontDefHt("hud") * 0.7
            text = "20"
        }
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(147), ph(12)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "FLARE"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(147), ph(20)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "BINGO"
    }
    {
      rendObj = ROBJ_FRAME
      pos = [pw(149), ph(28)]
      size = const [pw(15), ph(12)]
      borderColor = color
      borderWidth = baseLineWidth
      borderRadius = hdpx(10)
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      flow = FLOW_VERTICAL
      children = {
            size = SIZE_TO_CONTENT
            rendObj = ROBJ_TEXT
            color = color
            font = Fonts.ah64
            fontSize = getFontDefHt("hud") * 0.7
            text = "20"
        }
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(155), ph(85)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "INV"
    }
    {
      size = SIZE_TO_CONTENT
      pos = [pw(147), ph(93)]
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "RESET"
    }
  ]
}

let chaff = {
  rendObj = ROBJ_FRAME
  size = const [pw(25), ph(20)]
  pos = [pw(-20), ph(90)]
  borderColor = color
  borderWidth = baseLineWidth
  borderRadius = hdpx(10)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    {
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "CHAFF"
    }
    @(){
      watch = ChaffsCount
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = ChaffsCount.get().tostring()
    }
  ]
}

let flare = {
  rendObj = ROBJ_FRAME
  size = const [pw(25), ph(20)]
  pos = [pw(20), ph(90)]
  borderColor = color
  borderWidth = baseLineWidth
  borderRadius = hdpx(10)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  flow = FLOW_VERTICAL
  children = [
    {
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = "FLARE"
    }
    @(){
      watch = FlaresCount
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ah64
      fontSize = getFontDefHt("hud") * 0.7
      text = FlaresCount.get().tostring()
    }
  ]
}

let function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
     scope(scale, style)
     buttons
     chaff
     flare
    ]
  }
}

return tws
