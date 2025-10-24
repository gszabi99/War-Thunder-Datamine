module mfdFA18C_common
require %rGui.utils.canvas_common
require darg
require DagorStdGuiRender
require DagorMath

let fa18RadarColor = E3DCOLOR(0xfa0aca0a)

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 2.
  scaleMarkLength : float = 0.05
  dugoutHeight : float = 0.05
  baseScale : float = 0.95
