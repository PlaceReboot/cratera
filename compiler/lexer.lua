local Declared = {}
local gOffset = 0
local operators = {'+', '-', '*', '/', '%', '^', '#', '==', '~=', '-=', '*=',
	'+=', '<=', '>=', '<', '>', '=', ';', ':', ',', '.', '..', '...', '/='}

local keywords = {'and', 'break', 'do', 'else', 'elseif',
	'end', 'false', 'for', 'function', 'goto', 'if',
	'in', 'local', 'nil', 'not', 'or',
	'repeat', 'return', 'then', 'true', 'until',
	'while', 'continue', 'export', 'type'
}



local delimiters = {
	'"', '`', '[', ']', '{', '}', '\'', '(', ')'
}

local comments = {
	lineComment = "--",
	multiComment = "--["
}

local function isnl(ch)
	return ch == "\n" or ch == ""
end

local function isnum(ch)
	return ch:match("%d")
end

local function isSpace(ch)
	return ch == ' ' or ch == '\t' or ch == '\r' or ch == '\n' or ch == '\v' or ch == '\f'
end

function getChar(str, pos)
	return str:sub(pos, pos)
end

function getAfter(str, pos)
	return str:sub(pos)
end

function lexer(raw)
	local Tokens = {}
	local currentOffset = 0
	local currentStr = ""
	local Type = "identifier"
	
	while currentOffset <= string.len(raw) do
		currentOffset += 1
		local char = getChar(raw, currentOffset)
		local nextChar = getChar(raw, currentOffset+1)
		local TypeOver = true
		if table.find(keywords, currentStr) then
			Type = "keyword"
		elseif char..nextChar == comments.lineComment then
			char ..= nextChar
			currentOffset += 1
			Type = "comment"
		elseif char..nextChar..getChar(raw, currentOffset+2) == comments.multiComment then
			char ..= nextChar..getChar(raw, currentOffset+2)
			currentOffset += 2
			Type = "comment"
		elseif table.find(operators, char..nextChar) then
			char ..= nextChar
			Type = "symbol"
			currentOffset += 1
		elseif table.find(operators, char) then
			Type = "symbol"
		elseif table.find(delimiters, char) then
			Type = "delimiter"
		else
			if not table.find(delimiters, nextChar) then
				TypeOver = false
			end
			Type = "identifier"
		end
		if not isSpace(getChar(raw, currentOffset)) then
			currentStr ..= char
		else
			TypeOver = true
		end
		
		if TypeOver or currentOffset == string.len(raw) then
			if currentStr ~= "" then
				table.insert(Tokens, {kind = Type, raw = currentStr, body = currentStr})
			end
			currentStr = ""
		end
	end
	
	return Tokens
end

return lexer
