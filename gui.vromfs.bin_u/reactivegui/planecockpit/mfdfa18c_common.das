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

class MfdFA18CBase : Canvas
  frameHalfSizeRel : float2 = float2(0.375)
  scaleMarkLength : float = 0.05

  dugoutHeight : float = 0.05
  targetBoxHalfSize : float2 = float2(0.025, 0.01)

  buttonCollumnX = array<float>(
    -0.32, -0.16, 0.0, 0.16, 0.32
  )
  buttonRowY = array<float>(
    -0.32, -0.14, 0.0, 0.2, 0.35
  )

  baseScale : float = 0.95

  def MfdFA18CBase(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const)
    Canvas`Canvas(self, guiCtx, rdata, rstate)