--!strict

local PlayerData = {}
PlayerData.__index = PlayerData

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Shared = script.Parent

local Trove = require(Shared.Trove)
local Signal = require(Shared.Signal)
local Network = require(Shared.Network)
local Promise = require(Shared.Promise)
local DeltaTable = require(Shared.DeltaTable)
local RunContext = require(Shared.RunContext)

local AUTO_SAVE_INTERVAL = 15
local DEBUG_USE_LIVE_DATA_IN_STUDIO = true

local STORE_NAME = if RunContext.IsStudio and not DEBUG_USE_LIVE_DATA_IN_STUDIO
    then if RunContext.IsEdit
        then "PlayerData_Edit"
        else "PlayerData_Studio"
    else "PlayerData"

local DATA_STORE = if RunContext.IsServer or RunContext.IsEdit
    then DataStoreService:GetDataStore(STORE_NAME)            
    else nil

PlayerData.StoreName = STORE_NAME

if RunContext.IsEdit then
    local src = script.Source
    local cached = shared.PlayerDataSource

    if src == cached then
        local data: any = shared.PlayerData

        if data then
            return data :: typeof(PlayerData)
        end
    end

    shared.PlayerDataSource = src
    shared.PlayerData = PlayerData
end

local CONST = table.freeze
type Connection = Signal.Connection

--- The default data structure for a player's save data.
--- This is used as a template for new player data and
--- adding new fields to existing player data.

export type SaveData = {
    Loadout: {
        
    },

    Stats: {
        XP: number,
        Kills: number,
        Deaths: number,
    },

    -- TODO: Add specific values for each setting.
    Settings: {
        [string]: any,
    },

    Wallet: {
        Credits: number,
    },

    Metadata: {
        LastInventoryView: number,
    },

    _compressionSchema: number?,
}

local Default: SaveData = CONST {
    -- For item drops, keys in the 'Inventory' dictionary will be GUIDs.
    -- The "Item" key is what identifies which item from the ItemData it is (skin, weapon, etc.)
    -- We'll be able to add additional metadata in the future like paint, nametags, stat-trackers, etc.

    Inventory = CONST {
    --  ["GUID"] = {
    --      Item = "Item",
    --      ... = ...,
    --  }
    },

    Loadout = CONST {
        
    },

    Stats = CONST {
        XP = 0,
        Kills = 0,
        Deaths = 0,
    },

    Settings = CONST {
        
    },

    Metadata = CONST {
        LastInventoryView = 0,
    },

    Wallet = CONST {
        Credits = 0,
    }
}

local DataCache = {} :: {
    [number]: Class
}

local ViewCache = {} :: {
    [number]: Class
}

type Trove = Trove.Class
type Promise = Promise.Class
type LazyTable = DeltaTable.LazyTable
type Signal<T...> = Signal.Typed<T...>

export type Patch = {
    Path: string,
    Value: any,
}

export type Class = typeof(setmetatable({} :: {
    CurrentData: SaveData,
    Owner: Player?,
    Maid: Trove,

    IsLoaded: boolean,
    Updated: Signal<Patch>,
    Loaded: Signal<boolean>,
    HasPendingChanges: boolean,
}, PlayerData))

local DataInit = Network.Event("DataInit", function (data: unknown): SaveData
    assert(type(data) == "table")
    return data :: SaveData
end)

local DataPatch = Network.Event("DataPatch", function (patch: unknown): LazyTable
    assert(type(patch) == "table")
    return patch :: LazyTable
end)

local compressionRoutines = nil :: {
    Compress: (SaveData) -> LazyTable,
    Decompress: (LazyTable) -> SaveData,
}?

local function getProfileKey(userId: number)
    return `Player${userId}`
end

local function free(data: Class)
    if data.Maid then
        data.Maid:Clean()
    end
end

local function reconcileTable(target: LazyTable, template: LazyTable): ()
    for k, v in pairs(template) do
        if type(k) == "string" then -- Only string keys will be reconciled
            if target[k] == nil then
                if type(v) == "table" then
                    target[k] = DeltaTable.DeepCopy(v)
                else
                    target[k] = v
                end
            elseif type(target[k]) == "table" and type(v) == "table" then
                reconcileTable(target[k], v)
            end
        end
    end
end

PlayerData.Default = Default

--- **[Server-Only]** Forces the player's data to be saved now.
--- * If the player's data is not loaded, the promise will reject.
--- * If the player's data is loaded, the promise will resolve when the data has been saved.
--- * If called on the client, the promise will reject.
--- @return A `Promise` that resolves when the player's data has been saved and rejects with an error message if something went wrong.
function PlayerData.Save(self: Class): Promise
    return Promise.new(function (resolve, reject)
        if not self.IsLoaded then
            reject("PlayerData not loaded!")
            return
        end

        if not (RunContext.IsServer or RunContext.IsEdit) then
            reject("PlayerData.Save can only be called on the server")
            return
        end

        if not self:IsActive() then
            reject("PlayerData is read-only!")
            return
        end

        local owner = self.Owner

        if not owner then
            if RunContext.IsEdit then
                local StudioService = game:GetService("StudioService")

                owner = {
                    UserId = StudioService:GetUserId(),
                } :: any
            else
                reject("PlayerData has no owner!")
                return
            end
        end
        
        local store = assert(DATA_STORE)
        local key = getProfileKey(assert(owner).UserId)
        
        store:UpdateAsync(key, function (oldData)
            return self.CurrentData
        end)
        
        resolve()
    end)
end

--- Gets a `PlayerData` object for the specified player **immediately**.
--- * **It may not be immediately ready for use!** Use `PlayerData.Load` to wait for the data to be loaded through a `Promise`
---   * Check the `IsLoaded` property to see if the data is ready, and/or listen against the `Loaded` signal.
--- * The data is read-only on the client, and on the server when the player is not in-game.
---   * It *can* be modified on the server if the player is in-game, or in edit mode if it belongs to the studio user.
---   * Modifications from the server will be propagated over to the client.
--- * If called on the client or in edit mode, it will return the data for the local user (the `userId` is ignored)
--- * If called on the server, the `userId` argument is **required** and the data for the specified player will be returned.
--- @param userId The userId of the player to get data for. Has no effect on the client or in edit mode.
function PlayerData.Get(userId: number?): Class
    if RunContext.IsServer or RunContext.IsEdit then
        if RunContext.IsEdit and userId == nil then
            local StudioService = game:GetService("StudioService")
            userId = StudioService:GetUserId()
        end

        assert(userId, "PlayerData.Get must be called with a userId on the server")

        local player = RunContext.IsServer and Players:GetPlayerByUserId(userId) or nil
        local cache: {Class} = if player then DataCache else ViewCache

        if not cache[userId] then
            local key = getProfileKey(userId)
            local maid = Trove.new()

            local data: Class = setmetatable({
                CurrentData = DeltaTable.DeepCopy(Default),
                HasPendingChanges = false,
                IsLoaded = false,
                Owner = player,

                Updated = Signal.new(),
                Loaded = Signal.new(),
                Maid = maid,
            }, PlayerData)

            task.spawn(function ()
                local RETRY_COUNT = 5
                local store = assert(DATA_STORE)

                for retry = 1, RETRY_COUNT do
                    local success, currentData = xpcall(function ()
                        return store:GetAsync(key)
                    end, function (err)
                        warn("!! Error while loading profile for player", userId, err, debug.traceback())
                    end)

                    if success then
                        if currentData == nil then
                            currentData = DeltaTable.DeepCopy(Default)
                        end

                        if currentData.RobloxMetaData ~= nil then
                            -- ProfileService holdover, use the Data key.
                            currentData = currentData.Data
                        end

                        if currentData then
                            reconcileTable(currentData, Default)

                            data.CurrentData = currentData
                            data.IsLoaded = true

                            data.Loaded:Fire(true)
                            break
                        end
                    elseif retry < RETRY_COUNT then
                        warn("Failed to load profile data for player", userId, "retrying...")
                        task.wait(retry / 2)
                    elseif player then
                        player:Kick("Failed to load profile data! Please rejoin.")
                        return
                    end
                end

                if data:IsActive() then
                    local autoSave = task.spawn(function ()
                        while task.wait(AUTO_SAVE_INTERVAL) do
                            if data:IsActive() and data.HasPendingChanges then
                                local promise = data:Save()
                                    :andThen(function ()
                                        data.HasPendingChanges = false
                                        warn("Autosaved profile for player", userId)
                                    end)
                                    :catch(function (err)
                                        warn("Failed to autosave profile for player", userId, err)
                                    end)

                                promise:await()
                            end
                        end
                    end)

                    maid:Add(function ()
                        task.cancel(autoSave)
                    end)
                end
            end)

            maid:Add(function ()
                cache[userId] = nil
                data.IsLoaded = false

                data.Loaded:DisconnectAll()
                data.Updated:DisconnectAll()
            end)

            cache[userId] = data
        end

        return cache[userId]
    else
        local myPlayer
        local myUserId

        if RunContext.IsEdit then
            local StudioService = game:GetService("StudioService")
            myUserId = StudioService:GetUserId()
        else
            myPlayer = assert(Players.LocalPlayer)
            myUserId = myPlayer.UserId
        end

        local data = DataCache[myUserId]

        if not data then
            data = setmetatable({
                CurrentData = DeltaTable.DeepCopy(Default),
                HasPendingChanges = false,
                Updated = Signal.new(),
                Owner = myPlayer,

                IsLoaded = false,
                Loaded = Signal.new(),

                Maid = Trove.new(),
            }, PlayerData)

            DataCache[myUserId] = data
        end

        return data
    end
end

--- Returns a promise that resolves when the player's data has been loaded.
--- * See `PlayerData.Get` for more information about the PlayerData object.
--- * If the data is already loaded, the promise will resolve immediately.
--- * If the data is not loaded, the promise will resolve when the data is loaded.
--- @return `Promise<PlayerData>` A promise that resolves when the player's data has been loaded.
function PlayerData.Load(userId: number?): Promise
    local data = PlayerData.Get(userId)

    return Promise.new(function (resolve, reject)
        if data.IsLoaded then
            task.defer(resolve, data)
        else
            data.Loaded:Once(function ()
                if data.IsLoaded then
                    task.defer(resolve, data)
                elseif reject then
                    warn("PlayerData.Load failed for player", userId)
                    reject(data)
                end
            end)
        end
    end)
end

--- **[!! Server Only !!]** Performs a patch operation on the player's data.
--- * The patch function will receive a copy of the player's data to make changes to.
--- * If the patch function executes successfully, those changes will be applied to the player's data.
--- * The changes will be replicated to the client and the `Updated` signal will be fired with each change made.
--- @param patch The function to execute on a snapshot of the player's data.
--- @return `Promise<(), string>` A promise that resolves when the patch operation is complete and rejects with an error message if something went wrong.
function PlayerData.Patch(self: Class, patchFunc: (edit: SaveData) -> ()): Promise
    return Promise.new(function (resolve, reject)
        if not (RunContext.IsServer or RunContext.IsEdit) then
            reject("PlayerData.Patch can only be called on the server")
            return
        end

        if not self.IsLoaded then
            reject("PlayerData not loaded!")
            return
        end

        local copy = DeltaTable.DeepCopy(self.CurrentData)
        patchFunc(copy)

        local changes, count = DeltaTable.Create(self.CurrentData, copy)
        local replicate = DataPatch:Server()

        if count > 0 then
            if self.Owner then
                replicate:Fire(self.Owner, changes)
            end

            DeltaTable.Apply(self.CurrentData, changes, function (path, value)
                self.Updated:Fire({
                    Path = table.concat(path, "/"),
                    Value = value,
                })
            end)

            self.HasPendingChanges = true
        end

        resolve()
    end)
end

--- Fetches a view of the player's current data, but only if it has loaded.
--- * **The returned SaveData is immutable. Do not attempt to modify it.**
--- * !! Will return nil if the data is not loaded yet.
function PlayerData.Read(userId: number?): SaveData?
    if userId == nil or userId > 0 then
        local data = PlayerData.Get(userId)

        if data.IsLoaded then
            return data.CurrentData
        end
    end

    return nil
end

--- Returns a promise that resolves with the player's data.
function PlayerData.PromiseRead(userId: number?): Promise
    return Promise.new(function (resolve, reject)
        local data = PlayerData.Get(userId)

        if data.IsLoaded then
            resolve(data.CurrentData)
        else
            data.Loaded:Once(function ()
                if data.IsLoaded then
                    resolve(data.CurrentData)
                else
                    reject("PlayerData not loaded!")
                end
            end)
        end
    end)
end

--- Connects a callback to be invoked when a specific path in the player's data changes.
function PlayerData.Connect(self: Class, path: string, callback: (value: any) -> ()): Connection
    local myPath = path:lower()

    local conn = self.Updated:Connect(function (patch)
        local path = patch.Path:lower()

        if path == myPath then
            callback(patch.Value)
        end
    end)

    local maid = self.Maid
    maid:Add(conn)

    return conn
end

function PlayerData.IsActive(self: Class)
    return self.Owner ~= nil or RunContext.IsEdit
end

function PlayerData.Release(self: Class, force: boolean?)
    if self:IsActive() then
        local owner = self.Owner

        if owner and owner:IsDescendantOf(game) then
            if force then
                owner:Kick("Your game session was deactivated. Please rejoin!")
            else
                warn("Cannot release active profile for player", owner.UserId)
                return false
            end
        end
    end

    free(self)
    return true
end

--- Sets up the compression routines for the player data.
--- This is handled externally to avoid cyclic dependency.
--- * !! THESE MUST MATCH ON THE SERVER AND CLIENT !!
function PlayerData.SetCompressionRoutines(routines: typeof(assert(compressionRoutines)))
    compressionRoutines = routines
end

if RunContext.IsServer then
    local init = DataInit:Server()

    local function onPlayerAdded(player: Player)
        PlayerData.Load(player.UserId):andThen(function (plrData: Class)
            local data = DeltaTable.DeepCopy(plrData.CurrentData)

            if compressionRoutines then
                data = compressionRoutines.Compress(data)
            end

            init:Fire(player, data)
        end)
    end

    local function onPlayerRemoving(player: Player)
        local data = DataCache[player.UserId]

        if data then
            data:Save()
            free(data)
        end
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for i, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end

    if not RunContext.IsStudio then
        game:BindToClose(function ()
            for userId, data in pairs(DataCache) do
                data:Save()
                free(data)
            end

            warn("done!")
        end)
    end

    PlayerData.StoreName = STORE_NAME
else
    local init = DataInit:Client()
    local patch = DataPatch:Client()

    init:On(function (data: LazyTable)
        if compressionRoutines then
            data = compressionRoutines.Decompress(data)
        end

        local myData = PlayerData.Get()
        myData.CurrentData = data

        myData.IsLoaded = true
        myData.Loaded:Fire(true)
    end)

    patch:On(function (patch: LazyTable)
        local myData = PlayerData.Get()

        DeltaTable.Apply(myData.CurrentData, patch, function (path, value)
            myData.Updated:Fire({
                Path = table.concat(path, "/"),
                Value = value,
            })
        end)
    end)
end

return PlayerData