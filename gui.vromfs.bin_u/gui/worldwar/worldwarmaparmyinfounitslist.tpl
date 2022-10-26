tdiv{
  width:t='pw'
  flow:t='vertical'
  <<#infoSections>>
  <<#title>>
  activeText {
    position:t='relative'
    text:t='<<title>>'
  }
  <</title>>

  tdiv {
    width:t='pw'
    padding:t='1@framePadding, 0'
    position:t='relative'

    <<#columns>>
      tdiv {
        <<#multipleColumns>>
          width:t='50%pw'
          <<^first>>
            padding-left:t='1@framePadding'
          <</first>>
        <</multipleColumns>>
        <<^multipleColumns>>
          width:t='pw'
          position:t='relative'
        <</multipleColumns>>

        flow:t='vertical'
        css-hier-invalidate:t='yes'

        include "%gui/worldWar/worldWarArmyInfoUnitString.tpl"
      }
    <</columns>>

  <<#multipleColumns>>
    blockSeparator {}
  <</multipleColumns>>
  }
  <</infoSections>>
}
