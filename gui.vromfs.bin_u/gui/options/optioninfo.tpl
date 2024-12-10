tdiv {
  size:t='pw, ph'
  flow:t='vertical'
  padding-left:t='10@sf/@pf'
  padding-top:t='14@sf/@pf'
  overflow-y:t='auto'

  activeText {
    width:t='pw'
    mediumFont:t='yes'
    text:t='<<title>>'
  }

  img {
    id:t='option_info_image'
    width:t='0.8ph/0.552' // 0.552 is the info-images ratio
    max-width:t='pw'
    height:t='0.552w'
    min-height:t='0.552w' // in some cases re_size height is set to 0 without this
    margin-top:t='2@blockInterval'
    margin-bottom:t='4@blockInterval'
    background-image:t='<<imageSrc>>'
    background-repeat:t='aspect-ratio'
    display:t='<<#imageSrc>>show<</imageSrc>><<^imageSrc>>hide<</imageSrc>>'
  }

  textareaNoTab {
    width:t='pw'
    margin-top:t='3@blockInterval'
    text:t='<<description>>'
  }
}