-- Tiny test harness for your utils under ReplicatedStorage.Modules.combinedFunctions

local RS = game:GetService("ReplicatedStorage")
local function requireUtils()
	local Modules = RS:WaitForChild("Modules")
	local cf = Modules:WaitForChild("combinedFunctions")

	if cf:IsA("ModuleScript") then
		print("[UtilsSpec] requiring ModuleScript: Modules/combinedFunctions")
		return require(cf)
	else
		local init = cf:FindFirstChild("Init") or cf:FindFirstChild("init")
		if not (init and init:IsA("ModuleScript")) then
			local names = {}
			for _,child in ipairs(cf:GetChildren()) do
				table.insert(names, (`{child.Name} ({child.ClassName})`))
			end
			error(("[UtilsSpec] No 'Init' ModuleScript under Modules/combinedFunctions.\nChildren: %s")
				:format(table.concat(names, ", ")))
		end
		print("[UtilsSpec] requiring Folder child: Modules/combinedFunctions/Init")
		return require(init)
	end
end

local Utils = requireUtils()
local Results = { passed = 0, failed = 0 }
local function ok(cond: boolean, msg: string)
	if cond then
		Results.passed += 1
		print("[PASS] " .. msg)
	else
		Results.failed += 1
		warn("[FAIL] " .. msg)
	end
end

local function approx(a: number, b: number, eps: number?) : boolean
	eps = eps or 1e-2
	return math.abs(a - b) <= eps
end

local function it(name: string, fn: ()->())
	print("\n[it] " .. name)
	local okP, err = pcall(fn)
	if not okP then
		Results.failed += 1
		warn("[ERROR] " .. name .. " → " .. tostring(err))
	end
end

local function newPart(name: string)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = Vector3.new(2, 2, 2)
	p.CFrame = CFrame.new(0, 6, 0)
	p.Parent = workspace
	return p
end

local function nowait(sec: number)
	local t = os.clock()
	while os.clock() - t < sec do task.wait() end
end

-- ============= TESTS =============

it("Maid: GiveSignal / GiveInstance / Destroy cleans all", function()
	-- Usa los 3 args: new, isShared, name
	local Maid = Utils:maid(true, true, "SpecMaid")

	local ev = Instance.new("BindableEvent")
	local fired = 0
	Maid:GiveSignal(ev.Event, function() fired += 1 end)
	ev:Fire(); ev:Fire()
	task.wait() -- <— necesario por deferred signals
	ok(fired == 2, "Maid gives signal connection")

	local tmp = Instance.new("Folder")
	tmp.Parent = workspace             -- <— parentear para la aserción
	Maid:GiveInstance(tmp)
	ok(tmp.Parent ~= nil, "Instance exists before destroy")

	Maid:Destroy()
	ok(Maid:Count() == 0, "Maid count is zero after Destroy")
	ok(tmp.Parent == nil, "Instance destroyed by Maid")

	ev:Destroy()
end)

it("Timer: start/await, pause/resume, finished vs stopped", function()
	local t = Utils:timer(true)
	local states = {}
	t:start(0.15, function(self) table.insert(states, self:getProgress()) end)
	local res = t:awaitFinished()
	ok(res == "Finished", "Timer finished returns 'Finished'")
	ok(#states > 0, "Timer called per-frame callback")

	local t2 = Utils:timer(true)
	t2:start(0.30)
	nowait(0.10); t2:pause(); local pausedElapsed = t2:getElapsed()
	nowait(0.15); t2:resume()
	local res2 = t2:awaitFinished()
	ok(res2 == "Finished", "Timer finished after pause/resume")
	ok((t2:getElapsed() - pausedElapsed) > 0.10, "Elapsed advanced after resume")

	local t3 = Utils:timer(true)
	t3:start(1.0)
	nowait(0.05)
	t3:stop() -- no finished flag
	local res3 = t3:awaitFinished()
	ok(res3 == "Stopped", "Timer stopped returns 'Stopped'")
end)

it("Tween: single await, group await, cancelById", function()
	local Tween = Utils:tween()
	local p1 = newPart("TweenP1")
	local p2 = newPart("TweenP2")

	p1.Transparency = 0
	local tw = Tween.linear(p1, {Transparency = 1}, 0.05, "tw1")
	local r = tw:await()
	ok(r == "Finished" and approx(p1.Transparency, 1), "Single tween finishes and sets property")

	p1.Transparency = 0; p2.Transparency = 0
	local grp = Tween.linear({p1, p2}, {Transparency = 0.5}, 0.08, "grp")
	local r2 = grp:await()
	ok(r2 == "Finished" and approx(p1.Transparency, 0.5) and approx(p2.Transparency, 0.5), "Group tween finishes")

	p1.Transparency = 0
	local tw2 = Tween.linear(p1, {Transparency = 1}, 0.5, "cancelMe")
	nowait(0.05)
	Tween.cancelById("cancelMe")
	local r3 = tw2:await()
	ok(r3 == "Stopped", "Cancel sets result to 'Stopped'")
	ok(not Tween.isActive("cancelMe"), "Tween id removed after cancel")

	p1:Destroy(); p2:Destroy()
end)

it("Debounce & RateLimiter", function()
	local Debounce = Utils:debounce()
	local hits = 0
	local a = Debounce.call("K1", 0.25, function() hits += 1 end)
	local b = Debounce.call("K1", 0.25, function() hits += 1 end)
	task.wait() -- <— callback de Debounce se ejecuta con task.defer
	ok(a and not b and hits == 1, "Debounce prevents rapid re-entry")

	local rl = Utils:ratelimiter(2, 2) -- 2 tokens/s, burst 2
	ok(rl:allow() and rl:allow() and not rl:allow(), "RateLimiter enforces burst")
	nowait(0.6)
	ok(rl:allow(), "RateLimiter refills over time")
end)

it("RandomWeighted & SeededRng deterministic", function()
	local RW = Utils:random()
	local S1 = Utils:rng(42)
	local S2 = Utils:rng(42)
	local S3 = Utils:rng(99)

	local a1, a2, a3 = S1:nextInteger(1,10), S1:nextInteger(1,10), S1:nextInteger(1,10)
	local b1, b2, b3 = S2:nextInteger(1,10), S2:nextInteger(1,10), S2:nextInteger(1,10)
	ok(a1==b1 and a2==b2 and a3==b3, "SeededRng: same seed → same ints")

	local c1 = S3:nextInteger(1,10)
	ok(c1 ~= a1, "SeededRng: different seed → different sequence (likely)")

	local counts = {Common=0, Rare=0, Epic=0}
	for i=1,200 do
		local k = RW.pick({Common=60, Rare=30, Epic=10}, S1._random)
		counts[k] += 1
	end
	ok(counts.Common > counts.Rare and counts.Rare > counts.Epic, "RandomWeighted respects weights")
end)

it("ObjectPool: acquire/release returns same instance", function()
	local template = Instance.new("Part"); template.Anchored = true
	local pool = Utils:pool(template, 1)
	local a = pool:acquire(workspace)
	pool:release(a)
	local b = pool:acquire(workspace)
	ok(a == b, "ObjectPool reuses the same instance")
	template:Destroy(); pool:drain()
end)

it("Timeline orchestrates multiple steps", function()
	local p = newPart("TL")
	local tl = Utils:timeline(true)
		:to(p, {Transparency = 1}, 0.05)
		:wait(0.02)
		:to(p, {Transparency = 0}, 0.05)
	local res = tl:await()
	ok(approx(p.Transparency, 0), "Timeline finished with expected property")
	p:Destroy()
end)

it("ObjectiveManager basic flow", function()
	local OM = Utils:objectives()
	local id1 = OM:add({name="Restore power", required=2})
	local id2 = OM:add({name="Find keycard", required=1})
	ok(not OM:allDone(), "Objectives not done initially")
	OM:progress(id1, 1)
	ok(not OM:allDone(), "Halfway")
	OM:progress(id1, 1)
	OM:progress(id2, 1)
	ok(OM:allDone(), "All objectives completed")
end)

it("Director schedules spawns under low pressure", function()
	local rng = Utils:rng(7)
	local director = Utils:director({minGap=0.1, maxPressure=40, decay=3}, rng)
	local world = {
		players = { {hp=90, maxHp=100, recentHits=0} },
		timeSinceLastObjective = 0
	}
	local spawned = 0
	director:requestSpawn("slotA", function() spawned += 1 end)
	for i=1,30 do
		director:update(0.05, world)
		nowait(0.01)
	end
	ok(spawned >= 1, "Director executed queued spawn")
end)

return function()
	print("\n===== Utils Spec Summary =====")
	print(("Passed: %d | Failed: %d"):format(Results.passed, Results.failed))
	print("================================\n")
	return Results
end