local science_packs = {}
for _, tech in pairs(data.raw["technology"]) do
    local hidden = tech.hidden
    local unit = tech.unit

    if tech.normal then
        hidden = tech.normal.hidden
        unit = tech.normal.unit
    elseif tech.expensive then
        hidden = tech.expensive.hidden
        unit = tech.expensive.unit
    end

    if hidden or not unit then goto continue end

    for _, pack in pairs(unit.ingredients) do
        local name = pack.name or pack[1]

        -- only convert tool based science packs
        -- will not touch armors / repair packs
        if data.raw["tool"][name] and not science_packs[name] then
            science_packs[name] = {}
        end

        local unlocks = {}
        for _, effect in pairs(tech.effects or {}) do
            if effect.type == "unlock-recipe" then
                local recipe = data.raw["recipe"][effect.recipe] or {}
                local results = recipe.results or { { recipe.result } }
                if recipe.normal then
                    results = recipe.normal.results or { { recipe.normal.result } }
                elseif recipe.expensive then
                    results = recipe.expensive.results or { { recipe.expensive.result } }
                end

                for _, result in pairs(results) do
                    local res_name = result.name or result[1]

                    if data.raw["tool"][res_name] then
                        unlocks[res_name] = true
                    end

                    for itype, _ in pairs(defines.prototypes.item) do
                        ---@type data.ItemPrototype
                        local item = data.raw[itype][res_name]
                        if item then
                            local rocket_result = item.rocket_launch_products or { item.rocket_launch_product }
                            for _, r in pairs(rocket_result) do
                                local r_name = r.name or r[1]
                                if data.raw["tool"][r_name] then
                                    unlocks[r_name] = true
                                end
                            end
                        end
                    end
                end
            end
        end

        if table_size(unlocks) == 1 then
            local uname, _ = next(unlocks)
            local scp = science_packs[uname] or {}
            if scp.tech == nil then
                science_packs[uname] = { tech = tech.name }
            end
        end
    end

    ::continue::
end

local function icon2layers(data, scale)
    local icons = data.icons or { { icon = data.icon } }
    local layers = {}

    for _, icon in pairs(icons) do
        local img = icon.icon
        local size = icon.icon_size or data.icon_size or 64
        local scale = (64 / size) * scale * (icon.scale or 1)
        local shift = { 0, 0 }

        local size1 = size
        if table_size(layers) > 0 then
            size1 = layers[1].size
            local scale1 = layers[1].scale
            scale = scale1 * (icon.scale or 1)
        end

        shift[1] = shift[1] + (icon.shift and icon.shift[1] or 0) / size1
        shift[2] = shift[2] + (icon.shift and icon.shift[2] or 0) / size1

        table.insert(layers, {
            direction_count = 1,
            filename = img,
            size = size,
            scale = scale,
            shift = shift,
            tint = icon.tint
        })
    end

    return layers
end

local armors = {} ---@type data.ArmorPrototype[]
local anims = {} ---@type data.CharacterArmorAnimation[]
for name, info in pairs(science_packs) do
    local pack = table.deepcopy(data.raw["tool"][name])
    data.raw["tool"][name] = nil

    pack.type = "armor"
    ---@cast pack data.ArmorPrototype
    table.insert(armors, pack)

    local scale = 0.75
    local layers = icon2layers(pack, scale)
    local scale = 0.75

    if name == "automation-science-pack" and not info.tech then
        layers = icon2layers({
            icon = "__base__/graphics/technology/automation-science-pack.png",
            icon_size = 256
        }, scale)
    elseif info.tech then
        layers = icon2layers(data.raw["technology"][info.tech], scale)
    end

    ---@type data.RotatedAnimation
    local anim = {
        layers = layers,
    }

    local anim18 = table.deepcopy(anim)
    for _, layer in pairs(anim18.layers) do
        local stripes = {}

        for _ = 1, 18 do
            table.insert(stripes, {
                filename = layer.filename,
                height_in_frames = 1,
                width_in_frames = 1
            })
        end

        layer.stripes = stripes
        layer.direction_count = 18
        layer.filename = nil
    end

    table.insert(anims, {
        armors = { pack.name },
        idle = anim,
        idle_with_gun = anim,
        running = anim,
        running_with_gun = anim18,
        mining_with_tool = anim,
    })
end

data:extend(armors)

if table_size(data.raw["tool"]) == 0 and table_size(armors) > 0 then
    local dummy = table.deepcopy(armors[1])
    dummy.type = "tool"
    dummy.name = "SPA-dummy-tool"
    dummy.flags = { "hidden" }
    data:extend({ dummy })
end

for _, char in pairs(data.raw["character"]) do
    for _, anim in pairs(anims) do
        table.insert(char.animations, anim)
    end
end
