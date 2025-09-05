xpcall(function()
	for i,v in script:GetDescendants() do
		if v:IsA('ModuleScript') then
			require(v)
			print(v.Name .. ' loaded')
		end
	end
end, function(res)
	game.Players.LocalPlayer:Kick(res)
end)

print('Init completed')