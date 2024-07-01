tdiv {
  flow:t='vertical'
  smallFont:t='yes'
  textareaNoTab{
    text:t='<<title>>'
    max-width:t='0.8@wwMapPanelInfoWidth'
    pos:t='0.5pw-0.5w, 0'
    position:t='relative'
    text-align:t='center'
    overlayTextColor:t='active'
    padding-bottom:t='1@blockInterval'
  }

  tdiv {
    pos:t='0.5pw-0.5w, 0'
    position:t='relative'
    padding:t='1@framePadding, 0'
    <<#columns>>
      tdiv {
        <<#hasMultipleColumns>>
          <<^isFirst>>
            padding-left:t='1@framePadding+1@blockInterval'
          <</isFirst>>
        <</hasMultipleColumns>>

        flow:t='vertical'

        <<#groupList>>
        tdiv{
          flow:t='horizontal'
          img {
            size:t="1@tableIcoSize, 1@tableIcoSize"
            background-svg-size:t='@tableIcoSize, @tableIcoSize'
            position:t='relative'
            padding-left:t='1@blockInterval'
            background-image:t='<<icon>>'
            background-repeat:t='aspect-ratio'
            shopItemType:t='<<shopItemType>>'
          }
          textareaNoTab {
            pos:t='0, 0.5ph-0.5h'
            position:t='relative'
            padding-left:t='1@blockInterval'
            text:t='<<unitName>>'
          }
        }
        <</groupList>>
      }
    <</columns>>
  }
}
