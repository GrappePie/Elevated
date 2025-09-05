-- Toggle this to false in production if needed.
local ENABLE = true

if ENABLE then
	local run = require(script.Parent.Tests:WaitForChild("TestUtils.spec"))()
end