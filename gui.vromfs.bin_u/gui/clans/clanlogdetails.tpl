<<#role_old>>
tdiv {
  text {
    text:t='<<?clan/log/old_members_role>><<?ui/colon>>'
  }
  activeText {
    text:t='#clan/<<role_old>>'
  }
}
<</role_old>>
<<#role_new>>
tdiv {
  text {
    text:t='<<?clan/log/new_members_role>><<?ui/colon>>'
  }
  activeText {
    text:t='#clan/<<role_new>>'
  }
}
<</role_new>>
<<#name>>
tdiv {
  text {
    text:t='<<?clan/clan_name>><<?ui/colon>>'
  }
  activeText {
    text:t='<<name>>'
  }
}
<</name>>
<<#tag>>
tdiv {
  text {
    text:t='<<?clan/clan_tag>><<?ui/colon>>'
  }
  activeText {
    text:t='<<tag>>'
  }
}
<</tag>>
<<#slogan>>
tdiv {
  width:t='pw'
  textareaNoTab {
    width:t='pw'
    text:t='<<?clan/clan_slogan>><<?ui/colon>><color=@activeTextColor><<slogan>></color>'
  }
}
<</slogan>>
<<#region>>
tdiv {
  width:t='pw'
  text {
    text:t='<<?clan/clan_region>><<?ui/colon>>'
  }
  activeText {
    width:t='fw'
    text:t='<<region>>'
  }
}
<</region>>
<<#desc>>
tdiv {
  width:t='pw'
  textareaNoTab {
    width:t='pw'
    text:t='<<?clan/clan_description>><<?ui/colon>>\n<<desc>>'
  }
}
<</desc>>
<<#announcement>>
tdiv {
  width:t='pw'
  textareaNoTab {
    width:t='pw'
    text:t='<<?clan/clan_announcement>><<?ui/colon>>\n<<announcement>>'
  }
}
<</announcement>>
<<#type>>
tdiv {
  text{
    text:t='<<?clan/clan_type>><<?ui/colon>>'
  }
  activeText {
    text:t='#clan/clan_type/<<type>>'
  }
}
<</type>>
<<#status>>
tdiv {
  text {
    text:t='<<?caln/log/membership_applications>><<?ui/colon>>'
  }
  activeText {
    text:t='#clan/log/membership_applications/<<status>>'
  }
}
<</status>>
<<#upgrade_members_old>>
tdiv {
  text {
    text:t='<<?clan/log/old_members_limit>><<?ui/colon>>'
  }
  activeText {
    text:t='<<upgrade_members_old>>'
  }
}
<</upgrade_members_old>>
<<#upgrade_members_new>>
tdiv {
  text {
    text:t='<<?clan/log/new_members_limit>><<?ui/colon>>'
  }
  activeText {
    text:t='<<upgrade_members_new>>'
  }
}
<</upgrade_members_new>>
<<#comments>>
tdiv {
  width:t='pw'
  text {
    text:t='<<?clan/log/comment>><<?ui/colon>>'
  }
  textareaNoTab {
    text:t='<<comments>>'
    width:t='fw'
    overlayTextColor:t='active'
  }
}
<</comments>>
<<#signText>>
tdiv {
  position:t='relative'
  pos:t='pw - w, 0'

  textareaNoTab {
    text:t='<<signText>>'
    on_link_rclick:t="onUserLinkRClick"
  }
}
<</signText>>