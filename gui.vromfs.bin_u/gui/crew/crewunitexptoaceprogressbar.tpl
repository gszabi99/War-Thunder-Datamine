tdiv {
  width:t='pw'
  position:t='relative'
  tooltip:t='$tooltipObj'
  total-input-transparent:t='yes'
  interactive:t='yes'
  flow:t='vertical'
  padding-top:t='2@crewAceResearchBlockPadding' //to place upper crewSpecProgressBar textareas with pricees
  padding-bottom:t='2@crewAceResearchBlockPadding' //to place under crewSpecProgressBar textareas with RP

  crewSpecProgressBar {
    height:t='1@crewAceResearchProgresBlockHeight'
    width:t='pw'
    min:t='0'
    max:t='1000'
    value:t='<<progressBarValue>>'
  }

  div{
    width:t='pw'
    position:t='absolute'
    top:t='ph/2-h/2'

    div {
      width:t='pw'
      height:t='1@crewAceResearchProgresBlockHeight + 4@crewAceResearchBlockPadding'

      <<#markers>>
      tdiv {
        bottom:t='ph/2 - h/2'
        position:t='absolute'
        left:t='<<markerRatio>>*pw - w/2'
        width:t='0.75*@referenceMarkerWidth'
        height:t='1@crewAceResearchBlockPadding'
        background-image:t='#ui/gameuiskin#slider_thumb.svg'
        background-svg-size:t='1@referenceMarkerWidth, 0.02@sf'
        background-repeat:t='expand'
        bgcolor:t='#FFFFFF'
      }
      textareaNoTab {
        position:t='absolute'
        top:t='0'
        left:t='<<markerRatio>>*pw<<#alignRight>>- w<</alignRight>>'
        text-align:t='left'
        tinyFont:t='yes'
        text:t='<<markerPriceText>>'
      }
      textareaNoTab {
        position:t='absolute'
        left:t='<<markerRatio>>*pw<<#alignRight>>- w<</alignRight>>'
        bottom:t='0'
        text-align:t='left'
        tinyFont:t='yes'
        text:t='<<markerRPText>>'
      }
      <</markers>>
    }
  }

  tooltipObj {
    display:t='hide'
    textarea {
      text:t='<<hintText>>'
    }
  }
}