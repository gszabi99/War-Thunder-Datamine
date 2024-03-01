from "iostream" import blob

/*
Usage:

local t = {
  success = false
  data = {
    start = 10
    count = 1
    mode  = "solo"
    flags = [true, true, false]
  }
}

shortValue(t)        == "{- {1 [+,+,-] solo 10}}"
shortKeyValue(t)     == "{success- data{count:1 flags[+,+,-] mode=solo start:10}}"
shortKeyValue(t, 32) == "{success- data{count:1 flags[+,+*"
*/

//#strict


function Comma(char = ',') {
  let ch = char
  local i  = 0
  return function(stream) { if (i++ > 0) stream.writen(ch, 'b') }
}

let dumpValWrite = {
  "string"   : @(v, stream, _) stream.writestring(v)
  "integer"  : @(v, stream, _) stream.writestring(v.tostring())
  "float"    : @(v, stream, _) stream.writestring(v.tostring())
  "bool"     : @(v, stream, _) stream.writestring(v ? "+" : "-")
  "null"     : @(_, stream, __) stream.writestring("~")
  "array"    : @(v, _, fEach) fEach(v, "[,]")
  "table"    : @(v, _, fEach) fEach(v, "{ }")
  "instance" : @(v, _, fEach) fEach(v, "< >")
}

function dumpValue(value) {
  let stream = blob()

  function fEach(val, decor) {
    stream.writen(decor[0], 'b')
    let comma = Comma(decor[1])
    foreach (v in val) {
      comma(stream)
      dumpValWrite?[type(v)](v, stream, fEach)
    }
    stream.writen(decor[2], 'b')
  }

  dumpValWrite?[type(value)](value, stream, fEach)
  return stream
}

function writeKeyValue(key, separator, str, stream) {
  if (key != "") {
    stream.writestring(key)
    stream.writestring(separator)
  }
  stream.writestring(str)
}

let dumpKeyValWrite = {
  "string"   : @(k, v, stream, _) writeKeyValue(k, "=", v, stream)
  "integer"  : @(k, v, stream, _) writeKeyValue(k, ":", v.tostring(), stream)
  "float"    : @(k, v, stream, _) writeKeyValue(k, ":", v.tostring(), stream)
  "bool"     : @(k, v, stream, _) writeKeyValue(k, "",  v ? "+" : "-", stream)
  "null"     : @(k, _, stream, __) writeKeyValue(k, "",  "~", stream)
  "array"    : @(k, v, _, wList) wList(k, v, "[,]", true)
  "table"    : @(k, v, _, wList) wList(k, v, "{ }")
  "instance" : @(k, v, _, wList) wList(k, v, "< >")
}

function dumpKeyValue(value) {
  let stream = blob()

  function writeList(key, val, decor, short = false) {
    stream.writestring(key)
    stream.writen(decor[0], 'b')
    let comma = Comma(decor[1])
    foreach (k, v in val) {
      comma(stream)
      dumpKeyValWrite?[type(v)](short ? "" : k, v, stream, writeList)
    }
    stream.writen(decor[2], 'b')
  }

  dumpKeyValWrite?[type(value)]("", value, stream, writeList)
  return stream
}

function cut(stream, maxLen) {
  if (stream.len() > maxLen) {
    stream.resize(maxLen)
    stream.writestring("*")
  }
  return stream
}

return {
  shortValue    = @(value, maxLen = 256) cut(dumpValue(value),    maxLen).tostring()
  shortKeyValue = @(value, maxLen = 512) cut(dumpKeyValue(value), maxLen).tostring()
}
