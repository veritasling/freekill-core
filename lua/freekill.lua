-- SPDX-License-Identifier: GPL-3.0-or-later

-- 用于初始化FreeKill的最基本脚本
-- 向Lua虚拟机中加载库、游戏中的类，以及加载Mod等等。

-- 加载第三方库
package.path = "./?.lua;./?/init.lua;./lua/lib/?.lua;./lua/?.lua;./lua/?/init.lua"

-- middleclass: 轻量级的面向对象库
class = require "middleclass"

-- 老json只能待命了
json = require "json"

cbor = require "server.rpc.cbor"

-- 初始化随机数种子
math.randomseed(os.time())

-- 加载实用类，让Lua编写起来更轻松。
Util = require "core.util"
dofile "lua/core/debug.lua"
UsingNewCore = FileIO.pwd():endsWith("packages/freekill-core")

-- 加载游戏核心类
local ModManager = require "core.mod_manager"
GameMode = require "core.game_mode"
RequestHandler = require "core.request_handler"
UI = require "ui-util"
GameEvent = require "server.gameevent"
TriggerEvent = require "core.trigger_event"

-- 读取配置文件。
-- 因为io马上就要被禁用了，所以赶紧先在这里读取配置文件。
local function loadConf()
  local new_core = FileIO.pwd():endsWith("packages/freekill-core")

  local cfg = io.open((new_core and "../../" or "") .. "freekill.client.config.json")
  local ret
  if cfg == nil then
    ret = {
      language = "zh_CN",
    }
  else
    ret = json.decode(cfg:read("a"))
    cfg:close()
  end
  return ret
end
Config = loadConf()

-- 禁用各种危险的函数，尽可能让Lua执行安全的代码。
os = {
  time = os.time,
  date = os.date,
  clock = os.clock,
  difftime = os.difftime,
  getms = os.getms,
}
io = {
  lines = io.lines
}
package = nil
-- load = nil
loadfile = nil
local _dofile = dofile
dofile = function(f)
  local errmsg = "Refusing dofile that not in game directory"
  assert(not f:startsWith("/"), errmsg)
  assert(not f:startsWith(".."), errmsg)
  assert(not f:find(":"), errmsg)
  return _dofile(f)
end

-- FIXME 择日弄掉这玩意

---@class GameModeSpec
---@field public name string @ 游戏模式名
---@field public minPlayer integer @ 最小玩家数
---@field public maxPlayer integer @ 最大玩家数
---@field public minComp? integer @ 最小电脑数，负数为实际玩家数+此数。创建房间后自动添加，无视服务器设置
---@field public maxComp? integer @ 最大电脑数，负数为实际玩家数+此数
---@field public rule? string @ 规则（通过技能完成，通常用来为特定角色及特定时机提供触发事件）
---@field public logic? fun(): GameLogic @ 逻辑（通过function完成，通常用来初始化、分配身份及座次）
---@field public whitelist? string[] | fun(self: GameMode, pkg: Package): boolean? @ 白名单
---@field public blacklist? string[] | fun(self: GameMode, pkg: Package): boolean? @ 黑名单
---@field public ui_settings? any @ ui规则
---@field public main_mode? string @ 主模式名（用于判断此模式是否为某模式的衍生）
---@field public winner_getter? fun(self: GameMode, victim: ServerPlayer): string @ 在死亡流程中用于判断是否结束游戏，并输出胜利者身份
---@field public surrender_func? fun(self: GameMode, playedTime: number): table
---@field public is_counted? fun(self: GameMode, room: Room): boolean @ 是否计入胜率统计
---@field public get_adjusted? fun(self: GameMode, player: ServerPlayer): table @ 调整玩家初始属性
---@field public reward_punish? fun(self: GameMode, victim: ServerPlayer, killer?: ServerPlayer) @ 死亡奖惩
---@field public friend_enemy_judge? fun(self: GameMode, targetOne: ServerPlayer | Player, targetTwo: ServerPlayer | Player): boolean? @ 敌友判断
---@field public build_draw_pile? fun(self: GameMode): integer[], integer[]

---@param spec GameModeSpec
---@return GameMode
function fk.CreateGameMode(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.minPlayer) == "number")
  assert(type(spec.maxPlayer) == "number")
  local ret = GameMode:new(spec.name, spec.minPlayer, spec.maxPlayer)
  ret.minComp = spec.minComp or 0
  ret.maxComp = spec.maxComp or -1
  ret.whitelist = spec.whitelist
  ret.blacklist = spec.blacklist
  ret.rule = spec.rule
  ret.logic = spec.logic
  ret.main_mode = spec.main_mode or spec.name
  Fk.main_mode_list[ret.main_mode] = Fk.main_mode_list[ret.main_mode] or {}
  table.insert(Fk.main_mode_list[ret.main_mode], ret.name)
  ret.ui_settings = spec.ui_settings

  if spec.winner_getter then
    assert(type(spec.winner_getter) == "function")
    ret.getWinner = spec.winner_getter
  end
  if spec.surrender_func then
    assert(type(spec.surrender_func) == "function")
    ret.surrenderFunc = spec.surrender_func
  end
  if spec.is_counted then
    assert(type(spec.is_counted) == "function")
    ret.countInFunc = spec.is_counted
  end
  if spec.get_adjusted then
    assert(type(spec.get_adjusted) == "function")
    ret.getAdjustedProperty = spec.get_adjusted
  end
  if spec.reward_punish then
    assert(type(spec.reward_punish) == "function")
    ret.deathRewardAndPunish = spec.reward_punish
  end
  if spec.build_draw_pile then
    assert(type(spec.build_draw_pile) == "function")
    ret.buildDrawPile = spec.build_draw_pile
  end
  if spec.friend_enemy_judge then
    assert(type(spec.winner_getter) == "function")
    ret.friendEnemyJudge = spec.friend_enemy_judge
  end
  return ret
end

-- 初始化Engine类并置于Fk全局变量中，这里会加载拓展包

-- 令人绝望的历史问题
-- 主要一开始的时候只打算做个ltk克隆而不是通用桌游引擎
-- 导致现在耦合着这样一个玩意
-- FIXME 想想办法把这里消除掉吧
local dirs = ModManager:getExtensionDirectories()
if table.contains(dirs, "lunarltk") then
  if UsingNewCore then FileIO.cd("../..") end
  dofile "packages/lunarltk/freekill.lua"
  Fk = Engine:new()
  if UsingNewCore then FileIO.cd("packages/freekill-core") end
  Fk:load()
else
  local baseEngine = require "core.engine"
  local MiniEngine = baseEngine:subclass("MiniEngine") --[[@as Base.ModManager]]
  MiniEngine:include(ModManager)
  Fk = MiniEngine:new()
  Fk:initModManager()
  Fk:loadPackages()
end
