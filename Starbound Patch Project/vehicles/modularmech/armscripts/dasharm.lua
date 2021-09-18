require "/vehicles/modularmech/armscripts/base.lua"

DashArm = MechArm:extend()

function DashArm:init()

  self.state = FSM:new()
end

function DashArm:update(dt)
  if self.state.state then
    self.state:update()
  end

  if not self.state.state then
    if self.fireTriggered then
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

function DashArm:windupState()
  animator.setAnimationState(self.armName, "windup")

  local stateTimer = self.windupTime

  -- The vanilla logic will work in zero-G or in low gravity. However,
  -- it will not work in full gravity environments, because there the
  -- gravity causes a continuous minimum of ~-1.18 on the y-axis of the
  -- velocity vector, even when the mech is stationary.
  local gravity = world.gravity(mcontroller.position())
  local maxInitialVelocity = 1.0
  if gravity > 0 and gravity <= 40 then
    maxInitialVelocity = 1.6
  elseif gravity > 40 then
    maxInitialVelocity = 2.2
  end

  while vec2.mag(mcontroller.velocity()) > maxInitialVelocity or stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle + self.windupAngle, self.shoulderOffset)
    stateTimer = stateTimer - script.updateDt()
    mcontroller.approachVelocity({0.0, 0.0}, self.stopForce)
    coroutine.yield()
  end

  self.state:set(self.fireState, self, self.windupAngle, self.fireAngle)
end

function DashArm:fireState(fromAngle, toAngle)
  animator.playSound(self.armName .. "Fire")

  local stateTimer = self.fireTime
  local projectileSpawnTime = stateTimer - self.swingTime
  local fireWasTriggered = false
  local dashDir = self.aimVector
  local startVelocity = mcontroller.velocity()

  animator.setParticleEmitterActive(self.armName.."Dash", true)
  animator.resetTransformationGroup("dash")
  animator.rotateTransformationGroup("dash", self.aimAngle)
  while stateTimer > 0 do
    fireWasTriggered = fireWasTriggered or self.fireTriggered
    
    vehicle.setDamageTeam({type = "ghostly"})
    vehicle.setDamageSourceEnabled("bumperGround", false)

    mcontroller.setVelocity(vec2.mul(dashDir, self.dashSpeed))
    animator.setGlobalTag("directives", self.dashDirectives)

    local swingRatio = math.min(1, (self.fireTime - stateTimer) / self.swingTime)
    local currentAngle = util.lerp(swingRatio, fromAngle, toAngle)
    animator.rotateTransformationGroup(self.armName, self.aimAngle + currentAngle, self.shoulderOffset)

    local dt = script.updateDt()
    if stateTimer > projectileSpawnTime and (stateTimer - projectileSpawnTime) < dt then
      self:fire()
    end

    stateTimer = stateTimer - dt
    coroutine.yield()
  end
  
  animator.setParticleEmitterActive(self.armName.."Dash", false)
  animator.setGlobalTag("directives", "")
  
  mcontroller.setVelocity({0, 0})
  
  self.state:set(self.cooldownState, self)
end

function DashArm:cooldownState()
  animator.setAnimationState(self.armName, "winddown")

  local stateTimer = self.cooldownTime
  while stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.cooldownAngle, self.shoulderOffset)
    stateTimer = stateTimer - script.updateDt()
    coroutine.yield()
  end

  self.state:set()
end
