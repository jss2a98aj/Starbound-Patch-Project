require "/vehicles/modularmech/armscripts/base.lua"

BeamArm = MechArm:extend()

function BeamArm:init()
  self.state = FSM:new()

  if self.chain ~= nil then
    self.chain.sourcePart = self.armName
    self.chain.endPart = self.armName
  end
  self.renderChain = false
end

function BeamArm:update(dt)
  if self.state.state then
    self.state:update()
  end

  if not self.state.state then
    if self.isFiring then
      self.state:set(self.windupState, self)
    end
  end

  if self.state.state then
    self.bobLocked = true
  else
    animator.setAnimationState(self.armName, "idle")
    self.bobLocked = false
  end
end

function BeamArm:windupState()
  local stateTimer = self.windupTime

  animator.setAnimationState(self.armName, "windup")
  animator.playSound(self.armName .. "Windup")

  while stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    local dt = script.updateDt()
    stateTimer = stateTimer - dt
    coroutine.yield()
  end
  --SBPP - Do not fire through wall if checkWalls is true. Based on changes by rl-starbound.
  if self.isFiring and (not self.checkWalls or self:rayCheck(self.firePosition)) then
    self.state:set(self.fireState, self)
  else
    self.state:set(self.winddownState, self)
    animator.playSound(self.armName .. "WinddownNoFire")
  end
end

function BeamArm:fireState()
  local stateTimer = self.fireTime

  animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

  local endPoint, beamCollision, beamLength = self:updateBeam()

  animator.playSound(self.armName .. "Fire")
  animator.setParticleEmitterBurstCount(self.armName .. "Beam", math.ceil(self.beamParticleDensity * beamLength))
  animator.burstParticleEmitter(self.armName .. "Beam")
  if self.scriptedBeam then
    self.renderChain = true
  else
    animator.setAnimationState(self.armName .. "Beam", "fire", true)
  end
  
  vehicle.setDamageSourceEnabled(self.armName .. "Beam", true)

  self.aimLocked = self.lockAim

  if beamCollision and self.beamTileDamage > 0 then
    local maximumEndPoint = vec2.add(self.firePosition, vec2.mul(self.aimVector, self.beamLength))
    local damagePositions = world.collisionBlocksAlongLine(self.firePosition, maximumEndPoint, nil, self.beamTileDamageDepth)
    local driver = vehicle.entityLoungingIn("seat")
    world.damageTiles(damagePositions, "foreground", self.firePosition, "beamish", self.beamTileDamage, 99, driver)
    world.damageTiles(damagePositions, "background", self.firePosition, "beamish", self.beamTileDamage, 99, driver)
  end

  coroutine.yield()

  --SBPP - Do not fire through wall if checkWalls is true. Based on changes by rl-starbound.
  while stateTimer > 0 and (self.holdFire or self.isFiring) and (not self.checkWalls or self:rayCheck(self.firePosition)) do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    self:updateBeam()

    local dt = script.updateDt()
    stateTimer = stateTimer - dt
    coroutine.yield()
  end

  self.aimLocked = false
  
  if self.scriptedBeam then
    self.renderChain = false
  end

  vehicle.setDamageSourceEnabled(self.armName .. "Beam", false)

  --SBPP - Do not fire through wall if checkWalls is true. Based on changes by rl-starbound.
  if self.isFiring and self.repeatFire and (not self.checkWalls or self:rayCheck(self.firePosition)) then
    self.state:set(self.fireState, self)
  else
    self.state:set(self.winddownState, self)
  end
end

function BeamArm:winddownState()
  local stateTimer = self.winddownTime or 0

  animator.setAnimationState(self.armName, "winddown")
  animator.playSound(self.armName .. "Winddown")
  
  if self.scriptedBeam then
    vehicle.setAnimationParameter("chains", {})
  end

  while stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    local dt = script.updateDt()
    stateTimer = stateTimer - dt
    coroutine.yield()
  end

  self.state:set()
end

function BeamArm:updateBeam()
  local endPoint = vec2.add(self.firePosition, vec2.mul(self.aimVector, self.beamLength))
  local beamCollision = world.lineCollision(self.firePosition, endPoint)
  if beamCollision then
    endPoint = beamCollision
  end
  local beamLength = world.magnitude(self.firePosition, endPoint)

  if not self.scriptedBeam then
    animator.resetTransformationGroup(self.armName .. "Beam")
    animator.scaleTransformationGroup(self.armName .. "Beam", {beamLength, 1}, {self.beamSourceOffset[1], self.beamSourceOffset[2] - self.beamHeight / 2})
  end

  local particleRegion = {self.beamSourceOffset[1], self.beamSourceOffset[2], self.beamSourceOffset[1] + beamLength, self.beamSourceOffset[2]}
  animator.setParticleEmitterOffsetRegion(self.armName .. "Beam", particleRegion)

  return endPoint, beamCollision, beamLength
end
