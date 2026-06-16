require %rGui.planeIlses.ilsCth3022

require DagorStdGuiRender
require darg

require %rGui.utils.canvas_common

class ComponentSu30 : Component
  def ComponentSu30(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    super(guiCtx, rdata, rstate, props)


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new ComponentSu30(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  setup_component(props, propStorage)
