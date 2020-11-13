root {
  background-color:t = '@shadeBackgroundColor'
  type:t="shop"

  navBar{
    style:t='id:slotbar_place;'
  }

  frame {
    id:t='shop_wnd_frame'
    position:t='absolute'

    <<^hasMaxWindowSize>>
    size:t='1@slotbarWidthFull, 1@maxWindowHeightWithSlotbar'
    pos:t='0.5pw-0.5w, 1@shopYPos-h'
    <</hasMaxWindowSize>>

    <<#hasMaxWindowSize>>
    size:t='1@maxWindowWidth, 1@maxWindowHeight'
    pos:t='0.5sw-0.5w, 1@minYposWindow'
    <</hasMaxWindowSize>>

    class:t='wndNav'
    type:t='blue'
    padByLine:t='yes'

    include 'gui/shop/shopInclude.blk'
  }

  gamercard_div {
    include 'gui/gamercardTopPanel.blk'
    include 'gui/gamercardBottomPanel.blk'
  }
}
