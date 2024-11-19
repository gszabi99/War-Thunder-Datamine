<<#title>>
blankTextArea {
  id:t='showcase_name'
  position:t='relative'
  left:t='(pw-w)/2'
  font:t="@fontMedium"
  color:t='@showcaseGreyText'
  text:t='<<title>>'
}
<</title>>

<<#gamemode>>
tdiv {
  left:t='(pw-w)/2'
  position:t='relative'
  flow:t='horizontal'
  showInEditMode:t='no'

  image {
    position:t='relative'
    top:t='(ph-h)/2'
    size:t='32@sf/@pf, 32@sf/@pf'
    background-color:t='@showcaseBlue'
    background-image:t='#ui/gameuiskin#all_unit_types.svg'
    background-svg-size:t='32@sf/@pf, 32@sf/@pf'
    background-repeat:t='aspect-ratio'
  }

  blankTextArea {
    id:t='showcase_type'
    position:t='relative'
    padding:t='32@sf/@pf, 0'
    font:t='@fontBigBold'
    color:t='#FFFFFF'
    text:t='<<gamemode>>'
  }

  image {
    position:t='relative'
    top:t='(ph-h)/2'
    size:t='32@sf/@pf, 32@sf/@pf'
    background-color:t='@showcaseBlue'
    background-image:t='#ui/gameuiskin#all_unit_types.svg'
    background-svg-size:t='32@sf/@pf, 32@sf/@pf'
    background-repeat:t='aspect-ratio'
  }
}
<</gamemode>>