---@class Base.Package : Object
---@field public name string @ 拓展包的名字
---@field public extensionName string @ 拓展包对应的mod文件夹的名字。
---@field public customPages? W.PageButtonSpec[] @ 这个拓展包注册的额外页面
---@field public game_modes GameMode[] @ 拓展包包含的游戏模式
---@field public game_modes_whitelist? string[] @ 拓展包关于游戏模式的白名单
---@field public game_modes_blacklist? string[] @ 拓展包关于游戏模式的黑名单
local Package = class("Base.Package")

function Package:initialize(name)
  assert(type(name) == "string")
  self.name = name
  self.extensionName = name -- used for get assets

  self.game_modes = {}
end

--- 把自己加载到对应engine中，需要具体Package类重写
---@param engine Base.Engine
function Package:install(engine)
  if engine.packages[self.name] ~= nil then
    error(string.format("Duplicate package %s detected", self.name))
  end
  engine.packages[self.name] = self
  table.insert(engine.package_names, self.name)

  engine:addGameModes(self.game_modes)
end

--- 向拓展包中添加游戏模式。
---@param game_mode GameMode @ 要添加的游戏模式。
function Package:addGameMode(game_mode)
  table.insert(self.game_modes, game_mode)
end


return Package
