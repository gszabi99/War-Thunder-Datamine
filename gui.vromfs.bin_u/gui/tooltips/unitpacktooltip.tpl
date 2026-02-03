tdiv {
  flow:t='vertical'
  textareaNoTab {
    position:t='relative'
    padding-bottom:t='1@blockInterval'
    normalBoldFont:t='yes'
    text:t='<<headerText>>'
  }
  img {
    position:t='relative'
    left:t='pw/2-w/2'
    size:t='<<scale>>*<<count>>*@unitPackCardSize, <<scale>>*@unitPackCardSize'
    min-width:t='<<scale>>*3@unitPackCardSize'
    background-image:t='!ui/groups/<<name>>.avif'
    background-repeat:t='aspect-ratio'
    background-align:t='center-pixel-perfect'
    background-color:t='#FFFFFF'
  }
  tdiv {
    position:t='relative'
    left:t='pw/2-w/2'
    padding-top:t='6@blockInterval'
    padding-bottom:t='2@blockInterval'
    <<#units>>
    tdiv {
      width:t='<<scale>>*@unitPackCardSize'
      flow:t='vertical'
      smallFont:t='yes'
      textareaNoTab {
        position:t='relative'
        pos:t='pw/2-w/2, 0'
        overlayTextColor:t='active'
        text:t='<<unitName>>'
      }
      textareaNoTab {
        position:t='relative'
        pos:t='pw/2-w/2, 0'
        text:t='<<typeText>>'
      }
      tdiv {
        position:t='relative'
        pos:t='pw/2-w/2, 0'
        flow:t='horizontal'
        textareaNoTab {
          padding-right:t='4@blockInterval'
          position:t='relative'
          text:t='<<unitRank>>'
        }
        textareaNoTab {
          position:t='relative'
          text:t='<<battleRating>>'
        }
      }
      img {
        position:t='relative'
        size:t='pw, <<scale>>*0.7@unitPackCardSize'
        background-image:t='<<image>>'
        background-repeat:t='aspect-ratio'
        bgcolor:t='#FFFFFF'
      }
    }
    <</units>>
  }
}
