<<#rewards>>
tdiv {
  width:t='pw'
  <<#needVerticalAlign>>
  pos:t='0.5pw-0.5w, 0'
  position:t='relative'
  <</needVerticalAlign>>

  <<#isComplete>>
  cardImg {
    background-image:t='#ui/gameuiskin#favorite'
  }
  <</isComplete>>

  <<#rewardImage>>
  cardImg {
    background-image:t='<<rewardImage>>'
  }
  <</rewardImage>>

  textarea {
    width:t='fw'
    class:t='textHeader'
    text:t='<<rewardText>>'
  }
}
<<#resourceImage>>
img {
  size:t='<<resourceImageSize>>'
  <<#needVerticalAlign>>
  pos:t='0.5pw-0.5w, 0'
  position:t='relative'
  <</needVerticalAlign>>
  background-image:t='<<resourceImage>>'
}
<</resourceImage>>
<</rewards>>