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

local lib = false

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

  return self.handle[s] or false
end ---- match

--[[
function TMain:spell (s)
  local h = self.handle
  if not h or not s then return end

  local ret = self.handle[s] and 1 or 2
  return ret ~= 0, ret == 2 and 'warn' or nil
end ---- spell
--]]

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

function TMain:add_dic (dpath, key, n)
  local f = io_open(dpath, 'r')
  if not f then return end -- Нет словаря
  --if dpath:find("Nomo_Kiril", 1, true) then far.Show(dpath, key, n) end

  -- Пропуск заголовка:
  local s = ""
  while s and not s:find("^%-%-%-") do
    --logShow(s, "Header line")
    s = f:read('*l')
  end
  if s == nil then return end -- Нет слов

  -- Чтение слов:
  s = f:read('*l') -- first
  if s == nil then return end -- Нет слов

  local t, v = self.handle, n or true
  while s do
    --logShow(s, "Word line")
    t[s] = v

    s = f:read('*l') -- next
  end
end ---- add_dic

function TMain:add_dics (dpath, key, n)
  -- TODO
end ---- add_dics

end -- do
---------------------------------------- main

function unit.new (path, key)

  local self = {
    handle = {},
  } --- self

  setmetatable(self, MMain)
  self:add_dic(path, key, true)

  return self
end -- new

--------------------------------------------------------------------------------
return unit
--------------------------------------------------------------------------------
