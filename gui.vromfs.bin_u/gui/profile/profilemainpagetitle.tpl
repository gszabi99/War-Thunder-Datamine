<<#title>>
blankTextArea {
  id:t='showcase_name'
  position:t='relative'
  left:t='(pw-w)/2'
  font:t="@fontMedium"
  font-pixht:t='<<scale>>*27@sf/@pf \ 1'
  color:t='@showcaseGreyText'
  text:t='<<title>>'
}
<</title>>

<<#secondTitle>>
tdiv {
  left:t='(pw-w)/2'
  position:t='relative'
  flow:t='horizontal'
  showInEditMode:t='no'

  image {
    position:t='relative'
    top:t='(ph-h)/2'
    size:t='<<scale>>*32@sf/@pf, <<scale>>*32@sf/@pf'
    background-color:t='@showcaseBlue'
    background-image:t='#ui/gameuiskin#all_unit_types.svg'
    background-svg-size:t='<<scale>>*32@sf/@pf, <<scale>>*32@sf/@pf'
    background-repeat:t='aspect-ratio'
  }

  blankTextArea {
    id:t='showcase_type'
    position:t='relative'
    padding:t='<<scale>>*32@sf/@pf, 0'
    font:t='@fontBigBold'
    font-pixht:t='(<<scale>>*38@sf/@pf) \ 1'
    color:t='#FFFFFF'
    text:t='<<secondTitle>>'
  }

  image {
    position:t='relative'
    top:t='(ph-h)/2'
    size:t='<<scale>>*32@sf/@pf, <<scale>>*32@sf/@pf'
    background-color:t='@showcaseBlue'
    background-image:t='#ui/gameuiskin#all_unit_types.svg'
    background-svg-size:t='<<scale>>*32@sf/@pf, <<scale>>*32@sf/@pf'
    background-repeat:t='aspect-ratio'
  }
}
<</secondTitle>>