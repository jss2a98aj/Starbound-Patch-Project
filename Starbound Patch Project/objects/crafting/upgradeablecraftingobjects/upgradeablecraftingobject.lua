require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  object.setInteractive(true)

  self.maxUpgradeStage = config.getParameter("maxUpgradeStage")

  if not storage.currentStage then
    storage.currentStage = math.min(config.getParameter("startingUpgradeStage", 1), self.maxUpgradeStage)
  end

  self.stageDataList = config.getParameter("upgradeStages")

  -- handle upgrade messages from the crafting interface
  message.setHandler("requestUpgrade", function(_, _)
      upgradeTo(storage.currentStage, storage.currentStage + 1)
    end)

  updateStageData()

  if ObjectAddons then
    local addonConfig = currentStageData().addonConfig
    ObjectAddons:init(addonConfig or {}, updateStageData)
  end
end

function uninit()
  if ObjectAddons then
    ObjectAddons:uninit()
  end
end

function update(dt)

end

function onInteraction(args)
  return { "OpenCraftingInterface", currentStageData().interactData}
end

function currentStageData()
  if self.stageDataList[storage.currentStage].addonConfig then
    -- merge any data from connected addons
    local res = copy(self.stageDataList[storage.currentStage])
    for _, addon in pairs(self.stageDataList[storage.currentStage].addonConfig.usesAddons or {}) do
      if ObjectAddons:isConnectedTo(addon.name) then
        res = util.mergeTable(res, addon.addonData)
      end
    end
    return res
  else
    return self.stageDataList[storage.currentStage]
  end
end

function upgradeTo(oldStage, newStage)
  if (newStage <= self.maxUpgradeStage and newStage ~= storage.currentStage) then

    showUpgradeEffects(oldStage)

    storage.currentStage = newStage

    if ObjectAddons then
      local addonConfig = currentStageData().addonConfig
      ObjectAddons:init(addonConfig or {}, updateStageData)
    else
      updateStageData()
    end
  end
end

function showUpgradeEffects(stageIndex)
  local stageData = currentStageData()

  if (stageData.upgradeSoundEffect ~= nil) then
    animator.playSound(stageData.upgradeSoundEffect)
  end

  if (stageData.upgradeParticleEffect ~= nil) then
    animator.burstParticleEmitter(stageData.upgradeParticleEffect)
  end
end

function updateStageData()
  local stageData = currentStageData()
  animator.setAnimationState("stage", stageData.animationState)
  object.setMaterialSpaces(stageData.materialSpaces)

  for k, v in pairs(stageData.itemSpawnParameters or {}) do
    object.setConfigParameter(k, v)
  end
end

function die()
  local stageData = currentStageData()
  stageData.itemSpawnParameters.startingUpgradeStage = storage.currentStage
  --SBPP - don't add any parameters if the object has not been upgraded so placed and non-placed ones will stack.
  local itemDescriptor
  if(storage.currentStage == config.getParameter("startingUpgradeStage", 1)) then
      itemDescriptor = {name = config.getParameter("objectName"), count = 1}
  else
      itemDescriptor = {name = config.getParameter("objectName"), count = 1, parameters = stageData.itemSpawnParameters}
  end
  world.spawnItem(itemDescriptor, vec2.add(object.position(), {0, 3}))
end
