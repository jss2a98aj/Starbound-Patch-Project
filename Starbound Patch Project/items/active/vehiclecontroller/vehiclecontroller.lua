require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  interactRadius = root.assetJson("/player.config:interactRadius") * 4 --Extra range to account for vehicle size
  if config.getParameter("key") == nil then
    activeItem.setInstanceValue("key", sb.makeUuid())
  end

  VehicleBlocked, VehiclePlaceable, VehicleEmpty = 1, 2, 3

  self.vehicleBoundingBox = config.getParameter("vehicleBoundingBox")

  if config.getParameter("filled") then
    self.vehicleState = VehicleBlocked
  else
    self.vehicleState = VehicleEmpty
  end

  self.respawnTimer = 0

  updateIcon()

  activeItem.setScriptedAnimationParameter("vehicleImage", config.getParameter("vehicleImage"))
  activeItem.setScriptedAnimationParameter("vehicleState", self.vehicleState)
end

function activate(fireMode, shiftHeld)
  if config.getParameter("filled") then

    if fireMode == "primary" then
      if self.vehicleState == VehiclePlaceable then
        animator.playSound("placeOk")

        local vehicleParams = {
          ownerKey = config.getParameter("key"),
          startHealthFactor = config.getParameter("vehicleStartHealthFactor"),
          fromItem = true
        }

        world.spawnVehicle(config.getParameter("vehicleType"), activeItem.ownerAimPosition(), vehicleParams )

        activeItem.setInstanceValue("filled", false)
        self.vehicleState = VehicleEmpty

        activeItem.setScriptedAnimationParameter("vehicleState", self.vehicleState)
      else
        animator.playSound("placeBad")
      end
    end

  elseif self.consumePromise == nil then
    local vehicleId = world.entityQuery(activeItem.ownerAimPosition(), 0, {includedTypes = {"vehicle"}, order = "nearest"})[1]
    if vehicleId then
      local vehiclePosition = world.entityPosition(vehicleId)
      local playerPosition = mcontroller.position()
      if withinRange(playerPosition, vehiclePosition) then
        self.consumePromise = world.sendEntityMessage(vehicleId, "store", config.getParameter("key"))
      end
    end
  end

  updateIcon()
end

function update(dt)
  if config.getParameter("filled") then
    if self.respawnTimer > 0 then
      self.respawnTimer = self.respawnTimer - dt
      self.vehicleState = VehicleEmpty
    else
      if placementValid() then
        self.vehicleState = VehiclePlaceable
      else
        self.vehicleState = VehicleBlocked
      end
    end

  else
    if self.consumePromise then
      if self.consumePromise:finished() then
        local vehicleResult = self.consumePromise:result()
        if vehicleResult then
          activeItem.setInstanceValue("filled", vehicleResult.storable)
          self.respawnTimer = config.getParameter("respawnTime")

          if vehicleResult.storable then
            activeItem.setInstanceValue("vehicleStartHealthFactor", vehicleResult.healthFactor)
          end
        end

        updateIcon()

        self.consumePromise = nil
      end
    end
  end

  activeItem.setScriptedAnimationParameter("vehicleState", self.vehicleState)
end

function updateIcon()
  if config.getParameter("filled") then
    animator.setAnimationState("controller", "full")
    activeItem.setInventoryIcon(config.getParameter("filledInventoryIcon"))
  else
    animator.setAnimationState("controller", "empty")
    activeItem.setInventoryIcon(config.getParameter("emptyInventoryIcon"))
  end
end

function placementValid()
  local aimPosition = activeItem.ownerAimPosition()
  local playerPosition = mcontroller.position()

  if not withinRange(playerPosition, aimPosition) then
    return false
  end

  local vehicleBounds = {
    self.vehicleBoundingBox[1] + aimPosition[1],
    self.vehicleBoundingBox[2] + aimPosition[2],
    self.vehicleBoundingBox[3] + aimPosition[1],
    self.vehicleBoundingBox[4] + aimPosition[2]
  }

  if world.rectTileCollision(vehicleBounds, {"Null", "Block", "Dynamic", "Slippery"}) then
    return false
  end

  return true
end

function withinRange(position1, position2)
  return world.magnitude(position1, position2) <= interactRadius and not world.lineTileCollision(position1, position2)
end
