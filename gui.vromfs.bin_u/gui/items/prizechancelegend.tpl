prizeChanceLegend {
  width:t='pw'
  left:t='0.5pw-0.5w'
  position:t='relative'
  flow:t='vertical'

  textareaNoTab {
    width:t='pw'
    text:t='#item/chance'
    background-color:t='@separatorBlockColor'
    text-align:t='center'
    padding:t='1@blockInterval'
  }

  tdiv {
    width:t='pw'
    flow:t='h-flow'
    flow-align:t='center'

    <<#chances>>
    tdiv {
      width:t='0.33pw'

      tdiv {
        left:t='0.5pw-0.5w'
        max-width:t='pw'
        position:t='relative'
        margin-top:t='1@blockInterval'

        textareaNoTab {
          top:t='0.5ph-0.5h'
          position:t='relative'
          text:t='<<chanceName>>'
        }
        chanceIcon {
          top:t='0.5ph-0.5h'
          position:t='relative'
          margin-left:t='2@blockInterval'
          background-image:t='<<chanceIcon>>'
          background-color:t='@gray'
        }
      }
    }
    <</chances>>
  }
}