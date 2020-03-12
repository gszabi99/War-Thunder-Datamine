titleTextArea {
  text-align:t='center'
  text:t='<<title>>'
}

bigMedalPlace {
  double:t='yes'
  bigMedalImg {
    background-image:t='<<image>>'
    background-repeat:t='aspect-ratio'
    status:t='<<status>>'
  }
}

<<#condition>>
  <<#isHeader>>unlockConditionHeader<</isHeader>>
  <<^isHeader>>unlockCondition<</isHeader>>
  {
    unlocked:t='<<unlocked>>'
    textarea{
      id:t='<<id>>'
      text:t='<<text>>'
    }
    <<#hasProgress>>
    challengeDescriptionProgress{
      id:t='progress'
      value:t='<<progress>>'
    }
    <</hasProgress>>
  }
<</condition>>

<<#rewardText>>
  unlockConditionHeader {
    textarea {
      text:t='<<?challenge/reward>> <<rewardText>>'
    }
  }
<</rewardText>>
