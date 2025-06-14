-- Grow a garden

-- local types = require("../Library/types.lua")
local Night = getgenv().Night :: types.night
local NightTabs = Night.Tabs

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage")) :: ReplicatedStorage
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players
local LocalPlayer = Players.LocalPlayer :: Player

local Modules = {
    Remotes = require(ReplicatedStorage.Modules.Remotes),
    Seeds = require(ReplicatedStorage.Data.SeedData),
    DataService = require(ReplicatedStorage.Modules.DataService),
    Gear = require(ReplicatedStorage.Data.GearData)
}

local Seeds = {}
local Gear = {}
if Modules.Seeds and typeof(Modules.Seeds) == "table" then
    for i: string, v: {} in Modules.Seeds do
        if typeof(i) == "string" then
            table.insert(Seeds, i)
        end
    end
else
    warn("No seeds table")
    Modules.Seeds = {}
end

if Modules.Gear and typeof(Modules.Gear) == "table" then
    for i: string, v: {} in Modules.Gear do
        if typeof(i) == "string" then
            table.insert(Gear, i)
        end
    end
else
    warn("No Gear Table")
    Modules.Gear = {}
end

if #Seeds == 0 then
    warn("No seeds in table")
end

if #Gear == 0 then
    warn("No gear in table")
end

local function GetFarm() : Folder?
    for i,v in Workspace.Farm:GetChildren() do
        if v:FindFirstChild("Important") and v.Important:FindFirstChild("Data") and v.Important.Data:FindFirstChild("Owner") then
            local FarmOwner = v.Important.Data:FindFirstChild("Owner") :: StringValue
            if FarmOwner and FarmOwner:IsA("StringValue") and FarmOwner.Value == LocalPlayer.Name then
                return v :: Folder
            end
        end
    end
    return nil :: nil
end

local function GetPlants(MaxedAge: boolean, NotAged: boolean) : ({}, Folder?)
    local Plants = {}
    local Farm = GetFarm() :: Folder?
    if Farm then
        for i,v in Farm.Important.Plants_Physical:GetChildren() do
            if v:IsA("Model") and v:GetAttribute("MaxAge") and v:FindFirstChild("Grow") and v.Grow:FindFirstChild("Age") then
                local MaxAge = v:GetAttribute("MaxAge") :: number
                local Age = v.Grow:FindFirstChild("Age") :: NumberValue
                if MaxedAge or NotAged then
                    if Age:IsA("NumberValue") and MaxAge and typeof(MaxAge) == "number" then
                        if (MaxedAge and Age.Value >= MaxAge or NotAged and MaxAge > Age.Value) then
                            if v:FindFirstChild("Fruits") then
                                for i2,v2 in v.Fruits:GetChildren() do
                                    table.insert(Plants, v2)
                                end
                            else
                                table.insert(Plants, v)          
                            end
                        end
                    end
                else
                    table.insert(Plants, v)
                end
            end
        end
    end
    return Plants :: {}, Farm :: Folder   
end

local function GetRandomSide() : (Part?, Folder?)
    local Farm = GetFarm() :: Folder?
    local Side = nil :: Part?
    if Farm and Farm.Important:FindFirstChild("Plant_Locations") then
        for i,v in Farm.Important.Plant_Locations:GetChildren() do
            if v:IsA("Part") and v.Name == "Can_Plant" and v:GetAttribute("Side") then
                if math.random(0, 1) == 1 then
                    Side = v
                    break
                end
                Side = v
            end
        end
    end
    return Side :: Part, Farm :: Folder
end

local function Plant(Item: Tool | string) : boolean
    local Side, Farm = GetRandomSide()
    if Side and Farm then
        local FarmSpawn = Farm:FindFirstChild("Spawn_Point") :: Part
        if FarmSpawn and FarmSpawn:IsA("Part") then
            LocalPlayer.Character.PrimaryPart.CFrame = FarmSpawn.CFrame
            task.wait(0.15)
        end
        
        local XPos = Side.Position.X + math.random(-Side.Size.X/2, Side.Size.X/2) :: number
        local ZPos = Side.Position.Z + math.random(-Side.Size.Z/2, Side.Size.Z/2) :: number
        local PlantPosition = Vector3.new(XPos, Side.Position.Y, ZPos) :: Vector3
        
        local SeedType = Item :: string
        if typeof(Item) == "Instance" and Item:IsA("Tool") and Item:GetAttribute("Seed") then
            SeedType = Item:GetAttribute("Seed") :: string
        end

        if not SeedType or typeof(SeedType) ~= "string" then
            return false :: boolean
        end

        ReplicatedStorage.GameEvents.Plant_RE:FireServer(PlantPosition, tostring(SeedType))
        return true :: boolean
    end
    return false :: boolean
end

local function GetSeedFromInv(Valid: {}?) : {}
    local Seeds = {}
    for i,v : Tool in LocalPlayer.Backpack:GetChildren() do
        if v:GetAttribute("Quantity") then
            if (Valid and v:GetAttribute("Seed") and table.find(Valid, v:GetAttribute("Seed"))) or not Valid then
                Seeds[v] = false
            end
        end
    end

    for i,v : Tool in LocalPlayer.Character:GetChildren() do
        if v:GetAttribute("Quantity") then
            if (Valid and v:GetAttribute("Seed") and table.find(Valid, v:GetAttribute("Seed"))) or not Valid then
                Seeds[v] = true
            end
        end
    end

    return Seeds :: {}
end

local function GetCollectedSeeds() : ({}, number)
    local Seeds = {}
    local Amount = 0
    for i,v : Tool in LocalPlayer.Backpack:GetChildren() do
        if v:IsA("Tool") and v:GetAttribute("MaxAge") and v:GetAttribute("WeightMulti") and v:FindFirstChild("Item_Seed") then
            table.insert(Seeds, v)
            Amount += 1     
        end
    end

    for i,v : Tool in LocalPlayer.Character:GetChildren() do
        if v:IsA("Tool") and v:GetAttribute("MaxAge") and v:GetAttribute("WeightMulti") and v:FindFirstChild("Item_Seed") then
            table.insert(Seeds, v)
            Amount += 1     
        end
    end

    return Seeds :: {}, Amount :: number
end

local function GetWaterCan() : Tool?
    for i,v : Tool in LocalPlayer.Backpack:GetChildren() do
        if v:IsA("Tool") and v.Name:find("Watering Can") and v:GetAttribute("e") then
            return v
        end
    end

    for i,v : Tool in LocalPlayer.Character:GetChildren() do
        if v:IsA("Tool") and v.Name:find("Watering Can") and v:GetAttribute("e") then
            return v
        end
    end

    return nil
end

local function GetSeedPrice(Seed: string) : (number, boolean)
    local SeedData = rawget(Modules.Seeds, Seed) :: {Price: number, SeedName: string}
    if SeedData and typeof(SeedData) == "table" and SeedData.SeedName and SeedData.Price then
        if typeof(SeedData.SeedName) == "string" and typeof(SeedData.Price) == "number" then
            return SeedData.Price :: number, true :: boolean
        end
    end
    return math.huge :: number, false :: boolean
end

local AutoPlantOptions = {}
NightTabs.Tabs.World.Functions.NewModule({
    Name = "Auto Plant",
    Description = "Plants crops",
    Icon = "",
    Flag = "AutoPlant",
    Callback = function(self, callback: boolean)
        if callback then
            repeat
                local Seeds = GetSeedFromInv(AutoPlantOptions) :: {}
                for i : Tool, v : boolean in Seeds do
                    if not v then
                        LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid"):EquipTool(i)
                    end
                
                    local amt = i:GetAttribute("Quantity") :: number
                    if not amt then amt = 1 end
                
                    for _ = 1, amt  do
                        if not self.Data.Enabled then
                            break
                        end
                        Plant(i) 
                        task.wait(0.15)       
                    end
                    task.wait(0.15)        
                end
                
                task.wait(0.2)
            until not self.Data.Enabled
        end
    end
}).Functions.Settings.Dropdown({
    Name = "Seeds",
    Description = "Seeds to plant",
    Flag = "AutoPlantSeeds",
    SelectLimit = math.huge,
    Options = Seeds,
    Default = Seeds,
    Callback = function(self, callback: {})
        AutoPlantOptions = callback
    end
})

NightTabs.Tabs.Utility.Functions.NewModule({
    Name = "Auto Collect",
    Description = "Collects grown crops",
    Icon = "",
    Flag = "AutoCollect",
    Callback = function(self, callback : boolean)
        if callback then
            repeat
                local Crops = GetPlants(true, false) :: {}
                if Crops then
                    Modules.Remotes.Crops.Collect.send(Crops)
                end
                task.wait(0.15)
            until not self.Data.Enabled
        end
    end
})

local AutoBuy = {
    Toggle = nil,
    Settings = {
        Seeds = {},
        Gear = {}
    }
}

AutoBuy.Toggle = NightTabs.Tabs.Utility.Functions.NewModule({
    Name = "Auto Buy",
    Description = "Buys seeds and gear",
    Icon = "",
    Flag = "AutoBuy",
    Callback = function(self, callback : boolean)
        if callback then
            repeat
                local Data = Modules.DataService:GetData() :: {}
                if Data and typeof(Data) == "table" and Data.SeedStock and Data.GearStock then
                    local Sheckles, SeedStock, GearStock = Data.Sheckles :: number, Data.SeedStock.Stocks :: {}, Data.GearStock.Stocks
                    if Sheckles then
                        if SeedStock and typeof(Sheckles) == "number" and typeof(SeedStock) == "table" then
                            for i,v in AutoBuy.Settings.Seeds do
                                local Seed = SeedStock[v] :: {Stock: number}?
                                if Seed and Seed.Stock and typeof(Seed.Stock) == "number" and Seed.Stock > 0 then
                                    local Price: number, Valid: boolean = GetSeedPrice(v)
                                    if Price and typeof(Price) == "number" and Valid and Sheckles >= Price then
                                        ReplicatedStorage.GameEvents.BuySeedStock:FireServer(v)
                                    end
                                end
                            end
                        end

                        if GearStock and typeof(GearStock) == "table" then
                            for i,v in AutoBuy.Settings.Gear do
                                local Gear = Modules.Gear[v] :: {Price: number}
                                if Gear and typeof(Gear) == "table" and Gear.Price and typeof(Gear.Price) == "number" then
                                    local Stock = GearStock[v] :: {Stock: number, MaxStock: number}
                                    if Stock and typeof(Stock) == "table" and Stock.Stock and typeof(Stock.Stock) == "number" and Stock.Stock > 0 then
                                        if Sheckles >= Gear.Price then
                                            ReplicatedStorage.GameEvents.BuyGearStock:FireServer(v)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(0.45)
            until not self.Data.Enabled
        end
    end
})
AutoBuy.Toggle.Functions.Settings.Dropdown({
    Name = "Seeds",
    Description = "Seeds to buy",
    Flag = "AutoBuySeeds",
    SelectLimit = math.huge,
    Options = Seeds,
    Default = Seeds,
    Callback = function(self, callback)
        AutoBuy.Settings.Seeds = callback
    end
})
AutoBuy.Toggle.Functions.Settings.Dropdown({
    Name = "Gear",
    Description = "Gear to buy",
    Flag = "AutoBuyGear",
    SelectLimit = math.huge,
    Options = Gear,
    Default = {"Watering Can"},
    Callback = function(self, callback)
        AutoBuy.Settings.Gear = callback
    end
})


local SellThreshold = 50
NightTabs.Tabs.Utility.Functions.NewModule({
    Name = "Auto Sell",
    Description = "Sells your inventory",
    Icon = "",
    Flag = "AutoSell",
    Callback = function(self, callback: boolean)
        if callback then
            repeat
                local Sellable, Amount = GetCollectedSeeds()
                if Sellable and Amount >= SellThreshold then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = Workspace.Tutorial_Points.Tutorial_Point_2.CFrame
                    ReplicatedStorage.GameEvents.Sell_Inventory:FireServer()
                end
                task.wait(0.5)
            until not self.Data.Enabled
        end
    end
}).Functions.Settings.Slider({
    Name = "Threshold",
    Description = "Amount of crops before selling",
    Min = 1,
    Max = 200,
    Default = 50,
    Flag = "AutoSellThreshold",
    Callback = function(self, callback: boolean)
        if callback then
           SellThreshold = callback 
        end
    end
})

NightTabs.Tabs.Utility.Functions.NewModule({
    Name = "Auto Water",
    Description = "Uses your water can to water crops",
    Icon = "",
    Flag = "AutoWater",
    Callback = function(self, callback: boolean)
        repeat
            local Crops = GetPlants(false, true) :: {}
            local WateringCan = GetWaterCan() :: Tool
            if Crops and WateringCan and #Crops > 0 then
                LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid"):EquipTool(WateringCan)
                for i,v : Model in Crops do
                    if v.PrimaryPart then
                        local Pos = v.PrimaryPart.Position :: Vector3
                        ReplicatedStorage.GameEvents.Water_RE:FireServer(vector.create(Pos.X, Pos.Y, Pos.Z))            
                    end        
                end
            end
            task.wait(0.15)
        until not self.Data.Enabled
    end
})