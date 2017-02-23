class "Common"

function Common:__init()

	self.ImmobileBuffs = {
		[5] = true,
		[11] = true,
		[24] = true,
		[29] = true,
		["zhonyasringshield"] = true,
		["willrevive"] = true
	}

end

function Common:GotBuff(unit, buffName)
	for i = 0, 63 do 
		local Buff = unit:GetBuff(i)
		if Buff and Buff.name ~= "" and Game.Timer() >= Buff.startTime and Buff.expireTime < Game.Timer() then
			return Buff.count
		end
	end
	return 0
end

function Common:HasBuffType(unit, buffType)
	for i = 0, 63 do 
		local Buff = unit:GetBuff(i)
		if Buff and Buff.name ~= "" and Game.Timer() >= Buff.startTime and Buff.expireTime < Game.Timer() and Buff.type == buffType then
			return true
		end
	end
	return false
end

function Common:IsImmobile(unit)
	for i = 0, 63 do 
		local Buff = unit:GetBuff(i)
		if Buff and Buff.name ~= "" and Buff.count > 0 then
			if self.ImmobileBuffs[Buff.type] or self.ImmobileBuffs[Buff.name] then
				return Buff.expireTime
			end
		end
	end
	return false
end

function Common:GetDistance(Pos1, Pos2)
	return math.sqrt((Pos2.x - Pos1.x)^2 + (Pos2.y - Pos1.y)^2 + (Pos2.z - Pos1.z)^2)
end

function Common:GetPercentHP(unit)
	return (unit.health / unit.maxHealth) * 100
end

function Common:GetPercentMP(unit)
	return (unit.mana / unit.maxMana) * 100
end

function Common:Ready(slot)
	return Game.CanUseSpell(slot) == 0
end

function Common:GetTarget()
	local Closest = math.huge
	local Best
	for i = 1, Game.HeroCount() do
		local H = Game.Hero(i)
		if H.team ~= myHero.team and self:ValidTarget(H) and H.distance < Closest then
			Closest = H.distance
			Best = H
		end
	end
	return Best
end

function Common:ValidTarget(unit, range)
	local range = type(range) == "number" and range or math.huge
	return unit and unit.team ~= myHero.team and unit.valid and unit.distance <= range and not unit.dead and unit.isTargetable and unit.visible
end

function Common:EnemiesAround(pos, range)
	local C = 0
	for i = 1, Game.HeroCount() do
		local H = Game.Hero(i)
		if H.isEnemy and self:ValidTarget(H) and self:GetDistance(H.pos, pos) <= range then
			C = C + 1
		end
	end
	return C
end

class "Jinx"

function Jinx:__init()

	self.Menu = MenuElement({id = "Jinx", name = "Jinx", type = MENU, leftIcon = "http://ddragon.leagueoflegends.com/cdn/6.24.1/img/champion/"..myHero.charName..".png"})
	
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "CQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "CW", name = "Use W", value = true})
	
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "HQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "HW", name = "Use W", value = true})
	self.Menu.Harass:MenuElement({id = "CMM", name = "Min Mana To Harass", value = 50, min = 0, max = 100, step = 1})
	
	self.Menu:MenuElement({id = "Killsteal", name = "Killsteal", type = MENU})
	self.Menu.Killsteal:MenuElement({id = "KSW", name = "Killsteal W", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSR", name = "Killsteal R", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSRR", name = "R Max Range", value = 2500, min = 300, max = 25000, step = 100})
	
	self.Menu:MenuElement({id = "Misc", name = "Misc", type = MENU})
	self.Menu.Misc:MenuElement({id = "ECC", name = "Auto E On CC", value = true})
	
	self.Menu:MenuElement({id = "Draw", name = "Drawings", type = MENU})
	
	self.Menu.Draw:MenuElement({id = "DA", name = "Disable All Drawings", value = false})
	
	self.Menu.Draw:MenuElement({id = "DRocket", name = "Draw Rocket Range", type = MENU})
	self.Menu.Draw.DRocket:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.Draw.DRocket:MenuElement({id = "Width", name = "Width", value = 2, min = 1, max = 5, step = 1})
	self.Menu.Draw.DRocket:MenuElement({id = "Color", name = "Color", color = Draw.Color(255, 255, 0, 0)})
	
	self.Menu.Draw:MenuElement({id = "DMinigun", name = "Draw Minigun Range", type = MENU})
	self.Menu.Draw.DMinigun:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.Draw.DMinigun:MenuElement({id = "Width", name = "Width", value = 2, min = 1, max = 5, step = 1})
	self.Menu.Draw.DMinigun:MenuElement({id = "Color", name = "Color", color = Draw.Color(255, 0, 0, 255)})
	
	self.Menu.Draw:MenuElement({id = "DW", name = "Draw W Range", type = MENU})
	self.Menu.Draw.DW:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.Draw.DW:MenuElement({id = "Width", name = "Width", value = 2, min = 1, max = 5, step = 1})
	self.Menu.Draw.DW:MenuElement({id = "Color", name = "Color", color = Draw.Color(255, 255, 255, 255)})
	
	self.Menu.Draw:MenuElement({id = "DE", name = "Draw E Range", type = MENU})
	self.Menu.Draw.DE:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.Draw.DE:MenuElement({id = "Width", name = "Width", value = 2, min = 1, max = 5, step = 1})
	self.Menu.Draw.DE:MenuElement({id = "Color", name = "Color", color = Draw.Color(255, 255, 255, 255)})
	
	
	self.Target = nil
	
	self.Spells = {
		[1] = {range = 1500, delay = 0.6, width = 60, speed = 3300},
		[2] = {range = 900, delay = 0.75, width = 50, speed = math.huge},
		[3] = {range = math.huge, delay = 0.6, width = 140}
	}
	
	self.Damage = {
	[0] = function(unit) return EOW:CalcPhysicalDamage(myHero, unit, (not self:GotMinigun() and myHero.totalDamage * 1.1 or myHero.totalDamage)) end,
	[1] = function(unit) return EOW:CalcPhysicalDamage(myHero, unit, (-40 + (50 * myHero:GetSpellData(_W).level)) + (myHero.totalDamage * 1.4)) end,
	[3] = function(unit) return EOW:CalcPhysicalDamage(myHero, unit, (150 + (100 * myHero:GetSpellData(_R).level)) + (myHero.bonusDamage * 1.5) + ((unit.maxHealth - unit.health) * (0.2 + (0.05 * myHero:GetSpellData(_W).level)))) end
	}
	
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)

end

function Jinx:Tick()
	self.Target = EOW:GetTarget() or Common:GetTarget()
	
	if EOW:Mode() == "Combo" then
		self:Combo()
	elseif EOW:Mode() == "Harass" then
		self:Harass()
	end
	
	self:AutoE()
	
	self:Killsteal()
end

function Jinx:Draw()
	if self.Menu.Draw.DA:Value() then
		return
	end
	
	if self.Menu.Draw.DRocket.Enabled:Value() then
		Draw.Circle(myHero.pos, self:RocketRange(), self.Menu.Draw.DRocket.Width:Value(), self.Menu.Draw.DRocket.Color:Value())
	end
	
	if self.Menu.Draw.DMinigun.Enabled:Value() then
		Draw.Circle(myHero.pos, self:MinigunRange(), self.Menu.Draw.DMinigun.Width:Value(), self.Menu.Draw.DMinigun.Color:Value())
	end
	
	if self.Menu.Draw.DW.Enabled:Value() then
		Draw.Circle(myHero.pos, self.Spells[1].range, self.Menu.Draw.DW.Width:Value(), self.Menu.Draw.DW.Color:Value())
	end
	
	if self.Menu.Draw.DE.Enabled:Value() then
		Draw.Circle(myHero.pos, self.Spells[2].range, self.Menu.Draw.DE.Width:Value(), self.Menu.Draw.DE.Color:Value())
	end
end

function Jinx:Combo()
	if myHero.attackData.state == STATE_WINDUP or not self.Target then
		return
	end
	
	if self.Menu.Combo.CW:Value() and Common:Ready(_W) and Common:ValidTarget(self.Target, self.Spells[1].range) and (Common:GetDistance(myHero.pos, self.Target.pos) > myHero.range or Common:IsImmobile(self.Target)) then
		self:CastW(self.Target)
	end

	if self.Menu.Combo.CQ:Value() and Common:Ready(_Q) then
		local Minigun = self:GotMinigun()
		local MinigunRange = self:MinigunRange()
		local RocketRange = self:RocketRange()
		local Distance = Common:GetDistance(myHero.pos, self.Target.pos)
		if Common:ValidTarget(self.Target, RocketRange) then
			if Minigun then
				if Common:EnemiesAround(self.Target.pos, 230) > 1 or Distance > MinigunRange then
					Order:CastSpell(_Q)
				end
			elseif Distance <= MinigunRange and Common:EnemiesAround(self.Target.pos, 230) == 1 then
				Order:CastSpell(_Q)
			end
		elseif not Minigun and Distance > RocketRange then
			Order:CastSpell(_Q)
		end
	end
end

function Jinx:Harass()
	if myHero.attackData.state == STATE_WINDUP or not self.Target then
		return
	end
	local Minigun = self:GotMinigun()
	if Common:GetPercentMP(myHero) < self.Menu.Harass.HMM:Value() then
		if not Minigun and Common:Ready(_Q) then
			Order:CastSpell(_Q)
		end
		return
	end
	
	if self.Menu.Harass.HW:Value() and Common:Ready(_W) and Common:ValidTarget(self.Target, self.Spells[1].range) and (Common:GetDistance(myHero.pos, self.Target.pos) > myHero.range or Common:IsImmobile(self.Target)) then
		self:CastW(self.Target)
	end
	
	if self.Menu.Harass.HQ:Value() and Common:Ready(_Q) then
		local MinigunRange = self:MinigunRange()
		local RocketRange = self:RocketRange()
		local Distance = Common:GetDistance(myHero.pos, self.Target.pos)
		if Common:ValidTarget(self.Target, RocketRange) then
			if Minigun then
				if Common:EnemiesAround(self.Target.pos, 230) > 1 or Distance > MinigunRange then
					Order:CastSpell(_Q)
				end
			elseif Distance <= MinigunRange and Common:EnemiesAround(self.Target.pos, 230) <= 1 then
				Order:CastSpell(_Q)
			end
		elseif not Minigun and Distance > 1000 then
			Order:CastSpell(_Q)
		end
	end
end

function Jinx:AutoE()
	if not Common:Ready(_E) or not self.Menu.Misc.ECC:Value() then
		return
	end
	for i = 1, Game.HeroCount() do
		local e = Game.Hero(i)
		if e.team ~= myHero.team then
			if not e.dead and Common:GetDistance(myHero.pos, e.pos) <= self.Spells[2].range then
				local ExpireTime = Common:IsImmobile(e)
				if ExpireTime and ExpireTime > Game.Timer() + self.Spells[2].delay and Game.Timer() < ExpireTime - self.Spells[2].delay then
					Order:CastSpell(_E, e.pos)
					return
				end
			end
		end
	end
end

function Jinx:Killsteal()
	for i = 1, Game.HeroCount() do
		local e = Game.Hero(i)
		if e and e.team ~= myHero.team then
			if self.Menu.Killsteal.KSW:Value() and Common:Ready(_W) and Common:GetDistance(myHero.pos, e.pos) > myHero.range and Common:ValidTarget(e, self.Spells[1].range) and self.Damage[1](e) > e.health then
				self:CastW(e)
				break
			elseif self.Menu.Killsteal.KSR:Value() and Common:Ready(_R) and Common:GetDistance(myHero.pos, e.pos) > myHero.range and Common:ValidTarget(e, self.Menu.Killsteal.KSRR:Value()) and self.Damage[3](e) > e.health then
				self:CastR(e)
				break
			end
		end
	end
end

function Jinx:GotMinigun()
	return myHero:GetSpellData(_Q).toggleState == 1
end

function Jinx:CastW(unit)
	local Pred = unit:GetPrediction(self.Spells[1].speed, self.Spells[1].delay)
	local Col = unit:GetCollision(self.Spells[1].width, self.Spells[1].speed, self.Spells[1].delay)
	if Pred and Col == 0 then
		Pred = Vector(Pred)
		Pred = myHero.pos + (Pred - myHero.pos):Normalized() * 300
		Order:CastSpell(_W, Pred)
	end
end

function Jinx:CastR(unit)
	local Speed =  unit.distance > 1350 and (2295000 + (unit.distance - 1350) * 2200) / unit.distance or 1700
	local Pred = unit:GetPrediction(Speed, self.Spells[3].delay)
	if Pred then
		Pred = Vector(Pred)
		Pred = myHero.pos + (Pred - myHero.pos):Normalized() * 300
		Order:CastSpell(_R, Pred)
	end
end

function Jinx:MinigunRange()
	return 525 + myHero.boundingRadius
end

function Jinx:RocketRange()
	return 525 + myHero.boundingRadius + (50 + (25 * myHero:GetSpellData(_Q).level))
end

Callback.Add("Load", function()
	if _G[myHero.charName] then
		_G.Common = Common()
		_G[myHero.charName]()
	end
end)
