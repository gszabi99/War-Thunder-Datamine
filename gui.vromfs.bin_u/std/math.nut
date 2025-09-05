import "math" as math

const GOLDEN_RATIO = 1.618034

let minByAbs = @[pure](a, b) math.fabs(a) < math.fabs(b) ? a : b
let maxByAbs = @[pure](a, b) math.fabs(a) > math.fabs(b) ? a : b




function [pure] roundToDigits(value, digits) {
  if (value==0) return value
  let log = math.log10(math.fabs(value))
  let mul = math.pow(10, math.floor(log) - digits + 1)
  return mul * math.floor(0.5 + value.tofloat() / mul)
}



function [pure] round_by_value(value, roundValue) {
  return math.floor(value.tofloat() / roundValue + 0.5) * roundValue
}

function [pure] number_of_set_bits(i) {
  i = i - ((i >> 1) & (0x5555555555555555));
  i = (i & 0x3333333333333333) + ((i >> 2) & 0x3333333333333333);
  return (((i + (i >> 4)) & 0xF0F0F0F0F0F0F0F) * 0x101010101010101) >> 56;
}

function [pure] is_bit_set(bitMask, bitIdx) {
  return (bitMask & (1 << bitIdx)) != 0
}

function [pure] change_bit(bitMask, bitIdx, value) {
  return (bitMask & ~(1 << bitIdx)) | (value ? (1 << bitIdx) : 0)
}

function [pure] change_bit_mask(bitMask, bitMaskToSet, value) {
  return (bitMask & ~bitMaskToSet) | (value ? bitMaskToSet : 0)
}






function [pure] lerp(valueMin, valueMax, resMin, resMax, curValue) {
  if (valueMin == valueMax)
    return 0.5 * (resMin + resMax)
  return resMin + (resMax - resMin) * (curValue - valueMin) / (valueMax - valueMin)
}







let lerpClamped = @[pure](valueMin, valueMax, resMin, resMax, tvalue)
  lerp(valueMin, valueMax, resMin, resMax,
    valueMax > valueMin ? math.clamp(tvalue, valueMin, valueMax) : math.clamp(tvalue, valueMax, valueMin))

function interpolateArray(arr, value) {
  let maxIdx = arr.len() - 1
  foreach (idx, curElem in arr) {
    if (value <= curElem.x || idx == maxIdx)
      return curElem.y

    let nextElem = arr[idx + 1]
    if (value > nextElem.x)
      continue

    let valueMin = curElem.x
    let resMin = curElem.y
    let valueMax = nextElem.x
    let resMax = nextElem.y
    return lerp(valueMin, valueMax, resMin, resMax, value)
  }
  return 0
}






function calc_golden_ratio_columns(total, widthToHeight = 1.0) {
  let rows = (math.sqrt(total.tofloat() / GOLDEN_RATIO * widthToHeight) + 0.5).tointeger()
  return math.ceil(total.tofloat() / math.max(rows, 1)).tointeger()
}

let color2uint = @[pure](r, g, b, a = 255) math.clamp(r + g * 256 + b * 65536 + a * 16777216, 0, 4294967295)

let romanNumeralLookup = [
  "","I","II","III","IV","V","VI","VII","VIII","IX",
  "","X","XX","XXX","XL","L","LX","LXX","LXXX","XC",
  "","C","CC","CCC","CD","D","DC","DCC","DCCC","CM"
]
let maxRomanDigit = 3


function getRomanNumeral(num) {
  let t = type(num)
  if ((t != "integer" && t != "float") || num < 0)
    return ""

  num = num.tointeger()
  if (num >= 4000)
    return num.tostring()

  let thousands = []
  for (local n = 0; n < num / 1000; n++)
    thousands.append("M")

  let roman = []
  local i = -1
  while (num > 0 && i++ < maxRomanDigit) {
    let digit = num % 10
    num = num / 10
    roman.insert(0, romanNumeralLookup?[digit + (i * 10)])
  }
  return "".join(thousands.extend(roman).filter(@(v) v!=null))
}

function splitThousands(val, spacer = " ") {
  val = val.tostring()
  local res = val.slice(-3)
  while (val.len() > 3) {
    val = val.slice(0, -3)
    res = $"{val.slice(-3)}{spacer}{res}"
  }
  return res
}






function average(list) {
  let n = list.len()
  return n == 0 ? null
    : list.reduce(@(sum, v) sum + v, 0.0) / n
}






function median(sortedList) {
  let n = sortedList.len()
  return n == 0 ? null
    : (n % 2 == 1) ? (sortedList[(n - 1) / 2] * 1.0)
    : (sortedList[(n / 2) - 1] + sortedList[n / 2]) / 2.0
}

function truncateToMultiple(number, multiple) {
  if (multiple == 0)
    return -1
  return math.floor(number / multiple) * multiple
}


let export = math.__merge({
  GOLDEN_RATIO
  minByAbs
  maxByAbs
  round_by_value
  number_of_set_bits
  roundToDigits
  is_bit_set
  change_bit
  change_bit_mask
  lerp
  lerpClamped
  interpolateArray
  calc_golden_ratio_columns
  color2uint
  getRomanNumeral
  splitThousands
  calcPercent = @[pure](value) (100.0 * value + 0.5).tointeger()
  average
  median
  truncateToMultiple
})

return freeze(export)
