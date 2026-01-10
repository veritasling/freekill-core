import QtQuick
import Fk

QtObject {
  id: root

  property var photoItem

  property int index: 0 // photo们在屏幕内的排位

  property int playerid: -1
  property string avatar: ""
  property string screenName: ""
  property string netstate: "online"

  property string general: ""
  property string deputyGeneral: ""
  property int maxHp: 0
  property int hp: 0
  property int shield: 0
  property int gender: 0
  property string kingdom: "qun"
  property string role: "unknown"
  property bool role_shown: false

  property bool dying: false
  property bool dead: false
  property int rest: 0
  property bool faceup: true
  property bool chained: false
  property list<string> sealedSlots: []
  property int seatNumber: 1

  property int drank: 0

  property bool surrendered: false
}
