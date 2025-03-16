local stringmatch = string.match;
local stringgsub = string.gsub;
local pairs = pairs;
local ipairs = ipairs;
local _G = _G;
local keysConfig;

local updateBindings;

local templates = {
  {command = "^ACTIONBUTTON(%d+)$",          attributes = {{"type", "macro"}, {"actionbutton", "%1"}}},
  {command = "^MULTIACTIONBAR1BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton", "MultiBarBottomLeftButton%1"}}},
  {command = "^MULTIACTIONBAR2BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton", "MultiBarBottomRightButton%1"}}},
  {command = "^MULTIACTIONBAR3BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton", "MultiBarRightButton%1"}}},
  {command = "^MULTIACTIONBAR4BUTTON(%d+)$", attributes = {{"type", "click"}, {"clickbutton", "MultiBarLeftButton%1"}}},
  {command = "^SHAPESHIFTBUTTON(%d+)$",      attributes = {{"type", "click"}, {"clickbutton", "ShapeshiftButton%1"}}},
  {command = "^BONUSACTIONBUTTON(%d+)$",     attributes = {{"type", "click"}, {"clickbutton", "PetActionButton%1"}}},
  {command = "^MULTICASTSUMMONBUTTON(%d+)$", attributes = {{"type", "click"}, {"multicastsummon", "%1"}}},
  {command = "^MULTICASTRECALLBUTTON1$",     attributes = {{"type", "click"}, {"clickbutton", "MultiCastRecallSpellButton"}}},
  {command = "^CLICK (.+):([^:]+)$",         attributes = {{"type", "click"}, {"clickbutton", "%1"}}},
  {command = "^MACRO (.+)$",                 attributes = {{"type", "macro"}, {"macro", "%1"}}},
  {command = "^SPELL (.+)$",                 attributes = {{"type", "spell"}, {"spell", "%1"}}},
  {command = "^ITEM (.+)$",                  attributes = {{"type", "item"}, {"item", "%1"}}},
};

local hook = true;

local overrideFrame = CreateFrame("Frame");

local allowedTypeAttributes = {
  ["actionbar"] = true,
  ["action"] = true,
  ["pet"] = true,
  ["multispell"] = true,
  ["spell"] = true,
  ["item"] = true,
  ["macro"] = true,
  ["cancelaura"] = true,
  ["stop"] = true,
  ["target"] = true,
  ["focus"] = true,
  ["assist"] = true,
  ["maintank"] = true,
  ["mainassist"] = true
};

local keys = SnowfallKeyPress.settings.keys;
local modifiers = SnowfallKeyPress.settings.modifiers;

local modifierCombos = {};
local function createModifierCombos(base, modifierNum, modifiers, modifierCombos)
  local modifier = modifiers[modifierNum];
  if (not modifier) then
    table.insert(modifierCombos, base);
    return;
  end

  local nextModifierNum = modifierNum + 1;
  createModifierCombos(base, nextModifierNum, modifiers, modifierCombos);
  createModifierCombos(base .. modifier .. "-", nextModifierNum, modifiers, modifierCombos);
end
createModifierCombos("", 1, modifiers, modifierCombos);

local function keyLess(key1, key2)
  local comp1, comp2;

  comp1 = string.gsub(key1, "^.*%-(.+)", "%1", 1);
  comp2 = string.gsub(key2, "^.*%-(.+)", "%1", 1);
  if (comp1 < comp2) then
    return true;
  elseif (comp1 > comp2) then
    return false;
  end

  comp1 = string.match(key1, "ALT%-");
  comp2 = string.match(key2, "ALT%-");
  if (not comp1 and comp2) then
    return true;
  elseif (comp1 and not comp2) then
    return false;
  end

  comp1 = string.match(key1, "CTRL%-");
  comp2 = string.match(key2, "CTRL%-");
  if (not comp1 and comp2) then
    return true;
  elseif (comp1 and not comp2) then
    return false;
  end

  comp1 = string.match(key1, "SHIFT%-");
  comp2 = string.match(key2, "SHIFT%-");
  if (not comp1 and comp2) then
    return true;
  elseif (comp1 and not comp2) then
    return false;
  end

  return nil;
end

function insertKey(key)
  local less, position;
  position = 0;
  for k, v in ipairs(keysConfig) do
    less = keyLess(key, v);
    if (less == nil) then
      return nil;
    elseif (less == true) then
      break;
    end
    position = k;
  end
  position = position + 1;
  table.insert(keysConfig, position, key);
  return position;
end

local function removeKey(key)
  for k, v in ipairs(keysConfig) do
    if (key == v) then
      table.remove(keysConfig, k);
      return k;
    end
  end
  return false;
end

local scrollBarUpdate;

local function populateKeysConfig()
  wipe(keysConfig);
  for _, key in ipairs(keys) do
    if (stringmatch(key, "-.")) then
      insertKey(stringmatch(key, "^-?(.*)$"));
    else
      for _, modifierCombo in ipairs(modifierCombos) do
        insertKey(modifierCombo .. key);
      end
    end
  end
end

local configFrame = CreateFrame("Frame", nil, UIParent);
configFrame:SetWidth(420);
configFrame:SetHeight(310);
configFrame:SetPoint("TOPLEFT", 200, -200);
configFrame:SetBackdrop({
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 16,
  insets = {left = 4, right = 4, top = 4, bottom = 4},
});
configFrame:Hide();

configFrame.name = "SnowfallKeyPress";

configFrame.title = configFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
configFrame.title:SetPoint("TOPLEFT", 16, -16);
configFrame.title:SetPoint("RIGHT");
configFrame.title:SetText(configFrame.name);
configFrame.title:SetJustifyH("LEFT");

local modifierCombosConfig = {};
createModifierCombos("", 1, modifiers, modifierCombosConfig);

local function addAll(_, key)
  if (
    key == "UNKNOWN"
    or key == "LSHIFT"
    or key == "RSHIFT"
    or key == "LCTRL"
    or key == "RCTRL"
    or key == "LALT"
    or key == "RALT"
  ) then
    return;
  end
  if (key == "LeftButton") then
    key = "BUTTON1"
  elseif (key == "RightButton") then
    key = "BUTTON2"
  elseif (key == "MiddleButton") then
    key = "BUTTON3"
  else
    key = string.gsub(key, "^Button(%d+)$", "BUTTON%1");
  end

  for k, modifierCombo in ipairs(modifierCombosConfig) do
    insertKey(modifierCombo .. key);
  end
  scrollBarUpdate();
  updateBindings();
end

local function addOne(_, key)
  if (
    key == "UNKNOWN"
    or key == "LSHIFT"
    or key == "RSHIFT"
    or key == "LCTRL"
    or key == "RCTRL"
    or key == "LALT"
    or key == "RALT"
  ) then
    return;
  end
  if (key == "LeftButton") then
    key = "BUTTON1"
  elseif (key == "RightButton") then
    key = "BUTTON2"
  elseif (key == "MiddleButton") then
    key = "BUTTON3"
  else
    key = string.gsub(key, "^Button(%d+)$", "BUTTON%1");
  end
  if (IsShiftKeyDown()) then
    key = "SHIFT-" .. key;
  end
  if (IsControlKeyDown()) then
    key = "CTRL-" .. key;
  end
  if (IsAltKeyDown()) then
    key = "ALT-" .. key;
  end

  insertKey(key);
  scrollBarUpdate();
  updateBindings();
end

local function subAll(_, key)
  if (
    key == "UNKNOWN"
    or key == "LSHIFT"
    or key == "RSHIFT"
    or key == "LCTRL"
    or key == "RCTRL"
    or key == "LALT"
    or key == "RALT"
  ) then
    return;
  end
  if (key == "LeftButton") then
    key = "BUTTON1"
  elseif (key == "RightButton") then
    key = "BUTTON2"
  elseif (key == "MiddleButton") then
    key = "BUTTON3"
  else
    key = string.gsub(key, "^Button(%d+)$", "BUTTON%1");
  end

  for k, modifierCombo in ipairs(modifierCombosConfig) do
    removeKey(modifierCombo .. key);
  end
  scrollBarUpdate();
  updateBindings();
end

local function subOne(_, key)
  if (
    key == "UNKNOWN"
    or key == "LSHIFT"
    or key == "RSHIFT"
    or key == "LCTRL"
    or key == "RCTRL"
    or key == "LALT"
    or key == "RALT"
  ) then
    return;
  end
  if (key == "LeftButton") then
    key = "BUTTON1"
  elseif (key == "RightButton") then
    key = "BUTTON2"
  elseif (key == "MiddleButton") then
    key = "BUTTON3"
  else
    key = string.gsub(key, "^Button(%d+)$", "BUTTON%1");
  end
  if (IsShiftKeyDown()) then
    key = "SHIFT-" .. key;
  end
  if (IsControlKeyDown()) then
    key = "CTRL-" .. key;
  end
  if (IsAltKeyDown()) then
    key = "ALT-" .. key;
  end

  removeKey(key);
  scrollBarUpdate();
  updateBindings();
end

configFrame.addAllButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate");
configFrame.addAllButton:SetWidth(130);
configFrame.addAllButton:SetHeight(44);
configFrame.addAllButton:SetPoint("TOPLEFT", 16, -42);
configFrame.addAllButton:SetText("+\n(" .. MODIFIERS_COLON .. " " .. ALL .. ")");
configFrame.addAllButton:SetFrameStrata("DIALOG");
configFrame.addAllButton:SetScript("OnEnter", function(self) self:EnableKeyboard(true); end);
configFrame.addAllButton:SetScript("OnLeave", function(self) self:EnableKeyboard(false); end);
configFrame.addAllButton:SetScript("OnKeyDown", addAll);
configFrame.addAllButton:SetScript("OnClick", addAll);
configFrame.addAllButton:RegisterForClicks("AnyUp");

configFrame.addButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate");
configFrame.addButton:SetWidth(65);
configFrame.addButton:SetHeight(22);
configFrame.addButton:SetPoint("TOPLEFT", configFrame.addAllButton, "BOTTOMLEFT", 0, 0);
configFrame.addButton:SetText("+");
configFrame.addButton:SetFrameStrata("DIALOG");
configFrame.addButton:SetScript("OnEnter", function(self) self:EnableKeyboard(true); end);
configFrame.addButton:SetScript("OnLeave", function(self) self:EnableKeyboard(false); end);
configFrame.addButton:SetScript("OnKeyDown", addOne);
configFrame.addButton:SetScript("OnClick", addOne);
configFrame.addButton:RegisterForClicks("AnyUp");

configFrame.subButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate");
configFrame.subButton:SetWidth(65);
configFrame.subButton:SetHeight(22);
configFrame.subButton:SetPoint("TOPLEFT", configFrame.addButton, "TOPRIGHT", 0, 0);
configFrame.subButton:SetText("-");
configFrame.subButton:SetFrameStrata("DIALOG");
configFrame.subButton:SetScript("OnEnter", function(self) self:EnableKeyboard(true); end);
configFrame.subButton:SetScript("OnLeave", function(self) self:EnableKeyboard(false); end);
configFrame.subButton:SetScript("OnKeyDown", subOne);
configFrame.subButton:SetScript("OnClick", subOne);
configFrame.subButton:RegisterForClicks("AnyUp");

configFrame.subAllButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate");
configFrame.subAllButton:SetWidth(130);
configFrame.subAllButton:SetHeight(44);
configFrame.subAllButton:SetPoint("TOPRIGHT", configFrame.subButton, "BOTTOMRIGHT", 0, 0);
configFrame.subAllButton:SetText("-\n(" .. MODIFIERS_COLON .. " " .. ALL .. ")");
configFrame.subAllButton:SetFrameStrata("DIALOG");
configFrame.subAllButton:SetScript("OnEnter", function(self) self:EnableKeyboard(true); end);
configFrame.subAllButton:SetScript("OnLeave", function(self) self:EnableKeyboard(false); end);
configFrame.subAllButton:SetScript("OnKeyDown", subAll);
configFrame.subAllButton:SetScript("OnClick", subAll);
configFrame.subAllButton:RegisterForClicks("AnyUp");

configFrame.clearAllButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate");
configFrame.clearAllButton:SetWidth(130);
configFrame.clearAllButton:SetHeight(22);
configFrame.clearAllButton:SetPoint("TOPLEFT", configFrame.addAllButton, "TOPRIGHT", 40, 0);
configFrame.clearAllButton:SetText(CLEAR_ALL);
configFrame.clearAllButton:SetScript("OnClick", function() wipe(keysConfig); scrollBarUpdate(); updateBindings(); end);

configFrame.resetDefaultButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate");
configFrame.resetDefaultButton:SetWidth(130);
configFrame.resetDefaultButton:SetHeight(22);
configFrame.resetDefaultButton:SetPoint("TOPRIGHT", configFrame.clearAllButton, "BOTTOMRIGHT", 0, 0);
configFrame.resetDefaultButton:SetText(RESET_TO_DEFAULT);
configFrame.resetDefaultButton:SetScript("OnClick", function() populateKeysConfig(); scrollBarUpdate(); updateBindings(); end);

configFrame.enableButton = CreateFrame("CheckButton", "SnowfallKeyPress_configFrameEnableButton", configFrame, "UICheckButtonTemplate");
configFrame.enableButton:SetWidth(22);
configFrame.enableButton:SetHeight(22);
configFrame.enableButton:SetPoint("TOPLEFT", configFrame.resetDefaultButton, "BOTTOMLEFT", 0, -40);
SnowfallKeyPress_configFrameEnableButtonText:SetText(ENABLE);
configFrame.enableButton:SetScript("OnClick", function(self) if (self:GetChecked()) then SnowfallKeyPressSV.enable = true; hook = true; overrideFrame:RegisterEvent("UPDATE_BINDINGS"); updateBindings(); else SnowfallKeyPressSV.enable = false; updateBindings(); end end);

configFrame.keyFrame = CreateFrame("Frame", nil, configFrame);
configFrame.keyFrame:SetWidth(322);
configFrame.keyFrame:SetHeight(16 * 16 + 12);
configFrame.keyFrame:SetPoint("TOPLEFT", 16, -155);
configFrame.keyFrame:SetBackdrop({
  bgFile = "Interface\\BUTTONS\\WHITE8X8.BLP",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  edgeSize = 16,
  insets = {left = 4, right = 4, top = 4, bottom = 4},
});
configFrame.keyFrame:SetBackdropColor(0, 0, 0, 0);

local numRows = 16;
configFrame.keyRows = {};
for i = 1, 16 do
  configFrame.keyRows[i] = configFrame:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall");
  configFrame.keyRows[i]:SetWidth(314);
  configFrame.keyRows[i]:SetHeight(16);
  configFrame.keyRows[i]:SetPoint("TOPLEFT", 16, -146 - 16 * i);
  configFrame.keyRows[i]:SetJustifyH("RIGHT");
  configFrame.keyRows[i]:SetText(i);
end
function scrollBarUpdate()
  FauxScrollFrame_Update(configFrame.scrollBar, #keysConfig, numRows, 16);
  local offset = FauxScrollFrame_GetOffset(configFrame.scrollBar);
  for i = 1, 16 do
    configFrame.keyRows[i]:SetText(keysConfig[offset + i]);
  end
end
configFrame.scrollBar = CreateFrame("ScrollFrame", "SnowfallKeyPress_configFrameScrollBar", configFrame, "FauxScrollFrameTemplate");
configFrame.scrollBar:SetWidth(316);
configFrame.scrollBar:SetHeight(16 * 16);
configFrame.scrollBar:SetPoint("TOPLEFT", 16, -162);
configFrame.scrollBar:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, 16, scrollBarUpdate); end);
configFrame.scrollBarTextureTop = configFrame.scrollBar:CreateTexture();
configFrame.scrollBarTextureTop:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar");
configFrame.scrollBarTextureTop:SetWidth(31);
configFrame.scrollBarTextureTop:SetHeight(256);
configFrame.scrollBarTextureTop:SetPoint("TOPLEFT", configFrame.scrollBar, "TOPRIGHT", -2, 5);
configFrame.scrollBarTextureTop:SetTexCoord(0, 0.484375, 0, 1);
configFrame.scrollBarTextureBottom = configFrame.scrollBar:CreateTexture();
configFrame.scrollBarTextureBottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar");
configFrame.scrollBarTextureBottom:SetWidth(31);
configFrame.scrollBarTextureBottom:SetHeight(106);
configFrame.scrollBarTextureBottom:SetPoint("BOTTOMLEFT", configFrame.scrollBar, "BOTTOMRIGHT", -2, -2);
configFrame.scrollBarTextureBottom:SetTexCoord(0.515625, 1, 0, 0.4140625);

hooksecurefunc("ShowUIPanel", function() if (KeyBindingFrame) then KeyBindingFrame.mode = nil; end end);

local function isSecureButton(x)
  return not not (
    type(x) == "table"
    and type(x.IsObjectType) == "function"
    and issecurevariable(x, "IsObjectType")
    and x:IsObjectType("Button")
    and select(2, x:IsProtected())
  );
end

local function accelerateKey(key, command)
  local bindButtonName, bindButton;
  local attributeName, attributeValue;
  local mouseButton, harmButton, helpButton;
  local mouseType, harmType, helpType;
  local clickButtonName, clickButton;

  for _, template in ipairs(templates) do
    if (stringmatch(command, template.command)) then
      if (template.attributes) then
        clickButtonName, mouseButton = stringmatch(command, "^CLICK (.+):([^:]+)$");
        if (clickButtonName) then
          clickButton = _G[clickButtonName];
          if (not isSecureButton(clickButton) or clickButton:GetAttribute("", "downbutton", mouseButton)) then
            return;
          end
          harmButton = SecureButton_GetModifiedAttribute(clickButton, "harmbutton", mouseButton);
          helpButton = SecureButton_GetModifiedAttribute(clickButton, "helpbutton", mouseButton);
          mouseType = SecureButton_GetModifiedAttribute(clickButton, "type", mouseButton);
          harmType = SecureButton_GetModifiedAttribute(clickButton, "type", harmButton);
          helpType = SecureButton_GetModifiedAttribute(clickButton, "type", helpButton);
          if (
            mouseType and not allowedTypeAttributes[mouseType]
            or harmType and not allowedTypeAttributes[harmType]
            or helpType and not allowedTypeAttributes[helpType]
          ) then
            return;
          end
        else
          mouseButton = "LeftButton";
        end

        bindButtonName = "SnowfallKeyPress_Button_" .. key;
        bindButton = _G[bindButtonName];
        if (not bindButton) then
          bindButton = CreateFrame("Button", "SnowfallKeyPress_Button_" .. key, nil, "SecureActionButtonTemplate");
          bindButton:RegisterForClicks("AnyDown");
          SecureHandlerSetFrameRef(bindButton, "VehicleMenuBar", VehicleMenuBar);
          SecureHandlerSetFrameRef(bindButton, "BonusActionBarFrame", BonusActionBarFrame);
          SecureHandlerSetFrameRef(bindButton, "MultiCastSummonSpellButton", MultiCastSummonSpellButton);
          SecureHandlerExecute(
            bindButton,
            [[
              VehicleMenuBar = self:GetFrameRef("VehicleMenuBar");
              BonusActionBarFrame = self:GetFrameRef("BonusActionBarFrame");
              MultiCastSummonSpellButton = self:GetFrameRef("MultiCastSummonSpellButton");
            ]]
          );
        end

        SecureHandlerUnwrapScript(bindButton, "OnClick");

        for _, attribute in ipairs(template.attributes) do
          attributeName = attribute[1];
          attributeValue = stringgsub(command, template.command, attribute[2], 1);

          if (attributeName == "clickbutton") then
            bindButton:SetAttribute(attributeName, _G[attributeValue]);
          elseif (attributeName == "actionbutton") then
            SecureHandlerWrapScript(
              bindButton, "OnClick", bindButton,
              [[
                local clickMacro = "/click ActionButton]] .. attributeValue .. [[";
                if (VehicleMenuBar:IsProtected() and VehicleMenuBar:IsShown() and ]] .. tostring(tonumber(attributeValue) <= VEHICLE_MAX_ACTIONBUTTONS) .. [[) then
                  clickMacro = "/click VehicleMenuBarActionButton]] .. attributeValue .. [[";
                elseif (BonusActionBarFrame:IsProtected() and BonusActionBarFrame:IsShown()) then
                  clickMacro = "/click BonusActionButton]] .. attributeValue .. [[";
                end
                self:SetAttribute("macrotext", clickMacro);
              ]]
            );
          elseif (attributeName == "multicastsummon") then
            SecureHandlerWrapScript(
              bindButton, "OnClick", bindButton,
              [[
                lastID = MultiCastSummonSpellButton:GetID();
                MultiCastSummonSpellButton:SetID(]] .. attributeValue .. [[);
              ]],
              [[
                MultiCastSummonSpellButton:SetID(lastID);
              ]]
            );
            bindButton:SetAttribute("clickbutton", MultiCastSummonSpellButton);
          else
            bindButton:SetAttribute(attributeName, attributeValue);
          end
        end

        hook = false;
        SetOverrideBindingClick(overrideFrame, true, key, bindButtonName, mouseButton);
        hook = true;
      end

      return;
    end
  end
end

function updateBindings()
  if (InCombatLockdown()) then
    return;
  end

  hook = false;
  ClearOverrideBindings(overrideFrame);
  hook = true;

  if (not SnowfallKeyPressSV.enable) then
    overrideFrame:UnregisterEvent("UPDATE_BINDINGS");
    hook = false;
    return;
  end

  local command;
  for _, key in ipairs(keysConfig) do
    command = GetBindingAction(key, true);
    if (command) then
      accelerateKey(key, command);
    end
  end
end

local function setOverrideBindingHook(_, _, overrideKey)
  if (not hook or InCombatLockdown()) then
    return;
  end

  local command;
  for _, key in ipairs(keysConfig) do
    if (overrideKey == key) then
      hook = false;
      SetOverrideBinding(overrideFrame, false, overrideKey, nil);
      hook = true;
      command = GetBindingAction(overrideKey, true);
      if (command) then
        accelerateKey(overrideKey, command);
      end
      break;
    end
  end
end
hooksecurefunc("SetOverrideBinding", setOverrideBindingHook);
hooksecurefunc("SetOverrideBindingSpell", setOverrideBindingHook);
hooksecurefunc("SetOverrideBindingClick", setOverrideBindingHook);
hooksecurefunc("SetOverrideBindingItem", setOverrideBindingHook);
hooksecurefunc("SetOverrideBindingMacro", setOverrideBindingHook);

local function clearOverrideBindingsHook()
  if (not hook) then
    return;
  end

  updateBindings();
end
hooksecurefunc("ClearOverrideBindings", clearOverrideBindingsHook);

local function addonLoaded()
  if (not SnowfallKeyPressSV) then
    SnowfallKeyPressSV = {keys = {}, enable = true};
  end
  keysConfig = SnowfallKeyPressSV.keys;

  configFrame.enableButton:SetChecked(SnowfallKeyPressSV.enable);

  if (#keysConfig == 0) then
    populateKeysConfig();
  end

  scrollBarUpdate();

  InterfaceOptions_AddCategory(configFrame);

  overrideFrame:UnregisterAllEvents();
  overrideFrame:SetScript("OnEvent", updateBindings);
  overrideFrame:RegisterEvent("UPDATE_BINDINGS");
end
overrideFrame:SetScript("OnEvent", addonLoaded);
overrideFrame:RegisterEvent("ADDON_LOADED");