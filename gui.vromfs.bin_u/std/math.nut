local math = require("math")

const GOLDEN_RATIO = 1.618034

local function minByAbs(a, b) { return (math.fabs(a) < math.fabs(b))? a : b }
local function maxByAbs(a, b) { return (math.fabs(a) > math.fabs(b))? a : b }

//round @value to valueble @digits amount
// roundToDigits(1.23, 2) = 1.2
// roundToDigits(123, 2) = 120
local function roundToDigits(value, digits) {
  if (value==0) return value
  local log = math.log10(math.fabs(value))
  local mul = math.pow(10, math.floor(log)-digits+1)
  return mul*math.floor(0.5+value.tofloat()/mul)
}

//round @value by @roundValue
//round_by_value(1.56, 0.1) = 1.6
local function round_by_value(value, roundValue) {
  return math.floor(value.tofloat() / roundValue + 0.5) * roundValue
}


local function number_of_set_bits(i) {
  i = i - ((i >> 1) & (0x5555555555555555));
  i = (i & 0x3333333333333333) + ((i >> 2) & 0x3333333333333333);
  return (((i + (i >> 4)) & 0xF0F0F0F0F0F0F0F) * 0x101010101010101) >> 56;
}


local function is_bit_set(bitMask, bitIdx) {
  return (bitMask & 1 << bitIdx) > 0
}

local function change_bit(bitMask, bitIdx, value) {
  return (bitMask & ~(1 << bitIdx)) | (value? (1 << bitIdx) : 0)
}

local function change_bit_mask(bitMask, bitMaskToSet, value) {
  return (bitMask & ~bitMaskToSet) | (value? bitMaskToSet : 0)
}

/**
* Linear interpolation of f(value) where:
* f(valueMin) = resMin
* f(valueMax) = resMax
*/
local function lerp(valueMin, valueMax, resMin, resMax, value) {
  if (valueMin == valueMax)
    return 0.5 * (resMin + resMax)
  return resMin + (resMax - resMin) * (value - valueMin) / (valueMax - valueMin)
}

/*
* return columns amount for the table with <total> same size items
* with a closer table size to golden ratio
* <widthToHeight> is a item size ratio (width / height)
*/
local function calc_golden_ratio_columns(total, widthToHeight = 1.0) {
  local rows = (math.sqrt(total.tofloat() / GOLDEN_RATIO * widthToHeight) + 0.5).tointeger() || 1
  return math.ceil(total.tofloat() / rows).tointeger()
}
local function color2uint(r,g=0,b=0,a=255){
  if (::type(r)=="table") {
    r = r?.r ?? r
    g = r?.g ?? g
    b = r?.b ?? b
    a = r?.a ?? a
  }
  return ::clamp(r+g*256+b*65536+a*16777216, 0, 4294967295)
}

local romanNumeralLookup = [
  "","I","II","III","IV","V","VI","VII","VIII","IX",
  "","X","XX","XXX","XL","L","LX","LXX","LXXX","XC",
  "","C","CC","CCC","CD","D","DC","DCC","DCCC","CM"
]
local maxRomanDigit = 3

//Function from http://blog.stevenlevithan.com/archives/javascript-roman-numeral-converter
local function getRomanNumeral(num) {
  local t = typeof num
  if ((t != "integer" && t != "float") || num < 0)
    return ""

  num = num.tointeger()
  if (num >= 4000)
    return num.tostring()

  local thousands = []
  for (local n = 0; n < num / 1000; n++)
    thousands.append("M")

  local roman = []
  local i = -1
  while (num > 0 && i++ < maxRomanDigit) {
    local digit = num % 10
    num = num / 10
    roman.insert(0, romanNumeralLookup?[digit + (i * 10)])
  }
  return "".join(thousands.extend(roman).filter(@(v) v!=null))
}

//EXPORT content for require
local export = math.__merge({
  GOLDEN_RATIO = GOLDEN_RATIO
  minByAbs = minByAbs
  maxByAbs = maxByAbs
  round_by_value = round_by_value
  number_of_set_bits = number_of_set_bits
  roundToDigits = roundToDigits
  is_bit_set = is_bit_set
  change_bit = change_bit
  change_bit_mask = change_bit_mask
  lerp = lerp
  calc_golden_ratio_columns = calc_golden_ratio_columns
  color2uint = color2uint
  getRomanNumeral = getRomanNumeral
  calcPercent = @(value) (100.0 * value + 0.5).tointeger()
})

return export
