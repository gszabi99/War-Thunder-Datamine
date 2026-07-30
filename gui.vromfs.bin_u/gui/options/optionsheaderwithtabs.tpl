tr {
  id:t='<<id>>'
  optContainer:t='yes'
  headerRow:t='yes'

  td {
    cellType:t='left'
    width:t='0.50pw'
    optionBlockHeader {
      text:t='<<headerText>>'
      margin-left:t='@blockInterval'
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
        <<#tabId>>
          id:t='<<tabId>>'
        <</tabId>>
        unitTypeTag:t='<<unitTypeTag>>'
        hasChangedIcon:t='no'
        <<#selected>>
        selected:t='yes'
        <</selected>>
        <<#disabled>>
        enable:t='no'
        <</disabled>>
        shopFilterText {
          text:t='<<tabName>>'
        }
        <<#tabId>>
        cornerImg {
          imgTiny:t='yes'
          type:t='left'
          background-image:t='#ui/gameuiskin#controls_help_point.svg'
          display:t='hide'
        }
        <</tabId>>
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
