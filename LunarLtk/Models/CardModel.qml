import QtQuick
import Fk
import LunarLtk.Components

// 此为某个游戏牌的UI数据
//
// 凭借这套数据可以造出各种外观的游戏牌

QtObject {
  id: root

  property int cardId   // 游戏牌的id
  property int virtId   // 若cardId为0（虚拟卡），则另设id以便与ui卡一一对应

  property string name: "slash" // 牌名
  property string virtName: "" // 被〖武神〗之类技能强制转化，或被当作其他牌使用时，此牌的实际牌名
  property int number // 点数
  property string suit // 花色
  property string color // 颜色

  property string extension

  // TODO 这俩没啥用途吧，再看
  property int type: 0
  property string subtype: ""

  property bool known: true // 是否已知

  property list<var> marks: [] // 标记，详见PhotoModel

  property string footnote: ""  // footnote, e.g. "A use card to B"
  property bool footnoteVisible: false
}

