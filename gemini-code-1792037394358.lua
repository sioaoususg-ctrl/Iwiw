--====================================================================--
-- Script:  SUN HUB (Full Compact Version - No Truncation)
-- Game:    Ride & Steal Eggs (PlaceId: 15448459363)
--====================================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local GameUI = PlayerGui:WaitForChild("GameUI")
local HUD = GameUI:WaitForChild("HUD")
local Windows = GameUI:WaitForChild("Windows")
local BackpackGui = PlayerGui:WaitForChild("Backpack")

-- ลบ UI เก่าหากรันซ้ำ
if Windows:FindFirstChild("SunHubWindow") then Windows.SunHubWindow:Destroy() end
if HUD.LeftMenu:FindFirstChild("SunHubBtn") then HUD.LeftMenu.SunHubBtn:Destroy() end

local State = {
    SelectedRidePet = "Auto (Best/First)",
    AutoStealEggs = false,
    AutoDeliverBase = false,
    AutoCollectIncome = false,
    AutoHatch = false,
    AntiTrap = false,
    EggESP = false,
    WalkSpeedEnabled = false,
    WalkSpeed = 65,
}

-- ดึงไอคอนแท้จาก StarterGui
local Icons = {
    Egg = HUD.RightMenu.Eggs.Icon.Image,
    Pet = HUD.RightMenu.Pets.Icon.Image,
    Speed = HUD.Stats.Speed.Icon.Image,
    Money = HUD.Stats.Money.Icon.Image,
    Shop = HUD.LeftMenu.Shop.Icon.Image,
    Settings = HUD.LeftMenu.Settings.Icon.Image,
    Index = HUD.LeftMenu.Index.Icon.Image,
}

-- ฟังก์ชันจำลองการคลิกปุ่ม UI
local function ClickBtn(btn)
    if not btn then return end
    if firesignal then
        pcall(function() firesignal(btn.MouseButton1Click) end)
        pcall(function() firesignal(btn.Activated) end)
    elseif getconnections then
        for _, c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
        for _, c in ipairs(getconnections(btn.Activated)) do pcall(function() c:Fire() end) end
    end
end

local function GetChar() return LocalPlayer.Character end
local function GetRoot() local c = GetChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function IsCarryingEgg() return HUD:FindFirstChild("Carry") and HUD.Carry.Visible end

local function IsRidingPet()
    if HUD:FindFirstChild("PetPanel") and HUD.PetPanel.Visible then return true end
    local c = GetChar()
    if c then
        if c:GetAttribute("Riding") or c:GetAttribute("Mounted") or c:FindFirstChild("PetModel") then return true end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and h.Sit then return true end
    end
    return false
end

-- ดึงรายชื่อสัตว์เลี้ยงในกระเป๋าและหน้าต่าง Pets
local function GetMyPetsList()
    local list, seen = {"Auto (Best/First)"}, {["Auto (Best/First)"] = true}
    local bagGrid = BackpackGui:FindFirstChild("Bag") and BackpackGui.Bag:FindFirstChild("Grid")
    if bagGrid then
        for _, item in ipairs(bagGrid:GetChildren()) do
            if item:IsA("TextButton") and item:FindFirstChild("ItemName") then
                local n = item.ItemName.Text
                if n ~= "" and not seen[n] then seen[n] = true table.insert(list, n) end
            end
        end
    end
    local petsGrid = Windows:FindFirstChild("Pets") and Windows.Pets.Body.Panel:FindFirstChild("Grid")
    if petsGrid then
        for _, card in ipairs(petsGrid:GetChildren()) do
            if card:IsA("TextButton") and card:FindFirstChild("PetName") then
                local n = card.PetName.Text
                if n ~= "" and not seen[n] then seen[n] = true table.insert(list, n) end
            end
        end
    end
    if #list == 1 and ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("PetModels") then
        for _, m in ipairs(ReplicatedStorage.Assets.PetModels:GetChildren()) do
            if not seen[m.Name] then seen[m.Name] = true table.insert(list, m.Name) end
        end
    end
    return list
end

-- บังคับขี่สัตว์เลี้ยงที่เลือกไว้ก่อนไปขโมยไข่
local function EnsureRidingSelectedPet()
    if IsRidingPet() then return true end
    local target = State.SelectedRidePet
    local bagGrid = BackpackGui:FindFirstChild("Bag") and BackpackGui.Bag:FindFirstChild("Grid")
    local hotbar = BackpackGui:FindFirstChild("Hotbar")
    local petAction = BackpackGui:FindFirstChild("PetAction")
    local slot = nil

    if bagGrid then
        for _, item in ipairs(bagGrid:GetChildren()) do
            if item:IsA("TextButton") and item:FindFirstChild("ItemName") then
                if target == "Auto (Best/First)" or item.ItemName.Text == target then slot = item break end
            end
        end
    end
    if not slot and hotbar then
        for _, s in ipairs(hotbar:GetChildren()) do
            if s:IsA("TextButton") and s.Visible then slot = s break end
        end
    end

    if slot then
        ClickBtn(slot)
        task.wait(0.15)
        if petAction and petAction:FindFirstChild("Box") and petAction.Box:FindFirstChild("Ride") then
            ClickBtn(petAction.Box.Ride)
            task.wait(0.25)
        end
    end

    pcall(function()
        if target ~= "Auto (Best/First)" then
            ReplicatedStorage.Shared.Modules.NetworkFramework.NetworkEvent:FireServer("RidePet", target)
        end
    end)
    return IsRidingPet()
end

local function GetMyBase()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "OwnerBoard" and obj:IsA("BillboardGui") then
            local b = obj:FindFirstChild("Banner")
            local p = b and b:FindFirstChild("PlayerName")
            local u = b and b:FindFirstChild("User")
            if (p and (p.Text == LocalPlayer.Name or p.Text == LocalPlayer.DisplayName)) or (u and u.Text:find(LocalPlayer.Name)) then
                return obj.Parent
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:GetAttribute("Owner") == LocalPlayer.Name or obj:GetAttribute("OwnerId") == LocalPlayer.UserId then return obj end
    end
    return nil
end

local function GetBestTargetEgg()
    local root = GetRoot()
    if not root then return nil end
    local best, dist = nil, math.huge
    local myBase = GetMyBase()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj.Name:lower():find("egg") or obj:GetAttribute("EggName") or obj:GetAttribute("Rarity")) and (obj:IsA("Model") or obj:IsA("BasePart")) then
            if not (myBase and obj:IsDescendantOf(myBase)) and not obj:IsDescendantOf(LocalPlayer.Character) then
                local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                if part and (part.Position - root.Position).Magnitude < dist then
                    dist = (part.Position - root.Position).Magnitude
                    best = part
                end
            end
        end
    end
    return best
end

local function Interact(part)
    local root = GetRoot()
    if not root or not part then return end
    if firetouchinterest then
        pcall(function() firetouchinterest(root, part, 0) task.wait(0.04) firetouchinterest(root, part, 1) end)
    end
    if part.Parent then
        for _, d in ipairs(part.Parent:GetDescendants()) do
            if d:IsA("ProximityPrompt") and fireproximityprompt then pcall(function() fireproximityprompt(d) end) end
        end
    end
end

--====================================================================--
-- สร้าง UI โคลนจาก Windows.Settings และ VFX Dropdown
--====================================================================--
local SettingsWin = Windows:WaitForChild("Settings")
local SunHubWin = SettingsWin:Clone()
SunHubWin.Name = "SunHubWindow"
SunHubWin.Visible = false
SunHubWin.Parent = Windows
SunHubWin.Header.Title.Text = "SUN HUB"

local HIcon = HUD.RightMenu.Eggs.Icon:Clone()
HIcon.Size = UDim2.new(0, 32, 0, 32)
HIcon.Position = UDim2.new(0, 14, 0.5, 0)
HIcon.AnchorPoint = Vector2.new(0, 0.5)
HIcon.Parent = SunHubWin.Header

local Body = SunHubWin:WaitForChild("Body")
local TglTpl = Body:WaitForChild("SFX"):Clone()
local TitleTpl = Body:WaitForChild("BaseTitle"):Clone()
local SldTpl = Body:WaitForChild("Music"):Clone()
local DropRowTpl = Body:WaitForChild("VFX"):Clone()
local DropMenuTpl = SunHubWin:WaitForChild("VFXMenu"):Clone()

if SunHubWin:FindFirstChild("VFXMenu") then SunHubWin.VFXMenu:Destroy() end
if SunHubWin:FindFirstChild("NotifyMenu") then SunHubWin.NotifyMenu:Destroy() end
for _, ch in ipairs(Body:GetChildren()) do
    if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
end

SunHubWin.Header.Close.MouseButton1Click:Connect(function() SunHubWin.Visible = false end)

local SunBtn = HUD.LeftMenu:WaitForChild("Settings"):Clone()
SunBtn.Name = "SunHubBtn"
SunBtn.Label.Text = "SUN HUB"
SunBtn.Icon.Image = Icons.Egg
SunBtn.Parent = HUD.LeftMenu
SunBtn.MouseButton1Click:Connect(function() SunHubWin.Visible = not SunHubWin.Visible end)

local Order = 0
local function SetRowIcon(row, img)
    if not img or img == "" then return end
    local ic = Instance.new("ImageLabel")
    ic.BackgroundTransparency = 1
    ic.Image = img
    ic.Size = UDim2.new(0, 26, 0, 26)
    ic.Position = UDim2.new(0, 12, 0.5, 0)
    ic.AnchorPoint = Vector2.new(0, 0.5)
    ic.ScaleType = Enum.ScaleType.Fit
    ic.Parent = row
    if row:FindFirstChild("Label") then
        row.Label.Position = UDim2.new(0, 46, row.Label.Position.Y.Scale, row.Label.Position.Y.Offset)
    end
end

local function AddSection(txt, img)
    Order = Order + 1
    local s = TitleTpl:Clone()
    s.Text = "      " .. txt
    s.LayoutOrder = Order
    s.Visible = true
    s.Parent = Body
    if img then
        local ic = Instance.new("ImageLabel")
        ic.BackgroundTransparency = 1
        ic.Image = img
        ic.Size = UDim2.new(0, 24, 0, 24)
        ic.Position = UDim2.new(0, 4, 0.5, 0)
        ic.AnchorPoint = Vector2.new(0, 0.5)
        ic.ScaleType = Enum.ScaleType.Fit
        ic.Parent = s
    end
end

local function AddDropdown(txt, img, def, getOpts, cb)
    Order = Order + 1
    local row = DropRowTpl:Clone()
    row.Label.Text = txt
    row.LayoutOrder = Order
    row.Visible = true
    row.Parent = Body
    SetRowIcon(row, img)

    local btn = row.Dropdown
    btn.Label.Text = def

    local menu = DropMenuTpl:Clone()
    menu.Visible = false
    menu.ZIndex = 50
    menu.Parent = SunHubWin

    local list = menu:WaitForChild("List")
    local optTpl = list:WaitForChild("Option"):Clone()
    optTpl.Visible = true
    if list:FindFirstChild("Actions") then list.Actions:Destroy() end

    local function Refresh()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for i, name in ipairs(getOpts()) do
            local o = optTpl:Clone()
            o.Label.Text = name
            o.LayoutOrder = i
            o.Parent = list
            if o:FindFirstChild("Box") and o.Box:FindFirstChild("Check") then
                o.Box.Check.Visible = (State.SelectedRidePet == name)
            end
            o.MouseButton1Click:Connect(function()
                State.SelectedRidePet = name
                btn.Label.Text = name
                menu.Visible = false
                cb(name)
            end)
        end
    end
    btn.MouseButton1Click:Connect(function()
        if not menu.Visible then Refresh() end
        menu.Visible = not menu.Visible
    end)
end

local function AddToggle(txt, img, def, cb)
    Order = Order + 1
    local row = TglTpl:Clone()
    row.Label.Text = txt
    row.LayoutOrder = Order
    row.Visible = true
    row.Parent = Body
    SetRowIcon(row, img)

    local btn, st = row.Toggle, def
    local function Upd()
        btn.Label.Text = st and "ON" or "OFF"
        if btn:FindFirstChild("UIGradient") then
            btn.UIGradient.Color = st and ColorSequence.new(Color3.fromRGB(80,225,100), Color3.fromRGB(40,175,65))
                or ColorSequence.new(Color3.fromRGB(235,75,75), Color3.fromRGB(175,40,40))
        end
    end
    Upd()
    btn.MouseButton1Click:Connect(function() st = not st Upd() task.spawn(cb, st) end)
end

local function AddButton(txt, img, bTxt, cb)
    Order = Order + 1
    local row = TglTpl:Clone()
    row.Label.Text = txt
    row.LayoutOrder = Order
    row.Visible = true
    row.Parent = Body
    SetRowIcon(row, img)

    local btn = row.Toggle
    if btn:FindFirstChild("Knob") then btn.Knob:Destroy() end
    btn.Label.Text = bTxt
    btn.Label.Size = UDim2.new(1, 0, 1, 0)
    btn.Label.Position = UDim2.new(0, 0, 0, 0)
    if btn:FindFirstChild("UIGradient") then
        btn.UIGradient.Color = ColorSequence.new(Color3.fromRGB(255,185,45), Color3.fromRGB(215,125,15))
    end
    btn.MouseButton1Click:Connect(function() task.spawn(cb) end)
end

local function AddSlider(txt, img, minV, maxV, def, cb)
    Order = Order + 1
    local row = SldTpl:Clone()
    row.Label.Text = txt
    row.LayoutOrder = Order
    row.Visible = true
    row.Parent = Body
    SetRowIcon(row, img)

    local sBtn, fill, knob, valLbl = row.Slider, row.Slider.Track.Fill, row.Slider.Knob, row.Value
    local function SetV(v)
        v = math.clamp(math.floor(v), minV, maxV)
        local p = (v - minV) / (maxV - minV)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, 0, 0.5, 0)
        valLbl.Text = tostring(v)
        cb(v)
    end
    SetV(def)
    local drag = false
    sBtn.MouseButton1Down:Connect(function() drag = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local p = math.clamp((i.Position.X - sBtn.Track.AbsolutePosition.X) / sBtn.Track.AbsoluteSize.X, 0, 1)
            SetV(minV + (maxV - minV) * p)
        end
    end)
end

--====================================================================--
-- สร้างปุ่มฟีเจอร์ทั้งหมดใน SUN HUB
--====================================================================--
AddSection("ระบบขี่สัตว์และขโมยไข่ (Ride & Steal)", Icons.Egg)
AddDropdown("เลือกสัตว์เลี้ยงที่จะขี่ไปขโมยไข่", Icons.Pet, State.SelectedRidePet, GetMyPetsList, function(v) State.SelectedRidePet = v end)
AddToggle("ออโต้ขี่สัตว์ + วาร์ปขโมยไข่ (Auto Ride & Steal)", Icons.Egg, false, function(v) State.AutoStealEggs = v end)
AddToggle("ออโต้วาร์ปส่งไข่เข้าฐาน (Auto Deliver Egg)", Icons.Egg, false, function(v) State.AutoDeliverBase = v end)
AddToggle("ออโต้ฟักไข่ทั้งหมดเมื่อโตเต็มที่ (Auto Hatch)", Icons.Egg, false, function(v) State.AutoHatch = v end)

AddSection("ระบบฟาร์มความเร็วและฐาน (Treadmill & Base)", Icons.Speed)
AddButton("Auto Treadmill (วาร์ปไปลู่วิ่งเพื่อฟาร์มความเร็ว)", Icons.Speed, "WARP & RUN", function()
    local root = GetRoot()
    if not root then return end
    local tm = nil
    local search = GetMyBase() or Workspace
    for _, o in ipairs(search:GetDescendants()) do
        if o.Name:lower():find("treadmill") then
            tm = o:IsA("BasePart") and o or (o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart"))
            if tm then break end
        end
    end
    if not tm then
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o.Name:lower():find("treadmill") then
                tm = o:IsA("BasePart") and o or (o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart"))
                if tm then break end
            end
        end
    end
    if tm then
        root.CFrame = tm.CFrame + Vector3.new(0, 3.5, 0)
        task.wait(0.15)
        Interact(tm)
        local h = GetChar() and GetChar():FindFirstChildOfClass("Humanoid")
        if h then h:Move(Vector3.new(0, 0, -1), true) end
    end
end)

AddToggle("ออโต้เก็บเงินในฐาน (Auto Collect Money)", Icons.Money, false, function(v) State.AutoCollectIncome = v end)
AddButton("ใส่สัตว์เลี้ยงตัวที่ดีที่สุด (Equip Best Pets)", Icons.Pet, "EQUIP BEST", function()
    ClickBtn(Windows.Pets.Body.Bar:FindFirstChild("EquipBest"))
end)

AddSection("ระบบป้องกันและเรดาร์ (Bypass & ESP)", Icons.Settings)
AddToggle("กันกับดักและเสาไฟฟ้าช็อต (Anti-Trap / Tesla)", Icons.Settings, false, function(v) State.AntiTrap = v end)
AddToggle("มองทะลุตำแหน่งไข่และระดับความหายาก (Egg ESP)", Icons.Index, false, function(v)
    State.EggESP = v
    if not v then
        for _, o in ipairs(Workspace:GetDescendants()) do if o.Name == "SunHubEggESP" then o:Destroy() end end
    end
end)

AddSection("ระบบความเร็วและวาร์ป (Movement & TP)", Icons.Speed)
AddToggle("เปิดใช้งานปรับความเร็ว (Enable Speed)", Icons.Speed, false, function(v)
    State.WalkSpeedEnabled = v
    if not v and GetChar() and GetChar():FindFirstChildOfClass("Humanoid") then
        GetChar():FindFirstChildOfClass("Humanoid").WalkSpeed = 16
    end
end)
AddSlider("ระดับความเร็ว (Walk / Ride Speed)", Icons.Speed, 16, 250, 65, function(v) State.WalkSpeed = v end)
AddButton("วาร์ปกลับฐานตัวเอง (TP to My Base)", Icons.Shop, "TELEPORT", function()
    local b, r = GetMyBase(), GetRoot()
    if b and r then
        local p = b:IsA("BasePart") and b or (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart"))
        if p then r.CFrame = p.CFrame + Vector3.new(0, 5, 0) end
    end
end)
AddButton("วาร์ปไปรังไข่กลางแมพ (TP to Egg Nest)", Icons.Egg, "TELEPORT", function()
    local e, r = GetBestTargetEgg(), GetRoot()
    if e and r then r.CFrame = e.CFrame + Vector3.new(0, 4, 0) end
end)

--====================================================================--
-- ลูปการทำงานหลัก (Runtime Loops)
--====================================================================--
task.spawn(function()
    while task.wait(0.3) do
        pcall(function()
            local root = GetRoot()
            if not root then return end

            if State.AutoDeliverBase and IsCarryingEgg() then
                local b = GetMyBase()
                if b then
                    local p = b:IsA("BasePart") and b or (b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart"))
                    if p then root.CFrame = p.CFrame + Vector3.new(0, 4, 0) Interact(p) end
                end
            elseif State.AutoStealEggs and not IsCarryingEgg() then
                if not IsRidingPet() then EnsureRidingSelectedPet() end
                local phase = Workspace:GetAttribute("NestPhase")
                if not phase or phase == "Open" then
                    local egg = GetBestTargetEgg()
                    if egg then root.CFrame = egg.CFrame + Vector3.new(0, 3, 0) Interact(egg) end
                end
            end

            if State.AutoHatch and Windows:FindFirstChild("Eggs") then
                local gBtn = Windows.Eggs.Header:FindFirstChild("GrowAll")
                if gBtn and gBtn.Visible then ClickBtn(gBtn) end
                for _, r in ipairs(Windows.Eggs.Body.Panel.List:GetChildren()) do
                    local oBtn = r:FindFirstChild("Open")
                    if oBtn and oBtn.Visible then ClickBtn(oBtn) end
                end
            end

            if State.AutoCollectIncome then
                local b = GetMyBase()
                if b then
                    for _, p in ipairs(b:GetDescendants()) do
                        if p:IsA("BasePart") and (p.Name:lower():find("collect") or p.Name:lower():find("pad") or p.Name:lower():find("claim")) then
                            Interact(p)
                        end
                    end
                end
            end
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    pcall(function()
        local c = GetChar()
        if c and State.WalkSpeedEnabled then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed = State.WalkSpeed end
        end
        if State.AntiTrap then
            local cam = Workspace.CurrentCamera
            if cam and cam:FindFirstChild("TeslaFx") then
                for _, p in ipairs(cam.TeslaFx:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanTouch = false p.CanQuery = false end
                end
            end
            for _, o in ipairs(Workspace:GetDescendants()) do
                if o:IsA("BasePart") and (o.Name:lower():find("trap") or o.Name:lower():find("spike") or o.Name:lower():find("tesla")) then
                    o.CanTouch = false o.CanCollide = false
                end
            end
        end
    end)
end)

task.spawn(function()
    while task.wait(1) do
        if State.EggESP then
            pcall(function()
                for _, o in ipairs(Workspace:GetDescendants()) do
                    local en, er = o:GetAttribute("EggName"), o:GetAttribute("Rarity")
                    if (en or er) and (o:IsA("Model") or o:IsA("BasePart")) and not o:FindFirstChild("SunHubEggESP") then
                        local bg = Instance.new("BillboardGui", o)
                        bg.Name = "SunHubEggESP"
                        bg.Size = UDim2.new(0, 140, 0, 45)
                        bg.StudsOffset = Vector3.new(0, 4, 0)
                        bg.AlwaysOnTop = true
                        local tl = Instance.new("TextLabel", bg)
                        tl.Size = UDim2.new(1, 0, 1, 0)
                        tl.BackgroundTransparency = 1
                        tl.Font = Enum.Font.FredokaOne
                        tl.TextSize = 15
                        tl.TextColor3 = Color3.fromRGB(255, 215, 50)
                        tl.TextStrokeTransparency = 0
                        tl.Text = string.format("[%s]\n%s", tostring(er or "Egg"), tostring(en or o.Name))
                    end
                end
            end)
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

SunHubWin.Visible = true
print("[SUN HUB] Loaded Successfully!")