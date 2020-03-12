local math = require("math")


/*
  TODO:
    View
      back as robj blur mask (need procuderal images)
*/
local function place_by_circle(params) {
  local objs = params?.objects ?? []
  local radius = params?.radius ?? hdpx(100)
  local offset = params?.offset ?? (3.0/4)
  local seg_angle = 2.0*math.PI/objs.len()

  return objs.map(function(o,i) {
    local angle = seg_angle*i-math.PI/2
    local pos = [math.cos(angle)*radius*offset+radius, math.sin(angle)*radius*offset+radius]
    return {
      pos=pos
      halign = ALIGN_CENTER
      valign=ALIGN_CENTER
      size=[0,0]
      rendObj=ROBJ_DTEXT
      text=",".concat(pos[0],pos[1])
      children = o
    }
  })
}

local selectedBorderColor = Color(85, 85, 85, 100)
local selectedBgColor = Color(0, 0, 0, 120)
local sectorWidth = 1.0/2

local function mDefCtor(text) {
  return function (curIdx, idx) {
    return ::watchElemState(function(sf) {
      return {
        rendObj = ROBJ_DTEXT
        text = text
        color = (curIdx.value==idx || (S_HOVER & sf)) ? Color(250,250,250) : Color(120,120,120)
      }
    })
  }
}

local defParams = {
  objs=[], radius=::hdpx(250) back=null, axisXY=[],
  sectorCtor = null, nullSectorCtor = null,
  eventHandlers= null, hotkeys = null
  devId = DEVID_MOUSE, stickNo = 1
}


local function makeDefaultBack(radius, size) {
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    color = selectedBgColor
    size = size
    commands = [
      [VECTOR_WIDTH, sectorWidth*radius],
      [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
      [VECTOR_ELLIPSE, 50, 50, 50*sectorWidth*3/2, 50*sectorWidth*3/2],
      [VECTOR_WIDTH, hdpx(5)],
      [VECTOR_COLOR, selectedBorderColor],
      [VECTOR_FILL_COLOR, 0],
      [VECTOR_ELLIPSE, 50, 50, 50*(1-sectorWidth), 50*(1-sectorWidth)],
//      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }
}

local function makeDefaultSector(size, radius, sangle) {
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    color = selectedBgColor
//    fillColor = selectedFillColor
    size = size
    commands = [
//      [VECTOR_COLOR, selectedBorderColor],
      [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
      [VECTOR_WIDTH, radius*sectorWidth],
      [VECTOR_SECTOR, 50, 50, 50*sectorWidth*3/2, 50*sectorWidth*3/2, -sangle-90, sangle-90],
      [VECTOR_COLOR, selectedBorderColor],
      [VECTOR_WIDTH, hdpx(5)],
      [VECTOR_SECTOR, 50, 50, 50, 50, -sangle-90, sangle-90],
    ]
  }
}


local function mkPieMenu(params=defParams){
  local radius = params?.radius ?? hdpx(250)
  local objs = params?.objs ?? []
  local objsnum = objs.len()
  local size = [radius*2, radius*2]
  local back = params?.back?() ?? makeDefaultBack(radius, size)
  if (objsnum==0)
    return back
  local sangle = 360.0 / objsnum/2

  local internalIdx = ::Watched(null)
  local curIdx = params?.curIdx ?? ::Watched(null)
  local curAngle = ::Watched(null)
  internalIdx.subscribe(function(v) { if (v != null) curIdx(v)})
  local children = place_by_circle({
    radius=radius, objects=objs.map(@(v, i) v?.ctor?(curIdx, i) ?? mDefCtor(v?.text)(curIdx, i) ), offset=3.0/4
  })
  local sector = params?.sectorCtor?() ?? makeDefaultSector(size, radius, sangle)

  local function angle() {
    return {
      rendObj = ROBJ_VECTOR_CANVAS
      color = Color(0,0,0,180)
      transform = {
        pivot = [0.5,0.5]
        rotate = (curAngle.value ?? 0.0)*180.0/math.PI
      }
      size = size
      watch = curAngle
      commands = curAngle.value!=null
      ? [
          [VECTOR_FILL_COLOR, Color(0, 0, 0, 0)],
          [VECTOR_WIDTH, hdpx(6)],
          [VECTOR_COLOR, Color(250,250,250)],
          [VECTOR_SECTOR, 50, 50, 50*sectorWidth*0.95, 50*sectorWidth*0.95, -sangle-90, sangle-90],
        ]
      : []
    }
  }

  local nullSector = params?.nullSectorCtor?() ?? {
    rendObj = ROBJ_VECTOR_CANVAS
    color = selectedBorderColor
    fillColor = Color(0,0,0,50)
    size = size
    commands = [
      [VECTOR_WIDTH, hdpx(5)],
      [VECTOR_ELLIPSE, 50, 50, 50*(1-sectorWidth), 50*(1-sectorWidth)]
    ]
  }

  local function activeSector() {
    return {
      watch = [curIdx]
      size = size
      children = curIdx.value!=null ? [sector, nullSector] : null
      transform = {
        rotate = (curIdx.value ?? 0) * 2*sangle
        pivot = [0.5,0.5]
      }
    }
  }

  local function pieMenu() {
    return {
      size = size
      watch = curIdx
      behavior = Behaviors.PieMenu
      skipDirPadNav = true
      devId = params?.devId ?? defParams.devId
      stickNo = params?.stickNo ?? defParams.stickNo
      curSector = internalIdx
      curAngle = curAngle
      sectorsCount = objsnum
      onClick = @(idx) params?.onClick?(idx)
      onDetach = params?.onDetach
      children = [back, activeSector, angle].extend(params?.children ?? []).extend(children)
    }
  }

  return pieMenu
}


local function mkPieMenuActivator(params = defParams){
  params = defParams.__merge(params)
  local hotkeys = params?.hotkeys
  local showPieMenu = params?.showPieMenu ?? Watched(hotkeys==null)
  local pieMenu = mkPieMenu(params)
  local eventHandlers = params?.eventHandlers
  if (::type(hotkeys)=="string")
    hotkeys = [[hotkeys, @() showPieMenu(!showPieMenu.value)]]

  return function() {
    return {
      hotkeys = hotkeys
      eventHandlers = eventHandlers
      children = showPieMenu.value ? pieMenu : null
      watch = showPieMenu
    }
  }
}

return mkPieMenuActivator
