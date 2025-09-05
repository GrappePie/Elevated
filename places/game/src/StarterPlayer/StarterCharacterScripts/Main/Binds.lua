local UIS = game:GetService("UserInputService")
--local Signal = require(game.ReplicatedStorage.Modules.GoodSignal).new()

local bind = {}
local Signal = Instance.new('BindableEvent')

function bind.bindEvent(key, state)
	return Signal.Event
end

function bind.getMousePosition()
	return UIS:GetMouseLocation()
end

UIS.InputBegan:Connect(function(key, isTyping)
	if isTyping then return end
	if key.UserInputType.Name == 'Keyboard' then
		Signal:Fire(key.KeyCode.Name, true)
		return
	end
	Signal:Fire(key.UserInputType.Name, true)
end)

UIS.InputChanged:Connect(function(key, isTyping)
	if isTyping then return end
	if key.UserInputType == Enum.UserInputType.MouseWheel then
		if key.Position.Z > 0 then
			Signal:Fire('MouseWheelUp', true)
			return
		end
		Signal:Fire('MouseWheelDown', true)
	end
end)

UIS.InputEnded:Connect(function(key, isTyping)
	if isTyping then return end
	if key.UserInputType.Name == 'Keyboard' then
		Signal:Fire(key.KeyCode.Name, false)
		return
	end
	Signal:Fire(key.UserInputType.Name, false)
end)

return bind