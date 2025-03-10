from "%darg/ui_imports.nut" import *
from "base64" import encodeBlob
from "iostream" import blob

function mkBitmapPicture(w, h, fillcb, prefix="") {
  const HEADER_SIZE = 18
  let BITMAP_SIZE = w*h*4

  let b = blob()
  b.resize(HEADER_SIZE+BITMAP_SIZE)

  b.seek(0)
  b.writen(0, 'b') 
  b.writen(0, 'b') 
  b.writen(2, 'b') 
  b.writen(0, 's') 
  b.writen(0, 's') 
  b.writen(0, 'b') 
  b.writen(0, 's') 
  b.writen(0, 's') 
  b.writen(w, 's') 
  b.writen(h, 's') 
  b.writen(32,'b') 
  b.writen(8, 'b') 

  for (local i=0;i<BITMAP_SIZE; ++i)
    b.writen(0, 'b')

  function setPixel(x_, y_, c) {
    let x = x_.tointeger()
    let y = y_.tointeger()
    if (x<0 || x>=w || y<0 || y>=h)
      throw $"Invalid coordinates {x},{y} for bitmap of size {w}x{h}"
    b.seek(HEADER_SIZE+(y*w+x)*4)
    b.writen(c, 'i')
  }

  function bufSetAt(idx, byte) {
    if (idx<0 || idx>BITMAP_SIZE)
      throw $"Invalid index {idx} for bitmap of size {w}x{h}"
    b.seek(HEADER_SIZE+idx)
    b.writen(byte, 'b')
  }

  function bufGetAt(idx) {
    if (idx<0 || idx>BITMAP_SIZE)
      throw $"Invalid index {idx} for bitmap of size {w}x{h}"
    b.seek(HEADER_SIZE+idx)
    return b.readn('b')
  }

  fillcb({w, h}, {setPixel, bufSetAt, bufGetAt})

  return Picture($"{prefix}b64://{encodeBlob(b)}.tga?Ac")
}

let cache = {}
local maxCachedSize = sw(15) * sh(15)

function mkBitmapPictureLazy(w, h, fillCb, prefix = "") {
  if (w * h > maxCachedSize)
    logerr($"Queued mkBitmapPictureLazy has size = {w}*{h} = {w*h} bigger than sw(15) * sh(15) = {maxCachedSize}")
  return function() {
    if (fillCb not in cache)
      cache[fillCb] <- mkBitmapPicture(w, h, fillCb, prefix)
    return cache[fillCb]
  }
}

return {
  mkBitmapPicture
  mkBitmapPictureLazy
  function setMaxCachedSize(size) { maxCachedSize = size }
}
