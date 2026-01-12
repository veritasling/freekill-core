// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk
import LunarLtk

RowLayout {
  id: root
  spacing: 4

  required property PhotoModel dataModel

  Repeater {
    id: markRepeater
    model: root.dataModel.picMarks

    Item {
      id: markItem
      required property var modelData
      width: 21
      height: 21
      Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: SkinBank.getMarkPic(parent.modelData.origName)

        MouseArea{ // 鼠标经过时显示文字，单击固定
          id: markArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: markItem.modelData.desc !== ""
          onEntered: {
            descriptionTip.visible = true;
          }
          onExited: {
            descriptionTip.visible = descriptionTip.clicked;
          }
          onClicked: {
            descriptionTip.visible = true;
            descriptionTip.clicked = true;
          }
        }
        ToolTip {
          id: descriptionTip
          x: 20
          y: 20
          text: markItem.modelData.desc;
          visible: false
          property bool clicked: false
          font.family: Config.libianName
          font.pixelSize: 20
        }
      }

      Text { // 右下角的文字，单个为翻译，1省略，数组为数量
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: markItem.modelData.value
        visible: markItem.modelData.value && markItem.modelData.value !== "1"
        font.family: Config.libianName
        font.pixelSize: 20
        font.bold: true
        color: "white"
        style: Text.Outline
      }
    }
  }
}
