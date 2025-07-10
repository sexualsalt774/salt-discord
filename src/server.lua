AddEventHandler('Discordbot:Shared:DependencyUpdate', RetrieveComponents) 
function RetrieveComponents()
    Fetch = exports['mythic-base']:FetchComponent('Fetch')
    Discordbot = exports['mythic-base']:FetchComponent('Discordbot')
    Inventory = exports['mythic-base']:FetchComponent('Inventory')
    Jobs = exports['mythic-base']:FetchComponent('Jobs')
    Database = exports['mythic-base']:FetchComponent('Database')
    Vehicles = exports['mythic-base']:FetchComponent('Vehicles')
    Wallet = exports['mythic-base']:FetchComponent('Wallet') -- for cash?
    Banking = exports['mythic-base']:FetchComponent('Banking') -- for bank? why
    Callbacks = exports['mythic-base']:FetchComponent('Callbacks')
    MDT = exports['skdev-base']:FetchComponent('MDT')
    EmergencyAlerts = exports['skdev-base']:FetchComponent('EmergencyAlerts')
end

function FetchCharacterFromDB(stateId) -- functions that call this need to await but i could just await all main funcs anyway
    local p = promise.new()

    Database.Game:findOne({
        collection = 'characters',
        query = {
            SID = stateId,
        }
    }, function(success, results)
        if success and #results > 0 then
            p:resolve(results[1] or {})
        else
            p:resolve(false)
        end
    end)
    local res = Citizen.Await(p)
    return res
end


AddEventHandler('Core:Shared:Ready', function()
    exports['mythic-base']:RequestDependencies('Discordbot', { 
        'Fetch',
        'Discordbot',
        'Inventory',
        'Jobs',
        'Database',
        'Vehicles',
        'Wallet',
        'Banking',
        'Callbacks',
        'MDT',
        'EmergencyAlerts',
    }, function(error)
        if #error > 0 then return; end
        RetrieveComponents()

        -- print(json.encode(Discordbot, {indent = true}))
        --Wait(500) -- is thie nessccaascsry?
        DISCORDBOT:RegisterFunction('fetchSource', function(source) -- only one to use source
            source = tonumber(source)
            local plyr = Fetch:Source(source)
            if not plyr then return nil end
            local char = plyr:GetData('Character')
            if not char then
                -- this only works if playe is offline so no need for offline logic like i did below
                return nil 
            end
            return char:GetData()
        end)


        DISCORDBOT:RegisterFunction('fetchCharacter', function(sid) -- async func
            sid = tonumber(sid)
            local char = Fetch:SID(sid)
            if not char then
                local charDB = FetchCharacterFromDB(sid)
                -- print(charDB)
                -- print(type(charDB))
                return charDB
            end
            char = char:GetData('Character')
            return char:GetData()
        end)

        DISCORDBOT:RegisterFunction('fetchJobs', function(sid) -- async func (could be useless tbh and i just call it from fetchCharacter in the future but easier for just the jobs table)
            sid = tonumber(sid)
            local char = Fetch:SID(sid)
            if not char then
                local charDB = FetchCharacterFromDB(sid)
                return charDB.Jobs
            end
            char = char:GetData('Character')
            return char:GetData('Jobs')
        end)


        DISCORDBOT:RegisterFunction('giveItem', function(sid, item, amount) -- fails if sid is offline or source is not found
            sid = tonumber(sid)
            local player = Fetch:SID(sid)
            if not player then 
                return false
            end

            -- Maybe a weapon check here
            -- fuck it i have a new idea
            -- Create false data for if it detects weapon..
            local data = {}
            if item:match('^WEAPON_') or item:match('^weapon_') then
                item = item:upper()
                data = { 
                    ammo = 0,
                    clip = 0,
                    Scratched = nil
                }
            end

            local success = Inventory:AddItem(sid, item, amount, data, 1)
            -- print(success)
            if not success then return false end
            return true
        end)

        DISCORDBOT:RegisterFunction('giveWeapon', function(sid, weapon, ammo, scractched) -- fails if sid is offline or source is not found
            sid = tonumber(sid)
            local player = Fetch:SID(sid)
            if not player then 
                return false
            end

            local success = Inventory:AddItem(sid, weapon:upper(), 1, { 
                ammo = ammo,
                clip = 0,
                Scratched = scractched == '1' or nil
            }, 1)
            if not success then return false end
            return true
        end)

        DISCORDBOT:RegisterFunction('getJobs', function()
            local jobs = Jobs:GetAll() -- list of jobs
            return jobs
        end)

        DISCORDBOT:RegisterFunction('setCallsign', function(sid, callsign)
            sid = tonumber(sid)
            local target = Fetch:SID(sid)
            if not target then return false end

            local source = target:GetData("Source")
            if not Jobs.Permissions:HasJob(source, "police") and not Jobs.Permissions:HasJob(source, "ems") then
                return false
            end

            local updated = MDT.People:Update(-1, sid, "Callsign", callsign)
            if updated then
                EmergencyAlerts:RefreshCallsign(sid, callsign)
                return true
            end

            return false
        end)

        DISCORDBOT:RegisterFunction('giveJob', function(sid, jobId, gradeId, workplaceId)
            sid = tonumber(sid)

            local jobExists = Jobs:DoesExist(jobId, workplaceId, gradeId)
            if not jobExists then return false end

            local success = Jobs:GiveJob(sid, jobId, workplaceId, gradeId)
            if not success then return false end
            return true
        end)

        DISCORDBOT:RegisterFunction('removeJob', function(sid, jobId)
            sid = tonumber(sid)

            local success = Jobs:RemoveJob(sid, jobId)
            return success
        end)

        DISCORDBOT:RegisterFunction('setOwner', function(sid, jobId)
            sid = tonumber(sid)

            local jobExists = Jobs:Get(jobId)
            if jobExists and jobExists.Type == 'Company' then
                local success = Jobs.Management:Edit(jobId, {
                    Owner = sid
                })
                return success
            end
            return false
        end)

        DISCORDBOT:RegisterFunction('addOwnedVehicle', function(sid, hash, make, model, _class, value, _type, cb)
            local p = promise.new()
            sid = tonumber(sid)
            _type = tonumber(_type) or 0
            hash = GetHashKey(hash)
            if type(hash) == 'number' and make and model then
                Vehicles.Owned:AddToCharacter(sid, hash, _type, {
                    make = make,
                    model = model,
                    class = _class,
                    value = tonumber(value),
                }, function(success, vehicle)
                    if success then
                        p:resolve(vehicle.VIN)
                    else
                        p:resolve(false)
                    end
                end)
            else
                p:resolve(false)
            end

            local res = Citizen.Await(p)
            return res
        end)

        DISCORDBOT:RegisterFunction('giveMoney', function(sid, _type, amount) -- Player has to be online for this to work
            sid = tonumber(sid)
            -- Wallet:Modify(source, -(math.abs(cost))) -- Wallet wont work because it calls source and not sid basically just have to edit data 
            local plyr = Fetch:SID(sid)
            if not plyr then return false end --Offline
            local char = plyr:GetData('Character')
            if not char then return false end --Offline
            local source = plyr:GetData('Source')


            if _type == 'cash' then
                -- local currentCash = char:GetData('Cash')
                -- local newCashBalance = math.floor(currentCash + amount)
                -- if newCashBalance >= 0 then
                --     char:SetData('Cash', newCashBalance)
                -- end
                Wallet:Modify(source, amount)
                return true
            elseif _type == 'bank' then 
                local bankAccount = char:GetData('BankAccount')
                -- local bankAccount = Banking.Accounts:GetPersonal(sid).Account
                Banking.Balance:Deposit(bankAccount, amount, {
                    type = 'deposit',
                    title = 'God Deposit',
                    description = ('God deposited %s'):format(amount),
                })
                return true
            end
        end)

        DISCORDBOT:RegisterFunction('setPed', function(sid, ped)
            sid = tonumber(sid)
            local plyr = Fetch:SID(sid)
            if not plyr then return false end --Offline
            local char = plyr:GetData('Character')
            if not char then return false end --Offline
            local source = plyr:GetData('Source')
            TriggerClientEvent("Admin:Client:ChangePed", source, ped)
            return true
        end)

        DISCORDBOT:RegisterFunction('addCrypto', function(sid, crypto, amount)
            sid = tonumber(sid)
            local plyr = Fetch:SID(sid)
            if not plyr then return false end --Offline
            local char = plyr:GetData('Character')
            if not char then return false end --Offline
            
            -- hahahaha fuck im high i just ate a budle for 4 meal fuck mcdonalds mans
            Crypto.Exchange:Add(crypto, char:GetData("CryptoWallet"), amount)

            return true
        end)

        DISCORDBOT:RegisterFunction('addFleetVehicle', function(jobId, workplaceId, level, vehHash, make, model, class, value, vehType, qual)
            local p = promise.new()


            vehType = tonumber(vehType)
		    vehHash = GetHashKey(vehHash)
		    level = tonumber(level)

            if workplaceId == "false" or workplaceId == "all" then
                workplaceId = false
            end

            if not qual or qual == "false" or qual == "all" then
                qual = false
            end

            local jobExists = Jobs:DoesExist(jobId, workplaceId)

            if type(vehHash) == "number" and jobExists and level and level >= 0 and level < 10 and make and model then
                Vehicles.Owned:AddToFleet(jobId, workplaceId, level, vehHash, vehType, {
                    make = make,
                    model = model,
                    class = class,
                    value = math.tointeger(value),
                }, function(success, vehicle)
                    if success then
                        p:resolve(vehicle.VIN)
                    else
                        p:resolve(false)
                    end
                end, false, qual)
            else
                p:resolve(false)
            end

            local res = Citizen.Await(p)
            return res
        end)

        DISCORDBOT:RegisterFunction('heal', function(sid) --untested but should work ?
            if sid == "all" then
                Callbacks:ClientCallback(-1, "Damage:Heal", true)
                return true
            end
            sid = tonumber(sid)

            local plyr = Fetch:SID(sid)
            if not plyr then return false end --Offline
            local char = plyr:GetData('Character')
            if not char then return false end --Offline
            Callbacks:ClientCallback(char:GetData("Source"), "Damage:Heal", true)
            return true
        end)

    end)
end)

DISCORDBOT = {
    RegisterFunction = function(self, name, cb)
        print('Created export: '.. name)
        exports(name, cb)
        -- exports(name, function(...) -- use tis in javascript directly?
        --     local invoker = GetInvokingResource()
        --     local current = GetCurrentResourceName()
        --     print('INVOKER', invoker, invoker ~= current)
        --     if invoker ~= current then
        --         print(('[SECURITY] Export '%s' was called from '%s' (blocked)'):format(name, invoker or 'unknown'))
        --         -- optional: auto-ban/flag/report the resource
        --         return
        --     end
        --     cb(...)
        -- end)
    end,
}


AddEventHandler('Proxy:Shared:RegisterReady', function()
    exports['mythic-base']:RegisterComponent('Discordbot', DISCORDBOT)
end)

-- AddEventHandler('Proxy:Shared:ExtendReady', function(component)
--     if component == 'Discordbot' then
--         exports['mythic-base']:ExtendComponent(component, DISCORDBOT)
--     end
-- end)
