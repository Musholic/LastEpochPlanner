local applyRangeTests = {
    [{ "+(10-20) Health", 128, 1.0, "Integer" }] = "+15 Health",
    [{ "(5-14)% increased Health", 96, 0.38 }] = "3% increased Health",
    [{ "(5-14)% increased Health", 96, 0.38, "Thousandth" }] = "3.2% increased Health",
    [{ "+(2-6) to All Attributes", 48, 1.0, "Integer" }] = "+2 to All Attributes",
    [{ "+(7-8) Attunement", 38, 1.5, "Integer" }] = "+10 Attunement",
}

describe("TestItemTools", function()
    for args, expected in pairs(applyRangeTests) do
        it(string.format("tests applyRange('%s', %.2f, %.2f)", unpack(args)), function()
            local result = itemLib.applyRange(unpack(args))
            assert.are.equals(expected, result)
        end)
    end
end)
