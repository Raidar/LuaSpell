--[[ LuaSpell ]]--

----------------------------------------
--[[ description:
  -- Spell checking based on Hunspell.
  -- Проверка орфографии на основе Hunspell.
--]]
----------------------------------------
--[[ uses:
  LuaFAR, LuaMacro.
  -- areas: editor.
--]]
----------------------------------------
--[[ based on:
  spell.lua
  (Макрос для проверки орфографии в редакторе.)
  (Searchable Menu.)
  (c) 2013+, zg.
  URL: http://forum.farmanager.com/viewtopic.php?f=60&t=8089&hilit=LuaSpell
--]]
----------------------------------------
--[[ required:
  1. Библиотека dll из проекта luapower (http://luapower.com/)
     URL: http://luapower.com/hunspell
     Отсюда берётся архив с последней версией. Из него нужна
     либо \bin\mingw32\hunspell.dll, либо bin\mingw64\hunspell.dll .
     Положить её в каталог общих dll, например, в каталог FAR Manager,
     добавив к названию x86 или x64 в соответствии с версией программы.
  2. Словари.
     Словари ожидаются в каталоге ~%FARPROFILE%\Dictionaries~.
     Все файлы словарей должны быть в кодировке UTF-8 без BOM,
     в первой строке aff-файлов нужно прописать "SET UTF-8" (без кавычек).
     По умолчанию макрос настроен на словари
     ru_RU_yo и en_US (нужны файлы aff и dic).
  3. Конфигурация:
     файл конфигурации макроса — ~%FARPROFILE%\data\macros\LuaSpell.cfg~.
--]]
--------------------------------------------------------------------------------

----------------------------------------
local useprofiler = false
--local useprofiler = true

local actprofiler
if useprofiler then
  require "profiler" -- Lua Profiler
  actprofiler = false
end

----------------------------------------
local tostring = tostring

----------------------------------------
local regex = regex

local F = far.Flags
local Flag4BIT = bit64.bor(F.FCF_FG_4BIT, F.FCF_BG_4BIT)

local EditorGetInfo = editor.GetInfo
local EditorGetLine = editor.GetString
local EditorSetLine = editor.SetString

----------------------------------------
--[[
local debugs = require "context.utils.useDebugs"
local logShow = debugs.Show
--]]

--------------------------------------------------------------------------------
local unit = {}

---------------------------------------- Main data
unit.ScriptName = "LuaSpell"

---------------------------------------- utils
local function ExpandEnv (s)
  return s:gsub("%%(.-)%%", win.GetEnv)
end

---------------------------------------- config
local CfgNameFmt = [[%%FARPROFILE%%\%s\%s\%s.cfg]]
local CfgName = CfgNameFmt:format(win.GetEnv("FARUSERDATADIR") or "data",
                                  "macros", unit.ScriptName)
local DictionaryPath = [[%FARPROFILE%\Dictionaries\]]
--local UserDictPath = DictionaryPath..[[custom\]]

local CharEnum = [[A-Za-zА-Яа-яЁё_0-9́]]
local CharsSet = "["..CharEnum.."]+"

local DefCfgData = {
  -- Settings:
  Enabled = false,

  Guid      = win.Uuid("f7684e73-a856-4196-9562-9e829e53a410"),
  ColorGuid = win.Uuid("d7f001ff-7860-4a24-b9ca-37bef603f7bc"),
  PopupGuid = false,

  Path = DictionaryPath,                -- Путь к словарям

  CharsSet = CharsSet,                  -- Множество допустимых символов
                                        -- для проверки на наличие слова:
  InnerSet = CharsSet.."$",             -- - в конце строке
  StartSet = "^"..CharsSet,             -- - в начале строке
  CheckSet = "/\\b"..CharsSet.."\\b/",  -- - в середине строки
  BoundSet = "\\S*",                    -- - с граничными символами

  ColorPrio = 199,                      -- Приоритет раскрашивания

  MacroKeys = {                         -- Клавиши для макросов:
    CheckSpell  = "CtrlF12",            -- - проверка текущего слова
    Misspelling = "ShiftF12",           -- - переход на следующее ошибочное слово
    SwitchCheck = "CtrlShiftF12",       -- - переключение подсветки ошибочных слов
    UnloadSpell = "LCtrlLAltShiftF12",  -- - завершение проверки (выгрузка)
  },

  -- Dictionaries:
  --[[
  { -- Custom dictionary (OOoUserDict)
    Type = "UserDict",                  -- Тип
    WordType = "enabled",               -- Тип слов: разрешённый
    StrToPath = false,                  -- Функция преобразования пути
    path = UserDictPath,                -- Путь к пользовательским словарям
    filename = "BaseDict",              -- Основной словарь
                                        -- Дополнительные словари:
    dics = {                            --   - списком:
      "ExtraDict",                      --     - имена файлов без расширения
    },
    dics = {                            --   - по lua-маске:
      path  = nil,                      --     - путь к файлам
      mask  = "^Dict_",                 --     - маска имён файлов с расширением
      match = nil,                      --     - функция фильтрации имён файлов
    },
    match = true,                       --
    --color = nil,                      -- Не используется при WordType = enabled
    Enabled = true,

    BreakOnMatch = true,                -- Успешная проверка
                                        -- при обнаружении слова в словаре
  },
  { -- Word list
    Type = "WordList",                  -- Тип                                
    WordType = "disabled",              -- Тип слов: запрещённый
    StrToPath = false,
    path = UserDictPath,
    filename = "Stop_List",
    dicext = ".lst",                    -- Расширение файла (с точкой)
    dics = { "ExtraList", },
    match = DicMatch,
    color = {
      Flags = Flag4BIT,
      ForegroundColor = 0xF,
      BackgroundColor = 0xC,
    },
    Enabled = true,

    BreakOnMatch = true,
  },
  --]]
  { -- Hunspell: Russian
    lng = "rus",                        -- Язык
    desc = "Russian",                   -- Описание
    Type = "Hunspell",                  -- Тип
    filename = "ru_RU_yo",              -- Имя файла без расширения
    --masks = {  },                     -- Маски имён файлов для проверки
                                        --   Формат аналогичен полю masks
                                        --   в context\cfg\types_config.lua
    find = [[/[А-Яа-яЁё]+/]],           -- Regexp для предварительной проверки
    match = true,                       -- Функция для предварительной проверки
    color = {                           -- Цвет для раскрашивания ошибочных слов
      Flags = Flag4BIT,
      ForegroundColor = 0xF,
      BackgroundColor = 0x4,
    },
    Enabled = true,
  },
  { -- Hunspell: English
    lng = "eng",                        -- Language
    desc = "English",                   -- Description
    Type = "Hunspell",                  -- Type
    filename = "en_US",                 -- File name without extension
    find = [[/[A-Za-z]+/]],             -- Regexp to check preliminary
    match = true,                       -- Function to check preliminary
    color = {                           -- Color to colorize wrong words
      Flags = Flag4BIT,
      ForegroundColor = 0xF,
      BackgroundColor = 0x5,
    },
    Enabled = true,
  },

} --- DefCfgData

DefCfgData.PopupGuid = DefCfgData.Guid

---------------------------------------- Main
local config

local function DefMatch ()
  return true
end -- DefMatch

local function CreateMain (ArgData)
  --ArgData = ArgData or DefCfgData

  local chunk, serror = loadfile(ExpandEnv(CfgName))
  --far.Show(CfgName, chunk)
  if chunk then
    local env = { __index = _G }
    setmetatable(env, env)
    config, serror = setfenv(chunk, env)()
    if config == nil then config = env.Data end
  end
  if not config then config = {} end

  setmetatable(config, { __index = DefCfgData })

  local n = #config
  if n == 0 then
    n = #DefCfgData
    --for k = 1, n do
    --  config[k] = DefCfgData[k]
    --end
  end

  for k = 1, n do
    local v = config[k]
    if type(v.match) == 'boolean' and v.match then
      v.match = DefMatch
    end
  end

  config.n = n
end -- CreateMain

CreateMain()

----------------------------------------
local editors = {}

---------------------------------------- File

local function CheckFile (filename) --> (true | nil)
  local file = io.open(filename, "rb")
  if not file then return end
  file:close()

  return true
end -- CheckFile
unit.CheckFile = CheckFile

local PathNamePattern = '^(.-)([^\\/]+)$'

local function ParseFilePath (path) --> (path, name)
  if not path then return end
  return path:match(PathNamePattern)
end -- ParseFilePath
unit.ParseFilePath = ParseFilePath

---------------------------------------- Str
function unit.StrToStr (s)
  return s
end ---- StrToStr

do
  local AnsiCP
  local WCtoMB = win.WideCharToMultiByte
  local U8toU16 = win.Utf8ToUtf16

function unit.StrToAnsi (s)
  if not AnsiCP then AnsiCP = win.GetACP() end
  return WCtoMB(U8toU16(s), AnsiCP)
end ---- StrToAnsi

end -- do
---------------------------------------- Hunspell
local hunspell = require "hunspell"

local function NewHunspell (k, v)
  if not hunspell then return false end
  
  local v = v
  --local handle, text = hunspell.new(v.affpath, v.dicpath, nil)
  local handle, text = hunspell.new(v.StrToPath(v.affpath),
                                    v.StrToPath(v.dicpath), nil)
  if handle then return handle end

  far.Message(win.OemToUtf8(text), "hunspell", nil, 'we')
  hunspell = false

  return false
end -- NewHunspell

function unit.InitHunspell (k)
  local k = k
  local v = config[k]
  local Path = v.path or config.Path

  v.filename = v.filename or v.lng or tostring(k)
  if not v.dic then v.dic = v.filename..".dic" end
  if not v.aff then v.aff = v.filename..".aff" end
  if v.dic then v.dicpath = ExpandEnv(Path..v.dic) end
  if v.aff then v.affpath = ExpandEnv(Path..v.aff) end

  if hunspell and
     v.dicpath and CheckFile(v.dicpath) and
     v.affpath and CheckFile(v.affpath) then
    v.handle = NewHunspell(k, v)
    --v.coding = v.handle:get_dic_encoding()

    --far.Show(v.handle, v.dic, v.find, v.coding)
    --logShow(v, v.filename, "w d2")

    if not v.handle then return false end

    unit.Add_Dics(k)

    return true
  end

  return false
end ---- InitHunspell

---------------------------------------- UserDict
local userdict = require "userdict"

local function NewUserDict (k, v)
  if not userdict then return false end
  
  local v = v
  --local handle, text = hunspell.new(v.affpath, v.dicpath, nil)
  local handle, text = userdict.new(v)
  if handle then return handle end

  far.Message(win.OemToUtf8(text), "userdict", nil, 'we')
  hunspell = false

  return false
end -- NewUserDict

function unit.InitUserDict (k)
  local k = k
  local v = config[k]
  local Path = v.path or config.Path

  --v.filename = v.filename or tostring(k)
  if not v.dicext then v.dicext = ".dic" end
  if not v.dic and v.filename then v.dic = v.filename..v.dicext end
  if v.dic then v.dicpath = ExpandEnv(Path..v.dic) end
  if v.dicpath and v.dicpath ~= "" then
    v.Path = v.StrToPath(v.dicpath)
  end

  if userdict then
    if (v.dicpath or "") ~= "" and
       not CheckFile(v.dicpath) then
      return false
    end

    v.handle = NewUserDict(k, v)

    if not v.handle then return false end

    unit.Add_Dics(k)

    --far.Show(v.handle, v.dic, v.find, v.coding)
    --logShow(v, v.filename, "w d2")

    return true
  end

  return false
end ---- InitUserDict

---------------------------------------- Dictionary

local tostring = tostring

function unit.InitDictionary (k)
  local v = config[k]
  --local Path = config.Path

  if v.StrToPath == false then
    v.StrToPath = unit.StrToStr
  elseif v.StrToPath == nil or
         v.StrToPath == true then
    v.StrToPath = unit.StrToAnsi
  end

  if not v.Type then v.Type = "Hunspell" end
  if not v.WordType then v.WordType = "enabled" end
  v.allowed = v.WordType == "enabled" --> true/false

  if v.Visible == false then return end

  if v.Enabled == nil then v.Enabled = true end

  --if not v.Enabled then return end

  --FreeDictionary(k) -- DEBUG only

  local Type = v.Type
  if Type == "Hunspell" then
    unit.InitHunspell(k)

  elseif Type == "UserDict" or Type == "WordList" then
    unit.InitUserDict(k)

  else--if Type == "Custom" then
    if type(v.new) == 'function' then
      v.handle = v:new()
    end
    --far.Show(k, v.handle)

  end

  if v.handle and v.find then
    v.regex = regex.new(v.find)
  end

  if not v.handle then
    v.Enabled = nil
  end
end ---- InitDictionary

function unit.FreeDictionary (k)
  local v = config[k]

  if v.handle then
    v.handle:free()
  end
end ---- FreeDictionary

function unit.Add_Dics (k)
  local k = k
  local v = config[k]

  local h = v.handle
  if not h or
     not h.add_dic then
    return
  end

  local dics = v.dics
  local tp = type(dics)
  if tp == 'table' then
    local Path, Ext = v.path or config.Path, v.dicext
    for i, dic in ipairs(dics) do
      local path = ExpandEnv(Path..dic..Ext)
      if CheckFile(path) then
        h:add_dic(v.StrToPath(path), "", i)
      end
    end

    return unit.Add_DirDics(k, dics.path, dics.mask, dics.match, #dics + 1)

  --elseif then
  --  return unit.Add_DirDics(k, v.dics_mask, v.dics_match, 1)

  end
end -- Add_Dics

function unit.Add_DirDics (k, path, mask, match, n)
  if not mask then
    return
  end

  local k = k
  local v = config[k]

  local h = v.handle
  if not h or
     not h.add_dic then
    return
  end

  local path = ExpandEnv(path or v.path or config.Path)
  return unit.Add_ByMask(path, mask, match, h, "", n)
end ---- Add_DirDics

function unit.Add_ByMask (path, mask, match, handle, key, n)
  if not path or
     not mask then
    return
  end

  local h = handle
  if not h or
     not h.add_dic then
    return
  end

  local t = {}
  local dics = {}

  local function HandleFile (item, fullname)
    local attrs = item.FileAttributes
    --t[#t + 1] = item.FileName
    if not attrs:find("d", 1, true) and
       not attrs:find("h", 1, true) and
       item.FileName:find(mask) and
       (not match or match(item, fullname)) then
      --t[#t + 1] = item.FileName
      item.FullName = fullname
      dics[#dics + 1] = item
    end
  end -- HandleFile

  --far.Show(path:gsub("\\$", ""), mask, match, add_dic, key, n)
  far.RecursiveSearch(path:gsub("\\$", ""), "*", HandleFile, F.FRS_SCANSYMLINK)
  --far.Show(unpack(t))

  for i, dic in ipairs(dics) do
    --t[#t + 1] = dic.FullName
    h:add_dic(dic.FullName, key, n)
  end
  --far.Show(unpack(t))
end ---- Add_ByMask

---------------------------------------- Work
do
  local InitDictionary = unit.InitDictionary
  local FreeDictionary = unit.FreeDictionary

function unit.Init ()
  if unit.Enabled then return end

  for k = 1, config.n do
    InitDictionary(k)
  end

  unit.Enabled = true
  --Init = function() end
end ---- Init

function unit.Free ()

  for k = 1, config.n do
    FreeDictionary(k)
  end

  unit.Enabled = false
end ---- Free

end
---------------------------------------- Find
-- from LF context (context\scripts\detectType.lua):

local pcall = pcall
-- Mask & first line find function.
local sfind = ('').cfind -- Slow but char positions return
--local sfind = ('').find -- Fast but byte positions return

-- Protected find of pattern.
-- Защищённый поиск паттерна.
local function pfind (s, pattern) --> (number, number | nil)
  if not s then return end

  local isOk, findpos, findend = pcall(sfind, s, pattern)
  if isOk then return findpos, findend end -- Успешный поиск
end -- pfind

local function checkValueOver (value, values)
  if not values then return nil end
  if type(values) == 'string' then values = { values } end

  for k = 1, #values do
    local v = values[k]
    local findpos, findend = pfind(value, v)
    if findpos then
      return findend - findpos + 1, v -- + 1 for real length
    end
  end
end -- checkValueOver

---------------------------------------- Menu
local tinsert = table.insert

local function ShowMenu (strings, wordLen)
  local info = EditorGetInfo()

  local menuShadowWidth = 2
  local menuOverheadWidth = menuShadowWidth + 4 --6 => 2 рамка, 2 тень, 2 место для чекмарка
  local menuOverheadHeight = 3 --3 => 2 рамка, 1 тень

  local w = 0
  local Items = {}
  for k = 1, #strings do
    local v = strings[k]
    w = math.max(w, v:len())
    tinsert(Items, { Flags = 0, Text = v })
  end

  local h = 1
  local c = info.CurTabPos - info.LeftPos
  local r = info.CurLine - info.TopScreenLine
  local x = math.max(0, c - w - menuOverheadWidth + menuShadowWidth)
  x = (info.WindowSizeX - c) > (c + 2 - wordLen) and (c + 1) or x -- меню справа или слева от слова?

  local y = 0
  if (info.WindowSizeY - r - 1) > (r + 1) then -- меню сверху или снизу?
    -- снизу
    y = r + 2
    h = info.WindowSizeY - y + 1 - menuOverheadHeight
    h = math.min(h, #strings)

  else
    -- сверху
    y = r - #strings - 1
    if y < 1 then y = 1 end
    h = r - y - 1

  end

  -- fix menu width
  if (x + w + menuOverheadWidth) > info.WindowSizeX then
    w = info.WindowSizeX - x - menuOverheadWidth

  end

  local Form = {
    { "DI_LISTBOX", 0, 0, w + 3, h + 1, Items, 0, 0, 0, "" }
  }

  local function DlgProc (dlg, msg, param1, param2)
  end -- DlgProc

  local hDlg = far.DialogInit(config.PopupGuid,
                              x, y,
                              x + w + 3,
                              y + h + 1,
                              nil, Form, 0, DlgProc)
  local Index = far.DialogRun(hDlg) > 0 and
                far.SendDlgMessage(hDlg, F.DM_LISTGETCURPOS, 1).SelectPos or nil
  far.DialogFree(hDlg)

  return Index
end -- ShowMenu

---------------------------------------- Spell
--[[
-- @params:
  cfg   (table) - config.
  name (string) - file name.
  line (string) - file line content.
  pos  (number) - word position in file line.
  no   (number) - file line number
--]]
local function CheckMatch (cfg, name, line, pos, no) --> (bool | nil)
  local v = cfg
  if not v then return nil end
  if not v.Enabled or not v.handle then return false end

  v.masked = not v.masks or (checkValueOver(name, v.masks) and true)
  if not v.masked then return false end

  local matched = not v.match or v:match(v.word, line, pos, no)

  local h = v.handle
  if h.match then
    matched = h:match(v.word)
  end

  if matched then
    matched = not v.regex or v.regex:match(v.word)
  end

  return matched
end -- CheckMatch
unit.CheckMatch = CheckMatch

function unit.CheckSpell ()
  local Info = EditorGetInfo()
  if not Info then return end

  local _, fname = ParseFilePath(Info.FileName)

  unit.Init()

  local l, p = Info.CurLine, Info.CurPos
  local line, eol = EditorGetLine(Info.EditorID, l, 3)
  if not line then return end

  local word = ""
  local s, spos = line, 0
  if p <= s:len() + 1 then
    local slab = p > 1 and
                 s:sub(1, p - 1):match(config.InnerSet) or ""
    local tail = s:sub(p, -1):match(config.StartSet) or ""
    spos = p - slab:len()
    word = slab..tail
  end

  --far.Show("CheckSpell", line, word, spos)

  local wLen = word:len()
  if word == "" then return end

  for k = 1, config.n do
    local v = config[k]

    if v.Enabled then
      v.Info = Info
      v.word = word

      --far.Show("CheckSpell", line, word, spos, v.Enabled, v.handle)

      local matched = CheckMatch(v, fname, line, spos, l)
      --far.Show("CheckSpell", line, spos, v.word, matched)

      if matched then
        local h = v.handle
        local w = v.word
        if h.suggest and
           (not h.spell or not h:spell(w)) then
          local items = h:suggest(w)
          if #items > 0 then
            local Index = ShowMenu(items, wLen)
            if Index then
              local s = line:sub(1, spos - 1)..
                        items[Index]..
                        line:sub(spos + wLen)
              EditorSetLine(-1, 0, s, eol)
            end
          end

          break
        end

        if v.BreakOnMatch then break end
      end -- matched

    end -- Enabled

  end -- for

end ---- CheckSpell

---------------------------------------- Colorize

local function GetEditorData (id)
  local data = editors[id]
  if not data then
    editors[id] = { start = 0, finish = -1, }
    data = editors[id]
  end

  return data
end ---- GetEditorData
unit.GetEditorData = GetEditorData

local function RemoveColors (id)
  local data = GetEditorData(id)
  local guid = config.ColorGuid
  for l = data.start, data.finish do
    editor.DelColor(id, l, 0, guid)
  end

  data.start  = 0
  data.finish = -1
  return data
end -- RemoveColors
unit.RemoveColors = RemoveColors

do
  local Far_WinCount    = F.ACTL_GETWINDOWCOUNT
  local Far_WinInfo     = F.ACTL_GETWINDOWINFO
  local WinType_Editor  = F.WTYPE_EDITOR

function unit.RemoveAllColors ()
  local Count = far.AdvControl(Far_WinCount, 0, 0)
  for i = 1, Count do
    local Info = far.AdvControl(Far_WinInfo, i, 0)
    if Info and Info.Type == WinType_Editor then
      RemoveColors(Info.Id)
    end
  end
end ---- RemoveAllColors

end -- do

do
  local AddColor = editor.AddColor
  local Mark_Current = F.ECF_TABMARKCURRENT

function unit.CheckSpellText (Info, action)
  local Info = Info
  if not Info then return end

  unit.Init()

  --if useprofiler and not actprofiler then profiler.start("LuaSpell.log"); actprofiler = true end

  local id = Info.EditorID
  local prio = config.ColorPrio
  local guid = config.ColorGuid

  local _, fname = ParseFilePath(Info.FileName)

  for k = 1, config.n do
    local v = config[k]
    v.Info = Info
    v.masked = not v.masks or (checkValueOver(fname, v.masks) and true)
  end

  local action = action or "all"
  local data
  if action == "all" then
    data = RemoveColors(id)
    data.posit  = 1
    data.step   = 1
    data.start  = Info.TopScreenLine
    data.finish = math.min(Info.TopScreenLine + Info.WindowSizeY - 1,
                           Info.TotalLines)

  elseif action == "next" then
    data = GetEditorData(id)
    data.posit  = Info.CurPos + 1
    data.step   = 1
    data.start  = Info.CurLine
    data.finish = Info.TotalLines

  elseif action == "prior" then
    data = GetEditorData(id)
    data.posit  = Info.CurPos + 1
    data.step   = -1
    data.start  = 1
    data.finish = Info.CurLine

  end

  local Regex = regex.new(config.CheckSet)
  local Bound = config.BoundSet and
                regex.new(config.BoundSet)

  for l = data.start, data.finish, data.step do
    local line = EditorGetLine(-1, l, 3)
    local p = data.posit
    data.posit = 1
    while true do
      local spos, send = Regex:find(line, p)
      if not spos or spos > send then break end

      p = send + 1 -- for next word
      local word = line:sub(spos, send)
      if word ~= "" then
        --far.Show(config.CheckSet, line, word, spos, send)

        for k = 1, config.n do
          local v = config[k]

          if v.Enabled then
            v.word = word
            local brim = ""

            local matched = CheckMatch(v, fname, line, spos, l)
            if not matched then
              local bpos, bend = Bound:find(line, p)
              if bpos and bend >= bpos then
                brim = line:sub(bpos, bend)
              end
              if brim ~= "" then
                local word = v.word
                v.word = word..brim
                matched = CheckMatch(v, fname, line, spos, l)
                v.word = word
              end
            end

            if matched then
              local h = v.handle
              local isError = h.spell and not h:spell(v.word)
              if isError and brim ~= "" then
                isError = not h:spell(v.word..brim)
              end
              
              if isError then
                if action == "all" then
                  if v.color then
                    AddColor(id, l, spos, send,
                             Mark_Current, v.color, prio, guid)
                  end

                elseif action == "next" then
                  Info.CurLine = l
                  Info.CurPos = spos
                  Info.CurTabPos = -1
                  editor.SetPosition(id, Info)

                  return true
                end

                break
              end

              if v.BreakOnMatch then break end
            end -- matched

          end -- Enabled

        end -- for

      end -- word ~= ""

    end -- while
  end -- for data

  return true
end ---- CheckSpellText

end -- do

function unit.Misspelling ()
  return unit.CheckSpellText(EditorGetInfo(), "next")
end ---- Misspelling

function unit.SwitchCheck ()
  --far.Show"SwitchCheck"
  config.Enabled = not config.Enabled
  if not config.Enabled then
    unit.RemoveAllColors()
  end

  return editor.Redraw()
end ---- SwitchCheck

function unit.UnloadSpell ()
  unit.RemoveAllColors()

  unit.Free()
end

---------------------------------------- Events
local CheckSpellText = unit.CheckSpellText

do
  local EE_READ     = F.EE_READ
  --local EE_SAVE     = F.EE_SAVE
  local EE_CLOSE    = F.EE_CLOSE
  local EE_GOTFOCUS = F.EE_GOTFOCUS
  --local EE_CHANGE   = F.EE_CHANGE
  local EE_REDRAW   = F.EE_REDRAW

local function reloadEditorConfig (id, kind) --| editors
  --logShow({ "reset", editor.GetInfo() })

  local current = editors[id]
  if not current or current.kind ~= 'focus' then
    editors.current = nil                   -- reset
    current = { start = 0, finish = -1, }   -- new config
  end
  if current then current.kind = kind end
  editors.current = current

  -- Alternative code using indexes directly
  --local current = e_index(editors, 'current')
  --ev_newindex(editors, 'current', current)

  editors[id] = current
  --handleEvent('reloadEditor', current)

  --far.Message(editors.current.type, "Editor")
end -- reloadEditorConfig

Event {
  group = "EditorEvent",
  description = "Check spell all",

  action = function (id, event, param)
    local eid = id
    if event == EE_READ then
      reloadEditorConfig(eid, 'load')

    elseif event == EE_GOTFOCUS then
      reloadEditorConfig(eid, 'focus')
    
    elseif event == EE_CLOSE then
      editors.current, editors[eid] = nil, nil
      --if useprofiler and actprofiler then profiler.stop(); actprofiler = false end

    elseif event == EE_REDRAW then
      if config.Enabled then
        CheckSpellText(EditorGetInfo(), "all")
      end

    end
  end,
} -- Event "EditorEvent"

Event {
  group = "ExitFAR",
  description = "LuaSpell: Exit",

  action = unit.UnloadSpell,
} -- Event "ExitFAR"

end -- do
---------------------------------------- Macros
if config.MacroKeys.CheckSpell then
Macro {
  area = "Editor",
  key = config.MacroKeys.CheckSpell,
  description = "LuaSpell: Check spell",
  action = unit.CheckSpell,
} ---
end

if config.MacroKeys.SwitchCheck then
Macro {
  area = "Editor",
  key = config.MacroKeys.SwitchCheck,
  description = "LuaSpell: Spell on/off",
  action = unit.SwitchCheck,
} ---
end

if config.MacroKeys.Misspelling then
Macro {
  area = "Editor",
  key = config.MacroKeys.Misspelling,
  description = "LuaSpell: Next misspelling",
  action = unit.Misspelling,
} ---
end

if config.MacroKeys.UnloadSpell then
Macro {
  area = "Editor",
  key = config.MacroKeys.UnloadSpell,
  description = "LuaSpell: Unload",
  action = unit.UnloadSpell,
} ---
end
--------------------------------------------------------------------------------
