local mpu = require 'mp.utils'

local path = {}

-- join_path returns url if it is an absolute path
function path.is_absolute(fp)
	return mpu.join_path("testing", fp) == fp
end

function path.is_relative(fp)
	return not path.is_absolute(fp)
end

return path
