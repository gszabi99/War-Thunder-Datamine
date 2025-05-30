module mfdFA18C_common
require %rGui.utils.canvas_common
require darg
require DagorStdGuiRender
require DagorMath

struct CanvasParams
  color : E3DCOLOR = E3DCOLOR(0xFFFFFFFF)
  fontId : int = -1
  fontSize : int = 20
  lineWidth : float = 2.
  frameHalfSizeRel : float2 = float2(0.375)
  scaleMarkLength : float = 0.05
  dugoutHeight : float = 0.05
  targetBoxHalfSize : float2 = float2(0.025, 0.01)
  baseScale : float = 0.95
