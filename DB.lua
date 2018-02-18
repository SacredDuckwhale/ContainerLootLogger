----------------------------------------------------------------------------------------------------------------------
    -- This program is free software: you can redistribute it and/or modify
    -- it under the terms of the GNU General Public License as published by
    -- the Free Software Foundation, either version 3 of the License, or
    -- (at your option) any later version.
	
    -- This program is distributed in the hope that it will be useful,
    -- but WITHOUT ANY WARRANTY; without even the implied warranty of
    -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    -- GNU General Public License for more details.

    -- You should have received a copy of the GNU General Public License
    -- along with this program.  If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------------------------------------------------


local addonName, CLL = ...
if not CLL then return end


-- Initialise environment
local DB = {}

-- Locals and constants
local MODULE = "DB"
local DB_VERSION = 1

-- DB Versioning
local versions = {
	[1] = { changelog = "Initial version", changes = {} }
}

-- Upvalues
local type = type
local format = format
local tonumber = tonumber
local tostring = tostring
local pairs = pairs
local UnitName = UnitName
local GetRealmName = GetRealmName
local GetLocale = GetLocale
local DebugMsg = CLL.Debug.Print
local GetFQCN = CLL.GetFQCN


-- Print a formatted message
function DB.Init()

	-- Create DB tables if necessary
	ContainerLootLoggerDB = ContainerLootLoggerDB or {}
	
	local fqcn = GetFQCN()
	ContainerLootLoggerDB[fqcn] = ContainerLootLoggerDB[fqcn] or {}
	
	-- Update to current version (if outdated)
	local currentVersion = ContainerLootLoggerDB["DatabaseVersion"]
	DebugMsg(MODULE, "Initialising DB with currentVersion = " .. tostring(currentVersion))
	
	if not currentVersion or type(currentVersion) ~= "number" or (tonumber(currentVersion) < DB_VERSION) then -- DB needs upgrade to newer version
		DebugMsg(MODULE, "DatabaseVersion was found to be outdated (is " .. tostring(currentVersion) .. ", needs upgrading to " .. DB_VERSION .. ")")
		-- TODO: Apply changes where necessary
		ContainerLootLoggerDB["DatabaseVersion"] = DB_VERSION
	end	
	
end

-- Validates a given entry (must contain container name and loot info)
function DB.ValidateEntry(entry)
	-- A valid entry looks like this (for the current DB_VERSION; may be subject to change):
	-- <link> = { amount = <total amount>, type = <currency, item, etc.>, locale = <client locale>, count = <no. of opened containers> }
	local template = {
		amount = "number",
		type = "string",
		--locale = "string", -- Not needed, as it will be added by DB.AddEntry automatically if omitted
		count = "number", -- Will also be increased or initialised with 1 automatically
	}
	
	for k, v in pairs(template) do -- Compare entry with the template and make sure the fields exist
		if not entry[k] or type(entry[k]) ~= v then -- This part of the template doesn't exist or is invalid -> reject entry
			DebugMsg(MODULE, "Failed to validate entry " .. tostring(entry[k]) .. " for key '" .. k .. "' (should be " .. v .. ", but is " .. type(entry[k]) .. ")")
			return false
		end
	end
	
	return true
	
end


-- Add one instance of opened container
function DB.AddOpening(container, fqcn)

	fqcn = fqcn or GetFQCN()
	
	container = container or "UNKNOWN_SOURCE" -- TODO
	DebugMsg(MODULE, "Adding opening for fqcn = " .. tostring(fqcn) .. ", container = " .. tostring(container))
	ContainerLootLoggerDB[fqcn][container] = ContainerLootLoggerDB[fqcn][container] or {} -- Init table if this container hasn't been added before
	

	ContainerLootLoggerDB[fqcn][container].numContainersOpened = ContainerLootLoggerDB[fqcn][container].numContainersOpened and (ContainerLootLoggerDB[fqcn][container].numContainersOpened + 1 ) or 1 -- TODO: Wrong for missions, should consider each mission instead of the "table opening"?
	
end

-- Adds a loot entry for the given fqcn (or the current player if none was given)
-- @param entry
-- @param fqcn
function DB.AddEntry(key, entry, container, fqcn)

	container = container or "UNKNOWN_CONTAINER"
	fqcn = fqcn or GetFQCN()

	local isValid = DB.ValidateEntry(entry)
	if not isValid then -- Can't add this to the DB
		DebugMsg(MODULE, "Failed to add entry to the DB because it was invalid")
		return
	end
	
	-- Update existing entry or create anew with default values to add the given loot info
	DebugMsg(MODULE, "Adding entry for fqcn = " .. tostring(fqcn))
	ContainerLootLoggerDB[fqcn][container] = ContainerLootLoggerDB[fqcn][container] or {} -- Init table if this container hasn't been added before
	--ContainerLootLoggerDB[fqcn][container].numContainersOpened = ContainerLootLoggerDB[fqcn][container].numContainersOpened or 0
	ContainerLootLoggerDB[fqcn][container][key] = ContainerLootLoggerDB[fqcn][container][key] or {}
	ContainerLootLoggerDB[fqcn][container][key].count = ContainerLootLoggerDB[fqcn][container][key].count or 0
	
	DebugMsg(MODULE, "Count was " .. ContainerLootLoggerDB[fqcn][container][key].count .. ", is now " .. (ContainerLootLoggerDB[fqcn][container][key].count and (ContainerLootLoggerDB[fqcn][container][key].count + entry.count) or entry.count))	
	ContainerLootLoggerDB[fqcn][container][key].count = ContainerLootLoggerDB[fqcn][container][key].count and (ContainerLootLoggerDB[fqcn][container][key].count + entry.count) or entry.count
	--ContainerLootLoggerDB[fqcn][container][key].count = (ContainerLootLoggerDB[fqcn][container][key].count + 1)
	ContainerLootLoggerDB[fqcn][container][key].amount = ContainerLootLoggerDB[fqcn][container][key].amount and (ContainerLootLoggerDB[fqcn][container][key].amount + entry.amount) or entry.amount
	ContainerLootLoggerDB[fqcn][container][key].type = ContainerLootLoggerDB[fqcn][container][key].type or entry.type -- Types shouldn't be able to change, no need to check this
	ContainerLootLoggerDB[fqcn][container][key].locale = ContainerLootLoggerDB[fqcn][container][key].locale or GetLocale() -- ditto
	
	--ContainerLootLoggerDB[fqcn][container].numContainersOpened = ContainerLootLoggerDB[fqcn][container].numContainersOpened + numOpenings
	
end

-- Add module to shared environment
CLL.DB = DB