--- 这位只能作为mixin注入到Fk中，也不会有别的子类了
---
--- 它作为整个游戏比较核心的一部分，而并非仅仅是三国杀的engine
---@class Base.ModManager : Object
---@field public extensions table<string, string[]> @ 所有mod列表及其包含的拓展包
---@field public extension_names string[] @ Mod名字的数组，为了方便排序
---@field public translations table<string, table<string, string>> @ 翻译表
---@field public boardgames { [string] : BoardGame } @ name -> game
---@field public game_modes table<string, GameMode> @ 所有游戏模式
---@field public taskdefs { [string] : TaskDef } @ name -> taskdef
local ModManager = {}

local BoardGame = require "core.boardgame"

function ModManager:initModManager()
  self.extensions = {
    ["standard"] = { "standard" },
    ["standard_cards"] = { "standard_cards" },
    ["maneuvering"] = { "maneuvering" },
    ["test"] = { "test_p_0" },
  }
  self.extension_names = { "standard", "standard_cards", "maneuvering", "test" }

  self.translations = {}  -- srcText --> translated

  self.boardgames = {}
  self.game_modes = {}

  self.taskdefs = {}

  self.Base = {
    Player = require "core.player",
    RoomBase = require "core.roombase",
    ClientBase = require "client.clientbase",
    ClientPlayerBase = require "client.clientplayer_base",
    ServerRoomBase = require "server.roombase",
    ServerPlayerBase = require "server.serverplayer_base",
    GameLogic = require "server.gamelogic",
    Engine = require "core.engine",
    AI = require "server.ai",
  }
end

-- 获取拓展包们的文件夹名，不考虑被禁用了的
---@return string[]
function ModManager:getExtensionDirectories()
  if UsingNewCore then FileIO.cd("../..") end

  local directories = FileIO.ls("packages")
  table.removeOne(directories, "freekill-core")
  table.removeOne(directories, "standard")
  table.removeOne(directories, "standard_cards")
  table.removeOne(directories, "maneuvering")
  table.removeOne(directories, "test")
  local _disable_packs = json.decode(fk.GetDisabledPacks())
  directories = table.filter(directories, function(d)
    return not table.contains(_disable_packs, d) and
      FileIO.isDir("packages/" .. d)
  end)

  if UsingNewCore then FileIO.cd("packages/freekill-core") end
  return directories
end

--- 加载所有拓展包。
---
--- Engine会在packages/下搜索所有含有init.lua的文件夹，并把它们作为拓展包加载进来。
---
--- 这样的init.lua可以返回单个拓展包，也可以返回拓展包数组，或者什么都不返回。
---
--- 标包和标准卡牌包比较特殊，它们永远会在第一个加载。
---@return nil
function ModManager:loadPackages()
  local directories = self:getExtensionDirectories()

  if UsingNewCore then FileIO.cd("../..") end

  for _, dir in ipairs(directories) do
    if FileIO.exists("packages/" .. dir .. "/init.lua") then
      local pack = Pcall(require, string.format("packages.%s", dir))
      -- Note that instance of Package is a table too
      -- so dont use type(pack) == "table" here
      if type(pack) == "table" then
        table.insert(self.extension_names, dir)
        if pack[1] ~= nil then
          self.extensions[dir] = {}
          for _, p in ipairs(pack) do
            table.insert(self.extensions[dir], p.name)
            p:install(self)
          end
        else
          self.extensions[dir] = { pack.name }
          pack:install(self)
        end
      end
    end
  end

  if UsingNewCore then FileIO.cd("packages/freekill-core") end
end

--- 向翻译表中加载新的翻译表。
---@param t table @ 要加载的翻译表，这是一个 原文 --> 译文 的键值对表
---@param lang? string @ 目标语言，默认为zh_CN
function ModManager:loadTranslationTable(t, lang)
  assert(type(t) == "table")
  lang = lang or "zh_CN"
  self.translations[lang] = self.translations[lang] or {}
  for k, v in pairs(t) do
    self.translations[lang][k] = v
  end
end

--- 翻译一段文本。其实就是从翻译表中去找
---@param src string @ 要翻译的文本
---@param lang? string @ 要使用的语言，默认读取config
function ModManager:translate(src, lang)
  lang = lang or (Config.language or "zh_CN")
  if not self.translations[lang] then lang = "zh_CN" end
  local ret = self.translations[lang][src]
  return ret or src
end

---@param game BoardGameSpec
function ModManager:addBoardGame(game)
  self.boardgames[game.name] = BoardGame:new(game)
end

---@param name string 游戏模式名 并非桌游类型
---@return BoardGame
function ModManager:getBoardGame(name)
  local gameMode = Fk.game_modes[name or ""]
  local gameName = gameMode and gameMode.game_name
  local ret = self.boardgames[gameName or "lunarltk"]
  if ret then return ret end
  return BoardGame {
    name = "lunarltk",
    room_klass = Room,
    client_klass = Client,
    engine = Fk,
    page = {
      uri = "Fk.Pages.LunarLTK",
      name = "Room",
    }
  }
end

--- 向Engine中添加一系列游戏模式。
---@param game_modes GameMode[] @ 要添加的游戏模式列表
function ModManager:addGameModes(game_modes)
  for _, s in ipairs(game_modes) do
    self:addGameMode(s)
  end
end

--- 向Engine中添加一个游戏模式。
---@param game_mode GameMode @ 要添加的游戏模式
function ModManager:addGameMode(game_mode)
  assert(game_mode:isInstanceOf(GameMode))
  if self.game_modes[game_mode.name] ~= nil then
    error(string.format("Duplicate game_mode %s detected", game_mode.name))
  end
  self.game_modes[game_mode.name] = game_mode
end

local TaskDef = require "core.task_def"

---@param t TaskDefSpec
function ModManager:addTaskDef(t)
  local def = TaskDef:new(t.type)
  def.handler = t.handler
  if self.taskdefs[def.type] then
    fk.qCritical(string.format("Duplicated task type %s detected. Skipping.", def.type))
    return
  end

  self.taskdefs[def.type] = def
end

---@return TaskDef?
function ModManager:getTaskDef(tp)
  return self.taskdefs[tp]
end

--- 获知当前的Engine是跑在服务端还是客户端，并返回相应的实例。
---@return AbstractRoom
function ModManager:currentRoom()
  if RoomInstance then
    return RoomInstance
  end
  return ClientInstance
end

return ModManager
