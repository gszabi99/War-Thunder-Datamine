<<#rows>>
tr {
  <<#rowParam>><<rowParam>>:t='yes'<</rowParam>>
  <<#isEven>>even:t='yes'<</isEven>>

  <<#columns>>
  td {
    <<#image>>
    img {
      background-image:t='<<image>>'
      <<#needShowLocked>>background-saturate:t='0'<</needShowLocked>>
    }
    <</image>>
    <<#text>>
    text {
      <<#id>>id:t='<<id>>'<</id>>
      <<#overlayTextColor>>overlayTextColor:t='<<overlayTextColor>>'<</overlayTextColor>>
      text:t='<<text>>'
    }
    <</text>>
  }
  <</columns>>
}
<</rows>>