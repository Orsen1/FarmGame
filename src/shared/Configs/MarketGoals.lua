local function units(scope, target)
    return {Metric = "Units", Scope = scope, Target = target}
end

local function cash(scope, target, lifetime)
    return {Metric = "Revenue", Scope = scope, Target = target, Lifetime = lifetime}
end

local function rate(scope, target)
    return {Metric = "Rate", Scope = scope, Target = target}
end

local function hold(scope, target, duration)
    return {Metric = "SustainedRate", Scope = scope, Target = target, Seconds = duration}
end

local function kinds(scope, target, perItem)
    return {Metric = "Diversity", Scope = scope, Target = target, PerItemTarget = perItem}
end

local function all(...)
    return {Kind = "All", Children = {...}}
end

local function any(...)
    return {Kind = "Any", Children = {...}}
end

local function paths(crops, livestock, dairy, bakery, mixed)
    return {Paths = {Crops = crops, Livestock = livestock, Dairy = dairy, Bakery = bakery, Mixed = mixed}}
end

return {
    [6] = units("Crops", 20),
    [7] = kinds("Crops", 2, 6),
    [8] = any(units("Egg", 3), units("Flour", 5), kinds("Crops", 2, 8)),
    [9] = all(units("Crops", 14), any(units("Egg", 4), units("Flour", 6), kinds("Crops", 3, 4))),
    [10] = any(cash("All", 300, true), kinds("Crops", 2, 12)),
    [11] = rate("All", 12),
    [12] = rate("Crops", 14),
    [13] = any(units("Processed", 10), kinds("Crops", 2, 12)),
    [14] = any(rate("Egg", 2), rate("Processed", 2), rate("Crops", 12)),
    [15] = hold("All", 10, 60),
    [16] = any(units("Cream", 4), units("Bread", 2), units("Flour", 12), kinds("Crops", 2, 14)),
    [17] = any(cash("Processed", 200), cash("Crops", 300)),
    [18] = any(all(rate("Crops", 12), any(rate("Processed", 2), rate("Egg", 2))), all(rate("Grains", 6), rate("Vegetables", 6))),
    [19] = kinds("All", 3, 6),
    [20] = all(rate("All", 14), cash("All", 250)),
    [21] = paths(
        units("Crops", 50),
        units("Egg", 6),
        units("Dairy", 5),
        all(units("Flour", 8), units("Bread", 2)),
        all(units("Crops", 30), any(units("Egg", 3), units("Dairy", 3), units("Flour", 6)))),
    [22] = paths(
        cash("Crops", 500),
        units("Egg", 9),
        cash("Dairy", 300),
        all(cash("Bakery", 350), units("Bread", 1)),
        all(cash("All", 400), any(units("Egg", 4), units("Dairy", 4), units("Flour", 7)))),
    [23] = paths(
        rate("Crops", 14),
        rate("Egg", 2),
        rate("Dairy", 2),
        rate("Bakery", 3),
        all(rate("Crops", 10), any(rate("Egg", 1), rate("Dairy", 1), rate("Flour", 2)))),
    [24] = paths(
        kinds("Crops", 2, 14),
        hold("Egg", 1, 60),
        any(kinds("Dairy", 2, 3), hold("Dairy", 1, 60)),
        any(kinds("Bakery", 2, 4), hold("Bakery", 2, 60)),
        all(kinds("Crops", 2, 8), any(units("Egg", 3), units("Dairy", 3), units("Flour", 6)))),
    [25] = paths(
        all(units("Crops", 80), rate("Crops", 14)),
        all(units("Egg", 11), rate("Egg", 1)),
        all(units("Dairy", 8), rate("Dairy", 1)),
        all(units("Flour", 10), units("Bread", 4)),
        all(units("Crops", 45), any(units("Egg", 5), units("Dairy", 5), units("Flour", 9)))),
    [26] = paths(
        units("Crops", 90),
        units("Egg", 12),
        units("Dairy", 10),
        all(units("Flour", 12), units("Bread", 4)),
        all(units("Crops", 55), any(units("Egg", 6), units("Dairy", 6), units("Flour", 10)))),
    [27] = paths(
        cash("Crops", 800),
        cash("Egg", 260),
        cash("Dairy", 500),
        all(cash("Bakery", 600), units("Bread", 2)),
        all(cash("All", 600), any(units("Egg", 5), units("Dairy", 5), units("Flour", 9)))),
    [28] = paths(
        rate("Crops", 16),
        rate("Egg", 2),
        rate("Dairy", 2),
        rate("Bakery", 4),
        all(rate("Crops", 12), any(rate("Egg", 1), rate("Dairy", 1), rate("Flour", 2)))),
    [29] = paths(
        kinds("Crops", 3, 12),
        hold("Egg", 1, 60),
        any(kinds("Dairy", 2, 4), hold("Dairy", 1, 60)),
        kinds("Bakery", 2, 5),
        all(kinds("Crops", 2, 10), any(units("Egg", 5), units("Dairy", 5), units("Flour", 9)))),
    [30] = paths(
        all(units("Crops", 115), cash("Crops", 900)),
        all(units("Egg", 15), rate("Egg", 1)),
        all(units("Dairy", 12), cash("Dairy", 500)),
        all(units("Bread", 6), rate("Bakery", 2)),
        all(units("Crops", 65), any(units("Egg", 7), units("Dairy", 7), units("Flour", 12)))),
    [31] = paths(
        units("Crops", 125),
        units("Egg", 14),
        units("Dairy", 12),
        all(units("Flour", 16), units("Bread", 5)),
        all(units("Crops", 70), any(units("Egg", 7), units("Dairy", 7), units("Flour", 12)))),
    [32] = paths(
        cash("Crops", 1000),
        cash("Egg", 320),
        cash("Dairy", 600),
        all(cash("Bakery", 800), units("Bread", 3)),
        all(cash("All", 800), any(units("Egg", 6), units("Dairy", 6), units("Flour", 11)))),
    [33] = paths(
        rate("Crops", 17),
        rate("Egg", 2),
        rate("Dairy", 2),
        rate("Bakery", 4),
        all(rate("Crops", 13), any(rate("Egg", 1), rate("Dairy", 1), rate("Flour", 2)))),
    [34] = paths(
        hold("Crops", 12, 60),
        hold("Egg", 1, 60),
        any(kinds("Dairy", 2, 5), hold("Dairy", 1, 60)),
        hold("Bakery", 2, 60),
        all(kinds("Crops", 2, 14), any(units("Egg", 6), units("Dairy", 6), units("Flour", 11)))),
    [35] = paths(
        all(units("Crops", 140), rate("Crops", 15)),
        all(units("Egg", 17), hold("Egg", 1, 60)),
        all(units("Dairy", 14), units("Butter", 3)),
        all(units("Bread", 7), cash("Bakery", 1000)),
        all(units("Crops", 80), any(units("Egg", 8), units("Dairy", 8), units("Flour", 13)))),
    [36] = paths(
        units("Crops", 150),
        units("Egg", 16),
        units("Dairy", 14),
        all(units("Flour", 18), units("Bread", 6)),
        all(units("Crops", 85), any(units("Egg", 8), units("Dairy", 8), units("Flour", 13)))),
    [37] = paths(
        cash("Crops", 1200),
        cash("Egg", 360),
        cash("Dairy", 750),
        all(cash("Bakery", 1100), units("Bread", 4)),
        all(cash("All", 900), any(units("Egg", 7), units("Dairy", 7), units("Flour", 12)))),
    [38] = paths(
        rate("Crops", 18),
        rate("Egg", 2),
        rate("Dairy", 2),
        rate("Bakery", 4),
        all(rate("Crops", 14), any(rate("Egg", 1), rate("Dairy", 1), rate("Flour", 2)))),
    [39] = paths(
        kinds("Crops", 3, 18),
        hold("Egg", 1, 60),
        any(kinds("Dairy", 2, 6), hold("Dairy", 1, 60)),
        kinds("Bakery", 2, 7),
        all(kinds("Crops", 3, 10), any(units("Egg", 7), units("Dairy", 7), units("Flour", 12)))),
    [40] = paths(
        all(units("Crops", 160), hold("Crops", 14, 60)),
        all(units("Egg", 19), rate("Egg", 1)),
        all(units("Dairy", 16), rate("Dairy", 1)),
        all(units("Bread", 8), rate("Bakery", 2)),
        all(units("Crops", 95), any(units("Egg", 9), units("Dairy", 9), units("Flour", 15)))),
    [41] = paths(
        units("Crops", 170),
        units("Egg", 18),
        units("Dairy", 16),
        all(units("Flour", 22), units("Bread", 7)),
        all(units("Crops", 100), any(units("Egg", 9), units("Dairy", 9), units("Flour", 15)))),
    [42] = paths(
        cash("Crops", 1500),
        cash("Egg", 400),
        cash("Dairy", 850),
        all(cash("Bakery", 1300), units("Bread", 5)),
        all(cash("All", 1100), any(units("Egg", 8), units("Dairy", 8), units("Flour", 14)))),
    [43] = paths(
        rate("Crops", 19),
        rate("Egg", 3),
        rate("Dairy", 2),
        rate("Bakery", 5),
        all(rate("Crops", 14), any(rate("Egg", 1), rate("Dairy", 1), rate("Flour", 2)))),
    [44] = paths(
        hold("Crops", 14, 60),
        hold("Egg", 1, 60),
        hold("Dairy", 1, 60),
        hold("Bakery", 2, 60),
        all(kinds("Crops", 3, 12), any(units("Egg", 8), units("Dairy", 8), units("Flour", 14)))),
    [45] = paths(
        all(units("Crops", 185), cash("Crops", 1700)),
        all(units("Egg", 21), hold("Egg", 1, 60)),
        all(units("Dairy", 18), units("Butter", 4)),
        all(units("Bread", 9), hold("Bakery", 2, 60)),
        all(units("Crops", 110), any(units("Egg", 10), units("Dairy", 10), units("Flour", 16)))),
    [46] = paths(
        units("Crops", 195),
        units("Egg", 20),
        units("Dairy", 18),
        all(units("Flour", 24), units("Bread", 8)),
        all(units("Crops", 115), any(units("Egg", 10), units("Dairy", 10), units("Flour", 16)))),
    [47] = paths(
        cash("Crops", 1800),
        cash("Egg", 440),
        cash("Dairy", 1000),
        all(cash("Bakery", 1500), units("Bread", 6)),
        all(cash("All", 1300), any(units("Egg", 9), units("Dairy", 9), units("Flour", 15)))),
    [48] = paths(
        rate("Crops", 20),
        rate("Egg", 3),
        rate("Dairy", 3),
        rate("Bakery", 5),
        all(rate("Crops", 15), any(rate("Egg", 1), rate("Dairy", 1), rate("Flour", 2)))),
    [49] = paths(
        kinds("Crops", 3, 22),
        hold("Egg", 1, 60),
        any(kinds("Dairy", 2, 7), hold("Dairy", 1, 60)),
        kinds("Bakery", 2, 9),
        all(kinds("Crops", 3, 14), any(units("Egg", 9), units("Dairy", 9), units("Flour", 15)))),
    [50] = paths(
        all(units("Crops", 210), hold("Crops", 16, 60)),
        all(units("Egg", 23), rate("Egg", 2)),
        all(units("Dairy", 20), cash("Dairy", 1100)),
        all(units("Bread", 10), rate("Bakery", 3)),
        all(units("Crops", 130), any(units("Egg", 11), units("Dairy", 11), units("Flour", 18)))),
    [51] = paths(
        units("Crops", 220),
        units("Egg", 22),
        units("Dairy", 20),
        all(units("Flour", 28), units("Bread", 9)),
        all(units("Crops", 135), any(units("Egg", 11), units("Dairy", 11), units("Flour", 18)))),
    [52] = paths(
        cash("Crops", 2100),
        cash("Egg", 480),
        cash("Dairy", 1150),
        all(cash("Bakery", 1800), units("Bread", 7)),
        all(cash("All", 1500), any(units("Egg", 10), units("Dairy", 10), units("Flour", 16)))),
    [53] = paths(
        rate("Crops", 21),
        rate("Egg", 3),
        rate("Dairy", 3),
        rate("Bakery", 5),
        all(rate("Crops", 16), any(rate("Egg", 1), rate("Dairy", 1), rate("Flour", 2)))),
    [54] = paths(
        hold("Crops", 16, 75),
        hold("Egg", 1, 60),
        hold("Dairy", 1, 60),
        hold("Bakery", 2, 75),
        all(kinds("Crops", 3, 16), any(units("Egg", 10), units("Dairy", 10), units("Flour", 16)))),
    [55] = paths(
        all(units("Crops", 240), cash("Crops", 2200), hold("Crops", 18, 75)),
        all(units("Egg", 25), cash("Egg", 500), hold("Egg", 1, 60)),
        all(units("Dairy", 22), units("Butter", 5), hold("Dairy", 1, 60)),
        all(units("Bread", 12), cash("Bakery", 2000), hold("Bakery", 2, 75)),
        all(units("Crops", 150), any(units("Egg", 12), units("Dairy", 12), units("Flour", 20)), rate("Crops", 16))),
}
