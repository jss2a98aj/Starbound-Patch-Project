function init()
  --Instantly spawn the pet when first created
  storage.spawnTimer = storage.spawnTimer and 0.5 or 0
  storage.petParams = storage.petParams or {}

  self.monsterType = config.getParameter("shipPetType", "petcat")
  self.spawnOffset = config.getParameter("spawnOffset", {0, 2})

  message.setHandler("activateShip", function()
    animator.playSound("shipUpgrade")
    self.dialog = config.getParameter("dialog.wakeUp")
    self.dialogTimer = 0.0
    self.dialogInterval = 5.0
    self.drawMoreIndicator = true
    object.setOfferedQuests({})
  end)

  message.setHandler("wakePlayer", function()
    self.dialog = config.getParameter("dialog.wakePlayer")
    self.dialogTimer = 0.0
    self.dialogInterval = 14.0
    self.drawMoreIndicator = false
    object.setOfferedQuests({})
  end)

  -- (\_/) Fix crash when placing 2x (or more) S.A.I.L
  --  		Lofty 2025/05/13
  -- 
  --  When placing any techstation, verify whether or not an object
  --  with the uniqueId "techstation" already exists in the world.
  --  
  --  If another object already exists with this uniqueId, save its
  --  entityId locally.
  -- 
  --  If another object does not already exist with this uniqueId,
  --  update our uniqueId for quest tracking.
  --
  --  Periodically check on the last known uniqueId in case it has
  --  been destroyed. If it has been destroyed, run the search again.
  
  self.findTechStation = coroutine.create(findTechstationByUniqueId)
  self.lastKnownTechStation = nil
  
end

function findTechstationByUniqueId()
  -- (\_/) including this value here (instead of passing as an argument) survives /reload gracefully
  local id = "techstation"
  
  -- (\_/) see also: loadBountyManager in bounty.lua
  while true do
	local findManager = world.findUniqueEntity(id)
	while not findManager:finished() do
	  coroutine.yield()
	end
	if findManager:succeeded() then
	  --  findManager:result() returns Vec2f position of entity in question
	  --  fire an entityQuery and iterate results to pinpoint desired target
	  local wQuery = world.entityQuery(findManager:result(), 1, {})
	  for v in ipairs(wQuery) do
	    if world.entityUniqueId(v) == id then
		  self.lastKnownTechStation = v
		  break
		end
	  end
	else
	  world.setUniqueId(entity.id(),id)
	  self.lastKnownTechStation = entity.id()
	end
	coroutine.yield()
  end
end

function onInteraction()
  if self.dialogTimer then
    sayNext()
    return nil
  else
    return config.getParameter("interactAction")
  end
end

function hasPet()
  return self.petId ~= nil
end

function setPet(entityId, params)
  if self.petId == nil or self.petId == entityId then
    self.petId = entityId
    storage.petParams = params
  else
    return false
  end
end

function sayNext()
  if self.dialog and #self.dialog > 0 then
    if #self.dialog > 0 then
      local options = {
        drawMoreIndicator = self.drawMoreIndicator
      }
      self.dialogTimer = self.dialogInterval
      if #self.dialog == 1 then
        options.drawMoreIndicator = false
        self.dialogTimer = 0.0
      end

      object.sayPortrait(self.dialog[1][1], self.dialog[1][2], nil, options)
      table.remove(self.dialog, 1)

      return true
    end
  else
    self.dialog = nil
    return false
  end
end

function update(dt)
  if self.petId and not world.entityExists(self.petId) then
    self.petId = nil
  end

  if storage.spawnTimer < 0 and self.petId == nil then
    storage.petParams.level = 1
    self.petId = world.spawnMonster(self.monsterType, object.toAbsolutePosition(self.spawnOffset), storage.petParams)
    world.callScriptedEntity(self.petId, "setAnchor", entity.id())
    storage.spawnTimer = 0.5
  else
    storage.spawnTimer = storage.spawnTimer - dt
  end

  if self.dialogTimer then
    self.dialogTimer = math.max(self.dialogTimer - dt, 0.0)
    if self.dialogTimer == 0 and not sayNext() then
      self.dialogTimer = nil
    end
  end
  
  if self.dialogTimer == nil then
    object.setOfferedQuests(config.getParameter("offeredQuests"))
  end
  
  --  (\_/) resume async find if necessary
  if self.lastKnownTechStation == nil or not world.entityExists(self.lastKnownTechStation) then
    coroutine.resume(self.findTechStation)
  end
end
