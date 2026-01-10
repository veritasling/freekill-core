import QtQuick
import Fk

// 试做型RoomModel
//
// 目标是干掉大部分游戏对局内UI页面/组件的property定义
// 他们只需要一个property RoomModel model就行了，剩下需要的数据从model拿
// 因此，model需要定义对局页面依赖的各种数据
//
// 然后，这个model再负责从Lua中及时取得最新数据。
//
// 预计还需要定义一系列signal
//
// 隔壁PhotoModel同理

QtObject {
  id: root

  property var roomPage

  property string promptText    // 要显示的prompt文本（已翻译）
  property var promptStack      // prompt文本栈，因为有各种转化技的存在需要弹出压入啥的

  property int playerNum        // 房间当前游玩人数
  property int dashboardId      // 初次开局时主视角id 用于保存主视角本来的玩家防止被切视角乱掉

  property int drawPileNum      // 牌堆剩余数
  property int roundCount       // 轮数
  property int playedTime       // 对局已经过的时长

  property list<PhotoModel> players // 所有玩家的photo所需数据（包括自己的）

  function getTimeString(time) {
    let s = time % 60;
    const m = (time - s) / 60;
    const h = (time - s - m * 60) / 3600;
    if (s < 10) s = '0' + s;
    return h ? `${h}:${m}:${s}` : `${m}:${s}`;
  }

  function getPhoto(pid) {
    for (const model of players) {
      if (model.playerid === pid) {
        return model;
      }
    }
  }

  // 一秒5刷智慧
  function refreshData() {
    drawPileNum = Lua.client.draw_pile.length;
    for (const model of players) {
      model.refreshData();
    }
  }

  function setupCallbacks() {
    // TODO 等那场 ~大搬家~
  }

  function initialize() {
    dashboardId = Self.id;
    const luaPlayers = Lua.client.players;
    playerNum = luaPlayers.length;
    const photoModelComponent = Qt.createComponent("Fk.Components.LunarLTK", "PhotoModel");
    for (const player of luaPlayers) {
      const prop = player.__toqml().prop;
      delete prop.scale;
      delete prop.selectable;
      delete prop.state;
      const model = photoModelComponent.createObject(null, prop);
      model.index = players.length;
      players.push(model);
    }
  }
}
