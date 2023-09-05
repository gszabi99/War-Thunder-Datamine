let { round } = require("math")

local scrnTgt = 0
let sfpf = @(value) round(1.0 * scrnTgt * value / 1080)
let setScrnTgt = @(value) scrnTgt = value

return {
  setScrnTgt
  sfpf
}