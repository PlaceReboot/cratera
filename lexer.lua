
return function(code)
	local cursor = 0
	local function getCursor(steps)
		steps = (steps or 0)+1
		local pos = cursor+steps
		if pos <= #code then
			return code:sub(pos, pos)
		end
	end

	local compiledString = ""
	local tempString = ""
	local Tokens = {}
	local commentOpen = false
	local multiLine = false
	local stringQuote

	local function Location(start, length)
		length = (length or 1)
		return {
			Start = start,
			End = start+length,
			Length = length,
			Raw = code:sub(start+1, start+length)
		}
	end

	local function Lexeme(position, kind)
		local token = {
			kind = kind,
			body = position.Raw,
			location = position.Start,
			length = position.Length
		}

		return token
	end

	local function consume(times)
		for i = 1,times or 1 do
			if getCursor() == "\n" then

			end
			cursor += 1
		end
	end

	local function isSpace(ch)
		return ch == ' ' or ch == '\t' or ch == '\r' or ch == '\n' or ch == '\v' or ch == '\f'; 
	end

	local function longSeparator()
		local start = getCursor()
		local length = 0
		consume()
		while getCursor() == "=" do
			consume()
			length += 1
		end

		return start == getCursor() and length or -1
	end

	local function isAlpha(char)
		return char:match("%w")
	end

	local function readLongString(start, sep, kind)
		assert(getCursor() == "[", "Incorrect delimiter for long string.")

		consume()
		while true do
			if getCursor() == "]" then
				local sep2 = longSeparator()
				if sep2 == sep then
					consume()
					return Lexeme(Location(start, cursor-start), kind)
				end
			end
		end
	end

	local function readComment()
		local start = cursor
		consume(2)
		if getCursor() == "[" then
			local sep = longSeparator()
			if sep >= 0 then
				return readLongString(cursor, sep, "BlockComment")
			end
		end

		while getCursor() ~= "\r" and getCursor() ~= "\n" do
			consume()

		end
		local length = cursor-start
		return Lexeme(Location(start, length), "Comment")
	end

	local function readBackslashString()
		consume()
		local char = getCursor()
		if char == "\r" then
			consume()
			if getCursor() == "\n" then
				consume()
			end
			return
		elseif char == "0" then
			return
		elseif char == "\z" then
			consume()
			while (isSpace(getCursor())) do
				consume()
			end
			return
		end
		consume()
	end

	local function readString()
		local start = cursor
		local delimiter = getCursor()
		consume()

		while getCursor() and getCursor() ~= delimiter do
			print(getCursor(), delimiter)
			local char = getCursor()
			if char == "0" or char == "\r" or char == "\z" then
				return Lexeme(Location(start, cursor-start), "BrokenString")
			elseif char == "\\" then
				readBackslashString()
				break
			else
				consume()
			end
		end
		consume()
		return Lexeme(Location(start, cursor-start), "QuotedString")
	end

	local function readNumber(start)
		while tonumber(getCursor()) or getCursor() == "." or getCursor() == "_" do
			consume()
		end
		if getCursor():lower() == "e" then
			consume()
			if getCursor() == "+" or getCursor() == "-" then
				consume()
			end
		end
		while isAlpha(getCursor()) or tonumber(getCursor()) or getCursor() == "." or getCursor() == "_" do
			consume()
		end

		return Lexeme(Location(start, cursor-start), "number")
	end

	local function readName()
		local start = cursor

		while isAlpha(getCursor()) or getCursor() == "_" or tonumber(getCursor()) do
			consume()
		end

		return Lexeme(Location(start, cursor-start), "identifier")
	end

	local function treat()
		local start = cursor
		local currentChar = getCursor()
		local nextChar = getCursor(1)

		if currentChar == "-" then
			if nextChar == ">" then
				consume(2)
				return Lexeme(Location(start, 2), "Arrow")
			elseif nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "SubAssign")
			elseif nextChar == "-" then
				return readComment()
			else
				consume()
				return Lexeme(Location(start, 1), "-")
			end
		elseif currentChar == "=" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "Equal")
			else
				consume()
				return Lexeme(Location(start, 1), "=")
			end
		elseif currentChar == ">" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "GreaterEqual")
			else
				consume()
				return Lexeme(Location(start, 1), ">")
			end
		elseif currentChar == "<" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "LesserEqual")
			else
				consume()
				return Lexeme(Location(start, 1), "<")
			end
		elseif currentChar == "~" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "NotEqual")
			else
				consume()
				return Lexeme(Location(start, 1), "~")
			end
		elseif currentChar == "[" then
			local sep = longSeparator()
			if sep >= 0 then
				return readLongString(start, sep, "LongString")
			elseif sep == -1 then
				return Lexeme(Location(start, 1), "[")
			end
		elseif currentChar == "{" then
			consume()
			return Lexeme(Location(start, 1), "{")
		elseif currentChar == "}" then
			consume()
			return Lexeme(Location(start, 1), "}")
		elseif currentChar == "'" or currentChar == "\"" then
			return readString()
		elseif currentChar == "." then
			if nextChar == "." then
				if getCursor(2) == "." then
					consume(3)
					return Lexeme(Location(start, 3), "3Dots")
				elseif getCursor(2) == "=" then
					consume(3)
					return Lexeme(Location(start, 3), "ConcatAssign")
				else
					consume(2)
					return Lexeme(Location(start, 2), "2Dots")
				end
			else
				if nextChar:match("%d") then
					return readNumber(cursor)
				else
					consume()
					return Lexeme(Location(start, 1), ".")
				end
			end
		elseif currentChar == "+" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "AddAssign")
			else
				consume()
				return Lexeme(Location(start, 1), "+")
			end
		elseif currentChar == "/" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "DivAssign")
			else
				consume()
				return Lexeme(Location(start, 1), "/")
			end
		elseif currentChar == "*" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "MulAssign")
			else
				consume()
				return Lexeme(Location(start, 1), "*")
			end
		elseif currentChar == "%" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "ModAssign")
			else
				consume()
				return Lexeme(Location(start, 1), "%")
			end
		elseif currentChar == "^" then
			if nextChar == "=" then
				consume(2)
				return Lexeme(Location(start, 2), "PowAssign")
			else
				consume()
				return Lexeme(Location(start, 1), "^")
			end
		elseif currentChar == ":" then
			if nextChar == ":" then
				consume(2)
				return Lexeme(Location(start, 2), "DoubleColon")
			else
				consume()
				return Lexeme(Location(start, 1), ":")
			end
		elseif currentChar == "(" 
			or currentChar == ")"
			or currentChar == "{"
			or currentChar == "}"
			or currentChar == ";"
			or currentChar == "#"
			or currentChar == "," then
			consume()
			return Lexeme(Location(start, 1), currentChar)
		elseif tonumber(currentChar) then
			return readNumber(start)
		elseif isAlpha(currentChar) or currentChar == "_" then
			return readName()
		else
			if currentChar then
				consume()
				return Lexeme(Location(start, 1), currentChar)
			end
		end
	end

	local function Next()
		while getCursor() and getCursor():match("%s") do
			consume()
		end

		if getCursor() then
			table.insert(Tokens, treat())
		end
	end

	while getCursor() do

		local response = Next()

		task.wait()
	end
	return Tokens
end
