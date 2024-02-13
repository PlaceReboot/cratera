--this is a prototype, not final code and is not complete. It still doesn't fully work either I'm still figuring out how I'm gonna make this work.
local ASTBuilder = {}

function ASTBuilder.new()
	local self = {
		tokens = nil,
		position = 1
	}
	local i = 0
	
	local function peek(steps)
		steps = steps or 0
		
		return self.tokens[self.position+steps]
	end
	
	local function consume()
		local lastPeek = peek()
		self.position += 1
		return lastPeek
	end
	
	local function peekIsA(expected, positions)
		if peek(positions).kind == expected or peek(positions).body == expected then
			return true
		end
		return false
	end
	
	local function expect(expected)
		for i = self.position, #self.tokens do
			if peekIsA(expected, i-self.position) then
				return true
			end
		end
	end
	
	local function build(tokenType, token, additional)
		local node = {}
		token = token or {}
		if token then
			local tokenName, tokenKind = token.body, token.kind
			node = {
				["type"] = tokenType,
				["name"] = tokenName,
				["kind"] = tokenKind
			}
		else
			node = table.clone(token)
		end
		node["type"] = tokenType
		if additional then
			for i,v in additional do
				node[i] = v
			end
		end
		print(node)
		return node
	end
	
	local function parseFunctionDef(funcName)

		local params = {}
		local body = {}
		if peekIsA("(") then
			consume()
			local varArgs = {}
			while not peekIsA(")") do
				if peekIsA(",") then
					consume()
					continue
				end
				local expr = consume().body
				table.insert(params, expr)
				i+= 1
				if i %500 == 0 then
					task.wait()
				end
			end
			consume()
		end
		if not peekIsA("end") then
			while not peekIsA("end") do
				local statement,rest = parseStatement()
				table.insert(body, statement)
				i+= 1
				if i %500 == 0 then
					task.wait()
				end
			end
		end
		consume()
		return build("FunctionAssignment", peek(), {arguments = params, name = funcName, body = body})
	end
	
	local function parseFunction(funcName)
		local functionName = consume()
		consume()
		local varArgs = {}
		if not expect(")") then
			return error("Expected '(' to close function at "..self.position)
		end
		while not peekIsA(")") do
			if peekIsA(",") then
				consume()
				continue
			end
			local expr = parseExpression()
			table.insert(varArgs, expr)
			i+= 1
			if i %500 == 0 then
				task.wait()
			end
		end
		consume()
		return build("FunctionCall", functionName, {arguments = varArgs})
	end
	
	local function parseTableField()
		local token = peek()
		local tbl = {}
		
		local k,v
		if peekIsA("[") then
			consume()
			while not peekIsA("]") do
				k = parseStatement()
			end
			consume()
			v = parseExpression()
		elseif peekIsA("identifier") then
			k = parseExpression()
			consume()
			v = parseExpression()
		else
			k = #tbl+1
			v = parseExpression()
		end
		
		return {key = k, value = v}
	end
	
	local function parseTable()
		consume()
		local fields = {}
		while not peekIsA("}") do
			if peekIsA(",") or peekIsA(";") then
				consume()
				continue
			end
			local field = parseTableField()
			table.insert(fields, field)
			i+= 1
			if i %500 == 0 then
				task.wait()
			end
		end
		consume()
		
		return build("Table", nil, {
			fields = fields
		})
	end
	
	local function handleExpression(expressionType, first)
		if peekIsA("=", 1) then
			consume()
			consume()
			local second = parseStatement()
			return build(expressionType.."Assignment", nil, {
				left = first,
				right = second
			})
		end

		consume()
		return build(expressionType, nil, {
			left = first,
			right = parseStatement()
		})
	end
	
	function parseExpression(noCall)
		local token = peek()
		
		if peekIsA("number") or peekIsA("QuotedString") or peekIsA("LongString") then
			return build("Literal", consume())
		elseif peekIsA("identifier") then
			local base = nil
			while true do
				i+= 1
				if i %500 == 0 then
					task.wait()
				end
				if peekIsA("(", 1) and not noCall then
					local initToken = peek()
					local func = parseFunction()
					func.name = initToken.body
					func.base = base
					base = func
				elseif peekIsA("[", 1) then
					local initToken = peek()
					consume()
					local key = parseStatement()
					consume()
					local lastBaseName = base and base.body
					base = build("TableMember", initToken, {
						base = base,
						name = initToken.body,
						indexes = lastBaseName,
						value = key
					})
				elseif peekIsA("+") then
					local first = base
					return handleExpression("Add", first)
				elseif peekIsA(".", 1) then
					local initToken = peek()
					consume()
					consume()
					local key = parseExpression()
					local lastBaseName = base and base.body
					base = build("TableMember", initToken, {
						base = base,
						name = initToken.body,
						indexes = lastBaseName,
						value = key
					})
				else
					if peekIsA("identifier") and base then
						base = build("Identifier", peek(), {
							base = base,
							name = peek().body
						})
						consume()
					end
					break
				end

			end
			if not base then
				base = build("Identifier", consume())
			end
			
			return base
		elseif peekIsA("{") then
			return parseTable()
		end
	end
	
	
	function parseStatement()
		local token = peek()
		local nextToken = peek(1)
		
		
		if peekIsA("or", 1) then
			local first = parseExpression()
			consume()
			local second = parseExpression()
			return build("LogicalExpression", nil, {left = first, right = second})
		elseif peekIsA("return") then
			consume()
			return build("ReturnStatement", nil, {
				returns = parseStatement()
			})
		elseif peekIsA("{") then
			return parseExpression()
		elseif peekIsA(";") then
			consume()
		elseif peekIsA("Comment") or peekIsA("BlockComment") then
			consume()
		elseif peekIsA("#") then
			if peekIsA("identifier", 1) then
				consume()
				local item = peek()
				consume()
				return build("Length", item)
			else
				error("Expected identifier after #")
			end
		elseif peekIsA("identifier") then
			if nextToken then
				if peekIsA("function") then
					local funcName
					if peekIsA("identifier", 1) then
						consume()
						funcName = parseExpression(true)
					end
					if not funcName then
						error("No name provided for function at "..self.position)
					end
					consume()
					return parseFunctionDef(funcName)
				else
					if peekIsA("function", 1) then
						local funcName = parseExpression()
						consume()
						return parseFunctionDef(funcName)
					elseif peekIsA("local") then
						if peekIsA("=", 2) then
							consume()
							local statement = parseStatement()
							statement["type"] = "LocalAssignment"
							return statement
						elseif peekIsA("function", 1) then
							local funcName
							if peekIsA("identifier", 1) then
								consume()
								funcName = parseExpression()
							end
							if not funcName then
								error("No name provided for local function at "..self.position)
							end
							consume()
							return parseFunctionDef(funcName)
						end
					else
						local identity = parseExpression()
						local ret
						if peekIsA("=") then
							consume()
							if peekIsA("function") then
								ret = parseFunctionDef(identity)	
							else								
								ret = build("Assignment", nil, {base = identity, value = parseStatement()})
							end
						else
							ret = identity
						end
						return ret
					end
				end
			end
		end
	end
	
	function self:parse(tokens)
		self.tokens = tokens
		self.position = 1
		
		local ast = {["type"] = "Program", ["body"] = {}}
		local lastToken
		while self.position <= #self.tokens do
			print(self.position)
			if lastToken ~= peek() then
				lastToken = peek()
				local statement = parseStatement()
				if statement then
					table.insert(ast.body, statement)
				end
				i+= 1
				if i %500 == 0 then
					task.wait()
				end
			else
				break
			end
		end
		
		return ast
	end
	
	return self
end

return ASTBuilder
