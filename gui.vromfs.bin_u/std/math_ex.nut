/*
  This module have all math functions
*/

local math = require("math.nut").__merge(require("math"),require("dagor.math"))
local {PI} = math
local function degToRad(angle){
  return angle*PI/180.0
}

local function radToDeg(angle){
  return angle*180.0/PI
}

return math.__merge({
  degToRad = degToRad
  radToDeg = radToDeg
})
