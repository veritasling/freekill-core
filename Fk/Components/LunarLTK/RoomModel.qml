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

  property int playerNum        // 房间当前游玩人数
  property int dashboardId      // 初次开局时主视角id 用于保存主视角本来的玩家防止被切视角乱掉

  property int drawPileNum      // 牌堆剩余数
  property int roundCount       // 轮数
  property int playedTime       // 对局已经过的时长

  property list<PhotoModel> players // 所有玩家的photo所需数据（包括自己的）

  // banners，细节与PhotoModel的marks一致。
  property list<var> banners: []

  // 我们主视角的数据在此
  readonly property DashboardModel dashboard: DashboardModel {}

  signal seatChanged(); // 座位排序后的信号
  signal playerAdded(PhotoModel model); // 新玩家加入的信号（addNpc）

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

  function setPrompt(text) {
    promptText = Ltk.processPrompt(text);
  }

  // 一秒5刷智慧
  function refreshData() {
    drawPileNum = Lua.client.draw_pile.length;
    for (const model of players) {
      model.refreshData();
    }
  }

  function arrangeSeats(_, order) {
    // 先重设座位号
    for (const model of players) {
      model.seatNumber = order.indexOf(model.playerid) + 1;
    }

    // 然后打散order，把Self放到第一个，这样才好调整model们的index以重排photo
    const selfIndex = order.indexOf(Self.id);
    const after = order.splice(selfIndex);
    after.push(...order);
    const photoOrder = after;

    for (const model of players) {
      model.index = photoOrder.indexOf(model.playerid);
    }

    seatChanged();
  }

  function propertyUpdate(_, data) {
    const [uid, property_name, value] = data;
    const model = getPhoto(uid);
    if (model && property_name in model) {
      model[property_name] = value;
    }
  }

  function startGame() {
    for (const model of players) {
      model.general = "";
    }
  }

  function setPlayerMark(_, data) {
    const [ id, mark, v ] = data;
    const player = getPhoto(id);
    Ltk.setMark(mark.startsWith("@!") ? player.picMarks : player.marks, mark, v, id);
  }

  function setBanner(_, data) {
    const [ mark, v ] = data;
    Ltk.setMark(banners, mark, v);
  }

  function updateLimitSkill(sender, data) {
    const [ id, skill, time ] = data;
    getPhoto(id)?.updateLimitSkill(skill, time);
  }

  function addNpc(_, data) {
    const [id, name, avatar] = data;
    const photoModelComponent = Qt.createComponent("Fk.Components.LunarLTK", "PhotoModel");
    const model = photoModelComponent.createObject(null, {
      playerid: id,
      avatar,
      screenName: name,
      index: players.length,
    });
    model.index = players.length;
    players.push(model);
    playerNum++;
    playerAdded(model);
  }

  // 确定只会修改model属性的逻辑都搬家到这里
  function setupCallbacks() {
    roomPage.addCallback(Command.ArrangeSeats, arrangeSeats);
    roomPage.addCallback(Command.PropertyUpdate, propertyUpdate);
    roomPage.addCallback(Command.StartGame, startGame);
    roomPage.addCallback(Command.SetPlayerMark, setPlayerMark);
    roomPage.addCallback(Command.SetBanner, setBanner);
    roomPage.addCallback(Command.UpdateLimitSkill, updateLimitSkill);
    roomPage.addCallback("AddNpc", addNpc);
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
