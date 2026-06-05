module mfdZ19_common shared

require %gameLibs.das.math.base

require DagorMath
require Plane

let shared
  COLOR_GREEN  = E3DCOLOR(0xFF00FF00)
  COLOR_YELLOW = E3DCOLOR(0xFFFFFF00)
  COLOR_NULL   = E3DCOLOR(0x00000000)
  COLOR_BLACK  = E3DCOLOR(0xFF000000)
  COLOR_WHITE  = E3DCOLOR(0xFFFFFFFF)
  COLOR_RED    = E3DCOLOR(0xFFFF3300)
  COLOR_SKY    = E3DCOLOR(uint4(10, 105, 180, 255))
  COLOR_GROUND = E3DCOLOR(uint4(110, 60, 40, 255))


struct EngineData
  turbineRpmRel  : float = 0.0
  torqueRel      : float = 0.0
  turbineTemp    : float = 0.0
  turbineTempMax : float[3]
  oilPresRel     : float = 0.0
  oilLvlRel      : float = 0.0
  fuelPresRel    : float = 0.0
  oilTemp        : float = 0.0
  oilTempMax     : float[3]


struct RotorData
  nr : float = 0.0


def get_engine_data(var propulsion : Propulsion?; n : int) : EngineData
  var eng = EngineData()
  *propulsion |> propulsion_getEngine(n) <| $(e)
    eng.turbineRpmRel = e.omegaRel * 100.0
    eng.torqueRel = safediv(e.engineMoment, e.props.engineMomentMax) * 100.0
    eng.turbineTemp = e.waterTemp + ZERO_KELVIN_IN_CELSIUM
    for i in 0 .. eng.turbineTempMax.length()
      eng.turbineTempMax[i] = engine_getLoadTemperature(e.thermodynamicProps, EngineThermodynamicsContour.CONTOUR_COOLANT, i + 1) + ZERO_KELVIN_IN_CELSIUM
    eng.oilPresRel = e.oilPressure
    eng.oilLvlRel = e.oilLevel * 100.0
    eng.fuelPresRel = e.fuelConsumption * 3600.0 / e.fuelConsumptionMax
    eng.oilTemp = e.oilTemp + ZERO_KELVIN_IN_CELSIUM
    for i in 0 .. eng.oilTempMax.length()
      eng.oilTempMax[i] = engine_getLoadTemperature(e.thermodynamicProps, EngineThermodynamicsContour.CONTOUR_OIL, i + 1) + ZERO_KELVIN_IN_CELSIUM
  return eng


def get_rotor_data(var propulsion : Propulsion?; n : int) : RotorData
  var rotor = RotorData()
  *propulsion |> propulsion_getPropeller(n) <| $(p)
    rotor.nr = p.state.omega * (60.0 / TWOPI)
  return rotor
