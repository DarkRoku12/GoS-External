class "Common"

function Common:__init()
	
	require("MapPosition")
	
	self.str = {[0] = "Q", [1] = "W", [2] = "E", [3] = "R"}
	
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

function Common:GetDistanceSqr(Pos1, Pos2)
	local Pos2 = Pos2 or myHero.pos
	local dx = Pos1.x - Pos2.x
	local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
	return dx^2 + dz^2
end

function Common:GetDistance(Pos1, Pos2)
	return math.sqrt(self:GetDistanceSqr(Pos1, Pos2))
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

function Common:VectorPointProjectionOnLineSegment(v1, v2, v)
	local cx, cy, ax, ay, bx, by = v.x, (v.z or v.y), v1.x, (v1.z or v1.y), v2.x, (v2.z or v2.y)
    local rL = ((cx - ax) * (bx - ax) + (cy - ay) * (by - ay)) / ((bx - ax) ^ 2 + (by - ay) ^ 2)
    local pointLine = { x = ax + rL * (bx - ax), y = ay + rL * (by - ay) }
    local rS = rL < 0 and 0 or (rL > 1 and 1 or rL)
    local isOnSegment = rS == rL
    local pointSegment = isOnSegment and pointLine or {x = ax + rS * (bx - ax), y = ay + rS * (by - ay)}
	return pointSegment, pointLine, isOnSegment
end

function Common:GetPrediction(unit, spellData)
	local pos = unit.posTo
	local unitpos = unit.pos
	if pos == unitpos or self:IsImmobile(unit) then
		return unitpos
	end
	local speed = spellData.speed
	local delay = spellData.delay
	local delay = delay + (Game.Latency() * 0.001) + (EOW.ClickDelay / 2)
	local WalkDistance = (((Common:GetDistance(myHero.pos, unitpos) / speed) + delay) * unit.ms)
	local Pred = unitpos + (pos - unitpos):Normalized() * WalkDistance
	local LineSeg = LineSegment(Point(pos), Point(unitpos))
	if MapPosition:intersectsWall(LineSeg) then
		Pred = unitpos + (unit.dir):Normalized() * WalkDistance
	end
	if Common:GetDistance(myHero.pos, Pred) > spellData.range then
		return false
	end
	return Pred
end

function Common:GetHeroCollision(StartPos, EndPos, Width, Target)
	local Count = 0
	for i = 1, Game.HeroCount() do
		local h = Game.Hero(i)
		if h and h ~= Target and h.isEnemy and Common:ValidTarget(h) then
			local w = Width + h.boundingRadius
			pointSegment, pointLine, isOnSegment = self:VectorPointProjectionOnLineSegment(StartPos, EndPos, h.pos)
			if isOnSegment and self:GetDistanceSqr(pointSegment, h.pos) < w^2 and self:GetDistanceSqr(StartPos, EndPos) > self:GetDistanceSqr(StartPos, h.pos) then
				Count = Count + 1
			end
		end
	end
	return Count
end

function Common:GetMinionCollision(StartPos, EndPos, Width, Target)
	local Count = 0
	for i = 1, Game.MinionCount() do
		local m = Game.Minion(i)
		if m and m ~= Target and not m.isAlly and Common:ValidTarget(m) then
			local w = Width + m.boundingRadius
			pointSegment, pointLine, isOnSegment = self:VectorPointProjectionOnLineSegment(StartPos, EndPos, m.pos)
			if isOnSegment and self:GetDistanceSqr(pointSegment, m.pos) < w^2 and self:GetDistanceSqr(StartPos, EndPos) > self:GetDistanceSqr(StartPos, m.pos) then
				Count = Count + 1
			end
		end
	end
	return Count
end

function Common:GetItemSlot(unit, itemID)
	for i = ITEM_1, ITEM_7 do
		if unit:GetItemData(i).itemID == itemID then
			return i
		end
	end
	return 0
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
	self.Menu.Harass:MenuElement({id = "HMM", name = "Min Mana To Harass", value = 50, min = 0, max = 100, step = 1})
	
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
			if self.Menu.Killsteal.KSW:Value() and Common:Ready(_W) and Common:GetDistance(myHero.pos, e.pos) > myHero.range and Common:ValidTarget(e, self.Spells[1].range) and self.Damage[1](e) >= e.health + e.shieldAD then
				self:CastW(e)
				break
			elseif self.Menu.Killsteal.KSR:Value() and Common:Ready(_R) and Common:GetDistance(myHero.pos, e.pos) > myHero.range and Common:ValidTarget(e, self.Menu.Killsteal.KSRR:Value()) and self.Damage[3](e) >= e.health + e.shieldAD then
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
	local Pred = Common:GetPrediction(unit, self.Spells[1])
	if Pred and Common:GetHeroCollision(myHero.pos, Pred, self.Spells[1].width, unit) == 0 and Common:GetMinionCollision(myHero.pos, Pred, self.Spells[1].width, unit) == 0 then
		Pred = Vector(Pred)
		Pred = myHero.pos + (Pred - myHero.pos):Normalized() * 300
		Order:CastSpell(_W, Pred)
	end
end

function Jinx:CastR(unit)
	local Speed =  unit.distance > 1350 and (2295000 + (unit.distance - 1350) * 2200) / unit.distance or 1700
	self.Spells[3].speed = Speed
	local Pred = Common:GetPrediction(unit, self.Spells[3])
	if Pred and Common:GetHeroCollision(myHero.pos, Pred, self.Spells[3].width, unit) == 0 then
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

class "Ezreal"

function Ezreal:__init()
	
	self.Spells = {
		[0] = {delay = 0.25, speed = 2000, range = 1200, width = 60},
		[1] = {delay = 0.25, speed = 1600, range = 1050, width = 80},
		[2] = {delay = 0.25, speed = math.huge, range = 450, width = 1},
		[3] = {delay = 1, speed = 2000, range = math.huge, width = 160}
	}
	
	self.Damage = {
		[0] = function(unit)
			local BaseDamage = 15 + (20 * myHero:GetSpellData(_Q).level) + (myHero.ap * 0.4) + (myHero.totalDamage * 1.1)
			local BonusPhysicalDamage = 0
			local BonusMagicalDamage = 0
			local Sheen = nil
			local TriForce = nil
			local Lichbane = nil
			local IceBorn = nil
			for i = ITEM_1, ITEM_7 do
				local ItemID = myHero:GetItemData(i).itemID
				if ItemID == 3057 then
					Sheen = i
				elseif ItemID == 3100 then
					Lichbane = i
				elseif ItemID == 3078 then
					TriForce = i
				elseif ItemID == 3025 then
					IceBorn = i
				end
			end
			if Sheen then
				if Game.CanUseSpell(Sheen) ~= ONCOOLDOWN or Common:GotBuff(myHero, "sheen") > 0 then
					BonusPhysicalDamage = myHero.baseDamage
				end
			elseif TriForce then
				if Game.CanUseSpell(TriForce) ~= ONCOOLDOWN or Common:GotBuff(myHero, "sheen") > 0 then
					BonusPhysicalDamage = myHero.baseDamage * 2
				end
			elseif IceBorn then
				if Game.CanUseSpell(IceBorn) ~= ONCOOLDOWN or Common:GotBuff(myHero, "itemfrozenfist") > 0 then
					BonusPhysicalDamage = myHero.baseDamage
				end
			elseif Lichbane then
				if Game.CanUseSpell(Lichbane) ~= ONCOOLDOWN or Common:GotBuff(myHero, "lichbane") > 0 then
					BonusMagicalDamage = (myHero.baseDamage * 0.75) + (myHero.ap * 0.5)
				end
			end
			return EOW:CalcPhysicalDamage(myHero, unit, BaseDamage + BonusMagicalDamage + BonusPhysicalDamage)
		end,
		[1] = function(unit)
			return EOW:CalcMagicalDamage(myHero, unit, 25 + (45 * myHero:GetSpellData(_W).level) + (myHero.ap + 0.8))
		end,
		[3] = function(unit)
			local BaseDamage = 200 + (150 * myHero:GetSpellData(_R).level) + (myHero.bonusDamage) + (myHero.ap * 0.9)
			local Reduction = math.min(Common:GetHeroCollision(myHero.pos, unit.pos, self.Spells[3].width, unit) + Common:GetMinionCollision(myHero.pos, unit.pos, self.Spells[3].width, unit), 7)
			BaseDamage = BaseDamage * ((10 - Reduction) / 10)
			return EOW:CalcMagicalDamage(myHero, unit, BaseDamage)
		end
	}
	
	self.Menu = MenuElement({id = "Ezreal", name = "Ezreal", type = MENU, leftIcon = "http://ddragon.leagueoflegends.com/cdn/6.24.1/img/champion/"..myHero.charName..".png"})
	
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "CQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "CW", name = "Use W", value = true})
	self.Menu.Combo:MenuElement({id = "CR", name = "Use R", value = true})
	self.Menu.Combo:MenuElement({id = "Items", name = "Items", type = MENU})
	self.Menu.Combo.Items:MenuElement({id = "BORK", name = "Blade of the Ruined King", value = true})
	self.Menu.Combo.Items:MenuElement({id = "BORKMYHP", name = "Use If My HP < x%", value = 70, min = 1, max = 100, step = 1})
	self.Menu.Combo.Items:MenuElement({id = "BORKEHP", name = "Use If Target HP < x%", value = 70, min = 1, max = 100, step = 1})
	self.Menu.Combo.Items:MenuElement({id = "Bilge", name = "Bilgewater Cutlass", value = true})
	self.Menu.Combo.Items:MenuElement({id = "BilgeMYHP", name = "Use If My HP < x%", value = 70, min = 1, max = 100, step = 1})
	self.Menu.Combo.Items:MenuElement({id = "BilgeEHP", name = "Use If Target HP < x%", value = 70, min = 1, max = 100, step = 1})
	
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "HQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "HW", name = "Use W", value = true})
	self.Menu.Harass:MenuElement({id = "HMM", name = "Min Mana To Harass", value = 50, min = 1, max = 100, step = 1})
	
	self.Menu:MenuElement({id = "Killsteal", name = "Killsteal", type = MENU})
	self.Menu.Killsteal:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSQ", name = "Use Q", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSW", name = "Use W", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSR", name = "Use R", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSRC", name = "R Max Range", value = 2000, min = 300, max = 25000, step = 100})
	
	self.Menu:MenuElement({id = "Draw", name = "Drawings", type = MENU})
	self.Menu.Draw:MenuElement({id = "DA", name = "Disable All Drawings", value = false})
	for i = 0, 2 do
		self.Menu.Draw:MenuElement({id = "D"..Common.str[i], name = "Draw "..Common.str[i].." Range", type = MENU})
		self.Menu.Draw["D"..Common.str[i]]:MenuElement({id = "Enabled", name = "Enabled", value = true})
		self.Menu.Draw["D"..Common.str[i]]:MenuElement({id = "Width", name = "Width", value = 2, min = 1, max = 5, step = 1})
		self.Menu.Draw["D"..Common.str[i]]:MenuElement({id = "Color", name = "Color", color = Draw.Color(255, 255, 255, 255)})
	end
	
	self.Menu:MenuElement({id = "Misc", name = "Misc", type = MENU})
	
	self.Target = nil
	
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Ezreal:Tick()
	self.Target = EOW:GetTarget() or Common:GetTarget()
	
	if EOW:Mode() == "Combo" then
		self:Combo()
	elseif EOW:Mode() == "Harass" then
		self:Harass()
	end
	
	if self.Menu.Killsteal.Enabled:Value() then
		self:Killsteal()
	end
end

function Ezreal:Draw()
	if self.Menu.Draw.DA:Value() then
		return
	end
	for i = 0, 2 do
		local Str = Common.str[i]
		if self.Menu.Draw["D"..Str].Enabled:Value() then
			Draw.Circle(myHero.pos, self.Spells[i].range, self.Menu.Draw["D"..Str].Width:Value(), self.Menu.Draw["D"..Str].Color:Value())
		end
	end
end

function Ezreal:Combo()
	if myHero.attackData.state == STATE_WINDUP or not self.Target then
		return
	end
	
	if self.Menu.Combo.CQ:Value() and Common:Ready(_Q) and Common:ValidTarget(self.Target, self.Spells[0].range) then
		self:CastQ(self.Target)
	end
	
	if self.Menu.Combo.CW:Value() and Common:Ready(_W) and Common:ValidTarget(self.Target, self.Spells[1].range) then
		self:CastW(self.Target)
	end
	
	if self.Menu.Combo.CR:Value() and Common:Ready(_R) and Common:ValidTarget(self.Target, 2000) then
		if Common:GetPercentHP(self.Target) <= 50 and Common:GetDistance(myHero.pos, self.Target.pos) > 800 and Common:EnemiesAround(myHero.pos, 800) <= 1 then
			self:CastR(self.Target)
		end
	end
	
	if self.Menu.Combo.Items.BORK:Value() then
		local Bork = Common:GetItemSlot(myHero, 3153)
		if Bork > 0 and Common:Ready(Bork) and Common:ValidTarget(self.Target, 550) and Common:GetPercentHP(myHero) <= self.Menu.Combo.Items.BORKMYHP:Value() and Common:GetPercentHP(self.Target) <= self.Menu.Combo.Items.BORKEHP:Value() then
			Order:CastSpell(Bork, self.Target.pos)
		end
	end
	
	if self.Menu.Combo.Items.Bilge:Value() then
		local Bilge = Common:GetItemSlot(myHero, 3144)
		if Bilge > 0 and Common:Ready(Bilge) and Common:ValidTarget(self.Target, 550) and Common:GetPercentHP(myHero) <= self.Menu.Combo.Items.BilgeMYHP:Value() and Common:GetPercentHP(self.Target) <= self.Menu.Combo.Items.BilgeEHP:Value() then
			Order:CastSpell(Bilge, self.Target.pos)
		end
	end
end

function Ezreal:Harass()
	if myHero.attackData.state == STATE_WINDUP or not self.Target or Common:GetPercentMP(myHero) < self.Menu.Harass.HMM:Value() then
		return
	end
	
	if self.Menu.Harass.HQ:Value() and Common:Ready(_Q) and Common:ValidTarget(self.Target, self.Spells[0].range) then
		self:CastQ(self.Target)
	end
	
	if self.Menu.Harass.HW:Value() and Common:Ready(_W) and Common:ValidTarget(self.Target, self.Spells[1].range) then
		self:CastW(self.Target)
	end
end

function Ezreal:Killsteal()
	if myHero.attackData.state == STATE_WINDUP then
		return
	end
	for i = 1, Game.HeroCount() do
		local h = Game.Hero(i)
		if h and h.isEnemy then
			if self.Menu.Killsteal.KSQ:Value() and Common:Ready(_Q) and Common:ValidTarget(h, self.Spells[0].range) and self.Damage[0](h) >= h.health + h.shieldAD then
				self:CastQ(h)
			elseif self.Menu.Killsteal.KSW:Value() and Common:Ready(_W) and Common:ValidTarget(h, self.Spells[1].range) and self.Damage[1](h) >= h.health + h.shieldAP then
				self:CastW(h)
			elseif self.Menu.Killsteal.KSR:Value() and Common:Ready(_R) and Common:ValidTarget(h, self.Menu.Killsteal.KSRC:Value()) and Common:GetDistance(myHero.pos, h.pos) > myHero.range and self.Damage[3](h) >= h.health + h.shieldAD then
				self:CastR(h)
			end
		end
	end
end

function Ezreal:CastQ(unit)
	local Pred = Common:GetPrediction(unit, self.Spells[0])
	if Pred and Common:GetHeroCollision(myHero.pos, Pred, self.Spells[0].width, unit) == 0 and Common:GetMinionCollision(myHero.pos, Pred, self.Spells[0].width, unit) == 0 then
		Order:CastSpell(_Q, Pred)
	end
end

function Ezreal:CastW(unit)
	local Pred = Common:GetPrediction(unit, self.Spells[1])
	if Pred then
		Order:CastSpell(_W, Pred)
	end
end

function Ezreal:CastR(unit)
	local Pred = Common:GetPrediction(unit, self.Spells[3])
	if Pred then
		Pred = Vector(Pred)
		Pred = myHero.pos + (Pred - myHero.pos):Normalized() * 500
		Order:CastSpell(_R, Pred)
	end
end

class "Lux"

function Lux:__init()

	self.Spells = {
		[0] = {delay = 0.25, speed = 1600, range = 1300, width = 70},
		[1] = {delay = 0.25, speed = 1400, range = 1075},
		[2] = {delay = 0.25, speed = 1300, range = 1100, width = 350},
		[3] = {delay = 1, speed = math.huge, range = 3500, width = 190}
	}
	
	self.Damage = {
		[0] = function(unit)
			return EOW:CalcMagicalDamage(myHero, unit, (50 * myHero:GetSpellData(_Q).level) + (myHero.ap * 0.7))
		end,
		[2] = function(unit)
			return EOW:CalcMagicalDamage(myHero, unit, 15 + (45 * myHero:GetSpellData(_E).level) + (myHero.ap * 0.6))
		end,
		[3] = function(unit)
			local BaseDamage = 200 + (100 * myHero:GetSpellData(_R).level) + (myHero.ap * 0.75)
			local BonusDamage = Common:GotBuff(unit, "luxilluminatingfraulein") > 0 and 10 + (myHero.levelData.lvl * 10) + (myHero.ap * 0.2) or 0
			return EOW:CalcMagicalDamage(myHero, unit, BaseDamage + BonusDamage)
		end
	}
	
	self.Target = nil
	
	self.Menu = MenuElement({id = "Lux", name = "Lux", type = MENU, leftIcon = "http://ddragon.leagueoflegends.com/cdn/6.24.1/img/champion/"..myHero.charName..".png"})
	
	self.Menu:MenuElement({id = "Combo", name = "Combo", type = MENU})
	self.Menu.Combo:MenuElement({id = "CQ", name = "Use Q", value = true})
	self.Menu.Combo:MenuElement({id = "CE", name = "Use E", value = true})
	self.Menu.Combo:MenuElement({id = "CR", name = "Use R", value = true})
	
	self.Menu:MenuElement({id = "Harass", name = "Harass", type = MENU})
	self.Menu.Harass:MenuElement({id = "HQ", name = "Use Q", value = true})
	self.Menu.Harass:MenuElement({id = "HE", name = "Use E", value = true})
	self.Menu.Harass:MenuElement({id = "HMM", name = "Min Mana To Harass", value = 60, min = 1, max = 100, step = 1})
	
	self.Menu:MenuElement({id = "Killsteal", name = "Killsteal", type = MENU})
	self.Menu.Killsteal:MenuElement({id = "Enabled", name = "Enabled", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSQ", name = "Use Q", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSE", name = "Use E", value = true})
	self.Menu.Killsteal:MenuElement({id = "KSR", name = "Use R", value = true})
	
	self.Menu:MenuElement({id = "Misc", name = "Misc", type = MENU})
	self.Menu.Misc:MenuElement({id = "AE", name = "Auto E2", value = true})
	self.Menu.Misc:MenuElement({id = "AQCC", name = "Auto Q On CC", value = true})
	self.Menu.Misc:MenuElement({id = "AECC", name = "Auto E On CC", value = true})
	
	self.Menu:MenuElement({id = "Draw", name = "Drawings", type = MENU})
	self.Menu.Draw:MenuElement({id = "DA", name = "Disable All Draws", value = true})
	for i = 0, 3 do
		local k = Common.str[i]
		self.Menu.Draw:MenuElement({id = "D"..k, name = "Draw "..k.." Range", type = MENU})
		self.Menu.Draw["D"..k]:MenuElement({id = "Enabled", name = "Enabled", value = true})
		self.Menu.Draw["D"..k]:MenuElement({id = "Width", name = "Width", value = 2, min = 1, max = 5, step = 1})
		self.Menu.Draw["D"..k]:MenuElement({id = "Color", name = "Color", color = Draw.Color(255, 255, 255, 255)})
	end
	
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
end

function Lux:Tick()
	self.Target = EOW:GetTarget() or Common:GetTarget()
	
	if EOW:Mode() == "Combo" then
		self:Combo()
	elseif EOW:Mode() == "Harass" then
		self:Harass()
	end
	
	self:Auto()
	
	if self.Menu.Killsteal.Enabled:Value() then
		self:Killsteal()
	end
end

function Lux:Draw()
	if self.Menu.Draw.DA:Value() then
		return
	end
	for i = 0, 3 do
		local k = Common.str[i]
		if self.Menu.Draw["D"..k].Enabled:Value() then
			Draw.Circle(myHero.pos, self.Spells[i].range, self.Menu.Draw["D"..k].Width:Value(), self.Menu.Draw["D"..k].Color:Value())
		end
	end
end

function Lux:Combo()
	if myHero.attackData.state == STATE_WINDUP then
		return
	end
	
	if self.Menu.Combo.CQ:Value() and Common:Ready(_Q) and Common:ValidTarget(self.Target, self.Spells[0].range) then
		self:CastQ(self.Target)
	end
	
	if self.Menu.Combo.CE:Value() and Common:Ready(_E) then
		if not self:IsE2() and Common:ValidTarget(self.Target, self.Spells[2].range) then
			self:CastE(self.Target)
		elseif self:IsE2() then
			Order:CastSpell(_E)
		end
	end
	
	if self.Menu.Combo.CR:Value() and Common:Ready(_R) and Common:ValidTarget(self.Target, self.Spells[3].range) and self.Damage[3](self.Target) >= self.Target.health + self.Target.shieldAP then
		self:CastR(self.Target)
	end
end

function Lux:Harass()
	if myHero.attackData.state == STATE_WINDUP or Common:GetPercentMP(myHero) < self.Menu.Harass.HMM:Value() then
		return
	end
	
	if self.Menu.Harass.HQ:Value() and Common:Ready(_Q) and Common:ValidTarget(self.Target, self.Spells[0].range) then
		self:CastQ(self.Target)
	end
	
	if self.Menu.Harass.HE:Value() and Common:Ready(_E) then
		if not self:IsE2() and Common:ValidTarget(self.Target, self.Spells[2].range) then
			self:CastE(self.Target)
		elseif self:IsE2() then
			Order:CastSpell(_E)
		end
	end
end

function Lux:Killsteal()
	if myHero.attackData.state == STATE_WINDUP then
		return
	end
	for i = 1, Game.HeroCount() do
		local h = Game.Hero(i)
		if h and h.isEnemy then
			if self.Menu.Killsteal.KSQ:Value() and Common:Ready(_Q) and Common:ValidTarget(h, self.Spells[0].range) and self.Damage[0](h) >= h.health + h.shieldAP then
				self:CastQ(h)
				break
			elseif self.Menu.Killsteal.KSE:Value() and Common:Ready(_E) and self.Damage[2](h) >= h.health + h.shieldAP then
				if not self:IsE2() and Common:ValidTarget(h, self.Spells[2].range) then
					self:CastE(h)
					break
				elseif self:IsE2() then
					Order:CastSpell(_E)
					break
				end
			elseif self.Menu.Killsteal.KSR:Value() and Common:Ready(_R) and Common:ValidTarget(h, self.Spells[3].range) and self.Damage[3](h) >= h.health + h.shieldAP then
				self:CastR(h)
				break
			end
		end
	end
end

function Lux:Auto()
	if self.Menu.Misc.AE:Value() and self:IsE2() then
		Order:CastSpell(_E)
	end
	for i = 1, Game.HeroCount() do
		local h = Game.Hero(i)
		if h and h.isEnemy then 
			if self.Menu.Misc.AECC:Value() and Common:Ready(_E) and Common:ValidTarget(h, self.Spells[2].range) and Common:IsImmobile(h) then
				self:CastE(h)
			elseif self.Menu.Misc.AQCC:Value() and Common:Ready(_Q) and not h.dead and Common:GetDistance(myHero.pos, h.pos) <= self.Spells[0].range then
				local ExpireTime = Common:IsImmobile(h)
				local TimeToReach = self.Spells[0].delay + (Common:GetDistance(myHero.pos, h.pos) / self.Spells[0].speed)
				if ExpireTime and ExpireTime > Game.Timer() + TimeToReach and Game.Timer() < ExpireTime - TimeToReach then
					self:CastQ(h)
				end
			end
		end	
	end
end

function Lux:CastQ(unit)
	local Pred = Common:GetPrediction(unit, self.Spells[0])
	if Pred and Common:GetHeroCollision(myHero.pos, Pred, self.Spells[0].width, unit) + Common:GetMinionCollision(myHero.pos, Pred, self.Spells[0].width, unit) < 2 then
		Pred = Vector(Pred)
		Pred = myHero.pos + (Pred - myHero.pos):Normalized() * 300
		Order:CastSpell(_Q, Pred)
	end
end

function Lux:CastE(unit)
	if self:IsE2() then
		return
	end
	local Pred = Common:GetPrediction(unit, self.Spells[2])
	if Pred then
		Order:CastSpell(_E, Pred)
	end
end

function Lux:CastR(unit)
	local Pred = Common:GetPrediction(unit, self.Spells[3])
	if Pred then
		Pred = Vector(Pred)
		Pred = myHero.pos + (Pred - myHero.pos):Normalized() * 300
		Order:CastSpell(_R, Pred)
	end
end

function Lux:IsE2()
	return myHero:GetSpellData(_E).toggleState == 2
end

Callback.Add("Load", function()
	if _G[myHero.charName] then
		_G.Common = Common()
		_G[myHero.charName]()
	end
end)
