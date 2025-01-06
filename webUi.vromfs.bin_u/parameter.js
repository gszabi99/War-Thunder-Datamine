//Parameter

//Unit systems

const degToRad = Math.PI / 180.0
const radToDeg = 1.0 / degToRad
const omegaToRpm = 60.0 / (2.0 * Math.PI)
const rpmToOmega = 1.0 / omegaToRpm

const AirspeedType = {
  IAS: 0,
  TAS: 1,
  MACH: 2
}

const cookieLifeTime = 60*60*24*1000

function timeToString(time)
{
  var sign = time > 0.0 ? '' : '-'
  time = Math.abs(time)
  var hh = Math.floor(time / 3600.0)
  time = time - hh * 3600
  var mm = Math.floor(time / 60.0)
  time = time - mm * 60
  var ss = Math.floor(time + 0.5)
  var str = sign
  if (hh > 0)
    str = str + (hh > 9 ? hh.toString() : '0' + hh.toString()) + ':'
  if (mm > 0)
    str = str + (mm > 9 ? mm.toString() : '0' + mm.toString()) + ':'
  str = str + (ss < 10 && mm > 0 ? '0' + ss.toString() : ss.toString())
  return str
}

const units = {

  ratio: {
    name: '%',
    coeff: 0.01
  },
  time: {
    name: 's',
    coeff: 1.0,
    valueToString: timeToString
  },
  deg: {
    name: 'deg',
    coeff: Math.PI / 180.0
  },
  dps: {
    name: 'deg/s',
    coeff: Math.PI / 180.0
  },
  loadFactor: {
    name: 'G',
    coeff: 1.0
  }, 
  
  km: {
    name: 'km',
    coeff: 0.001
  },
  ml: {
    name: 'ml',
    coeff: 1.0 / 1600.0
  },
  nm: {
    name: 'nm',
    coeff: 1.0 / 1850.0
  },
  
  m: {
    name: 'm',
    coeff: 1.0
  },
  ft: {
    name: 'ft',
    coeff: 1.0 / 3.28
  },
    
  kmph: {
    name: 'kmh',
    coeff: 1.0 / 3.6
  },
  mph: {
    name: 'mph',
    coeff: 1.0 / 2.237
  },
  kts: {
    name: 'kts',
    coeff: 1.0 / 3.6 * 1.852
  },
  
  mps: {
    name: 'mps',
    coeff: 1.0
  },
  fpm: {
    name: 'fpm',
    coeff: 1.0 / 3.28 / 60.0
  },
  
  kg: {
    name: 'kg',
    coeff: 1.0
  },
  lb: {
    name: 'lb',
    coeff: 0.45362
  },
  
  gphph: {
    name: 'g/hp/hour',
    coeff: 1000.0 * 746.0 * 3600.0
  },
  lbphph: {
    name: 'lb/hp/hour',
    coeff: 0.45362 * 746.0 * 3600.0
  },
  
  rpm: {
    name: 'rpm',
    coeff: (2 * Math.PI) / 60.0
  },
  
  atm: {
    name: 'atm',
    coeff: 101325
  },
  torr: {
    name: 'Torr',
    coeff: 101325 / 760.0
  },
  inHg: {
    name: 'inHg',
    coeff: 3386.3836
  },
  psi: {
    name: 'psi+',
    coeff: 101325.0 / 14.7,
    offset: -14.7
  },
  
  hp: {
    name: 'hp',
    coeff: 746
  },
  
  kgs: {
    name: 'kgs',
    coeff: 9.81,
  },
  lbs: {
    name: 'lbs',
    coeff: 0.45362 * 9.81
  },
  
  kgsm: {
    name: 'kgg*m',
    coeff: 9.81,
  },
  lbsf: {
    name: 'lbs*f',
    coeff: 0.45362 * 9.81 / 0.304
  },  
  
  celsius: {
    name: 'C',
    coeff: 1.0,
    offset: -273.16
  },
  farenheit: {
    name: 'F',
    coeff: 5.0 / 9.0,
    offset: -459.4
  }
}

const unitSystems = [
  {
    dist: units.km,
    altitude: units.m,
    velocity: units.kmph,
    verticalVelocity: units.mps,
    mass: units.kg,
    fuelConsumption: units.gphph,
    time: units.time,
    angle: units.deg,
    angularVelocity: units.dps,
    rotationVelocity: units.rpm,
    pressure: units.torr,
    ratio: units.ratio,
    loadFactor: units.loadFactor,
    time: units.time,
    power: units.hp,
    thrust: units.kgs,
    moment: units.kgsm,
    temperature: units.celsius
  },
  {
    dist: units.km,
    altitude: units.m,
    velocity: units.kmph,
    verticalVelocity: units.mps,
    mass: units.kg,
    fuelConsumption: units.gphph,
    time: units.time,
    angle: units.deg,
    angularVelocity: units.dps,
    rotationVelocity: units.rpm,
    pressure: units.torr,
    ratio: units.ratio,
    loadFactor: units.loadFactor,
    time: units.time,
    power: units.hp,
    thrust: units.kgs,
    moment: units.kgsm,
    temperature: units.celsius
  },
  {
    dist: units.km,
    altitude: units.m,
    velocity: units.kmph,
    verticalVelocity: units.mps,
    mass: units.kg,
    fuelConsumption: units.gphph,
    time: units.time,
    angle: units.deg,
    angularVelocity: units.dps,
    rotationVelocity: units.rpm,
    pressure: units.atm,
    ratio: units.ratio,
    loadFactor: units.loadFactor,
    time: units.time,
    power: units.hp,
    thrust: units.kgs,
    moment: units.kgsm,
    temperature: units.celsius
  },
  {
    dist: units.ml,
    altitude: units.ft,
    velocity: units.mph,
    verticalVelocity: units.fpm,
    mass: units.lb,
    fuelConsumption: units.lbphph,
    time: units.time,
    angle: units.deg,
    angularVelocity: units.dps,
    rotationVelocity: units.rpm,
    pressure: units.inHg,
    ratio: units.ratio,
    loadFactor: units.loadFactor,
    time: units.time,
    power: units.hp,
    thrust: units.lbs,
    moment: units.lbsf,
    temperature: units.farenheit
  },
  {
    dist: units.nm,
    altitude: units.ft,
    velocity: units.kts,
    verticalVelocity: units.fpm,
    mass: units.lb,
    fuelConsumption: units.lbphph,
    time: units.time,
    angle: units.deg,
    angularVelocity: units.dps,
    rotationVelocity: units.rpm,
    pressure: units.inHg,
    ratio: units.ratio,
    loadFactor: units.loadFactor,
    time: units.time,
    power: units.hp,
    thrust: units.lbs,
    moment: units.lbsf,
    temperature: units.farenheit
  },
  {
    dist: units.ml,
    altitude: units.ft,
    velocity: units.mph,
    verticalVelocity: units.fpm,
    mass: units.lb,
    fuelConsumption: units.lbphph,
    time: units.time,
    angle: units.deg,
    angularVelocity: units.dps,
    rotationVelocity: units.rpm,
    pressure: units.psi,
    ratio: units.ratio,
    loadFactor: units.loadFactor,
    time: units.time,
    power: units.hp,
    thrust: units.lbs,
    moment: units.lbsf,
    temperature: units.farenheit
  },
  {
    dist: units.nm,
    altitude: units.ft,
    velocity: units.kts,
    verticalVelocity: units.fpm,
    mass: units.lb,
    fuelConsumption: units.lbphph,
    time: units.time,
    angle: units.deg,
    angularVelocity: units.dps,
    rotationVelocity: units.rpm,
    pressure: units.psi,
    ratio: units.ratio,
    loadFactor: units.loadFactor,
    time: units.time,
    power: units.hp,
    thrust: units.lbs,
    moment: units.lbsf,
    temperature: units.farenheit
  }
]

const unitSystemVariants = [
  { name: 'Metric-Russian', value: 0 },
  { name: 'Metric-Japanise', value: 1 },
  { name: 'Metric-German', value: 2 },
  { name: 'Imperial-USA', value: 3 },
  { name: 'Imperial-USA-Naval', value: 4 },
  { name: 'Imperial-UK', value: 5 },
  { name: 'Imperial-UK-Naval', value: 6 }
]

function getUnitName(unit, unitSystemName)
{
  const unitData = unitSystems[unitSystemName][unit]
  return unitData != undefined ? unitData.name : ''
}

function convertToUnit(value, unit, unitSystemName)
{
  const unitData = unitSystems[unitSystemName][unit]
  return unitData != undefined ? value / unitData.coeff + (unitData.offset || 0.0) : value
}

function convertFromUnit(value, unit, unitSystemName)
{
  const unitData = unitSystems[unitSystemName][unit]
  return unitData != undefined ? (value - (unitData.offset || 0.0)) * unitData.coeff : value
}

function convertToString(value, unitData)
{
  if (unitData != undefined &&
      unitData.valueToString != undefined)
    return unitData.valueToString(value)
  else
    return value.toString()
}

//GUI element

function getControl(param)
{
  var control = document.getElementById(param.controlId)
  if (control == undefined)
    alert("Element \"" + param.controlId + "\" not found")
  return control
}

//Prepare

function prepareEnum(param)
{
  if (param.variants && param.variants.length > 0)
  {
    var control = getControl(param)
    control.options.length = 0
    for (var index in param.variants)
    {
      var variant = param.variants[index]
      control.options[control.options.length] = new Option(variant.name, variant.value)
    }
  }
}

function prepareParameter(param)
{
  if (param.type == 'enum')
    prepareEnum(param)
  else if (param.type == 'table')
    for (index in param.items)
      prepareParameter(param.items[index])
  else if (param.type == 'array')
    for (var i = 0; i < param.items.length; ++i)
      prepareParameter(param.items[i])
}

//Load
function loadNumber(param, unitSystemName)
{
  var control = getControl(param)
  const str = control.value
  param.value = convertFromUnit(parseFloat(str), param.unit, unitSystemName)
  if (param.min != undefined &&
      param.value < param.min)
  {
    param.value = param.min
    saveNumber(param, unitSystemName)
  }  
  if (param.max != undefined &&
      param.value > param.max)
  {
    param.value = param.max
    saveNumber(param, unitSystemName)
  }
}

function loadString(param)
{
  var control = getControl(param)
  const str = control.value
  param.value = str
}

function loadBool(param)
{
  var control = getControl(param)
  param.value = control.checked
}
   
function loadEnum(param)
{
  var control = getControl(param)
  const str = control.value
  param.value = parseInt(str)
}

function loadParameter(param, unitSystemName)
{
  if (param == undefined ||
      param.condition != undefined &&
      !param.condition())
    return false
  if (param.type == 'table')
    for (index in param.items)
      loadParameter(param.items[index], unitSystemName)
  else if (param.type == 'array')
    for (var i = 0; i < param.items.length; ++i)
      loadParameter(param.items[i], unitSystemName)
  else if (param.controlId != undefined)
  {
    if (param.type == 'number')
      loadNumber(param, unitSystemName)
    else if (param.type == 'string')  
      loadString(param)
    else if (param.type == 'bool')
      loadBool(param)
    else if (param.type == 'enum')
      loadEnum(param)
    if (param.handler != undefined)
      param.handler(param)
  }
  return true
}

function getParamValue(param, unitSystemName)
{
  return convertToUnit(param.value, param.unit, unitSystemName)
}

//Save
function saveNumber2(param, value, unitSystemName)
{
  var control = getControl(param)
  if (param.inactive || param.value == undefined)
  {
    if (param.readOnly) //label
      control.innerHTML = '-'
    else //edit
      control.value = '-'
  }
  else
  {
    var val = convertToUnit(value, param.unit, unitSystemName)
    if (val == undefined)
    {
      alert(param.unit)
      alert(value)
    }
    var precision = param.precision
    if (precision == undefined)
      precision = 0
    const unitData = unitSystems[unitSystemName][param.unit]
    var str = convertToString(val.toFixed(precision), unitData)
    if (param.readOnly) //label
      control.innerHTML = str
    else //edit
      control.value = str
  }
}

function saveNumber(param, unitSystemName)
{
  saveNumber2(param, param.value, unitSystemName)
}

function saveString(param)
{
  var control = getControl(param)
  if (param.readOnly) //label
    control.innerHTML = (param.inactive || param.value == undefined) ? '-' : param.value
  else //edit
    control.value = (param.inactive || param.value == undefined) ? '-' : param.value
}
  
function saveBool(param)
{
  var control = getControl(param)
  control.checked = (param.inactive || param.value == undefined) ? false : param.value
}

function saveEnum(param)
{
  var control = getControl(param)
  control.value = param.value != undefined ? param.value.toString() : undefined //combo-box
}

function saveParameter(param, unitSystemName, triggerOnChange)
{
  if (param.condition != undefined &&
      !param.condition())
    return
  if (param.type == 'table')
  {
    for (index in param.items)
      saveParameter(param.items[index], unitSystemName)
  }
  else if (param.type == 'array')
  {
    for (var i = 0; i < param.items.length; ++i)
      saveParameter(param.items[i], unitSystemName)
  }
  else if (param.controlId != undefined)
  {
    var control = getControl(param)
    if (control == undefined)
      alert(param.controlId)    
    control.disabled = param.disabled || param.inactive
    if (param.type == 'number')
      saveNumber(param, unitSystemName)
    else if (param.type == 'string')
      saveString(param)
    else if (param.type == 'bool')
      saveBool(param)
    else if (param.type == 'enum')
      saveEnum(param)
    if (triggerOnChange)
      control.onchange()
  }
}

//Range

function setNumberRange(param, minValue, maxValue, unitSystemName)
{
  if (param.type == 'number')
  {
    param.min = minValue || param.min
    param.max = maxValue || param.max
    document.getElementById(param.controlId).min = minValue
    document.getElementById(param.controlId).max = maxValue
    loadParameter(param, unitSystemName)
  }
}

//Active / inactive
function setParameterActive(param, active, unitSystemName)
{
  param.inactive = !active
  saveParameter(param, unitSystemName)
}

//Enable / disable
function setParameterEnabled(param, enabled, unitSystemName)
{
  param.disabled = !enabled
  saveParameter(param, unitSystemName)
}

//Navigation
function getParameterByPath(root, path)
{
  var tbl = root
  for (var i = 0; i < path.length - 1; ++i)
  {
    if (tbl == undefined ||
        tbl.items == undefined)
      return undefined
    //alert('path tbl ' + path[i])
    tbl = tbl.items[path[i]]
  }
  if (tbl != undefined)
  {
    //alert('path key ' + path[path.length - 1])
    return tbl.items[path[path.length - 1]]
  }
}

function parameterPathToString(path)
{
  var str = ''
  for (var i = 0; i < path.length; ++i)
    str = str + '.' + path[i]
  return str
}

//Serialization
function serializeParameterToJSON(param)
{
  if (param.type == 'table')
  {
    var data = {}
    for (var index in param.items)
      data[index] = serializeParameterToJSON(param.items[index])
    return data
  }
  else if (param.type == 'array')
  {
    var data = []
    for (var index = 0; index < param.items.length; ++index)
      data[index] = serializeParameterToJSON(param.items[index])
    return data  
  }
  else
    return param.value
}

function serializeParameterToCookie(param, pathStr)
{
  if (param.type == 'table')
  {
    for (index in param.items)
    {
      var newPathStr = (pathStr != undefined) ? pathStr + '.' + index.toString() : index.toString()
      serializeParameterToCookie(param.items[index], newPathStr)
    }
  }
  else if (param.type == 'array')
  {
    for (var i = 0; i < param.items.length; ++i)
    {
      var newPathStr = (pathStr != undefined) ? pathStr + '.' + i.toString() : i.toString()
      serializeParameterToCookie(param.items[i], newPathStr)
    }
  }
  else
  {
    Cookies.set(pathStr, param.value.toString(), { expires:cookieLifeTime })
  }
}

function serializeParameterToURLProc(param, pathStr, result)
{
  if (param.type == 'table')
  {
    for (var index in param.items)
    {
      var newPathStr = (pathStr != undefined) ? pathStr + '.' + index.toString() : index.toString()
      serializeParameterToURLProc(param.items[index], newPathStr, result)
    }
  }
  else if (param.type == 'array')
  {
    for (var i = 0; i < param.items.length; ++i)
    {
      var newPathStr = (pathStr != undefined) ? pathStr + '.' + i.toString() : i.toString()
      serializeParameterToURLProc(param.items[i], newPathStr, result)
    }
  }
  else
  {
    result[pathStr] = param.value.toString()
  }
}

function serializeParameterToURL(param, result)
{
  return serializeParameterToURLProc(param, undefined, result)
}

function deserializeParameterFromJSON(param, data)
{
  if (data instanceof Object)
  {
    if (param.items != undefined)
    {
      if (param.type == 'table')
      {
        for (var index in data)
        {
          var subParam = param.items[index]
          if (subParam != undefined)
            deserializeParameterFromJSON(subParam, data[index])
        }
      }
      else if (param.type == 'array')
      {
        for (var i = 0; i < data.length; ++i)
        {
          var subParam = param.items[i]
          if (subParam != undefined)
            deserializeParameterFromJSON(subParam, data[i])
        }
      }
    }
  }
  else
  {
    param['value'] = data
    if (param.handler != undefined)
      param.handler(param)
  }
}

function deserializeParameterFromCookie(param, pathStr)
{
  if (param.type == 'table')
  {
    for (index in param.items)
    {
      var newPathStr = (pathStr != undefined) ? pathStr + '.' + index.toString() : index.toString()
      deserializeParameterFromCookie(param.items[index], newPathStr)
    }
  }
  else if (param.type == 'array')
  {
    for (var i = 0; i < param.items.length; ++i)
    {
      var newPathStr = (pathStr != undefined) ? pathStr + '.' + i.toString() : i.toString()
      deserializeParameterFromCookie(param.items[i], newPathStr)
    }
  }
  else
  {
    const str = Cookies.get(pathStr)
    if (str != undefined)
    {
      if (param.type == 'number')
      {
        var value = parseFloat(str)
        if (!isNaN(value))
          param.value = value
      }
      else if (param.type == 'enum')
      {
        var value = parseInt(str)
        if (!isNaN(value))
          param.value = value
      }
      else if (param.type == 'bool')
        param.value = (str == 'true')
      else if (param.type == 'string')
        param.value = str
      if (param.handler != undefined)
        param.handler(param)
    }
  }
}

function compareWithJSON(param, srl)
{
  if (param.type == 'table')
  {
    for (var index in param.items)
      if (!compareWithJSON(param.items[index], srl[index]))
        return false
    return true
  }
  else if (param.type == 'array')
  {
    for (var index = 0; index < param.items.length; ++index)
      if (!compareWithJSON(param.items[index], srl[index]))
        return false
    return true
  }
  else
    return param.value == srl
}
