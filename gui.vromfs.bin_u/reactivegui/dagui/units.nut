



from "daRg" import sw, sh
from "math" import floor
from "string" import format
import "%appGlobals/style/cssConsts.nut" as cssConsts
from "%rGui/style/screenState.nut" import safeAreaMenu
from "%rGui/style/fontsState.nut" import fontSizePx



let preInclude = {
  scrn_tgt = $"{fontSizePx.get()}"
  isWide = "(((10(sw + 1)) \\ (16@scrn_tgt))) $min 1"
  pf_outdated = "800"
  sf = "@scrn_tgt"
  pf = "1080"
  fontHeightNormal = "22"
  _safearea_menu_w = format("%.2f", safeAreaMenu.get()[0])
  _safearea_menu_h = format("%.2f", safeAreaMenu.get()[1])
  _safearea_hud_w = "1.0"
  _safearea_hud_h = "1.0"
  isInVr = "0"
}

const OP_NONE = -1
const OP_MIN = 0
const OP_MAX = 1
const OP_PLUS = 10
const OP_PERCENT = 20
const OP_MUL = 30
const OP_DIV = 31
const OP_DIV_FLOOR = 32

let tier = @(op) op / 10

function doOp(a, b, op) {
  if (op == OP_PLUS) return a + b
  if (op == OP_MUL) return a * b
  if (op == OP_DIV) return a / b
  if (op == OP_DIV_FLOOR) return floor(a / b)
  if (op == OP_PERCENT) return a / 100.0 * b
  if (op == OP_MIN) return a < b ? a : b
  if (op == OP_MAX) return a > b ? a : b
  return a
}


function constText(name) {
  let v = (name in preInclude) ? preInclude[name] : (name in cssConsts ? cssConsts[name] : null)
  return type(v) == "string" ? v : null
}

function isDigit(c) {
  return c >= '0' && c <= '9'
}

function isNameChar(c) {
  return isDigit(c) || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}


function parseExpr(str, start, mulSignIn, objUnits = null) {
  local mulSign = mulSignIn
  let vars = [0.0, 0.0, 0.0]
  local varInd = 0
  let ops = [OP_NONE, OP_NONE]
  local waitNextDigit = false
  local i = start
  let len = str.len()

  let pushVar = function(v) {
    vars[varInd] = v
    varInd++
  }
  let setOp = function(op) {
    if (varInd > 0)
      ops[ops[0] == OP_NONE ? 0 : 1] = op
  }

  while (i < len) {
    let c = str[i]
    if (c == '(') {
      let [v, next] = parseExpr(str, i + 1, mulSign, objUnits)
      pushVar(v)
      mulSign = 1.0
      i = next
    }
    else if (c == ')')
      break
    else if (isDigit(c)) {
      if (!waitNextDigit) {
        local e = i
        while (e < len && (isDigit(str[e]) || str[e] == '.'))
          e++
        pushVar(str.slice(i, e).tofloat() * mulSign)
        mulSign = 1.0
        waitNextDigit = true
      }
    }
    else {
      waitNextDigit = false
      if (c == '.')
        waitNextDigit = true
      else if (c == '+')
        setOp(OP_PLUS)
      else if (c == '-') {
        mulSign *= -1.0
        setOp(OP_PLUS)
      }
      else if (c == '*')
        setOp(OP_MUL)
      else if (c == '/')
        setOp(OP_DIV)
      else if (c == '\\')
        setOp(OP_DIV_FLOOR)
      else if (c == '%') {
        if (varInd > 0) {
          setOp(OP_PERCENT)
          pushVar(1.0)
        }
      }
      else if (c == '$' && varInd > 0 && str.slice(i, i + 5) == "$max ") {
        setOp(OP_MAX)
        i += 4
      }
      else if (c == '$' && varInd > 0 && str.slice(i, i + 5) == "$min ") {
        setOp(OP_MIN)
        i += 4
      }
      else if (str.slice(i, i + 2) == "px")
        i += 1
      else if (str.slice(i, i + 2) == "sw") {
        i += 1
        pushVar(sw(100) * mulSign)
        mulSign = 1.0
      }
      else if (str.slice(i, i + 2) == "sh") {
        i += 1
        pushVar(sh(100) * mulSign)
        mulSign = 1.0
      }
      else if (objUnits != null && (str.slice(i, i + 2) == "pw" || str.slice(i, i + 2) == "ph")) {
        pushVar(objUnits[str.slice(i, i + 2)] * mulSign)
        mulSign = 1.0
        i += 1
      }
      else if (objUnits != null && (c == 'w' || c == 'h')) {
        pushVar(objUnits[c == 'w' ? "w" : "h"] * mulSign)
        mulSign = 1.0
      }
      else if (c == '@') {
        local e = i + 1
        while (e < len && isNameChar(str[e]))
          e++
        let name = str.slice(i + 1, e)
        let value = constText(name)
        if (value == null)
          throw $"units: unknown constant @{name}"
        pushVar(parseExpr(value, 0, mulSign, objUnits)[0])
        mulSign = 1.0
        i = e - 1
      }
      else if (c == ',' || c == ':' || c == ';' || c == ' ' || c == '\t') {
      }
      else
        throw $"units: object unit or bad token at '{str.slice(i)}'"
    }
    if (ops[0] == OP_NONE && varInd > 1)
      ops[0] = OP_MUL
    if (ops[1] == OP_NONE && varInd > 2)
      ops[1] = OP_MUL
    if (ops[1] != OP_NONE && varInd > 2) {
      if (tier(ops[1]) > tier(ops[0]))
        vars[1] = doOp(vars[1], vars[2], ops[1])
      else {
        vars[0] = doOp(vars[0], vars[1], ops[0])
        vars[1] = vars[2]
        ops[0] = ops[1]
      }
      ops[1] = OP_NONE
      vars[2] = 0.0
      varInd = 2
    }
    i++
  }
  return [ops[0] == OP_NONE ? vars[0] : doOp(vars[0], vars[1], ops[0]), i]
}

let roundPx = @[pure, nodiscard] (v) floor(v + 0.5).tointeger()


function px(expr) {
  return roundPx(parseExpr(expr, 0, 1.0)[0])
}


function objPx(expr, units) {
  return roundPx(parseExpr(expr, 0, 1.0, units)[0])
}

let valueCache = {}


function cssConst(name) {
  if (name not in valueCache)
    valueCache[name] <- px($"@{name}")
  return valueCache[name]
}

return freeze({ px, objPx, cssConst, constText, roundPx })
