<<#headersView>>
craftBranchTree {
  width:t='<<branchWidth>>'
  height:t='fh'
  flow:t='vertical'

  <<#branchHeader>>
    craftBranchHeader {
      width:t='pw'
      text:t='<<branchHeader>>'
      text-align:t='center'
      <<#separators>>
      craftTreeSeparator{
        located:t='left'
      }
      <</separators>>
    }
  <</branchHeader>>

  <<#hasHeaderItems>>
  <<#headerItemsTitle>>
    craftBranchHeader {
      width:t='pw'
      textareaNoTab {
        position:t='absolute'
        pos:t='<<positionsTitleX>>, 0.5ph-0.5h'
        text:t='<<headerItemsTitle>>'
      }
      craftTreeSeparator{
        located:t='top'
      }
    }
  <</headerItemsTitle>>

  <<#branchHeaderItems>>
    craftHeaderRow {
      <<#itemsSize>>itemsSize:t='<<itemsSize>>'<</itemsSize>>
      tdiv{
        flow:t='vertical'
        position:t='relative'
        width:t='<<branchWidth>>'
        itemsBlock {
          position:t='relative'
          left:t='0.5pw - 0.5w'
          smallItems:t='yes'
          include "gui/items/item"
        }
        <<#totalEfficiency>>
        textareaNoTab {
          max-width:t='pw'
          text-align:t='center'
          pos:t='0.5pw - 0.5w, 1@itemPercentHeight'
          position:t='relative'
          text:t='<<?items/workshop/craft_tree/efficiency>><<?ui/colon>><<totalEfficiency>><<itemsEfficiency>>'
        }
        <</totalEfficiency>>
      }
      craftTreeSeparator{
        located:t='bottom'
      }
      <<#separators>>
        craftTreeSeparator{
          located:t='left'
        }
      <</separators>>
    }
  <</branchHeaderItems>>
  <</hasHeaderItems>>

  <<#bodyItemsTitle>>
    craftBranchHeader {
      width:t='pw'
      textareaNoTab {
        position:t='absolute'
        pos:t='<<positionsTitleX>>, 0.5ph-0.5h'
        text:t='<<bodyItemsTitle>>'
      }
    }
  <</bodyItemsTitle>>
}
<</headersView>>
craftTreeSeparator{
  located:t='bottom'
}
