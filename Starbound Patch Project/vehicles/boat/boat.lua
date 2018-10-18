require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.rockingTimer = 0
  self.facingDirection = 1
  self.angle = 0
  animator.setParticleEmitterActive("bubbles", false)
  self.damageEmoteTimer = 0
  self.spawnPosition = mcontroller.position()

  self.waterFactor = 0 --how much water are we in right now

  self.rockingInterval = config.getParameter("rockingInterval")
  self.maxHealth = config.getParameter("maxHealth")
  self.protection = config.getParameter("protection")

  self.damageStateNames = config.getParameter("damageStateNames")
  self.damageStateDriverEmotes = config.getParameter("damageStateDriverEmotes")
  self.materialKind = config.getParameter("materialKind")

  self.windLevelOffset = config.getParameter("windLevelOffset")
  self.rockingWindAngleMultiplier = config.getParameter("rockingWindAngleMultiplier")
  self.maxRockingAngle = config.getParameter("maxRockingAngle")
  self.angleApproachFactor = config.getParameter("angleApproachFactor")

  self.speedRotationMultiplier = config.getParameter("speedRotationMultiplier")

  self.targetMoveSpeed = config.getParameter("targetMoveSpeed")
  self.moveControlForce = config.getParameter("moveControlForce")

  mcontroller.resetParameters(config.getParameter("movementSettings"))

  self.minWaterFactorToFloat = config.getParameter("minWaterFactorToFloat")
  self.sinkingBuoyancy = config.getParameter("sinkingBuoyancy")
  self.sinkingFriction = config.getParameter("sinkingFriction")

  self.bowWaveParticleNames=config.getParameter("bowWaveParticles")
  self.bowWaveMaxEmissionRate=config.getParameter("bowWaveMaxEmissionRate")

  self.splashParticleNames = config.getParameter("splashParticles")
  self.splashEpsilon = config.getParameter("splashEpsilon")

  self.maxGroundSearchDistance = config.getParameter("maxGroundSearchDistance")

  local bounds = mcontroller.localBoundBox()
  self.frontGroundTestPoint = {bounds[1], bounds[2]}
  self.backGroundTestPoint = {bounds[3], bounds[2]}

  --setup the store functionality
  self.ownerKey = config.getParameter("ownerKey")
  vehicle.setPersistent(self.ownerKey)

  message.setHandler("store",
      function(_, _, ownerKey)
        local animState=animator.animationState("base")

        if (animState == "idle" or animState == "sinking") then
          if (self.ownerKey and self.ownerKey == ownerKey) then
            self.spawnPosition = mcontroller.position()
            animator.setAnimationState("base", "warpOutPart1")
            local localStorable = (self.driver == nil)
            return {storable = true, healthFactor = storage.health / self.maxHealth}
          end
        end
      end)

  if (storage.health) then
    animator.setAnimationState("base", "idle")
  else
    local startHealthFactor = config.getParameter("startHealthFactor")

    if (startHealthFactor == nil) then
        storage.health = self.maxHealth
    else
       storage.health = math.min(startHealthFactor * self.maxHealth, self.maxHealth)
    end
    animator.setAnimationState("base", "warpInPart1")
  end

  updateDamageEffects(0, true)
  self.maxBuoyancy = mcontroller.parameters().liquidBuoyancy
end

function update()
  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end

  local animState = animator.animationState("base")
  local waterFactor = mcontroller.liquidPercentage()

  if (animState == "warpedOut") then
    vehicle.destroy()
  elseif (animState == "warpInPart1" or animState == "warpOutPart2") then
    -- world.debugText("warping",mcontroller.position(),"red")

    mcontroller.setPosition(self.spawnPosition)
    mcontroller.setVelocity({0, 0})
  elseif (animState == "sinking") then
    -- world.debugText("sinking", mcontroller.position(), "red")

    self.angle = updateSinking(waterFactor, self.angle, -math.pi * 0.4)
  elseif (animState == "idle") then
    -- world.debugText("idle", mcontroller.position(), "green")

    local healthFactor = storage.health / self.maxHealth
    local waterSurface = self.maxGroundSearchDistance
    self.waterBounds = mcontroller.localBoundBox()

    --work out water surface
    if (waterFactor > 0) then
      waterSurface = (self.waterBounds[4] * waterFactor) + (self.waterBounds[2] * (1.0 - waterFactor))
    end

    self.waterBounds[2] = waterSurface + 0.25
    self.waterBounds[4] = waterSurface + 0.5

    -- world.debugText(string.format("WaterSurface=%s", self.waterBounds[2]), mcontroller.position(), "yellow")

    local moving, facing = updateDriving()

    --Rocking in the wind, and rotating up when moving
    local floating = updateFloating(waterFactor, moving,facing)
    updateMovingEffects(floating,moving)
    updatePassengers(healthFactor)

    if storage.health <= 0 then
      vehicle.setLoungeEnabled("titanicPose", false)
      animator.setAnimationState("base", "sinking")
      self.sinkTimer = config.getParameter("maxSinkTime")
    end

    self.facingDirection = facing
    self.waterFactor = waterFactor
  end

  --take care of rotating and flipping
  animator.resetTransformationGroup("flip")
  animator.resetTransformationGroup("rotation")

  if self.facingDirection < 0 then
    animator.scaleTransformationGroup("flip", {-1, 1})
  end

  animator.rotateTransformationGroup("rotation", self.angle)

  mcontroller.setRotation(self.angle)
end

function updateDriving()
  local moving = false
  local facing = self.facingDirection

  local driverThisFrame = vehicle.entityLoungingIn("drivingSeat")
  if (driverThisFrame ~= nil) then
    vehicle.setDamageTeam(world.entityDamageTeam(driverThisFrame))

    if vehicle.controlHeld("drivingSeat", "left") then
      if self.waterFactor > 0 then
        mcontroller.approachXVelocity(-self.targetMoveSpeed, self.moveControlForce)
        moving = true
      end
      facing = -1
    end

    if vehicle.controlHeld("drivingSeat", "right") then
      if self.waterFactor > 0 then
        mcontroller.approachXVelocity(self.targetMoveSpeed, self.moveControlForce)
        moving = true
      end
      facing = 1
    end
  else
    vehicle.setDamageTeam({type = "passive"})
  end

  return moving, facing
end

function updateSinking(waterFactor, currentAngle, sinkAngle)
  self.sinkTimer = self.sinkTimer - script.updateDt()
  if self.sinkTimer <= 0 or mcontroller.onGround() then
    animator.playSound("changeDamageState")
    animator.setParticleEmitterBurstCount("damageShards", config.getParameter("destroyParticleBurstCount"))
    animator.burstParticleEmitter("damageShards")
    vehicle.destroy()
  else
    if (waterFactor > self.minWaterFactorToFloat) then
      if (currentAngle ~= sinkAngle) then
        currentAngle = currentAngle + (sinkAngle - currentAngle) * self.angleApproachFactor

        local lerpFactor = math.cos(currentAngle - sinkAngle)
        local finalBuoyancy = (self.maxBuoyancy * (1.0 - lerpFactor)) + (self.sinkingBuoyancy * lerpFactor)
        mcontroller.applyParameters({
            liquidBuoyancy = finalBuoyancy,
            liquidFriction = self.sinkingFriction,
            frictionEnabled = true
          })
      end
      animator.setParticleEmitterActive("bubbles", true)
    end
  end

  return currentAngle
end

function updateFloating(waterFactor, moving, facing)
  local floating = waterFactor > self.minWaterFactorToFloat

  local targetAngle
  if (floating) then
    self.rockingTimer = self.rockingTimer + script.updateDt()
    if self.rockingTimer > self.rockingInterval then
      self.rockingTimer = self.rockingTimer - self.rockingInterval--jss - TImer -> Timer
    end

    local speedAngle = mcontroller.xVelocity() * self.speedRotationMultiplier

    local windPosition = vec2.add(mcontroller.position(), self.windLevelOffset)
    local windLevel = world.windLevel(windPosition)
    local windMaxAngle = self.rockingWindAngleMultiplier * windLevel
    local windAngle = windMaxAngle * (math.sin(self.rockingTimer / self.rockingInterval * (math.pi * 2)))

    targetAngle = windAngle + speedAngle--jss - use windAngle not windMaxAngle
  else
    targetAngle = calcGroundCollisionAngle(self.waterBounds[2]) --pass in the water surface
  end

  self.angle = self.angle + (targetAngle - self.angle) * self.angleApproachFactor

  if waterFactor > (self.waterFactor + self.splashEpsilon) then
    local floatingLiquid = mcontroller.liquidId()
    if (floatingLiquid > 0) then
      if (floatingLiquid > #self.bowWaveParticleNames) then
        floatingLiquid = 1 --off the end, go to "water" as a default
      end

      local splashEmitter=self.splashParticleNames[floatingLiquid]

      animator.setParticleEmitterOffsetRegion(splashEmitter,self.waterBounds)

      animator.burstParticleEmitter(splashEmitter)
    end
  end
  return floating
end

function updateMovingEffects(floating, moving)
  if moving then
    animator.setAnimationState("propeller", "turning")
    if floating then
      local floatingLiquid = mcontroller.liquidId()
      if (floatingLiquid > 0) then
        if (floatingLiquid > #self.bowWaveParticleNames) then
          floatingLiquid = 1 --off the end, go to "water" as a default
        end

        local bowWaveEmitter = self.bowWaveParticleNames[floatingLiquid]

        local rateFactor = math.abs(mcontroller.xVelocity()) / self.targetMoveSpeed
        rateFactor = rateFactor * self.bowWaveMaxEmissionRate
        animator.setParticleEmitterEmissionRate(bowWaveEmitter, rateFactor)

        local bowWaveBounds = self.waterBounds
        animator.setParticleEmitterOffsetRegion(bowWaveEmitter, bowWaveBounds)

        animator.setParticleEmitterActive(bowWaveEmitter, true)
      end
    end
  else
    animator.setAnimationState("propeller", "still")
    for i, emitter in ipairs(self.bowWaveParticleNames) do
       animator.setParticleEmitterActive(emitter, false)
    end
  end
end

--make the driver emote according to the damage state of the vehicle
function updatePassengers(healthFactor)
  if healthFactor >= 0 then
    --if we have a scared face on because of taking damage
    if self.damageEmoteTimer > 0 then
      self.damageEmoteTimer = self.damageEmoteTimer - script.updateDt()
      if (self.damageEmoteTimer < 0) then
        maxDamageState = #self.damageStateDriverEmotes
        damageStateIndex = maxDamageState
        damageStateIndex = (maxDamageState - math.ceil(healthFactor * maxDamageState)) + 1
        vehicle.setLoungeEmote("drivingSeat", self.damageStateDriverEmotes[damageStateIndex])
      end
    end
  end
end

function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return
  end

  updateDamageEffects(damage, false)

  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost

  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = healthLost,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.health <= 0
  }}
end

function setDamageEmotes()
  local damageTakenEmote = config.getParameter("damageTakenEmote")
  self.damageEmoteTimer = config.getParameter("damageEmoteTime")
  vehicle.setLoungeEmote("drivingSeat", damageTakenEmote)
end

function updateDamageEffects(damage, initialise)
  local maxDamageState = #self.damageStateNames
  local healthFactor = (storage.health - damage) / self.maxHealth
  local prevhealthFactor = storage.health / self.maxHealth

  local prevDamageStateIndex = util.clamp(maxDamageState - math.ceil(prevhealthFactor * maxDamageState) + 1, 1, maxDamageState)
  self.damageStateIndex = util.clamp(maxDamageState - math.ceil(healthFactor * maxDamageState) + 1, 1, maxDamageState)

  if ((self.damageStateIndex > prevDamageStateIndex) or initialise == true) then
    animator.setGlobalTag("damageState", self.damageStateNames[self.damageStateIndex])

    local settingsNameList = config.getParameter("damageMovementSettingNames")
    local settingsObject = config.getParameter(settingsNameList[self.damageStateIndex])

    self.maxBuoyancy = mcontroller.parameters().liquidBuoyancy

    mcontroller.applyParameters(settingsObject)
  end

  if (self.damageStateIndex > prevDamageStateIndex) then
    setDamageEmotes(healthFactor)

    animator.burstParticleEmitter("damageShards")
    animator.playSound("changeDamageState")
  end
end

function calcGroundCollisionAngle(waterSurface)
  local frontDistance = math.min(distanceToGround(self.frontGroundTestPoint), waterSurface)
  local backDistance = math.min(distanceToGround(self.backGroundTestPoint), waterSurface)

  if frontDistance == self.maxGroundSearchDistance and backDistance == self.maxGroundSearchDistance then
    return 0
  else
    return -math.atan(backDistance - frontDistance)
  end
end

function distanceToGround(point)
  -- to worldspace
  point = vec2.rotate(point, self.angle)
  point = vec2.add(point, mcontroller.position())

  local endPoint = vec2.add(point, {0, -self.maxGroundSearchDistance})
  local intPoint = world.lineCollision(point, endPoint)

  if intPoint then
    -- world.debugPoint(intPoint, {255, 255, 0, 255})
    return point[2] - intPoint[2]
  else
    -- world.debugPoint(endPoint, {255, 0, 0, 255})
    return self.maxGroundSearchDistance
  end
end
