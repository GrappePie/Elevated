local deep = {}

local function FixData(arg)
	if typeof(arg) == "table" then
		for i,v in arg do
			if typeof(i) == "string" then
				local newI = string.gsub(i, "[^%w%s_]+", "")
				if string.len(newI) > 100_000 then
					newI = string.sub(newI, 1, 100_000)
				end

				arg[i] = nil
				arg[newI] = v
				i = newI
			elseif typeof(i) == "number" then
			else
				arg[i] = nil
			end

			if arg[i] and v then
				if typeof(v) == "table" then
					FixData(v)
				elseif typeof(v) == "string" then
					local newV = string.gsub(v, "[^%w%s_]+", "")
					if string.len(newV) > 100_000 then
						newV = string.sub(newV, 1, 100_000)
					end

					arg[i] = newV
					v = newV
				elseif typeof(v) == "number" then
				else
					arg[i] = nil
					v = nil
				end
			end
		end
	end
end

local function splitPath(path)
	local result = {}
	for part in string.gmatch(path, "[^" .. '/' .. "]+") do
		table.insert(result, part)
	end
	return result
end

local function recursiveSearch(tab, pathArray, index, write)
	index = index or 1

	if type(tab) ~= "table" then
		return nil
	end

	local key = pathArray[index]
	local nextValue = tab[key]

	if index == #pathArray then
		if write then
			return tab, key
		end
		return nextValue
	else
		return recursiveSearch(nextValue, pathArray, index + 1, write)
	end
end

function deep.deepSearch(tab, path)
	local pathArray = splitPath(path)
	return recursiveSearch(tab, pathArray)
end

function deep.deepWrite(tab, path, newValue)
	assert(typeof(newValue) == "number" or typeof(newValue) == "string" or typeof(newValue) == "table" or typeof(newValue) == "nil", "Incorrect data type of the newValue! Must be number; string or table")
	local pathArray = splitPath(path)
	local _table, _key = recursiveSearch(tab, pathArray, 1, true)

	if _table and _key then
		if typeof(newValue) == "table" then
			FixData(newValue)
		end

		_table[_key] = newValue
		return true
	end
end

--[[
local result = deepSearch(PROFILE_TEMPLATE, "UnlockedCharacters/Guest")
print(result)

local success = deepWrite(PROFILE_TEMPLATE, "UnlockedCharacters/Guest", 10)
print(success)

local added = deepWrite(PROFILE_TEMPLATE, "UnlockedCharacters/God", 0)
print(added)

local result = deepSearch(PROFILE_TEMPLATE, "UnlockedCharacters/Guest")
print(result)

local result = deepSearch(PROFILE_TEMPLATE, "UnlockedCharacters")
print(result)  --- UnlockedCharacters = {
		['Guest'] = 0,
		['Sweeper'] = 10,
		['God'] = 0
	},

]]

return deep
