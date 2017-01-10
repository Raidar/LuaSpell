--[[ Hunspell ]]--

----------------------------------------
--[[ description:
  -- Hunspell FFI binding.
  -- Доступ к Hunspell через FFI.
--]]
----------------------------------------
--[[ uses:
  hunspell 1.3.2 .
--]]
----------------------------------------
--[[ based on:
  hunspell.lua
  (hunspell ffi binding.)
  (c) ?+, Cosmin Apreutesei.
  URL: http://luapower.com/hunspell
--]]
----------------------------------------
--[[ required:
  *. luapower hunspell
     URL: http://luapower.com/hunspell
--]]
--------------------------------------------------------------------------------

local assert = assert

----------------------------------------
--local win = win

local ffi = require'ffi'

--------------------------------------------------------------------------------
local unit = {}

local lib = false
local lib_name = "hunspell"..(win.GetEnv("PROCESSOR_ARCHITECTURE"):gsub("AMD64","x64"))

---------------------------------------- Main data
unit.ScriptName = "Hunspell"

---------------------------------------- Library
local function LoadLib () --> (bool)

  if lib then return true end

  --local lib = ffi.load(lib_name)
  local isOk, res = pcall(ffi.load, lib_name)
  if not isOk then return false, res or "" end

  lib = res

ffi.cdef[[
/*enum {
  HUNSPELL_MAXDIC = 20,
  HUNSPELL_MAXSUGGESTION = 15,
  HUNSPELL_MAXSHARPS = 5
};*/
typedef struct Hunhandle Hunhandle;
Hunhandle *Hunspell_create(const char * affpath, const char * dpath);
Hunhandle *Hunspell_create_key(const char * affpath, const char * dpath, const char * key);
void Hunspell_destroy(Hunhandle *pHunspell);
int Hunspell_spell(Hunhandle *pHunspell, const char *);
char *Hunspell_get_dic_encoding(Hunhandle *pHunspell);
int Hunspell_suggest(Hunhandle *pHunspell, char*** slst, const char * word);
int Hunspell_analyze(Hunhandle *pHunspell, char*** slst, const char * word);
int Hunspell_stem(Hunhandle *pHunspell, char*** slst, const char * word);
int Hunspell_stem2(Hunhandle *pHunspell, char*** slst, char** desc, int n);
int Hunspell_generate(Hunhandle *pHunspell, char*** slst, const char * word, const char * word2);
int Hunspell_generate2(Hunhandle *pHunspell, char*** slst, const char * word, char** desc, int n);
int Hunspell_add(Hunhandle *pHunspell, const char * word);
int Hunspell_add_with_affix(Hunhandle *pHunspell, const char * word, const char * example);
int Hunspell_remove(Hunhandle *pHunspell, const char * word);
void Hunspell_free_list(Hunhandle *pHunspell, char *** slst, int n);

//extras from extras.cxx
int Hunspell_add_dic(Hunhandle *pHunspell, const char * dpath, const char * key);

]]

  return true

end ---- LoadLib
---------------------------------------- Main class
local TMain = {

  --Guid       = win.Uuid(""),

}
local MMain = { __index = TMain }

---------------------------------------- Methods

function TMain:free ()

  local h = self.handle
  if not h then return end

  lib.Hunspell_destroy(h)
  ffi.gc(h, nil)
  self.handle = nil

end ---- free

function TMain:spell (s)

  local ret = lib.Hunspell_spell(self.handle, s)

  return ret ~= 0, ret == 2 and 'warn' or nil

end ---- spell

function TMain:get_dic_encoding ()

  local s = lib.Hunspell_get_dic_encoding(self.handle)
  if s == nil then return end

  return ffi.string(s)

end -- get_dic_encoding

local function output_list ()

  return ffi.new('char**[1]')

end -- output_list

local tinsert = table.insert

local function free_list (h, list, n)

  local t = {}
  for i = 0, n - 1 do
    tinsert(t, ffi.string(list[0][i]))

  end
  lib.Hunspell_free_list(h, list, n)

  return t

end -- free_list

function TMain:suggest (word)

  local h = self.handle

  local list = output_list()
  local n = lib.Hunspell_suggest(h, list, word)

  return free_list(h, list, n)

end ---- suggest

function TMain:analyze (word)

  local h = self.handle

  local list = output_list()
  local n = lib.Hunspell_analyze(h, list, word)

  return free_list(h, list, n)

end ---- analyze

function TMain:stem (word)

  local h = self.handle

  local list = output_list()
  local n = lib.Hunspell_stem(h, list, word)

  return free_list(h, list, n)

end ---- stem

local function input_list (t)

  local p = ffi.new('const char*[?]', #t)
  for i = 1, #t do
    p[i - 1] = t[i]

  end

  return p, #t

end -- input_list

function TMain:generate (word, word2)

  local h = self.handle

  local list = output_list()
  local n
  if type(word2) == 'table' then
    local desc, desc_n = input_list(word2)
    n = lib.Hunspell_generate2(h, list, word, ffi.cast('char**', desc), desc_n)

  else
    n = lib.Hunspell_generate(h, list, word, word2)

  end

  return free_list(h, list, n)

end ---- generate

---------------------------------------- -- word

function TMain:add_word (word, example)

  if example then
    assert(lib.Hunspell_add_with_affix(self.handle, word, example) == 0)

  else
    assert(lib.Hunspell_add(self.handle, word) == 0)

  end
end ---- add_word

function TMain:remove_word (word)

  assert(lib.Hunspell_remove(self.handle, word) == 0)

end ---- remove_word

---------------------------------------- -- file
-- extras

function TMain:add_dic (dpath, key)

  --far.Message(self.handle, dpath, key)

  assert(lib.Hunspell_add_dic(self.handle, dpath, key) == 0)

end ---- add_dic

---------------------------------------- main

-- key is for hzip-encrypted dictionary files
function unit.create (affpath, dicpath, key)

  local isOk, Error = LoadLib()
  if not isOk then return false, Error end

  local h = key and
            assert(lib.Hunspell_create_key(affpath, dicpath, key)) or
            assert(lib.Hunspell_create(affpath, dicpath))

  ffi.gc(h, lib.Hunspell_destroy)

  local self = {

    handle = h,

  } --- self

  return setmetatable(self, MMain)

end -- create

-- key is for hzip-encrypted dictionary files
function unit.new (Info)

  if not Info then return nil end

  local self = unit.create(Info.AffPath, Info.DicPath, Info.key)
  --self.Info = Info

  return self

end -- new

---------------------------------------- Test
--[[
if not ... then
  local hunspell = unit
  local pp = require'pp'.pp

  local h = hunspell.new(
    'media/hunspell/en_US/en_US.aff',
    'media/hunspell/en_US/en_US.dic')

  assert(h:spell('dog'))
  assert(not h:spell('dawg'))

  pp('suggest for "dawg"', h:suggest('dawg'))
  pp('analyze "words"', h:analyze('words'))

  pp('stem of "words"', h:stem('words'))

  pp('generate plural of "word"', h:generate('word', 'ts:Ns'))
  pp('generate plural of "word"', h:generate('word', {'ts:Ns'}))

  h:add_word('asdf')
  assert(h:spell('asdf'))
  h:remove_word('asdf')
  assert(not h:spell('asdf'))

  assert(h:get_dic_encoding() == 'UTF-8')

  --extras
  h:add_dic('media/hunspell/en_US/en_US.dic')

  h:free()
end
--]]
--------------------------------------------------------------------------------
return unit
--------------------------------------------------------------------------------
