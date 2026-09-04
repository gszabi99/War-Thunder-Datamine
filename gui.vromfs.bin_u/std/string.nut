from "string" import regexp, format
from "iostream" import blob
from "math" import clamp, log10, min
from "types" import Table, Array, String, Function, Integer, Float
import "string" as string

let utf8 = require_optional("utf8")


const CASE_PAIR_LOWER = "abcdefghijklmnopqrstuvwxyzàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿāăąćĉċčďđēĕėęěĝğġģĥħĩīĭįıĳĵķĺļľŀłńņňŋōŏőœŕŗřśŝşšţťŧũūŭůűųŵŷźżžƃƅƈƌƒƙơƣƥƨƭưƴƶƹƽǆǉǌǎǐǒǔǖǘǚǜǟǡǣǥǧǩǫǭǯǳǵǻǽǿȁȃȅȇȉȋȍȏȑȓȕȗɓɔɗɘəɛɠɣɨɩɯɲɵʃʈʊʋʒάέήίαβγδεζηθικλμνξοπρσςτυφχψωϊϋόύώϣϥϧϩϫϭϯабвгдежзийклмнопрстуфхцчшщъыьэюяёђѓєѕіїјљњћќўџѡѣѥѧѩѫѭѯѱѳѵѷѹѻѽѿҁґғҕҗҙқҝҟҡңҥҧҩҫҭүұҳҵҷҹһҽҿӂӄӈӌӑӓӕӗәӛӝӟӡӣӥӧөӫӯӱӳӵӹաբգդեզէըթժիլխծկհձղճմյնշոչպջռսվտրցւփքօֆაბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰჱჲჳჴჵḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡḣḥḧḩḫḭḯḱḳḵḷḹḻḽḿṁṃṅṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩṫṭṯṱṳṵṷṹṻṽṿẁẃẅẇẉẋẍẏẑẓẕạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹἀἁἂἃἄἅἆἇἐἑἒἓἔἕἠἡἢἣἤἥἦἧἰἱἲἳἴἵἶἷὀὁὂὃὄὅὑὓὕὗὠὡὢὣὤὥὦὧᾀᾁᾂᾃᾄᾅᾆᾇᾐᾑᾒᾓᾔᾕᾖᾗᾠᾡᾢᾣᾤᾥᾦᾧᾰᾱῐῑῠῡⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ"
const CASE_PAIR_UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮIĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŹŻŽƂƄƇƋƑƘƠƢƤƧƬƯƳƵƸƼǄǇǊǍǏǑǓǕǗǙǛǞǠǢǤǦǨǪǬǮǱǴǺǼǾȀȂȄȆȈȊȌȎȐȒȔȖƁƆƊƎƏƐƓƔƗƖƜƝƟƩƮƱƲƷΆΈΉΊΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΣΤΥΦΧΨΩΪΫΌΎΏϢϤϦϨϪϬϮАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯЁЂЃЄЅІЇЈЉЊЋЌЎЏѠѢѤѦѨѪѬѮѰѲѴѶѸѺѼѾҀҐҒҔҖҘҚҜҞҠҢҤҦҨҪҬҮҰҲҴҶҸҺҼҾӁӃӇӋӐӒӔӖӘӚӜӞӠӢӤӦӨӪӮӰӲӴӸԱԲԳԴԵԶԷԸԹԺԻԼԽԾԿՀՁՂՃՄՅՆՇՈՉՊՋՌՍՎՏՐՑՒՓՔՕՖႠႡႢႣႤႥႦႧႨႩႪႫႬႭႮႯႰႱႲႳႴႵႶႷႸႹႺႻႼႽႾႿჀჁჂჃჄჅḀḂḄḆḈḊḌḎḐḒḔḖḘḚḜḞḠḢḤḦḨḪḬḮḰḲḴḶḸḺḼḾṀṂṄṆṈṊṌṎṐṒṔṖṘṚṜṞṠṢṤṦṨṪṬṮṰṲṴṶṸṺṼṾẀẂẄẆẈẊẌẎẐẒẔẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸἈἉἊἋἌἍἎἏἘἙἚἛἜἝἨἩἪἫἬἭἮἯἸἹἺἻἼἽἾἿὈὉὊὋὌὍὙὛὝὟὨὩὪὫὬὭὮὯᾈᾉᾊᾋᾌᾍᾎᾏᾘᾙᾚᾛᾜᾝᾞᾟᾨᾩᾪᾫᾬᾭᾮᾯᾸᾹῘῙῨῩⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ"
local INVALID_INDEX = -1










function implode(pieces: array = [], glue: string = ""): string {
  return glue.join(pieces, true)
}











function join(pieces: array, glue: string = ""): string {
  return glue.join(pieces)
}










function split(joined: string, glue: string, isIgnoreEmpty = false): array {
  return (!isIgnoreEmpty) ? joined.split(glue)
            : joined.split(glue).filter(@(v) v!="")
}

const intre = @"^-?\d+$"
const floatre = @"^-?\d+\.?\d*([eE][-+]?\d{1,3})?$"
const notstringre = @"(^-?\d+$)|(^-?\d+\.?\d*([eE][-+]?\d{1,3})?$)|^(null|true|false)$"
let intRegExp = regexp(intre)
let possibleNotStrRegExp = regexp(notstringre)
let floatRegExp = regexp(floatre)
let stripTagsConfig = [
  { from = "~",  repl = "~~"  }
  { from = "\"", repl = "~\"" }
  { from = "\r", repl = "~r"  }
  { from = "\n", repl = "~n"  }
  { from = "\'", repl = "~\'" }
]
let escapeConfig = [
  { from = "\\", repl = "\\\\" }
  { from = "\"", repl = "\\\"" }
  { from = "\n", repl = "\\n"  }
  { from = "\r", repl = "\\r"  }
]
for (local ch = 0; ch < 32; ch++)
  escapeConfig.append({
    from = ch.tochar()
    repl = format("\\u%04X", ch)
  })

function [pure] isStringObviousString(str: string): bool {
  return !possibleNotStrRegExp.match(str)
}

const defTostringParams = {
  maxdeeplevel = 4
  compact=true
  tostringfunc= {
    compare=@(_val) false
    tostring=@(val) val.tostring()
  }
  separator = " "
  indentOnNewline = "  "
  newline="\n"
  splitlines = true
  showArrIdx=false
}

function func2str_compact(func): string {
  local { native, name } = func.getfuncinfos()
  return native ? $"(nativefunc): {name}"
    : name.slice(0,1) == "(" ? "@()" : $"{name}()"
}

function func2str(func, p: table|null = const {}): string {
  local compact = p?.compact ?? false
  local showsrc = p?.showsrc ?? false
  local showparams = p?.showparams ?? !compact
  local showdefparams = p?.showdefparams ?? compact
  local tostr_func = p?.tostr_func ?? @(v) $"{v}"

  local out = []
  local info = func.getfuncinfos()

  if (!info.native) {
    local defparams = info?.defparams ?? []
    local params = info.parameters.slice(1)
    if (info.varargs) {
      if (params.len()>0 && params.top()=="...")
        params=params.slice(0,-2)
      params.append("...")
    }
    local reqparams = params.slice(0, params.len() - defparams.len())
    local optparams = params.slice(reqparams.len())
    local params_str = []
    if (params.len()>0) {
      if (reqparams.len()>0)
        params_str.append(", ".join(reqparams))
      if (optparams.len()>0) {
        foreach (i, op in optparams) {
          params_str.append(op)
          if (showdefparams)
            params_str.append(" = ", tostr_func(defparams?[i] ?? ""))
          if (i+1 < optparams.len())
            params_str.append(", ")
        }
      }
    }
    local fname = $"{info.name}"
    if (fname.slice(0,1)=="(")
      fname = "@"
    if (showsrc)
      out.append("(func): ", (info?.src ?? ""), " ")
    out.append(fname, "(")
    if (showparams)
      out.extend(params_str)
    out.append(")")
  } else if (info.native) {
    out.append("(nativefunc): ", info.name)

  } else {
    out.append(func.tostring())
  }
  return "".join(out)
}

let simple_types = ["string", "float", "bool", "integer", "null", "userdata", "thread"]
  .reduce(@(res, v) res.$rawset(v, true), {})
let function_types = ["function", "generator"]
  .reduce(@(res, v) res.$rawset(v, true), {})

function tostring_any(input, tostringfunc=null, compact=true) {
  local typ = type(input)
  if (tostringfunc!=null) {
    if (tostringfunc instanceof Table)
      tostringfunc = [tostringfunc]
    if (tostringfunc instanceof Array) {
      foreach (tf in tostringfunc){
        if (tf?.compare != null && tf.compare(input)){
          return tf.tostring(input)
        }
      }
    }
  }
  else if (typ in function_types){
    return compact ? func2str_compact(input) : func2str(input, { compact })
  }
  else if (typ == "string"){
    if (input=="")
      return "\"\""
    if (!compact || !isStringObviousString(input))
      return $"\"{input}\""
    return input
  }
  else if (typ == "null"){
    return "null"
  }
  else if (typ == "float"){
    local r = input.tostring()
    if (compact || input != input.tointeger().tofloat())
      return r
    return r.contains(".") || r.contains("e") ? r : $"{r}.0"
  }
  else if (typ=="instance"){
    return $"\"{input.tostring()}\""
  }
  else if (typ == "userdata"){
    return "#USERDATA#"
  }
  else if (typ == "weakref"){
    return "#WEAKREF#"
  }
  if (typ=="thread") {
    return $"thread: {input.getstatus()}"
  }
  return input.tostring()
}

let table_types = ["table","class","instance"]
  .reduce(@(res, v) res.$rawset(v, true), {})

const openSymByType = {
  ["array"] = "[",
  ["class"] = "class {",
  ["instance"] = "instance {",
}

let openSym = @(value) openSymByType?[type(value)] ?? "{"
let closeSym = @(value) value instanceof Array ? "]" : "}"

function tostring_r(inp, params=defTostringParams): string {
  local newline = params?.newline ?? defTostringParams.newline
  local maxdeeplevel = params?.maxdeeplevel ?? defTostringParams.maxdeeplevel
  local separator = params?.separator ?? defTostringParams.separator
  local showArrIdx = params?.showArrIdx ?? defTostringParams.showArrIdx
  local tostringfunc = params?.tostringfunc
  local indentOnNewline = params?.indentOnNewline ?? defTostringParams.indentOnNewline
  local splitlines = params?.splitlines ?? defTostringParams.splitlines
  local compact = params?.compact ?? defTostringParams.compact

  function tostringLeaf(val) {
    local typ = type(val)
    if (tostringfunc!=null) {
      if (tostringfunc instanceof Table)
        tostringfunc = [tostringfunc]
      foreach (tf in tostringfunc)
        if (tf.compare(val))
          return [true, tf.tostring(val)]
    }

    if (typ in simple_types || typ in function_types)
      return [true, tostring_any(val, null, compact)]
    if (typ == "table" && val.$len() == 0)
      return const [true, "{}"]
    if (typ == "array" && val.len() == 0)
      return const [true, "[]"]
    if (typ == "instance") {
      let str = val?.tostring instanceof Function ? val.tostring() : null
      return [str != null && str.indexof("(instance : 0x") != 0, str]
    }
    return const [false, null]
  }

  local arrSep = separator
  if (!splitlines) {
    newline = " "
    indentOnNewline = ""
  }
  let stream = blob()
  function write_to_string(input, indent, curdeeplevel, arrayElem = false, sep = newline, arrInd=null) {
    if (arrInd==null)
      arrInd=indent
    local li = 0
    local maxind = -1
    try {
      if (input?.len instanceof Function) {
        let info = input.len.getfuncinfos()
        if (!info.native && info.parameters.len()==1)
          maxind = input.len()-1
        else if (info.native && info.typecheck.len()==1 && (info.typecheck[0]==32|| info.typecheck[0]==64)) 
          maxind = input.len()-1
      }
    }
    catch(e){}
    foreach (key, value in input) {
      local typ = type(value)
      local isArray = typ=="array"
      let [isProcessed, resultStr] = tostringLeaf(value)
      if (isProcessed) {
        if (!arrayElem) {
          stream.writestring(sep)
          stream.writestring(indent)
          stream.writestring(tostring_any(key, null, compact))
          stream.writestring(" = ")
        }
        stream.writestring(resultStr)
        if (arrayElem && li != maxind)
          stream.writestring(sep)
      }
      else if (maxdeeplevel != null && curdeeplevel == maxdeeplevel) {
        local brOp = openSym(value)
        local brCl = closeSym(value)
        if (!arrayElem) {
          stream.writestring(newline)
          stream.writestring(indent)
          stream.writestring(tostring_any(key, null, compact))
          stream.writestring(" = ")
        }
        else if (arrayElem && showArrIdx) {
          stream.writestring(tostring_any(key, null, compact))
          stream.writestring(" = ")
        }
        stream.writestring(brOp)
        stream.writestring("...")
        stream.writestring(brCl)
      }
      else if (isArray && !showArrIdx) {
        if (!arrayElem) {
          stream.writestring(newline)
          stream.writestring(indent)
          stream.writestring(tostring_any(key, null, compact))
          stream.writestring(" = ")
        }
        stream.writestring("[")
        write_to_string(value, $"{indent}{indentOnNewline}", curdeeplevel+1, true, arrSep, indent) 
        stream.writestring("]")
        if (arrayElem && li!=maxind)
          stream.writestring(sep)
      }
      else if (typ in table_types || (isArray && showArrIdx )) {
        local brOp = openSym(value)
        local brCl = closeSym(value)
        stream.writestring(newline)
        stream.writestring(indent)
        if (!arrayElem) {
          stream.writestring(tostring_any(key,null, compact))
          stream.writestring(" = ")
        }
        stream.writestring(brOp)
        write_to_string(value, $"{indent}{indentOnNewline}", curdeeplevel+1)
        stream.writestring(newline)
        stream.writestring(indent)
        stream.writestring(brCl)
        if (arrayElem && li==maxind ){
          stream.writestring(newline)
          stream.writestring(arrInd)
        }
        else if (arrayElem && li < maxind && !(input[li+1] instanceof Table)){
          stream.writestring(newline)
          stream.writestring(indent)
        }
      }
      li += 1
    }
  }
  write_to_string([inp], "", 0,true)
  return stream.as_string()
}












function slice(str, start = 0, end = null) {
  str = str ?? ""
  return str.slice(start, end ?? str.len())
}












function substring(str, start = 0, length = null) {
  local end = length
  if (length != null && length >= 0) {
    str = str ?? ""
    local total = str.len()
    if (start < 0)
      start += total
    start = clamp(start, 0, total)
    end = start + length
  }
  return slice(str, start, end)
}








function startsWith(str, value): bool {
  str = str ?? ""
  value = value ?? ""
  return str.startswith(value)
}








function endsWith(str, value): bool {
  str = str ?? ""
  value = value ?? ""
  return str.endswith(value)
}









function indexOf(str, value, startIndex = 0) {
  str = str ?? ""
  value = value ?? ""
  if (value == "")
    return clamp(startIndex, 0, str.len())
  local idx = str.indexof(value, startIndex)
  return idx ?? INVALID_INDEX
}









function lastIndexOf(str, value, startIndex = 0): int {
  str = str ?? ""
  value = value ?? ""
  if (value == "")
    return str.len()
  local idx = INVALID_INDEX
  local curIdx = startIndex - 1
  local length = str.len()
  while (curIdx < length - 1) {
    curIdx = str.indexof(value, curIdx + 1)
    if (curIdx == null)
      break
    idx = curIdx
  }
  return idx
}









function indexOfAny(str, anyOf, startIndex = 0) {
  str = str ?? ""
  anyOf = anyOf ?? []
  local idx = INVALID_INDEX
  foreach (value in anyOf) {
    if (value == null || value == "")
      continue
    local curIdx = indexOf(str, value, startIndex)
    if (curIdx != INVALID_INDEX && (idx == INVALID_INDEX || curIdx < idx))
      idx = curIdx
  }
  return idx
}









function lastIndexOfAny(str, anyOf, startIndex = 0): int {
  str = str ?? ""
  anyOf = anyOf ?? []
  local idx = INVALID_INDEX
  foreach (value in anyOf) {
    if (value == null || value == "")
      continue
    local curIdx = lastIndexOf(str, value, startIndex)
    if (curIdx != INVALID_INDEX && (idx == INVALID_INDEX || curIdx > idx))
      idx = curIdx
  }
  return idx
}


function countSubstrings(str: string, substr: string): int {
  local res = 0
  local findex = str.indexof(substr)
  while (findex != null) {
    res++
    findex = str.indexof(substr, findex + 1)
  }
  return res
}

function capitalize(str: string): string {
  return "".concat(str.slice(0, 1).toupper(), str.slice(1))
}

function replace(str, from: string, to: string): string {
  return (str ?? "").replace(from, to)
}







function trim(str): string {
  str = str ?? ""
  return str.strip()
}

















function [pure] floatToStringRounded(value: number, presize: number): string {
  if (presize >= 1) {
    local res = (value / presize + (value < 0 ? -0.5 : 0.5)).tointeger()
    return res == 0 ? "0" : "".join([res].extend(array(log10(presize).tointeger(), "0")))
  }
  return format("%.{0}f".subst(-log10(presize).tointeger()), value)
}

function [pure] isStringInteger(str): bool {
  if (str instanceof Integer)
    return true
  if (!(str instanceof String))
    return false
  return intRegExp.match(str)
}

function [pure] isStringFloat(str, separator="."): bool {
  if (str instanceof Integer || str instanceof Float)
    return true
  if (!(str instanceof String))
    return false
  if (separator == ".")
    return floatRegExp.match(str)

  if (str.startswith("-"))
    str = str.slice(1)
  local numList = split(str, separator)
  local numListLen = numList.len()
  if (numListLen > 2 || numList[0] == "")
    return false
  if (numListLen == 2 && numList[1] == "")
    numList[1] = "0"
  local lastSeg = numList[numListLen - 1]
  local expMark = lastSeg.contains("e") ? "e"
    : lastSeg.contains("E") ? "E"
    : null
  if (expMark) {
    local eList = split(lastSeg, expMark)
    if (eList.len() != 2)
      return false
    if (numListLen == 2 && eList.len() == 2 && eList[0] == "")
      eList[0] = "0"
    if (eList[1].startswith("-") || eList[1].startswith("+"))
      eList[1] = eList[1].slice(1)
    local expDigits = eList[1].len()
    if (expDigits < 1 || expDigits > 3)
      return false
    numList[numListLen - 1] = eList[0]
    numList.append(eList[1])
  }
  foreach (s in numList) {
    if (s == "")
      return false
    for (local i = 0; i < s.len(); i++)
      if (s[i] < '0' || s[i] > '9')
        return false
  }
  return true
}

function [pure] toIntegerSafe(str, defValue = 0, needAssert = true) {
  if (str instanceof String)
    str = str.strip()
  if (isStringInteger(str))
    return str.tointeger()
  if (needAssert)
    assert(false, @() $"can't convert '{str}' to integer")
  return defValue
}

function [pure] toFloatSafe(str, defValue = 0.0, needAssert = true) {
  if (str instanceof String)
    str = str.strip()
  if (isStringFloat(str))
    return str.tofloat()
  if (needAssert)
    assert(false, @() $"can't convert '{str}' to float")
  return defValue
}

local utf8ToUpper
local utf8ToLower
local utf8Capitalize
local utf8CapitalizeWords

if (utf8 != null) {
  utf8ToUpper = function [pure] utf8ToUpperImpl(str) {
    return utf8(str).toUpper()
  }

  utf8ToLower = function [pure] utf8ToLowerImpl(str) {
    return utf8(str).toLower()
  }

  utf8Capitalize = function [pure] utf8CapitalizeImpl(str) {
    let utf8Str = utf8(str)
    return "".concat(utf8(utf8Str.slice(0, 1)).toUpper(), utf8Str.slice(1))
  }
  utf8CapitalizeWords = @[pure] utf8CapitalizeWordsImpl(str) " ".join(str.split(" ").map(utf8Capitalize))
}
else {
  function noUtf8Module(...) { assert(false, "No 'utf8' module") }
  utf8ToUpper = noUtf8Module
  utf8ToLower = noUtf8Module
  utf8Capitalize = noUtf8Module
  utf8CapitalizeWords = noUtf8Module
}

function [pure] intToUtf8Char(c: int): string {
  if (c <= 0x7F)
    return c.tochar()
  if (c <= 0x7FF)
    return "".concat((0xC0 + (c>>6)).tochar(), (0x80 + (c & 0x3F)).tochar())
  if (c <= 0xFFFF)
    return "".concat((0xE0 + (c>>12)).tochar(), (0x80 + ((c>>6) & 0x3F)).tochar(), (0x80 + (c & 0x3F)).tochar())
  if (c <= 0x10FFFF)
    return "".concat((0xF0 + (c>>18)).tochar(), (0x80 + ((c>>12) & 0x3F)).tochar(), (0x80 + ((c>>6) & 0x3F)).tochar(), (0x80 + (c & 0x3F)).tochar())
  return ""
}

const firstOctet = [
  { ofs = 0, mask = 0x7F }
  { ofs = 0xC0, mask = 0x1F }
  { ofs = 0xE0, mask = 0x0F }
  { ofs = 0xF0, mask = 0x07 }
]
const nextOctet = { ofs = 0x80, mask = 0x3F }

function [pure] utf8CharToInt(str): int {
  let list = []
  foreach (i in str)
    list.append(i)

  local res = 0
  for (local i = list.len() - 1; i >= 0; i--) {
    let { ofs = null, mask = null } = i > 0 ? nextOctet
      : firstOctet?[list.len() - 1]
    if (ofs == null)
      return 0 
    let val = list[i]
    if ((val & ~mask) != ofs)
      return 0 
    res += (val & mask) << ((list.len() - 1 - i) * 6)
  }

  return res
}

function [pure] hexStringToInt(hexString): int {
  
  if (hexString.len() >= 2 && hexString.slice(0, 2) == "0x")
    hexString = hexString.slice(2)

  
  local res = 0
  foreach (character in hexString) {
    local nibble = character - '0'
    if (nibble > 9)
      nibble = ((nibble & 0x1F) - 7)
    res = (res << 4) + nibble
  }

  return res
}


function [pure] cutPrefix(id, prefix, defValue = null) {
  if (!id)
    return defValue

  local pLen = prefix.len()
  if ((id.len() >= pLen) && (id.slice(0, pLen) == prefix))
    return id.slice(pLen)
  return defValue
}

function [pure] cutPostfix(id, postfix, defValue = null) {
  if (!id)
    return defValue

  local pLen = postfix.len()
  local idLen = id.len()
  if ((idLen >= pLen) && (id.slice(-1 * pLen) == postfix))
    return id.slice(0, idLen - pLen)
  return defValue
}

function [pure] intToStrWithDelimiter(value, delimiter = " ", charsAmount = 3): string {
  local res = value.tointeger().tostring()
  local negativeSignCorrection = value < 0 ? 1 : 0
  local idx = res.len()
  while (idx > charsAmount + negativeSignCorrection) {
    idx -= charsAmount
    res = delimiter.concat(res.slice(0, idx), res.slice(idx))
  }
  return res
}


function [pure] stripTags(str) {
  if (!str || !str.len())
    return ""
  foreach(test in stripTagsConfig)
    str = str.replace(test.from, test.repl)
  return str
}

function [pure] escape(str): string {
  if (!(str instanceof String)) {
    assert(false, @() $"wrong escape param type: {type(str)}")
    return ""
  }
  foreach(test in escapeConfig)
    str = str.replace(test.from, test.repl)
  return str
}

function pprint(...){
  
  function findlast(str, substr, startidx=0){
    local ret = null
    for(local i=startidx; i<str.len(); i++) {
      local k = str.indexof(substr, i)
      if (k!=null) {
        i = k
        ret = k
      }
      else
        break;
    }
    return ret
  }
  if (vargv.len()<=1)
    print("".concat(tostring_r(vargv[0]),"\n"))
  else {
    local a = vargv.map(@(i) tostring_r(i))
    local res = ""
    local prev_val_newline = false
    local len = 0
    local maxlen = 50
    foreach(k,i in a) {
      local l = findlast(i,"\n")
      if (l!=null)
        len = len + i.len()-l
      else
        len = len+i.len()
      if (k==0)
        res = i
      else if (prev_val_newline && len<maxlen)
        res = " ".concat(res.slice(0,-1), i)
      else if (len>=maxlen){
        res = "\n ".concat(res, i)
        len = i.len()
      }
      else
        res = " ".concat(res, i)

      prev_val_newline = i.slice(-1) == "\n" && len < maxlen
    }
    print(res)
    print("\n")
  }
}

function validateEmail(no_dump_email): bool {
  if (!(no_dump_email instanceof String))
    return false

  local str = split(no_dump_email,"@")
  if (str.len() < 2)
    return false

  local locpart = str[0]
  if (str.len() > 2)
    locpart = "@".join(str.slice(0,-1))
  if (locpart.len() > 64)
    return false

  local dompart = str[str.len()-1]
  if (dompart.len() > 253 || dompart.len() < 4) 
    return false

  local quotes = locpart.indexof("\"")
  if (quotes && quotes != 0)
    return false 

  if (quotes == null && locpart.contains("@"))
    return false 

  if (!dompart.contains(".") || lastIndexOf(dompart, ".") > dompart.len() - 3)
    return false  

  return true
}

function clearBorderSymbols(value, symList = [" "]) {
  while(value != "" && symList.contains(value.slice(0,1)))
    value = value.slice(1)
  while(value!="" && symList.contains(value.slice(-1)))
    value = value.slice(0, -1)
  return value
}

function clearBorderSymbolsMultiline(str) {
  return clearBorderSymbols(str, [" ", 0x0A.tochar(), 0x0D.tochar()])
}

function [pure] splitStringBySize(str, maxSize): array {
  if (maxSize <= 0) {
    assert(false, $"maxSize = {maxSize}")
    return [str]
  }
  let result = []
  local start = 0
  let l = str.len()
  while (start < l) {
    let pieceSize = min(l - start, maxSize)
    result.append(str.slice(start, start + pieceSize))
    start += pieceSize
  }
  return result
}

function obj2stringarray(obj, curpath = null): array {
  let res = []
  curpath = curpath ?? []
  if (obj instanceof Array) {
    foreach(i in obj)
      res.extend(obj2stringarray(i, [].extend(curpath)))
  }
  else if (obj instanceof Table) {
    foreach( k, v in obj)
      res.extend(obj2stringarray(v, [].extend(curpath).append(k)))
  }
  else {
    res.append($"{"/".join(curpath)}={tostring_any(obj, null, false)}") 
  }
  return res
}

return freeze(string.__merge({
  INVALID_INDEX
  CASE_PAIR_LOWER
  CASE_PAIR_UPPER
  slice
  substring
  startsWith
  endsWith
  indexOf
  lastIndexOf
  indexOfAny
  lastIndexOfAny
  countSubstrings
  implode
  join
  split
  replace
  trim
  floatToStringRounded
  isStringInteger
  isStringFloat
  isStringLatin = @(str) regexp(@"[a-zA-Z]+").match(str)
  intToUtf8Char
  utf8CharToInt
  capitalize
  utf8Capitalize
  utf8ToUpper
  utf8ToLower
  utf8CapitalizeWords
  hexStringToInt
  cutPrefix
  cutPostfix
  intToStrWithDelimiter
  stripTags
  escape
  tostring_any
  tostring_r
  pprint
  validateEmail
  clearBorderSymbols
  clearBorderSymbolsMultiline

  toIntegerSafe
  toFloatSafe
  splitStringBySize
  obj2stringarray
}))
