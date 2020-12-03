blur {}
blur_foreground {}

fillBlock {
  id:t = '<<id>>'
  <<#action>> on_click:t='<<action>>' <</action>>
  flow:t='vertical'
  width:t='1@arrowButtonWidth'
  headerBg {pos:t='pw-w, 0'}

  tdiv {
    size:t='1@arrowButtonWidth-1@blockInterval, 1@arrowButtonHeight'
    position:t='relative'
    pos:t='-1@arrowButtonHeight, 0'
    <<#action>> interactive:t='yes' <</action>>
    autoScrollText:t='yes'
    overflow:t='hidden'
    css-hier-invalidate:t='yes'
    textareaNoTab {
      position:t='relative'
      needAutoScroll:t='<<needAutoScroll>>'
      text:t='<<otherItemsText>>'
      top:t='0.5ph-0.5h'
      padding:t='1@blockInterval, 0'
    }
  }
  div {
    id:t = '<<id>>_items'
    max-width:t='1@arrowButtonWidth'
    overflow:t='hidden'
    smallItems:t='yes'
    position:t='relative'
    pos:t='pw-w+1@dp-1@contentRightPadding, 1@dp'
    not-input-transparent:t='yes'

    <<@items>>
  }
}

collapsedContainer {
  <<#collapsedAction>> on_click:t='<<collapsedAction>>Collapsed' <</collapsedAction>>
  shortInfoBlock {
    shortHeaderText { text:t='<<collapsedText>>' }
    shortHeaderIcon { text:t='<<collapsedIcon>>' }
  }
}
baseToggleButton {
  id:t='<<id>>_toggle'
  on_click:t='onToggleItem'
  type:t='right'
  directionImg {}
}
