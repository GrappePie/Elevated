xpcall(function()
	for i,v in script:GetDescendants() do
		if v:IsA('ModuleScript') then
			require(v)
			print(v.Name .. ' loaded')
		end
	end
end, function(res)
	warn(res)
	for i,v in game.Players:GetDescendants() do
		v:Kick(res)
	end
end)

print('Init completed')
