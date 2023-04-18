<<#plates>>
  shopRow {
    id:t='shop_tier_<<tierNum>>'
    size:t='<<w>>, <<h>>'
    pos:t='<<x>>, <<y>>'
    position:t='absolute'
    type:t='<<tierType>>'
    tooltip:t=''
  }
<</plates>>

<<#vertSeparators>>
  tdiv {
    size:t='1@dp, <<h>> <<#isTop>>-1@itemsInterval<</isTop>> <<#isBottom>>-1@itemsInterval<</isBottom>>'
    pos:t='<<x>>-w/2, <<y>> <<#isTop>>+1@itemsInterval<</isTop>>'
    position:t='absolute'
    background-color:t='@frameSeparatorColor'
  }
<</vertSeparators>>

<<#horSeparators>>
  tdiv {
    size:t='<<w>> <<#isLeft>>-3@modBlockTierNumHeight<</isLeft>> -2@itemsInterval, 1@dp'
    pos:t='<<x>> <<#isLeft>>+3@modBlockTierNumHeight<</isLeft>> +1@itemsInterval, <<y>>-h/2'
    position:t='absolute'
    background-color:t='@frameSeparatorColor'
  }
<</horSeparators>>
