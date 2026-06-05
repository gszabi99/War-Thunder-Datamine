tr {
  optContainer:t='yes'
  headerRow:t='yes'

  td {
    cellType:t='left'
    width:t='0.50pw'
    optionBlockHeader {
      text:t='<<headerText>>'
    }
  }
  td {
    cellType:t='left'
    HorizontalListBox {
      id:t="tabs_list"
      height:t='ph'
      class:t='header'
      interactive:t='yes'
      sectionIdx:t='<<sectionIdx>>'
      on_select:t = 'onUnitTypeOptionSelect'

      <<#tabs>>
      shopFilter {
        <<#selected>>
        selected:t='yes'
        <</selected>>
        shopFilterText {
          text:t='<<tabName>>'
        }
        <<#tabImage>>
        shopFilterImg {
          background-image:t='<<tabImage>>'
        }
        <</tabImage>>
      }
      <</tabs>>
    }
  }

  optionHeaderLine{}
}
