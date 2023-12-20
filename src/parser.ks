/**
 * parser.ks
 * Version 0.7.0
 * May 23rd, 2017
 *
 * Copyright (c) 2017 Baptiste Augrain
 * Licensed under the MIT license.
 * http://www.opensource.org/licenses/mit-license.php
 **/
#![error(ignore(Error))]

import 'npm:@kaoscript/ast'

export namespace Parser {
	include {
		'./util.ks'

		'./types.ks'

		'./ast.ks'
		'./scanner.ks'
	}

	bitmask AccessMode {
		Nil

		Internal
		Private
		Protected
		Public

		Closed = Public + Internal + Private
		Opened = Public + Protected + Internal + Private
	}

	bitmask DestructuringMode {
		Nil

		COMPUTED
		DEFAULT
		EXTERNAL_ONLY
		MODIFIER
		RECURSION
		THIS_ALIAS
		TYPE

		Declaration			= COMPUTED + DEFAULT + MODIFIER + RECURSION + TYPE
		Expression			= COMPUTED + DEFAULT + RECURSION
		Parameter			= DEFAULT + RECURSION + TYPE
	}

	bitmask ExpressionMode {
		Nil

		AtThis
		Curry
		ImplicitMember
		MatchCase
		NoAnonymousFunction
		NoAwait
		NoInlineCascade
		NoMultiLine
		NoObject
		NoRestriction
		Pipeline
		WithMacro

		InlineOnly			= NoInlineCascade + NoMultiLine
		Method				= PrimaryType + AtThis
		PrimaryType			= InlineOnly
	}

	bitmask FunctionMode {
		Nil

		Macro
		Method
		NoPipeline
	}

	bitmask MacroTerminator {
		Nil

		COMMA
		NEWLINE
		RIGHT_CURLY
		RIGHT_ROUND
		RIGHT_SQUARE

		Array				= COMMA + NEWLINE + RIGHT_SQUARE
		List				= COMMA + NEWLINE + RIGHT_ROUND
		Object				= COMMA + NEWLINE + RIGHT_CURLY
		Parenthesis			= NEWLINE + RIGHT_ROUND
	}

	bitmask MemberBits<u32> {
		AbstractMethod		 = 1
		AssistMethod
		Attribute
		FinalMethod
		FinalVariable
		LateVariable
		Method
		NoAssignment
		NoBody
		OverrideMethod
		OverrideProperty
		OverwriteMethod
		OverwriteProperty
		Property
		Proxy
		RequiredAssignment
		Value
		Variable
	}

	bitmask ParserMode {
		Nil

		InlineStatement
		MacroExpression
		Typing
	}

	bitmask TypeMode {
		Nil

		Module
		NoIdentifier
	}

	type ModeTracker = {
		pop: Boolean
		mode: ParserMode?
	}

	var ESCAPES = {
		'0': 0x0
		'\'': 0x27
		'\"': 0x22
		'\\': 0x5C
		'n': 0x0A
		'r': 0x0D
		'v': 0x0B
		't': 0x09
		'b': 0x08
		'f': 0x0C
	}

	var NO: Event(N) = { ok: false }

	class Parser {
		private {
			@mode: ParserMode	= ParserMode.Nil
			@scanner: Scanner
			@token: Token?
		}

		constructor(
			data: String
		) ~ SyntaxError # {{{
		{
			@scanner = Scanner.new(data)
		} # }}}

		commit(): valueof this # {{{
		{
			@token = @scanner.commit()
		} # }}}

		error(
			message: String
			lineNumber: Number = @scanner.line()
			columnNumber: Number = @scanner.column()
		): SyntaxError # {{{
		{
			var error = SyntaxError.new(message)

			error.lineNumber = lineNumber
			error.columnNumber = columnNumber

			return error
		} # }}}

		mark(): Marker => @scanner.mark()

		match(
			...tokens: Token
		): Token => @token <- @scanner.match(...tokens)

		matchM(
			matcher: Function
			eMode: ExpressionMode? = null
			fMode: FunctionMode? = null
		): Token # {{{
		{
			@token = @scanner.matchM(matcher, eMode, fMode, @mode)

			return @token
		} # }}}

		matchNS(
			...tokens: Token
		): Token => @token <- @scanner.matchNS(...tokens)

		no(
			...expecteds: String
		): Event(N) # {{{
		{
			return {
				ok: false
				expecteds
			}
		} # }}}

		position(): Range => @scanner.position()

		position(
			start: Number
		): Range => @scanner.position(start)

		position(
			start: Number
			length: Number
		): Range => @scanner.position(start, length)

		printDebug(
			prefix: String? = null
		): Void # {{{
		{
			if ?prefix {
				console.log(prefix, @scanner.toDebug())
			}
			else {
				console.log(@scanner.toDebug())
			}
		} # }}}

		relocate<T is Event>(
			event: T
			first: Event?
			last: Event?
		): T # {{{
		{
			if ?first {
				event.start = event.value.start = first.start
			}

			if ?last {
				event.end = event.value.end = last.end
			}

			return event
		} # }}}

		rollback(
			mark: Marker
		): Boolean # {{{
		{
			return @scanner.rollback(mark)
		} # }}}

		skipNewLine(): Void # {{{
		{
			if @scanner.skipNewLine() == -1 {
				@token = Token.EOF
			}
			else {
				@token = Token.INVALID
			}
		} # }}}

		test(
			token: Token
		): Boolean # {{{
		{
			if @scanner.test(token) {
				@token = token

				return true
			}
			else {
				return false
			}
		} # }}}

		test(
			...tokens: Token
		): Boolean => tokens.indexOf(@match(...tokens)) != -1

		testNS(
			...tokens: Token
		): Boolean => tokens.indexOf(@matchNS(...tokens)) != -1

		throw(): Never ~ SyntaxError # {{{
		{
			throw @error(`Unexpected \(@scanner.toQuote())`)
		} # }}}

		throw(
			expected: String
		): Never ~ SyntaxError # {{{
		{
			throw @error(`Expecting "\(expected)" but got \(@scanner.toQuote())`)
		} # }}}

		throw(
			...expecteds: String
		): Never ~ SyntaxError # {{{
		{
			throw @error(`Expecting "\(expecteds.slice(0, expecteds.length - 1).join('", "'))" or "\(expecteds[expecteds.length - 1])" but got \(@scanner.toQuote())`)
		} # }}}

		until(
			token: Token
		): Boolean => !@scanner.test(token) && !@scanner.isEOF()

		value(): String | Array<String> => @scanner.value(@token!?)

		yep(): Event<Null>(Y) # {{{
		{
			var { start, end } = @scanner.position()

			return {
				ok: true
				start
				end
			}
		} # }}}

		yep<T>(
			value: T
		): Event<T>(Y) # {{{
		{
			var start: Position = value.start ?? @scanner.startPosition()
			var end: Position = value.end ?? @scanner.endPosition()

			return {
				ok: true
				value
				start
				end
			}
		} # }}}

		yep<T>(
			value: T
			{ start }: Event(Y)
			{ end }: Event(Y)
		): Event<T>(Y) # {{{
		{
			return {
				ok: true
				value
				start
				end
			}
		} # }}}

		yes(): Event<Null>(Y) # {{{
		{
			var { start, end } = @scanner.position()

			@commit()

			return {
				ok: true
				start
				end
			}
		} # }}}

		yes<T>(
			value: T
		): Event<T>(Y) # {{{
		{
			var start: Position = value.start ?? @scanner.startPosition()
			var end: Position = value.end ?? @scanner.endPosition()

			@commit()

			return {
				ok: true
				value
				start
				end
			}
		} # }}}

		yes<T>(
			value: T
			{ start }: Event(Y)
		): Event<T>(Y) # {{{
		{
			var end: Position = value.end ?? @scanner.endPosition()

			@commit()

			return {
				ok: true
				value
				start
				end
			}
		} # }}}

		NL_0M(): Void ~ SyntaxError # {{{
		{
			@skipNewLine()
		} # }}}

		altArrayComprehensionFor(
			expression: Event<NodeData(Expression)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(ArrayComprehension)>(Y) ~ SyntaxError # {{{
		{
			var firstLoop = @yes()

			@NL_0M()

			var iteration = @reqIteration(fMode)

			@NL_0M()

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			var loop = @yep(AST.ForStatement(iteration, firstLoop, iteration))

			return @yep(AST.ArrayComprehension(expression, loop, first, @yes()))
		} # }}}

		altArrayComprehensionRepeat(
			expression: Event<NodeData(Expression)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(ArrayComprehension)>(Y) ~ SyntaxError # {{{
		{
			var firstLoop = @yes()

			@NL_0M()

			var condition = @reqExpression(.Nil, fMode)

			unless @test(Token.TIMES) {
				@throw('times')
			}

			var loop = @yep(AST.RepeatStatement(condition, null, firstLoop, @yes()))

			@NL_0M()

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ArrayComprehension(expression, loop, first, @yes()))
		} # }}}

		altArrayList(
			expression: Event<NodeData(Expression)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(ArrayExpression)>(Y) ~ SyntaxError # {{{
		{
			var values = [@altRestrictiveExpression(expression, fMode)]

			repeat {
				if @test(.COMMA) {
					@commit().NL_0M()

					var expression = @reqExpression(null, fMode, MacroTerminator.Array)

					values.push(@altRestrictiveExpression(expression, fMode))
				}
				else if @test(.NEWLINE) {
					@commit().NL_0M()

					if @test(.COMMA) {
						@commit().NL_0M()
					}
					else if @test(.RIGHT_SQUARE) {
						break
					}

					var expression = @reqExpression(null, fMode, MacroTerminator.Array)

					values.push(@altRestrictiveExpression(expression, fMode))
				}
				else {
					break
				}
			}

			unless @test(.RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ArrayExpression(values, first, @yes()))
		} # }}}

		altRestrictiveExpression(
			expression: Event<NodeData(Expression)>(Y)
			fMode: FunctionMode
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var mark = @mark()

			if @test(Token.IF, Token.UNLESS) {
				var kind = @token == Token.IF ? RestrictiveOperatorKind.If : RestrictiveOperatorKind.Unless
				var operator = @yep(AST.RestrictiveOperator(kind, @yes()))
				var condition = @reqExpression(.NoMultiLine, fMode)

				if @test(Token.NEWLINE) || @token == Token.EOF {
					return @yep(AST.RestrictiveExpression(operator, condition, expression, expression, condition))
				}
				else {
					@rollback(mark)
				}
			}

			return expression
		} # }}}

		altTypeContainer(
			mut type: Event<NodeData(Type)>(Y)
			nullable: Boolean = true
		): Event<NodeData(Type)>(Y) ~ SyntaxError # {{{
		{
			var mut mark = @mark()

			while @testNS(Token.QUESTION, Token.LEFT_CURLY, Token.LEFT_SQUARE) {
				if @token == Token.QUESTION {
					var modifier = @yep(AST.Modifier(ModifierKind.Nullable, @yes()))

					if !@testNS(Token.LEFT_CURLY, Token.LEFT_SQUARE) {
						@rollback(mark)

						break
					}

					AST.pushModifier(type.value, modifier)
				}

				if @token == Token.LEFT_CURLY {
					@commit()

					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					var property = @yep(AST.PropertyType([], null, type, type, type))

					type = @yep(AST.ObjectType([], [], property, property, @yes()))
				}
				else {
					@commit()

					unless @test(Token.RIGHT_SQUARE) {
						@throw(']')
					}

					var property = @yep(AST.PropertyType([], null, type, type, type))

					type = @yep(AST.ArrayType([], [], property, property, @yes()))
				}

				mark = @mark()
			}

			if nullable && @testNS(Token.QUESTION) {
				var modifier = @yep(AST.Modifier(ModifierKind.Nullable, @yes()))

				return @yep(AST.pushModifier(type.value, modifier))
			}
			else {
				return type
			}
		} # }}}

		hasNL_1M(): Boolean ~ SyntaxError # {{{
		{
			if @test(Token.NEWLINE) {
				@commit()

				@skipNewLine()

				return true
			}
			else {
				return false
			}
		} # }}}

		hasSeparator(
			token: Token
		): Boolean ~ SyntaxError # {{{
		{
			if @match(Token.COMMA, Token.NEWLINE, token) == Token.COMMA {
				@commit()

				if @test(token) {
					return false
				}

				@skipNewLine()

				return true
			}
			else if @token == Token.NEWLINE {
				@commit()

				@skipNewLine()

				return true
			}
			else if @token == token {
				return true
			}
			else {
				return false
			}
		} # }}}

		hasTopicReference(
			expression: NodeData(Argument, Expression)
		): Boolean # {{{
		{
			match expression {
				.ArrayExpression {
					for var value in expression.values {
						if @hasTopicReference(value) {
							return true
						}
					}
				}
				.CallExpression {
					if @hasTopicReference(expression.callee) {
						return true
					}

					for var argument in expression.arguments {
						if @hasTopicReference(argument) {
							return true
						}
					}
				}
				.MemberExpression {
					if ?expression.object && @hasTopicReference(expression.object) {
						return true
					}
				}
				.TopicReference {
					return true
				}
			}

			return false
		} # }}}

		isComputed(
			expression: NodeData(Expression)?
		): Boolean # {{{
		{
			match expression {
				.CallExpression, .RollingExpression, .DisruptiveExpression {
					return true
				}
				.MemberExpression {
					return @isComputed(expression.object) || @isComputed(expression.property)
				}
				else {
					return false
				}
			}
		} # }}}

		parseModule(): NodeData(Module) ~ SyntaxError # {{{
		{
			var attributes = []
			var body = []

			var dyn attrs = []
			var dyn statement

			if (statement <- @tryShebang()).ok {
				body.push(statement.value)
			}

			@NL_0M()

			until @scanner.isEOF() {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				match @matchM(M.MODULE_STATEMENT) {
					Token.DISCLOSE {
						statement = @reqDiscloseStatement(@yes()).value
					}
					Token.EXPORT {
						statement = @reqExportStatement(@yes()).value
					}
					Token.EXTERN {
						statement = @reqExternStatement(@yes()).value
					}
					Token.EXTERN_IMPORT {
						statement = @reqExternOrImportStatement(@yes()).value
					}
					Token.EXTERN_REQUIRE {
						statement = @reqExternOrRequireStatement(@yes()).value
					}
					Token.INCLUDE {
						statement = @reqIncludeStatement(@yes()).value
					}
					Token.INCLUDE_AGAIN {
						statement = @reqIncludeAgainStatement(@yes()).value
					}
					Token.REQUIRE {
						statement = @reqRequireStatement(@yes()).value
					}
					Token.REQUIRE_EXTERN {
						statement = @reqRequireOrExternStatement(@yes()).value
					}
					Token.REQUIRE_IMPORT {
						statement = @reqRequireOrImportStatement(@yes()).value
					}
					else {
						statement = @reqStatement(null, FunctionMode.Nil).value
					}
				}

				AST.pushAttributes(statement, attrs)

				body.push(statement)

				@NL_0M()
			}

			return AST.Module(attributes, body, this)
		} # }}}

		parseModuleType(): NodeData(TypeList) ~ SyntaxError # {{{
		{
			@NL_0M()

			var types = []
			var attributes = []
			var mut attrs = []
			var mut type: Event = NO

			until @scanner.isEOF() {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				var type = @reqTypeDescriptive(TypeMode.Module)

				@reqNL_EOF_1M()

				AST.pushAttributes(type.value, attrs)

				types.push(type)
			}

			return AST.TypeList(attributes, types, attributes[0] ?? types[0], types[types.length - 1])
		} # }}}

		parseStatements(
			mode: FunctionMode
		): NodeData(StatementList) ~ SyntaxError # {{{
		{
			var first = @yep()
			var attributes = []
			var body = []

			var dyn attrs = []
			var dyn statement

			@NL_0M()

			while !@scanner.isEOF() {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				var statement = @reqStatement(null, mode).value

				AST.pushAttributes(statement, attrs)

				body.push(statement)

				@NL_0M()
			}

			var last = @yep()

			unless @scanner.isEOF() {
				@throw('EOF')
			}

			return {
				kind: .StatementList
				attributes: [attribute.value for var attribute in attributes]
				body
				start: first.start
				end: last.end
			}
		} # }}}

		popMode(
			{ pop, mode }: ModeTracker
		): Void # {{{
		{
			if pop {
				@mode = mode!?
			}
		} # }}}

		pushMode(
			modifier: ParserMode
		): ModeTracker { # {{{
			if @mode ~~ modifier {
				return { pop: false }
			}
			else {
				var tracker = { pop: true, mode: @mode }

				@mode += modifier

				return tracker
			}
		} # }}}

		replaceReference(
			expression: NodeData(Expression)
			name: String
			reference: NodeData(Expression)
		): Boolean # {{{
		{
			match expression {
				.CallExpression {
					if @replaceReference(expression.callee, name, reference) {
						expression.start = expression.callee.start

						return true
					}
				}
				.MemberExpression {
					if expression.object is .Reference && expression.object.name == name {
						expression.object = reference
						expression.start = expression.object.start

						return true
					}

					if ?expression.object && @replaceReference(expression.object, name, reference) {
						expression.start = expression.object.start

						return true
					}
				}
			}

			return false
		} # }}}

		reqAccessModifiers(
			modifiers: Event<ModifierData>(Y)[]
		): Event<ModifierData>(Y)[] ~ SyntaxError # {{{
		{
			if @match(Token.PRIVATE, Token.PROTECTED, Token.PUBLIC, Token.INTERNAL) == Token.PRIVATE {
				modifiers.push(@yep(AST.Modifier(ModifierKind.Private, @yes())))
			}
			else if @token == Token.PROTECTED {
				modifiers.push(@yep(AST.Modifier(ModifierKind.Protected, @yes())))
			}
			else if @token == Token.PUBLIC {
				modifiers.push(@yep(AST.Modifier(ModifierKind.Public, @yes())))
			}
			else if @token == Token.INTERNAL {
				modifiers.push(@yep(AST.Modifier(ModifierKind.Internal, @yes())))
			}

			return modifiers
		} # }}}

		reqArgumentList(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Event<NodeData(Argument)>(Y)[]>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			if @test(Token.RIGHT_ROUND) {
				return @yep([])
			}
			else {
				var arguments = []
				var mut argument: Event = NO

				var mut subEMode = ExpressionMode.ImplicitMember
				if eMode ~~ ExpressionMode.Pipeline {
					subEMode += ExpressionMode.Pipeline
				}

				while @until(Token.RIGHT_ROUND) {
					if @test(Token.BACKSLASH) {
						var first = @yes()

						if fMode ~~ FunctionMode.Method && @test(Token.AT) {
							var alias = @reqThisExpression(@yes())

							argument = @yep(AST.PositionalArgument([], alias, alias, alias))
						}
						else {
							var identifier = @reqIdentifier()

							argument = @yep(AST.PositionalArgument([], identifier, identifier, identifier))
						}
					}
					else if eMode ~~ .Curry && @test(.CARET) {
						var first = @yes()

						if @testNS(Token.NUMERAL) {
							var index = @yep(AST.NumericExpression(parseInt(@scanner.value(), 10), 10, @yes()))

							argument = @yep(AST.PlaceholderArgument([], index, first, index))
						}
						else {
							argument = @yep(AST.PlaceholderArgument([], null, first, first))
						}
					}
					else if @test(Token.COLON) {
						var first = @yes()

						var late expression

						if fMode ~~ FunctionMode.Method && @test(Token.AT) {
							var alias = @reqThisExpression(@yes())

							expression = @yep(AST.NamedArgument([], @yep(alias.value.name), alias, first, alias))
						}
						else {
							var identifier = @reqIdentifier()

							expression = @yep(AST.NamedArgument([], identifier, identifier, first, identifier))
						}

						argument = @altRestrictiveExpression(expression, fMode)
					}
					else if eMode ~~ .Curry && @test(Token.DOT_DOT_DOT) {
						var mark = @mark()
						var modifier = @yep(AST.Modifier(ModifierKind.Rest, @yes()))

						if @testNS(Token.COMMA, Token.NEWLINE, Token.RIGHT_ROUND) {
							argument = @yep(AST.PlaceholderArgument([modifier], null, modifier, modifier))
						}
						else {
							@rollback(mark)
						}
					}

					if argument.ok {
						arguments.push(argument)
					}
					else {
						argument = @reqExpression(subEMode, fMode, MacroTerminator.List)

						if argument.value is .Identifier {
							if @test(Token.COLON) {
								@commit()

								var value = if eMode ~~ ExpressionMode.Curry && @test(Token.CARET) {
									var first = @yes()

									if @testNS(Token.NUMERAL) {
										var index = @yep(AST.NumericExpression(parseInt(@scanner.value(), 10), 10, @yes()))

										set @yep(AST.PlaceholderArgument([], index, first, index))
									}
									else {
										set @yep(AST.PlaceholderArgument([], null, first, first))
									}
								}
								else {
									set @reqExpression(subEMode, fMode, MacroTerminator.List)
								}

								var expression = @yep(AST.NamedArgument([], argument!!, value, argument, value))

								arguments.push(@altRestrictiveExpression(expression, fMode))
							}
							else {
								arguments.push(argument)
							}
						}
						else {
							arguments.push(argument)
						}
					}

					if @match(Token.COMMA, Token.NEWLINE) == Token.COMMA || @token == Token.NEWLINE {
						@commit().NL_0M()
					}
					else {
						break
					}

					argument = NO
				}

				@throw(')') unless @test(Token.RIGHT_ROUND)

				return @yep(arguments)
			}
		} # }}}

		reqArray(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(ArrayExpression, ArrayRange, ArrayComprehension)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.RIGHT_SQUARE) {
				return @yep(AST.ArrayExpression([], first, @yes()))
			}

			var mark = @mark()

			var mut operand = @tryRangeOperand(ExpressionMode.InlineOnly, fMode)

			if operand.ok && (@match(Token.LEFT_ANGLE, Token.DOT_DOT) == Token.LEFT_ANGLE || @token == Token.DOT_DOT) {
				var then = @token == Token.LEFT_ANGLE
				if then {
					@commit()

					unless @test(Token.DOT_DOT) {
						@throw('..')
					}

					@commit()
				}
				else {
					@commit()
				}

				var til = @test(Token.LEFT_ANGLE)
				if til {
					@commit()
				}

				var toOperand = @reqPrefixedOperand(ExpressionMode.InlineOnly, fMode)

				var dyn byOperand
				if @test(Token.DOT_DOT) {
					@commit()

					byOperand = @reqPrefixedOperand(ExpressionMode.InlineOnly, fMode)
				}

				unless @test(Token.RIGHT_SQUARE) {
					@throw(']')
				}

				if then {
					if til {
						return @yep(AST.ArrayRangeTI(operand, toOperand, byOperand, first, @yes()))
					}
					else {
						return @yep(AST.ArrayRangeTO(operand, toOperand, byOperand, first, @yes()))
					}
				}
				else {
					if til {
						return @yep(AST.ArrayRangeFI(operand, toOperand, byOperand, first, @yes()))
					}
					else {
						return @yep(AST.ArrayRangeFO(operand, toOperand, byOperand, first, @yes()))
					}
				}
			}
			else {
				@rollback(mark)

				@NL_0M()

				if @test(Token.RIGHT_SQUARE) {
					return @yep(AST.ArrayExpression([], first, @yes()))
				}

				var expression = @reqExpression(null, fMode, MacroTerminator.Array)

				if @match(Token.RIGHT_SQUARE, Token.FOR, Token.NEWLINE, Token.REPEAT) == Token.RIGHT_SQUARE {
					return @yep(AST.ArrayExpression([expression], first, @yes()))
				}
				else if @token == Token.FOR {
					return @altArrayComprehensionFor(expression, first, fMode)
				}
				else if @token == Token.NEWLINE {
					var mark = @mark()

					@commit().NL_0M()

					if @match(Token.RIGHT_SQUARE, Token.FOR, Token.REPEAT) == Token.RIGHT_SQUARE {
						return @yep(AST.ArrayExpression([expression], first, @yes()))
					}
					else if @token == Token.FOR {
						return @altArrayComprehensionFor(expression, first, fMode)
					}
					else if @token == Token.REPEAT {
						return @altArrayComprehensionRepeat(expression, first, fMode)
					}
					else {
						@rollback(mark)

						return @altArrayList(expression, first, fMode)
					}
				}
				else if @token == Token.REPEAT {
					return @altArrayComprehensionRepeat(expression, first, fMode)
				}
				else {
					return @altArrayList(expression, first, fMode)
				}
			}
		} # }}}

		reqAttribute(
			first: Event(Y)
			isStatement: Boolean
		): Event<NodeData(AttributeDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var declaration = @reqAttributeMember()

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			var last = @yes()

			if isStatement {
				unless @test(Token.NEWLINE) {
					@throw('NewLine')
				}

				@commit()
			}

			@scanner.skipComments()

			return @yep(AST.AttributeDeclaration(declaration, first, last))
		} # }}}

		reqAttributeIdentifier(): Event<NodeData(Identifier)>(Y) ~ SyntaxError # {{{
		{
			if @scanner.test(Token.ATTRIBUTE_IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqAttributeMember(): Event<NodeData(Identifier, AttributeOperation, AttributeExpression)>(Y) ~ SyntaxError # {{{
		{
			var identifier = @reqAttributeIdentifier()

			if @match(Token.EQUALS, Token.LEFT_ROUND) == Token.EQUALS {
				@commit()

				var value = @reqString()

				return @yep(AST.AttributeOperation(identifier, value, identifier, value))
			}
			else if @token == Token.LEFT_ROUND {
				@commit()

				var arguments = [@reqAttributeMember()]

				while @test(Token.COMMA) {
					@commit()

					arguments.push(@reqAttributeMember())
				}

				if !@test(Token.RIGHT_ROUND) {
					@throw(')')
				}

				return @yep(AST.AttributeExpression(identifier, arguments, identifier, @yes()))
			}
			else {
				return identifier
			}
		} # }}}

		reqAwaitExpression(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(AwaitExpression)>(Y) ~ SyntaxError # {{{
		{
			var operand = @reqPrefixedOperand(eMode, fMode)

			return @yep(AST.AwaitExpression([], null, operand, first, operand))
		} # }}}

		reqBinaryOperand(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var operand = @tryBinaryOperand(eMode, fMode)

			if operand.ok {
				return operand
			}
			else {
				// TODO!
				// ?#operand.expecteds ? @throw(...operand.expecteds) : @throw()
				@throw(...?operand.expecteds)
			}
		} # }}}

		reqBitmaskMember(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
		): Event<NodeData(BitmaskValue, MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var member = @tryBitmaskMember(attributes, modifiers, bits, null)

			unless member.ok {
				@throw('Identifier')
			}

			return member
		} # }}}

		reqBitmaskMemberBlock(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			members: NodeData(BitmaskValue, MethodDeclaration)[]
		): Void ~ SyntaxError # {{{
		{
			@commit().NL_0M()

			var mut attrs = [...attributes]

			bits += MemberBits.Attribute

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attrs) {
					continue
				}

				members.push(@reqBitmaskMember(attrs, modifiers, bits).value)
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			@commit().reqNL_1M()
		} # }}}

		reqBitmaskMemberList(
			members: NodeData(BitmaskValue, MethodDeclaration)[]
		): Void ~ SyntaxError # {{{
		{
			var attributes = @stackOuterAttributes([])
			var modifiers = []

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier(.Closed)

			if accessModifier.ok && @test(Token.LEFT_CURLY) {
				return @reqBitmaskMemberBlock(
					attributes
					[accessModifier]
					MemberBits.Method
					members
				)
			}

			var first = accessModifier.ok ? accessModifier : null
			var staticMark = @mark()
			var staticModifier = @tryStaticModifier()

			if staticModifier.ok {
				if @test(Token.LEFT_CURLY) {
					return @reqBitmaskMemberBlock(
						attributes
						[
							accessModifier if accessModifier.ok
							staticModifier
						]
						MemberBits.Method
						members
					)
				}
				else {
					var member = @tryBitmaskMember(
						attributes
						[
							accessModifier if accessModifier.ok
							staticModifier
						]
						MemberBits.Method
						(first ?? staticModifier)!!
					)

					if member.ok {
						members.push(member.value)

						return
					}

					@rollback(staticMark)
				}
			}

			if accessModifier.ok {
				var member = @tryBitmaskMember(
					attributes
					[accessModifier]
					MemberBits.Method
					accessModifier
				)

				if member.ok {
					members.push(member.value)

					return
				}

				@rollback(accessMark)
			}

			members.push(@reqBitmaskMember(attributes, [], MemberBits.Value + MemberBits.Method).value)
		} # }}}

		reqBitmaskStatement(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[] = []
		): Event<NodeData(BitmaskDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryBitmaskStatement(first, modifiers)

			if statement.ok {
				return statement
			}
			else {
				@throw('Identifier')
			}

			// TODO!
			// if var statement ?&= @tryBitmaskStatement(first, modifiers) {
			// 	return statement
			// }
			// else {
			// 	@throw('Identifier')
			// }

			// match var statement = @tryBitmaskStatement(first, modifiers) {
			// 	true => return statement
			// 	false => @throw('Identifier')
			// }
		} # }}}

		reqBlock(
			mut first: Event
			eMode: ExpressionMode?
			fMode: FunctionMode
		): Event<NodeData(Block)>(Y) ~ SyntaxError # {{{
		{
			if !first.ok {
				unless @test(Token.LEFT_CURLY) {
					@throw('{')
				}

				first = @yes()
			}

			@NL_0M()

			var attributes = []
			var statements = []

			var dyn attrs = []
			var dyn statement
			while @match(Token.RIGHT_CURLY, Token.HASH_EXCLAMATION_LEFT_SQUARE, Token.HASH_LEFT_SQUARE) != Token.EOF && @token != Token.RIGHT_CURLY {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				statement = @reqStatement(eMode, fMode)

				AST.pushAttributes(statement.value, attrs)

				statements.push(statement)

				@NL_0M()
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.Block(attributes, statements, first, @yes()))
		} # }}}

		reqBreakStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(BreakStatement, IfStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.IF, Token.UNLESS) == Token.IF {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(eMode + .NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.IfStatement(condition, @yep(AST.BreakStatement(null, first, first)), null, first, condition))
				}
				else {
					return @yep(AST.BreakStatement(label, first, label))
				}
			}
			else if @token == Token.UNLESS {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(eMode + .NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.UnlessStatement(condition, @yep(AST.BreakStatement(null, first, first)), first, condition))
				}
				else {
					return @yep(AST.BreakStatement(label, first, label))
				}
			}
			else {
				var label = @tryIdentifier()

				if label.ok {
					if @match(Token.IF, Token.UNLESS) == Token.IF {
						@commit()

						var condition = @reqExpression(eMode + .NoRestriction, fMode)

						return @yep(AST.IfStatement(condition, @yep(AST.BreakStatement(label, first, label)), null, first, condition))
					}
					else if @token == Token.UNLESS {
						@commit()

						var condition = @reqExpression(eMode + .NoRestriction, fMode)

						return @yep(AST.UnlessStatement(condition, @yep(AST.BreakStatement(label, first, label)), first, condition))
					}
					else {
						return @yep(AST.BreakStatement(label, first, label))
					}
				}
				else {
					return @yep(AST.BreakStatement(null, first, first))
				}
			}
		} # }}}

		reqCascadeExpression(
			mut object: Event<NodeData(Expression)>(Y)
			mut modifiers: ModifierData[]
			identifier: Event<NodeData(Identifier)>(Y)?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var mode = eMode + ExpressionMode.ImplicitMember + ExpressionMode.NoMultiLine

			repeat {
				var value = @yep(AST.MemberExpression(modifiers, @yep(AST.Reference('main', object)), @reqIdentifier()))
				var operand = @reqUnaryOperand(value, eMode + ExpressionMode.NoMultiLine, fMode)
				var expression = @altRestrictiveExpression(operand, fMode)

				if expression.value is .RestrictiveExpression {
					// TODO! js shouldn't test the value
					var { operator, condition, expression % value } = expression.value

					object = @yep(AST.DisruptiveExpression(@yep(operator), @yep(condition), object, @yep(value), object, condition))
				}
				else {
					@replaceReference(value.value, 'main', object.value)

					object = expression
				}

				var mark = @mark()

				unless @test(Token.NEWLINE) {
					break
				}

				@commit().NL_0M()

				if @test(Token.DOT) {
					modifiers = []

					@commit()
				}
				else if @test(Token.QUESTION_DOT) {
					modifiers = [AST.Modifier(ModifierKind.Nullable, @yes())]
				}
				else {
					@rollback(mark)

					break
				}
			}

			return object
		} # }}}

		reqCatchOnClause(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(CatchClause)>(Y) ~ SyntaxError # {{{
		{
			var type = @reqIdentifier()

			var dyn binding
			if @test(Token.CATCH) {
				@commit()

				binding = @reqIdentifier()
			}

			@NL_0M()

			var body = @reqBlock(NO, null, fMode)

			return @yep(AST.CatchClause(binding, type, body, first, body))
		} # }}}

		reqClassMember(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			first: Range?
		): Event<NodeData(ClassMember)>(Y) ~ SyntaxError # {{{
		{
			var member = @tryClassMember(attributes, modifiers, bits, first)

			unless member.ok {
				@throw('Identifier', 'String', 'Template')
			}

			return member
		} # }}}

		reqClassMemberBlock(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			members: Event<NodeData(ClassMember)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			@commit().NL_0M()

			var mut attrs = [...attributes]

			bits += MemberBits.Attribute

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attrs) {
					continue
				}

				members.push(@reqClassMember(attrs, modifiers, bits, null))
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			@commit().reqNL_1M()
		} # }}}

		reqClassMemberList(
			members: Event<NodeData(ClassMember)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var mut first: Range? = null

			var attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			var macroMark = @mark()

			if @test(Token.MACRO) {
				var second = @yes()
				var mut identifier: Event? = null

				if @test(Token.LEFT_CURLY) {
					@commit().NL_0M()

					while @until(Token.RIGHT_CURLY) {
						members.push(@reqMacroStatement(attributes))
					}

					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					@commit().reqNL_1M()

					return
				}
				else if (identifier <- @tryIdentifier()).ok {
					members.push(@reqMacroStatement(attributes, identifier, first ?? second))

					return
				}

				@rollback(macroMark)
			}

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier(.Opened)

			if accessModifier.ok && @test(Token.LEFT_CURLY) {
				return @reqClassMemberBlock(
					attributes
					[accessModifier]
					MemberBits.Variable + MemberBits.FinalVariable + MemberBits.LateVariable + MemberBits.Property + MemberBits.Method + MemberBits.AssistMethod + MemberBits.OverrideMethod + MemberBits.Proxy
					members
				)
			}

			if @test(Token.ABSTRACT) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(ModifierKind.Abstract, @yes()))

				if @test(Token.LEFT_CURLY) {
					var modifiers = [modifier]
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					return @reqClassMemberBlock(
						attributes
						modifiers
						MemberBits.Method + MemberBits.Property + MemberBits.NoBody
						members
					)
				}

				@rollback(mark)
			}
			else if @test(.ASSIST) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(.Assist, @yes()))

				if @test(.LEFT_CURLY) {
					var modifiers = [modifier]
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					return @reqClassMemberBlock(
						attributes
						modifiers
						MemberBits.Method
						members
					)
				}

				@rollback(mark)
			}
			else if @test(Token.OVERRIDE) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(ModifierKind.Override, @yes()))

				if @test(Token.LEFT_CURLY) {
					var modifiers = [modifier]
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					return @reqClassMemberBlock(
						attributes
						modifiers
						MemberBits.Method + MemberBits.Property
						members
					)
				}

				@rollback(mark)
			}

			var staticMark = @mark()
			var dyn staticModifier = NO

			if @test(Token.STATIC) {
				staticModifier = @yep(AST.Modifier(ModifierKind.Static, @yes()))

				var modifiers = [staticModifier]
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(Token.LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						MemberBits.Variable + MemberBits.FinalVariable + MemberBits.LateVariable + MemberBits.Property + MemberBits.Method + MemberBits.FinalMethod + MemberBits.Proxy
						members
					)
				}
				else if @test(Token.PROXY) {
					var mark = @mark()

					@commit()

					if @test(Token.LEFT_CURLY) {
						return @reqClassProxyBlock(
							attributes
							modifiers
							members
						)
					}
					else if @test(Token.AT) {
						return @reqClassProxyGroup(
							attributes
							modifiers
							members
							staticModifier
						)
					}
					else {
						var member = @tryClassProxy(
							attributes
							modifiers
							modifiers[0]
						)

						if member.ok {
							members.push(member)

							return
						}

						@rollback(mark)
					}
				}
			}
			else if @test(Token.PROXY) {
				var mark = @mark()
				var first = @yes()

				var modifiers = []
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(Token.LEFT_CURLY) {
					return @reqClassProxyBlock(
						attributes
						modifiers
						members
					)
				}
				else if @test(Token.AT) {
					return @reqClassProxyGroup(
						attributes
						modifiers
						members
						first
					)
				}
				else {
					var member = @tryClassProxy(
						attributes
						modifiers
						modifiers[0] ?? first
					)

					if member.ok {
						members.push(member)

						return
					}

					@rollback(mark)
				}
			}

			var finalMark = @mark()
			var dyn finalModifier = NO

			if @test(Token.FINAL) {
				finalModifier = @yep(AST.Modifier(.Final, @yes()))

				if @test(Token.LEFT_CURLY) {
					var modifiers = [finalModifier]
					if staticModifier.ok {
						modifiers.unshift(staticModifier)
					}
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					if staticModifier.ok {
						return @reqClassMemberBlock(
							attributes
							modifiers
							MemberBits.Variable + MemberBits.LateVariable + MemberBits.RequiredAssignment + MemberBits.Property + MemberBits.Method
							members
						)
					}
					else {
						return @reqClassMemberBlock(
							attributes
							modifiers
							MemberBits.Variable + MemberBits.LateVariable + MemberBits.RequiredAssignment + MemberBits.Property + MemberBits.OverrideProperty + MemberBits.Method + MemberBits.AssistMethod + MemberBits.OverrideMethod
							members
						)
					}
				}
				else if !staticModifier.ok {
					if @test(.ASSIST) {
						var mark = @mark()
						var modifier = @yep(AST.Modifier(.Assist, @yes()))

						if @test(.LEFT_CURLY) {
							var modifiers = [finalModifier, modifier]
							if accessModifier.ok {
								modifiers.unshift(accessModifier)
							}

							return @reqClassMemberBlock(
								attributes
								modifiers
								MemberBits.Method
								members
							)
						}

						@rollback(mark)
					}
					else if @test(Token.OVERRIDE) {
						var mark = @mark()
						var modifier = @yep(AST.Modifier(ModifierKind.Override, @yes()))

						if @test(Token.LEFT_CURLY) {
							var modifiers = [finalModifier, modifier]
							if accessModifier.ok {
								modifiers.unshift(accessModifier)
							}

							return @reqClassMemberBlock(
								attributes
								modifiers
								MemberBits.Method + MemberBits.Property
								members
							)
						}

						@rollback(mark)
					}
				}
			}

			if @test(Token.LATE) {
				var lateMark = @mark()
				var lateModifier = @yep(AST.Modifier(ModifierKind.LateInit, @yes()))

				var modifiers = [lateModifier]
				if finalModifier.ok {
					modifiers.unshift(finalModifier)
				}
				if staticModifier.ok {
					modifiers.unshift(staticModifier)
				}
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(Token.LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						finalModifier.ok ? MemberBits.Variable : MemberBits.Variable + MemberBits.FinalVariable
						members
					)
				}

				var member = @tryClassMember(
					attributes
					modifiers
					MemberBits.Variable + MemberBits.NoAssignment
					first ?? modifiers[0]
				)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(lateMark)
			}

			if accessModifier.ok {
				var member = @tryClassMember(attributes, [accessModifier], staticModifier, staticMark, finalModifier, finalMark, first ?? accessModifier)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(accessMark)
			}

			var member = @tryClassMember(attributes, [], staticModifier, staticMark, finalModifier, finalMark, first)

			unless member.ok {
				@throw('Identifier', 'String', 'Template')
			}

			members.push(member)
		} # }}}

		reqClassMethod(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			name: Event<NodeData(Identifier)>(Y)
			first: Range
		): Event<NodeData(MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var typeParameters = @tryTypeParameterList()
			var parameters = @reqClassMethodParameterList(null, bits ~~ MemberBits.NoBody ? DestructuringMode.EXTERNAL_ONLY : null)
			var type = @tryFunctionReturns(.Method, bits !~ .NoBody)
			var throws = @tryFunctionThrows()

			if bits ~~ MemberBits.NoBody {
				@reqNL_1M()

				return @yep(AST.MethodDeclaration(attributes, modifiers, name, typeParameters, parameters, type, throws, null, first, (throws ?? type ?? parameters)!!))
			}
			else {
				var body = @tryFunctionBody(modifiers, FunctionMode.Method, !?type && !?throws)

				@reqNL_1M()

				return @yep(AST.MethodDeclaration(attributes, modifiers, name, typeParameters, parameters, type, throws, body, first, (body ?? throws ?? type ?? parameters)!!))
			}
		} # }}}

		reqClassMethodParameterList(
			mut first: Event = NO
			mut pMode: DestructuringMode = DestructuringMode.Nil
		): Event<Event<NodeData(Parameter)>(Y)[]>(Y) ~ SyntaxError # {{{
		{
			if !first.ok {
				unless @test(Token.LEFT_ROUND) {
					@throw('(')
				}

				first = @yes()
			}

			var parameters = []

			@NL_0M()

			pMode += DestructuringMode.Parameter + DestructuringMode.THIS_ALIAS

			while @until(Token.RIGHT_ROUND) {
				parameters.push(@reqParameter(pMode, FunctionMode.Method))

				@reqSeparator(Token.RIGHT_ROUND)
			}

			unless @test(Token.RIGHT_ROUND) {
				@throw(')')
			}

			return @yep(parameters, first, @yes())
		} # }}}

		reqClassProperty(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			type: Event<NodeData(Type)>
			first: Range
		): Event<NodeData(PropertyDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var dyn defaultValue, accessor, mutator

			if @test(Token.NEWLINE) {
				@commit().NL_0M()

				if @match(Token.GET, Token.SET) == Token.GET {
					var first = @yes()

					if @match(Token.EQUALS_RIGHT_ANGLE, Token.LEFT_CURLY) == Token.EQUALS_RIGHT_ANGLE {
						@commit()

						var expression = @reqExpression(.Nil, .Method)

						accessor = @yep(AST.AccessorDeclaration(expression, first, expression))
					}
					else if @token == Token.LEFT_CURLY {
						var block = @reqBlock(NO, null, FunctionMode.Method)

						accessor = @yep(AST.AccessorDeclaration(block, first, block))
					}
					else {
						accessor = @yep(AST.AccessorDeclaration(first))
					}

					@reqNL_1M()

					if @test(Token.SET) {
						var first = @yes()

						if @match(Token.EQUALS_RIGHT_ANGLE, Token.LEFT_CURLY) == Token.EQUALS_RIGHT_ANGLE {
							@commit()

							var expression = @reqExpression(.Nil, .Method)

							mutator = @yep(AST.MutatorDeclaration(expression, first, expression))
						}
						else if @token == Token.LEFT_CURLY {
							var block = @reqBlock(NO, null, FunctionMode.Method)

							mutator = @yep(AST.MutatorDeclaration(block, first, block))
						}
						else {
							mutator = @yep(AST.MutatorDeclaration(first))
						}

						@reqNL_1M()
					}
				}
				else if @token == Token.SET {
					var first = @yes()

					if @match(Token.EQUALS_RIGHT_ANGLE, Token.LEFT_CURLY) == Token.EQUALS_RIGHT_ANGLE {
						@commit()

						var expression = @reqExpression(.Nil, .Method)

						mutator = @yep(AST.MutatorDeclaration(expression, first, expression))
					}
					else if @token == Token.LEFT_CURLY {
						var block = @reqBlock(NO, null, FunctionMode.Method)

						mutator = @yep(AST.MutatorDeclaration(block, first, block))
					}
					else {
						mutator = @yep(AST.MutatorDeclaration(first))
					}

					@reqNL_1M()
				}
				else {
					@throw('get', 'set')
				}
			}
			else {
				if @match(Token.GET, Token.SET) == Token.GET {
					accessor = @yep(AST.AccessorDeclaration(@yes()))

					if @test(Token.COMMA) {
						@commit()

						if @test(Token.SET) {
							mutator = @yep(AST.MutatorDeclaration(@yes()))
						}
						else {
							@throw('set')
						}
					}
				}
				else if @token == Token.SET {
					mutator = @yep(AST.MutatorDeclaration(@yes()))
				}
				else {
					@throw('get', 'set')
				}
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			var dyn last = @yes()

			if @test(Token.EQUALS) {
				@commit()

				defaultValue = @reqExpression(.Nil, .Method)
			}

			@reqNL_1M()

			return @yep(AST.PropertyDeclaration(attributes, modifiers, name, type, defaultValue, accessor, mutator, first, defaultValue ?? last))
		} # }}}

		reqClassProxy(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			first: Range?
		): Event<NodeData(ProxyDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var member = @tryClassProxy(attributes, modifiers, first)

			unless member.ok {
				@throw('Identifier')
			}

			return member
		} # }}}

		reqClassProxyBlock(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			members: Event<NodeData(ClassMember)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			@commit().NL_0M()

			var dyn attrs = [...attributes]

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attrs) {
					continue
				}

				members.push(@reqClassProxy(attrs, modifiers, null))
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			@commit().reqNL_1M()
		} # }}}

		reqClassProxyGroup(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			members: Event<NodeData(ClassMember)>(Y)[]
			first: Event(Y)
		): Void ~ SyntaxError # {{{
		{
			var recipient = @reqExpression(.Nil, .Method)

			@throw('{') unless @test(Token.LEFT_CURLY)

			@commit().reqNL_1M()

			var attrs = [...attributes]
			var elements = []

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attrs) {
					continue
				}

				var external = @reqIdentifier()

				var internal = if @test(Token.EQUALS_RIGHT_ANGLE) {
					@commit()

					set @reqIdentifier()
				}
				else {
					set external
				}

				@reqNL_1M()

				elements.push(@yep(AST.ProxyDeclaration(attrs, modifiers, internal, external, external, internal)))
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			members.push(@yep(AST.ProxyGroupDeclaration(attrs, modifiers, recipient, elements, first, @yes())))

			@reqNL_1M()
		} # }}}

		reqClassStatement(
			modifiers: Event<ModifierData>(Y)[] = []
			first: Event(Y)
		): Event<NodeData(ClassDeclaration)>(Y) ~ SyntaxError # {{{
		{
			return @reqClassStatementBody(modifiers, @reqIdentifier(), first)
		} # }}}

		reqClassStatementBody(
			modifiers: Event<ModifierData>(Y)[] = []
			name: Event<NodeData(Identifier)>(Y)
			first: Event(Y)
		): Event<NodeData(ClassDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var dyn generic
			if @test(Token.LEFT_ANGLE) {
				generic = @reqTypeGeneric(@yes())
			}

			var dyn version
			if @test(Token.AT) {
				@commit()

				unless @test(Token.CLASS_VERSION) {
					@throw('Class Version')
				}

				var data = @value()

				version = @yep(AST.Version(data[0], data[1], data[1], @yes()))
			}

			var dyn extends
			if @test(Token.EXTENDS) {
				@commit()

				extends = @reqIdentifierOrMember()
			}

			var implements = []
			if @test(Token.IMPLEMENTS) {
				@commit()

				implements.push(@reqIdentifierOrMember())

				while @test(Token.COMMA) {
					@commit()

					implements.push(@reqIdentifierOrMember())
				}
			}

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var attributes = []
			var members = []

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@reqClassMemberList(members)
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.ClassDeclaration(attributes, name, version, extends, implements, modifiers, members, first, @yes()))
		} # }}}

		reqClassVariable(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			name: Event<NodeData(Identifier)>(Y)
			first: Range?
		): Event<NodeData(FieldDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var variable = @tryClassVariable(attributes, modifiers, bits, name, null, first)

			unless variable.ok {
				@throw('Identifier', 'String', 'Template')
			}

			return variable
		} # }}}

		reqComputedPropertyName(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(ComputedPropertyName)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(eMode, fMode)

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ComputedPropertyName(expression, first, @yes()))
		} # }}}

		reqConditionAssignment(): Event<BinaryOperatorData(Assignment)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.QUESTION_EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Existential, @yes()))
			}
			else if @test(Token.QUESTION_HASH_EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NonEmpty, @yes()))
			}

			@throw('?=', '?#=')
		} # }}}

		reqContinueStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(ContinueStatement, IfStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.IF, Token.UNLESS) == Token.IF {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(eMode + .NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.IfStatement(condition, @yep(AST.ContinueStatement(null, first, first)), null, first, condition))
				}
				else {
					return @yep(AST.ContinueStatement(label, first, label))
				}
			}
			else if @token == Token.UNLESS {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(eMode + .NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.UnlessStatement(condition, @yep(AST.ContinueStatement(null, first, first)), first, condition))
				}
				else {
					return @yep(AST.ContinueStatement(label, first, label))
				}
			}
			else {
				var label = @tryIdentifier()

				if label.ok {
					if @match(Token.IF, Token.UNLESS) == Token.IF {
						@commit()

						var condition = @reqExpression(eMode + .NoRestriction, fMode)

						return @yep(AST.IfStatement(condition, @yep(AST.ContinueStatement(label, first, label)), null, first, condition))
					}
					else if @token == Token.UNLESS {
						@commit()

						var condition = @reqExpression(eMode + .NoRestriction, fMode)

						return @yep(AST.UnlessStatement(condition, @yep(AST.ContinueStatement(label, first, label)), first, condition))
					}
					else {
						return @yep(AST.ContinueStatement(label, first, label))
					}
				}
				else {
					return @yep(AST.ContinueStatement(null, first, first))
				}
			}
		} # }}}

		reqDefaultAssignmentOperator(): Event<BinaryOperatorData(Assignment)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
			}
			else if @test(Token.QUESTION_QUESTION_EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NullCoalescing, @yes()))
			}
			else if @test(Token.QUESTION_HASH_HASH_EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind.EmptyCoalescing, @yes()))
			}

			@throw('=', '??=', '##=')
		} # }}}

		reqDestructuring(
			mut dMode: DestructuringMode?
			fMode: FunctionMode
		): Event<NodeData(ArrayBinding, ObjectBinding)>(Y) ~ SyntaxError # {{{
		{
			if !?dMode {
				if fMode ~~ FunctionMode.Method {
					dMode = DestructuringMode.Expression + DestructuringMode.THIS_ALIAS
				}
				else {
					dMode = DestructuringMode.Expression
				}
			}

			if @match(Token.LEFT_CURLY, Token.LEFT_SQUARE) == Token.LEFT_CURLY {
				return @reqDestructuringObject(@yes(), dMode, fMode)
			}
			else if @token == Token.LEFT_SQUARE {
				return @reqDestructuringArray(@yes(), dMode, fMode)
			}
			else {
				@throw('{', '[')
			}
		} # }}}

		reqDestructuringArray(
			first: Range
			dMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(ArrayBinding)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var elements = []

			while @until(Token.RIGHT_SQUARE) {
				elements.push(@reqDestructuringArrayItem(dMode, fMode))

				unless @hasSeparator(Token.RIGHT_SQUARE) {
					break
				}
			}

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ArrayBinding(elements, first, @yes()))
		} # }}}

		reqDestructuringArrayItem(
			dMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(BindingElement)>(Y) ~ SyntaxError # {{{
		{
			var modifiers = []
			var mut {
				first = null
				name = null
				atthis = false
				rest = false
			}

			if @test(Token.DOT_DOT_DOT) {
				first = @yes()
				rest = true

				modifiers.push(AST.Modifier(ModifierKind.Rest, first))

				if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AT) {
					name = @reqThisExpression(@yes())
					atthis = true
				}
				else if dMode ~~ DestructuringMode.MODIFIER && @test(Token.MUT) {
					var mark = @mark()
					var modifier = AST.Modifier(ModifierKind.Mutable, @yes())

					if @test(Token.IDENTIFIER) {
						modifiers.push(modifier)

						first = modifier
						name = @yep(AST.Identifier(@scanner.value(), @yes()))
					}
					else {
						@rollback(mark)

						name = @reqIdentifier()
					}
				}
				else if @test(Token.IDENTIFIER) {
					name = @yep(AST.Identifier(@scanner.value(), @yes()))
				}
			}
			else if dMode ~~ DestructuringMode.RECURSION && @test(Token.LEFT_CURLY) {
				name = @reqDestructuringObject(@yes(), dMode, fMode)
			}
			else if dMode ~~ DestructuringMode.RECURSION && @test(Token.LEFT_SQUARE) {
				name = @reqDestructuringArray(@yes(), dMode, fMode)
			}
			else if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AT) {
				name = @reqThisExpression(@yes())
				atthis = true
			}
			else if dMode ~~ DestructuringMode.MODIFIER && @test(Token.MUT) {
				var mark = @mark()
				var modifier = AST.Modifier(ModifierKind.Mutable, @yes())

				if @test(Token.IDENTIFIER) {
					modifiers.push(modifier)

					first = modifier
					name = @yep(AST.Identifier(@scanner.value(), @yes()))
				}
				else {
					@rollback(mark)

					name = @reqIdentifier()
				}
			}
			else if @test(Token.IDENTIFIER) {
				name = @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else if @test(Token.UNDERSCORE) {
				first = @yes()
			}
			else {
				if dMode ~~ DestructuringMode.RECURSION {
					@throw('...', '_', '[', '{', 'Identifier')
				}
				else {
					@throw('...', '_', 'Identifier')
				}
			}

			if atthis {
				if @test(Token.EXCLAMATION_QUESTION) {
					modifiers.push(AST.Modifier(ModifierKind.NonNullable, @yes()))
				}
			}
			else {
				var mut required = false

				if ?name && dMode ~~ DestructuringMode.DEFAULT && @test(Token.EXCLAMATION) {
					modifiers.push(AST.Modifier(ModifierKind.Required, @yes()))

					required = true
				}

				if dMode ~~ DestructuringMode.TYPE && @test(Token.COLON) {
					@commit()

					var type = @reqTypeLimited()
					var operator = @tryDefaultAssignmentOperator(true)

					if operator.ok {
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.ArrayBindingElement(modifiers, name, type, operator, defaultValue, first ?? name!?, defaultValue))
					}
					else if required {
						@throw('=', '??=', '##=')
					}
					else {
						return @yep(AST.ArrayBindingElement(modifiers, name, type, null, null, first ?? name!?, type ?? name!?))
					}
				}
				else if @test(Token.QUESTION) {
					var modifier = AST.Modifier(ModifierKind.Nullable, @yes())

					modifiers.push(modifier)

					if !?name {
						return @yep(AST.ArrayBindingElement(modifiers, null, null, null, null, first!?, modifier))
					}
				}

				if required {
					var operator = @reqDefaultAssignmentOperator()
					var defaultValue = @reqExpression(.ImplicitMember, fMode)

					return @yep(AST.ArrayBindingElement(modifiers, name, null, operator, defaultValue, first ?? name!?, defaultValue))
				}
			}

			if ?name && dMode ~~ DestructuringMode.DEFAULT {
				var operator = @tryDefaultAssignmentOperator(true)

				if operator.ok {
					var defaultValue = @reqExpression(.ImplicitMember, fMode)

					return @yep(AST.ArrayBindingElement(modifiers, name, null, operator, defaultValue, first ?? name, defaultValue))
				}
			}

			return @yep(AST.ArrayBindingElement(modifiers, name, null, null, null, first ?? name!?, name ?? first!?))
		} # }}}

		reqDestructuringObject(
			first: Event(Y)
			dMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(ObjectBinding)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var elements = []

			do {
				elements.push(@reqDestructuringObjectItem(dMode, fMode))

				@reqSeparator(Token.RIGHT_CURLY)
			}
			while @until(Token.RIGHT_CURLY)

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.ObjectBinding(elements, first, @yes()))
		} # }}}

		reqDestructuringObjectItem(
			dMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(BindingElement)>(Y) ~ SyntaxError # {{{
		{
			var modifiers = []
			var mut {
				first = null
				external = null
				internal = null
				atthis = false
				computed = false
				mutable = false
				rest = false
			}

			if @test(Token.DOT_DOT_DOT) {
				first = @yes()
				rest = true

				modifiers.push(AST.Modifier(ModifierKind.Rest, first))

				if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AT) {
					internal = @reqThisExpression(@yes())
				}
				else if dMode ~~ DestructuringMode.MODIFIER && @test(Token.MUT) {
					var mark = @mark()
					var modifier = AST.Modifier(ModifierKind.Mutable, @yes())

					if @test(Token.IDENTIFIER) {
						modifiers.push(modifier)

						first = modifier
						internal = @yep(AST.Identifier(@scanner.value(), @yes()))
					}
					else {
						@rollback(mark)

						internal = @reqIdentifier()
					}
				}
				else if dMode ~~ DestructuringMode.TYPE {
					if @test(Token.IDENTIFIER) {
						internal = @yep(AST.Identifier(@scanner.value(), @yes()))
					}
				}
				else {
					internal = @reqIdentifier()
				}
			}
			else if dMode ~~ DestructuringMode.MODIFIER && @test(Token.MUT) {
				var mark = @mark()
				var modifier = AST.Modifier(ModifierKind.Mutable, @yes())

				if @test(Token.IDENTIFIER) {
					modifiers.push(modifier)

					first = modifier
					mutable = true
					internal = @yep(AST.Identifier(@scanner.value(), @yes()))
				}
				else {
					@rollback(mark)

					external = @reqIdentifier()
				}
			}
			else if dMode ~~ DestructuringMode.COMPUTED && @test(Token.LEFT_SQUARE) {
				first = @yes()
				external = @reqIdentifier()

				unless @test(Token.RIGHT_SQUARE) {
					@throw(']')
				}

				modifiers.push(AST.Modifier(ModifierKind.Computed, first, @yes()))

				computed = true
			}
			else {
				if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AT) {
					first = @yes()
					internal = @reqThisExpression(first)
					external = @yep(internal.value.name)
					atthis = true
				}
				else {
					external = @reqIdentifier()
				}
			}

			if !rest && !?internal && @test(Token.PERCENT) {
				@commit()

				if dMode ~~ DestructuringMode.RECURSION && @test(Token.LEFT_CURLY) {
					internal = @reqDestructuringObject(@yes(), dMode, fMode)
				}
				else if dMode ~~ DestructuringMode.RECURSION && @test(Token.LEFT_SQUARE) {
					internal = @reqDestructuringArray(@yes(), dMode, fMode)
				}
				else if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AT) {
					internal = @reqThisExpression(@yes())
					atthis = true
				}
				else if dMode ~~ DestructuringMode.MODIFIER && @test(Token.MUT) {
					var mark = @mark()
					var modifier = AST.Modifier(ModifierKind.Mutable, @yes())

					if @test(Token.IDENTIFIER) {
						modifiers.push(modifier)

						internal = @yep(AST.Identifier(@scanner.value(), @yes()))
					}
					else {
						@rollback(mark)

						internal = @reqIdentifier()
					}
				}
				else {
					internal = @reqIdentifier()
				}
			}

			if !?internal {
				internal = external
				external = null
			}

			if dMode ~~ DestructuringMode.TYPE {
				if atthis {
					if @test(Token.EXCLAMATION_QUESTION) {
						modifiers.push(AST.Modifier(ModifierKind.NonNullable, @yes()))
					}
				}
				else {
					var mut required = false

					if !rest && dMode ~~ DestructuringMode.DEFAULT && @test(Token.EXCLAMATION) {
						modifiers.push(AST.Modifier(ModifierKind.Required, @yes()))

						required = true
					}

					if @test(Token.COLON) {
						@commit()

						var type = @reqTypeLimited()
						var operator = @tryDefaultAssignmentOperator(true)

						if operator.ok {
							var defaultValue = @reqExpression(.ImplicitMember, fMode)

							return @yep(AST.ObjectBindingElement(modifiers, external, internal, type, operator, defaultValue, first ?? external ?? internal!?, defaultValue))
						}
						else {
							return @yep(AST.ObjectBindingElement(modifiers, external, internal, type, null, null, first ?? external ?? internal!?, type ?? internal ?? external!?))
						}
					}
					else if !rest && @test(Token.QUESTION) {
						modifiers.push(AST.Modifier(ModifierKind.Nullable, @yes()))
					}

					if required {
						var operator = @reqDefaultAssignmentOperator()
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.ObjectBindingElement(modifiers, external, internal, null, operator, defaultValue, first ?? external ?? internal!?, defaultValue))
					}
				}

				if (!rest || ?internal) && dMode ~~ DestructuringMode.DEFAULT {
					var operator = @tryDefaultAssignmentOperator(true)

					if operator.ok {
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.ObjectBindingElement(modifiers, external, internal, null, operator, defaultValue, first ?? external ?? internal!?, defaultValue))
					}
				}

				return @yep(AST.ObjectBindingElement(modifiers, external, internal, null, null, null, first ?? external ?? internal!?, internal ?? external ?? first!?))
			}

			if (!rest || ?internal) && dMode ~~ DestructuringMode.DEFAULT {
				if !rest && @test(Token.QUESTION) {
					var modifier = AST.Modifier(ModifierKind.Nullable, @yes())

					modifiers.push(modifier)

					return @yep(AST.ObjectBindingElement(modifiers, external, internal, null, null, null, first ?? external ?? internal!?, modifier))
				}
				else {
					var operator = @tryDefaultAssignmentOperator(true)

					if operator.ok {
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.ObjectBindingElement(modifiers, external, internal, null, operator, defaultValue, first ?? external ?? internal!?, defaultValue))
					}
				}
			}

			return @yep(AST.ObjectBindingElement(modifiers, external, internal, null, null, null, first ?? external ?? internal!?, internal ?? external ?? first!?))
		} # }}}

		reqDiscloseStatement(
			first: Event(Y)
		): Event<NodeData(DiscloseDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var members = []

			while @until(Token.RIGHT_CURLY) {
				@reqExternClassMemberList(members)
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.DiscloseDeclaration(name, members, first, @yes()))
		} # }}}

		reqDoStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(DoUntilStatement, DoWhileStatement)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var body = @reqBlock(NO, null, fMode)

			@reqNL_1M()

			if @match(Token.UNTIL, Token.WHILE) == Token.UNTIL {
				@commit()

				var condition = @reqExpression(.Nil, fMode)

				return @yep(AST.DoUntilStatement(condition, body, first, condition))
			}
			else if @token == Token.WHILE {
				@commit()

				var condition = @reqExpression(.Nil, fMode)

				return @yep(AST.DoWhileStatement(condition, body, first, condition))
			}
			else {
				@throw('until', 'while')
			}
		} # }}}

		reqEnumMember(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
		): Event<NodeData(EnumValue, FieldDeclaration, MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var member = @tryEnumMember(attributes, modifiers, bits, null)

			unless member.ok {
				@throw('Identifier')
			}

			return member
		} # }}}

		reqEnumMemberBlock(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			members: NodeData(EnumValue, FieldDeclaration, MethodDeclaration)[]
		): Void ~ SyntaxError # {{{
		{
			@commit().NL_0M()

			var mut attrs = [...attributes]

			bits += MemberBits.Attribute

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attrs) {
					continue
				}

				members.push(@reqEnumMember(attrs, modifiers, bits).value)
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			@commit().reqNL_1M()
		} # }}}

		reqEnumMemberList(
			members: NodeData(EnumValue, FieldDeclaration, MethodDeclaration)[]
		): Void ~ SyntaxError # {{{
		{
			var attributes = @stackOuterAttributes([])
			var modifiers = []

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier(.Closed)

			if accessModifier.ok && @test(Token.LEFT_CURLY) {
				return @reqEnumMemberBlock(
					attributes
					[accessModifier]
					MemberBits.Variable + MemberBits.Method
					members
				)
			}

			var first = accessModifier.ok ? accessModifier : null
			var staticMark = @mark()
			var staticModifier = @tryStaticModifier()

			if staticModifier.ok {
				if @test(Token.LEFT_CURLY) {
					return @reqEnumMemberBlock(
						attributes
						[
							accessModifier if accessModifier.ok
							staticModifier
						]
						MemberBits.Method
						members
					)
				}
				else {
					var member = @tryEnumMember(
						attributes
						[
							accessModifier if accessModifier.ok
							staticModifier
						]
						MemberBits.Method
						(first ?? staticModifier)!!
					)

					if member.ok {
						members.push(member.value)

						return
					}

					@rollback(staticMark)
				}
			}

			var constMark = @mark()
			var constModifier = @tryConstModifier()

			if constModifier.ok {
				if @test(Token.LEFT_CURLY) {
					return @reqEnumMemberBlock(
						attributes
						[
							accessModifier if accessModifier.ok
							constModifier
						]
						MemberBits.Variable
						members
					)
				}
				else {
					var member = @tryEnumMember(
						attributes
						[
							accessModifier if accessModifier.ok
							constModifier
						]
						MemberBits.Variable
						(first ?? constModifier)!!
					)

					if member.ok {
						members.push(member.value)

						return
					}

					@rollback(constMark)
				}
			}

			if accessModifier.ok {
				var member = @tryEnumMember(
					attributes
					[accessModifier]
					MemberBits.Method
					accessModifier
				)

				if member.ok {
					members.push(member.value)

					return
				}

				@rollback(accessMark)
			}

			members.push(@reqEnumMember(attributes, [], MemberBits.Value + MemberBits.Method).value)
		} # }}}

		reqEnumMethod(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			name: Event<NodeData(Identifier)>(Y)
			first: Range
		): Event<NodeData(MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var typeParameters = @tryTypeParameterList()
			var parameters = @reqClassMethodParameterList(null, null)
			var type = @tryFunctionReturns(.Method, true)
			var throws = @tryFunctionThrows()
			var body = @tryFunctionBody(modifiers, .Method, !?type && !?throws)

			@reqNL_1M()

			return @yep(AST.MethodDeclaration(attributes, modifiers, name, typeParameters, parameters, type, throws, body, first, (body ?? throws ?? type ?? parameters)!!))
		} # }}}

		reqEnumStatement(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[]? = []
		): Event<NodeData(EnumDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryEnumStatement(first, modifiers)

			if statement.ok {
				return statement
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqExportDeclarator(): Event<NodeData(DeclarationSpecifier, NamedSpecifier, PropertiesSpecifier)>(Y) ~ SyntaxError # {{{
		{
			match @matchM(M.EXPORT_STATEMENT) {
				Token.ABSTRACT {
					var first = @yes()

					if @test(.CLASS) {
						@commit()

						var modifiers = [@yep(AST.Modifier(.Abstract, first))]

						return @yep(AST.DeclarationSpecifier(@reqClassStatement(modifiers, first)))
					}
					else {
						@throw('class')
					}
				}
				Token.ASYNC {
					var first = @reqIdentifier()

					if @test(.FUNC) {
						@commit()

						var modifiers = [@yep(AST.Modifier(.Async, first))]

						return @yep(AST.DeclarationSpecifier(@reqFunctionStatement(modifiers, first)))
					}
					else {
						return @reqExportIdentifier(first)
					}
				}
				Token.BITMASK {
					return @yep(AST.DeclarationSpecifier(@reqBitmaskStatement(@yes())))
				}
				Token.CLASS {
					return @yep(AST.DeclarationSpecifier(@reqClassStatement(@yes())))
				}
				Token.ENUM {
					return @yep(AST.DeclarationSpecifier(@reqEnumStatement(@yes())))
				}
				Token.FINAL {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(.Final, first))]

					if @test(.CLASS) {
						@commit()

						return @yep(AST.DeclarationSpecifier(@reqClassStatement(modifiers, first)))
					}
					else if @test(.ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(.Abstract, @yes())))

						if @test(Token.CLASS) {
							@commit()

							return @yep(AST.DeclarationSpecifier(@reqClassStatement(modifiers, first)))
						}
						else {
							@throw('class')
						}
					}
					else {
						@throw('class')
					}
				}
				Token.FUNC {
					return @yep(AST.DeclarationSpecifier(@reqFunctionStatement(@yes())))
				}
				Token.IDENTIFIER {
					return @reqExportIdentifier(@reqIdentifier())
				}
				Token.MACRO {
					if @mode !~ .MacroExpression {
						var expression = @tryMacroStatement(@yes())

						if expression.ok {
							return @yep(AST.DeclarationSpecifier(expression))
						}
						else {
							@throw('macro')
						}
					}
					else {
						return @yep(AST.DeclarationSpecifier(@reqMacroExpression(@yes())))
					}
				}
				Token.NAMESPACE {
					var first = @yes()
					var identifier = @reqIdentifier()

					return @yep(AST.DeclarationSpecifier(@reqNamespaceStatement(first, identifier)))
				}
				Token.SEALED {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(.Sealed, first))]

					if @test(.CLASS) {
						@commit()

						return @yep(AST.DeclarationSpecifier(@reqClassStatement(modifiers, first)))
					}
					else if @test(.ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(.Abstract, @yes())))

						if @test(Token.CLASS) {
							@commit()

							return @yep(AST.DeclarationSpecifier(@reqClassStatement(modifiers, first)))
						}
						else {
							@throw('class')
						}
					}
					else {
						@throw('class')
					}
				}
				Token.STRUCT {
					return @yep(AST.DeclarationSpecifier(@reqStructStatement(@yes())))
				}
				Token.TUPLE {
					return @yep(AST.DeclarationSpecifier(@reqTupleStatement(@yes())))
				}
				Token.TYPE {
					return @yep(AST.DeclarationSpecifier(@reqTypeStatement(@yes(), @reqIdentifier())))
				}
				Token.VAR {
					return @yep(AST.DeclarationSpecifier(@reqVarStatement(@yes(), .NoAwait, .Nil)))
				}
				else {
					@throw()
				}
			}
		} # }}}

		reqExportIdentifier(
			identifier: Event<NodeData(Identifier)>(Y)
		): Event<NodeData(NamedSpecifier, PropertiesSpecifier)>(Y) ~ SyntaxError # {{{
		{
			var mut value: Event<NodeData(Identifier, MemberExpression)>(Y) = identifier
			var mut external: Event<NodeData(Identifier)>(Y)? = null

			if @testNS(Token.DOT) {
				do {
					@commit()

					if @testNS(Token.ASTERISK) {
						var modifier = @yep(AST.Modifier(ModifierKind.Wildcard, @yes()))

						return @yep(AST.NamedSpecifier([modifier], value, null, value, modifier))
					}
					else {
						external = @reqIdentifier()

						value = @yep(AST.MemberExpression([], value, external))
					}
				}
				while @testNS(Token.DOT)
			}

			if @test(Token.EQUALS_RIGHT_ANGLE) {
				@commit()

				var external = @reqIdentifier()

				return @yep(AST.NamedSpecifier([], value, external, value, external))
			}
			else if @test(Token.FOR) {
				@commit()

				if @test(Token.ASTERISK) {
					var modifier = @yep(AST.Modifier(ModifierKind.Wildcard, @yes()))

					return @yep(AST.NamedSpecifier([modifier], value, null, value, modifier))
				}
				else if @test(Token.LEFT_CURLY) {
					var members = []

					@commit().NL_0M()

					until @test(Token.RIGHT_CURLY) {
						var identifier = @reqIdentifier()

						if @test(Token.EQUALS_RIGHT_ANGLE) {
							@commit()

							var external = @reqIdentifier()

							members.push(@yep(AST.NamedSpecifier([], identifier, external, identifier, external)))
						}
						else {
							members.push(@yep(AST.NamedSpecifier([], identifier, null, identifier, identifier)))
						}

						if @test(Token.COMMA) {
							@commit()
						}

						@reqNL_1M()
					}

					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.PropertiesSpecifier([], value, members, value, @yes()))
				}
				else {
					var members = []

					var identifier = @reqIdentifier()

					if @test(Token.EQUALS_RIGHT_ANGLE) {
						@commit()

						var external = @reqIdentifier()

						members.push(@yep(AST.NamedSpecifier([], identifier, external, identifier, external)))
					}
					else {
						members.push(@yep(AST.NamedSpecifier([], identifier, null, identifier, identifier)))
					}

					while @test(Token.COMMA) {
						@commit()

						var identifier = @reqIdentifier()

						if @test(Token.EQUALS_RIGHT_ANGLE) {
							@commit()

							var external = @reqIdentifier()

							members.push(@yep(AST.NamedSpecifier([], identifier, external, identifier, external)))
						}
						else {
							members.push(@yep(AST.NamedSpecifier([], identifier, null, identifier, identifier)))
						}
					}

					var last = members[members.length - 1]

					return @yep(AST.PropertiesSpecifier([], value, members, value, last))
				}
			}
			else {
				return @yep(AST.NamedSpecifier([], value, external, value, value))
			}
		} # }}}

		reqExportModule(
			first: Event(Y)
		): Event<NodeData(ExportDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var mut last = first
			var declarations = []

			if @match(Token.EQUALS, Token.IDENTIFIER, Token.LEFT_CURLY) == Token.EQUALS {
				var modifier = @yep(AST.Modifier(.Default, @yes()))
				var identifier = @reqIdentifier()

				declarations.push(@yep(AST.NamedSpecifier([modifier], identifier, null, first, identifier)))
			}
			else if @token == Token.IDENTIFIER {
				var internal = @reqIdentifier()
				var mut external = internal

				if @test(Token.EQUALS_RIGHT_ANGLE) {
					@commit()

					external = @reqIdentifier()
				}

				declarations.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))

				while @until(Token.COMMA) {
					@commit()

					var internal = @reqIdentifier()
					var mut external = internal

					if @test(Token.EQUALS_RIGHT_ANGLE) {
						@commit()

						external = @reqIdentifier()
					}

					declarations.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))
				}

				last = declarations[declarations.length - 1]
			}
			else if @token == Token.LEFT_CURLY {
				@commit()

				while @until(Token.RIGHT_CURLY) {
					@commit()

					var internal = @reqIdentifier()
					var mut external = internal

					if @test(Token.EQUALS_RIGHT_ANGLE) {
						@commit()

						external = @reqIdentifier()
					}

					declarations.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))
				}

				@throw('}') unless @test(Token.RIGHT_CURLY)

				last = @yes()
			}
			else {
				@throw('Identifier', '{', '=')
			}

			return @yep(AST.ExportDeclaration([], declarations, first, last))
		} # }}}

		reqExportStatement(
			first: Event(Y)
		): Event<NodeData(ExportDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []

			var dyn last
			if @match(Token.ASTERISK, Token.LEFT_CURLY) == Token.ASTERISK {
				var first = @yes()

				if @test(Token.BUT) {
					var modifier = @yep(AST.Modifier(ModifierKind.Exclusion, @yes()))
					var elements = []

					if @test(Token.LEFT_CURLY) {
						@commit().NL_0M()

						until @test(Token.RIGHT_CURLY) {
							elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))

							@reqNL_1M()
						}

						@throw('}') unless @test(Token.RIGHT_CURLY)

						last = @yes()
					}
					else {
						elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))

						while @test(Token.COMMA) {
							@commit()

							elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))
						}

						last = elements[elements.length - 1]
					}

					declarations.push(@yep(AST.GroupSpecifier([modifier], elements, null, modifier, last)))
				}
				else {
					var modifier = @yep(AST.Modifier(ModifierKind.Wildcard, first))

					declarations.push(@yep(AST.GroupSpecifier([modifier], [], null, modifier, modifier)))

					last = modifier
				}
			}
			else if @token == Token.LEFT_CURLY {
				@commit().NL_0M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqExportDeclarator()

					if attrs.length > 0 {
						if declarator.value is not .DeclarationSpecifier {
							@throw()
						}

						AST.pushAttributes(declarator.value.declaration, attrs)

						declarator.value.start = declarator.value.declaration.start
					}

					declarations.push(declarator)

					@reqNL_1M()
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(@reqExportDeclarator())

				while @test(Token.COMMA) {
					@commit()

					declarations.push(@reqExportDeclarator())
				}

				last = declarations[declarations.length - 1]
			}

			@reqNL_EOF_1M()

			return @yep(AST.ExportDeclaration(attributes, declarations, first, last))
		} # }}}

		reqExpression(
			eMode: ExpressionMode?
			fMode: FunctionMode
			terminator: MacroTerminator? = null
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var expression = @tryExpression(eMode, fMode, terminator)

			if expression.ok {
				return expression
			}
			else {
				@throw(...?expression.expecteds)
			}
		} # }}}

		reqExpressionStatement(
			eMode: ExpressionMode = .Nil + .NoRestriction
			fMode: FunctionMode
		): Event<NodeData(ExpressionStatement, IfStatement, UnlessStatement, ForStatement, RepeatStatement)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(eMode, fMode)

			if @match(Token.FOR, Token.IF, Token.REPEAT, Token.UNLESS) == Token.FOR {
				var first = @yes()
				var iteration = @reqIteration(fMode)

				return @yep(AST.ForStatement([iteration], @yep(AST.ExpressionStatement(expression)), null, first, expression))
			}
			else if @token == Token.IF {
				@commit()

				var condition = @reqExpression(eMode, fMode)

				return @yep(AST.IfStatement(condition, @yep(AST.ExpressionStatement(expression)), null, expression, condition))
			}
			else if @token == Token.REPEAT {
				@commit().NL_0M()

				var condition = @reqExpression(eMode, fMode)
				var block =  @yep(AST.ExpressionStatement(expression))

				unless @test(Token.TIMES) {
					@throw('times')
				}

				return @yep(AST.RepeatStatement(condition, block, block, @yes()))
			}
			else if @token == Token.UNLESS {
				@commit()

				var condition = @reqExpression(eMode, fMode)

				return @yep(AST.UnlessStatement(condition, @yep(AST.ExpressionStatement(expression)), expression, condition))
			}
			else {
				return @yep(AST.ExpressionStatement(expression))
			}
		} # }}}

		reqExternClassDeclaration(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[] = []
		): Event<NodeData(ClassDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()

			var dyn generic
			if @test(Token.LEFT_ANGLE) {
				generic = @reqTypeGeneric(@yes())
			}

			var dyn extends
			if @test(Token.EXTENDS) {
				@commit()

				extends = @reqIdentifier()
			}

			var implements = []
			if @test(Token.IMPLEMENTS) {
				@commit()

				implements.push(@reqIdentifierOrMember())

				while @test(Token.COMMA) {
					@commit()

					implements.push(@reqIdentifierOrMember())
				}
			}

			if @test(Token.LEFT_CURLY) {
				@commit().NL_0M()

				var attributes = []
				var members = []

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@reqExternClassMemberList(members)
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				return @yep(AST.ClassDeclaration(attributes, name, null, extends, implements, modifiers, members, first, @yes()))
			}
			else {
				return @yep(AST.ClassDeclaration([], name, null, extends, implements, modifiers, [], first, extends ?? generic ?? name))
			}
		} # }}}

		reqExternClassField(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			type: Event<NodeData(Type)>(Y)?
			first: Event(Y)
		): Event<NodeData(FieldDeclaration)>(Y) ~ SyntaxError # {{{
		{
			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, null, first, (type ?? name)!!))
		} # }}}

		reqExternClassMember(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)?
		): Event<NodeData(FieldDeclaration, MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()

			if @match(Token.COLON, Token.LEFT_CURLY, Token.LEFT_ROUND) == Token.COLON {
				@commit()

				var type = @reqType()

				if @test(Token.LEFT_CURLY) {
					@throw()
				}
				else {
					return @reqExternClassField(attributes, modifiers, name, type, first ?? name)
				}
			}
			else if @token == Token.LEFT_CURLY {
				@throw()
			}
			else if @token == Token.LEFT_ROUND {
				return @reqExternClassMethod(attributes, modifiers, name, @yes(), first ?? name)
			}
			else {
				return @reqExternClassField(attributes, modifiers, name, null, first ?? name)
			}
		} # }}}

		reqExternClassMemberList(
			members: Event<NodeData(ClassMember)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var dyn first = null

			var attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			var modifiers = @reqAccessModifiers([])

			if @test(Token.ABSTRACT) {
				modifiers.push(@yep(AST.Modifier(ModifierKind.Abstract, @yes())))

				first = modifiers[0]

				if @test(Token.LEFT_CURLY) {
					@commit().NL_0M()

					first = null

					var dyn attrs
					while @until(Token.RIGHT_CURLY) {
						attrs = @stackOuterAttributes([])

						if attrs.length != 0 {
							first = attrs[0]
							attrs.unshift(...attributes)
						}
						else {
							attrs = attributes
						}

						members.push(@reqClassMember(
							attrs
							modifiers
							MemberBits.Method + MemberBits.NoBody
							first
						))
					}

					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					@commit().reqNL_1M()
				}
				else {
					members.push(@reqClassMember(
						attributes
						modifiers
						MemberBits.Method + MemberBits.NoBody
						first
					))
				}
			}
			else {
				if @test(Token.STATIC) {
					modifiers.push(@yep(AST.Modifier(ModifierKind.Static, @yes())))
				}
				if first == null && modifiers.length != 0 {
					first = modifiers[0]
				}

				if modifiers.length != 0 && @test(Token.LEFT_CURLY) {
					@commit().NL_0M()

					first = null

					var dyn attrs
					while @until(Token.RIGHT_CURLY) {
						attrs = @stackOuterAttributes([])

						if attrs.length != 0 {
							first = attrs[0]
							attrs.unshift(...attributes)
						}
						else {
							attrs = attributes
						}

						members.push(@reqExternClassMember(attrs, modifiers, first))
					}

					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					@commit().reqNL_1M()
				}
				else {
					members.push(@reqExternClassMember(attributes, modifiers, first))
				}
			}
		} # }}}

		reqExternClassMethod(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			round: Event
			first: Event(Y)
		): Event<NodeData(MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var typeParameters = @tryTypeParameterList()
			var parameters = @reqClassMethodParameterList(round, DestructuringMode.EXTERNAL_ONLY)
			var type = @tryFunctionReturns(.Method, false)

			@reqNL_1M()

			return @yep(AST.MethodDeclaration(attributes, modifiers, name, typeParameters, parameters, type, null, null, first, (type ?? parameters)!!))
		} # }}}

		reqExternFunctionDeclaration(
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)
		): Event<NodeData(FunctionDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()
			var typeParameters = @tryTypeParameterList()

			if @test(Token.LEFT_ROUND) {
				var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionDeclaration(name, typeParameters, parameters, modifiers, type, throws, null, first, (throws ?? type ?? parameters)!!))
			}
			else {
				var position = @yep()
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionDeclaration(name, typeParameters, null, modifiers, type, throws, null, first, (throws ?? type ?? name)!!))
			}
		} # }}}

		reqExternNamespaceDeclaration(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[] = []
		): Event<NodeData(NamespaceDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()

			if @test(Token.LEFT_CURLY) {
				@commit().NL_0M()

				var attributes = []
				var statements = []

				var dyn attrs = []
				var dyn statement

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					statement = @reqTypeDescriptive()

					@reqNL_1M()

					AST.pushAttributes(statement.value, attrs)

					statements.push(statement)
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				return @yep(AST.NamespaceDeclaration(attributes, modifiers, name, statements, first, @yes()))
			}
			else {
				return @yep(AST.NamespaceDeclaration([], modifiers, name, [], first, name))
			}
		} # }}}

		reqExternOrImportStatement(
			first: Event(Y)
		): Event<NodeData(ExternOrImportDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token.LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqImportDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token.NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(last <- @reqImportDeclarator())
			}

			@reqNL_EOF_1M()

			return @yep(AST.ExternOrImportDeclaration(attributes, declarations, first, last))
		} # }}}

		reqExternOrRequireStatement(
			first: Event(Y)
		): Event<NodeData(ExternOrRequireDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.ExternOrRequireDeclaration(attributes, declarations, first, last))
		} # }}}

		reqExternStatement(
			first: Event(Y)
		): Event<NodeData(ExternDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.ExternDeclaration(attributes, declarations, first, last))
		} # }}}

		reqExternVariableDeclarator(
			name: Event<NodeData(Identifier)>(Y)
		): Event<NodeData(VariableDeclarator, FunctionDeclaration)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.COLON, Token.LEFT_ROUND) == Token.COLON {
				@commit()

				var type = @reqType()

				return @yep(AST.VariableDeclarator([], name, type, name, type))
			}
			else if @token == Token.LEFT_ROUND {
				var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)

				return @yep(AST.FunctionDeclaration(name, null, parameters, [], type, null, null, name, (type ?? parameters)!!))
			}
			else {
				return @yep(AST.VariableDeclarator([], name, null, name, name))
			}
		} # }}}

		reqExternalDeclarations(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(DescriptiveType)>(Y)[]
		): Event(Y) ~ SyntaxError # {{{
		{
			var late last: Event(Y)

			if @test(Token.LEFT_CURLY) {
				@commit().NL_0M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqTypeDescriptive()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					@reqNL_1M()
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				var mark = @mark()

				var identifier = @tryIdentifier()
				if identifier.ok {
					if @test(Token.COMMA) {
						declarations.push(@yep(AST.VariableDeclarator([], identifier, null, identifier, identifier)))

						while @test(Token.COMMA) {
							@commit()

							var identifier = @reqIdentifier()

							if @test(Token.COLON) {
								@commit()

								var type = @reqTypeEntity()

								declarations.push(@yep(AST.VariableDeclarator([], identifier, type, identifier, type)))
							}
							else {
								declarations.push(@yep(AST.VariableDeclarator([], identifier, null, identifier, identifier)))
							}
						}
					}
					else if @test(Token.NEWLINE) {
						declarations.push(@yep(AST.VariableDeclarator([], identifier, null, identifier, identifier)))
					}
					else if @test(Token.COLON) {
						@commit()

						var type = @tryTypeEntity()

						if type.ok {
							declarations.push(@yep(AST.VariableDeclarator([], identifier, type, identifier, type)))

							while @test(Token.COMMA) {
								@commit()

								var identifier = @reqIdentifier()

								if @test(Token.COLON) {
									@commit()

									var type = @reqTypeEntity()

									declarations.push(@yep(AST.VariableDeclarator([], identifier, type, identifier, type)))
								}
								else {
									declarations.push(@yep(AST.VariableDeclarator([], identifier, null, identifier, identifier)))
								}
							}
						}
						else {
							@rollback(mark)

							declarations.push(@reqTypeDescriptive())
						}
					}
					else {
						@rollback(mark)

						declarations.push(@reqTypeDescriptive())
					}
				}
				else {
					declarations.push(@reqTypeDescriptive())
				}

				last = declarations[declarations.length - 1]
			}

			@reqNL_EOF_1M()

			return last
		} # }}}

		reqFallthroughStatement(
			first: Event(Y)
		): Event<NodeData(FallthroughStatement)>(Y) { # {{{
			return @yep(AST.FallthroughStatement(first))
		} # }}}

		reqForStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(ForStatement)>(Y) ~ SyntaxError # {{{
		{
			var iterations = []

			var mut mark = @mark()

			@NL_0M()

			if @test(.LEFT_CURLY) {
				@commit().NL_0M()

				if @test(.VAR) {
					while @test(.VAR) {
						iterations.push(@reqIteration(fMode))

						@NL_0M()
					}

					unless @test(.RIGHT_CURLY) {
						@throw('}')
					}

					@commit().NL_0M()

					unless @test(.THEN) {
						@throw('then')
					}

					@commit().NL_0M()
				}
				else {
					@rollback(mark)

					iterations.push(@reqIteration(fMode))
				}
			}
			else {
				@rollback(mark)

				iterations.push(@reqIteration(fMode))
			}

			@NL_0M()

			var body = @reqBlock(NO, null, fMode)

			var mut else = null

			mark = @mark()

			@commit().NL_0M()

			if @test(Token.ELSE) {
				@commit().NL_0M()

				else = @reqBlock(NO, null, fMode)
			}
			else {
				@rollback(mark)
			}

			return @yep(AST.ForStatement(iterations, body, else, first, else ?? body))
		} # }}}

		reqFunctionBody(
			modifiers: Event<ModifierData>(Y)[]
			fMode: FunctionMode
			automatable: Boolean
		): Event<NodeData(Block, Expression, IfStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			match automatable ? @match(.LEFT_CURLY, .EQUALS_RIGHT_ANGLE, .COLON_RIGHT_ANGLE) : @match(.LEFT_CURLY, .EQUALS_RIGHT_ANGLE) {
				.LEFT_CURLY {
					return @reqBlock(@yes(), null, fMode - FunctionMode.NoPipeline)
				}
				.EQUALS_RIGHT_ANGLE {
					@commit().NL_0M()

					var expression = @reqExpression(.NoRestriction, fMode)

					if @match(Token.IF, Token.UNLESS) == Token.IF {
						@commit()

						var condition = @reqExpression(.NoRestriction, fMode)

						return @yep(AST.IfStatement(condition, @yep(AST.ReturnStatement(expression, expression, expression)), null, expression, condition))
					}
					else if @token == Token.UNLESS {
						@commit()

						var condition = @reqExpression(.NoRestriction, fMode)

						return @yep(AST.UnlessStatement(condition, @yep(AST.ReturnStatement(expression, expression, expression)), expression, condition))
					}
					else {
						return expression
					}
				}
				.COLON_RIGHT_ANGLE {
					modifiers.push(@yep(AST.Modifier(.AutoType, @yes())))

					@NL_0M()

					return @reqExpression(.NoRestriction, fMode)
				}
				else {
					@throw('{', '=>')
				}
			}
		} # }}}

		reqFunctionParameterList(
			fMode: FunctionMode
			mut pMode: DestructuringMode = DestructuringMode.Nil
			maxParameters: Number = Infinity
		): Event<Event<NodeData(Parameter)>(Y)[]>(Y) ~ SyntaxError # {{{
		{
			unless @test(Token.LEFT_ROUND) {
				@throw('(')
			}

			var first = @yes()

			@NL_0M()

			var parameters = []

			pMode += DestructuringMode.Parameter

			while @until(Token.RIGHT_ROUND) {
				if parameters.length == maxParameters {
					@throw(')')
				}

				parameters.push(@reqParameter(pMode, fMode))

				@reqSeparator(Token.RIGHT_ROUND)
			}

			unless @test(Token.RIGHT_ROUND) {
				@throw(')')
			}

			return @yep(parameters, first, @yes())
		} # }}}

		reqFunctionStatement(
			modifiers: Event<ModifierData>(Y)[] = []
			first: Event(Y)
			fMode: FunctionMode = .Nil
		): Event<NodeData(FunctionDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()
			var typeParameters = @tryTypeParameterList()
			var parameters = @reqFunctionParameterList(.Nil)
			var type = @tryFunctionReturns()
			var throws = @tryFunctionThrows()
			var body = @reqFunctionBody(modifiers, .Nil, !?type && !?throws)

			return @yep(AST.FunctionDeclaration(name, typeParameters, parameters, modifiers, type, throws, body, first, body))
		} # }}}

		reqGeneric(): Event<NodeData(Identifier)>(Y) ~ SyntaxError # {{{
		{
			return @reqIdentifier()
		} # }}}

		reqIdentifier(): Event<NodeData(Identifier)>(Y) ~ SyntaxError # {{{
		{
			if @scanner.test(Token.IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqIdentifierOrMember(): Event<NodeData(Identifier, MemberExpression)>(Y) ~ SyntaxError # {{{
		{
			var mut name: Event<NodeData(Identifier, MemberExpression)>(Y) = @reqIdentifier()

			if @testNS(Token.DOT) {
				do {
					@commit()

					var property = @reqIdentifier()

					name = @yep(AST.MemberExpression([], name, property))
				}
				while @testNS(Token.DOT)
			}

			return name
		} # }}}

		reqIfStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(IfStatement)>(Y) ~ SyntaxError # {{{
		{
			var mut condition: Event? = null
			var declarations = []

			if @test(.VAR) {
				var mark = @mark()
				var first = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, first))]

				if @test(.MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind.Mutable, @yes())))
				}

				if @test(.IDENTIFIER, .LEFT_CURLY, .LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					var declaration = if @test(.COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(.COMMA)

						var operator = @reqConditionAssignment()

						unless @test(.AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(.Nil, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						set AST.VariableDeclaration([], modifiers, variables, operator, expression, first, expression)
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(.ImplicitMember, fMode)

						set AST.VariableDeclaration([], modifiers, [variable], operator, expression, first, expression)
					}

					@NL_0M()

					if @test(.SEMICOLON_SEMICOLON) {
						@commit().NL_0M()

						var condition = @reqExpression(.NoAnonymousFunction, fMode).value

						declarations.push([ declaration, condition ])
					}
					else {
						declarations.push([ declaration ])
					}
				}
				else {
					@rollback(mark)

					condition = @reqExpression(.NoAnonymousFunction, fMode)
				}
			}
			else {
				var mark = @mark()

				@NL_0M()

				if @test(.LEFT_CURLY) {
					@commit().NL_0M()

					if @test(.VAR) {
						while @test(.VAR) {
							var first = @yes()
							var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, first))]

							if @test(.MUT) {
								modifiers.push(@yep(AST.Modifier(ModifierKind.Mutable, @yes())))
							}

							unless @test(.IDENTIFIER, .LEFT_CURLY, .LEFT_SQUARE) {
								@throw('Identifier', '{', '[')
							}

							var variable = @reqTypedVariable(fMode)

							var declaration = if @test(.COMMA) {
								var variables = [variable]

								do {
									@commit()

									variables.push(@reqTypedVariable(fMode))
								}
								while @test(.COMMA)

								var operator = @reqConditionAssignment()

								unless @test(.AWAIT) {
									@throw('await')
								}

								@commit()

								var operand = @reqPrefixedOperand(.Nil, fMode)
								var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

								set AST.VariableDeclaration([], modifiers, variables, operator, expression, first, expression)
							}
							else {
								var operator = @reqConditionAssignment()
								var expression = @reqExpression(.ImplicitMember, fMode)

								set AST.VariableDeclaration([], modifiers, [variable], operator, expression, first, expression)
							}

							@NL_0M()

							if @test(.SEMICOLON_SEMICOLON) {
								@commit().NL_0M()

								var condition = @reqExpression(.NoAnonymousFunction, fMode).value

								@NL_0M()

								declarations.push([ declaration, condition ])
							}
							else {
								declarations.push([ declaration ])
							}
						}

						unless @test(.RIGHT_CURLY) {
							@throw('}')
						}

						@commit().NL_0M()

						unless @test(.THEN) {
							@throw('then')
						}

						@commit().NL_0M()
					}
					else {
						@rollback(mark)
					}
				}

				if !?#declarations {
					condition = @reqExpression(ExpressionMode.NoAnonymousFunction, fMode)
				}
			}

			@NL_0M()

			var whenTrue = @reqBlock(NO, null, fMode)

			if @test(Token.NEWLINE) {
				var mark = @mark()

				@commit().NL_0M()

				if @match(Token.ELSE_IF, Token.ELSE) == Token.ELSE_IF {
					var position = @yes()

					position.start.column += 5

					var whenFalse = @reqIfStatement(position, fMode)

					return @yep(AST.IfStatement(condition ?? declarations, whenTrue, whenFalse, first, whenFalse))
				}
				else if @token == Token.ELSE {
					@commit().NL_0M()

					var whenFalse = @reqBlock(NO, null, fMode)

					return @yep(AST.IfStatement(condition ?? declarations, whenTrue, whenFalse, first, whenFalse))
				}
				else {
					@rollback(mark)

					return @yep(AST.IfStatement(condition ?? declarations, whenTrue, null, first, whenTrue))
				}
			}
			else {
				return @yep(AST.IfStatement(condition ?? declarations, whenTrue, null, first, whenTrue))
			}
		} # }}}

		reqImplementMemberList(
			members: Event<NodeData(ClassMember)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var dyn first = null

			var attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier(.Opened)

			if accessModifier.ok && @test(Token.LEFT_CURLY) {
				return @reqClassMemberBlock(
					attributes
					[accessModifier]
					MemberBits.Variable + MemberBits.FinalVariable + MemberBits.LateVariable + MemberBits.Property + MemberBits.Method
					members
				)
			}

			if @test(.ASSIST) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(.Assist, @yes()))
				var modifiers = [modifier]
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(.LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						MemberBits.Method
						members
					)
				}

				var member = @tryClassMember(
					attributes
					modifiers
					MemberBits.Method
					first ?? modifiers[0]
				)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(mark)
			}
			else if @test(.OVERRIDE, .OVERWRITE) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(@token == Token.OVERRIDE ? ModifierKind.Override : ModifierKind.Overwrite, @yes()))
				var modifiers = [modifier]
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(Token.LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						MemberBits.Method + MemberBits.Property
						members
					)
				}

				var member = @tryClassMember(
					attributes
					modifiers
					MemberBits.Method + MemberBits.Property
					first ?? modifiers[0]
				)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(mark)
			}

			var staticMark = @mark()
			var dyn staticModifier = NO

			if @test(Token.STATIC) {
				staticModifier = @yep(AST.Modifier(ModifierKind.Static, @yes()))

				if @test(Token.LEFT_CURLY) {
					var modifiers = [staticModifier]
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					return @reqClassMemberBlock(
						attributes
						modifiers
						MemberBits.Variable + MemberBits.FinalVariable + MemberBits.LateVariable + MemberBits.Property + MemberBits.Method + MemberBits.FinalMethod
						members
					)
				}
			}

			var finalMark = @mark()
			var dyn finalModifier = NO

			if @test(.FINAL) {
				finalModifier = @yep(AST.Modifier(.Final, @yes()))

				if @test(.LEFT_CURLY) {
					var modifiers = [finalModifier]
					if staticModifier.ok {
						modifiers.unshift(staticModifier)
					}
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					if staticModifier.ok {
						return @reqClassMemberBlock(
							attributes
							modifiers
							MemberBits.Variable + MemberBits.LateVariable + MemberBits.RequiredAssignment + MemberBits.Property + MemberBits.Method
							members
						)
					}
					else {
						return @reqClassMemberBlock(
							attributes
							modifiers
							MemberBits.Variable + MemberBits.LateVariable + MemberBits.RequiredAssignment +
							MemberBits.Property + MemberBits.OverrideProperty + MemberBits.OverwriteProperty +
							MemberBits.Method + MemberBits.AssistMethod + MemberBits.OverrideMethod + MemberBits.OverwriteMethod
							members
						)
					}
				}
				else if !staticModifier.ok {
					if @test(.ASSIST) {
						var mark = @mark()
						var modifier = @yep(AST.Modifier(.Assist, @yes()))

						if @test(.LEFT_CURLY) {
							var modifiers = [finalModifier, modifier]
							if accessModifier.ok {
								modifiers.unshift(accessModifier)
							}

							return @reqClassMemberBlock(
								attributes
								modifiers
								MemberBits.Method
								members
							)
						}

						@rollback(mark)
					}
					else if @test(Token.OVERRIDE, Token.OVERWRITE) {
						var mark = @mark()
						var modifier = @yep(AST.Modifier(@token == Token.OVERRIDE ? ModifierKind.Override : ModifierKind.Overwrite, @yes()))

						if @test(Token.LEFT_CURLY) {
							var modifiers = [finalModifier, modifier]
							if accessModifier.ok {
								modifiers.unshift(accessModifier)
							}

							return @reqClassMemberBlock(
								attributes
								modifiers
								MemberBits.Method + MemberBits.Property
								members
							)
						}

						@rollback(mark)
					}
				}
			}

			if @test(Token.LATE) {
				var lateMark = @mark()
				var lateModifier = @yep(AST.Modifier(ModifierKind.LateInit, @yes()))

				var modifiers = [lateModifier]
				if finalModifier.ok {
					modifiers.unshift(finalModifier)
				}
				if staticModifier.ok {
					modifiers.unshift(staticModifier)
				}
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(Token.LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						finalModifier.ok ? MemberBits.Variable : MemberBits.Variable + MemberBits.FinalVariable
						members
					)
				}

				var member = @tryClassMember(
					attributes
					modifiers
					MemberBits.Variable + MemberBits.NoAssignment
					first ?? modifiers[0]
				)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(lateMark)
			}

			if accessModifier.ok {
				var member = @tryClassMember(attributes, [accessModifier], staticModifier, staticMark, finalModifier, finalMark, first ?? accessModifier)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(accessMark)
			}

			var member = @tryClassMember(attributes, [], staticModifier, staticMark, finalModifier, finalMark, first)

			unless member.ok {
				@throw('Identifier', 'String', 'Template')
			}

			members.push(member)
		} # }}}

		reqImplementStatement(
			first: Event(Y)
		): Event<NodeData(ImplementDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var late interface: Event?
			var late variable: Event

			var identifier = @reqIdentifierOrMember()

			if @test(Token.FOR) {
				@commit()

				interface = identifier
				variable = @reqIdentifierOrMember()
			}
			else {
				interface = null
				variable = identifier
			}

			if @test(Token.LEFT_ANGLE) {
				@reqTypeGeneric(@yes())
			}

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var attributes = []
			var members = []

			until @test(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@reqImplementMemberList(members)
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.ImplementDeclaration(attributes, variable, interface, members, first, @yes()))
		} # }}}

		reqImportDeclarator(): Event<NodeData(ImportDeclarator)>(Y) ~ SyntaxError # {{{
		{
			var source = @reqString()
			var modifiers = []
			var dyn arguments = null
			var mut last: Event(Y) = source

			if @test(Token.LEFT_ROUND) {
				@commit()

				arguments = []

				if @test(Token.DOT_DOT_DOT) {
					modifiers.push(AST.Modifier(ModifierKind.Autofill, @yes()))

					if @test(Token.COMMA) {
						@commit()
					}
				}

				while @until(Token.RIGHT_ROUND) {
					var dyn name = @reqExpression(.Nil, .Nil)
					var modifiers = []

					if name.value is .Identifier {
						if name.value.name == 'require' && !@test(Token.COLON, Token.COMMA, Token.RIGHT_ROUND) {
							var first = name

							modifiers.push(@yep(AST.Modifier(ModifierKind.Required, name)))

							name = @reqIdentifier()

							if @test(Token.COLON) {
								@commit()

								var value = @reqIdentifier()

								arguments.push(AST.NamedArgument(modifiers, name, value, first, value))
							}
							else {
								arguments.push(AST.PositionalArgument(modifiers, name, first, name))
							}
						}
						else {
							if @test(Token.COLON) {
								@commit()

								var value = @reqExpression(.Nil, .Nil)

								arguments.push(AST.NamedArgument(modifiers, name!!, value, name, value))
							}
							else {
								arguments.push(AST.PositionalArgument(modifiers, name, name, name))
							}
						}
					}
					else {
						arguments.push(AST.PositionalArgument(modifiers, name, name, name))
					}

					if @test(Token.COMMA) {
						@commit()
					}
					else {
						break
					}
				}

				unless @test(Token.RIGHT_ROUND) {
					@throw(')')
				}

				@commit()
			}

			var attributes = []
			var mut type = null
			var specifiers = []

			match @match(Token.BUT, Token.EQUALS_RIGHT_ANGLE, Token.FOR, Token.LEFT_CURLY) {
				.BUT {
					var modifier = @yep(AST.Modifier(ModifierKind.Exclusion, @yes()))
					var elements = []

					if @test(Token.LEFT_CURLY) {
						@commit().NL_0M()

						until @test(Token.RIGHT_CURLY) {
							elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))

							@reqNL_1M()
						}

						unless @test(Token.RIGHT_CURLY) {
							@throw('}')
						}

						last = @yes()
					}
					else {
						elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))

						while @test(Token.COMMA) {
							@commit()

							elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))
						}

						last = elements[elements.length - 1]
					}

					specifiers.push(@yep(AST.GroupSpecifier([modifier], elements, null, modifier, last)))

					last = specifiers[specifiers.length - 1]
				}
				.EQUALS_RIGHT_ANGLE {
					var modifier = @yep(AST.Modifier(ModifierKind.Alias, @yes()))
					type = @tryTypeDescriptive(TypeMode.Module + TypeMode.NoIdentifier)

					if type.ok {
						// TODO!
						var value = type.value as Any

						if ?value.name {
							specifiers.push(@yep(AST.NamedSpecifier([modifier], @yep(value.name), null, modifier, type)))

							last = type
						}
						else {
							@throw()
						}
					}
					else {
						type = null

						var elements = []
						var identifier = @reqIdentifier()

						elements.push(@yep(AST.NamedSpecifier(identifier)))

						if @test(Token.COMMA) {
							@commit()

							var element = @reqDestructuring(DestructuringMode.Nil, FunctionMode.Nil)

							elements.push(@yep(AST.NamedSpecifier(element)))
						}

						last = elements[elements.length - 1]

						specifiers.push(@yep(AST.GroupSpecifier([modifier], elements, null, modifier, last)))
					}
				}
				.FOR {
					var first = @yes()
					var elements = []

					if @test(Token.LEFT_CURLY) {
						@commit().NL_0M()

						while @until(Token.RIGHT_CURLY) {
							var type = @tryTypeDescriptive(TypeMode.Module + TypeMode.NoIdentifier)

							if type.ok {
								if @test(Token.EQUALS_RIGHT_ANGLE) {
									@commit()

									@submitNamedGroupSpecifier([], type, elements)
								}
								else {
									elements.push(@yep(AST.TypedSpecifier(type, type)))
								}
							}
							else {
								@submitNamedSpecifier([], elements)
							}

							@reqNL_1M()
						}

						@throw('}') unless @test(Token.RIGHT_CURLY)

						@commit()
					}
					else {
						var type = @tryTypeDescriptive(TypeMode.Module + TypeMode.NoIdentifier)

						if type.ok {
							if @test(Token.EQUALS_RIGHT_ANGLE) {
								@commit()

								@submitNamedGroupSpecifier([], type, elements)
							}
							else {
								elements.push(@yep(AST.TypedSpecifier(type, type)))
							}
						}
						else {
							@submitNamedSpecifier([], elements)

							while @test(Token.COMMA) {
								@commit()

								@submitNamedSpecifier([], elements)
							}
						}
					}

					last = elements[elements.length - 1]

					specifiers.push(@yep(AST.GroupSpecifier([], elements, null, first, last)))

					last = specifiers[specifiers.length - 1]
				}
				.LEFT_CURLY {
					type = @reqTypeModule(@yes())

					if @match(Token.EQUALS_RIGHT_ANGLE, Token.FOR) == Token.EQUALS_RIGHT_ANGLE {
						var modifier = @yep(AST.Modifier(ModifierKind.Alias, @yes()))
						var elements = []
						var identifier = @reqIdentifier()

						elements.push(@yep(AST.NamedSpecifier(identifier)))

						if @test(Token.COMMA) {
							@commit()

							var element = @reqDestructuring(DestructuringMode.Nil, FunctionMode.Nil)

							elements.push(@yep(AST.NamedSpecifier(element)))
						}

						last = elements[elements.length - 1]

						specifiers.push(@yep(AST.GroupSpecifier([modifier], elements, null, modifier, last)))
					}
					else if @token == Token.FOR {
						@commit()

						var elements = []

						if @test(Token.ASTERISK) {
							var modifier = @yep(AST.Modifier(ModifierKind.Wildcard, @yes()))

							specifiers.push(@yep(AST.GroupSpecifier([modifier], [], null, modifier, modifier)))

							last = modifier
						}
						else if @test(Token.LEFT_CURLY) {
							@commit().NL_0M()

							while @until(Token.RIGHT_CURLY) {
								@submitNamedSpecifier([], specifiers)

								@reqNL_1M()
							}

							@throw('}') unless @test(Token.RIGHT_CURLY)

							last = @yes()
						}
						else {
							@submitNamedSpecifier([], specifiers)

							while @test(Token.COMMA) {
								@commit()

								@submitNamedSpecifier([], specifiers)
							}
						}

						last = specifiers[specifiers.length - 1]
					}
					else {
						last = type
					}
				}
			}

			return @yep(AST.ImportDeclarator(attributes, modifiers, source, arguments, type, specifiers, source, last))
		} # }}}

		reqImportStatement(
			first: Event(Y)
		): Event<NodeData(ImportDeclaration)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token.LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqImportDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token.NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(last <- @reqImportDeclarator())
			}

			return @yep(AST.ImportDeclaration(attributes, declarations, first, last))
		} # }}}

		reqIncludeDeclarator(): Event<NodeData(IncludeDeclarator)>(Y) ~ SyntaxError # {{{
		{
			unless @test(Token.STRING) {
				@throw('String')
			}

			var file = @yes(@value())

			return @yep(AST.IncludeDeclarator(file!!))
		} # }}}

		reqIncludeStatement(
			first: Event(Y)
		): Event<NodeData(IncludeDeclaration)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token.LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqIncludeDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token.NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(last <- @reqIncludeDeclarator())
			}

			return @yep(AST.IncludeDeclaration(attributes, declarations, first, last))
		} # }}}

		reqIncludeAgainStatement(
			first: Event(Y)
		): Event<NodeData(IncludeAgainDeclaration)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token.LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqIncludeDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token.NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(last <- @reqIncludeDeclarator())
			}

			return @yep(AST.IncludeAgainDeclaration(attributes, declarations, first, last))
		} # }}}

		reqIteration(
			fMode: FunctionMode
		): Event<IterationData>(Y) ~ SyntaxError # {{{
		{
			var modifiers = []
			var mut first = null
			var mut declaration = false

			var mark = @mark()

			if @test(Token.VAR) {
				var mark2 = @mark()
				first = @yes()

				var modifier = if @test(Token.MUT) {
					set AST.Modifier(ModifierKind.Mutable, @yes())
				}
				else {
					set null
				}

				if @test(Token.COMMA) {
					first = null

					@rollback(mark)
				}
				else if @test(Token.FROM, Token.IN, Token.OF) {
					@commit()

					if @test(Token.FROM, Token.IN, Token.OF) {
						modifiers
							..push(AST.Modifier(ModifierKind.Declarative, first))
							..push(modifier) if ?modifier

						declaration = true

						@rollback(mark2)
					}
					else {
						first = null

						@rollback(mark)
					}
				}
				else {
					modifiers
							..push(AST.Modifier(ModifierKind.Declarative, first))
							..push(modifier) if ?modifier

					declaration = true
				}
			}


			var mut identifier1: Event = NO
			var mut type1: Event = NO
			var mut identifier2: Event = NO
			var mut destructuring: Event = NO

			if @test(Token.UNDERSCORE) {
				if ?first {
					@commit()
				}
				else {
					first = @yes()
				}
			}
			else {
				destructuring = @tryDestructuring(declaration ? .Declaration : null, fMode)

				if destructuring.ok {
					first ??= destructuring
				}
				else {
					identifier1 = @reqIdentifier()

					if @test(Token.COLON) {
						@commit()

						type1 = @reqType()
					}

					first ??= identifier1
				}
			}

			if @test(Token.COMMA) {
				@commit()

				identifier2 = @reqIdentifier()
			}

			@NL_0M()

			if destructuring.ok {
				if @match(Token.IN, Token.OF) == Token.IN {
					@commit()

					var expression = @reqExpression(.Nil, fMode)

					return @reqIterationIn(modifiers, destructuring, type1, identifier2, expression, first, fMode)
				}
				else if @token == Token.OF {
					@commit()

					return @reqIterationOf(modifiers, destructuring, type1, identifier2, first, fMode)
				}
				else {
					@throw('in', 'of')
				}
			}
			else if identifier2.ok {
				if @match(Token.IN, Token.OF) == Token.IN {
					@commit()

					return @reqIterationInRange(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else if @token == Token.OF {
					@commit()

					return @reqIterationOf(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					@throw('in', 'of')
				}
			}
			else if identifier1.ok {
				if @match(Token.FROM, Token.FROM_TILDE, Token.IN, Token.OF) == .FROM | .FROM_TILDE {
					return @reqIterationFrom(modifiers, identifier1, first, fMode)
				}
				else if @token == .IN {
					@commit()

					return @reqIterationInRange(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else if @token == .OF {
					@commit()

					return @reqIterationOf(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					@throw('from', 'in', 'of')
				}
			}
			else {
				if @test(.IN) {
					@commit()

					var expression = @reqExpression(.Nil, fMode)

					return @reqIterationIn(modifiers, identifier1, type1, identifier2, expression, first, fMode)
				}
				else if @test(.OF) {
					@commit()

					return @reqIterationOf(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					@throw('in', 'of')
				}
			}
		} # }}}

		reqIterationFrom(
			modifiers: ModifierData[]
			variable: Event<NodeData(Identifier)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(From)>(Y) ~ SyntaxError # {{{
		{
			var late from: Event
			if @token == Token.FROM_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))

				from = @reqExpression(.Nil, fMode)

				AST.pushModifier(from.value, modifier)
			}
			else {
				@commit()

				from = @reqExpression(.Nil, fMode)
			}

			@NL_0M()

			if @match(Token.DOWN, Token.UP) == Token.DOWN {
				modifiers.push(AST.Modifier(ModifierKind.Descending, @yes()))

				@NL_0M()
			}
			else if @token == Token.UP {
				modifiers.push(AST.Modifier(ModifierKind.Ascending, @yes()))

				@NL_0M()
			}

			var late to: Event
			if @match(Token.TO, Token.TO_TILDE) == Token.TO {
				@commit()

				to = @reqExpression(.Nil, fMode)
			}
			else if @token == Token.TO_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))

				to = @reqExpression(.Nil, fMode)

				AST.pushModifier(to.value, modifier)
			}
			else {
				@throw('to', 'to~')
			}

			@NL_0M()

			var mut step: Event? = null
			if @test(Token.STEP) {
				@commit()

				step = @reqExpression(.Nil, fMode)

				@NL_0M()
			}

			var mut until: Event? = null
			var mut while: Event? = null
			if @match(Token.UNTIL, Token.WHILE) == Token.UNTIL {
				@commit()

				until = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else if @token == Token.WHILE {
				@commit()

				while = @reqExpression(.Nil, fMode)

				@NL_0M()
			}

			var mut when: Event? = null
			if @test(Token.WHEN) {
				var first = @yes()

				when = @relocate(@reqExpression(.Nil, fMode), first, null)
			}

			return @yep(AST.IterationFrom(modifiers, variable, from, to, step, until, while, when, first, (when ?? while ?? until ?? step ?? to)!!))
		} # }}}

		reqIterationIn(
			modifiers: ModifierData[]
			value: Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>
			type: Event<NodeData(Type)>
			index: Event<NodeData(Identifier)>
			expression: Event<NodeData(Expression)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(Array)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var mut from: Event? = null
			if @match(Token.FROM, Token.FROM_TILDE) == Token.FROM {
				@commit()

				from = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else if @token == Token.FROM_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))

				from = @reqExpression(.Nil, fMode)

				AST.pushModifier(from.value, modifier)

				@NL_0M()
			}

			var mut order: Event? = null
			if @match(Token.DOWN, Token.UP) == Token.DOWN {
				order = @yes()

				modifiers.push(AST.Modifier(ModifierKind.Descending, order))

				@NL_0M()
			}
			else if @token == Token.UP {
				order = @yes()

				modifiers.push(AST.Modifier(ModifierKind.Ascending, order))

				@NL_0M()
			}

			var mut to: Event? = null
			if @match(Token.TO, Token.TO_TILDE) == Token.TO {
				@commit()

				to = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else if @token == Token.TO_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))

				to = @reqExpression(.Nil, fMode)

				AST.pushModifier(to.value, modifier)

				@NL_0M()
			}

			var mut step: Event? = null
			if @test(Token.STEP) {
				@commit()

				step = @reqExpression(.Nil, fMode)

				@NL_0M()
			}

			var mut split: Event? = null
			if @test(Token.SPLIT) {
				@commit()

				split = @reqExpression(.Nil, fMode)

				@NL_0M()
			}

			var mut until: Event? = null
			var mut while: Event? = null
			if @match(Token.UNTIL, Token.WHILE) == Token.UNTIL {
				@commit()

				until = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else if @token == Token.WHILE {
				@commit()

				while = @reqExpression(.Nil, fMode)

				@NL_0M()
			}

			var mut when: Event? = null
			if @test(Token.WHEN) {
				var first = @yes()

				when = @relocate(@reqExpression(.Nil, fMode), first, null)
			}

			return @yep(AST.IterationArray(modifiers, value, type, index, expression, from, to, step, split, until, while, when, first, (when ?? while ?? until ?? split ?? step ?? to ?? order ?? from ?? expression)!!))
		} # }}}

		reqIterationInRange(
			modifiers: ModifierData[]
			value: Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>
			type: Event<NodeData(Type)>
			index: Event<NodeData(Identifier)>
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(Array, Range)>(Y) ~ SyntaxError # {{{
		{
			var operand = @tryRangeOperand(ExpressionMode.InlineOnly, fMode)

			if operand.ok {
				if @test(Token.LEFT_ANGLE, Token.DOT_DOT) {
					if @token == Token.LEFT_ANGLE {
						AST.pushModifier(operand.value, @yep(AST.Modifier(ModifierKind.Ballpark, @yes())))

						unless @test(Token.DOT_DOT) {
							@throw('..')
						}

						@commit()
					}
					else {
						@commit()
					}

					var mut modifier: Event? = null
					if @test(Token.LEFT_ANGLE) {
						modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))
					}

					var to = @reqPrefixedOperand(.InlineOnly, fMode)

					if ?modifier {
						AST.pushModifier(to.value, modifier)
					}

					var mut step: Event? = null
					if @test(Token.DOT_DOT) {
						@commit()

						step = @reqPrefixedOperand(.InlineOnly, fMode)
					}

					return @reqIterationRange(modifiers, value!!, index, operand, to, step, first, fMode)
				}
				else {
					var expression = @tryOperation(operand, .Nil, fMode)

					return @reqIterationIn(modifiers, value, type, index, expression!!, first, fMode)
				}
			}
			else {
				var expression = @reqExpression(.Nil, fMode)

				return @reqIterationIn(modifiers, value, type, index, expression, first, fMode)
			}
		} # }}}

		reqIterationOf(
			modifiers: ModifierData[]
			value: Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>
			type: Event<NodeData(Type)>
			key: Event<NodeData(Identifier)>
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(Object)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(.Nil, fMode)

			var dyn until, while
			if @match(Token.UNTIL, Token.WHILE) == Token.UNTIL {
				@commit()

				until = @reqExpression(.Nil, fMode)
			}
			else if @token == Token.WHILE {
				@commit()

				while = @reqExpression(.Nil, fMode)
			}

			@NL_0M()

			var dyn whenExp
			if @test(Token.WHEN) {
				var first = @yes()

				whenExp = @relocate(@reqExpression(.Nil, fMode), first, null)
			}

			return @yep(AST.IterationObject(modifiers, value, type, key, expression, until, while, whenExp, first, (whenExp ?? while ?? until ?? expression)!!))
		} # }}}

		reqIterationRange(
			modifiers: ModifierData[]
			value: Event<NodeData(Identifier)>
			index: Event<NodeData(Identifier)>
			from: Event<NodeData(Expression)>(Y)
			to: Event<NodeData(Expression)>(Y)
			filter: Event<NodeData(Expression)>(Y)?
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(Range)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var mut until: Event? = null
			var mut while: Event? = null
			if @match(Token.UNTIL, Token.WHILE) == Token.UNTIL {
				@commit()

				until = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else if @token == Token.WHILE {
				@commit()

				while = @reqExpression(.Nil, fMode)

				@NL_0M()
			}

			var mut when: Event? = null
			if @test(Token.WHEN) {
				var first = @yes()

				when = @relocate(@reqExpression(.Nil, fMode), first, null)
			}

			return @yep(AST.IterationRange(modifiers, value, index, from, to, filter, until, while, when, first, (when ?? while ?? until ?? filter ?? to ?? from)!!))
		} # }}}

		reqJunctionExpression(
			operator: Event<BinaryOperatorData>(Y)
			mut eMode: ExpressionMode
			fMode: FunctionMode
			values: NodeData(Expression)[]
			type: Boolean
		): NodeData(JunctionExpression) ~ SyntaxError # {{{
		{
			@NL_0M()

			eMode += ExpressionMode.ImplicitMember

			var operands = [values.pop()]

			if type {
				operands.push(@reqTypeLimited(false).value)
			}
			else {
				operands.push(@reqBinaryOperand(eMode, fMode).value)
			}

			var kind = operator.value.kind

			repeat {
				var mark = @mark()
				var operator = @tryJunctionOperator()

				if operator.ok && operator.value.kind == kind {
					@NL_0M()

					if type {
						operands.push(@reqTypeLimited(false).value)
					}
					else {
						operands.push(@reqBinaryOperand(eMode, fMode).value)
					}
				}
				else {
					@rollback(mark)

					break
				}
			}

			return AST.JunctionExpression(operator, operands)
		} # }}}

		reqLambdaBody(
			modifiers: Event<ModifierData>(Y)[]
			fMode: FunctionMode
			automatable: Boolean
		): Event<NodeData(Block, Expression)>(Y) ~ SyntaxError # {{{
		{
			var body = @tryLambdaBody(modifiers, fMode, automatable)

			if body.ok {
				return body
			}
			else {
				@throw('=>')
			}
		} # }}}

		reqMacroElements(
			elements: Event<MacroElementData(Expression, Literal)>(Y)[]
			terminator: MacroTerminator
		): Void ~ SyntaxError # {{{
		{
			var history = []

			var dyn literal = null
			var dyn first, last

			var addLiteral = () => {
				if literal != null {
					elements.push(@yep(AST.MacroElementLiteral(literal, first!?, last!?)))

					literal = null
				}
			}

			var addToLiteral = () => {
				if literal == null {
					literal = @scanner.value()
					first = last = @yep()
				}
				else {
					literal += @scanner.value()
					last = @yep()
				}

				@commit()
			}

			var pushToLiteral = (value, position) => {
				if literal == null {
					literal = value
					first = last = position
				}
				else {
					literal += value
					last = position
				}
			}

			repeat {
				match @matchM(M.MACRO) {
					Token.EOF {
						if history.length == 0 && terminator !~ MacroTerminator.NEWLINE {
							@throw()
						}

						break
					}
					Token.HASH_LEFT_ROUND {
						addLiteral()

						var first = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, null, first, @yes())))
					}
					Token.HASH_A_LEFT_ROUND {
						addLiteral()

						var reification = AST.Reification(.Argument, @yes())
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, reification, reification, @yes())))
					}
					Token.HASH_E_LEFT_ROUND {
						addLiteral()

						var reification = AST.Reification(.Expression, @yes())
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, reification, reification, @yes())))
					}
					Token.HASH_J_LEFT_ROUND {
						addLiteral()

						var reification = AST.Reification(.Join, @yes())
						var expression = @reqExpression(.Nil, .Nil)

						@throw(',') unless @test(Token.COMMA)

						@commit()

						var separator = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						var ast = AST.MacroElementExpression(expression, reification, reification, @yes())

						ast.separator = separator.value

						elements.push(@yep(ast))
					}
					Token.HASH_S_LEFT_ROUND {
						addLiteral()

						var reification = AST.Reification(.Statement, @yes())
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, reification, reification, @yes())))
					}
					Token.HASH_W_LEFT_ROUND {
						addLiteral()

						var reification = AST.Reification(.Write, @yes())
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, reification, reification, @yes())))
					}
					Token.INVALID {
						addToLiteral()
					}
					Token.LEFT_CURLY {
						addToLiteral()

						history.unshift(Token.RIGHT_CURLY)
					}
					Token.LEFT_ROUND {
						addToLiteral()

						history.unshift(Token.RIGHT_ROUND)
					}
					Token.NEWLINE {
						if history.length == 0 && terminator ~~ MacroTerminator.NEWLINE {
							break
						}
						else {
							addLiteral()

							elements.push(@yep(AST.MacroElementNewLine(@yes())))

							@scanner.skip()
						}
					}
					Token.RIGHT_CURLY {
						if history.length == 0 {
							if terminator !~ MacroTerminator.RIGHT_CURLY {
								addToLiteral()
							}
							else {
								break
							}
						}
						else {
							addToLiteral()

							if history[0] == Token.RIGHT_CURLY {
								history.shift()
							}
						}
					}
					Token.RIGHT_ROUND {
						if history.length == 0 {
							if terminator !~ MacroTerminator.RIGHT_ROUND {
								addToLiteral()
							}
							else {
								break
							}
						}
						else {
							addToLiteral()

							if history[0] == Token.RIGHT_ROUND {
								history.shift()
							}
						}
					}
				}
			}

			unless history.length == 0 {
				@throw()
			}

			if literal != null {
				elements.push(@yep(AST.MacroElementLiteral(literal, first!?, last!?)))
			}
		} # }}}

		reqMacroExpression(
			mut first: Event
			terminator: MacroTerminator = MacroTerminator.NEWLINE
		): Event<NodeData(MacroExpression)>(Y) ~ SyntaxError # {{{
		{
			var elements = []

			if @test(Token.LEFT_CURLY) {
				if first.ok {
					@commit()
				}
				else {
					first = @yes()
				}

				@reqNL_1M()

				@reqMacroElements(elements, MacroTerminator.RIGHT_CURLY)

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				return @yep(AST.MacroExpression(elements, first, @yes()))
			}
			else {
				if !first.ok {
					first = @yep()
				}

				@reqMacroElements(elements, terminator)

				return @yep(AST.MacroExpression(elements, first, elements[elements.length - 1]))
			}
		} # }}}

		reqMacroParameterList(): Event<Event<NodeData(Parameter)>(Y)[]>(Y) ~ SyntaxError # {{{
		{
			unless @test(Token.LEFT_ROUND) {
				@throw('(')
			}

			var first = @yes()

			@NL_0M()

			var parameters = []

			while @until(Token.RIGHT_ROUND) {
				parameters.push(@reqParameter(DestructuringMode.Parameter, FunctionMode.Macro))

				@reqSeparator(Token.RIGHT_ROUND)
			}

			unless @test(Token.RIGHT_ROUND) {
				@throw(')')
			}

			return @yep(parameters, first, @yes())
		} # }}}

		reqMacroBody(): Event<NodeData(Block, ExpressionStatement)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.LEFT_CURLY, Token.EQUALS_RIGHT_ANGLE) == Token.LEFT_CURLY {
				@mode += ParserMode.MacroExpression

				var body = @reqBlock(@yes(), null, FunctionMode.Nil)

				@mode -= ParserMode.MacroExpression

				return body
			}
			else if @token == Token.EQUALS_RIGHT_ANGLE {
				var expression = @reqMacroExpression(@yes())

				return @yep(AST.ExpressionStatement(expression))
			}
			else {
				@throw('{', '=>')
			}
		} # }}}

		reqMacroStatement(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[] = []
		): Event<NodeData(MacroDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()
			var parameters = @reqMacroParameterList()

			var body = @reqMacroBody()

			@reqNL_1M()

			return @yep(AST.MacroDeclaration(attributes, name, parameters, body, name, body))
		} # }}}

		reqMacroStatement(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[] = []
			name: Event<NodeData(Identifier)>(Y)
			first: Range
		): Event<NodeData(MacroDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var parameters = @reqMacroParameterList()

			var body = @reqMacroBody()

			@reqNL_1M()

			return @yep(AST.MacroDeclaration(attributes, name, parameters, body, first, body))
		} # }}}

		reqMatchBinding(
			fMode: FunctionMode
		): Event<NodeData(VariableDeclarator, ArrayBinding, ObjectBinding)>(Y) ~ SyntaxError # {{{
		{
			var dMode: DestructuringMode = .RECURSION + .TYPE

			match @match(Token.LEFT_CURLY, Token.LEFT_SQUARE) {
				Token.LEFT_CURLY {
					return @reqDestructuringObject(@yes(), dMode, fMode)
				}
				Token.LEFT_SQUARE {
					return @reqDestructuringArray(@yes(), dMode, fMode)
				}
				else {
					var mark = @mark()

					var modifiers = []
					var mut modifier = null
					var mut name = null
					var mut type = null

					if @test(Token.VAR) {
						var varModifier = @yep(AST.Modifier(ModifierKind.Declarative, @yes()))

						var dMode: DestructuringMode = .MODIFIER + .RECURSION + .TYPE
						var mark2 = @mark()
						var mut typing = true

						if @test(Token.MUT) {
							var mutModifier = @yep(AST.Modifier(ModifierKind.Mutable, @yes()))

							match @match(Token.LEFT_CURLY, Token.LEFT_SQUARE) {
								Token.LEFT_CURLY {
									name = @tryDestructuringObject(@yes(), dMode, fMode)
								}
								Token.LEFT_SQUARE {
									name = @tryDestructuringArray(@yes(), dMode, fMode)
								}
								else {
									name = @tryIdentifier()
								}
							}

							if name.ok {
								modifiers.push(varModifier, mutModifier)
							}
							else {
								@rollback(mark2)

								name = @reqIdentifier()
							}
						}
						else {
							match @match(Token.LEFT_CURLY, Token.LEFT_SQUARE) {
								Token.LEFT_CURLY {
									name = @tryDestructuringObject(@yes(), dMode, fMode)
								}
								Token.LEFT_SQUARE {
									name = @tryDestructuringArray(@yes(), dMode, fMode)
								}
								else {
									name = @tryIdentifier()
								}
							}

							if name.ok {
								modifiers.push(varModifier)
							}
							else {
								@rollback(mark)

								name = @reqIdentifier()
								typing = false
							}
						}

						if typing && @test(Token.COLON) {
							@commit()

							type = @reqType()
						}
					}
					else {
						name = @reqIdentifier()
					}

					return @yep(AST.VariableDeclarator(modifiers, name, type, modifier ?? name, type ?? name))
				}
			}
		} # }}}

		reqMatchCaseExpression(
			fMode: FunctionMode
		): Event<NodeData(Statement)>(Y) ~ SyntaxError # {{{
		{
			match @match(Token.BREAK, Token.CONTINUE, Token.PASS, Token.RETURN, Token.THROW) {
				Token.BREAK {
					return @reqBreakStatement(@yes(), .ImplicitMember, fMode)
				}
				Token.CONTINUE {
					return @reqContinueStatement(@yes(), .ImplicitMember, fMode)
				}
				Token.PASS {
					return @reqPassStatement(@yes())
				}
				Token.RETURN {
					return @reqReturnStatement(@yes(), .ImplicitMember, fMode)
				}
				Token.THROW {
					var first = @yes()
					var expression = @reqExpression(.ImplicitMember, fMode)

					return @yep(AST.ThrowStatement(expression, first, expression))
				}
				else {
					var expression = @reqExpression(.MatchCase + .ImplicitMember, fMode)

					if @mode ~~ .InlineStatement {
						return @yep(AST.SetStatement(expression, expression, expression))
					}
					else {
						return @yep(AST.ExpressionStatement(expression))
					}
				}
			}
		} # }}}

		reqMatchCaseList(
			fMode: FunctionMode
		): Event<NodeData(MatchClause)[]>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var clauses = []

			var dyn conditions, binding, filter, body, first
			until @test(Token.RIGHT_CURLY) {
				first = conditions = binding = filter = null

				if @test(Token.ELSE) {
					first = @yes()

					if @test(Token.LEFT_CURLY) {
						body = @reqBlock(@yes(), null, fMode)
					}
					else if @test(Token.EQUALS_RIGHT_ANGLE) {
						@commit()

						body = @reqMatchCaseExpression(fMode)
					}
					else {
						@throw('=>', '{')
					}
				}
				else {
					if !@test(Token.WITH, Token.WHEN) {
						first = @reqMatchCondition(fMode)

						conditions = [first]

						while @test(Token.COMMA) {
							@commit()

							conditions.push(@reqMatchCondition(fMode))
						}

						@NL_0M()
					}

					if @test(Token.WITH) {
						if ?first {
							@commit()
						}
						else {
							first = @yes()
						}

						binding = @reqMatchBinding(fMode)

						@NL_0M()
					}

					if @test(Token.WHEN) {
						if ?first {
							@commit()
						}
						else {
							first = @yes()
						}

						filter = @reqExpression(.ImplicitMember + .NoAnonymousFunction, fMode)

						@NL_0M()
					}

					if @test(Token.LEFT_CURLY) {
						body = @reqBlock(@yes(), null, fMode)
					}
					else if @test(Token.EQUALS_RIGHT_ANGLE) {
						@commit()

						body = @reqMatchCaseExpression(fMode)
					}
					else {
						@throw('=>', '{')
					}
				}

				@reqNL_1M()

				clauses.push(AST.MatchClause(conditions, binding, filter, body, first!?, body))
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yes(clauses)
		} # }}}

		reqMatchCondition(
			fMode: FunctionMode
		): Event<NodeData(Expression, MatchConditionArray, MatchConditionObject, MatchConditionRange, MatchConditionType)>(Y) ~ SyntaxError # {{{
		{
			match @match(Token.LEFT_CURLY, Token.LEFT_SQUARE, Token.IS) {
				Token.IS {
					var first = @yes()
					var type = @reqType(.InlineOnly + .ImplicitMember)

					return @yep(AST.MatchConditionType(type, first, type))
				}
				Token.LEFT_CURLY {
					var dyn first = @yes()

					var properties = []

					if !@test(Token.RIGHT_CURLY) {
						var dyn name

						while true {
							name = @reqIdentifier()

							if @test(Token.COLON) {
								@commit()

								var value = @reqMatchConditionValue(fMode)

								properties.push(@yep(AST.ObjectMember([], [], name, null, value, name, value)))
							}
							else {
								properties.push(@yep(AST.ObjectMember([], [], name, null, null, name, name)))
							}

							if @test(Token.COMMA) {
								@commit()
							}
							else {
								break
							}
						}
					}

					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.MatchConditionObject(properties, first, @yes()))
				}
				Token.LEFT_SQUARE {
					var dyn first = @yes()

					var values = []

					until @test(Token.RIGHT_SQUARE) {
						if @test(Token.UNDERSCORE) {
							values.push(@yep(AST.OmittedExpression([], @yes())))
						}
						else if @test(Token.DOT_DOT_DOT) {
							var modifier = AST.Modifier(ModifierKind.Rest, @yes())

							values.push(@yep(AST.OmittedExpression([modifier], modifier)))
						}
						else {
							values.push(@reqMatchConditionValue(fMode))
						}

						if @test(Token.COMMA) {
							@commit()

							if @test(Token.RIGHT_SQUARE) {
								values.push(@yep(AST.OmittedExpression([], @yep())))
							}
						}
						else {
							break
						}
					}

					unless @test(Token.RIGHT_SQUARE) {
						@throw(']')
					}

					return @yep(AST.MatchConditionArray(values, first, @yes()))
				}
				else {
					return @reqMatchConditionValue(fMode)
				}
			}
		} # }}}

		reqMatchConditionValue(
			fMode: FunctionMode
		): Event<NodeData(Expression, MatchConditionRange)>(Y) ~ SyntaxError # {{{
		{
			var eMode = ExpressionMode.InlineOnly + ExpressionMode.ImplicitMember
			var operand = @reqPrefixedOperand(eMode, fMode)
			var mut operator: Event = NO

			if @match(Token.LEFT_ANGLE, Token.DOT_DOT) == Token.DOT_DOT {
				@commit()

				if @test(Token.LEFT_ANGLE) {
					@commit()

					return @yep(AST.MatchConditionRangeFI(operand, @reqPrefixedOperand(.Nil, fMode)))
				}
				else {
					return @yep(AST.MatchConditionRangeFO(operand, @reqPrefixedOperand(.Nil, fMode)))
				}
			}
			else if @token == Token.LEFT_ANGLE {
				@commit()

				unless @test(Token.DOT_DOT) {
					@throw('..')
				}

				@commit()

				if @test(Token.LEFT_ANGLE) {
					@commit()

					return @yep(AST.MatchConditionRangeTI(operand, @reqPrefixedOperand(.Nil, fMode)))
				}
				else {
					return @yep(AST.MatchConditionRangeTO(operand, @reqPrefixedOperand(.Nil, fMode)))
				}
			}
			else if (operator <- @tryJunctionOperator()).ok {
				var values: NodeData(Expression)[] = [operand.value]
				// var values: BinaryOperationData[] = [operand.value]

				values.push(@reqJunctionExpression(operator, eMode, fMode, values, false))

				return @yep(AST.reorderExpression(values))
			}
			else {
				return operand
			}
		} # }}}

		reqMultiLineString(
			first: Event(Y)
			delimiter: Token
		): Event<NodeData(Literal)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.NEWLINE) {
				@commit()
			}
			else {
				@throw('NewLine')
			}

			var lines = []
			var mut last: Event
			var mut baseIndent: String = ''

			repeat {
				var currentIndent = @scanner.readIndent()

				if @test(delimiter) {
					baseIndent = currentIndent

					last = @yes()

					break
				}
				else if @token == Token.EOF {
					@throw(delimiter == Token.ML_DOUBLE_QUOTE ? '"""' : "'''")
				}
				else {
					lines.push(currentIndent, @scanner.readLine())

					if @test(Token.NEWLINE) {
						@commit()
					}
					else {
						@throw('NewLine')
					}
				}
			}

			var mut value = ''

			if ?#baseIndent {
				for var [indent, line], index in lines split 2 {
					if index > 0 {
						value += '\n'
					}

					if ?#line {
						if indent.startsWith(baseIndent) {
							value += indent.substr(baseIndent.length) + line
						}
						else {
							throw @error(`Unexpected indentation`, first.start.line + (index / 2) + 1, 1)
						}
					}
				}
			}
			else {
				for var [indent, line], index in lines split 2 {
					if index > 0 {
						value += '\n'
					}

					value += indent + line
				}
			}

			var modifiers = [@yep(AST.Modifier(ModifierKind.MultiLine, first, last))]

			return @yep(AST.Literal(modifiers, value, first, last!!))
		} # }}}

		reqMultiLineTemplate(
			first: Event(Y)
			fMode: FunctionMode
			delimiter: Token
		): Event<NodeData(TemplateExpression)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.NEWLINE) {
				@commit()
			}
			else {
				@throw('NewLine')
			}

			var lines = []
			var mut last: Event
			var mut baseIndent: String = ''

			repeat {
				var currentIndent = @scanner.readIndent()

				if @test(delimiter) {
					baseIndent = currentIndent

					last = @yes()

					break
				}
				else if @token == Token.EOF {
					@throw(delimiter == Token.ML_BACKQUOTE ? '```' : '~~~')
				}
				else {
					var line = [currentIndent]

					repeat {
						if @matchM(M.TEMPLATE) == Token.TEMPLATE_ELEMENT {
							@commit()

							line.push(@reqExpression(.Nil, fMode))

							unless @test(Token.RIGHT_ROUND) {
								@throw(')')
							}

							@commit()
						}
						else if @token == Token.TEMPLATE_VALUE {
							line.push(@yep(AST.Literal(null, @scanner.value(), @yes())))
						}
						else {
							break
						}
					}

					if @test(Token.NEWLINE) {
						lines.push(line)

						@commit()
					}
					else {
						@throw('NewLine')
					}
				}
			}

			var elements = []

			if ?#lines {
				if ?#baseIndent {
					var firstLine = first.start!?.line + 1
					var mut previous = null

					for var [indent, first? = null, ...rest], index in lines {
						if index > 0 {
							if !?previous {
								previous = AST.Literal(null, '\n', {
									line: firstLine
									column: 1
								}, {
									line: firstLine
									column: 2
								})

								elements.push(@yep(previous))
							}
							else if previous.kind == NodeKind.Literal {
								previous.value += '\n'
								previous.end.column += 1
							}
							else {
								previous = AST.Literal(null, '\n', {
									line: previous.end.line:Number
									column: previous.end.column:Number + 1
								}, {
									line: previous.end.line:Number
									column: previous.end.column:Number + 2
								})

								elements.push(@yep(previous))
							}
						}

						if ?first {
							unless indent.startsWith(baseIndent) {
								throw @error(`Unexpected indentation`, first.line:Number + index + 1, 1)
							}

							if var value ?#= indent.substr(baseIndent.length) {
								if !?previous {
									previous = AST.Literal(null, value, {
										line: firstLine
										column: baseIndent.length
									}, {
										line: firstLine
										column: indent.length
									})

									elements.push(@yep(previous))
								}
								else if previous.kind == NodeKind.Literal {
									previous.value += value
									previous.end.line += 1
									previous.end.column += indent.length
								}
								else {
									previous = AST.Literal(null, value, {
										line: previous.end.line:Number + 1
										column: baseIndent.length
									}, {
										line: previous.end.line:Number + 1
										column: indent.length
									})

									elements.push(@yep(previous))
								}
							}

							if ?previous && first.value.kind == NodeKind.Literal {
								previous.value += first.value.value
								previous.end = first.value.end

								if ?#rest {
									elements.push(...rest)

									previous = rest[rest.length - 1].value
								}
							}
							else {
								elements.push(first)

								if ?#rest {
									elements.push(...rest)

									previous = rest[rest.length - 1].value
								}
								else {
									previous = first.value
								}
							}
						}
					}
				}
				else {
					elements.push(...lines[0].slice(1)!?)

					if lines.length > 1 {
						var mut previous = elements[elements.length - 1].value

						for var [indent, first? = null, ...rest], index in lines from 1 {
							if previous.kind == NodeKind.Literal {
								previous.value += '\n'
								previous.end.column += 1
							}
							else {
								previous = AST.Literal(null, '\n', {
									line: previous.end.line:Number
									column: previous.end.column:Number + 1
								}, {
									line: previous.end.line:Number
									column: previous.end.column:Number + 2
								})

								elements.push(@yep(previous))
							}

							if ?first {
								if first.value.kind == NodeKind.Literal {
									previous.value += first.value.value
									previous.end = first.value.end
								}
								else {
									elements.push(first)
								}

								if ?#rest {
									elements.push(...rest)

									previous = rest[rest.length - 1].value
								}
								else {
									previous = first.value
								}
							}
						}
					}
				}
			}

			var modifiers = [@yep(AST.Modifier(ModifierKind.MultiLine, first, last))]

			return @yep(AST.TemplateExpression(modifiers, elements, first, last!!))
		} # }}}

		reqNameIB(): Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.IDENTIFIER, Token.LEFT_CURLY, Token.LEFT_SQUARE) == Token.IDENTIFIER {
				return @reqIdentifier()
			}
			else if @token == Token.LEFT_CURLY {
				return @reqDestructuringObject(@yes(), DestructuringMode.Nil, FunctionMode.Nil)
			}
			else if @token == Token.LEFT_SQUARE {
				return @reqDestructuringArray(@yes(), DestructuringMode.Nil, FunctionMode.Nil)
			}
			else {
				@throw('Identifier', 'Destructuring')
			}
		} # }}}

		reqNamespaceStatement(
			first: Event(Y)
			name: Event<NodeData(Identifier)>(Y)
		): Event<NodeData(NamespaceDeclaration)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			@commit()

			@NL_0M()

			var attributes = []
			var statements = []

			var dyn attrs = []
			var dyn statement

			until @test(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				if @matchM(M.MODULE_STATEMENT) == Token.EXPORT {
					statement = @reqExportStatement(@yes())
				}
				else if @token == Token.EXTERN {
					statement = @reqExternStatement(@yes())
				}
				else if @token == Token.INCLUDE {
					statement = @reqIncludeStatement(@yes())
				}
				else if @token == Token.INCLUDE_AGAIN {
					statement = @reqIncludeAgainStatement(@yes())
				}
				else {
					statement = @reqStatement(null, FunctionMode.Nil)
				}

				AST.pushAttributes(statement.value, attrs)

				statements.push(statement)

				@NL_0M()
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.NamespaceDeclaration(attributes, [], name, statements, first, @yes()))
		} # }}}

		reqNumber(): Event<NodeData(NumericExpression)>(Y) ~ SyntaxError # {{{
		{
			var value = @tryNumber()

			if value.ok {
				return value
			}
			else {
				@throw('Number')
			}
		} # }}}

		reqNumeralIdentifier(): Event<NodeData(Identifier)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.IDENTIFIER, Token.NUMERAL) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqNL_1M(): Void ~ SyntaxError # {{{
		{
			if @test(Token.NEWLINE) {
				@commit()

				@skipNewLine()
			}
			else {
				@throw('NewLine')
			}
		} # }}}

		reqNL_EOF_1M(): Void ~ SyntaxError # {{{
		{
			if @match(Token.NEWLINE) == Token.NEWLINE {
				@commit()

				@skipNewLine()
			}
			else if @token != Token.EOF {
				@throw('NewLine', 'EOF')
			}
		} # }}}

		reqOperand(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var operand = @tryOperand(eMode, fMode)

			if operand.ok {
				return operand
			}
			else {
				@throw(...?operand.expecteds)
			}
		} # }}}

		reqOperation(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var operation = @tryOperation(null, eMode, fMode)

			if operation.ok {
				return operation
			}
			else {
				@throw(...?operation.expecteds)
			}
		} # }}}

		reqParameter(
			pMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(Parameter)>(Y) ~ SyntaxError # {{{
		{
			var mut firstAttr = null
			var attributes = @stackInlineAttributes([])
			if attributes.length > 0 {
				firstAttr = attributes[0]
			}

			var mutMark = @mark()
			var mut mutModifier = null

			if @test(Token.MUT) {
				mutModifier = AST.Modifier(ModifierKind.Mutable, @yes())
			}

			var mut positionalModifier = null
			var mut namedModifier = null

			if @test(Token.HASH) {
				positionalModifier = AST.Modifier(ModifierKind.PositionOnly, @yes())
			}
			else if @test(Token.ASTERISK) {
				namedModifier = AST.Modifier(ModifierKind.NameOnly, @yes())
			}

			var mut external = null

			if ?namedModifier {
				var identifier = @tryIdentifier()

				if identifier.ok {
					if @test(Token.PERCENT) {
						@commit()

						external = identifier
					}
					else {
						var modifiers = []
						modifiers.push(mutModifier) if ?mutModifier
						modifiers.push(?positionalModifier ? positionalModifier : namedModifier)

						return @reqParameterIdentifier(attributes, modifiers, null, identifier, true, true, true, true, firstAttr ?? mutModifier ?? positionalModifier ?? namedModifier, fMode)
					}
				}
			}

			if @test(Token.LEFT_CURLY, Token.LEFT_SQUARE) {
				@throw() if fMode ~~ FunctionMode.Macro
				@throw() if ?positionalModifier || (?namedModifier && !?external)

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier
				modifiers.push(namedModifier) if ?namedModifier

				var late internal
				if @token == Token.LEFT_CURLY {
					internal = @reqDestructuringObject(@yes(), pMode, fMode)
				}
				else {
					internal = @reqDestructuringArray(@yes(), pMode, fMode)
				}

				return @reqParameterIdentifier(attributes, modifiers, external, internal, false, true, false, true, firstAttr ?? mutModifier ?? namedModifier ?? external ?? internal, fMode)
			}

			if @test(Token.DOT_DOT_DOT) {
				@throw() if ?positionalModifier || ?namedModifier

				var first = @yes()

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier

				return @reqParameterRest(attributes, modifiers, external, (firstAttr ?? mutModifier ?? first)!!, pMode, fMode)
			}

			if @test(Token.AT) {
				@throw() if ?mutModifier

				var modifiers = []
				modifiers.push(namedModifier) if ?namedModifier
				modifiers.push(positionalModifier) if ?positionalModifier

				return @reqParameterAt(attributes, modifiers, external, firstAttr ?? namedModifier ?? positionalModifier, pMode, fMode)
			}

			if @test(Token.UNDERSCORE) {
				@throw() if ?positionalModifier || (?namedModifier && !?external)

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier
				modifiers.push(namedModifier) if ?namedModifier

				var underscore = @yes()

				return @reqParameterIdentifier(attributes, modifiers, external, null, false, true, true, true, firstAttr ?? mutModifier ?? namedModifier ?? underscore, fMode)
			}

			if ?positionalModifier || ?namedModifier {
				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier
				modifiers.push(?positionalModifier ? positionalModifier : namedModifier)

				return @reqParameterIdentifier(attributes, modifiers, external, null, true, true, true, true, firstAttr ?? mutModifier ?? namedModifier ?? positionalModifier, fMode)
			}

			do {
				var identifier = @tryIdentifier()

				if identifier.ok {
					var modifiers = []
					modifiers.push(mutModifier) if ?mutModifier

					if pMode !~ DestructuringMode.EXTERNAL_ONLY && @test(Token.PERCENT) {
						@commit()

						if @test(Token.UNDERSCORE) {
							@commit()

							return @reqParameterIdentifier(attributes, modifiers, identifier, null, false, true, true, true, firstAttr ?? mutModifier ?? identifier, fMode)
						}
						else if @test(Token.LEFT_CURLY, Token.LEFT_SQUARE) {
							var late internal
							if @token == Token.LEFT_CURLY {
								internal = @reqDestructuringObject(@yes(), pMode, fMode)
							}
							else {
								internal = @reqDestructuringArray(@yes(), pMode, fMode)
							}

							return @reqParameterIdentifier(attributes, modifiers, identifier, internal, true, true, true, true, firstAttr ?? mutModifier ?? identifier, fMode)
						}
						else if @test(Token.DOT_DOT_DOT) {
							@commit()

							return @reqParameterRest(attributes, modifiers, identifier, (firstAttr ?? mutModifier ?? identifier)!!, pMode, fMode)
						}
						else if @test(Token.AT) {
							@throw() if ?mutModifier

							return @reqParameterAt(attributes, modifiers, identifier, firstAttr ?? namedModifier ?? identifier, pMode, fMode)
						}
						else {
							return @reqParameterIdentifier(attributes, modifiers, identifier, null, true, true, true, true, firstAttr ?? mutModifier ?? identifier, fMode)
						}
					}
					else {
						return @reqParameterIdentifier(attributes, modifiers, identifier, identifier, true, true, true, true, firstAttr ?? mutModifier ?? identifier, fMode)
					}
				}

				if ?mutModifier {
					@rollback(mutMark)

					mutModifier = null
				}
				else {
					break
				}
			}
			while true

			@throw()
		} # }}}

		reqParameterAt(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			external: Event<NodeData(Identifier)>(Y)?
			first: Range?
			pMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(Parameter)>(Y) ~ SyntaxError # {{{
		{
			if fMode ~~ FunctionMode.Macro {
				var at = @yes()

				modifiers.push(AST.Modifier(ModifierKind.AutoEvaluate, at))

				var internal = @reqIdentifier()

				return @reqParameterIdentifier(attributes, modifiers, external ?? internal, internal, true, true, true, true, first ?? at, fMode)
			}
			else if fMode ~~ FunctionMode.Method && pMode ~~ DestructuringMode.THIS_ALIAS {
				var at = @yes()

				return @reqParameterThis(attributes, modifiers, external, first ?? at, fMode)
			}
			else {
				@throw()
			}
		} # }}}

		reqParameterIdentifier(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			mut external: Event<NodeData(Identifier)>(Y)?
			mut internal: Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>(Y)?
			required: Boolean
			typed: Boolean
			nullable: Boolean
			valued: Boolean
			mut first: Range?
			fMode: FunctionMode
		): Event<NodeData(Parameter)>(Y) ~ SyntaxError # {{{
		{
			var mut last = internal ?? external ?? first

			if !?internal {
				if !required {
					var identifier = @tryIdentifier()

					if identifier.ok {
						internal = identifier

						first ??= identifier
						last = identifier
					}
				}
				else {
					if !?external {
						var identifier = @reqIdentifier()

						if @test(Token.PERCENT) {
							@commit()

							external = identifier
						}
						else {
							internal = identifier
						}

						first ??= identifier
						last = identifier
					}

					if !?internal {
						internal = @reqIdentifier()

						first ??= internal
						last = internal
					}
				}
			}

			var mut requireDefault = false

			if required && ?internal && valued && @test(Token.EXCLAMATION) {
				var modifier = AST.Modifier(ModifierKind.Required, @yes())

				modifiers.push(modifier)

				requireDefault = true
				last = modifier
			}

			if typed && @test(Token.COLON) {
				@commit()

				var type = @reqTypeParameter()
				var operator = valued ? @tryDefaultAssignmentOperator(true) : NO

				if operator.ok {
					var defaultValue = @reqExpression(.ImplicitMember, fMode)

					return @yep(AST.Parameter(attributes, modifiers, external, internal, type, operator, defaultValue, first!?, defaultValue))
				}
				else if requireDefault {
					@throw('=', '%%=', '##=')
				}
				else {
					return @yep(AST.Parameter(attributes, modifiers, external, internal, type, null, null, first!?, type))
				}
			}
			else {
				var operator = valued ? @tryDefaultAssignmentOperator(true) : NO

				if operator.ok {
					var defaultValue = @reqExpression(.ImplicitMember, fMode)

					return @yep(AST.Parameter(attributes, modifiers, external, internal, null, operator, defaultValue, first!?, defaultValue))
				}
				else if nullable && @test(Token.QUESTION) {
					var modifier = AST.Modifier(ModifierKind.Nullable, @yes())

					modifiers.push(modifier)

					var operator = valued ? @tryDefaultAssignmentOperator(true) : NO

					if operator.ok {
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.Parameter(attributes, modifiers, external, internal, null, operator, defaultValue, first!?, defaultValue))
					}
					else if requireDefault {
						@throw('=', '%%=', '##=')
					}
					else {
						return @yep(AST.Parameter(attributes, modifiers, external, internal, null, null, null, first!?, modifier))
					}
				}
				else if requireDefault {
					@throw('=', '%%=', '##=')
				}
				else {
					return @yep(AST.Parameter(attributes, modifiers, external, internal, null, null, null, first!?, last!?))
				}
			}
		} # }}}

		reqParameterRest(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			mut external: Event<NodeData(Identifier)>?
			first: Range
			pMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(Parameter)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.LEFT_CURLY) {
				@commit()

				var dyn min, max

				if @test(Token.COMMA) {
					@commit()

					min = 0
					max = @reqNumber().value.value
				}
				else {
					min = @reqNumber().value.value

					if @test(Token.COMMA) {
						@commit()

						if @test(Token.RIGHT_CURLY) {
							max = Infinity
						}
						else {
							max = @reqNumber().value.value
						}
					}
					else {
						max = min
					}
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				modifiers.push(AST.RestModifier(min, max, first, @yes()))
			}
			else {
				modifiers.push(AST.RestModifier(0, Infinity, first, first))
			}

			if @test(Token.AT) {
				if fMode ~~ FunctionMode.Method && pMode ~~ DestructuringMode.THIS_ALIAS {
					@commit()

					return @reqParameterThis(attributes, modifiers, external!!, first, fMode)
				}
				else {
					@throw()
				}
			}
			else {
				var identifier = @tryIdentifier()

				if identifier.ok {
					if !?external {
						external = identifier
					}
					else if !external.ok {
						external = null
					}

					return @reqParameterIdentifier(attributes, modifiers, external, identifier, false, true, true, true, first, fMode)
				}

				if ?external && !external.ok {
					external = null
				}

				return @reqParameterIdentifier(attributes, modifiers, external!!, null, false, true, true, true, first, fMode)
			}
		} # }}}

		reqParameterThis(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			external: Event<NodeData(Identifier)>(Y)?
			first: Range
			fMode: FunctionMode
		): Event<NodeData(Parameter)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqThisExpression(first)

			if @test(Token.EXCLAMATION_QUESTION) {
				modifiers.push(AST.Modifier(ModifierKind.NonNullable, @yes()))
			}

			var operator = @tryDefaultAssignmentOperator(true)

			if operator.ok {
				var defaultValue = @reqExpression(.ImplicitMember, fMode)

				return @yep(AST.Parameter(attributes, modifiers, external ?? @yep(name.value.name), name, null, operator, defaultValue, first ?? name, defaultValue))
			}
			else {
				return @yep(AST.Parameter(attributes, modifiers, external ?? @yep(name.value.name), name, null, null, null, first ?? name, name))
			}
		} # }}}

		reqParenthesis(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(SequenceExpression)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var expressions = [@reqExpression(null, fMode, MacroTerminator.List)]

			@NL_0M()

			while @test(Token.COMMA) {
				@commit()

				expressions.push(@reqExpression(null, fMode, MacroTerminator.List))

				@NL_0M()
			}

			unless @test(Token.RIGHT_ROUND) {
				@throw(')')
			}

			if expressions.length == 1 {
				var expression = expressions[0]

				@relocate(expression, first, @yes())

				return expression
			}
			else {
				return @yep(AST.SequenceExpression(expressions, first, @yes()))
			}
		} # }}}

		reqPassStatement(
			first: Event(Y)
		): Event<NodeData(PassStatement)>(Y) ~ SyntaxError # {{{
		{
			return @yep(AST.PassStatement(first))
		} # }}}

		reqPostfixedOperand(
			operand: Event<NodeData(Expression)>(Y)?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var result = @tryPostfixedOperand(operand, eMode, fMode)

			if result.ok {
				return result
			}
			else {
				@throw(...?result.expecteds)
			}
		} # }}}

		reqPrefixedOperand(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var operand = @tryPrefixedOperand(eMode, fMode)

			if operand.ok {
				return operand
			}
			else {
				@throw()
			}
		} # }}}

		reqRepeatStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(RepeatStatement)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			if @test(Token.LEFT_CURLY) {
				var block = @reqBlock(NO, null, fMode)

				return @yep(AST.RepeatStatement(null, block, first, block))
			}
			else {
				var expression = @reqExpression(.Nil, fMode)

				unless @test(Token.TIMES) {
					@throw('times')
				}

				@commit().NL_0M()

				var block = @reqBlock(NO, null, fMode)

				return @yep(AST.RepeatStatement(expression, block, first, block))
			}
		} # }}}

		reqRequireStatement(
			first: Event(Y)
		): Event<NodeData(RequireDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.RequireDeclaration(attributes, declarations, first, last))
		} # }}}

		reqRequireOrExternStatement(
			first: Event(Y)
		): Event<NodeData(RequireOrExternDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.RequireOrExternDeclaration(attributes, declarations, first, last))
		} # }}}

		reqRequireOrImportStatement(
			first: Event(Y)
		): Event<NodeData(RequireOrImportDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token.LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqImportDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token.NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(last <- @reqImportDeclarator())
			}

			@reqNL_EOF_1M()

			return @yep(AST.RequireOrImportDeclaration(attributes, declarations, first, last))
		} # }}}

		reqReturnStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(IfStatement, ReturnStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryReturnStatement(first, eMode, fMode)

			if statement.ok {
				return statement
			}
			else {
				@throw('Expression')
			}
		} # }}}

		reqRollingExpression(
			object: Event<NodeData(Expression)>(Y)
			modifiers: ModifierData[]
			eMode: ExpressionMode
			fMode: FunctionMode
			restrictive: Boolean
		): Event<NodeData(RollingExpression)>(Y) ~ SyntaxError # {{{
		{
			var mode = eMode + ExpressionMode.ImplicitMember + ExpressionMode.NoMultiLine
			var reference =  @yep(AST.Reference('main', object))
			var expressions = []

			repeat {
				@commit()

				var value = @yep(AST.MemberExpression([], reference, @reqIdentifier()))
				var operand = @reqUnaryOperand(value, eMode + ExpressionMode.NoMultiLine, fMode)
				var mut mark = @mark()

				@NL_0M()

				var operator = @tryAssignementOperator()

				if operator.ok {
					@NL_0M()

					var values: NodeData(Expression)[] = [
					// var values: BinaryOperationData[] = [
						operand.value
						AST.BinaryExpression(operator)
						@reqBinaryOperand(mode, fMode).value
					]

					repeat {
						mark = @mark()

						@NL_0M()

						var operator = @tryBinaryOperator(fMode)

						if operator.ok {
							values.push(AST.BinaryExpression(operator))

							@NL_0M()

							values.push(@reqBinaryOperand(mode, fMode).value)
						}
						else {
							@rollback(mark)

							break
						}
					}

					var expression = @yep(AST.reorderExpression(values))

					expressions.push(
						if restrictive || ?#expressions {
							set @altRestrictiveExpression(expression, fMode)
						}
						else {
							set expression
						}
					)

					mark = @mark()
				}
				else {
					@rollback(mark)

					expressions.push(
						if restrictive || ?#expressions {
							set @altRestrictiveExpression(operand, fMode)
						}
						else {
							set operand
						}
					)

					mark = @mark()
				}

				unless @test(Token.NEWLINE) {
					@rollback(mark)

					break
				}

				@commit().NL_0M()

				unless @test(Token.DOT_DOT) {
					@rollback(mark)

					break
				}
			}

			return @yep(AST.RollingExpression(modifiers, object, expressions, object, expressions[expressions.length - 1]))
		} # }}}

		reqSeparator(
			token: Token
		): Void ~ SyntaxError # {{{
		{
			if @match(Token.COMMA, Token.NEWLINE, token) == Token.COMMA {
				@commit()

				if @test(token) {
					@throw()
				}

				@skipNewLine()
			}
			else if @token == Token.NEWLINE {
				@commit()

				@skipNewLine()
			}
			else if @token == token {
				pass
			}
			else {
				@throw(',', token.toString(), 'NewLine')
			}
		} # }}}

		reqSetStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(IfStatement, SetStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(.NoRestriction, fMode)

			if @match(Token.IF, Token.UNLESS) == Token.IF {
				@commit()

				var condition = @reqExpression(.NoRestriction, fMode)

				return @yep(AST.IfStatement(condition, @yep(AST.SetStatement(expression, first, expression)), null, first, condition))
			}
			else if @token == Token.UNLESS {
				@commit()

				var condition = @reqExpression(.NoRestriction, fMode)

				return @yep(AST.UnlessStatement(condition, @yep(AST.SetStatement(expression, first, expression)), first, condition))
			}
			else {
				return @yep(AST.SetStatement(expression, first, expression))
			}
		} # }}}

		reqStatement(
			eMode!: ExpressionMode = .Nil
			fMode: FunctionMode
		): Event<NodeData(Statement)>(Y) ~ SyntaxError # {{{
		{
			var mark = @mark()

			var mut statement: Event = NO

			match @matchM(M.STATEMENT) {
				Token.ABSTRACT {
					var first = @yes()

					if @test(Token.CLASS) {
						@commit()

						var modifiers = [@yep(AST.Modifier(ModifierKind.Abstract, first))]

						statement = @reqClassStatement(modifiers, first)
					}
					else {
						statement = NO
					}
				}
				Token.ASYNC {
					var first = @yes()

					if @test(Token.FUNC) {
						@commit()

						var modifiers = [@yep(AST.Modifier(ModifierKind.Async, first))]

						statement = @reqFunctionStatement(modifiers, first, fMode)
					}
					else {
						statement = NO
					}
				}
				Token.BITMASK {
					statement = @tryBitmaskStatement(@yes())
				}
				Token.BLOCK {
					statement = @tryBlockStatement(@yes(), fMode)
				}
				Token.BREAK {
					statement = @reqBreakStatement(@yes(), .Nil, fMode)
				}
				Token.CLASS {
					statement = @tryClassStatement(@yes())
				}
				Token.CONST {
					statement = @tryConstStatement(@yes(), .Nil, fMode)
				}
				Token.CONTINUE {
					statement = @reqContinueStatement(@yes(), .Nil, fMode)
				}
				Token.DO {
					statement = @reqDoStatement(@yes(), fMode)
				}
				Token.ENUM {
					statement = @tryEnumStatement(@yes())
				}
				Token.FALLTHROUGH {
					statement = @reqFallthroughStatement(@yes())
				}
				Token.FINAL {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(.Final, first))]

					if @test(.CLASS) {
						@commit()

						statement = @reqClassStatement(modifiers, first)
					}
					else if @test(.ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(.Abstract, @yes())))

						if @test(.CLASS) {
							@commit()

							statement = @reqClassStatement(modifiers, first)
						}
						else {
							@throw('class')
						}
					}
					else {
						statement = NO
					}
				}
				Token.FOR {
					statement = @reqForStatement(@yes(), fMode)
				}
				Token.FUNC {
					statement = @reqFunctionStatement(null, @yes(), fMode)
				}
				Token.IF {
					statement = @reqIfStatement(@yes(), fMode)
				}
				Token.IMPL {
					statement = @reqImplementStatement(@yes())
				}
				Token.IMPORT {
					statement = @reqImportStatement(@yes())
				}
				Token.MACRO {
					if @mode !~ ParserMode.MacroExpression {
						statement = @tryMacroStatement(@yes())
					}
					else {
						var expression = @reqMacroExpression(@yes())

						statement = @yep(AST.ExpressionStatement(expression))
					}
				}
				Token.MATCH {
					statement = @tryMatchStatement(@yes(), fMode)
				}
				Token.NAMESPACE {
					statement = @tryNamespaceStatement(@yes())
				}
				Token.PASS {
					statement = @reqPassStatement(@yes())
				}
				Token.SET {
					statement = @reqSetStatement(@yes(), fMode)
				}
				Token.REPEAT {
					statement = @reqRepeatStatement(@yes(), fMode)
				}
				Token.RETURN {
					statement = @tryReturnStatement(@yes(), .Nil, fMode)
				}
				Token.SEALED {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(ModifierKind.Sealed, first))]

					if @test(Token.CLASS) {
						@commit()

						statement = @reqClassStatement(modifiers, first)
					}
					else if @test(Token.ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(ModifierKind.Abstract, @yes())))

						if @test(Token.CLASS) {
							@commit()

							statement = @reqClassStatement(modifiers, first)
						}
						else {
							@throw('class')
						}
					}
					else {
						statement = NO
					}
				}
				Token.STRUCT {
					statement = @tryStructStatement(@yes())
				}
				Token.THROW {
					statement = @reqThrowStatement(@yes(), fMode)
				}
				Token.TRY {
					statement = @tryTryStatement(@yes(), fMode)
				}
				Token.TUPLE {
					statement = @reqTupleStatement(@yes())
				}
				Token.TYPE {
					statement = @tryTypeStatement(@yes())
				}
				Token.UNLESS {
					statement = @reqUnlessStatement(@yes(), fMode)
				}
				Token.UNTIL {
					statement = @tryUntilStatement(@yes(), fMode)
				}
				Token.VAR {
					statement = @tryVarStatement(@yes(), .Nil, fMode)
				}
				.VARIANT {
					statement = @tryVariantStatement(@yes())
				}
				Token.WHILE {
					statement = @tryWhileStatement(@yes(), fMode)
				}
				Token.WITH {
					statement = @tryWithStatement(@yes(), fMode)
				}
			}

			unless statement.ok {
				@rollback(mark)

				if !(statement <- @tryAssignementStatement(eMode, fMode)).ok {
					@rollback(mark)

					statement = @reqExpressionStatement(eMode, fMode)
				}
			}

			@reqNL_EOF_1M()

			return statement
		} # }}}

		reqString(): Event<NodeData(Literal)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.STRING) {
				return @yep(AST.Literal(null, @value()!!, @yes()))
			}
			else {
				@throw('String')
			}
		} # }}}

		reqStructStatement(
			first: Event(Y)
		): Event<NodeData(StructDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryStructStatement(first)

			if statement.ok {
				return statement
			}
			else {
				@throw()
			}
		} # }}}

		reqTemplateExpression(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(TemplateExpression)>(Y) ~ SyntaxError # {{{
		{
			var elements = []

			repeat {
				if @matchM(M.TEMPLATE) == Token.TEMPLATE_ELEMENT {
					@commit()

					elements.push(@reqExpression(eMode, fMode))

					unless @test(Token.RIGHT_ROUND) {
						@throw(')')
					}

					@commit()
				}
				else if @token == Token.TEMPLATE_VALUE {
					elements.push(@yep(AST.Literal(null, @scanner.value(), @yes())))
				}
				else {
					break
				}
			}

			unless @test(Token.TEMPLATE_END) {
				@throw('`')
			}

			return @yep(AST.TemplateExpression(null, elements, first, @yes()))
		} # }}}

		reqThisExpression(
			first: Range
		): Event<NodeData(ThisExpression)>(Y) ~ SyntaxError # {{{
		{
			var identifier = @reqIdentifier()

			return @yep(AST.ThisExpression(identifier, first, identifier))
		} # }}}

		reqThrowStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(IfStatement, ThrowStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(.NoRestriction, fMode)

			if @match(Token.IF, Token.UNLESS) == Token.IF {
				@commit()

				var condition = @reqExpression(.NoRestriction, fMode)

				return @yep(AST.IfStatement(condition, @yep(AST.ThrowStatement(expression, first, expression)), null, first, condition))
			}
			else if @token == Token.UNLESS {
				@commit()

				var condition = @reqExpression(.NoRestriction, fMode)

				return @yep(AST.UnlessStatement(condition, @yep(AST.ThrowStatement(expression, first, expression)), first, condition))
			}
			else {
				return @yep(AST.ThrowStatement(expression, first, expression))
			}
		} # }}}

		reqTryCatchClause(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(CatchClause)>(Y) ~ SyntaxError # {{{
		{
			var dyn binding
			if @test(Token.IDENTIFIER) {
				binding = @reqIdentifier()
			}

			@NL_0M()

			var body = @reqBlock(NO, null, fMode)

			return @yep(AST.CatchClause(binding, null, body, first, body))
		} # }}}

		reqTryExpression(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(TryExpression)>(Y) ~ SyntaxError # {{{
		{
			var modifiers = []
			if @testNS(Token.EXCLAMATION) {
				modifiers.push(AST.Modifier(ModifierKind.Disabled, @yes()))
			}

			var operand = @reqPrefixedOperand(.Nil, fMode)

			var dyn default = null

			if @test(Token.TILDE) {
				@commit()

				default = @reqPrefixedOperand(.Nil, fMode)
			}

			return @yep(AST.TryExpression(modifiers, operand, default, first, default ?? operand))
		} # }}}

		reqTupleStatement(
			first: Event(Y)
		): Event<NodeData(TupleDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryTupleStatement(first)

			if statement.ok {
				return statement
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqType(
			modifiers: Event<ModifierData>(Y)[] = []
			multiline: Boolean = false
			eMode: ExpressionMode = .InlineOnly
		): Event<NodeData(Type)>(Y) ~ SyntaxError # {{{
		{
			var type = @tryType(modifiers, multiline, eMode)

			if type.ok {
				return type
			}
			else {
				@throw('type')
			}
		} # }}}

		reqTypeArray(
			modifiers: Event<ModifierData>(Y)[]
			multiline: Boolean
			first: Event(Y)
			eMode: ExpressionMode
		): Event<NodeData(Type)>(Y) ~ SyntaxError # {{{
		{
			var properties: Event<NodeData(PropertyType)>(Y)[] = []
			var mut rest = null

			@NL_0M()

			while @until(Token.RIGHT_SQUARE) {
				if @test(Token.COMMA) {
					var first = @yep()
					var property = @yep(AST.PropertyType([], null, null, first, first))

					properties.push(property)

					@commit().NL_0M()
				}
				else {
					@NL_0M()

					if @test(Token.DOT_DOT_DOT) {
						if ?rest {
							@throw('Identifier')
						}

						var first = @yes()
						var modifier = @yep(AST.RestModifier(0, Infinity, first, first))
						var type = @tryType([], multiline, eMode)

						if type.ok {
							rest = @yep(AST.PropertyType([modifier], null, type, first, type))
						}
						else {
							rest = @yep(AST.PropertyType([modifier], null, null, first, first))
						}
					}
					else {
						var type = @reqType([], multiline)

						var property = @yep(AST.PropertyType([], null, type, type, type))

						properties.push(property)
					}

					if @test(Token.COMMA) {
						@commit().NL_0M()
					}
					else if @test(Token.NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}
			}

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			var type = @yep(AST.ArrayType(modifiers, properties, rest, first, @yes()))

			return @altTypeContainer(type)
		} # }}}

		reqTypeCore(
			modifiers: Event<ModifierData>(Y)[]
			multiline: Boolean
			eMode: ExpressionMode
		): Event<NodeData(Type)>(Y) ~ SyntaxError # {{{
		{
			var type = @tryTypeCore(modifiers, multiline, eMode)

			if type.ok {
				return type
			}
			else {
				@throw('type')
			}
		} # }}}

		reqTypeDescriptive(
			tMode: TypeMode = .Nil
		): Event<NodeData(DescriptiveType)>(Y) ~ SyntaxError # {{{
		{
			var type = @tryTypeDescriptive(tMode)

			if type.ok {
				return type
			}
			else {
				// TODO!
				// @throw(...?type.expecteds ## 'type')
				if ?type.expecteds {
					@throw(...type.expecteds)
				}
				else {
					@throw('type')
				}
			}
		} # }}}

		reqTypeLimited(
			modifiers: Event<ModifierData>(Y)[] = []
			nullable: Boolean = true
			eMode: ExpressionMode = .Nil
		): Event<NodeData(Type)>(Y) ~ SyntaxError # {{{
		{
			var type = @tryTypeLimited(modifiers, eMode)

			if type.ok {
				return @altTypeContainer(type, nullable)
			}
			else {
				@throw()
			}
		} # }}}

		reqTypeEntity(): Event<NodeData(TypeReference)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifierOrMember()

			return @yep(AST.TypeReference(name))
		} # }}}

		reqTypeGeneric(
			first: Event(Y)
		): Event<Event<NodeData(TypeReference)>[]>(Y) ~ SyntaxError # {{{
		{
			var types = [@reqTypeEntity()]

			while @test(Token.COMMA) {
				@commit()

				types.push(@reqTypeEntity())
			}

			unless @test(Token.RIGHT_ANGLE) {
				@throw('>')
			}

			return @yes(types)
		} # }}}

		reqTypeModule(
			first: Event(Y)
		): Event<NodeData(TypeList)>(Y) ~ SyntaxError # {{{
		{
			@reqNL_1M()

			var types = []
			var attributes = []
			var mut attrs = []

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				var type = @reqTypeDescriptive(TypeMode.Module)

				@reqNL_1M()

				AST.pushAttributes(type.value, attrs)

				types.push(type)
			}

			@throw('}') unless @test(Token.RIGHT_CURLY)

			return @yep(AST.TypeList(attributes, types, first, @yes()))
		} # }}}

		reqTypeNamed(
			modifiers: Event<ModifierData>(Y)[]
		): Event<NodeData(TypeReference)>(Y) ~ SyntaxError # {{{
		{
			var type = @tryTypeNamed(modifiers)

			if type.ok {
				return type
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqTypeObject(
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)
			eMode: ExpressionMode
		): Event<NodeData(Type)>(Y) ~ SyntaxError # {{{
		{
			var properties = []
			var mut rest = null

			@NL_0M()

			until @test(Token.RIGHT_CURLY) {
				var mark = @mark()
				var mut nf = true

				if @test(Token.ASYNC) {
					var async = @yes()

					if @test(Token.FUNC) {
						@commit()
					}

					var identifier = @tryIdentifier()

					if identifier.ok && @test(Token.LEFT_ROUND) {
						var modifiers = [@yep(AST.Modifier(ModifierKind.Async, async))]
						var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
						var type = @tryFunctionReturns(eMode, false)
						var throws = @tryFunctionThrows()

						var objectType = @yep(AST.FunctionExpression(parameters, modifiers, type, throws, null, parameters, (throws ?? type ?? parameters)!!))

						var property = @yep(AST.PropertyType([], identifier, objectType, identifier, objectType))

						properties.push(property)

						nf = false
					}
					else {
						@rollback(mark)
					}
				}

				if nf && @test(Token.FUNC) {
					var first = @yes()
					var identifier = @tryIdentifier()

					if identifier.ok && @test(Token.LEFT_ROUND) {
						var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
						var type = @tryFunctionReturns(eMode, false)
						var throws = @tryFunctionThrows()

						var objectType = @yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, (throws ?? type ?? parameters)!!))

						var property = @yep(AST.PropertyType([], identifier, objectType, identifier, objectType))

						properties.push(property)

						nf = false
					}
					else {
						@rollback(mark)
					}
				}

				if nf && @test(.VARIANT) {
					var first = @yes()
					var identifier = @tryIdentifier()

					if identifier.ok && @test(.COLON) {
						@commit()

						var name = @reqIdentifierOrMember()
						var master = @yep(AST.TypeReference(name))
						var elements = []

						if @test(.LEFT_CURLY) {
							@commit()

							@reqVariantFieldList(elements)
						}

						var objectType = @yep(AST.VariantType(master, elements, master, @yes()))

						var property = @yep(AST.PropertyType([], identifier, objectType, first, objectType))

						properties.push(property)

						nf = false
					}
					else {
						@rollback(mark)
					}
				}

				if nf && @test(Token.DOT_DOT_DOT) {
					if ?rest {
						@throw('Identifier')
					}

					var first = @yes()
					var modifier = @yep(AST.RestModifier(0, Infinity, first, first))
					var type = @tryType(eMode)

					if type.ok {
						rest = @yep(AST.PropertyType([modifier], null, type, first, type))
					}
					else {
						rest = @yep(AST.PropertyType([modifier], null, null, first, first))
					}

					nf = false
				}

				if nf {
					var identifier = @tryIdentifier()

					if identifier.ok {
						var modifiers = []
						var mut type = null

						if @test(.LEFT_ROUND) {
							var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
							var return = @tryFunctionReturns(eMode)
							var throws = @tryFunctionThrows()

							type = @yep(AST.FunctionExpression(parameters, null, return, throws, null, parameters, (throws ?? return ?? parameters)!!))
						}
						else if @test(.COLON) {
							@commit()

							type = @reqType()
						}
						else if @test(.QUESTION) {
							modifiers.push(@yep(AST.Modifier(.Nullable, @yes())))
						}

						var property = @yep(AST.PropertyType(modifiers, identifier, type, identifier, type ?? identifier))

						properties.push(property)

						nf = false
					}
				}

				if nf {
					@throw('Identifier', '...')
				}
				else {
					if @test(Token.COMMA) {
						@commit().NL_0M()
					}
					else if @test(Token.NEWLINE) {
						@commit().NL_0M()

						if @test(Token.COMMA) {
							@commit().NL_0M()
						}
					}
					else {
						break
					}
				}
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			var type = @yep(AST.ObjectType(modifiers, properties, rest, first, @yes()))

			return @altTypeContainer(type)
		} # }}}

		reqTypeParameter(): Event<NodeData(Type)>(Y) ~ SyntaxError # {{{
		{
			var type = @reqType()

			if @match(Token.PIPE_PIPE, Token.AMPERSAND_AMPERSAND) == Token.PIPE_PIPE {
				var types = [type]

				do {
					@commit()

					types.push(@reqType())
				}
				while @test(Token.PIPE_PIPE)

				return @yep(AST.UnionType(types, type, types[types.length - 1]))
			}
			else if @token == Token.AMPERSAND_AMPERSAND {
				var types = [type]

				do {
					@commit()

					types.push(@reqType())
				}
				while @test(Token.AMPERSAND_AMPERSAND)

				return @yep(AST.UnionType(types, type, types[types.length - 1]))
			}
			else {
				return type
			}
		} # }}}

		reqTypeReturn(
			eMode: ExpressionMode = .InlineOnly
		): Event<NodeData(Type)>(Y) ~ SyntaxError # {{{
		{
			match @match(.NEW, .VALUEOF) {
				.NEW {
					var operator = @yep(AST.UnaryTypeOperator(.NewInstance, @yes()))
					var operand = @reqType(eMode)

					return @yep(AST.UnaryTypeExpression([], operator, operand, operator, operand))
				}
				.VALUEOF {
					var operator = @yep(AST.UnaryTypeOperator(.ValueOf, @yes()))
					var operand = @reqUnaryOperand(null, eMode, eMode ~~ .AtThis ? .Method : .Nil)

					return @yep(AST.UnaryTypeExpression([], operator, operand, operator, operand))
				}
				else {
					return @reqType(eMode)
				}
			}
		} # }}}

		reqTypeStatement(
			first: Event(Y)
			name: Event<NodeData(Identifier)>(Y)
		): Event<NodeData(TypeAliasDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var parameters = @tryTypeParameterList()

			unless @test(.EQUALS) {
				@throw('=')
			}

			@commit().NL_0M()

			var type = @reqType(true, .InlineOnly)

			return @yep(AST.TypeAliasDeclaration(name, parameters, type, first, type))
		} # }}}

		reqTypedVariable(
			fMode: FunctionMode
			typeable: Boolean = true
			questionable: Boolean = true
		): Event<NodeData(VariableDeclarator)>(Y) ~ SyntaxError # {{{
		{
			var mut name = null

			var dMode = if fMode ~~ .Method {
				set DestructuringMode.Declaration + DestructuringMode.THIS_ALIAS
			}
			else {
				set DestructuringMode.Declaration
			}

			if @match(.LEFT_CURLY, .LEFT_SQUARE) == .LEFT_CURLY {
				name = @reqDestructuringObject(@yes(), dMode, fMode)
			}
			else if @token == .LEFT_SQUARE {
				name = @reqDestructuringArray(@yes(), dMode, fMode)
			}
			else {
				name = @tryIdentifier()

				@throw('Identifier', '{', '[') unless name.ok
			}

			if typeable {
				if @test(.COLON) {
					@commit()

					var type = @reqType(fMode ~~ .Method ? .Method : .PrimaryType)

					return @yep(AST.VariableDeclarator([], name, type, name, type))
				}
				else if questionable && @test(.QUESTION) {
					var modifier = @yep(AST.Modifier(.Nullable, @yes()))

					return @yep(AST.VariableDeclarator([modifier], name, null, name, modifier))
				}
			}

			return @yep(AST.VariableDeclarator([], name, null, name, name))
		} # }}}

		reqUnaryOperand(
			value: Event<NodeData(Expression)>(Y)?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)>(Y) ~ SyntaxError # {{{
		{
			var operand = @tryUnaryOperand(value, eMode, fMode)

			if operand.ok {
				return operand
			}
			else {
				@throw(...?operand.expecteds)
			}
		} # }}}

		reqUnlessStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			var condition = @reqExpression(.Nil, fMode)

			@NL_0M()

			var whenFalse = @reqBlock(NO, null, fMode)

			return @yep(AST.UnlessStatement(condition, whenFalse, first, whenFalse))
		} # }}}

		reqVarStatement(
			first: Event(Y)
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(VariableStatement)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryVarStatement(first, eMode, fMode)

			if statement.ok {
				return statement
			}
			else {
				@throw('Identifier', '{', '[')
			}
		} # }}}

		reqVariable(): Event<NodeData(VariableDeclarator)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()

			return @yep(AST.VariableDeclarator([], name, null, name, name))
		} # }}}

		reqVariableIdentifier(
			fMode: FunctionMode
		): Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.IDENTIFIER, Token.LEFT_CURLY, Token.LEFT_SQUARE) == Token.IDENTIFIER {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else if @token == Token.LEFT_CURLY {
				return @reqDestructuringObject(@yes(), DestructuringMode.Expression, fMode)
			}
			else if @token == Token.LEFT_SQUARE {
				return @reqDestructuringArray(@yes(), DestructuringMode.Expression, fMode)
			}
			else {
				@throw('Identifier', '{', '[')
			}
		} # }}}

		reqVariableName(
			mut object: Event<NodeData(Identifier, MemberExpression, ThisExpression)>
			fMode: FunctionMode
		): Event<NodeData(Identifier, MemberExpression, ThisExpression)>(Y) ~ SyntaxError # {{{
		{
			if !object.ok {
				if fMode ~~ FunctionMode.Method && @test(Token.AT) {
					object = @reqThisExpression(@yes())
				}
				else {
					object = @reqIdentifier()
				}
			}

			var dyn property
			while true {
				if @match(Token.DOT, Token.LEFT_SQUARE) == Token.DOT {
					@commit()

					property = @reqIdentifier()

					object = @yep(AST.MemberExpression([], object, property))
				}
				else if @token == Token.LEFT_SQUARE {
					var modifiers = [AST.Modifier(ModifierKind.Computed, @yes())]

					property = @reqExpression(.Nil, fMode)

					unless @test(Token.RIGHT_SQUARE) {
						@throw(']')
					}

					object = @yep(AST.MemberExpression(modifiers, object, property, object, @yes()))
				}
				else {
					break
				}
			}

			return object
		} # }}}

		reqVariantFieldList(
			elements: NodeData(VariantField)[]
		): Void ~ SyntaxError # {{{
		{
			@NL_0M()

			while @until(.RIGHT_CURLY) {
				var names = [@reqIdentifier()]

				while @test(.COMMA) {
					@commit()

					names.push(@reqIdentifier())
				}

				if @test(.LEFT_CURLY) {
					var type = @reqTypeObject([], @yes(), .InlineOnly)

					@reqNL_1M()

					elements.push(AST.VariantField(names, type, names[0], type))
				}
				else {
					@reqNL_1M()

					elements.push(AST.VariantField(names, null, names[0], names[names.length - 1]))
				}
			}

			unless @test(.RIGHT_CURLY) {
				@throw('}')
			}
		} # }}}

		stackInlineAttributes(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
		): Event<NodeData(AttributeDeclaration)>(Y)[] ~ SyntaxError # {{{
		{
			while @test(Token.HASH_LEFT_SQUARE) {
				attributes.push(@reqAttribute(@yes(), false))
			}

			return attributes
		} # }}}

		stackInnerAttributes(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]): Boolean ~ SyntaxError # {{{
		{
			if @test(Token.HASH_EXCLAMATION_LEFT_SQUARE) {
				do {
					var first = @yes()
					var declaration = @reqAttributeMember()

					unless @test(Token.RIGHT_SQUARE) {
						@throw(']')
					}

					attributes.push(@yep(AST.AttributeDeclaration(declaration, first, @yes())))

					@reqNL_EOF_1M()
				}
				while @test(Token.HASH_EXCLAMATION_LEFT_SQUARE)

				return true
			}
			else {
				return false
			}
		} # }}}

		stackOuterAttributes(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
		): Event<NodeData(AttributeDeclaration)>(Y)[] ~ SyntaxError # {{{
		{
			while @test(Token.HASH_LEFT_SQUARE) {
				attributes.push(@reqAttribute(@yes(), true))

				@NL_0M()
			}

			return attributes
		} # }}}

		submitNamedGroupSpecifier(
			modifiers: Event<ModifierData>(Y)[]
			type: Event<NodeData(DescriptiveType)>(Y)?
			specifiers: Event<NodeData(GroupSpecifier)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var elements = []

			var name = @reqNameIB()

			elements.push(@yep(AST.NamedSpecifier(name)))

			while @test(Token.COMMA) {
				@commit()

				var name = @reqNameIB()

				elements.push(@yep(AST.NamedSpecifier(name)))
			}

			var first = ?#modifiers ? modifiers[0] : name
			var last = elements[elements.length - 1]

			specifiers.push(@yep(AST.GroupSpecifier(modifiers, elements, type, first, last)))
		} # }}}

		submitNamedSpecifier(
			modifiers: Event<ModifierData>(Y)[]
			specifiers: Event<NodeData(NamedSpecifier)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var identifier = @reqIdentifier()

			if @test(Token.EQUALS_RIGHT_ANGLE) {
				@commit()

				var internal = @reqNameIB()

				specifiers.push(@yep(AST.NamedSpecifier(modifiers, internal, identifier, identifier, internal)))
			}
			else {
				specifiers.push(@yep(AST.NamedSpecifier(modifiers, identifier, null, identifier, identifier)))
			}
		} # }}}

		tryAccessModifier(aMode: AccessMode): Event<ModifierData> ~ SyntaxError # {{{
		{
			if aMode ~~ .Private && @test(.PRIVATE) {
				return @yep(AST.Modifier(ModifierKind.Private, @yes()))
			}
			else if aMode ~~ .Protected && @test(.PROTECTED) {
				return @yep(AST.Modifier(ModifierKind.Protected, @yes()))
			}
			else if aMode ~~ .Public && @test(.PUBLIC) {
				return @yep(AST.Modifier(ModifierKind.Public, @yes()))
			}
			else if aMode ~~ .Internal && @test(.INTERNAL) {
				return @yep(AST.Modifier(ModifierKind.Internal, @yes()))
			}

			return NO
		} # }}}

		tryAssignementOperator(): Event<BinaryOperatorData(Assignment)> ~ SyntaxError # {{{
		{
			match @matchM(M.ASSIGNEMENT_OPERATOR) {
				.AMPERSAND_AMPERSAND_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalAnd, @yes()))
				}
				.ASTERISK_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Multiplication, @yes()))
				}
				.CARET_CARET_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalXor, @yes()))
				}
				.EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
				}
				.EXCLAMATION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NonExistential, @yes()))
				}
				.EXCLAMATION_QUESTION_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Empty, @yes()))
				}
				.LEFT_ANGLE_MINUS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Return, @yes()))
				}
				.MINUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Subtraction, @yes()))
				}
				.PERCENT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Modulo, @yes()))
				}
				.PIPE_PIPE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalOr, @yes()))
				}
				.PLUS_AMPERSAND_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseAnd, @yes()))
				}
				.PLUS_CARET_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseXor, @yes()))
				}
				.PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Addition, @yes()))
				}
				.PLUS_LEFT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseLeftShift, @yes()))
				}
				.PLUS_PIPE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseOr, @yes()))
				}
				.PLUS_RIGHT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseRightShift, @yes()))
				}
				.QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Existential, @yes()))
				}
				.QUESTION_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NonEmpty, @yes()))
				}
				.QUESTION_HASH_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.EmptyCoalescing, @yes()))
				}
				.QUESTION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NullCoalescing, @yes()))
				}
				.SLASH_DOT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Quotient, @yes()))
				}
				.SLASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Division, @yes()))
				}
			}

			return NO
		} # }}}

		tryAssignementStatement(
			eMode!: ExpressionMode = .Nil
			fMode: FunctionMode
		): Event<NodeData(ExpressionStatement)> ~ SyntaxError # {{{
		{
			var dyn identifier = NO

			var dMode: DestructuringMode = if fMode ~~ FunctionMode.Method {
				set DestructuringMode.Expression + DestructuringMode.THIS_ALIAS
			}
			else {
				set DestructuringMode.Expression
			}

			if @match(Token.IDENTIFIER, Token.LEFT_CURLY, Token.LEFT_SQUARE, Token.AT) == Token.IDENTIFIER {
				identifier = @tryUnaryOperand(@reqIdentifier(), eMode + .InlineOnly, fMode)
			}
			else if @token == Token.LEFT_CURLY {
				identifier = @tryDestructuringObject(@yes(), dMode, fMode)
			}
			else if @token == Token.LEFT_SQUARE {
				identifier = @tryDestructuringArray(@yes(), dMode, fMode)
			}
			else if fMode ~~ FunctionMode.Method && @token == Token.AT {
				identifier = @tryUnaryOperand(@reqThisExpression(@yes()), eMode, fMode)
			}

			unless identifier.ok {
				return NO
			}

			// TODO!
			// var expression = if @match(Token.COMMA, Token.EQUALS) == Token.COMMA {
			var mut statement: Event<NodeData(Expression)>(Y)? = null

			if @match(Token.COMMA, Token.EQUALS) == Token.COMMA {
				unless identifier.value.kind == NodeKind.Identifier || identifier.value.kind == NodeKind.ArrayBinding || identifier.value.kind == NodeKind.ObjectBinding {
					return NO
				}

				var variables = [identifier]

				do {
					@commit()

					variables.push(@reqVariableIdentifier(fMode))
				}
				while @test(Token.COMMA)

				if @test(Token.EQUALS) {
					@validateAssignable(identifier.value)

					@commit().NL_0M()

					unless @test(Token.AWAIT) {
						@throw('await')
					}

					var operand = @reqPrefixedOperand(eMode, fMode)

					statement = @yep(AST.AwaitExpression([], variables, operand, identifier, operand))
				}
				else {
					@throw('=')
				}
			}
			else if @token == Token.EQUALS {
				@validateAssignable(identifier.value)

				var equals = @yes()

				@NL_0M()

				var expression = @reqExpression(eMode + .ImplicitMember + .NoRestriction, fMode)

				statement = @yep(AST.BinaryExpression(identifier, @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, equals)), expression, identifier, expression))
			}
			else {
				return NO
			}

			statement = @altRestrictiveExpression(statement, fMode)

			return @yep(AST.ExpressionStatement(statement))
		} # }}}

		tryAwaitExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(AwaitExpression)> ~ SyntaxError # {{{
		{
			unless @test(Token.AWAIT) {
				return NO
			}

			try {
				return @reqAwaitExpression(@yes(), eMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}

		tryBinaryOperand(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			var mark = @mark()
			var mut expression = null

			if (expression <- @tryAwaitExpression(eMode, fMode)).ok {
				return expression
			}
			else if @rollback(mark) && (expression <- @tryFunctionExpression(eMode, fMode)).ok {
				return expression
			}
			else if @rollback(mark) && (expression <- @tryIfExpression(eMode, fMode)).ok {
				return expression
			}
			else if @rollback(mark) && (expression <- @tryMatchExpression(eMode, fMode)).ok {
				return expression
			}
			else if @rollback(mark) && (expression <- @tryTryExpression(eMode, fMode)).ok {
				return expression
			}

			@rollback(mark)

			return @tryPrefixedOperand(eMode, fMode)
		} # }}}

		tryBinaryOperator(
			fMode: FunctionMode
		): Event<BinaryOperatorData> ~ SyntaxError # {{{
		{
			match @matchM(M.BINARY_OPERATOR, null, fMode) {
				Token.AMPERSAND_AMPERSAND {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.LogicalAnd, @yes()))
				}
				Token.AMPERSAND_AMPERSAND_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalAnd, @yes()))
				}
				Token.ASTERISK {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Multiplication, @yes()))
				}
				Token.ASTERISK_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Multiplication, @yes()))
				}
				Token.ASTERISK_PIPE_RIGHT_ANGLE {
					var modifiers = [AST.Modifier(ModifierKind.Wildcard, @position(0, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.ForwardPipeline, @yes()))
				}
				Token.ASTERISK_PIPE_RIGHT_ANGLE_HASH {
					var modifiers = [AST.Modifier(ModifierKind.Wildcard, @position(0, 1)), AST.Modifier(ModifierKind.NonEmpty, @position(3, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.ForwardPipeline, @yes()))
				}
				Token.ASTERISK_PIPE_RIGHT_ANGLE_QUESTION {
					var modifiers = [AST.Modifier(ModifierKind.Wildcard, @position(0, 1)), AST.Modifier(ModifierKind.Existential, @position(3, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.ForwardPipeline, @yes()))
				}
				Token.CARET_CARET {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.LogicalXor, @yes()))
				}
				Token.CARET_CARET_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalXor, @yes()))
				}
				Token.EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
				}
				Token.EQUALS_EQUALS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Equality, @yes()))
				}
				Token.EXCLAMATION_EQUALS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Inequality, @yes()))
				}
				Token.EXCLAMATION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NonExistential, @yes()))
				}
				Token.EXCLAMATION_QUESTION_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Empty, @yes()))
				}
				Token.EXCLAMATION_TILDE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Mismatch, @yes()))
				}
				Token.HASH_LEFT_ANGLE_PIPE {
					var modifiers = [AST.Modifier(ModifierKind.NonEmpty, @position(0, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.BackwardPipeline, @yes()))
				}
				Token.HASH_LEFT_ANGLE_PIPE_ASTERISK {
					var modifiers = [AST.Modifier(ModifierKind.NonEmpty, @position(0, 1)), AST.Modifier(ModifierKind.Wildcard, @position(3, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.BackwardPipeline, @yes()))
				}
				Token.LEFT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.LessThan, @yes()))
				}
				Token.LEFT_ANGLE_EQUALS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.LessThanOrEqual, @yes()))
				}
				Token.LEFT_ANGLE_MINUS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Return, @yes()))
				}
				Token.LEFT_ANGLE_PIPE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.BackwardPipeline, @yes()))
				}
				Token.LEFT_ANGLE_PIPE_ASTERISK {
					var modifiers = [AST.Modifier(ModifierKind.Wildcard, @position(2, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.BackwardPipeline, @yes()))
				}
				Token.MINUS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Subtraction, @yes()))
				}
				Token.MINUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Subtraction, @yes()))
				}
				Token.MINUS_RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.LogicalImply, @yes()))
				}
				Token.PERCENT {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Modulo, @yes()))
				}
				Token.PERCENT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Modulo, @yes()))
				}
				Token.PIPE_RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.ForwardPipeline, @yes()))
				}
				Token.PIPE_RIGHT_ANGLE_HASH {
					var modifiers = [AST.Modifier(ModifierKind.NonEmpty, @position(2, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.ForwardPipeline, @yes()))
				}
				Token.PIPE_RIGHT_ANGLE_QUESTION {
					var modifiers = [AST.Modifier(ModifierKind.Existential, @position(2, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.ForwardPipeline, @yes()))
				}
				Token.PIPE_PIPE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.LogicalOr, @yes()))
				}
				Token.PIPE_PIPE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalOr, @yes()))
				}
				.PLUS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Addition, @yes()))
				}
				.PLUS_AMPERSAND {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.BitwiseAnd, @yes()))
				}
				.PLUS_AMPERSAND_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseAnd, @yes()))
				}
				.PLUS_CARET {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.BitwiseXor, @yes()))
				}
				.PLUS_CARET_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseXor, @yes()))
				}
				.PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Addition, @yes()))
				}
				.PLUS_LEFT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.BitwiseLeftShift, @yes()))
				}
				.PLUS_LEFT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseLeftShift, @yes()))
				}
				.PLUS_PIPE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.BitwiseOr, @yes()))
				}
				.PLUS_PIPE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseOr, @yes()))
				}
				.PLUS_RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.BitwiseRightShift, @yes()))
				}
				.PLUS_RIGHT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseRightShift, @yes()))
				}
				Token.QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Existential, @yes()))
				}
				Token.QUESTION_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NonEmpty, @yes()))
				}
				Token.QUESTION_HASH_HASH {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.EmptyCoalescing, @yes()))
				}
				Token.QUESTION_HASH_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.EmptyCoalescing, @yes()))
				}
				Token.QUESTION_LEFT_ANGLE_PIPE {
					var modifiers = [AST.Modifier(ModifierKind.Existential, @position(0, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.BackwardPipeline, @yes()))
				}
				Token.QUESTION_LEFT_ANGLE_PIPE_ASTERISK {
					var modifiers = [AST.Modifier(ModifierKind.Existential, @position(0, 1)), AST.Modifier(ModifierKind.Wildcard, @position(3, 1))]

					return @yep(AST.BinaryOperator(modifiers, BinaryOperatorKind.BackwardPipeline, @yes()))
				}
				Token.QUESTION_QUESTION {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.NullCoalescing, @yes()))
				}
				Token.QUESTION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NullCoalescing, @yes()))
				}
				Token.RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.GreaterThan, @yes()))
				}
				Token.RIGHT_ANGLE_EQUALS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.GreaterThanOrEqual, @yes()))
				}
				Token.SLASH {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Division, @yes()))
				}
				Token.SLASH_DOT {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Quotient, @yes()))
				}
				Token.SLASH_DOT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Quotient, @yes()))
				}
				Token.SLASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Division, @yes()))
				}
				Token.TILDE_TILDE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.Match, @yes()))
				}
			}

			return NO
		} # }}}

		tryBitmaskMember(
			mut attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			mut first: Range?
		): Event<NodeData(BitmaskValue, MethodDeclaration)> ~ SyntaxError # {{{
		{
			if bits ~~ .Attribute {
				var attrs = @stackOuterAttributes([])

				if attrs.length != 0 {
					attributes = [...attributes, ...attrs]
					first ??= attrs[0]
				}
			}

			var mark = @mark()

			if bits ~~ .Method {
				var method = @tryEnumMethod(attributes, modifiers, bits, first)

				if method.ok {
					return method
				}

				@rollback(mark)
			}

			if bits ~~ .Value {
				var value = @tryBitmaskValue(attributes, modifiers, bits, first)

				if value.ok {
					return value
				}
			}

			return NO
		} # }}}

		tryBitmaskStatement(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[] = []
		): Event<NodeData(BitmaskDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()
			unless name.ok {
				return NO
			}

			var mut type = null

			if @test(Token.LEFT_ANGLE) {
				@commit()

				var identifier = @tryIdentifier()

				if identifier.ok {
					unless identifier.value.name == 'u8' | 'u16' | 'u32' | 'u48' | 'u64' | 'u128' | 'u256' {
						@throw('u8', 'u16', 'u32', 'u48', 'u64', 'u128', 'u256')
					}

					type = identifier
				}

				unless @test(Token.RIGHT_ANGLE) {
					@throw('>')
				}

				@commit()
			}

			@NL_0M()

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			// TODO!
			// var attributes = []
			// var members = []
			var attributes: Event<NodeData(AttributeDeclaration)>(Y)[] = []
			var members: NodeData(BitmaskValue, MethodDeclaration)[] = []

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					pass
				}
				else {
					@reqBitmaskMemberList(members)
				}
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.BitmaskDeclaration(attributes, modifiers, name, type, members, first, @yes()))
		} # }}}

		tryBitmaskValue(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<NodeData(BitmaskValue)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			return NO unless name.ok

			var mut value = null

			if @test(Token.EQUALS) {
				@commit()

				value = @reqExpression(.ImplicitMember, .Method)
			}

			@reqNL_1M()

			return @yep(AST.BitmaskValue(attributes, modifiers, name, value, (first ?? name)!!, (value ?? name)!!))
		} # }}}

		tryBlock(
			fMode: FunctionMode
		): Event<NodeData(Block)> ~ SyntaxError # {{{
		{
			try {
				return @reqBlock(NO, null, fMode)
			}
			catch {
				return NO
			}
		} # }}}

		tryBlockStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(BlockStatement)> ~ SyntaxError # {{{
		{
			var label = @tryIdentifier()

			unless label.ok {
				return NO
			}

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			var body = @reqBlock(@yes(), null, fMode)

			return @yep(AST.BlockStatement(label, body, first, body))
		} # }}}

		tryClassMember(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			staticModifier: Event<ModifierData>
			staticMark: Marker
			finalModifier: Event<ModifierData>
			finalMark: Marker
			first: Range?
		): Event<NodeData(FieldDeclaration, MethodDeclaration, PropertyDeclaration, ProxyDeclaration)> ~ SyntaxError # {{{
		{
			if staticModifier.ok {
				if finalModifier.ok {
					var member = @tryClassMember(
						attributes
						[...modifiers, staticModifier, finalModifier]
						MemberBits.Variable + MemberBits.LateVariable + MemberBits.Property + MemberBits.Method
						first ?? staticModifier
					)

					if member.ok {
						return member
					}

					@rollback(finalMark)
				}

				var member = @tryClassMember(
					attributes
					[...modifiers, staticModifier]
					MemberBits.Variable + MemberBits.FinalVariable + MemberBits.LateVariable + MemberBits.Property + MemberBits.Method + MemberBits.FinalMethod + MemberBits.Proxy
					first ?? staticModifier
				)

				if member.ok {
					return member
				}

				@rollback(staticMark)
			}
			else if finalModifier.ok {
				var member = @tryClassMember(
					attributes
					[...modifiers, finalModifier]
					MemberBits.Variable + MemberBits.RequiredAssignment + MemberBits.Property + MemberBits.Method
					first ?? finalModifier
				)

				if member.ok {
					return member
				}

				@rollback(finalMark)
			}

			return @tryClassMember(
				attributes
				[...modifiers]
				MemberBits.Variable + MemberBits.FinalVariable + MemberBits.LateVariable + MemberBits.Property + MemberBits.Method + MemberBits.AssistMethod + MemberBits.OverrideMethod + MemberBits.AbstractMethod + MemberBits.Proxy
				first
			)
		} # }}}

		tryClassMember(
			mut attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			mut first: Range?
		): Event<NodeData(FieldDeclaration, MethodDeclaration, PropertyDeclaration, ProxyDeclaration)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			if bits ~~ MemberBits.Attribute {
				var attrs = @stackOuterAttributes([])
				if attrs.length != 0 {
					attributes = [...attributes, ...attrs]
					first ??= attrs[0]
				}
			}

			if bits ~~ MemberBits.Method {
				var mark = @mark()

				if bits ~~ MemberBits.AbstractMethod && @test(Token.ABSTRACT) {
					var modifier = @yep(AST.Modifier(ModifierKind.Abstract, @yes()))

					var method = @tryClassMethod(
						attributes
						[...modifiers, modifier]
						bits + MemberBits.NoBody
						first ?? modifier
					)

					if method.ok {
						return method
					}

					@rollback(mark)
				}
				else if bits ~~ MemberBits.FinalMethod && @test(.FINAL) {
					var modifier = @yep(AST.Modifier(.Final, @yes()))
					var mark2 = @mark()

					if bits ~~ MemberBits.AssistMethod && @test(.ASSIST) {
						var modifier2 = @yep(AST.Modifier(.Assist, @yes()))
						var method = @tryClassMethod(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

						if method.ok {
							return method
						}

						@rollback(mark2)
					}
					else if bits ~~ MemberBits.OverrideMethod && @test(.OVERRIDE) {
						var modifier2 = @yep(AST.Modifier(ModifierKind.Override, @yes()))
						var method = @tryClassMethod(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

						if method.ok {
							return method
						}

						if bits ~~ MemberBits.OverrideProperty {
							var property = @tryClassProperty(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

							if property.ok {
								return property
							}
						}

						@rollback(mark2)
					}
					else if bits ~~ MemberBits.OverwriteMethod && @test(Token.OVERWRITE) {
						var modifier2 = @yep(AST.Modifier(ModifierKind.Overwrite, @yes()))
						var method = @tryClassMethod(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

						if method.ok {
							return method
						}

						@rollback(mark2)
					}

					var method = @tryClassMethod(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if method.ok {
						return method
					}

					@rollback(mark)
				}
				else if bits ~~ MemberBits.AssistMethod && @test(.ASSIST) {
					var modifier = @yep(AST.Modifier(.Assist, @yes()))

					var method = @tryClassMethod(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if method.ok {
						return method
					}

					@rollback(mark)
				}
				else if bits ~~ MemberBits.OverrideMethod && @test(Token.OVERRIDE) {
					var modifier = @yep(AST.Modifier(ModifierKind.Override, @yes()))

					var method = @tryClassMethod(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if method.ok {
						return method
					}

					if bits ~~ MemberBits.OverrideProperty {
						var property = @tryClassProperty(attributes, [...modifiers, modifier], bits, first ?? modifier)

						if property.ok {
							return property
						}
					}

					@rollback(mark)
				}
				else if bits ~~ MemberBits.OverwriteMethod && @test(Token.OVERWRITE) {
				}

				var method = @tryClassMethod(attributes, modifiers, bits, first)

				if method.ok {
					return method
				}

				@rollback(mark)
			}

			if bits ~~ MemberBits.Property {
				var mark = @mark()

				if bits ~~ MemberBits.OverrideProperty && @test(Token.OVERRIDE) {
					var modifier = @yep(AST.Modifier(ModifierKind.Override, @yes()))
					var property = @tryClassProperty(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if property.ok {
						return property
					}

					@rollback(mark)
				}

				var property = @tryClassProperty(attributes, modifiers, bits, first)

				if property.ok {
					return property
				}

				@rollback(mark)
			}

			if bits ~~ MemberBits.Proxy && @test(Token.PROXY) {
				var mark = @mark()
				var keyword = @yes()

				var proxy = @tryClassProxy(attributes, modifiers, first ?? keyword)

				if proxy.ok {
					return proxy
				}

				@rollback(mark)
			}

			if bits ~~ MemberBits.Variable {
				var mark = @mark()

				if bits ~~ MemberBits.FinalVariable && @test(.FINAL) {
					var modifier = @yep(AST.Modifier(.Final, @yes()))
					var mark2 = @mark()

					if bits ~~ MemberBits.LateVariable && @test(.LATE) {
						var modifier2 = @yep(AST.Modifier(.LateInit, @yes()))
						var method = @tryClassVariable(
							attributes
							[...modifiers, modifier, modifier2]
							bits - MemberBits.RequiredAssignment
							null
							null
							first ?? modifier
						)

						if method.ok {
							return method
						}

						@rollback(mark2)
					}

					var variable = @tryClassVariable(
						attributes
						[...modifiers, modifier]
						bits + MemberBits.RequiredAssignment
						null
						null
						first ?? modifier
					)

					if variable.ok {
						return variable
					}

					@rollback(mark)
				}
				else if bits ~~ MemberBits.LateVariable && @test(Token.LATE) {
					var modifier = @yep(AST.Modifier(ModifierKind.LateInit, @yes()))
					var method = @tryClassVariable(
						attributes
						[...modifiers, modifier]
						bits - MemberBits.RequiredAssignment
						null
						null
						first ?? modifier
					)

					if method.ok {
						return method
					}

					@rollback(mark)
				}

				var variable = @tryClassVariable(attributes, modifiers, bits, null, null, first)

				if variable.ok {
					return variable
				}
			}

			@rollback(mark)

			return NO
		} # }}}

		tryClassMethod(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<NodeData(MethodDeclaration)> ~ SyntaxError # {{{
		{
			var dyn name
			if @test(Token.ASYNC) {
				var dyn modifier = @reqIdentifier()

				name = @tryIdentifier()

				if name.ok {
					modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind.Async, modifier))]
					first = modifier
				}
				else {
					name = modifier
				}
			}
			else {
				name = @tryIdentifier()

				unless name.ok {
					return NO
				}
			}

			if @test(.LEFT_ROUND, .LEFT_ANGLE) {
				return @reqClassMethod(attributes, [...modifiers], bits, name, first ?? name)
			}

			return NO
		} # }}}

		tryClassProperty(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<NodeData(FieldDeclaration, PropertyDeclaration)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			if @test(Token.AT) {
				var modifier = @yep(AST.Modifier(ModifierKind.ThisAlias, @yes()))

				modifiers = [...modifiers, modifier]
				first ??= modifier
			}

			var name = @tryIdentifier()

			unless name.ok {
				@rollback(mark)

				return NO
			}

			var mut type: Event = NO

			if @test(Token.COLON) {
				@commit()

				type = @reqType(.Method)
			}

			if @test(Token.LEFT_CURLY) {
				@commit()

				return @reqClassProperty(attributes, modifiers, name, type, first ?? name)
			}
			else if type.ok && bits ~~ MemberBits.Variable {
				return @tryClassVariable(attributes, modifiers, bits, name, type, first)
			}

			return NO
		} # }}}

		tryClassProxy(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			mut first: Range?
		): Event<NodeData(ProxyDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			unless @test(Token.EQUALS) {
				return NO
			}

			@commit()

			unless @test(Token.AT) {
				@throw('@')
			}

			var target = @reqExpression(.Nil, .Method)

			@reqNL_1M()

			return @yep(AST.ProxyDeclaration(attributes, modifiers, name, target, first ?? name, target ?? name))
		} # }}}

		tryClassStatement(
			modifiers: Event<ModifierData>(Y)[] = []
			first: Event(Y)
		): Event<NodeData(ClassDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			return @reqClassStatementBody(modifiers, name, first)
		} # }}}

		tryClassVariable(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut name: Event<NodeData(Identifier)>(Y)?
			mut type: Event<NodeData(Type)>(Y)?
			mut first: Range?
		): Event<NodeData(FieldDeclaration)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			if !?name {
				if @test(Token.AT) {
					var modifier = @yep(AST.Modifier(ModifierKind.ThisAlias, @yes()))

					modifiers = [...modifiers, modifier]
					first ??= modifier
				}

				var identifier = @tryIdentifier()

				unless identifier.ok {
					@rollback(mark)

					return NO
				}

				name = identifier
			}

			if !?type {
				if @test(Token.COLON) {
					@commit()

					type = @reqType(Function.Method)
				}
				else if @test(Token.QUESTION) {
					modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind.Nullable, @yes()))]
				}
			}

			var dyn value
			if bits ~~ MemberBits.NoAssignment {
				pass
			}
			else if @test(Token.EQUALS) {
				@commit()

				value = @reqExpression(.ImplicitMember, .Method)
			}
			else if bits ~~ MemberBits.RequiredAssignment {
				@throw('=')
			}

			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, value, (first ?? name)!!, (value ?? type ?? name)!!))
		} # }}}

		tryConstModifier(): Event<ModifierData> ~ SyntaxError # {{{
		{
			if @test(.CONST) {
				return @yep(AST.Modifier(.Constant, @yes()))
			}

			return NO
		} # }}}

		tryConstStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(VariableStatement)> ~ SyntaxError # {{{
		{
			var modifier = @yep(AST.Modifier(.Constant, first))

			return @tryVarImmuStatement([modifier], first, eMode, fMode)
		} # }}}

		tryDefaultAssignmentOperator(
			typed: Boolean
		): Event<BinaryOperatorData(Assignment)> ~ SyntaxError # {{{
		{
			if typed {
				if @test(Token.EQUALS) {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
				}
				else if @test(Token.QUESTION_QUESTION_EQUALS) {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NullCoalescing, @yes()))
				}
				else if @test(Token.QUESTION_HASH_HASH_EQUALS) {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.EmptyCoalescing, @yes()))
				}
			}
			else {
				if @test(Token.QUESTION_EQUALS) {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Existential, @yes()))
				}
				else if @test(Token.QUESTION_HASH_EQUALS) {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NonEmpty, @yes()))
				}
			}

			return NO
		} # }}}

		tryDestructuring(
			mut dMode: DestructuringMode?
			fMode: FunctionMode
		): Event<NodeData(ArrayBinding, ObjectBinding)> ~ SyntaxError # {{{
		{
			if !?dMode {
				if fMode ~~ FunctionMode.Method {
					dMode = DestructuringMode.Expression + DestructuringMode.THIS_ALIAS
				}
				else {
					dMode = DestructuringMode.Expression
				}
			}

			if @match(Token.LEFT_CURLY, Token.LEFT_SQUARE) == Token.LEFT_CURLY {
				try {
					return @reqDestructuringObject(@yes(), dMode, fMode)
				}
			}
			else if @token == Token.LEFT_SQUARE {
				try {
					return @reqDestructuringArray(@yes(), dMode, fMode)
				}
			}

			return NO
		} # }}}

		tryDestructuringArray(
			first: Range
			dMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(ArrayBinding)> ~ SyntaxError # {{{
		{
			try {
				return @reqDestructuringArray(first, dMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}

		tryDestructuringObject(
			first: Event(Y)
			dMode: DestructuringMode
			fMode: FunctionMode
		): Event<NodeData(ObjectBinding)> ~ SyntaxError # {{{
		{
			try {
				return @reqDestructuringObject(first, dMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}

		tryEnumMember(
			mut attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			mut first: Range?
		): Event<NodeData(EnumValue, FieldDeclaration, MethodDeclaration)> ~ SyntaxError # {{{
		{
			if bits ~~ .Attribute {
				var attrs = @stackOuterAttributes([])

				if attrs.length != 0 {
					attributes = [...attributes, ...attrs]
					first ??= attrs[0]
				}
			}

			var mark = @mark()

			if bits ~~ .Method {
				var method = @tryEnumMethod(attributes, modifiers, bits, first)

				if method.ok {
					return method
				}

				@rollback(mark)
			}

			if bits ~~ .Value {
				var value = @tryEnumValue(attributes, modifiers, bits, first)

				if value.ok {
					return value
				}
			}

			if bits ~~ .Variable {
				var variable = @tryEnumVariable(attributes, modifiers, bits, first)

				if variable.ok {
					return variable
				}

				@rollback(mark)
			}

			return NO
		} # }}}

		tryEnumMethod(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<NodeData(MethodDeclaration)> ~ SyntaxError # {{{
		{
			var dyn name
			if @test(Token.ASYNC) {
				var dyn modifier = @reqIdentifier()

				name = @tryIdentifier()

				if name.ok {
					modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind.Async, modifier))]
					first = modifier
				}
				else {
					name = modifier
				}
			}
			else {
				name = @tryIdentifier()

				unless name.ok {
					return NO
				}
			}

			if @test(.LEFT_ROUND, .LEFT_ANGLE) {
				return @reqEnumMethod(attributes, [...modifiers], bits, name, first ?? name)
			}

			return NO
		} # }}}

		tryEnumStatement(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[] = []
		): Event<NodeData(EnumDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()
			unless name.ok {
				return NO
			}

			var mut type = null
			var mut init = null
			var mut step = null

			if @test(Token.LEFT_ANGLE) {
				@commit()

				type = @reqTypeEntity()

				if @test(.SEMICOLON) {
					@commit()

					init = @reqUnaryOperand(null, .Nil, .Nil)

					if @test(.SEMICOLON) {
						@commit()

						step = @reqUnaryOperand(null, .Nil, .Nil)
					}
				}

				unless @test(Token.RIGHT_ANGLE) {
					@throw('>')
				}

				@commit()
			}

			@NL_0M()

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var attributes = []
			var members = []

			while @until(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					pass
				}
				else {
					@reqEnumMemberList(members)
				}
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.EnumDeclaration(attributes, modifiers, name, type, init, step, members, first, @yes()))
		} # }}}

		tryEnumValue(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<NodeData(EnumValue)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			return NO unless name.ok

			var mut arguments = null
			var mut value = null

			if @test(Token.EQUALS) {
				@commit()

				if @test(.LEFT_ROUND) {
					@commit()

					arguments = @reqArgumentList(.Nil, .Nil).value

					@commit()

					if @test(Token.AMPERSAND) {
						@commit()

						value = @reqExpression(.ImplicitMember, .Method)
					}
				}
				else {
					value = @reqExpression(.ImplicitMember, .Method)
				}
			}

			@reqNL_1M()

			return @yep(AST.EnumValue(attributes, modifiers, name, value, arguments, (first ?? name)!!, (value ?? name)!!))
		} # }}}

		tryEnumVariable(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<NodeData(FieldDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			return NO unless name.ok

			var mut type = null

			if @test(Token.COLON) {
				@commit()

				type = @reqType(Function.Method)
			}
			else if @test(Token.QUESTION) {
				modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind.Nullable, @yes()))]
			}

			var mut value = null

			if @test(Token.EQUALS) {
				@commit()

				value = @reqExpression(.ImplicitMember, .Method)
			}

			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, value, (first ?? name)!!, (value ?? type ?? name)!!))
		} # }}}

		tryExpression(
			mut eMode: ExpressionMode?
			fMode: FunctionMode
			terminator: MacroTerminator? = null
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			if eMode == null | ExpressionMode.ImplicitMember {
				if @mode ~~ ParserMode.MacroExpression &&
					@scanner.test(Token.IDENTIFIER) &&
					@scanner.value() == 'macro'
				{
					return @reqMacroExpression(@yes(), terminator)
				}
				else {
					eMode ??= .Nil
				}
			}

			if @test(.CONST) {
				var mark = @mark()
				var operator = @yep(AST.UnaryOperator(.Constant, @yes()))
				var operand = @tryOperation(null, eMode, fMode)

				if operand.ok {
					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}

				@rollback(mark)
			}

			return @tryOperation(null, eMode, fMode)
		} # }}}

		tryExternFunctionDeclaration(
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)
		): Event<NodeData(FunctionDeclaration)> ~ SyntaxError # {{{
		{
			try {
				return @reqExternFunctionDeclaration(modifiers, first)
			}
			catch {
				return NO
			}
		} # }}}

		tryFunctionBody(
			modifiers: Event<ModifierData>(Y)[]
			fMode: FunctionMode
			automatable: Boolean
		): Event<NodeData(Block, Expression, IfStatement, UnlessStatement)>? ~ SyntaxError # {{{
		{
			var mark = @mark()

			@NL_0M()

			if @test(.LEFT_CURLY, .EQUALS_RIGHT_ANGLE, .COLON_RIGHT_ANGLE) {
				return @reqFunctionBody(modifiers, fMode, automatable)
			}
			else {
				@rollback(mark)

				return null
			}
		} # }}}

		tryFunctionExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
			maxParameters: Number = Infinity
		): Event<NodeData(FunctionExpression, LambdaExpression)> ~ SyntaxError # {{{
		{
			if eMode ~~ ExpressionMode.NoAnonymousFunction {
				return NO
			}

			if @match(Token.ASYNC, Token.FUNC, Token.LEFT_ROUND, Token.IDENTIFIER) == Token.ASYNC {
				var first = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Async, first))]

				if @test(Token.FUNC) {
					@commit()

					var parameters = @reqFunctionParameterList(FunctionMode.Nil, maxParameters)
					var type = @tryFunctionReturns(eMode)
					var throws = @tryFunctionThrows()
					var body = @reqFunctionBody(modifiers, FunctionMode.Nil, !?type && !?throws)

					return @yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, first, body))
				}
				else {
					var parameters = @tryFunctionParameterList(fMode, maxParameters)
					if !parameters.ok {
						return NO
					}

					var type = @tryFunctionReturns(eMode)
					var throws = @tryFunctionThrows()
					var body = @reqLambdaBody(modifiers, fMode, !?type && !?throws)

					return @yep(AST.LambdaExpression(parameters, modifiers, type, throws, body, first, body))
				}
			}
			else if @token == Token.FUNC {
				var first = @yes()

				var parameters = @tryFunctionParameterList(FunctionMode.Nil, maxParameters)
				if !parameters.ok {
					return NO
				}

				var modifiers = []
				var type = @tryFunctionReturns(eMode)
				var throws = @tryFunctionThrows()
				var body = @reqFunctionBody(modifiers, FunctionMode.Nil, !?type && !?throws)

				return @yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, first, body))
			}
			else if @token == Token.LEFT_ROUND {
				var parameters = @tryFunctionParameterList(fMode, maxParameters)

				unless parameters.ok {
					return NO
				}

				var type = @tryFunctionReturns(eMode)
				var throws = @tryFunctionThrows()

				var modifiers = []
				var body = @tryLambdaBody(modifiers, fMode, !?type && !?throws)

				unless body.ok {
					return NO
				}

				return @yep(AST.LambdaExpression(parameters, modifiers, type, throws, body, parameters, body))
			}
			else if @token == Token.IDENTIFIER {
				var name = @reqIdentifier()

				var modifiers = []
				var body = @tryLambdaBody(modifiers, fMode, false)

				unless body.ok {
					return NO
				}

				var parameters = @yep([@yep(AST.Parameter(name))], name, name)

				return @yep(AST.LambdaExpression(parameters, modifiers, null, null, body, parameters, body))
			}
			else {
				return NO
			}
		} # }}}

		tryFunctionParameterList(
			fMode: FunctionMode
			maxParameters: Number = Infinity
		): Event<Event<NodeData(Parameter)>[]> ~ SyntaxError # {{{
		{
			unless @test(Token.LEFT_ROUND) {
				return NO
			}

			var first = @yes()

			@NL_0M()

			var parameters = []

			while @until(Token.RIGHT_ROUND) {
				if parameters.length == maxParameters {
					return NO
				}

				try {
					parameters.push(@reqParameter(DestructuringMode.Parameter, fMode))
				}
				catch {
					return NO
				}

				unless @hasSeparator(Token.RIGHT_ROUND) {
					return NO
				}
			}

			unless @test(Token.RIGHT_ROUND) {
				return NO
			}

			return @yep(parameters, first, @yes())
		} # }}}

		tryFunctionReturns(
			eMode: ExpressionMode = .PrimaryType
			isAllowingAuto: Boolean = true
		): Event<NodeData(Type)>? ~ SyntaxError # {{{
		{
			var mark = @mark()

			@NL_0M()

			if @test(Token.COLON) {
				@commit()

				return @reqTypeReturn(eMode)
			}
			else {
				@rollback(mark)

				return null
			}
		} # }}}

		tryFunctionThrows(): Event<Event<NodeData(Identifier)>[]>? ~ SyntaxError # {{{
		{
			var mark = @mark()

			@NL_0M()

			if @test(Token.TILDE) {
				@commit()

				var exceptions = [@reqIdentifier()]

				while @test(Token.COMMA) {
					@commit()

					exceptions.push(@reqIdentifier())
				}

				return @yep(exceptions)
			}
			else {
				@rollback(mark)

				return null
			}
		} # }}}

		tryIdentifier(): Event<NodeData(Identifier)> ~ SyntaxError # {{{
		{
			if @scanner.test(Token.IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				return NO
			}
		} # }}}

		tryIdentifierOrMember(): Event<NodeData(Identifier, MemberExpression)> ~ SyntaxError # {{{
		{
			var mut name: Event = @tryIdentifier()

			return NO unless name.ok

			if @testNS(Token.DOT) {
				do {
					@commit()

					var property = @reqIdentifier()

					name = @yep(AST.MemberExpression([], name, property))
				}
				while @testNS(Token.DOT)
			}

			return name
		} # }}}

		tryIfExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(IfExpression)> ~ SyntaxError # {{{
		{
			unless @test(Token.IF) {
				return NO
			}

			var first = @yes()

			var tracker = @pushMode(.InlineStatement)

			var mark = @mark()

			var mut condition: Event? = null
			var mut declaration: Event? = null

			if @test(Token.VAR) {
				var mark = @mark()
				var first = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, first))]

				if @test(Token.MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind.Mutable, @yes())))
				}

				if @test(Token.IDENTIFIER, Token.LEFT_CURLY, Token.LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					if @test(Token.COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token.COMMA)

						var operator = @reqConditionAssignment()

						unless @test(Token.AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(.Nil, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						declaration = @yep(AST.VariableDeclaration([], modifiers, variables, operator, expression, first, expression))
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(.ImplicitMember, fMode)

						declaration = @yep(AST.VariableDeclaration([], modifiers, [variable], operator, expression, first, expression))
					}

					@NL_0M()

					if @test(Token.SEMICOLON_SEMICOLON) {
						@commit().NL_0M()

						condition = @reqExpression(ExpressionMode.NoAnonymousFunction, fMode)
					}
				}
				else {
					@rollback(mark)

					condition = @tryExpression(ExpressionMode.NoAnonymousFunction, fMode)
				}
			}
			else {
				@NL_0M()

				condition = @tryExpression(ExpressionMode.NoAnonymousFunction, fMode)
			}

			unless ?declaration || condition.ok {
				return NO
			}

			@NL_0M()

			unless @test(Token.LEFT_CURLY) {
				@rollback(mark)

				return NO
			}

			var whenTrue = @reqBlock(NO, null, fMode)

			@commit().NL_0M()

			unless @test(Token.ELSE) {
				@throw('else')
			}

			@commit().NL_0M()

			var whenFalse = @tryIfExpression(eMode, fMode)

			if whenFalse.ok {
				@popMode(tracker)

				return @yep(AST.IfExpression(condition, declaration, whenTrue, whenFalse, first, whenFalse))
			}
			else {
				var whenFalse = @reqBlock(NO, null, fMode)

				@popMode(tracker)

				return @yep(AST.IfExpression(condition, declaration, whenTrue, whenFalse!!, first, whenFalse!!))
			}
		} # }}}

		tryJunctionOperator(): Event<BinaryOperatorData> ~ SyntaxError # {{{
		{
			match @matchM(M.JUNCTION_OPERATOR) {
				Token.AMPERSAND {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.JunctionAnd, @yes()))
				}
				Token.CARET {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.JunctionXor, @yes()))
				}
				Token.PIPE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.JunctionOr, @yes()))
				}
				else {
					return NO
				}
			}
		} # }}}

		tryLambdaBody(
			modifiers: Event<ModifierData>(Y)[]
			fMode: FunctionMode
			automatable: Boolean
		): Event<NodeData(Block, Expression)> ~ SyntaxError # {{{
		{
			if automatable && @test(.COLON_RIGHT_ANGLE) {
				modifiers.push(@yep(AST.Modifier(.AutoType, @yes())))

				return @tryExpression(.NoRestriction, fMode)
			}
			else if @test(.EQUALS_RIGHT_ANGLE) {
				@commit()

				if @test(Token.LEFT_CURLY) {
					return @tryBlock(fMode)
				}
				else {
					return @tryExpression(.NoRestriction, fMode)
				}
			}
			else {
				return NO
			}
		} # }}}

		tryMacroStatement(
			first: Event(Y)
		): Event<NodeData(MacroDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			var parameters = @reqMacroParameterList()

			var body = @reqMacroBody()

			return @yep(AST.MacroDeclaration([], name, parameters, body, first, body))
		} # }}}

		tryMatchExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(MatchExpression)> ~ SyntaxError # {{{
		{
			unless @test(Token.MATCH) {
				return NO
			}

			var first = @yes()

			var expression = @tryOperation(null, eMode, fMode)

			unless expression.ok && @test(Token.LEFT_CURLY) {
				return NO
			}

			var tracker = @pushMode(.InlineStatement)

			var clauses = @reqMatchCaseList(fMode)

			@popMode(tracker)

			return @yep(AST.MatchExpression(expression, clauses, first, clauses))
		} # }}}

		tryMatchStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(MatchStatement)> ~ SyntaxError # {{{
		{
			var mut expression: Event? = null
			var mut declaration: Event? = null

			if @test(Token.VAR) {
				var mark = @mark()
				var firstVar = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, first))]

				if @test(Token.MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind.Mutable, @yes())))
				}

				if @test(Token.IDENTIFIER) {
					var variable = @reqTypedVariable(fMode)

					if @test(Token.COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token.COMMA)

						var late operator: Event

						if @test(Token.EQUALS) {
							operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
						}
						else {
							@throw('=')
						}

						unless @test(Token.AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(.Nil, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						declaration = @yep(AST.VariableDeclaration([], modifiers, variables, operator, expression, first, expression))
					}
					else {
						var late operator: Event

						if @test(Token.EQUALS) {
							operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
						}
						else {
							@throw('=')
						}

						var expression = @reqOperation(.ImplicitMember, fMode)

						declaration = @yep(AST.VariableDeclaration([], modifiers, [variable], operator, expression, first, expression))
					}
				}
				else {
					@rollback(mark)

					expression = @tryOperation(null, .Nil, fMode)

					unless expression.ok {
						return NO
					}
				}
			}
			else {
				expression = @tryOperation(null, .Nil, fMode)

				unless expression.ok {
					return NO
				}
			}

			unless @test(Token.LEFT_CURLY) {
				return NO
			}

			var clauses = @reqMatchCaseList(fMode)

			return @yep(AST.MatchStatement(expression, declaration, clauses, first, clauses))
		} # }}}

		tryNameIST(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Identifier, Literal, TemplateExpression)> ~ SyntaxError # {{{
		{
			if @match(Token.IDENTIFIER, Token.STRING, Token.TEMPLATE_BEGIN) == Token.IDENTIFIER {
				return @reqIdentifier()
			}
			else if @token == Token.STRING {
				return @reqString()
			}
			else if @token == Token.TEMPLATE_BEGIN {
				return @reqTemplateExpression(@yes(), eMode, fMode)
			}
			else {
				return NO
			}
		} # }}}

		tryNamespaceStatement(
			first: Event(Y)
		): Event<NodeData(NamespaceDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			return @reqNamespaceStatement(first, name)
		} # }}}

		tryNumber(): Event<NodeData(NumericExpression)> ~ SyntaxError # {{{
		{
			if @matchM(M.NUMBER) == Token.BINARY_NUMBER {
				return @yep(AST.NumericExpression(parseInt(@scanner.value().slice(2).replace(/\_/g, ''), 2), 2, @yes()))
			}
			else if @token == Token.CHARACTER_NUMBER {
				var value = @scanner.value()

				if value.length == 4 {
					var number = value.charCodeAt(2)

					return @yep(AST.NumericExpression(number, 7, @yes()))
				}
				else {
					var number = ESCAPES[value[3]]

					return @yep(AST.NumericExpression(number, 7, @yes()))
				}
			}
			else if @token == Token.OCTAL_NUMBER {
				var radix = 8

				var number = @scanner.value().slice(2).replace(/\_/g, '').split('p')
				var literals = number[0].split('.')

				var dyn value = parseInt(literals[0], radix)
				if literals.length > 1 {
					var floating = literals[1]
					var dyn power = 1

					for var i from 0 to~ floating.length {
						power *= radix

						value += parseInt(floating[i], radix) / power
					}
				}

				if number.length > 1 && number[1] != '0' {
					value *= Math.pow(2, parseInt(number[1]))
				}

				return @yep(AST.NumericExpression(value, 8, @yes()))
			}
			else if @token == Token.HEX_NUMBER {
				var radix = 16

				var number = @scanner.value().slice(2).replace(/\_/g, '').split('p')
				var literals = number[0].split('.')

				var dyn value = parseInt(literals[0], radix)
				if literals.length > 1 {
					var floating = literals[1]
					var dyn power = 1

					for var i from 0 to~ floating.length {
						power *= radix

						value += parseInt(floating[i], radix) / power
					}
				}

				if number.length > 1 && number[1] != '0' {
					value *= Math.pow(2, parseInt(number[1]))
				}

				return @yep(AST.NumericExpression(value, 16, @yes()))
			}
			else if @token == Token.RADIX_NUMBER {
				var data = /^(\d+)r(.*)$/.exec(@scanner.value())
				var radix = parseInt(data[1])

				return @yep(AST.NumericExpression(parseInt(data[2]!?.replace(/\_/g, ''), radix), radix, @yes()))
			}
			else if @token == Token.DECIMAL_NUMBER {
				return @yep(AST.NumericExpression(parseFloat(@scanner.value().replace(/\_/g, ''), 10), 10, @yes()))
			}
			else {
				return NO
			}
		} # }}}

		tryObject(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			@NL_0M()

			var attributes = []
			var properties = []

			until @test(Token.RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				var property = @tryObjectItem(eMode, fMode)

				return property unless property.ok

				properties.push(property)

				if @match(Token.COMMA, Token.NEWLINE) == Token.COMMA {
					@commit().NL_0M()
				}
				else if @token == Token.NEWLINE {
					@commit().NL_0M()

					if @test(Token.COMMA) {
						@commit().NL_0M()
					}
				}
				else {
					break
				}
			}

			unless @test(Token.RIGHT_CURLY) {
				return @no('}')
			}

			return @yep(AST.ObjectExpression(attributes, properties, first, @yes()))
		} # }}}

		tryObjectItem(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			var dyn first

			var attributes = @stackOuterAttributes([])
			if attributes.length > 0 {
				first = attributes[0]
			}

			var late name
			if @match(Token.AT, Token.DOT_DOT_DOT_QUESTION, Token.DOT_DOT_DOT, Token.IDENTIFIER, Token.LEFT_SQUARE, Token.STRING, Token.TEMPLATE_BEGIN) == Token.IDENTIFIER {
				name = @reqIdentifier()
			}
			else if @token == Token.LEFT_SQUARE {
				name = @reqComputedPropertyName(@yes(), .ImplicitMember, fMode)
			}
			else if @token == Token.STRING {
				name = @reqString()
			}
			else if @token == Token.TEMPLATE_BEGIN {
				name = @reqTemplateExpression(@yes(), eMode, fMode)
			}
			else if fMode ~~ FunctionMode.Method && @token == Token.AT {
				var name = @reqThisExpression(@yes())
				var expression = @yep(AST.ShorthandProperty(attributes, name, first ?? name, name))

				return @altRestrictiveExpression(expression, fMode)
			}
			else if @token == .DOT_DOT_DOT | .DOT_DOT_DOT_QUESTION {
				var modifiers = []

				if @token == .DOT_DOT_DOT_QUESTION {
					modifiers.push(@yep(AST.Modifier(.Nullable, @yep())))
				}

				var operator = @yep(AST.UnaryOperator(.Spread, @yes()))
				var operand = @reqPrefixedOperand(.Nil, fMode)

				if @test(.LEFT_CURLY) {
					@commit()

					var members = []

					while @until(.RIGHT_CURLY) {
						var dyn external = @reqIdentifier()
						var mut internal = external

						if @test(.PERCENT) {
							@commit()

							internal = @reqIdentifier()
						}
						else {
							external = null
						}

						members.push(@yep(AST.NamedSpecifier([], internal, external, external ?? internal, internal)))

						if @test(Token.COMMA) {
							@commit()
						}
						else {
							break
						}
					}

					unless @test(.RIGHT_CURLY) {
						@throw('}')
					}

					@commit()

					var expression = @yep(AST.SpreadExpression(modifiers, operand, members, operator, operand))

					return @altRestrictiveExpression(expression, fMode)
				}
				else {
					var expression = @yep(AST.UnaryExpression(modifiers, operator, operand, operator, operand))

					return @altRestrictiveExpression(expression, fMode)
				}
			}
			else {
				return @no('Identifier', 'String', 'Template', 'Computed Property Name')
			}

			if @test(Token.COLON) {
				@commit()

				var value = @reqExpression(ExpressionMode.ImplicitMember + ExpressionMode.NoRestriction, fMode, MacroTerminator.Object)
				var expression = @yep(AST.ObjectMember(attributes, [], name, null, value, first ?? name, value))

				return @altRestrictiveExpression(expression, fMode)
			}
			else if name.value.kind == NodeKind.Identifier {
				var expression = @yep(AST.ShorthandProperty(attributes, name, first ?? name, name))

				return @altRestrictiveExpression(expression, fMode)
			}
			else {
				return @no(':')
			}
		} # }}}

		tryOperand(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			match @matchM(M.OPERAND, eMode, fMode) {
				.AT {
					return @reqThisExpression(@yes())
				}
				.IDENTIFIER {
					return @yep(AST.Identifier(@scanner.value(), @yes()))
				}
				.LEFT_CURLY {
					return @tryObject(@yes(), eMode, fMode)
				}
				.LEFT_ROUND {
					return @tryParenthesis(@yes(), fMode)
				}
				.LEFT_SQUARE {
					return @reqArray(@yes(), fMode)
				}
				.ML_BACKQUOTE | .ML_TILDE {
					var delimiter = @token!?

					return @reqMultiLineTemplate(@yes(), fMode, delimiter)
				}
				.ML_DOUBLE_QUOTE | .ML_SINGLE_QUOTE {
					var delimiter = @token!?

					return @reqMultiLineString(@yes(), delimiter)
				}
				.REGEXP {
					return @yep(AST.RegularExpression(@scanner.value(), @yes()))
				}
				.STRING {
					return @yep(AST.Literal(null, @value()!!, @yes()))
				}
				.TEMPLATE_BEGIN {
					return @reqTemplateExpression(@yes(), eMode, fMode)
				}
				else {
					return @tryNumber()
				}
			}
		} # }}}

		tryOperation(
			mut operand: Event<NodeData(Expression)>?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			var mut mark = @mark()
			var mut operator = null

			if !?operand {
				var binding = @tryDestructuring(null, fMode)

				if binding.ok {
					@NL_0M()

					if (operator <- @tryAssignementOperator()).ok {
						@NL_0M()

						var operand = @reqBinaryOperand(eMode + ExpressionMode.ImplicitMember, fMode)

						return @yep(AST.BinaryExpression(binding, operator, operand, binding, operand))
					}
				}

				@rollback(mark)

				operand = @tryBinaryOperand(eMode, fMode)

				return operand unless operand.ok
			}

			var values: NodeData(Expression)[] = [operand.value]
			// var values: BinaryOperationData[] = [operand.value]

			var mut type = false

			repeat {
				mark = @mark()

				@NL_0M()

				if (operator <- @tryBinaryOperator(fMode)).ok {
					var mut mode = eMode + ExpressionMode.ImplicitMember

					match operator.value.kind {
						BinaryOperatorKind.Assignment {
							@validateAssignable(values[values.length - 1])
						}
						BinaryOperatorKind.ForwardPipeline {
							mode += ExpressionMode.Pipeline
						}
					}

					values.push(AST.BinaryExpression(operator))

					@NL_0M()

					if operator.value.kind == BinaryOperatorKind.BackwardPipeline | BinaryOperatorKind.ForwardPipeline {
						if @test(Token.DOT) {
							var first = @yes()
							var operand = @yep(AST.MemberExpression([], null, @reqNumeralIdentifier(), first))

							values.push(@reqUnaryOperand(operand, mode, fMode).value)
						}
						else if @test(Token.LEFT_SQUARE) {
							block computed {
								if operator.value.kind == BinaryOperatorKind.BackwardPipeline {
									for var modifier in operator.value.modifiers {
										if modifier.kind == ModifierKind.Wildcard {
											values.push(@reqBinaryOperand(mode, fMode).value)

											break computed
										}
									}
								}


								var first = @yes()
								var array = @reqArray(first, fMode).value

								if array is .ArrayExpression && array.values.length == 1 && !@hasTopicReference(array) {
									var modifiers = [AST.Modifier(ModifierKind.Computed, first)]
									var operand = @yep(AST.MemberExpression(modifiers, null, @yep(array.values[0]), first, array))

									values.push(@reqUnaryOperand(operand, mode, fMode).value)
								}
								else {
									values.push(array)
								}
							}
						}
						else {
							var mark = @mark()

							var operand = @tryFunctionExpression(mode, fMode + FunctionMode.NoPipeline, 1)

							if operand.ok {
								values.push(operand.value)
							}
							else {
								@rollback(mark)

								var binary = @reqBinaryOperand(mode, fMode).value

								if binary is .Identifier && binary.name == 'await' {
									values.push(AST.AwaitExpression([], null, null, binary, binary))
								}
								else {
									values.push(binary)
								}
							}
						}
					}
					else {
						values.push(@reqBinaryOperand(mode, fMode).value)
					}
				}
				else if !type && (operator <- @tryTypeOperator()).ok {
					if mark.line != operator.start.line {
						@rollback(mark)

						break
					}
					else {
						values.push(AST.BinaryExpression(operator), @reqTypeLimited(null, false, .ImplicitMember).value)

						type = true

						continue
					}
				}
				else if @test(Token.QUESTION_OPERATOR) {
					values.push(AST.ConditionalExpression(@yes()))

					values.push(@reqExpression(.ImplicitMember, fMode).value)

					unless @test(Token.COLON) {
						@throw(':')
					}

					@commit()

					values.push(@reqExpression(.ImplicitMember, fMode).value)
				}
				else if (operator <- @tryJunctionOperator()).ok {
					values.push(@reqJunctionExpression(operator, eMode, fMode, values, type))
				}
				else {
					@rollback(mark)

					break
				}

				if type {
					type = false
				}
			}

			if values.length == 1 {
				return @yep(values[0]!?)
			}
			else {
				return @yep(AST.reorderExpression(values))
			}
		} # }}}

		tryParenthesis(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(SequenceExpression)> ~ SyntaxError # {{{
		{
			try {
				return @reqParenthesis(first, fMode)
			}
			catch {
				return NO
			}
		} # }}}

		tryPostfixedOperand(
			operand: Event<NodeData(Expression)>(Y)?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			var unaryOperand = @tryUnaryOperand(operand, eMode, fMode)

			return unaryOperand unless unaryOperand.ok

			var mut operator = null
			var mut modifier = null

			match @matchM(M.POSTFIX_OPERATOR) {
				.EXCLAMATION_EXCLAMATION {
					operator = @yep(AST.UnaryOperator(.TypeFitting, @yes()))
					modifier = @yep(AST.Modifier(.Forced, operator))
				}
				.EXCLAMATION_QUESTION {
					operator = @yep(AST.UnaryOperator(.TypeFitting, @yes()))
					modifier = @yep(AST.Modifier(.Nullable, operator))
				}
				else {
					return unaryOperand
				}
			}

			var unaryExpression = @yep(AST.UnaryExpression([modifier], operator, unaryOperand, unaryOperand, operator))

			return @tryPostfixedOperand(unaryExpression, eMode, fMode)
		} # }}}

		tryPrefixedOperand(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			match @matchM(M.PREFIX_OPERATOR, eMode) {
				Token.DOT {
					var operator = @yep(AST.UnaryOperator(.Implicit, @yes()))
					var operand = @tryIdentifier()

					if operand.ok {
						return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
					}
					else {
						@rollback(mark)
					}
				}
				Token.DOT_DOT_DOT {
					if eMode ~~ ExpressionMode.Pipeline {
						var position = @yes()
						var operand = @tryPrefixedOperand(eMode, fMode)

						if operand.ok {
							var operator = @yep(AST.UnaryOperator(UnaryOperatorKind.Spread, position))

							return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
						}
						else {
							var modifiers = [AST.Modifier(ModifierKind.Spread, position)]
							var operator = @yep(AST.TopicReference(modifiers, position))

							return @reqPostfixedOperand(operator, eMode, fMode)
						}
					}
					else {
						var operator = @yep(AST.UnaryOperator(UnaryOperatorKind.Spread, @yes()))
						var operand = @reqPrefixedOperand(eMode, fMode)

						return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
					}
				}
				Token.DOT_DOT_DOT_QUESTION {
					var operator = @yep(AST.UnaryOperator(.Spread, @yes()))
					var modifier = @yep(AST.Modifier(.Nullable, operator))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([modifier], operator, operand, operator, operand))
				}
				Token.EXCLAMATION {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind.LogicalNegation, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				Token.QUESTION_HASH {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind.NonEmpty, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				Token.MINUS {
					var first = @yes()
					var operand = @reqPrefixedOperand(eMode, fMode)

					if operand.value is .NumericExpression {
						operand.value.value = -operand.value.value

						return @relocate(operand, first, null)
					}
					else {
						var operator = @yep(AST.UnaryOperator(UnaryOperatorKind.Negative, first))

						return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
					}
				}
				.PLUS_CARET {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind.BitwiseNegation, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				Token.QUESTION {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind.Existential, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				Token.UNDERSCORE {
					return @reqPostfixedOperand(@yep(AST.TopicReference(@yes())), eMode, fMode)
				}
			}

			return @tryPostfixedOperand(null, eMode, fMode)
		} # }}}

		tryRangeOperand(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			var operand = @tryOperand(eMode, fMode)

			if operand.ok {
				return @reqPostfixedOperand(operand, eMode, fMode)
			}
			else {
				return operand
			}
		} # }}}

		tryReturnStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(IfStatement, ReturnStatement, UnlessStatement)> ~ SyntaxError # {{{
		{
			if @match(Token.IF, Token.UNLESS, Token.NEWLINE) == Token.IF {
				var mark = @mark()

				@commit()

				var condition = @reqExpression(eMode + .NoRestriction, fMode)

				if @test(Token.NEWLINE) || @token == Token.EOF {
					return @yep(AST.IfStatement(condition, @yep(AST.ReturnStatement(first)), null, first, condition))
				}
				else {
					@rollback(mark)
				}
			}
			else if @token == Token.NEWLINE || @token == Token.EOF {
				return @yep(AST.ReturnStatement(first))
			}
			else if @token == Token.UNLESS {
				var mark = @mark()

				@commit()

				var condition = @reqExpression(eMode + .NoRestriction, fMode)

				if @test(Token.NEWLINE) || @token == Token.EOF {
					return @yep(AST.UnlessStatement(condition, @yep(AST.ReturnStatement(first)), first, condition))
				}
				else {
					@rollback(mark)
				}
			}

			var expression = @tryExpression(eMode + .NoRestriction, fMode)

			unless expression.ok {
				return NO
			}

			if @match(Token.IF, Token.UNLESS) == Token.IF {
				@commit()

				var condition = @reqExpression(eMode + .NoRestriction, fMode)

				return @yep(AST.IfStatement(condition, @yep(AST.ReturnStatement(expression, first, expression)), null, first, condition))
			}
			else if @token == Token.UNLESS {
				@commit()

				var condition = @reqExpression(eMode + .NoRestriction, fMode)

				return @yep(AST.UnlessStatement(condition, @yep(AST.ReturnStatement(expression, first, expression)), first, condition))
			}
			else {
				return @yep(AST.ReturnStatement(expression, first, expression))
			}
		} # }}}

		tryShebang(): Event<NodeData(ShebangDeclaration)> ~ SyntaxError # {{{
		{
			if @test(Token.HASH_EXCLAMATION) {
				var first = @yes()
				var command = @scanner.readLine()
				var last = @yep()

				@reqNL_1M()

				return @yep(AST.ShebangDeclaration(command, first, last))
			}

			return NO
		} # }}}

		tryStaticModifier(): Event<ModifierData> ~ SyntaxError # {{{
		{
			if @test(.STATIC) {
				return @yep(AST.Modifier(.Static, @yes()))
			}

			return NO
		} # }}}

		tryStructStatement(
			first: Event(Y)
		): Event<NodeData(StructDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			var attributes = []
			var elements = []
			var mut last: Range = name

			var extends = if @test(Token.EXTENDS) {
				@commit()

				set @reqTypeNamed([])
			}
			else {
				set null
			}

			var implements = []
			if @test(Token.IMPLEMENTS) {
				@commit()

				implements.push(@reqIdentifierOrMember())

				while @test(Token.COMMA) {
					@commit()

					implements.push(@reqIdentifierOrMember())
				}
			}

			if @test(Token.LEFT_CURLY) {
				var first = @yes()

				@NL_0M()

				@stackInnerAttributes(attributes)

				until @test(Token.RIGHT_CURLY) {
					var mark = @mark()
					var mut nf = true

					if @test(.VARIANT) {
						var first = @yes()
						var identifier = @tryIdentifier()

						if name.ok && @test(.COLON) {
							@commit()

							var name = @reqIdentifierOrMember()
							var enum = @yep(AST.TypeReference(name))
							var fields = []

							if @test(.LEFT_CURLY) {
								@commit()

								@reqVariantFieldList(fields)
							}

							var type = @yep(AST.VariantType(enum, fields, enum, @yes()))

							elements.push(AST.FieldDeclaration([], [], identifier!!, type, null, first, type))

							nf = false
						}
						else {
							@rollback(mark)
						}
					}

					if nf {
						var mut first = null

						var attributes = @stackOuterAttributes([])
						if attributes.length != 0 {
							first = attributes[0]
						}

						var modifiers = []

						var name = @reqIdentifier()

						var mut last: Event(Y) = name

						var mut type = null
						if @test(Token.COLON) {
							@commit()

							type = @reqType()

							last = type
						}
						else if @test(Token.QUESTION) {
							var modifier = @yep(AST.Modifier(ModifierKind.Nullable, @yes()))

							modifiers.push(modifier)

							last = modifier
						}

						var dyn defaultValue = null
						if @test(Token.EQUALS) {
							@commit()

							defaultValue = @reqExpression(.ImplicitMember, .Nil)

							last = defaultValue
						}

						elements.push(AST.FieldDeclaration(attributes, modifiers, name, type, defaultValue, first ?? name, last))
					}

					if @match(Token.COMMA, Token.NEWLINE) == Token.COMMA {
						@commit().NL_0M()
					}
					else if @token == Token.NEWLINE {
						@commit().NL_0M()

						if @test(Token.COMMA) {
							@commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}

			return @yep(AST.StructDeclaration(attributes, [], name, extends, implements, elements, first, last))
		} # }}}

		tryTryExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(TryExpression)> ~ SyntaxError # {{{
		{
			unless @test(Token.TRY) {
				return NO
			}

			try {
				return @reqTryExpression(@yes(), fMode)
			}
			catch {
				return NO
			}
		} # }}}

		tryTryStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(TryStatement)> ~ SyntaxError # {{{
		{
			@NL_0M()

			var body = @tryBlock(fMode)

			unless body.ok {
				return NO
			}

			var mut last: Event(Y) = body

			var mut mark = @mark()

			var catchClauses = []
			var dyn catchClause, finalizer

			@NL_0M()

			if @test(Token.ON) {
				do {
					catchClauses.push(last <- @reqCatchOnClause(@yes(), fMode))

					mark = @mark()

					@NL_0M()
				}
				while @test(Token.ON)
			}
			else {
				@rollback(mark)

				@NL_0M()
			}

			if @test(Token.CATCH) {
				catchClause = last = @reqTryCatchClause(@yes(), fMode)

				mark = @mark()
			}
			else {
				@rollback(mark)
			}

			@NL_0M()

			if @test(Token.FINALLY) {
				@commit()

				finalizer = last = @reqBlock(NO, null, fMode)
			}
			else {
				@rollback(mark)
			}

			return @yep(AST.TryStatement(body, catchClauses, catchClause, finalizer, first, last))
		} # }}}

		tryTupleStatement(
			first: Event(Y)
		): Event<NodeData(TupleDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			var attributes = []
			var modifiers = []
			var elements = []
			var dyn extends = null
			var dyn last = name

			if @test(Token.EXTENDS) {
				@commit()

				extends = @reqIdentifier()
			}

			var implements = []
			if @test(Token.IMPLEMENTS) {
				@commit()

				implements.push(@reqIdentifierOrMember())

				while @test(Token.COMMA) {
					@commit()

					implements.push(@reqIdentifierOrMember())
				}
			}

			if @test(Token.LEFT_SQUARE) {
				@commit().NL_0M()

				@stackInnerAttributes(attributes)

				until @test(Token.RIGHT_SQUARE) {
					var modifiers = []
					var mut name = null
					var mut type = null
					var mut first = null
					var mut last = null

					var attributes = @stackOuterAttributes([])
					if attributes.length != 0 {
						first = attributes[0]
					}

					if @test(Token.COLON) {
						if ?first {
							@commit()
						}
						else {
							first = @yes()
						}

						type = @reqType()

						last = type
					}
					else {
						name = @reqIdentifier()

						if @test(Token.COLON) {
							@commit()

							type = @reqType()

							last = type
						}
						else if @test(Token.QUESTION) {
							var modifier = @yep(AST.Modifier(ModifierKind.Nullable, @yes()))

							modifiers.push(modifier)

							last = modifier
						}
						else {
							last = name
						}
					}

					var dyn defaultValue = null
					if @test(Token.EQUALS) {
						@commit()

						defaultValue = @reqExpression(.ImplicitMember, .Nil)

						last = defaultValue
					}

					elements.push(AST.TupleField(attributes, modifiers, name, type, defaultValue, first ?? name!?, last))

					if @match(Token.COMMA, Token.NEWLINE) == Token.COMMA {
						@commit().NL_0M()
					}
					else if @token == Token.NEWLINE {
						@commit().NL_0M()

						if @test(Token.COMMA) {
							@commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless @test(Token.RIGHT_SQUARE) {
					@throw(']')
				}

				last = @yes()
			}

			return @yep(AST.TupleDeclaration(attributes, modifiers, name, extends, implements, elements, first, last))
		} # }}}

		tryType(
			modifiers: Event<ModifierData>(Y)[] = []
			multiline: Boolean = false
			eMode: ExpressionMode = .InlineOnly
		): Event<NodeData(Type)> ~ SyntaxError # {{{
		{
			var type = @tryTypeCore(modifiers, multiline, eMode)

			return NO unless type.ok

			var dyn mark = @mark()

			if multiline {
				var types = [type]

				@NL_0M()

				if @match(Token.PIPE, Token.AMPERSAND, Token.CARET) == Token.PIPE {
					do {
						@commit()

						if @test(Token.PIPE) {
							@commit()
						}

						@NL_0M()

						if @test(Token.QUESTION) {
							var name = @yep(AST.Identifier('Null', @yes()))

							types.push(@yep(AST.TypeReference(name)))
						}
						else {
							types.push(@reqTypeCore([], true, eMode))
						}

						mark = @mark()

						@NL_0M()
					}
					while @test(Token.PIPE)

					@rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return @yep(AST.UnionType(types, type, types[types.length - 1]))
					}
				}
				else if @token == Token.AMPERSAND {
					do {
						@commit()

						if @test(Token.AMPERSAND) {
							@commit()
						}

						@NL_0M()

						types.push(@reqTypeCore([], true, eMode))

						mark = @mark()

						@NL_0M()
					}
					while @test(Token.AMPERSAND)

					@rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return @yep(AST.FusionType(types, type, types[types.length - 1]))
					}
				}
				else if @token == Token.CARET {
					do {
						@commit()

						if @test(Token.CARET) {
							@commit()
						}

						@NL_0M()

						types.push(@reqTypeCore([], true, eMode))

						mark = @mark()

						@NL_0M()
					}
					while @test(Token.CARET)

					@rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return @yep(AST.ExclusionType(types, type, types[types.length - 1]))
					}
				}
				else {
					@rollback(mark)
				}
			}
			else {
				if @match(Token.PIPE_PIPE, Token.PIPE, Token.AMPERSAND_AMPERSAND, Token.AMPERSAND, Token.CARET_CARET, Token.CARET) == Token.PIPE {
					@commit()

					if @test(Token.NEWLINE) {
						@rollback(mark)

						return type
					}

					var types = [type]

					do {
						@commit()

						if @test(Token.QUESTION) {
							var name = @yep(AST.Identifier('Null', @yes()))

							types.push(@yep(AST.TypeReference(name)))
						}
						else {
							types.push(@reqTypeCore([], false, eMode))
						}
					}
					while @test(Token.PIPE)

					return @yep(AST.UnionType(types, type, types[types.length - 1]))
				}
				else if @token == Token.AMPERSAND {
					@commit()

					if @test(Token.NEWLINE) {
						@rollback(mark)

						return type
					}

					var types = [type]

					do {
						@commit()

						types.push(@reqTypeCore([], false, eMode))
					}
					while @test(Token.AMPERSAND)

					return @yep(AST.FusionType(types, type, types[types.length - 1]))
				}
				else if @token == Token.CARET {
					@commit()

					if @test(Token.NEWLINE) {
						@rollback(mark)

						return type
					}

					var types = [type]

					do {
						@commit()

						types.push(@reqTypeCore([], false, eMode))
					}
					while @test(Token.CARET)

					return @yep(AST.ExclusionType(types, type, types[types.length - 1]))
				}
			}

			return type
		} # }}}

		tryTypeCore(
			modifiers: Event<ModifierData>(Y)[]
			multiline: Boolean
			eMode: ExpressionMode
		): Event<NodeData(Type)> ~ SyntaxError # {{{
		{
			if @test(.CONST) {
				var operator = @yep(AST.UnaryTypeOperator(.Constant, @yes()))
				var operand = @tryTypeCore([], multiline, eMode)

				if operand.ok {
					return @yep(AST.UnaryTypeExpression(modifiers, operator, operand, operator, operand))
				}
				else {
					return NO
				}
			}
			else if @test(.MUT) {
				var operator = @yep(AST.UnaryTypeOperator(.Mutable, @yes()))
				var operand = @tryTypeCore([], multiline, eMode)

				if operand.ok {
					return @yep(AST.UnaryTypeExpression(modifiers, operator, operand, operator, operand))
				}
				else {
					return NO
				}
			}

			if @test(Token.LEFT_CURLY) {
				return @reqTypeObject(modifiers, @yes(), eMode)
			}

			if @test(Token.LEFT_SQUARE) {
				return @reqTypeArray(modifiers, multiline, @yes(), eMode)
			}

			var mark = @mark()

			if @test(Token.ASYNC) {
				var async = @yes()

				if @test(Token.FUNC) {
					@commit()
				}

				if @test(Token.LEFT_ROUND) {
					var modifiers = [@yep(AST.Modifier(ModifierKind.Async, async))]
					var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
					var type = @tryFunctionReturns(eMode, false)
					var throws = @tryFunctionThrows()

					var func = @yep(AST.FunctionExpression(parameters, modifiers, type, throws, null, async, (throws ?? type ?? parameters)!!))

					return @altTypeContainer(func)
				}

				@rollback(mark)
			}

			if @test(Token.FUNC) {
				var first = @yes()

				if @test(Token.LEFT_ROUND) {
					var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
					var type = @tryFunctionReturns(eMode, false)
					var throws = @tryFunctionThrows()

					var func = @yep(AST.FunctionExpression(parameters, null, type, throws, null, first, (throws ?? type ?? parameters)!!))

					return @altTypeContainer(func)
				}

				@rollback(mark)
			}

			if @test(.TYPEOF) {
				var operator = @yep(AST.UnaryTypeOperator(.TypeOf, @yes()))
				var operand = @tryUnaryOperand(null, eMode, eMode ~~ .AtThis ? .Method : .Nil)

				if operand.ok {
					return @yep(AST.UnaryTypeExpression(modifiers, operator, operand, operator, operand))
				}
				else {
					return NO
				}
			}

			if @test(Token.LEFT_ROUND) {
				var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
				var type = @tryFunctionReturns(eMode, false)
				var throws = @tryFunctionThrows()

				var func = @yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, (throws ?? type ?? parameters)!!))

				return @altTypeContainer(func)
			}

			var type = @tryTypeNamed(modifiers, eMode)

			if type.ok {
				return @altTypeContainer(type)
			}
			else {
				return NO
			}
		} # }}}

		tryTypeDescriptive(
			tMode: TypeMode = .Nil
		): Event<NodeData(DescriptiveType)> ~ SyntaxError # {{{
		{
			match @matchM(M.DESCRIPTIVE_TYPE) {
				Token.ABSTRACT {
					var abstract = @yep(AST.Modifier(ModifierKind.Abstract, @yes()))

					if @test(Token.CLASS) {
						@commit()

						return @reqExternClassDeclaration(abstract, [abstract])
					}
					else {
						return @no('class')
					}
				}
				Token.ASYNC {
					var first = @reqIdentifier()
					var modifiers = [@yep(AST.Modifier(ModifierKind.Async, first))]

					if @test(Token.FUNC) {
						@commit()

						return @reqExternFunctionDeclaration(modifiers, first)
					}
					else {
						var fn = @tryExternFunctionDeclaration(modifiers, first)
						if fn.ok {
							return fn
						}
						else {
							return @reqExternVariableDeclarator(first)
						}
					}
				}
				Token.BITMASK {
					with @mode += ParserMode.Typing {
						return @reqBitmaskStatement(@yes())
					}
				}
				Token.CLASS {
					return @reqExternClassDeclaration(@yes(), [])
				}
				Token.ENUM {
					with @mode += ParserMode.Typing {
						return @reqEnumStatement(@yes())
					}
				}
				Token.EXPORT {
					if tMode ~~ TypeMode.Module {
						return NO
					}
					else {
						return @reqExportModule(@yes())
					}
				}
				Token.FINAL {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(.Final, first))]

					if @test(.CLASS) {
						@commit()

						return @reqExternClassDeclaration(first, modifiers)
					}
					else if @test(.ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(.Abstract, @yes())))

						if @test(.CLASS) {
							@commit()

							return @reqExternClassDeclaration(first, modifiers)
						}
						else {
							return @no('class')
						}
					}
					else {
						return @no('class')
					}
				}
				Token.FUNC {
					var first = @yes()
					return @reqExternFunctionDeclaration([], first)
				}
				Token.IDENTIFIER {
					if tMode ~~ TypeMode.NoIdentifier {
						return NO
					}
					else {
						return @reqExternVariableDeclarator(@reqIdentifier())
					}
				}
				Token.NAMESPACE {
					return @reqExternNamespaceDeclaration(@yes(), [])
				}
				Token.SEALED {
					var sealed = @yep(AST.Modifier(ModifierKind.Sealed, @yes()))

					if @matchM(M.DESCRIPTIVE_TYPE) == Token.ABSTRACT {
						var abstract = @yep(AST.Modifier(ModifierKind.Abstract, @yes()))

						if @test(Token.CLASS) {
							@commit()

							return @reqExternClassDeclaration(sealed, [sealed, abstract])
						}
						else {
							return @no('class')
						}
					}
					else if @token == Token.CLASS {
						@commit()

						return @reqExternClassDeclaration(sealed, [sealed])
					}
					else if @token == Token.IDENTIFIER {
						var name = @reqIdentifier()

						if @test(Token.COLON) {
							@commit()

							var type = @reqType()

							return @yep(AST.VariableDeclarator([sealed], name, type, sealed, type))
						}
						else {
							return @yep(AST.VariableDeclarator([sealed], name, null, sealed, name))
						}
					}
					else if @token == Token.NAMESPACE {
						@commit()

						return @reqExternNamespaceDeclaration(sealed, [sealed])
					}
					else {
						return @no('class', 'namespace')
					}
				}
				Token.STRUCT {
					return @reqStructStatement(@yes())
				}
				Token.SYSTEM {
					var system = @yep(AST.Modifier(ModifierKind.System, @yes()))

					if @matchM(M.DESCRIPTIVE_TYPE) == Token.CLASS {
						@commit()

						return @reqExternClassDeclaration(system, [system])
					}
					else if @token == Token.IDENTIFIER {
						var name = @reqIdentifier()

						if @test(Token.COLON) {
							@commit()

							var type = @reqType()

							return @yep(AST.VariableDeclarator([system], name, type, system, type))
						}
						else {
							return @yep(AST.VariableDeclarator([system], name, null, system, name))
						}
					}
					else if @token == Token.NAMESPACE {
						@commit()

						return @reqExternNamespaceDeclaration(system, [system])
					}
					else {
						return @no('class', 'namespace')
					}
				}
				Token.TUPLE {
					return @reqTupleStatement(@yes())
				}
				Token.TYPE {
					return @reqTypeStatement(@yes(), @reqIdentifier())
				}
				Token.VAR {
					var first = @yes()
					var name = @reqIdentifier()

					if @test(Token.COLON) {
						@commit()

						var type = @reqType()

						return @yep(AST.VariableDeclarator([], name, type, first, type))
					}
					else {
						return @yep(AST.VariableDeclarator([], name, null, first, name))
					}
				}
			}

			return NO
		} # }}}

		tryTypeEntity(): Event<NodeData(TypeReference)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifierOrMember()

			return NO unless name.ok

			return @yep(AST.TypeReference(name))
		} # }}}

		tryTypeNamed(
			modifiers: Event<ModifierData>(Y)[]
			eMode: ExpressionMode = .Nil
		): Event<NodeData(TypeReference)> ~ SyntaxError # {{{
		{
			var mut name: Event = @tryIdentifierOrMember()

			unless name.ok {
				if eMode ~~ .ImplicitMember && @test(.DOT) {
					var operator = @yep(AST.UnaryOperator(.Implicit, @yes()))
					var operand = @tryIdentifierOrMember()

					if operand.ok {
						name = @yep(AST.UnaryExpression([], operator, operand, operator, operand))
					}
					else {
						return NO
					}
				}
				else {
					return NO
				}
			}

			var first = modifiers[0] ?? name
			var mut last: Range = name

			var mut generic = null

			if @testNS(.LEFT_ANGLE) {
				var first = @yes()
				var types = [@reqType()]

				while @test(.COMMA) {
					@commit()

					types.push(@reqType())
				}

				unless @test(.RIGHT_ANGLE) {
					@throw('>')
				}

				last = generic = @yes(types, first)
			}

			var mut typeSubtypes = null

			if @testNS(.LEFT_ROUND) {
				var first = @yes()
				var mark = @mark()

				var identifier = @tryIdentifier()

				if identifier.ok && @test(.COMMA, .RIGHT_ROUND) {
					var names = [identifier]

					while @test(.COMMA) {
						@commit()

						names.push(@reqIdentifier())
					}

					unless @test(.RIGHT_ROUND) {
						@throw(')')
					}

					last = typeSubtypes = @yes(names, first)
				}
				else {
					var expression = @tryOperation(identifier, .InlineOnly, .Nil)

					unless expression.ok {
						@throw('expression')
					}

					unless @test(.RIGHT_ROUND) {
						@throw(')')
					}

					last = typeSubtypes = @yes(expression.value, first)
				}
			}

			return @yep(AST.TypeReference(modifiers, name, generic, typeSubtypes, first, last))
		} # }}}

		tryTypeLimited(
			modifiers: Event<ModifierData>(Y)[] = []
			eMode: ExpressionMode = .Nil
		): Event<NodeData(Type)> ~ SyntaxError # {{{
		{
			if @test(Token.LEFT_ROUND) {
				var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, (throws ?? type ?? parameters)!!))
			}

			if @test(Token.LEFT_CURLY) {
				return @reqTypeObject(modifiers, @yes(), .InlineOnly)
			}

			if @test(Token.LEFT_SQUARE) {
				return @reqTypeArray(modifiers, false, @yes(), .InlineOnly)
			}

			return @tryTypeNamed(modifiers, eMode)
		} # }}}

		tryTypeOperator(): Event<BinaryOperatorData> ~ SyntaxError # {{{
		{
			match @matchM(M.TYPE_OPERATOR) {
				Token.AS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.TypeCasting, @yes()))
				}
				Token.AS_EXCLAMATION {
					var position = @yes()

					return @yep(AST.BinaryOperator([AST.Modifier(ModifierKind.Forced, position)], BinaryOperatorKind.TypeCasting, position))
				}
				Token.AS_QUESTION {
					var position = @yes()

					return @yep(AST.BinaryOperator([AST.Modifier(ModifierKind.Nullable, position)], BinaryOperatorKind.TypeCasting, position))
				}
				Token.IS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.TypeEquality, @yes()))
				}
				Token.IS_NOT {
					return @yep(AST.BinaryOperator(BinaryOperatorKind.TypeInequality, @yes()))
				}
				else {
					return NO
				}
			}
		} # }}}

		tryTypeParameterList(): Event<Event<NodeData(TypeParameter)>[]>? ~ SyntaxError # {{{
		{
			unless @test(.LEFT_ANGLE) {
				return null
			}

			@commit()

			var result = []
			var mut last = null

			do {
				@commit() if ?last

				var identifier = @reqIdentifier()

				var constraint = if @test(.IS) {
					@commit()

					set @reqType(.InlineOnly + .ImplicitMember)
				}
				else {
					set null
				}

				result.push(@yep(AST.TypeParameter(identifier, constraint, identifier, constraint ?? identifier)))

				last = identifier
			}
			while @test(Token.COMMA)

			unless @test(.RIGHT_ANGLE) {
				@throw('>')
			}

			@commit()

			return @yep(result, result[0], last!?)
		} # }}}

		tryTypeStatement(
			first: Event(Y)
		): Event<NodeData(TypeAliasDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			return @reqTypeStatement(first, name)
		} # }}}

		tryTypedVariable(
			fMode: FunctionMode
			typeable: Boolean = true
			questionable: Boolean = true
		): Event<NodeData(VariableDeclarator)> ~ SyntaxError # {{{
		{
			try {
				return @reqTypedVariable(fMode, typeable, questionable)
			}
			catch {
				return NO
			}
		} # }}}

		tryUnaryOperand(
			mut value: Event<NodeData(Expression)>(Y)?
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(Expression)> ~ SyntaxError # {{{
		{
			if !?value {
				var operand = @tryOperand(eMode, fMode)

				if operand.ok {
					value = operand
				}
				else {
					return operand
				}
			}

			var dyn expression, first

			repeat {
				match @matchM(M.OPERAND_JUNCTION) {
					Token.ASTERISK_DOLLAR_LEFT_ROUND {
						@commit()

						var arguments = @reqArgumentList(eMode, fMode)

						value = @yep(AST.CallExpression([], AST.Scope(ScopeKind.Argument, arguments.value.shift()!!), value, arguments, value, @yes()))
					}
					Token.CARET_CARET_LEFT_ROUND {
						@commit()

						var arguments = @reqArgumentList(eMode + ExpressionMode.Curry, fMode)

						value = @yep(AST.CurryExpression(AST.Scope(ScopeKind.This), value, arguments, value, @yes()))
					}
					Token.CARET_DOLLAR_LEFT_ROUND {
						@commit()

						var arguments = @reqArgumentList(eMode + ExpressionMode.Curry, fMode)

						value = @yep(AST.CurryExpression(AST.Scope(ScopeKind.Argument, arguments.value.shift()!!), value, arguments, value, @yes()))
					}
					Token.COLON {
						first = @yes()

						expression = @reqIdentifier()

						value = @yep(AST.BinaryExpression(value, @yep(AST.BinaryOperator(BinaryOperatorKind.TypeCasting, first)), @yep(AST.TypeReference(expression)), value, expression))
					}
					Token.COLON_EXCLAMATION {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([AST.Modifier(ModifierKind.Forced, first)], BinaryOperatorKind.TypeCasting, first))

						expression = @reqIdentifier()

						value = @yep(AST.BinaryExpression(value, operator, @yep(AST.TypeReference(expression)), value, expression))
					}
					Token.COLON_QUESTION {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([AST.Modifier(ModifierKind.Nullable, first)], BinaryOperatorKind.TypeCasting, first))

						expression = @reqIdentifier()

						value = @yep(AST.BinaryExpression(value, operator, @yep(AST.TypeReference(expression)), value, expression))
					}
					Token.DOT {
						@commit()

						value = @yep(AST.MemberExpression([], value, @reqNumeralIdentifier()))
					}
					Token.DOT_DOT {
						if eMode ~~ ExpressionMode.NoInlineCascade {
							break
						}

						value = @reqRollingExpression(value, [], eMode, fMode, false)
					}
					Token.LEFT_SQUARE {
						var modifiers = [AST.Modifier(ModifierKind.Computed, @yes())]

						expression = @reqExpression(eMode, fMode)

						unless @test(Token.RIGHT_SQUARE) {
							@throw(']')
						}

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, @yes()))
					}
					Token.LEFT_ROUND {
						@commit()

						value = @yep(AST.CallExpression([], value, @reqArgumentList(eMode, fMode), value, @yes()))
					}
					Token.NEWLINE {
						if eMode ~~ ExpressionMode.NoMultiLine {
							break
						}

						var mark = @mark()

						@commit().NL_0M()

						if @test(Token.DOT_DOT) {
							value = @reqRollingExpression(value, [], eMode, fMode, true)
						}
						else if @test(Token.DOT) {
							@commit()

							if eMode ~~ .MatchCase {
								var identifier = @reqIdentifier()

								if @test(.EQUALS_RIGHT_ANGLE, .WHEN, .WITH) {
									@rollback(mark)

									return value
								}
								else {
									value = @reqCascadeExpression(value, [], identifier, eMode, fMode)
								}
							}
							else {
								value = @reqCascadeExpression(value, [], null, eMode, fMode)
							}
						}
						else if @test(Token.QUESTION_DOT) {
							var modifiers = [AST.Modifier(ModifierKind.Nullable, @yes())]

							value = @reqCascadeExpression(value, modifiers, null, eMode, fMode)
						}
						else {
							@rollback(mark)

							break
						}
					}
					Token.QUESTION_DOT {
						var modifiers = [AST.Modifier(ModifierKind.Nullable, @yes())]

						expression = @reqIdentifier()

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, expression))
					}
					Token.QUESTION_DOT_DOT {
						if eMode ~~ ExpressionMode.NoInlineCascade {
							break
						}

						var modifiers = [AST.Modifier(ModifierKind.Nullable, @yes())]

						value = @reqRollingExpression(value, modifiers, eMode, fMode, true)
					}
					Token.QUESTION_LEFT_ROUND {
						var modifiers = [AST.Modifier(ModifierKind.Nullable, @yes())]

						value = @yep(AST.CallExpression(modifiers, AST.Scope(ScopeKind.This), value, @reqArgumentList(eMode, fMode), value, @yes()))
					}
					Token.QUESTION_LEFT_SQUARE {
						var position = @yes()
						var modifiers = [AST.Modifier(ModifierKind.Nullable, position), AST.Modifier(ModifierKind.Computed, position)]

						expression = @reqExpression(eMode, fMode)

						unless @test(Token.RIGHT_SQUARE) {
							@throw(']')
						}

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, @yes()))
					}
					Token.TEMPLATE_BEGIN {
						value = @yep(AST.TaggedTemplateExpression(value, @reqTemplateExpression(@yes(), eMode, fMode), value, @yes()))
					}
					else {
						break
					}
				}
			}

			return value
		} # }}}

		tryUntilStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(UntilStatement)> ~ SyntaxError # {{{
		{
			var condition = @tryExpression(.Nil, fMode)

			unless condition.ok {
				return NO
			}

			var dyn body
			if @match(Token.LEFT_CURLY, Token.EQUALS_RIGHT_ANGLE) == Token.LEFT_CURLY {
				body = @reqBlock(@yes(), null, fMode)
			}
			else if @token == Token.EQUALS_RIGHT_ANGLE {
				@commit()

				body = @reqExpression(.Nil, fMode)
			}
			else {
				@throw('{', '=>')
			}

			return @yep(AST.UntilStatement(condition, body, first, body))
		} # }}}

		tryVariable(): Event<NodeData(VariableDeclarator)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			if name.ok {
				return @yep(AST.VariableDeclarator([], name, null, name, name))
			}
			else {
				return NO
			}
		} # }}}

		tryVariableName(
			fMode: FunctionMode
		): Event<NodeData(Identifier, MemberExpression, ThisExpression)> ~ SyntaxError # {{{
		{
			var dyn object
			if fMode ~~ FunctionMode.Method && @test(Token.AT) {
				object = @reqThisExpression(@yes())
			}
			else {
				object = @tryIdentifier()

				unless object.ok {
					return NO
				}
			}

			return @reqVariableName(object, fMode)
		} # }}}}

		tryVariantStatement(
			first: Event(Y)
		): Event<NodeData(VariantDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			unless @test(.LEFT_CURLY) {
				return NO
			}

			@commit()

			var elements = []

			@reqVariantFieldList(elements)

			return @yep(AST.VariantDeclaration([], [], name, elements, first, @yes()))
		} # }}}

		tryVarStatement(
			first: Event(Y)
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(VariableStatement)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			if @test(Token.MUT) {
				var statement = @tryVarMutStatement(first, eMode, fMode)
				if statement.ok {
					return statement
				}

				@rollback(mark)
			}

			if @test(Token.DYN) {
				var statement = @tryVarDynStatement(first, eMode, fMode)
				if statement.ok {
					return statement
				}

				@rollback(mark)
			}

			if @test(Token.LATE) {
				var statement = @tryVarLateStatement(first, eMode, fMode)
				if statement.ok {
					return statement
				}

				@rollback(mark)
			}

			return @tryVarImmuStatement([], first, eMode, fMode)
		} # }}}

		tryVarDynStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(VariableStatement)> ~ SyntaxError # {{{
		{
			var modifiers = [@yep(AST.Modifier(ModifierKind.Dynamic, @yes()))]

			var mark = @mark()

			if @test(Token.LEFT_CURLY) {
				@commit()

				var declarations = []
				var mut ok = @hasNL_1M()

				if ok {
					while @until(Token.RIGHT_CURLY) {
						var variable = @tryTypedVariable(fMode, false, false)
						if !variable.ok {
							ok = false

							break
						}

						if @test(Token.EQUALS) {
							@commit()

							var value = @reqExpression(eMode, fMode)

							declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, value, variable, value)))
						}
						else {
							declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))
						}

						@reqNL_1M()
					}
				}

				if ok {
					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.VariableStatement([], modifiers, declarations, first, @yes()))
				}
				else {
					@rollback(mark)
				}
			}

			var variable = @tryTypedVariable(fMode, false, false)

			return NO unless variable.ok

			var variables = [variable]

			if @test(Token.COMMA) {
				@commit()

				var variable = @tryTypedVariable(fMode, false, false)

				return NO unless variable.ok

				variables.push(variable)
			}

			if @test(Token.EQUALS) {
				@commit().NL_0M()

				if variables.length == 1 {
					var value = @reqExpression(eMode + ExpressionMode.ImplicitMember, fMode)

					var declaration = @yep(AST.VariableDeclaration([], [], variables, null, value, first, value))

					return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
				}
				else {
					if @test(Token.AWAIT) {
						@commit()
					}
					else {
						@throw('await')
					}

					var operand = @reqPrefixedOperand(eMode, fMode)

					var value = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

					var declaration = @yep(AST.VariableDeclaration([], [], variables, null, value, first, value))

					return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
				}
			}

			var declarations = []
			var mut last = null

			for var variable in variables {
				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

				last = variable
			}

			while @test(Token.COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, false, false)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last))
		} # }}}

		tryVarImmuStatement(
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(VariableStatement)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			if @test(Token.LEFT_CURLY) {
				@commit()

				var declarations = []
				var mut ok = @hasNL_1M()

				if ok {
					while @until(Token.RIGHT_CURLY) {
						var variable = @tryTypedVariable(fMode, true, false)
						if !variable.ok {
							ok = false

							break
						}

						if @test(Token.EQUALS) {
							@commit()
						}
						else {
							ok = false

							break
						}

						var value = @reqExpression(eMode, fMode)

						declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, value, variable, value)))

						@reqNL_1M()
					}
				}

				if ok {
					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.VariableStatement([], modifiers, declarations, first, @yes()))
				}
				else {
					@rollback(mark)
				}
			}

			var variable = @tryTypedVariable(fMode, true, false)

			return NO unless variable.ok

			var variables = [variable]

			if @test(Token.COMMA) {
				@commit()

				variables.push(@reqTypedVariable(fMode, true, false))
			}

			if @test(Token.EQUALS) {
				@commit()
			}
			else {
				@throw('=')
			}

			@NL_0M()

			var late value: Event

			if variables.length == 1 {
				value = @reqExpression(eMode + ExpressionMode.ImplicitMember, fMode)
			}
			else {
				unless @test(Token.AWAIT) {
					@throw('await')
				}

				@commit()

				var operand = @reqPrefixedOperand(eMode, fMode)

				value = @yep(AST.AwaitExpression([], variables, operand, variable, operand))
			}

			var declaration = @yep(AST.VariableDeclaration([], [], variables, null, value, variable, value))

			return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
		} # }}}

		tryVarLateStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(VariableStatement)> ~ SyntaxError # {{{
		{
			var modifiers = [@yep(AST.Modifier(ModifierKind.LateInit, @yes()))]

			var mark = @mark()

			if @test(Token.LEFT_CURLY) {
				@commit()

				var declarations = []
				var mut ok = @hasNL_1M()

				if ok {
					while @until(Token.RIGHT_CURLY) {
						var variable = @tryTypedVariable(fMode, true, true)
						if !variable.ok {
							ok = false

							break
						}

						declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

						@reqNL_1M()
					}
				}

				if ok {
					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.VariableStatement([], modifiers, declarations, first, @yes()))
				}
				else {
					@rollback(mark)
				}
			}

			var variable = @tryTypedVariable(fMode, true, true)

			return NO unless variable.ok

			var declarations = [@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable))]

			var mut last = variable

			while @test(Token.COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, true, true)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last))
		} # }}}

		tryVarMutStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<NodeData(VariableStatement)> ~ SyntaxError # {{{
		{
			var modifiers = [@yep(AST.Modifier(ModifierKind.Mutable, @yes()))]

			var mark = @mark()

			if @test(Token.LEFT_CURLY) {
				@commit()

				var declarations = []
				var mut ok = @hasNL_1M()

				if ok {
					while @until(Token.RIGHT_CURLY) {
						var variable = @tryTypedVariable(fMode, true, true)
						if !variable.ok {
							ok = false

							break
						}

						if @test(Token.EQUALS) {
							@commit()

							var value = @reqExpression(eMode, fMode)

							declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, value, variable, value)))
						}
						else if ?variable.value.type {
							declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))
						}
						else {
							ok = false

							break
						}

						@reqNL_1M()
					}
				}

				if ok {
					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.VariableStatement([], modifiers, declarations, first, @yes()))
				}
				else {
					@rollback(mark)
				}
			}

			var variable = @tryTypedVariable(fMode, true, true)

			return NO unless variable.ok

			var variables = [variable]

			if @test(Token.COMMA) {
				@commit()

				var variable = @tryTypedVariable(fMode, true, true)

				return NO unless variable.ok

				variables.push(variable)
			}

			if variables.length == 1 {
				if @test(Token.EQUALS) {
					@commit().NL_0M()

					var value = @reqExpression(eMode + ExpressionMode.ImplicitMember, fMode)

					var declaration = @yep(AST.VariableDeclaration([], [], variables, null, value, first, value))

					return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
				}
				else if ?variable.value.type {
					var declaration = @yep(AST.VariableDeclaration([], [], variables, null, null, first, variable))

					return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
				}
				else {
					return NO
				}
			}

			if @test(Token.EQUALS) {
				@commit().NL_0M()

				if @test(Token.AWAIT) {
					@commit()
				}
				else {
					@throw('await')
				}

				var operand = @reqPrefixedOperand(eMode, fMode)

				var value = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

				var declaration = @yep(AST.VariableDeclaration([], [], variables, null, value, first, value))

				return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
			}

			var declarations = []
			var mut last = null

			for var variable in variables {
				if !?variable.value.type {
					return NO
				}

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

				last = variable
			}

			while @test(Token.COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, true, false)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last))
		} # }}}

		tryWhileStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(WhileStatement)> ~ SyntaxError # {{{
		{
			var dyn condition

			if @test(Token.VAR) {
				var mark = @mark()
				var first = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, first))]

				if @test(Token.MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind.Mutable, @yes())))
				}

				if @test(Token.IDENTIFIER, Token.LEFT_CURLY, Token.LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					if @test(Token.COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token.COMMA)

						var operator = @reqConditionAssignment()

						unless @test(Token.AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(.Nil, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						condition = @yep(AST.VariableDeclaration([], modifiers, variables, operator, expression, first, expression))
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(.Nil, fMode)

						condition = @yep(AST.VariableDeclaration([], modifiers, [variable], operator, expression, first, expression))
					}
				}
				else {
					@rollback(mark)

					condition = @tryExpression(.Nil, fMode)
				}
			}
			else {
				condition = @tryExpression(.Nil, fMode)
			}

			unless condition.ok {
				return NO
			}

			var dyn body
			if @match(Token.LEFT_CURLY, Token.EQUALS_RIGHT_ANGLE) == Token.LEFT_CURLY {
				body = @reqBlock(@yes(), null, fMode)
			}
			else if @token == Token.EQUALS_RIGHT_ANGLE {
				@commit()

				body = @reqExpression(.Nil, fMode)
			}
			else {
				@throw('{', '=>')
			}

			return @yep(AST.WhileStatement(condition, body, first, body))
		} # }}}

		tryWithVariable(
			fMode: FunctionMode
		): Event<NodeData(BinaryExpression, VariableDeclaration)> ~ SyntaxError # {{{
		{
			if @test(Token.VAR) {
				var mark = @mark()
				var first = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, first))]

				if @test(Token.MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind.Mutable, @yes())))
				}

				if @test(Token.IDENTIFIER, Token.LEFT_CURLY, Token.LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					if @test(Token.COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token.COMMA)

						if @test(Token.EQUALS) {
							@commit()
						}
						else {
							@throw('=')
						}

						unless @test(Token.AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(.Nil, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						return @yep(AST.VariableDeclaration([], modifiers, variables, null, expression, first, expression))
					}
					else {
						if @test(Token.EQUALS) {
							@commit()
						}
						else {
							@throw('=')
						}

						var expression = @reqExpression(.Nil, fMode)

						return @yep(AST.VariableDeclaration([], modifiers, [variable], null, expression, first, expression))
					}
				}

				@rollback(mark)
			}

			var variable = @tryVariableName(fMode)

			return NO unless variable.ok

			var late operator: Event

			match @matchM(M.ASSIGNEMENT_OPERATOR) {
				Token.AMPERSAND_AMPERSAND_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalAnd, @yes()))
				}
				Token.ASTERISK_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Multiplication, @yes()))
				}
				Token.CARET_CARET_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalXor, @yes()))
				}
				Token.EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
				}
				Token.MINUS_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Subtraction, @yes()))
				}
				Token.PERCENT_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Modulo, @yes()))
				}
				Token.PIPE_PIPE_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.LogicalOr, @yes()))
				}
				.PLUS_AMPERSAND_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseAnd, @yes()))
				}
				.PLUS_CARET_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseXor, @yes()))
				}
				.PLUS_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Addition, @yes()))
				}
				.PLUS_LEFT_ANGLE_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseLeftShift, @yes()))
				}
				.PLUS_PIPE_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseOr, @yes()))
				}
				.PLUS_RIGHT_ANGLE_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.BitwiseRightShift, @yes()))
				}
				Token.SLASH_DOT_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Quotient, @yes()))
				}
				Token.SLASH_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Division, @yes()))
				}
				else {
					return NO
				}
			}

			var value = @reqExpression(null, fMode)

			return @yep(AST.BinaryExpression(variable, operator, value, variable, value))
		} # }}}

		tryWithStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<NodeData(WithStatement)> ~ SyntaxError # {{{
		{
			var mut mark = @mark()
			var mut eMode = ExpressionMode.Nil
			var variables = []

			if @test(Token.LEFT_CURLY) {
				@commit()

				var mut ok = @hasNL_1M()

				if ok {
					while @until(Token.RIGHT_CURLY) {
						var variable = @tryWithVariable(fMode)

						if variable.ok {
							variables.push(variable)
						}
						else {
							ok = false

							break
						}

						@reqNL_1M()
					}
				}

				if !ok {
					@rollback(mark)

					return NO
				}

				if @test(Token.RIGHT_CURLY) {
					@commit()
				}
				else {
					@throw('}')
				}

				@reqNL_1M()

				if @test(Token.THEN) {
					@commit()
				}
				else {
					@throw('then')
				}
			}
			else {
				var variable = @tryWithVariable(fMode)

				if variable.ok {
					variables.push(variable)

					if variable.value.kind == NodeKind.Identifier {
						eMode += .ImplicitMember
					}
				}
				else {
					@rollback(mark)

					var operand = @tryUnaryOperand(null, .InlineOnly, fMode)

					return NO unless operand.ok

					variables.push(operand)

					eMode += .ImplicitMember
				}
			}

			var body = @reqBlock(NO, eMode, fMode)
			var mut finalizer = null

			mark = @mark()

			if @hasNL_1M() && @test(Token.FINALLY) {
				@commit()

				finalizer = @reqBlock(NO, null, fMode)
			}
			else {
				@rollback(mark)
			}

			return @yep(AST.WithStatement(variables, body, finalizer, first, finalizer ?? body))
		} # }}}

		validateAssignable(
			expression: NodeData(Expression)
		): Void ~ SyntaxError # {{{
		{
			unless expression.kind == NodeKind.ArrayBinding | NodeKind.Identifier | NodeKind.MemberExpression | NodeKind.ObjectBinding | NodeKind.ThisExpression {
				throw @error(`The left-hand side of an assignment expression must be a variable, a property access or a binding`, expression.start.line, expression.start.column)
			}
		} # }}}
	}

	func parse(data: String) ~ SyntaxError # {{{
		{
		var parser = Parser.new(data)

		return parser.parseModule()
	} # }}}

	func parseStatements(data: String, mode: FunctionMode) ~ SyntaxError # {{{
		{
		var parser = Parser.new(data)

		return parser.parseStatements(mode)
	} # }}}

	export {
		FunctionMode

		parse
		parseStatements
	}
}

export Parser.parse
