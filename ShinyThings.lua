-- Shiny Things: soft-target object icons + minimap tracking helper
local ADDON = "ShinyThings"
local P = "|cffffd100Shiny Things:|r "

local ICON_CVARS = {
  SoftTargetInteract         = "3", -- interact soft-target always on
  SoftTargetIconGameObject   = "1", -- icons over game objects
  SoftTargetIconInteract     = "1",
  SoftTargetLowPriorityIcons = "1", -- needed for corpse icons; benches etc. are hidden by the loot-only filter
  SoftTargetInteractArc      = "2",
  SoftTargetInteractRange    = "30",
}
-- settings later versions changed: put them back to game defaults once
local RESTORE = { SoftTargetIconFriend = "0", SoftTargetIconEnemy = "0", SoftTargetNameplateInteract = "1" }

local TRACK = {
  herbs    = { "Find Herbs" },
  ore      = { "Find Minerals" },
  treasure = { "Find Treasure" },
  fish     = { "Find Fish" },
}

local DEFAULT_IGNORE = { "bench", "chair", "stool", "seat", "throne", "couch", "pew" }

local function msg(t) DEFAULT_CHAT_FRAME:AddMessage(P .. t) end
local function cvarExists(n) return GetCVar(n) ~= nil end

local function Supported() return cvarExists("SoftTargetInteract") end

local function ApplyIcons(on)
  if not Supported() then
    msg("your client has no soft-target icons. Minimap tracking still works.")
    return false
  end
  for name, val in pairs(ICON_CVARS) do
    if cvarExists(name) then
      if on then
        ShinyThingsDB.saved[name] = ShinyThingsDB.saved[name] or GetCVar(name)
        SetCVar(name, val)
      elseif ShinyThingsDB.saved[name] then
        SetCVar(name, ShinyThingsDB.saved[name])
      end
    end
  end
  if not on then ShinyThingsDB.saved = {} end
  return true
end

-- Tracking: supports both the C_Minimap API and the older spell-based tracking
local function GetTrackingList()
  local list = {}
  local num = (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetNumTrackingTypes())
           or (GetNumTrackingTypes and GetNumTrackingTypes()) or 0
  for i = 1, num do
    local name, active
    if C_Minimap and C_Minimap.GetTrackingInfo then
      local info = C_Minimap.GetTrackingInfo(i)
      if type(info) == "table" then name, active = info.name, info.active
      else name, _, active = C_Minimap.GetTrackingInfo(i) end
    elseif GetTrackingInfo then
      name, _, active = GetTrackingInfo(i)
    end
    if name then list[#list + 1] = { i = i, name = name, active = active } end
  end
  return list
end

local function SetTrackingByName(spell)
  for _, t in ipairs(GetTrackingList()) do
    if t.name == spell then
      if C_Minimap and C_Minimap.SetTracking then C_Minimap.SetTracking(t.i, true)
      elseif SetTracking then SetTracking(t.i, true) end
      return true
    end
  end
  if GetSpellInfo(spell) and not InCombatLockdown() then
    CastSpellByName(spell) -- classic: tracking is a spell
    return true
  end
  return false
end

local function Track(key)
  local entry = TRACK[key]
  if not entry then return msg("unknown type. Use herbs, ore, treasure or fish.") end
  if SetTrackingByName(entry[1]) then
    ShinyThingsDB.track = key
    msg("tracking " .. entry[1] .. ". It turns back on after you die.")
  else
    msg("you don't know " .. entry[1] .. ".")
  end
end

local function Status()
  msg("object icons: " .. (Supported() and (ShinyThingsDB.icons and "|cff00ff00on|r" or "|cffff4040off|r") or "not supported"))
  msg("remembered tracking: " .. (ShinyThingsDB.track or "none"))
end

local function IsIgnored(name)
  if not name then return false end
  local n = name:lower()
  for word in pairs(ShinyThingsDB.ignore) do
    if n:find(word, 1, true) then return true end
  end
  return false
end

-- Loot-only mode: an icon is shown only if the target matches one of these
local LOOT_WORDS = {
  -- containers
  "chest","box","crate","trunk","coffer","strongbox","footlocker","cache","barrel","sack","bag","basket","stash","locker","keg",
  -- mining
  "vein","deposit","ore",
  -- fishing
  "school","pool","wreckage","debris","floating",
  -- herbs
  "peacebloom","silverleaf","earthroot","mageroyal","briarthorn","stranglekelp","bruiseweed","wild steelbloom",
  "grave moss","kingsblood","liferoot","fadeleaf","goldthorn","khadgar","wintersbite","firebloom","purple lotus",
  "arthas","sungrass","blindweed","ghost mushroom","gromsblood","golden sansam","dreamfoil","mountain silversage",
  "plaguebloom","icecap","black lotus","swiftthistle","bloodthistle",
}

local questCache, questCacheTime = {}, 0
local function QuestObjectiveText()
  if GetTime() - questCacheTime < 2 then return questCache end
  questCacheTime = GetTime(); questCache = {}
  local QL = C_QuestLog
  local add = function(text)
    if text and text ~= "" then questCache[#questCache + 1] = (text:gsub(":%s*%d+%s*/%s*%d+", "")):lower() end
  end
  if QL and QL.GetNumQuestLogEntries and QL.GetInfo then
    for i = 1, (QL.GetNumQuestLogEntries() or 0) do
      local info = QL.GetInfo(i)
      if info and not info.isHeader and info.questID then
        add(info.title)
        local objs = QL.GetQuestObjectives and QL.GetQuestObjectives(info.questID)
        if objs then
          for _, o in ipairs(objs) do if not o.finished then add(o.text) end end
        end
      end
    end
  elseif GetNumQuestLogEntries then
    for i = 1, (GetNumQuestLogEntries() or 0) do
      local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
      if title and not isHeader and isComplete ~= 1 then
        add(title)
        for j = 1, (GetNumQuestLeaderBoards(i) or 0) do
          local text, _, done = GetQuestLogLeaderBoard(j, i)
          if not done then add(text) end
        end
      end
    end
  end
  return questCache
end

local STOP = { the=1, of=1, a=1, an=1, ["and"]=1, old=1, small=1, large=1 }
local function Norm(t) return (t:lower():gsub("'s%f[%A]", ""):gsub("['`]", "")) end
local function WordMatch(name, text)
  for w in name:gmatch("%a+") do
    if #w >= 4 and not STOP[w] and text:find("%f[%a]" .. w .. "%f[%A]") then return true end
  end
  return false
end

local function IsLootable(name)
  if not name then return false end
  -- dead creatures: lootable or skinnable corpses
  if UnitExists("softinteract") and UnitIsDead("softinteract") then return true end
  local n = name:lower()
  for _, w in ipairs(LOOT_WORDS) do if n:find(w, 1, true) then return true end end
  -- quest objects: name appears in an unfinished objective (e.g. "Bingles' Wrench")
  local nn = Norm(name)
  for _, obj in ipairs(QuestObjectiveText()) do
    local o = Norm(obj)
    if o:find(nn, 1, true) or nn:find(o, 1, true) or WordMatch(nn, o) then return true end
  end
  for w in pairs(ShinyThingsDB.allow) do if n:find(w, 1, true) then return true end end
  return false
end

local hiding = false
local function CheckSoftTarget()
  if not ShinyThingsDB or not ShinyThingsDB.icons or not Supported() then return end
  local name = UnitName("softinteract")
  local ignore = name and (IsIgnored(name) or (ShinyThingsDB.lootOnly and not IsLootable(name)))
  if ignore and not hiding then
    hiding = true
    SetCVar("SoftTargetIconGameObject", "0"); SetCVar("SoftTargetIconInteract", "0")
  elseif not ignore and hiding then
    hiding = false
    SetCVar("SoftTargetIconGameObject", "1"); SetCVar("SoftTargetIconInteract", "1")
  end
end

local function ListIgnore()
  local t = {}
  for w in pairs(ShinyThingsDB.ignore) do t[#t + 1] = w end
  table.sort(t)
  msg("ignored: " .. (#t > 0 and table.concat(t, ", ") or "nothing"))
end

SLASH_SHINYTHINGS1 = "/shiny"
SLASH_SHINYTHINGS2 = "/glow"
SlashCmdList.SHINYTHINGS = function(arg)
  arg = (arg or ""):lower():match("^%s*(.-)%s*$")
  if arg == "" then
    ShinyThingsDB.icons = not ShinyThingsDB.icons
    if ApplyIcons(ShinyThingsDB.icons) then
      msg("object icons " .. (ShinyThingsDB.icons and "|cff00ff00on|r" or "|cffff4040off|r"))
    end
  elseif arg == "status" then Status(); ListIgnore()
    msg("loot-only mode: " .. (ShinyThingsDB.lootOnly and "|cff00ff00on|r" or "|cffff4040off|r"))
  elseif arg == "lootonly" then
    ShinyThingsDB.lootOnly = not ShinyThingsDB.lootOnly
    msg("loot-only mode " .. (ShinyThingsDB.lootOnly and "|cff00ff00on|r" or "|cffff4040off|r")); CheckSoftTarget()
  elseif arg == "allow" then
    local name = UnitName("softinteract")
    if name then ShinyThingsDB.allow[name:lower()] = true; msg("now showing " .. name); CheckSoftTarget() end
  elseif arg:match("^allow ") then
    local w = arg:match("^allow (.+)"); ShinyThingsDB.allow[w] = true; msg("now showing anything named *" .. w .. "*"); CheckSoftTarget()
  elseif arg:match("^unallow ") then
    local w = arg:match("^unallow (.+)"); ShinyThingsDB.allow[w] = nil; msg("removed " .. w); CheckSoftTarget()
  elseif arg == "ignore" then
    local name = UnitName("softinteract")
    if name then ShinyThingsDB.ignore[name:lower()] = true; msg("now ignoring " .. name); CheckSoftTarget()
    else ListIgnore() end
  elseif arg:match("^ignore ") then
    local w = arg:match("^ignore (.+)"); ShinyThingsDB.ignore[w] = true; msg("now ignoring anything named *" .. w .. "*"); CheckSoftTarget()
  elseif arg:match("^unignore ") then
    local w = arg:match("^unignore (.+)"); ShinyThingsDB.ignore[w] = nil; msg("stopped ignoring " .. w); CheckSoftTarget()
  elseif arg == "off" or arg == "track off" then
    ShinyThingsDB.track = nil; msg("stopped remembering tracking.")
  elseif arg:match("^track ") then Track(arg:match("^track (%a+)"))
  elseif TRACK[arg] then Track(arg)
  else
    msg("/shiny - toggle object icons")
    msg("/shiny herbs | ore | treasure | fish - set and remember tracking")
    msg("/shiny ignore - ignore the object the icon is on now")
    msg("/shiny ignore <word> | unignore <word> - edit the ignore list")
    msg("/shiny lootonly - only show icons on lootable things (default on)")
    msg("/shiny allow [word] | unallow <word> - extra things to always show")
    msg("/shiny off - forget tracking   /glow status")
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
pcall(f.RegisterEvent, f, "PLAYER_SOFT_INTERACT_CHANGED")
f:SetScript("OnEvent", function(_, ev)
  if ev == "PLAYER_SOFT_INTERACT_CHANGED" then return CheckSoftTarget() end
  if ev == "PLAYER_LOGIN" then
    ShinyThingsDB = ShinyThingsDB or { icons = true, saved = {} }
    ShinyThingsDB.saved = ShinyThingsDB.saved or {}
    ShinyThingsDB.allow = ShinyThingsDB.allow or {}
    if ShinyThingsDB.lootOnly == nil then ShinyThingsDB.lootOnly = true end
    if not ShinyThingsDB.ignore then
      ShinyThingsDB.ignore = {}
      for _, w in ipairs(DEFAULT_IGNORE) do ShinyThingsDB.ignore[w] = true end
    end
    if not ShinyThingsDB.restored123 then
      for k, v in pairs(RESTORE) do
        if GetCVar(k) ~= nil then SetCVar(k, (ShinyThingsDB.saved[k]) or GetCVarDefault and GetCVarDefault(k) or v) end
        ShinyThingsDB.saved[k] = nil
      end
      ShinyThingsDB.restored123 = true
    end
    if ShinyThingsDB.icons and Supported() then ApplyIcons(true) end
  end
  -- re-apply remembered tracking (lost on death in Classic)
  if ShinyThingsDB and ShinyThingsDB.track then
    C_Timer.After(1.5, function()
      if not UnitIsDeadOrGhost("player") then SetTrackingByName(TRACK[ShinyThingsDB.track][1]) end
    end)
  end
end)

-- Fallback for clients without PLAYER_SOFT_INTERACT_CHANGED
local poll = CreateFrame("Frame")
local elapsed = 0
poll:SetScript("OnUpdate", function(_, dt)
  elapsed = elapsed + dt
  if elapsed > 0.2 then elapsed = 0; CheckSoftTarget() end
end)
