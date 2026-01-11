// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk.Components.LunarLTK

ColumnLayout {
  id: root

  required property PhotoModel dataModel

  Repeater {
    id: rep
    model: root.dataModel.limitSkills
    LimitSkillItem {
      required property var modelData
      skillname: modelData?.skill
      usedtimes: modelData?.time
    }
  }
}
