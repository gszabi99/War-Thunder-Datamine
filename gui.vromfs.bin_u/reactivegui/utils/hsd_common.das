module hsd_common shared public

require DagorMath
require darg
require math
require Unit

enum AzimuthScaleType
  GATES = 0
  LINES
  DOTS

enum CenterMarkType
  CROSS = 0
  PLANE
  CIRCLE
  HELI
  TRIANGLE

enum Orient
  HDG_UP = 0
  NORTH_UP

struct HsdProps
  color                     : E3DCOLOR
  fontId                    : int
  fontSize                  : int
  lineWidth                 : float
  lineColor                 : E3DCOLOR
  orient                    : int
  centerMarkType            : int
  centerMarkLineColor       : E3DCOLOR
  centerMarkFillColor       : E3DCOLOR
  centerMarkScale           : float
  centerMarkSpeed           : bool
  spi                       : bool
  spiColor                  : E3DCOLOR
  spiInfo                   : bool
  spiInfoOffset             : float
  distScale                 : bool
  distScaleBeyondAzScale    : bool
  distScaleStepSize         : float
  distScaleColor            : E3DCOLOR
  distScaleNumbers          : bool
  distScaleNumbersAngle     : float
  distScaleNumbersFillColor : E3DCOLOR
  azScaleType               : int
  azScaleSize               : float
  azScaleColor              : E3DCOLOR
  headingIndFillColor       : E3DCOLOR
  centerCross               : bool
  time                      : bool
  mapBackground             : bool
  markers                   : bool
  extent                    : float
  metricUnits               : bool

def hsd_world_to_screen(worldPos : float3& const; props : HsdProps const? const; hero : Unit const? const) : float2
  let dir = worldPos.xz - hero.pos.xz
  let forward = fast_normalize(hero.unitTm[0].xz)
  var relPos : float2
  if props.orient == int(Orient.HDG_UP)
    relPos = float2(dot(dir, float2(-forward.y, forward.x)), dot(dir, forward))
  elif props.orient == int(Orient.NORTH_UP)
    relPos = dir * float2(-1.0, 1.0)
  return -relPos / float2(props.extent)

def hsd_load_props(props : Properties&; var hsd_props : HsdProps&)
  hsd_props.color                     = props.getColor("color", E3DCOLOR(0xFFFFFFFF))
  hsd_props.fontId                    = props.getInt("fontId", 0)
  hsd_props.fontSize                  = props.getInt("fontSize", 10)
  hsd_props.lineWidth                 = props.getFloat("lineWidth", 1.0)
  hsd_props.lineColor                 = props.getColor("lineColor", E3DCOLOR(0xFFFFFFFF))
  hsd_props.orient                    = props.getInt("orient", 0)
  hsd_props.centerMarkType            = props.getInt("centerMarkType", 0)
  hsd_props.centerMarkFillColor       = props.getColor("centerMarkFillColor", E3DCOLOR(0xFFFFFFFF))
  hsd_props.centerMarkLineColor       = props.getColor("centerMarkLineColor", E3DCOLOR(0xFFFFFFFF))
  hsd_props.centerMarkScale           = props.getFloat("centerMarkScale", 0.1)
  hsd_props.centerMarkSpeed           = props.getBool("centerMarkSpeed", true)
  hsd_props.spi                       = props.getBool("spi", true)
  hsd_props.spiColor                  = props.getColor("spiColor", E3DCOLOR(0xFFFFFFFF))
  hsd_props.spiInfo                   = props.getBool("spiInfo", true)
  hsd_props.spiInfoOffset             = props.getFloat("spiInfoOffset", 0.0)
  hsd_props.distScale                 = props.getBool("distScale", true)
  hsd_props.distScaleBeyondAzScale    = props.getBool("distScaleBeyondAzScale", true)
  hsd_props.distScaleStepSize         = props.getFloat("distScaleStepSize", 5000.0)
  hsd_props.distScaleColor            = props.getColor("distScaleColor", E3DCOLOR(0xFFFFFFFF))
  hsd_props.distScaleNumbers          = props.getBool("distScaleNumbers", true)
  hsd_props.distScaleNumbersAngle     = props.getFloat("distScaleNumbersAngle", 45.0)
  hsd_props.distScaleNumbersFillColor = props.getColor("distScaleNumbersFillColor", E3DCOLOR(0xFFFFFFFF))
  hsd_props.azScaleType               = props.getInt("azScaleType", 0)
  hsd_props.azScaleSize               = props.getFloat("azScaleSize", 10000.0)
  hsd_props.azScaleColor              = props.getColor("azScaleColor", E3DCOLOR(0xFFFFFFFF))
  hsd_props.headingIndFillColor       = props.getColor("headingIndFillColor", E3DCOLOR(0xFFFFFFFF))
  hsd_props.centerCross               = props.getBool("centerCross", true)
  hsd_props.time                      = props.getBool("time", true)
  hsd_props.mapBackground             = props.getBool("mapBackground", true)
  hsd_props.markers                   = props.getBool("markers", true)
  hsd_props.extent                    = props.getFloat("extent", 20000.0)
  hsd_props.metricUnits               = props.getBool("metricUnits", false)
