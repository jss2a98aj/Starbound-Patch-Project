require "/scripts/util.lua"

function init()
  storage.gender = storage.gender or "male"

  message.setHandler("swapGender", swapGender)
end

function update(dt)

end

function swapGender()
  storage.gender = storage.gender == "male" and "female" or "male"
  updateImages()
end

function containerCallback()
  updateImages()
end

function updateImages()
  local contents = world.containerItems(entity.id())

  setArmor(contents[1], "headarmor", "head")
  setArmor(contents[2], "chestarmor", "chest")
  setArmor(contents[3], "legsarmor", "legs")
  setArmor(contents[4], "backarmor", "back")
end

function setArmor(item, validType, slotName)
  if item and root.itemType(item.name) == validType then
    animator.setAnimationState(slotName, "show")
    local itemConfig = root.itemConfig(item.name)

    local frameSet = itemConfig.config[storage.gender .. "Frames"]
    local directives = buildDirectives(item, itemConfig)

    if type(frameSet) == "table" then
      for k, v in pairs(frameSet) do
        --Patch Project: Check for absolute paths in armor
        v = v:sub(1, 1) == "/" and v or util.absolutePath(itemConfig.directory, v)
        animator.setPartTag(k, "frameSet", v)
        animator.setPartTag(k, "directives", directives)
      end
    else
      --Patch Project: Check for absolute paths in armor
      frameSet = frameSet:sub(1, 1) == "/" and frameSet or util.absolutePath(itemConfig.directory, frameSet)
      animator.setPartTag(slotName, "frameSet", frameSet)
      animator.setPartTag(slotName, "directives", directives)
    end

  else
    animator.setAnimationState(slotName, "hide")
  end
end

function buildDirectives(item, itemConfig)
  local res = item.parameters.directives or itemConfig.directives or ""
  local colorOptions = itemConfig.config.colorOptions
  if colorOptions then
    local colorIndex = (item.parameters.colorIndex or itemConfig.config.colorIndex or 0) + 1
    colorIndex = colorIndex % #colorOptions
    if colorOptions[colorIndex] then
      for fromColor, toColor in pairs(colorOptions[colorIndex]) do
        res = res .. "?replace="..fromColor.."="..toColor
      end
    end
  end
  return res
end
