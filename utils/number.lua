local num = {}

-- inclusive
function num.random_in_range(min, max)
    return math.floor(math.random() * (max - min + 1) + min)
end

function num.round(n, digits)
    local shift = 10 ^ digits
    return math.floor(n * shift + 0.5) / shift
end

return num
