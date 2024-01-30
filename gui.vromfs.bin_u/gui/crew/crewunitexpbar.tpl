tdiv {
  width:t='pw'
  position:t='relative'
  tooltip:t='$tooltipObj'
  total-input-transparent:t="yes"
  interactive:t="yes"
  flow:t='vertical'
  margin-left:t='2@blockInterval'
  padding-bottom:t='7*@sf/@pf'

  crewSpecProgressBar {
    height:t='7*@sf/@pf'
    width:t='pw - 2@blockInterval'
    top:t='ph-h'
    position:t='absolute'
    min:t='0'
    max:t='1000'
    value:t='<<progressBarValue>>'
  }

  text{
    width:t='pw-2@blockInterval'
    position:t='relative'
    text:t=' '
    <<#markers>>
    tdiv {
      top:t='ph-7*@sf/@pf'
      position:t='absolute'
      left:t='<<markerRatio>> * pw - 0.5w'
      width:t="1@referenceMarkerWidth"
      height:t="0.02@sf"
      background-image:t="#ui/gameuiskin#slider_thumb.svg"
      background-svg-size:t="1@referenceMarkerWidth, 0.02@sf"
      background-repeat:t="expand"
      bgcolor:t="#FFFFFF"
    }
    textarea {
      text-align:t='center'
      position:t='absolute'
      pos:t='<<markerRatio>> * pw- w/2, - ph*0.1'
      text:t='<<markerText>>'
    }
    <</markers>>
  }

  tooltipObj {
    display:t='hide' 
    textarea {
      text:t='<<hintText>>'
    }
  }
}