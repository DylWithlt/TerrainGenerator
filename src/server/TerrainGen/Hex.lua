local sqrt_3 = math.sqrt(3)

local Orientation = {}
function Orientation.new(f0, f1, f2, f3, b0, b1, b2, b3, start_angle)
	return {
		f0 = f0;
		f1 = f1;
		f2 = f2;
		f3 = f3;
		b0 = b0;
		b1 = b1;
		b2 = b2;
		b3 = b3;
		start_angle = start_angle;
	}
end

local flat = Orientation.new(
	3/2, 0, sqrt_3/ 2, sqrt_3,
	2/3, 0, -1/3, sqrt_3/3, 0)

local pointy = Orientation.new(
	sqrt_3, sqrt_3/2, 0, 3/2,
	sqrt_3/3, -1/3, 0, 2/3, 0.5)

return function(size, pointyUp)
	local Hex = {}
	Hex.size = size
	Hex.w = 2 * size
	Hex.h = sqrt_3 * size
	
	local M = pointyUp and pointy or flat

	local layout = {
		orientation = M;
		size = Vector2.new(size, size);
		origin = Vector2.new(0, 0);
	}

    Hex.layout = layout


	function Hex.new(q, r, s)
		local self = {
			q = q;
			r = r;
			s = s or -q - r;
		}
		
		setmetatable(self, {
			__tostring = function(tbl)
				return string.format("%s %s %s", math.floor(self.q), math.floor(self.r), math.floor(self.s))
			end
		})

		return self
	end

	function Hex.hex_to_vec3(hex)
		local x = (M.f0 * hex.q + M.f1 * hex.r) * Hex.size
		local z = (M.f2 * hex.q + M.f3 * hex.r) * Hex.size
		return Vector3.new(x, 0, z)
	end

	function Hex.vec3_to_hex(vec3)
		local pt = Vector2.new(
			(vec3.X - Hex.layout.origin.X) / Hex.layout.size.X,
			(vec3.Z - Hex.layout.origin.Y) / Hex.layout.size.Y)

		local q = M.b0 * pt.X + M.b1 * pt.Y
		local r = M.b2 * pt.X + M.b3 * pt.Y

		return Hex.new(q, r) -- fractional hex
	end

	function Hex.hex_round(h)
		local q = math.round(h.q)
		local r = math.round(h.r)
		local s = math.round(h.s)
		local q_diff = math.abs(q - h.q)
		local r_diff = math.abs(r - h.r)
		local s_diff = math.abs(s - h.s)
		if q_diff > r_diff and q_diff > s_diff then
			q = -r - s
		elseif r_diff > s_diff then
			r = -q - s
		else
			s = -q - r
		end

		q = q == -0 and 0 or q
		r = r == -0 and 0 or r
		s = s == -0 and 0 or s

		return Hex.new(q, r, s)
	end

	function Hex.hex_add(a, b)
		return Hex.new(a.q + b.q, a.r + b.r, a.s + b.s)
	end

	function Hex.hex_subtract(a, b)
		return Hex.new(a.q - b.q, a.r - b.r, a.s - b.s)
	end

	function Hex.hex_multiply(a, k)
		return Hex.new(a.q * k, a.r * k, a.s * k)
	end

	function Hex.hex_length(hex)
		return math.floor((math.abs(hex.q) + math.abs(hex.r) + math.abs(hex.s))/2)
	end

	function Hex.hex_distance(a, b)
		return Hex.hex_length(Hex.hex_subtract(a, b))
	end

	local hex_directions = {
		Hex.new(1, 0, -1), Hex.new(1, -1, 0), Hex.new(0, -1, 1),
		Hex.new(-1, 0, 1), Hex.new(-1, 1, 0), Hex.new(0, 1, -1)
	}

	function Hex.hex_direction(direction)
		assert(1 <= direction and direction <= 6)
		return hex_directions[direction]
	end

	function Hex.hex_neighbor(hex, direction)
		return Hex.hex_add(hex, Hex.hex_direction(direction))
	end

	function Hex.single_ring(center, radius)
		local results = {}
		
		local curr_hex = Hex.hex_add(center, Hex.hex_multiply(Hex.hex_direction(5), radius))
		
		for i=1, 6 do
			for j=1, radius do
				table.insert(results, curr_hex)
				curr_hex = Hex.hex_neighbor(curr_hex, i)
			end
		end
		
		return results
	end

	function Hex.hex_spiral(center, radius)
		local results = {center}
		for k = 1, radius do
			if k % 25 == 0 then task.wait() end

			local ring = Hex.single_ring(center, k)
			table.move(ring, 1, table.getn(ring), table.getn(results)+1, results)
		end
		return results
	end

	return Hex
end