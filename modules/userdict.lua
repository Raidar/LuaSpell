--[[ UserDict ]]--

----------------------------------------
--[[ description:
  -- User dictionary handling.
  -- Обработка пользовательских словарей.
--]]
--------------------------------------------------------------------------------

local io = io
local string = string

----------------------------------------
--local win = win

local u8BOM = string.char(0xEF, 0xBB, 0xBF)

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

  self.dics  = nil
  self.words = nil

  self.handle = nil

end ---- free

function TMain:match (s)

  if not s then return end

  local t = self.words
  if not t then return end

  return t[s] or false

end ---- match

function TMain:spell (s)

  local t = self.words
  if not t or not s then return end

  local ret = t[s]
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

---------------------------------------- -- word

function TMain:add_word (word, example)

  local t = self.words
  t[word] = -1 -- Признак добавленного слова

end ---- add_word

function TMain:remove_word (word)

  local t = self.words
  t[word] = false -- Признак удалённого слова

end ---- remove_word

---------------------------------------- -- file
do
  local ssub = string.sub

-- Read dictionary file.
-- Чтение файла-словаря.
--[[
  -- @params:
  filepath (string) - full file path.
  value      (~nil) - value assigned to word.
  t         (table) - table for words.
  lines     (table) - table for file lines.
  -- @return:
  count    (number) - count of added words (but -1 - file not found).
--]]
function TMain:read_file (filepath, value, t, lines) --> (number)

  --local onlydic = onlydic == nil and true or onlydic

  local f = io.open(filepath, 'r')
  if not f then return -1 end -- Нет словаря
  --if dpath:find("Stop_List", 1, true) then far.Show(dpath, key, n) end

  local s = ""
  local lines = lines

  -- Пропуск заголовка:
  if self.Type == "UserDict" then
    while s and not s:find("^%-%-%-") do
      --logShow(s, "Header line")
      s = f:read('*l')
      if lines then lines[#lines + 1] = s end

    end

    if lines then lines.header_last = #lines end
    if s == nil then return 0 end -- Нет слов

  end

  -- Чтение списка слов:
  s = f:read('*l') -- first
  if s == nil or s:find("^%s*$") then return 0 end -- Нет слов

  if self.Type == "WordList" then
    if ssub(s, 1, 3) == u8BOM then
      s = ssub(s, 4, -1) -- Исключение UTF-8 BOM
      if lines then lines.is_bom = true end

    end
  end

  --local u = {}
  local count = 0
  local t, v = t, value
  while s do
    --logShow(s, "Word line")
    t[s] = v
    --u[#u + 1] = s
    count = count + 1
    if lines then lines[#lines + 1] = s end

    s = f:read('*l') -- next

  end

  f:close()
  f = nil

  --if self.Type == "WordList" then far.Show(unpack(u)) end

  return count

end ---- read_file

end -- do

function TMain:add_dic (dpath, key, n, name)

  n = n or 0

  local count = self:read_file(dpath, n, self.words, nil)
  if count >= 0 then
    self.dics[n]   = name
    self.counts[n] = count

  end
end ---- add_dic

---------------------------------------- main

-- Create new dictionary context.
-- Создание нового словарного контекста.
--[[
  -- @params:
  Info  (table) - information:
    DicPath  (string) - file path of base dictionary.
    Type     (string) - dictionary type: UserDict.
    WordType (string) - word type: enabled/disabled.
  -- @return:
  self  (table) - dictionary context.
--]]
function unit.new (Info) --> (table)

  if not Info then return nil end

  local self = {

    handle      = true,

    --Info        = Info, -- данные
    words       = {},   -- слова
    dics        = {},   -- словари
    counts      = {},   -- количество слов

    Type        = Info.Type,
    allowed     = Info.allowed,

  } --- self

  setmetatable(self, MMain)

  if Info.DicPath then
    self:add_dic(Info.DicPath, "", 0)

  end

  return self

end -- new

--------------------------------------------------------------------------------
return unit
--------------------------------------------------------------------------------
