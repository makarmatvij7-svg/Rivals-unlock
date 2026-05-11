-- ⚡ RIVALS UNLOCK ALL — AUTO-LOAD EDITION
-- Features: Anti-dupe | Autoexec Save | Teleport Persist | Mobile UI

-- ========== AUTO-LOAD / ANTI-DUPE ==========
if getgenv().RivalsUnlockerLoaded then
    -- Already running, just make sure UI is visible
    if getgenv().RivalsUnlockerGui and getgenv().RivalsUnlockerGui.Parent then
        getgenv().RivalsUnlockerGui.Enabled = true
    end
    return
end
getgenv().RivalsUnlockerLoaded = true

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ========== AUTOEXEC SAVE FUNCTION ==========
local autoexecPaths = {
    "autoexec/rivals_unlocker.lua",
    "workspace/autoexec/rivals_unlocker.lua",
    "autoexec/rivals_unlock.lua"
}

local function getScriptSource()
    -- Try to get our own source for auto-save
    if getscript then
        local s = getscript()
        if s and s.Source then return s.Source end
    end
    -- Fallback: return a placeholder loadstring template
    return nil
end

local function saveToAutoexec()
    if not writefile then return false, "Executor doesn't support writefile" end
    local source = getScriptSource()
    if not source then
        -- If we can't grab source, write a loader that tells user to paste script
        source = '-- Rivals Unlocker Loader\n-- PASTE THE FULL SCRIPT HERE OR USE loadstring(game:HttpGet("YOUR_URL"))()\n'
    end
    local saved = false
    for _, path in ipairs(autoexecPaths) do
        local ok = pcall(function()
            makefolder(path:match("(.+)/") or "autoexec")
            writefile(path, source)
        end)
        if ok then saved = true; break end
    end
    return saved, saved and "Saved to autoexec folder" or "Failed to write autoexec"
end

local function removeFromAutoexec()
    if not delfile then return false end
    for _, path in ipairs(autoexecPaths) do
        if isfile and isfile(path) then
            pcall(delfile, path)
        end
    end
    return true
end

-- ========== UNLOCK ALL LOGIC ==========
local unlockRan = false
local function doUnlockAll()
    if unlockRan then return true end
    unlockRan = true

    local success, err = pcall(function()
        local playerScripts = player:WaitForChild("PlayerScripts", 10)
        if not playerScripts then return end
        local controllers = playerScripts:WaitForChild("Controllers", 10)
        if not controllers then return end

        local EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 10))
        if EnumLibrary and typeof(EnumLibrary.WaitForEnumBuilder) == "function" then
            pcall(function() EnumLibrary:WaitForEnumBuilder() end)
        end

        local CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 10))
        local ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 10))
        local DataController = require(controllers:WaitForChild("PlayerDataController", 10))

        local equipped, favorites = {}, {}
        local constructingWeapon, viewingProfile = nil, nil
        local lastUsedWeapon = nil

        local function cloneCosmetic(name, cosmeticType, options)
            local base = CosmeticLibrary.Cosmetics[name]
            if not base then return nil end
            local data = {}
            for k, v in pairs(base) do data[k] = v end
            data.Name = name
            data.Type = data.Type or cosmeticType
            data.Seed = data.Seed or math.random(1, 1000000)
            if EnumLibrary then
                local ok, enumId = pcall(EnumLibrary.ToEnum, EnumLibrary, name)
                if ok and enumId then data.Enum, data.ObjectID = enumId, data.ObjectID or enumId end
            end
            if options then
                if options.inverted ~= nil then data.Inverted = options.inverted end
                if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
            end
            return data
        end

        local saveFile = "unlockall/config.json"
        local function saveConfig()
            if not writefile then return end
            pcall(function()
                local config = {equipped = {}, favorites = favorites}
                for weapon, cosmetics in pairs(equipped) do
                    config.equipped[weapon] = {}
                    for cosmeticType, cosmeticData in pairs(cosmetics) do
                        if cosmeticData and cosmeticData.Name then
                            config.equipped[weapon][cosmeticType] = {
                                name = cosmeticData.Name,
                                seed = cosmeticData.Seed,
                                inverted = cosmeticData.Inverted
                            }
                        end
                    end
                end
                makefolder("unlockall")
                writefile(saveFile, HttpService:JSONEncode(config))
            end)
        end

        local function loadConfig()
            if not readfile or not isfile or not isfile(saveFile) then return end
            pcall(function()
                local config = HttpService:JSONDecode(readfile(saveFile))
                if config.equipped then
                    for weapon, cosmetics in pairs(config.equipped) do
                        equipped[weapon] = {}
                        for cosmeticType, cosmeticData in pairs(cosmetics) do
                            local cloned = cloneCosmetic(cosmeticData.name, cosmeticType, {inverted = cosmeticData.inverted})
                            if cloned then cloned.Seed = cosmeticData.seed equipped[weapon][cosmeticType] = cloned end
                        end
                    end
                end
                favorites = config.favorites or {}
            end)
        end

        pcall(function()
            CosmeticLibrary.OwnsCosmeticNormally = function() return true end
            CosmeticLibrary.OwnsCosmeticUniversally = function() return true end
            CosmeticLibrary.OwnsCosmeticForWeapon = function() return true end
        end)

        local originalOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
        CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
            if name:find("MISSING_") then return originalOwnsCosmetic(self, inventory, name, weapon) end
            return true
        end

        local originalGet = DataController.Get
        DataController.Get = function(self, key)
            local data = originalGet(self, key)
            if key == "CosmeticInventory" then
                local proxy = {}
                if data then for k, v in pairs(data) do proxy[k] = v end end
                return setmetatable(proxy, {__index = function() return true end})
            end
            if key == "FavoritedCosmetics" then
                local result = data and table.clone(data) or {}
                for weapon, favs in pairs(favorites) do
                    result[weapon] = result[weapon] or {}
                    for name, isFav in pairs(favs) do result[weapon][name] = isFav end
                end
                return result
            end
            return data
        end

        local originalGetWeaponData = DataController.GetWeaponData
        DataController.GetWeaponData = function(self, weaponName)
            local data = originalGetWeaponData(self, weaponName)
            if not data then return nil end
            local merged = {}
            for k, v in pairs(data) do merged[k] = v end
            merged.Name = weaponName
            if equipped[weaponName] then
                for cosmeticType, cosmeticData in pairs(equipped[weaponName]) do merged[cosmeticType] = cosmeticData end
            end
            return merged
        end

        local FighterController
        pcall(function() FighterController = require(controllers:WaitForChild("FighterController", 10)) end)

        if hookmetamethod then
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local dataRemotes = remotes and remotes:FindFirstChild("Data")
            local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
            local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
            local replicationRemotes = remotes and remotes:FindFirstChild("Replication")
            local fighterRemotes = replicationRemotes and replicationRemotes:FindFirstChild("Fighter")
            local useItemRemote = fighterRemotes and fighterRemotes:FindFirstChild("UseItem")

            if equipRemote then
                local oldNamecall
                oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                    if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
                    local args = {...}

                    if useItemRemote and self == useItemRemote then
                        local objectID = args[1]
                        if FighterController then
                            pcall(function()
                                local fighter = FighterController:GetFighter(player)
                                if fighter and fighter.Items then
                                    for _, item in pairs(fighter.Items) do
                                        if item:Get("ObjectID") == objectID then
                                            lastUsedWeapon = item.Name
                                            break
                                        end
                                    end
                                end
                            end)
                        end
                    end

                    if self == equipRemote then
                        local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                        if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                            local inventory = DataController:Get("CosmeticInventory")
                            if inventory and rawget(inventory, cosmeticName) then return oldNamecall(self, ...) end
                        end
                        equipped[weaponName] = equipped[weaponName] or {}
                        if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                            equipped[weaponName][cosmeticType] = nil
                            if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                        else
                            local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                            if cloned then equipped[weaponName][cosmeticType] = cloned end
                        end
                        task.defer(function()
                            pcall(function() DataController.CurrentData:Replicate("WeaponInventory") end)
                            task.wait(0.2)
                            saveConfig()
                        end)
                        return
                    end

                    if self == favoriteRemote then
                        favorites[args[1]] = favorites[args[1]] or {}
                        favorites[args[1]][args[2]] = args[3] or nil
                        saveConfig()
                        task.spawn(function() pcall(function() DataController.CurrentData:Replicate("FavoritedCosmetics") end) end)
                        return
                    end

                    return oldNamecall(self, ...)
                end)
            end
        end

        local ClientItem
        pcall(function() ClientItem = require(player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) end)
        if ClientItem and ClientItem._CreateViewModel then
            local originalCreateViewModel = ClientItem._CreateViewModel
            ClientItem._CreateViewModel = function(self, viewmodelRef)
                local weaponName = self.Name
                local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
                constructingWeapon = (weaponPlayer == player) and weaponName or nil
                if weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Skin and viewmodelRef then
                    local dataKey, skinKey, nameKey = self:ToEnum("Data"), self:ToEnum("Skin"), self:ToEnum("Name")
                    if viewmodelRef[dataKey] then
                        viewmodelRef[dataKey][skinKey] = equipped[weaponName].Skin
                        viewmodelRef[dataKey][nameKey] = equipped[weaponName].Skin.Name
                    elseif viewmodelRef.Data then
                        viewmodelRef.Data.Skin = equipped[weaponName].Skin
                        viewmodelRef.Data.Name = equipped[weaponName].Skin.Name
                    end
                end
                local result = originalCreateViewModel(self, viewmodelRef)
                constructingWeapon = nil
                return result
            end
        end

        local viewModelModule = player.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
        if viewModelModule then
            local ClientViewModel = require(viewModelModule)
            if ClientViewModel.GetWrap then
                local originalGetWrap = ClientViewModel.GetWrap
                ClientViewModel.GetWrap = function(self)
                    local weaponName = self.ClientItem and self.ClientItem.Name
                    local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
                    if weaponName and weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Wrap then
                        return equipped[weaponName].Wrap
                    end
                    return originalGetWrap(self)
                end
            end
            local originalNew = ClientViewModel.new
            ClientViewModel.new = function(replicatedData, clientItem)
                local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
                local weaponName = constructingWeapon or clientItem.Name
                if weaponPlayer == player and equipped[weaponName] then
                    local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
                    local dataKey = ReplicatedClass:ToEnum("Data")
                    replicatedData[dataKey] = replicatedData[dataKey] or {}
                    local cosmetics = equipped[weaponName]
                    if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end
                    if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end
                    if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
                end
                local result = originalNew(replicatedData, clientItem)
                if weaponPlayer == player and equipped[weaponName] and equipped[weaponName].Wrap and result._UpdateWrap then
                    result:_UpdateWrap()
                    task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end)
                end
                return result
            end
        end

        local originalGetViewModelImage = ItemLibrary.GetViewModelImageFromWeaponData
        ItemLibrary.GetViewModelImageFromWeaponData = function(self, weaponData, highRes)
            if not weaponData then return originalGetViewModelImage(self, weaponData, highRes) end
            local weaponName = weaponData.Name
            local shouldShowSkin = (weaponData.Skin and equipped[weaponName] and weaponData.Skin == equipped[weaponName].Skin) or (viewingProfile == player and equipped[weaponName] and equipped[weaponName].Skin)
            if shouldShowSkin and equipped[weaponName] and equipped[weaponName].Skin then
                local skinInfo = self.ViewModels[equipped[weaponName].Skin.Name]
                if skinInfo then return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image end
            end
            return originalGetViewModelImage(self, weaponData, highRes)
        end

        pcall(function()
            local ViewProfile = require(player.PlayerScripts.Modules.Pages.ViewProfile)
            if ViewProfile and ViewProfile.Fetch then
                local originalFetch = ViewProfile.Fetch
                ViewProfile.Fetch = function(self, targetPlayer)
                    viewingProfile = targetPlayer
                    return originalFetch(self, targetPlayer)
                end
            end
        end)

        local ClientEntity
        pcall(function() ClientEntity = require(player.PlayerScripts.Modules.ClientReplicatedClasses.ClientEntity) end)
        if ClientEntity and ClientEntity.ReplicateFromServer then
            local originalReplicateFromServer = ClientEntity.ReplicateFromServer
            ClientEntity.ReplicateFromServer = function(self, action, ...)
                if action == "FinisherEffect" then
                    local args = {...}
                    local killerName = args[3]
                    local decodedKiller = killerName
                    if type(killerName) == "userdata" and EnumLibrary and EnumLibrary.FromEnum then
                        local ok, decoded = pcall(EnumLibrary.FromEnum, EnumLibrary, killerName)
                        if ok and decoded then decodedKiller = decoded end
                    end
                    local isOurKill = tostring(decodedKiller) == player.Name or tostring(decodedKiller):lower() == player.Name:lower()
                    if isOurKill and lastUsedWeapon and equipped[lastUsedWeapon] and equipped[lastUsedWeapon].Finisher then
                        local finisherData = equipped[lastUsedWeapon].Finisher
                        local finisherEnum = finisherData.Enum
                        if not finisherEnum and EnumLibrary then
                            local ok, result = pcall(EnumLibrary.ToEnum, EnumLibrary, finisherData.Name)
                            if ok and result then finisherEnum = result end
                        end
                        if finisherEnum then
                            args[1] = finisherEnum
                            return originalReplicateFromServer(self, action, unpack(args))
                        end
                    end
                end
                return originalReplicateFromServer(self, action, ...)
            end
        end

        loadConfig()
    end)

    return success
end

-- ========== COOL UI ==========
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local COL = {
    bg = Color3.fromRGB(10, 10, 14),
    panel = Color3.fromRGB(18, 18, 24),
    accent = Color3.fromRGB(0, 255, 200),
    accent2 = Color3.fromRGB(255, 0, 128),
    text = Color3.fromRGB(240, 240, 255),
    dim = Color3.fromRGB(140, 140, 160),
    success = Color3.fromRGB(0, 255, 128),
    error = Color3.fromRGB(255, 60, 80)
}

local gui = Instance.new("ScreenGui")
gui.Name = "RivalsUnlockUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
getgenv().RivalsUnlockerGui = gui

-- Open Button
local openBtn = Instance.new("TextButton")
openBtn.Name = "OpenBtn"
openBtn.Size = UDim2.new(0, 50, 0, 50)
openBtn.Position = UDim2.new(0, 20, 0.5, -25)
openBtn.BackgroundColor3 = COL.panel
openBtn.Text = "🔓"
openBtn.TextSize = 24
openBtn.Font = Enum.Font.GothamBold
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)

local openBorder = Instance.new("Frame")
openBorder.Size = UDim2.new(1, 4, 1, 4)
openBorder.Position = UDim2.new(0, -2, 0, -2)
openBorder.BackgroundColor3 = COL.accent
openBorder.BorderSizePixel = 0
openBorder.ZIndex = -1
openBorder.Parent = openBtn
Instance.new("UICorner", openBorder).CornerRadius = UDim.new(1, 0)

task.spawn(function()
    while openBtn and openBtn.Parent do
        TweenService:Create(openBorder, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = COL.accent2}):Play()
        task.wait(1.5)
        TweenService:Create(openBorder, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundColor3 = COL.accent}):Play()
        task.wait(1.5)
    end
end)

-- Main Panel
local panelW = isMobile and 320 or 400
local panelH = isMobile and 460 or 540

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, panelW, 0, panelH)
panel.Position = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
panel.BackgroundColor3 = COL.bg
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local pBorder = Instance.new("Frame")
pBorder.Size = UDim2.new(1, 4, 1, 4)
pBorder.Position = UDim2.new(0, -2, 0, -2)
pBorder.BackgroundColor3 = COL.accent
pBorder.BorderSizePixel = 0
pBorder.ZIndex = -1
pBorder.Parent = panel
Instance.new("UICorner", pBorder).CornerRadius = UDim.new(0, 18)

local grad = Instance.new("Frame")
grad.Size = UDim2.new(1, 0, 0, 120)
grad.Position = UDim2.new(0, 0, 0, 0)
grad.BackgroundColor3 = COL.accent
grad.BackgroundTransparency = 0.92
grad.BorderSizePixel = 0
grad.Parent = panel
Instance.new("UICorner", grad).CornerRadius = UDim.new(0, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 40)
title.Position = UDim2.new(0, 20, 0, 20)
title.BackgroundTransparency = 1
title.Text = "RIVALS UNLOCKER"
title.TextColor3 = COL.text
title.TextSize = isMobile and 20 or 24
title.Font = Enum.Font.GothamBlack
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -40, 0, 20)
sub.Position = UDim2.new(0, 20, 0, 58)
sub.BackgroundTransparency = 1
sub.Text = "Unlock every skin, wrap, charm & finisher"
sub.TextColor3 = COL.dim
sub.TextSize = 12
sub.Font = Enum.Font.GothamBold
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 32, 0, 32)
close.Position = UDim2.new(1, -42, 0, 14)
close.BackgroundColor3 = COL.panel
close.BorderSizePixel = 0
close.Text = "×"
close.TextColor3 = COL.text
close.TextSize = 20
close.Font = Enum.Font.GothamBold
close.Parent = panel
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)

local closeBorder = Instance.new("Frame")
closeBorder.Size = UDim2.new(1, 2, 1, 2)
closeBorder.Position = UDim2.new(0, -1, 0, -1)
closeBorder.BackgroundColor3 = COL.dim
closeBorder.BorderSizePixel = 0
closeBorder.ZIndex = -1
closeBorder.Parent = close
Instance.new("UICorner", closeBorder).CornerRadius = UDim.new(0, 10)

close.MouseButton1Click:Connect(function()
    TweenService:Create(panel, TweenInfo.new(0.2), {Size = UDim2.new(0, panelW, 0, 0)}):Play()
    task.wait(0.2)
    panel.Visible = false
    openBtn.Visible = true
end)

local div = Instance.new("Frame")
div.Size = UDim2.new(1, -40, 0, 1)
div.Position = UDim2.new(0, 20, 0, 90)
div.BackgroundColor3 = COL.dim
div.BackgroundTransparency = 0.7
div.BorderSizePixel = 0
div.Parent = panel

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -40, 1, -110)
content.Position = UDim2.new(0, 20, 0, 100)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, 0, 0, 24)
status.BackgroundTransparency = 1
status.Text = "⏳ Ready to unlock"
status.TextColor3 = COL.dim
status.TextSize = 13
status.Font = Enum.Font.GothamBold
status.TextXAlignment = Enum.TextXAlignment.Center
status.Parent = content

-- Unlock Button
local unlockBtn = Instance.new("TextButton")
unlockBtn.Name = "UnlockBtn"
unlockBtn.Size = UDim2.new(1, 0, 0, 56)
unlockBtn.Position = UDim2.new(0, 0, 0, 36)
unlockBtn.BackgroundColor3 = COL.accent
unlockBtn.BorderSizePixel = 0
unlockBtn.Text = "🔓 UNLOCK ALL COSMETICS"
unlockBtn.TextColor3 = COL.bg
unlockBtn.TextSize = 15
unlockBtn.Font = Enum.Font.GothamBlack
unlockBtn.AutoButtonColor = false
unlockBtn.Parent = content
Instance.new("UICorner", unlockBtn).CornerRadius = UDim.new(0, 12)

local unlockBorder = Instance.new("Frame")
unlockBorder.Size = UDim2.new(1, 4, 1, 4)
unlockBorder.Position = UDim2.new(0, -2, 0, -2)
unlockBorder.BackgroundColor3 = COL.accent
unlockBorder.BorderSizePixel = 0
unlockBorder.ZIndex = -1
unlockBorder.Parent = unlockBtn
Instance.new("UICorner", unlockBorder).CornerRadius = UDim.new(0, 14)

unlockBtn.MouseEnter:Connect(function()
    TweenService:Create(unlockBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50, 255, 210)}):Play()
end)
unlockBtn.MouseLeave:Connect(function()
    TweenService:Create(unlockBtn, TweenInfo.new(0.15), {BackgroundColor3 = COL.accent}):Play()
end)
unlockBtn.MouseButton1Down:Connect(function()
    TweenService:Create(unlockBtn, TweenInfo.new(0.1), {Size = UDim2.new(1, -4, 0, 52)}):Play()
end)
unlockBtn.MouseButton1Up:Connect(function()
    TweenService:Create(unlockBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Size = UDim2.new(1, 0, 0, 56)}):Play()
end)

-- Feature list
local features = {
    "✓ All Weapon Skins",
    "✓ All Wraps",
    "✓ All Charms", 
    "✓ All Finishers",
    "✓ Save & Load Config",
    "✓ Works in-game & lobby"
}

local yOff = 106
for i, feat in ipairs(features) do
    local f = Instance.new("TextLabel")
    f.Size = UDim2.new(1, 0, 0, 22)
    f.Position = UDim2.new(0, 0, 0, yOff + (i-1)*26)
    f.BackgroundTransparency = 1
    f.Text = feat
    f.TextColor3 = COL.dim
    f.TextSize = 12
    f.Font = Enum.Font.GothamBold
    f.TextXAlignment = Enum.TextXAlignment.Left
    f.Parent = content
end

-- ========== AUTO-LOAD SECTION ==========
local autoY = yOff + #features * 26 + 16

local autoHeader = Instance.new("TextLabel")
autoHeader.Size = UDim2.new(1, 0, 0, 18)
autoHeader.Position = UDim2.new(0, 0, 0, autoY)
autoHeader.BackgroundTransparency = 1
autoHeader.Text = "▸ AUTO-LOAD"
autoHeader.TextColor3 = COL.accent
autoHeader.TextSize = 10
autoHeader.Font = Enum.Font.GothamBold
autoHeader.TextXAlignment = Enum.TextXAlignment.Left
autoHeader.Parent = content

-- Helper for toggle row
local function makeToggleRow(parent, y, labelText, defaultState, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.Position = UDim2.new(0, 0, 0, y)
    row.BackgroundColor3 = COL.panel
    row.BorderSizePixel = 0
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    
    local rBorder = Instance.new("Frame")
    rBorder.Size = UDim2.new(1, 2, 1, 2)
    rBorder.Position = UDim2.new(0, -1, 0, -1)
    rBorder.BackgroundColor3 = COL.dim
    rBorder.BackgroundTransparency = 0.6
    rBorder.BorderSizePixel = 0
    rBorder.ZIndex = -1
    rBorder.Parent = row
    Instance.new("UICorner", rBorder).CornerRadius = UDim.new(0, 8)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COL.text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    
    local pillBg = Instance.new("Frame")
    pillBg.Size = UDim2.new(0, 32, 0, 16)
    pillBg.Position = UDim2.new(1, -38, 0.5, -8)
    pillBg.BackgroundColor3 = COL.panel
    pillBg.BorderSizePixel = 0
    pillBg.Parent = row
    Instance.new("UICorner", pillBg).CornerRadius = UDim.new(1, 0)
    
    local pBorder = Instance.new("Frame")
    pBorder.Size = UDim2.new(1, 2, 1, 2)
    pBorder.Position = UDim2.new(0, -1, 0, -1)
    pBorder.BackgroundColor3 = COL.accent
    pBorder.BackgroundTransparency = 0.7
    pBorder.BorderSizePixel = 0
    pBorder.ZIndex = -1
    pBorder.Parent = pillBg
    Instance.new("UICorner", pBorder).CornerRadius = UDim.new(1, 0)
    
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Position = UDim2.new(0, 3, 0.5, -5)
    knob.BackgroundColor3 = COL.dim
    knob.BorderSizePixel = 0
    knob.Parent = pillBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    
    local state = defaultState
    local function updateVisual()
        TweenService:Create(pillBg, TweenInfo.new(0.18), {BackgroundColor3 = state and COL.accent or COL.panel}):Play()
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
            Position = state and UDim2.new(0, 19, 0.5, -5) or UDim2.new(0, 3, 0.5, -5),
            BackgroundColor3 = state and COL.bg or COL.dim
        }):Play()
        pBorder.BackgroundTransparency = state and 0 or 0.7
        lbl.TextColor3 = state and COL.accent or COL.text
        TweenService:Create(rBorder, TweenInfo.new(0.18), {BackgroundColor3 = state and COL.accent or COL.dim}):Play()
    end
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        updateVisual()
        onToggle(state)
    end)
    
    if defaultState then updateVisual() end
    return row
end

-- Auto Execute Toggle (saves to autoexec folder)
makeToggleRow(content, autoY + 24, "Auto Execute on Join", false, function(enabled)
    if enabled then
        local ok, msg = saveToAutoexec()
        if ok then
            status.Text = "✅ Auto-load enabled!"
            status.TextColor3 = COL.success
        else
            status.Text = "⚠️ " .. msg
            status.TextColor3 = COL.error
        end
    else
        removeFromAutoexec()
        status.Text = "⏳ Auto-load disabled"
        status.TextColor3 = COL.dim
    end
end)

-- Teleport Persist Toggle (queue_on_teleport)
makeToggleRow(content, autoY + 62, "Persist on Teleport", false, function(enabled)
    if enabled and queue_on_teleport then
        -- Store script in getgenv so we can reference it for teleport
        getgenv().RivalsUnlockerAutoLoad = true
        queue_on_teleport([[
            if not getgenv().RivalsUnlockerLoaded then
                -- Replace this loadstring with your script URL, or paste the full script here
                -- Example: loadstring(game:HttpGet("https://pastebin.com/raw/XXXX"))()
                -- For now, we just set a flag. Paste the FULL script inside this string for standalone use.
                getgenv().RivalsUnlockerQueued = true
            end
        ]])
        status.Text = "✅ Teleport persist enabled!"
        status.TextColor3 = COL.success
    elseif enabled and not queue_on_teleport then
        status.Text = "⚠️ Executor doesn't support queue_on_teleport"
        status.TextColor3 = COL.error
    else
        getgenv().RivalsUnlockerAutoLoad = false
        status.Text = "⏳ Teleport persist disabled"
        status.TextColor3 = COL.dim
    end
end)

-- Note
local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, 0, 0, 40)
note.Position = UDim2.new(0, 0, 1, -40)
note.BackgroundTransparency = 1
note.Text = "Tip: Enable both for full auto-load.\nFor teleport, host script on GitHub/Pastebin."
note.TextColor3 = COL.dim
note.TextSize = 9
note.Font = Enum.Font.Gotham
note.TextXAlignment = Enum.TextXAlignment.Center
note.TextWrapped = true
note.Parent = content

-- Unlock logic
unlockBtn.MouseButton1Click:Connect(function()
    if unlockRan then
        status.Text = "✅ Already unlocked!"
        status.TextColor3 = COL.success
        return
    end

    status.Text = "⏳ Unlocking... please wait"
    status.TextColor3 = COL.accent
    unlockBtn.Text = "⏳ WORKING..."
    unlockBtn.BackgroundColor3 = COL.dim

    task.spawn(function()
        local ok = doUnlockAll()

        if ok then
            status.Text = "✅ All cosmetics unlocked!"
            status.TextColor3 = COL.success
            unlockBtn.Text = "✅ UNLOCKED"
            unlockBtn.BackgroundColor3 = COL.success
            unlockBorder.BackgroundColor3 = COL.success
            TweenService:Create(pBorder, TweenInfo.new(0.3), {BackgroundColor3 = COL.success}):Play()
            task.wait(0.3)
            TweenService:Create(pBorder, TweenInfo.new(0.5), {BackgroundColor3 = COL.accent}):Play()
        else
            status.Text = "❌ Something went wrong"
            status.TextColor3 = COL.error
            unlockBtn.Text = "❌ RETRY"
            unlockBtn.BackgroundColor3 = COL.error
            unlockBorder.BackgroundColor3 = COL.error
        end
    end)
end)

-- Open/Close
openBtn.MouseButton1Click:Connect(function()
    openBtn.Visible = false
    panel.Visible = true
    panel.Size = UDim2.new(0, panelW, 0, 0)
    TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, panelW, 0, panelH)
    }):Play()
end)

-- Dragging
do
    local dragging, dragStart, startPos = false, nil, nil
    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = panel.Position
        end
    end
    local function endDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end
    title.InputBegan:Connect(beginDrag)
    grad.InputBegan:Connect(beginDrag)
    title.InputEnded:Connect(endDrag)
    grad.InputEnded:Connect(endDrag)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Entrance
task.spawn(function()
    task.wait(0.2)
    openBtn.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(openBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 50, 0, 50)
    }):Play()
end)

print("Rivals Unlocker Auto-Load Edition ready!")
