local addonName, bepgp = ...
local moduleName = addonName.."_plusroll_bids"
local bepgp_plusroll_bids = bepgp:NewModule(moduleName, "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local C = LibStub("LibCrayon-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local DF = LibStub("LibDeformat-3.0")
local T = LibStub("LibQTip-1.0")
local LD = LibStub("LibDialog-1.0")
--/run BastionEPGP:GetModule("BastionEPGP_plusroll_bids"):Toggle()
--/run BastionEPGP:GetModule("BastionEPGP_plusroll_bids").bid_item.itemid = 19915
--/run BastionEPGP:GetModule("BastionEPGP_plusroll_bids").bid_item.itemlink = "\124cff0070dd\124Hitem:19915:0:0:0:0:0:0:0:0\124h[Zulian Defender]\124h\124r"
--/run BastionEPGP:GetModule("BastionEPGP_plusroll_bids"):clearRolls()
--/run BastionEPGP:GetModule("BastionEPGP_plusroll_bids"):bidPrint("\124cff0070dd\124Hitem:19915:0:0:0:0:0:0:0:0\124h[Zulian Defender]\124h\124r","Bushido",true)
local colorUnknown = {r=.75, g=.75, b=.75, a=.9}
bepgp_plusroll_bids.bids_res,bepgp_plusroll_bids.bids_main,bepgp_plusroll_bids.bids_off,bepgp_plusroll_bids.bid_item = {},{},{},{}
local bids_blacklist = {}
local bidlink = {
  ["ms"]=L["|cffFF3333|Hbepgproll:1:$ML|h[Mainspec/NEED]|h|r"],
  ["os"]=L["|cff009900|Hbepgproll:2:$ML|h[Offspec/GREED]|h|r"]
}
local out = "|cff9664c8"..addonName..":|r %s"
bepgp_plusroll_bids.running_bid = false
local reserves, plusroll_loot

local roll_sorter_bids = function(a,b)
  -- name, color, roll, wincount
  if a[4] and b[4] and (a[4] ~= b[4]) then
    return tonumber(a[4]) < tonumber(b[4])
  else
    if a[3] ~= b[3] then
      return tonumber(a[3]) > tonumber(b[3])
    else
      return a[1] < b[1]
    end
  end
end

function bepgp_plusroll_bids:OnEnable()
  self:RegisterEvent("CHAT_MSG_SYSTEM", "captureRoll")
  self:RegisterEvent("CHAT_MSG_RAID", "captureLootCall")
  self:RegisterEvent("CHAT_MSG_RAID_LEADER", "captureLootCall")
  self:RegisterEvent("CHAT_MSG_RAID_WARNING", "captureLootCall")
  self:SecureHook("SetItemRef")
  self:RawHook(ItemRefTooltip,"SetHyperlink",true)

  self.qtip = T:Acquire(addonName.."rollsTablet") -- Name, roll, wincount, reserve
  self.qtip:SetColumnLayout(5, "LEFT", "CENTER", "CENTER", "CENTER", "RIGHT")
  self.qtip:ClearAllPoints()
  self.qtip:SetClampedToScreen(true)
  self.qtip:SetClampRectInsets(-100,100,50,-50)
  self.qtip:SetPoint("TOP",UIParent,"TOP",0,-50)
  LD:Register(addonName.."DialogMemberRoll", bepgp:templateCache("DialogMemberRoll"))
end

function bepgp_plusroll_bids:announceWinner(data)
  local name, roll, msos, wincount = data[1], data[2], data[3], data[4]
  local out
  if not wincount then
    wincount = ""
  end
  if msos == "res" then
    out = L["Winning Reserve Roll: %s (%s)%s"]
  elseif msos == "ms" then
    out = L["Winning Mainspec Roll: %s (%s) (+%s)"]
  elseif msos == "os" then
    out = L["Winning Offspec Roll: %s (%s)%s"]
  end
  if out then
    bepgp:widestAudience(out:format(name,roll,wincount))
  end
end

function bepgp_plusroll_bids:announcedisench(data)
  local out = string.format(L["%s >> Disenchant."],data)
  bepgp:widestAudience(out)
end

function bepgp_plusroll_bids:showReserves()
  reserves = reserves or bepgp:GetModule(addonName.."_plusroll_reserves")
  if reserves then
    reserves:Toggle(true)
  end
end

function bepgp_plusroll_bids:updateBids()
  -- {name,class,ep,gp,ep/gp[,main]}
  table.sort(self.bids_res, roll_sorter_bids)
  table.sort(self.bids_main, roll_sorter_bids)
  table.sort(self.bids_off, roll_sorter_bids)
end

function bepgp_plusroll_bids:Refresh()
  local frame = self.qtip
  if not frame then return end
  frame:StopMovingOrSizing() -- free the mouse if we're mid-drag
  frame:Clear()
  frame:SetMovable(true)
  local minep = bepgp.db.profile.minep
  local line
  line = frame:AddHeader()
  frame:SetCell(line,1,L["BastionEPGP bids [roll]"],nil,"CENTER",4)
  frame:SetCell(line,5,"|TInterface\\Buttons\\UI-Panel-MinimizeButton-Up:16:16:2:-2:32:32:8:24:8:24|t",nil,"RIGHT")
  frame:SetCellScript(line,5,"OnMouseUp", function() frame:Hide() end)
  frame:SetCellScript(line,1,"OnMouseDown", function() frame:StartMoving() end)
  frame:SetCellScript(line,1,"OnMouseUp", function() frame:StopMovingOrSizing() end)

  if self.bid_item.itemid then
    line = frame:AddHeader()
    --SetCell spec : lineNum, colNum, value, font, justification, colSpan, provider
    local num_reserves, names = 0
    reserves = reserves or bepgp:GetModule(addonName.."_plusroll_reserves")
    if reserves then
      num_reserves, names = reserves:IsReserved(self.bid_item.itemid)
    end
    frame:SetCell(line,1,C:Orange(L["Item"]),nil,"LEFT",2)
    frame:SetCell(line,3,C:Orange(L["Reserves"]),nil,"RIGHT",2)
    frame:SetCell(line,5,"",nil,"RIGHT")
    line = frame:AddSeparator(2)
    line = frame:AddLine()
    frame:SetCell(line,1,self.bid_item.itemlink,nil,"LEFT",2)
    frame:SetCell(line,3,num_reserves,nil,"RIGHT",2)
    if num_reserves then
      frame:SetCellScript(line,3,"OnMouseUp", bepgp_plusroll_bids.showReserves )
    end
    frame:SetCell(line,5,"|TInterface\\Icons\\spell_holy_removecurse:18|t",nil,"RIGHT")
    frame:SetCellScript(line,5,"OnMouseUp", bepgp_plusroll_bids.announcedisench, bepgp_plusroll_bids.bid_item.itemlink)

    if #(self.bids_res) > 0 then
      line = frame:AddLine(" ")
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Red(L["Reserves"]),nil,"LEFT",5)
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Orange(L["Name"]),nil,"LEFT",3)
      frame:SetCell(line,4,C:Orange(ROLL),nil,"CENTER")
      frame:SetCell(line,5," ",nil,"RIGHT")
      line = frame:AddSeparator(1)
      for i,data in ipairs(self.bids_res) do
        local name, color, roll, wincount = unpack(data)
        local r,g,b = color.r, color.g, color.b
        line = frame:AddLine()
        frame:SetCell(line,1,name,nil,"LEFT",3)
        frame:SetCellTextColor(line,1,r,g,b)
        frame:SetCell(line,4,roll,nil,"CENTER")
        frame:SetCell(line,5,wincount,nil,"RIGHT")
        frame:SetLineScript(line, "OnMouseUp", bepgp_plusroll_bids.announceWinner, {name, roll, "res", wincount})
      end
    end
    if #(self.bids_main) > 0 then
      line = frame:AddLine(" ")
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Gold(L["Mainspec Rolls"]),nil,"LEFT",5)
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Orange(L["Name"]),nil,"LEFT",3)
      frame:SetCell(line,4,C:Orange(ROLL),nil,"CENTER")
      frame:SetCell(line,5,C:Orange(L["Wincount"]),nil,"RIGHT")
      line = frame:AddSeparator(1)
      for i,data in ipairs(self.bids_main) do
        local name, color, roll, wincount = unpack(data)
        local r,g,b = color.r, color.g, color.b
        line = frame:AddLine()
        frame:SetCell(line,1,name,nil,"LEFT",3)
        frame:SetCellTextColor(line,1,r,g,b)
        frame:SetCell(line,4,roll,nil,"CENTER")
        frame:SetCell(line,5,wincount,nil,"RIGHT")
        frame:SetLineScript(line, "OnMouseUp", bepgp_plusroll_bids.announceWinner, {name, roll, "ms", wincount})
      end
    end
    if #(self.bids_off) > 0 then
      line = frame:AddLine(" ")
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Silver(L["Offspec Rolls"]),nil,"LEFT",5)
      line = frame:AddHeader()
      frame:SetCell(line,1,C:Orange(L["Name"]),nil,"LEFT",3)
      frame:SetCell(line,4,C:Orange(ROLL),nil,"CENTER")
      frame:SetCell(line,5,C:Orange(L["Wincount"]),nil,"RIGHT")
      line = frame:AddSeparator(1)
      for i,data in ipairs(self.bids_off) do
        local name, color, roll, wincount = unpack(data)
        local r,g,b = color.r, color.g, color.b
        line = frame:AddLine()
        frame:SetCell(line,1,name,nil,"LEFT",3)
        frame:SetCellTextColor(line,1,r,g,b)
        frame:SetCell(line,4,roll,nil,"CENTER")
        frame:SetCell(line,5,wincount,nil,"RIGHT")
        frame:SetLineScript(line, "OnMouseUp", bepgp_plusroll_bids.announceWinner, {name, roll, "os", wincount})
      end
    end
  end
  frame:UpdateScrolling()
end

function bepgp_plusroll_bids:Toggle(anchor)
  if not T:IsAcquired(addonName.."rollsTablet") then
    self.qtip = T:Acquire(addonName.."rollsTablet") -- Name, roll, wincount, reserve
    self.qtip:SetColumnLayout(5, "LEFT", "CENTER", "CENTER", "CENTER", "RIGHT")
    return
  end
  if self.qtip:IsShown() then
    self.qtip:Hide()
  else
    if anchor then
      self.qtip:SmartAnchorTo(anchor)
    else
      self.qtip:ClearAllPoints()
      self.qtip:SetClampedToScreen(true)
      self.qtip:SetClampRectInsets(-100,100,50,-50)
      self.qtip:SetPoint("TOP",UIParent,"TOP",0,-50)
    end
    self:Refresh()
    self.qtip:Show()
  end
end

function bepgp_plusroll_bids:SetItemRef(link, text, button, chatFrame)
  if string.sub(link,1,9) == "bepgproll" then
    local _,_,bid,masterlooter = string.find(link,"bepgproll:(%d+):(%w+)")
    if bid == "1" then
      bid = "+"
    elseif bid == "2" then
      bid = "-"
    else
      bid = nil
    end
    if not (bepgp:inRaid(masterlooter)) then
      masterlooter = nil
    end -- DEBUG
    if (bid and masterlooter) then
      if bid == "+" then
        RandomRoll("1", "100")
      elseif bid == "-" then
        RandomRoll("1", "50")
      end
    end
    return false
  end
end

function bepgp_plusroll_bids:SetHyperlink(frame, link, ...)
  if string.sub(link,1,9) == "bepgproll" then
    return false
  end
  self.hooks[ItemRefTooltip].SetHyperlink(frame, link, ...)
end

local lootCall = {
  ["roll"] = { -- specifically ordered from narrow to broad
    "^(roll 50)[%s%p%c]+.+",
    ".+[%s%p%c]+(/roll 50)$",".*[%s%p%c]+(/roll 50)[%s%p%c]+.*",
    ".+[%s%p%c]+(roll 50)$",".*[%s%p%c]+(roll 50)[%s%p%c]+.*",
    "^(roll)[%s%p%c]+.+",
    ".+[%s%p%c]+(/roll)$",".*[%s%p%c]+(/roll)[%s%p%c]+.*",
    ".+[%s%p%c]+(roll)$",".*[%s%p%c]+(roll)[%s%p%c]+.*",
  },
}
function bepgp_plusroll_bids:captureLootCall(event, text, sender)
  if not (string.find(text, "|Hitem:", 1, true)) then return end
  local linkstriptext, count = string.gsub(text,"|c%x+|H[eimt:%d]+|h%[[%w%s',%-]+%]|h|r"," ; ")
  if count > 1 then return end
  local lowtext = string.lower(linkstriptext)
  local link_found, rollkw_found
  for _,f in ipairs(lootCall.roll) do
    rollkw_found = string.find(lowtext,f)
    if (rollkw_found) then break end
  end
  sender = Ambiguate(sender,"short") --:gsub("(\-.+)","")
  local _, itemLink, itemColor, itemString, itemName, itemID
  if (rollkw_found) then
    _,_,itemLink = string.find(text,"(|c%x+|H[eimt:%d]+|h%[[%w%s',%-]+%]|h|r)")
    if (itemLink) and (itemLink ~= "") then
      itemColor, itemString, itemName, itemID = bepgp:getItemData(itemLink)
    end
    if (itemName) then
      if (bepgp:lootMaster()) and (sender == bepgp._playerName) then
        self:clearRolls(true)
        bepgp_plusroll_bids.bid_item.itemstring = itemString
        bepgp_plusroll_bids.bid_item.itemlink = itemLink
        bepgp_plusroll_bids.bid_item.itemid = itemID
        bepgp_plusroll_bids.bid_item.name = string.format("%s%s|r",itemColor,itemName)
        self._rollTimer = self:ScheduleTimer("clearRolls",120)
        bepgp_plusroll_bids.running_bid = true
        bepgp:debugPrint(L["Capturing Rolls for 2min."])
        self.qtip:Show()
      end
      self:bidPrint(itemLink,sender,rollkw_found)
    end
  end
end

function bepgp_plusroll_bids:captureRoll(event, text)
  if bepgp.db.char.mode ~= "plusroll" then return end
  if not (bepgp_plusroll_bids.running_bid) then return end -- DEBUG
  if not (bepgp:lootMaster()) then return end -- DEBUG
  if not bepgp_plusroll_bids.bid_item.itemid then return end -- DEBUG
  local who, roll, low, high = DF.Deformat(text, RANDOM_ROLL_RESULT)
  roll, low, high = tonumber(roll),tonumber(low),tonumber(high)
  local msroll, osroll
  local inraid
  if who then
    who = Ambiguate(who,"short")
    inraid = bepgp:inRaid(who)
    if inraid then -- DEBUG
      msroll = (low == 1 and high == 100) and roll
      osroll = (low == 1 and high == 50) and roll
    end -- DEBUG
  end
  if (msroll) or (osroll) then
    if bids_blacklist[who] == nil then
      local cached = bepgp:groupCache(who)
      local color = cached and cached.color or colorUnknown
      if (msroll) then
        bids_blacklist[who] = true
        reserves = reserves or bepgp:GetModule(addonName.."_plusroll_reserves")
        if reserves and (reserves:IsReservedExact(who, bepgp_plusroll_bids.bid_item.itemid)) then
          table.insert(bepgp_plusroll_bids.bids_res,{who,color,msroll})
        else
          plusroll_loot = plusroll_loot or bepgp:GetModule(addonName.."_plusroll_loot")
          local wincount = plusroll_loot and plusroll_loot:getWincount(who) or 0
          table.insert(bepgp_plusroll_bids.bids_main,{who,color,msroll,wincount})
        end
      elseif (osroll) then
        bids_blacklist[who] = true
        table.insert(bepgp_plusroll_bids.bids_off,{who,color,osroll})
      end
      self:updateBids()
      self:Refresh()
      return
    end
  end
end

function bepgp_plusroll_bids:clearRolls(reset)
  if reset~=nil then
    bepgp:debugPrint(L["Clearing old Rolls"])
  else
    self.qtip:Hide()
  end
  table.wipe(bepgp_plusroll_bids.bid_item) -- = {}
  table.wipe(bepgp_plusroll_bids.bids_res) -- = {}
  table.wipe(bepgp_plusroll_bids.bids_main) -- = {}
  table.wipe(bepgp_plusroll_bids.bids_off) -- = {}
  table.wipe(bids_blacklist) -- = {}
  if self._rollTimer then
    self:CancelTimer(self._rollTimer)
    self._rollTimer = nil
  end
  bepgp_plusroll_bids.running_bid = false
  self:updateBids()
  self:Refresh()
end

function bepgp_plusroll_bids:bidPrint(link,masterlooter,bid)
  local mslink = string.gsub(bidlink["ms"],"$ML",masterlooter)
  local oslink = string.gsub(bidlink["os"],"$ML",masterlooter)
  local msg = string.format(L["Click $MS or $OS for %s"],link)
  if (bid) then
    msg = string.gsub(msg,"$MS",mslink)
    msg = string.gsub(msg,"$OS",oslink)
  end
  local _, count = string.gsub(msg,"%$","%$")
  if (count > 0) then return end
  local chatframe
  if (SELECTED_CHAT_FRAME) then
    chatframe = SELECTED_CHAT_FRAME
  else
    if not DEFAULT_CHAT_FRAME:IsVisible() then
      FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
    end
    chatframe = DEFAULT_CHAT_FRAME
  end
  if (chatframe) then
    chatframe:AddMessage(" ")
    chatframe:AddMessage(string.format(out,msg),NORMAL_FONT_COLOR.r,NORMAL_FONT_COLOR.g,NORMAL_FONT_COLOR.b)
    if bepgp.db.char.bidpopup then
      LD:Spawn(addonName.."DialogMemberRoll", link)
    end
    self:updateBids()
    self:Refresh()
  end
end