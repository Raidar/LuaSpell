--[[ UserDict ]]--

----------------------------------------
--[[ description:
  -- User dictionary handling.
  -- Обработка пользовательских словарей.
--]]
----------------------------------------
--local win = win

--local ffi = require'ffi'

--------------------------------------------------------------------------------
local unit = {}

---------------------------------------- Main data
unit.ScriptName = "UserDict"

---------------------------------------- Main class
local TMain = {
  --Guid       = win.Uuid(""),
}
local MMain = { __index = TMain }

---------------------------------------- Methods
function TMain:free ()
  local h = self.handle
  if not h then return end

  self.handle = nil
end ---- free

function TMain:match (s)
  if not s then return end

  local h = self.handle
  if not h then return end

  return h[s] or false
end ---- match

function TMain:spell (s)
  local h = self.handle
  if not h or not s then return end

  local ret = h[s]
  if self.allowed then
    ret = ret and 1 or 2
  else
    ret = ret and 0 or 2
  end

  return ret ~= 0, ret == 2 and 'warn' or nil
end ---- spell

--[[
function TMain:get_dic_encoding ()
  return
end -- get_dic_encoding

--local tinsert = table.insert

function TMain:suggest (word)
  return nil
end ---- suggest

function TMain:analyze (word)
  return nil
end ---- analyze

function TMain:stem (word)
  return nil
end ---- stem

function TMain:generate (word, word2)
  return nil
end ---- generate
--]]

function TMain:add_word (word, example)
  local t = self.handle
  t[word] = 0 -- Признак добавленного слова
end ---- add_word

function TMain:remove_word (word)
  local t = self.handle
  t[word] = false -- Признак удалённого слова
end ---- remove_word

--extras
do
  local io_open = io.open
  local ssub = string.sub
  local u8BOM = string.char(0xEF, 0xBB, 0xBF)

function TMain:add_dic (dpath, key, n)
  if not dpath then return end -- Нет пути

  local f = io_open(dpath, 'r')
  if not f then return end -- Нет словаря
  --if dpath:find("Stop_List", 1, true) then far.Show(dpath, key, n) end

  local s = ""

  -- Пропуск заголовка:
  if self.Type == "UserDict" then
    while s and not s:find("^%-%-%-") do
      --logShow(s, "Header line")
      s = f:read('*l')
    end
    if s == nil then return end -- Нет слов
  end

  -- Чтение списка слов:
  s = f:read('*l') -- first
  if s == nil then return end -- Нет слов

  if self.Type == "WordList" then
    if ssub(s, 1, 3) == u8BOM then
      s = ssub(s, 4, -1) -- Исключение UTF-8 BOM
    end
  end

  --local u = {}
  local t, v = self.handle, n or true
  while s do
    --logShow(s, "Word line")
    t[s] = v
    --u[#u + 1] = s

    s = f:read('*l') -- next
  end

  --if self.Type == "WordList" then far.Show(unpack(u)) end
end ---- add_dic

end -- do
---------------------------------------- main

-- Create new dictionary context.
-- Создание нового словарного контекста.
--[[
  -- @params:
  Info  (table) - information:
    Path     (string) - file path of base dictionary.
    Type     (string) - dictionary type: UserDict.
    WordType (string) - word type: enabled/disabled.
  -- @return:
  self  (table) - dictionary context.
--]]
function unit.new (Info) --> (table)
  if not Info then return nil end

  local self = {
    handle      = {},

    Type        = Info.Type,
    allowed     = Info.allowed,
  } --- self

  setmetatable(self, MMain)

  if Info.Path then
    self:add_dic(Info.Path, "", true)
  end

  return self
end -- new

--------------------------------------------------------------------------------
return unit
--------------------------------------------------------------------------------
