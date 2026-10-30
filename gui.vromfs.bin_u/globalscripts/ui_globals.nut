import "utf8" as utf8
from "dagor.localize" import loc


let logs = require("logs.nut")


return freeze({ utf8, loc }.__update(logs))