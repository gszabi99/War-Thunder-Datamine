bgGradientRight {}

fillBlock {
  id:t = '<<id>>'
  <<#action>> on_click:t='<<action>>' <</action>>
  flow:t='vertical';
  tdiv {
    id:t = '<<id>>_items'
    smallItems:t='yes'
    position:t='relative'
    left:t='pw - w'

    <<@items>>
  }

  textareaNoTab {
    text:t='<<otherItemsText>>'
    position:t='relative'
    pos:t='pw-w, 0'
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
