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
#![runtime(prefix='KS')]

import 'npm:@kaoscript/ast'

export namespace SyntaxAnalysis {
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
		BinaryOperator
		Curry
		ImplicitMember
		MatchCase
		NoAnonymousFunction
		NoAwait
		NoInlineCascade
		NoMultiLine
		NoNull
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

		Method
		NoPipeline
		Syntime
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
		NoAsync
		NoBody
		OverrideMethod
		OverrideProperty
		OverwriteMethod
		OverwriteProperty
		Property
		Proxy
		RequiredAssignment
		Syntime
		Value
		Variable
	}

	bitmask ParserMode {
		Nil

		InlineStatement
		Typing
	}

	bitmask StatementMode {
		Nil

		Expression
		NewLine

		Default = Expression + NewLine
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
				echo(prefix, @scanner.toDebug())
			}
			else {
				echo(@scanner.toDebug())
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

		testM(
			matcher: Function
		): Boolean # {{{
		{
			@token = @scanner.matchM(matcher, null, null, @mode)

			return @token != .INVALID
		} # }}}

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
			value: Event<Ast(Expression)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(ArrayComprehension)>(Y) ~ SyntaxError # {{{
		{
			var firstLoop = @yes()

			@NL_0M()

			var iteration = @reqIteration(null, fMode)

			@NL_0M()

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ArrayComprehension(value, iteration, first, @yes()))
		} # }}}

		altArrayComprehensionRepeat(
			value: Event<Ast(Expression)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(ArrayComprehension)>(Y) ~ SyntaxError # {{{
		{
			var firstLoop = @yes()

			@NL_0M()

			var condition = @reqExpression(.Nil, fMode)

			unless @test(Token.TIMES) {
				@throw('times')
			}

			var iteration = @yep(AST.IterationRepeat([], condition, firstLoop, @yes()))

			@NL_0M()

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ArrayComprehension(value, iteration, first, @yes()))
		} # }}}

		altArrayList(
			expression: Event<Ast(Expression)>(Y)
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(ArrayExpression)>(Y) ~ SyntaxError # {{{
		{
			var values = [@altRestrictiveExpression(expression, fMode)]

			repeat {
				if @test(.COMMA) {
					@commit().NL_0M()

					var newExpression = @reqExpression(eMode, fMode, MacroTerminator.Array)

					values.push(@altRestrictiveExpression(newExpression, fMode))
				}
				else if @test(.NEWLINE) {
					@commit().NL_0M()

					if @test(.COMMA) {
						@commit().NL_0M()
					}
					else if @test(.RIGHT_SQUARE) {
						break
					}

					var newExpression = @reqExpression(eMode, fMode, MacroTerminator.Array)

					values.push(@altRestrictiveExpression(newExpression, fMode))
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
			expression: Event<Ast(Expression)>(Y)
			fMode: FunctionMode
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
		{
			var mark = @mark()

			if @test(Token.IF, Token.UNLESS) {
				var kind = if @token == Token.IF set RestrictiveOperatorKind.If else RestrictiveOperatorKind.Unless
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
			mut type: Event<Ast(Type)>(Y)
			nullable: Boolean = true
		): Event<Ast(Type)>(Y) ~ SyntaxError # {{{
		{
			var mut mark = @mark()

			while @testNS(Token.QUESTION, Token.LEFT_CURLY, Token.LEFT_SQUARE) {
				if @token == Token.QUESTION {
					var modifier = @yep(AST.Modifier(ModifierKind.Nullable, @yes()))

					if !@testNS(Token.LEFT_CURLY, Token.LEFT_SQUARE) {
						@rollback(mark)

						break
					}

					AST.pushModifier(type.value, modifier, false)
				}

				if @token == Token.LEFT_CURLY {
					@commit()

					unless @test(Token.RIGHT_CURLY) {
						@throw('}')
					}

					var property = @yep(AST.PropertyType([], NO, type, type, type))

					type = @yep(AST.ObjectType([], [], property, property, @yes()))
				}
				else {
					@commit()

					unless @test(Token.RIGHT_SQUARE) {
						@throw(']')
					}

					var property = @yep(AST.PropertyType([], NO, type, type, type))

					type = @yep(AST.ArrayType([], [], property, property, @yes()))
				}

				mark = @mark()
			}

			if nullable && @testNS(Token.QUESTION) {
				var modifier = @yep(AST.Modifier(ModifierKind.Nullable, @yes()))

				return @yep(AST.pushModifier(type.value, modifier, false))
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
			expression: Ast(Argument, Expression)
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
			expression: Ast(Expression)?
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

		parseMatchClauses(): Ast(MatchClause)[] ~ SyntaxError # {{{
		{
			var fMode = FunctionMode.Method
			var clauses = []

			@NL_0M()

			while !@scanner.isEOF() {
				var late binding, filter, body, first
				var conditions = []

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

					binding = filter = NO
				}
				else {
					if @test(Token.WITH, Token.WHEN) {
						first = @yep()
					}
					else {
						first = @reqMatchCondition(fMode)

						conditions.push(first)

						while @test(Token.COMMA) {
							@commit()

							conditions.push(@reqMatchCondition(fMode))
						}

						@NL_0M()
					}

					if @test(Token.WITH) {
						@commit()

						binding = @reqMatchBinding(fMode)

						@NL_0M()
					}
					else {
						binding = NO
					}

					if @test(Token.WHEN) {
						@commit()

						filter = @reqExpression(.ImplicitMember + .NoAnonymousFunction, fMode)

						@NL_0M()
					}
					else {
						filter = NO
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

				clauses.push(AST.MatchClause(conditions, binding, filter, body, first, body))
			}

			return clauses
		} # }}}

		parseModule(): Ast(Module) ~ SyntaxError # {{{
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
						statement = @reqStatement(.Default, .Nil, .Nil).value
					}
				}

				AST.pushAttributes(statement, attrs)

				body.push(statement)

				@NL_0M()
			}

			return AST.Module(attributes, body, this)
		} # }}}

		parseModuleType(): Ast(TypeList) ~ SyntaxError # {{{
		{
			@NL_0M()

			var types = []
			var attributes = []
			var attrs = []

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
		): Ast(StatementList) ~ SyntaxError # {{{
		{
			var first = @yep()
			var attributes = []
			var body = []
			var attrs = []

			@NL_0M()

			while !@scanner.isEOF() {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				var statement =
					if @matchM(M.MODULE_STATEMENT) == Token.EXPORT {
						set @reqExportStatement(@yes())
					}
					else if @token == Token.EXTERN {
						set @reqExternStatement(@yes())
					}
					else if @token == Token.INCLUDE {
						set @reqIncludeStatement(@yes())
					}
					else if @token == Token.INCLUDE_AGAIN {
						set @reqIncludeAgainStatement(@yes())
					}
					else {
						set @reqStatement(.Default, .Nil, mode)
					}

				AST.pushAttributes(statement.value, attrs)

				body.push(statement.value)

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
			expression: Ast(Expression)
			name: String
			reference: Ast(Expression)
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
		): Event<Event<Ast(Argument, Expression)>(Y)[]>(Y) ~ SyntaxError # {{{
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

						if fMode ~~ FunctionMode.Method && @test(Token.AMPERAT) {
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
							argument = @yep(AST.PlaceholderArgument([], NO, first, first))
						}
					}
					else if @test(Token.COLON) {
						var first = @yes()

						var late expression

						if fMode ~~ FunctionMode.Method && @test(Token.AMPERAT) {
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
							argument = @yep(AST.PlaceholderArgument([modifier], NO, modifier, modifier))
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
										set @yep(AST.PlaceholderArgument([], NO, first, first))
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
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(ArrayExpression, ArrayRange, ArrayComprehension)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.RIGHT_SQUARE) {
				return @yep(AST.ArrayExpression([], first, @yes()))
			}

			var mark = @mark()

			var mut operand = @tryRangeOperand(ExpressionMode.InlineOnly, fMode)

			if operand.ok && (@match(Token.LEFT_ANGLE, Token.DOT_DOT) == Token.LEFT_ANGLE || @token == Token.DOT_DOT) {
				var then = @token == Token.LEFT_ANGLE

				@commit()

				if then {
					unless @test(Token.DOT_DOT) {
						@throw('..')
					}

					@commit()
				}

				var til = @test(Token.LEFT_ANGLE)

				if til {
					@commit()
				}

				var toOperand = @reqPrefixedOperand(ExpressionMode.InlineOnly, fMode)

				var byOperand =
					if @test(Token.DOT_DOT) {
						@commit()

						set @reqPrefixedOperand(ExpressionMode.InlineOnly, fMode)
					}
					else {
						set NO
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

				var expression = @reqExpression(eMode, fMode, MacroTerminator.Array)

				if @match(Token.RIGHT_SQUARE, Token.FOR, Token.NEWLINE, Token.REPEAT) == Token.RIGHT_SQUARE {
					return @yep(AST.ArrayExpression([expression], first, @yes()))
				}
				else if @token == Token.FOR {
					return @altArrayComprehensionFor(expression, first, fMode)
				}
				else if @token == Token.NEWLINE {
					var lineMark = @mark()

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
						@rollback(lineMark)

						return @altArrayList(expression, first, eMode, fMode)
					}
				}
				else if @token == Token.REPEAT {
					return @altArrayComprehensionRepeat(expression, first, fMode)
				}
				else {
					return @altArrayList(expression, first, eMode, fMode)
				}
			}
		} # }}}

		reqAttribute(
			first: Event(Y)
		): Event<Ast(AttributeDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var declaration = @reqAttributeMember()

			unless @test(Token.RIGHT_SQUARE) {
				@throw(']')
			}

			var last = @yes()

			@scanner.skipComments()

			return @yep(AST.AttributeDeclaration(declaration, first, last))
		} # }}}

		reqAttributeIdentifier(): Event<Ast(Identifier)>(Y) ~ SyntaxError # {{{
		{
			if @scanner.test(Token.ATTRIBUTE_IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqAttributeMember(): Event<Ast(Identifier, AttributeOperation, AttributeExpression)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(AwaitExpression)>(Y) ~ SyntaxError # {{{
		{
			var operand = @reqPrefixedOperand(eMode, fMode)

			return @yep(AST.AwaitExpression([], [], operand, first, operand))
		} # }}}

		reqBinaryOperand(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
		{
			var operand = @tryBinaryOperand(eMode, fMode)

			if operand.ok {
				return operand
			}
			else {
				@throw(...?operand.expecteds)
			}
		} # }}}

		reqBitmaskMember(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
		): Event<Ast(BitmaskValue, MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var member = @tryBitmaskMember(attributes, modifiers, bits, null)

			unless member.ok {
				@throw('Identifier')
			}

			return member
		} # }}}

		reqBitmaskMemberBlock(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			members: Ast(BitmaskValue, MethodDeclaration)[]
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
			members: Ast(BitmaskValue, MethodDeclaration)[]
		): Void ~ SyntaxError # {{{
		{
			var attributes = @stackOuterAttributes([])
			var modifiers = []

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier(.Closed)

			if ?]accessModifier && @test(Token.LEFT_CURLY) {
				return @reqBitmaskMemberBlock(
					attributes
					[accessModifier]
					MemberBits.Method
					members
				)
			}

			var staticMark = @mark()

			if var staticModifier ?]= @tryStaticModifier() {
				if @test(Token.LEFT_CURLY) {
					return @reqBitmaskMemberBlock(
						attributes
						[
							accessModifier if ?]accessModifier
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
							accessModifier if ?]accessModifier
							staticModifier
						]
						MemberBits.Method
						accessModifier ?]] staticModifier
					)

					if member.ok {
						members.push(member.value)

						return
					}

					@rollback(staticMark)
				}
			}

			if ?]accessModifier {
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

			// TODO!
			// match @reqBitmaskMember(attributes, [], MemberBits.Value + MemberBits.Method) {
			// 	.Ok({value}) => members.push(value)
			// 	.Err(error) => return error
			// }
		} # }}}

		reqBitmaskStatement(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[] = []
		): Event<Ast(BitmaskDeclaration)>(Y) ~ SyntaxError # {{{
		{
			if var statement ?]= @tryBitmaskStatement(first, modifiers) {
				return statement
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqBlock(
			mut first: Event
			eMode!: ExpressionMode = .Nil
			fMode: FunctionMode
		): Event<Ast(Block)>(Y) ~ SyntaxError # {{{
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

				statement = @reqStatement(.Default, eMode, fMode)

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
		): Event<Ast(BreakStatement, IfStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.IF, Token.UNLESS) == Token.IF {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(eMode + .NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.IfStatement(condition, @yep(AST.BreakStatement(NO, first, first)), NO, first, condition))
				}
				else {
					return @yep(AST.BreakStatement(label, first, label))
				}
			}
			else if @token == Token.UNLESS {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(eMode + .NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.UnlessStatement(condition, @yep(AST.BreakStatement(NO, first, first)), first, condition))
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

						return @yep(AST.IfStatement(condition, @yep(AST.BreakStatement(label, first, label)), NO, first, condition))
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
					return @yep(AST.BreakStatement(NO, first, first))
				}
			}
		} # }}}

		reqCascadeExpression(
			mut object: Event<Ast(Expression)>(Y)
			mut modifiers: ModifierData[]
			identifier: Event<Ast(Identifier)>(Y)?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
		{
			var mode = eMode + ExpressionMode.ImplicitMember + ExpressionMode.NoMultiLine

			repeat {
				var value = @yep(AST.MemberExpression(modifiers, @yep(AST.Reference('main', object)), @reqIdentifier()))
				var operand = @reqUnaryOperand(value, eMode + ExpressionMode.NoMultiLine, fMode)
				var restrictiveExpression = @altRestrictiveExpression(operand, fMode)

				if restrictiveExpression.value is .RestrictiveExpression {
					var { operator, condition, expression } = restrictiveExpression.value

					object = @yep(AST.DisruptiveExpression(@yep(operator), @yep(condition), object, @yep(expression), object, condition))
				}
				else {
					@replaceReference(value.value, 'main', object.value)

					object = restrictiveExpression
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
		): Event<Ast(CatchClause)>(Y) ~ SyntaxError # {{{
		{
			var type = @reqIdentifier()

			var binding =
				if @test(Token.CATCH) {
					@commit()

					set @reqIdentifier()
				}
				else {
					set NO
				}

			@NL_0M()

			var body = @reqBlock(NO, null, fMode)

			return @yep(AST.CatchClause(binding, type, body, first, body))
		} # }}}

		reqClassMember(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			first: Range?
		): Event<Ast(ClassMember)>(Y) ~ SyntaxError # {{{
		{
			var member = @tryClassMember(attributes, modifiers, bits, first)

			unless member.ok {
				@throw('Identifier', 'String', 'Template')
			}

			return member
		} # }}}

		reqClassMemberBlock(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			members: Event<Ast(ClassMember)>(Y)[]
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
			members: Event<Ast(ClassMember)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var mut first: Range? = null

			var attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			var syntimeMark = @mark()

			if @test(.AT_SYNTIME) {
				members.push(@reqSyntimeStatement(@yes()))

				@reqNL_1M()

				return
			}

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier(.Opened)

			if ?]accessModifier && @test(Token.LEFT_CURLY) {
				return @reqClassMemberBlock(
					attributes
					// TODO
					// [accessModifier]
					[accessModifier:!!!(Event<ModifierData>(Y))]
					MemberBits.Variable + MemberBits.FinalVariable + MemberBits.LateVariable + MemberBits.Property + MemberBits.Method + MemberBits.AssistMethod + MemberBits.OverrideMethod + MemberBits.Proxy
					members
				)
			}

			if @test(Token.ABSTRACT) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(ModifierKind.Abstract, @yes()))

				if @test(Token.LEFT_CURLY) {
					var modifiers = [modifier]

					if ?]accessModifier {
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
					if ?]accessModifier {
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
					if ?]accessModifier {
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
				if ?]accessModifier {
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
					else if @test(Token.AMPERAT) {
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
				var proxyFirst = @yes()

				var modifiers = []
				if ?]accessModifier {
					modifiers.unshift(accessModifier)
				}

				if @test(Token.LEFT_CURLY) {
					return @reqClassProxyBlock(
						attributes
						modifiers
						members
					)
				}
				else if @test(Token.AMPERAT) {
					return @reqClassProxyGroup(
						attributes
						modifiers
						members
						proxyFirst
					)
				}
				else {
					var member = @tryClassProxy(
						attributes
						modifiers
						modifiers[0] ?? proxyFirst
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
					if ?]accessModifier {
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
							if ?]accessModifier {
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
							if ?]accessModifier {
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
				if ?]accessModifier {
					modifiers.unshift(accessModifier)
				}

				if @test(Token.LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						if finalModifier.ok set MemberBits.Variable else MemberBits.Variable + MemberBits.FinalVariable
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

			if ?]accessModifier {
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			name: Event<Ast(Identifier)>(Y)
			first: Range
		): Event<Ast(MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var typeParameters = @tryTypeParameterList()
			var parameters = @reqClassMethodParameterList(null, if bits ~~ MemberBits.NoBody set DestructuringMode.EXTERNAL_ONLY else null)
			var type = @tryFunctionReturns(.Method, bits !~ .NoBody)
			var throws = @tryFunctionThrows()

			if bits ~~ MemberBits.NoBody {
				@reqNL_1M()

				return @yep(AST.MethodDeclaration(attributes, modifiers, name, typeParameters, parameters, type, throws, null, first, throws ?]] type ?]] parameters))
			}
			else {
				var body = @tryFunctionBody(modifiers, FunctionMode.Method)

				@reqNL_1M()

				return @yep(AST.MethodDeclaration(attributes, modifiers, name, typeParameters, parameters, type, throws, body, first, body ?]] throws ?]] type ?]] parameters))
			}
		} # }}}

		reqClassMethodParameterList(
			mut first: Event = NO
			mut pMode: DestructuringMode = DestructuringMode.Nil
		): Event<Event<Ast(Parameter)>(Y)[]>(Y) ~ SyntaxError # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			type: Event<Ast(Type)>
			first: Range
		): Event<Ast(PropertyDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var mut defaultValue: Event = NO
			var mut accessor: Event = NO
			var mut mutator: Event = NO

			if @test(Token.NEWLINE) {
				@commit().NL_0M()

				if @match(Token.GET, Token.SET) == Token.GET {
					var getFirst = @yes()

					if @match(Token.EQUALS_RIGHT_ANGLE, Token.LEFT_CURLY) == Token.EQUALS_RIGHT_ANGLE {
						@commit()

						var expression = @reqExpression(.Nil, .Method)

						accessor = @yep(AST.AccessorDeclaration(expression, getFirst, expression))
					}
					else if @token == Token.LEFT_CURLY {
						var block = @reqBlock(NO, null, FunctionMode.Method)

						accessor = @yep(AST.AccessorDeclaration(block, getFirst, block))
					}
					else {
						accessor = @yep(AST.AccessorDeclaration(getFirst))
					}

					@reqNL_1M()

					if @test(Token.SET) {
						var setFirst = @yes()

						if @match(Token.EQUALS_RIGHT_ANGLE, Token.LEFT_CURLY) == Token.EQUALS_RIGHT_ANGLE {
							@commit()

							var expression = @reqExpression(.Nil, .Method)

							mutator = @yep(AST.MutatorDeclaration(expression, setFirst, expression))
						}
						else if @token == Token.LEFT_CURLY {
							var block = @reqBlock(NO, null, FunctionMode.Method)

							mutator = @yep(AST.MutatorDeclaration(block, setFirst, block))
						}
						else {
							mutator = @yep(AST.MutatorDeclaration(setFirst))
						}

						@reqNL_1M()
					}
				}
				else if @token == Token.SET {
					var setFirst = @yes()

					if @match(Token.EQUALS_RIGHT_ANGLE, Token.LEFT_CURLY) == Token.EQUALS_RIGHT_ANGLE {
						@commit()

						var expression = @reqExpression(.Nil, .Method)

						mutator = @yep(AST.MutatorDeclaration(expression, setFirst, expression))
					}
					else if @token == Token.LEFT_CURLY {
						var block = @reqBlock(NO, null, FunctionMode.Method)

						mutator = @yep(AST.MutatorDeclaration(block, setFirst, block))
					}
					else {
						mutator = @yep(AST.MutatorDeclaration(setFirst))
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

			var last = @yes()

			if @test(Token.EQUALS) {
				@commit()

				defaultValue = @reqExpression(.Nil, .Method)
			}

			@reqNL_1M()

			return @yep(AST.PropertyDeclaration(attributes, modifiers, name, type, defaultValue, accessor, mutator, first, defaultValue ?]] last))
		} # }}}

		reqClassProxy(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			first: Range?
		): Event<Ast(ProxyDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var member = @tryClassProxy(attributes, modifiers, first)

			unless member.ok {
				@throw('Identifier')
			}

			return member
		} # }}}

		reqClassProxyBlock(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			members: Event<Ast(ClassMember)>(Y)[]
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			members: Event<Ast(ClassMember)>(Y)[]
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
		): Event<Ast(ClassDeclaration)>(Y) ~ SyntaxError # {{{
		{
			return @reqClassStatementBody(modifiers, @reqIdentifier(), first)
		} # }}}

		reqClassStatementBody(
			modifiers: Event<ModifierData>(Y)[] = []
			name: Event<Ast(Identifier)>(Y)
			first: Event(Y)
		): Event<Ast(ClassDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var dyn generic
			if @test(Token.LEFT_ANGLE) {
				generic = @reqTypeGeneric(@yes())
			}

			var version =
				if @test(Token.AMPERAT) {
					@commit()

					unless @test(Token.CLASS_VERSION) {
						@throw('Class Version')
					}

					var data = @value()

					set @yep(AST.Version(data[0], data[1], data[1], @yes()))
				}
				else {
					set NO
				}

			var extends =
				if @test(Token.EXTENDS) {
					@commit()

					set @reqIdentifierOrMember()
				}
				else {
					set NO
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

			return @yep(AST.ClassDeclaration(attributes, name, NO, version, extends, implements, modifiers, members, first, @yes()))
		} # }}}

		reqClassVariable(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			name: Event<Ast(Identifier)>(Y)
			first: Range?
		): Event<Ast(FieldDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var variable = @tryClassVariable(attributes, modifiers, bits, name, NO, first)

			unless variable.ok {
				@throw('Identifier', 'String', 'Template')
			}

			return variable
		} # }}}

		reqComputedPropertyName(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(ComputedPropertyName)>(Y) ~ SyntaxError # {{{
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
				return @yep(AST.AssignmentOperator(.Existential, @yes()))
			}
			else if @test(Token.QUESTION_HASH_EQUALS) {
				return @yep(AST.AssignmentOperator(.NonEmpty, @yes()))
			}
			else if @test(Token.QUESTION_PLUS_EQUALS) {
				return @yep(AST.AssignmentOperator(.Finite, @yes()))
			}
			else if @test(Token.QUESTION_RIGHT_SQUARE_EQUALS) {
				return @yep(AST.AssignmentOperator(.VariantYes, @yes()))
			}

			@throw('?=', '?#=', '?]=', '?+=')
		} # }}}

		reqContinueStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(ContinueStatement, IfStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.IF, Token.UNLESS) == Token.IF {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(eMode + .NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.IfStatement(condition, @yep(AST.ContinueStatement(NO, first, first)), NO, first, condition))
				}
				else {
					return @yep(AST.ContinueStatement(label, first, label))
				}
			}
			else if @token == Token.UNLESS {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(eMode + .NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.UnlessStatement(condition, @yep(AST.ContinueStatement(NO, first, first)), first, condition))
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

						return @yep(AST.IfStatement(condition, @yep(AST.ContinueStatement(label, first, label)), NO, first, condition))
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
					return @yep(AST.ContinueStatement(NO, first, first))
				}
			}
		} # }}}

		reqDefaultAssignmentOperator(): Event<BinaryOperatorData(Assignment)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.EQUALS) {
				return @yep(AST.AssignmentOperator(.Equals, @yes()))
			}
			else if @test(Token.QUESTION_QUESTION_EQUALS) {
				return @yep(AST.AssignmentOperator(.NullCoalescing, @yes()))
			}
			else if @test(Token.QUESTION_HASH_HASH_EQUALS) {
				return @yep(AST.AssignmentOperator(.EmptyCoalescing, @yes()))
			}
			else if @test(Token.QUESTION_PLUS_PLUS_EQUALS) {
				return @yep(AST.AssignmentOperator(.NonFinite, @yes()))
			}
			else if @test(Token.QUESTION_RIGHT_SQUARE_RIGHT_SQUARE_EQUALS) {
				return @yep(AST.AssignmentOperator(.VariantNoCoalescing, @yes()))
			}

			@throw('=', '??=', '?##=', '?]]=')
		} # }}}

		reqDestructuring(
			mut dMode: DestructuringMode?
			fMode: FunctionMode
		): Event<Ast(ArrayBinding, ObjectBinding)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(ArrayBinding)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(BindingElement)>(Y) ~ SyntaxError # {{{
		{
			var modifiers = []
			var mut {
				first: Range? = null
				name: Event<Ast(Identifier, ArrayBinding, ObjectBinding, ThisExpression)> = NO
				atthis = false
				rest = false
			}

			var attributes = @stackInlineAttributes([])

			if ?#attributes {
				first = attributes[0]
			}

			if @test(Token.DOT_DOT_DOT) {
				first ??= @yep()
				rest = true

				@commit()

				modifiers.push(AST.Modifier(ModifierKind.Rest, first))

				if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AMPERAT) {
					name = @reqThisExpression(@yes())
					atthis = true
				}
				else if dMode ~~ DestructuringMode.MODIFIER && @test(Token.MUT) {
					var mark = @mark()
					var modifier = AST.Modifier(ModifierKind.Mutable, @yes())

					if @test(Token.IDENTIFIER) {
						modifiers.push(modifier)

						first ??= modifier
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

				first ??= name
			}
			else if dMode ~~ DestructuringMode.RECURSION && @test(Token.LEFT_SQUARE) {
				name = @reqDestructuringArray(@yes(), dMode, fMode)

				first ??= name
			}
			else if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AMPERAT) {
				name = @reqThisExpression(@yes())
				atthis = true

				first ??= name
			}
			else if dMode ~~ DestructuringMode.MODIFIER && @test(Token.MUT) {
				var mark = @mark()
				var modifier = AST.Modifier(ModifierKind.Mutable, @yes())

				if @test(Token.IDENTIFIER) {
					modifiers.push(modifier)

					first ??= modifier
					name = @yep(AST.Identifier(@scanner.value(), @yes()))
				}
				else {
					@rollback(mark)

					name = @reqIdentifier()

					first ??= name
				}
			}
			else if @test(Token.IDENTIFIER) {
				name = @yep(AST.Identifier(@scanner.value(), @yes()))

				first ??= name
			}
			else if @test(Token.UNDERSCORE) {
				first ??= @yep()

				@commit()
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

				if ?]name && dMode ~~ DestructuringMode.DEFAULT && @test(Token.EXCLAMATION) {
					modifiers.push(AST.Modifier(ModifierKind.Required, @yes()))

					required = true
				}

				if dMode ~~ DestructuringMode.TYPE && @test(Token.COLON) {
					@commit()

					var type = @reqTypeLimited()

					if var operator ?]= @tryDefaultAssignmentOperator(true) {
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.ArrayBindingElement(attributes, modifiers, name, type, operator, defaultValue, first, defaultValue))
					}
					else if required {
						@throw('=', '??=', '##=')
					}
					else {
						return @yep(AST.ArrayBindingElement(attributes, modifiers, name, type, NO, NO, first, type))
					}
				}
				else if @testM(M.POSTFIX_QUESTION) {
					var modifier = AST.Modifier(ModifierKind.Nullable, @yes())

					modifiers.push(modifier)

					if !?]name {
						return @yep(AST.ArrayBindingElement(attributes, modifiers, NO, NO, NO, NO, first, modifier))
					}
				}

				if required {
					var operator = @reqDefaultAssignmentOperator()
					var defaultValue = @reqExpression(.ImplicitMember, fMode)

					return @yep(AST.ArrayBindingElement(attributes, modifiers, name, NO, operator, defaultValue, first, defaultValue))
				}
			}

			if ?]name && dMode ~~ DestructuringMode.DEFAULT {
				var operator = @tryDefaultAssignmentOperator(true)

				if operator.ok {
					var defaultValue = @reqExpression(.ImplicitMember, fMode)

					return @yep(AST.ArrayBindingElement(attributes, modifiers, name, NO, operator, defaultValue, first, defaultValue))
				}
			}

			return @yep(AST.ArrayBindingElement(attributes, modifiers, name, NO, NO, NO, first, name ?]] first))
		} # }}}

		reqDestructuringObject(
			first: Event(Y)
			dMode: DestructuringMode
			fMode: FunctionMode
		): Event<Ast(ObjectBinding)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(BindingElement)>(Y) ~ SyntaxError # {{{
		{
			var modifiers = []
			var mut {
				first: Range? = null
				external: Event = NO
				internal: Event = NO
				atthis = false
				computed = false
				mutable = false
				rest = false
			}

			var attributes = @stackInlineAttributes([])

			if ?#attributes {
				first = attributes[0]
			}

			if @test(Token.DOT_DOT_DOT) {
				first ??= @yep()
				rest = true

				@commit()

				modifiers.push(AST.Modifier(ModifierKind.Rest, first))

				if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AMPERAT) {
					internal = @reqThisExpression(@yes())
				}
				else if dMode ~~ DestructuringMode.MODIFIER && @test(Token.MUT) {
					var mark = @mark()
					var modifier = AST.Modifier(ModifierKind.Mutable, @yes())

					if @test(Token.IDENTIFIER) {
						modifiers.push(modifier)

						first ??= modifier
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

					first ??= modifier
					mutable = true
					internal = @yep(AST.Identifier(@scanner.value(), @yes()))
				}
				else {
					@rollback(mark)

					external = @reqIdentifier()
					first ??= external
				}
			}
			else if dMode ~~ DestructuringMode.COMPUTED && @test(Token.LEFT_SQUARE) {
				first ??= @yep()

				@commit()

				external = @reqIdentifier()

				unless @test(Token.RIGHT_SQUARE) {
					@throw(']')
				}

				modifiers.push(AST.Modifier(ModifierKind.Computed, first, @yes()))

				computed = true
			}
			else {
				if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AMPERAT) {
					first ??= @yep()

					@commit()

					internal = @reqThisExpression(first)
					external = @yep(internal.value.name)
					atthis = true
				}
				else {
					external = @reqIdentifier()
					first ??= external
				}
			}

			if !rest && !?]internal && @test(Token.PERCENT) {
				@commit()

				if dMode ~~ DestructuringMode.RECURSION && @test(Token.LEFT_CURLY) {
					internal = @reqDestructuringObject(@yes(), dMode, fMode)
				}
				else if dMode ~~ DestructuringMode.RECURSION && @test(Token.LEFT_SQUARE) {
					internal = @reqDestructuringArray(@yes(), dMode, fMode)
				}
				else if dMode ~~ DestructuringMode.THIS_ALIAS && @test(Token.AMPERAT) {
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

			if !?]internal {
				internal = external
				external = NO
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

						if var operator?]= @tryDefaultAssignmentOperator(true) {
							var defaultValue = @reqExpression(.ImplicitMember, fMode)

							return @yep(AST.ObjectBindingElement(attributes, modifiers, external, internal, type, operator, defaultValue, first, defaultValue))
						}
						else {
							return @yep(AST.ObjectBindingElement(attributes, modifiers, external, internal, type, NO, NO, first, type))
						}
					}
					else if !rest && @test(Token.QUESTION) {
						modifiers.push(AST.Modifier(ModifierKind.Nullable, @yes()))
					}

					if required {
						var operator = @reqDefaultAssignmentOperator()
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.ObjectBindingElement(attributes, modifiers, external, internal, NO, operator, defaultValue, first, defaultValue))
					}
				}

				if (!rest || ?]internal) && dMode ~~ DestructuringMode.DEFAULT {
					if var operator ?]= @tryDefaultAssignmentOperator(true) {
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.ObjectBindingElement(attributes, modifiers, external, internal, NO, operator, defaultValue, first, defaultValue))
					}
				}

				return @yep(AST.ObjectBindingElement(attributes, modifiers, external, internal, NO, NO, NO, first, internal ?]] external ?]] first))
			}

			if (!rest || ?]internal) && dMode ~~ DestructuringMode.DEFAULT {
				if !rest && @test(Token.QUESTION) {
					var modifier = AST.Modifier(ModifierKind.Nullable, @yes())

					modifiers.push(modifier)

					return @yep(AST.ObjectBindingElement(attributes, modifiers, external, internal, NO, NO, NO, first, modifier))
				}
				else {
					if var operator ?]= @tryDefaultAssignmentOperator(true) {
						var defaultValue = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.ObjectBindingElement(attributes, modifiers, external, internal, NO, operator, defaultValue, first, defaultValue))
					}
				}
			}

			return @yep(AST.ObjectBindingElement(attributes, modifiers, external, internal, NO, NO, NO, first, internal ?]] external ?]] first))
		} # }}}

		reqDiscloseStatement(
			first: Event(Y)
		): Event<Ast(DiscloseDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()
			var typeParameters = @tryTypeParameterList()

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

			return @yep(AST.DiscloseDeclaration(name, typeParameters, members, first, @yes()))
		} # }}}

		reqDoStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(DoUntilStatement, DoWhileStatement)>(Y) ~ SyntaxError # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
		): Event<Ast(EnumValue, FieldDeclaration, MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var member = @tryEnumMember(attributes, modifiers, bits, null)

			unless member.ok {
				@throw('Identifier')
			}

			return member
		} # }}}

		reqEnumMemberBlock(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			members: Ast(EnumValue, FieldDeclaration, MethodDeclaration)[]
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
			members: Ast(EnumValue, FieldDeclaration, MethodDeclaration)[]
		): Void ~ SyntaxError # {{{
		{
			var attributes = @stackOuterAttributes([])
			var modifiers = []

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier(.Closed)

			if ?]accessModifier && @test(Token.LEFT_CURLY) {
				return @reqEnumMemberBlock(
					attributes
					[accessModifier]
					MemberBits.Variable + MemberBits.Method
					members
				)
			}

			var staticMark = @mark()
			var staticModifier = @tryStaticModifier()

			if staticModifier.ok {
				if @test(Token.LEFT_CURLY) {
					return @reqEnumMemberBlock(
						attributes
						[
							accessModifier if ?]accessModifier
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
							accessModifier if ?]accessModifier
							staticModifier
						]
						MemberBits.Method
						accessModifier ?]] staticModifier
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
							accessModifier if ?]accessModifier
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
							accessModifier if ?]accessModifier
							constModifier
						]
						MemberBits.Variable
						accessModifier ?]] constModifier
					)

					if member.ok {
						members.push(member.value)

						return
					}

					@rollback(constMark)
				}
			}

			if ?]accessModifier {
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			name: Event<Ast(Identifier)>(Y)
			first: Range
		): Event<Ast(MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var typeParameters = @tryTypeParameterList()
			var parameters = @reqClassMethodParameterList(null, null)
			var type = @tryFunctionReturns(.Method, true)
			var throws = @tryFunctionThrows()
			var body = @tryFunctionBody(modifiers, .Method)

			@reqNL_1M()

			return @yep(AST.MethodDeclaration(attributes, modifiers, name, typeParameters, parameters, type, throws, body, first, body ?]] throws ?]] type ?]] parameters))
		} # }}}

		reqEnumStatement(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[]? = []
		): Event<Ast(EnumDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryEnumStatement(first, modifiers)

			if statement.ok {
				return statement
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqExportDeclarator(
			fMode: FunctionMode = .Nil
		): Event<Ast(DeclarationSpecifier, NamedSpecifier, PropertiesSpecifier)>(Y) ~ SyntaxError # {{{
		{
			match @matchM(M.EXPORT_STATEMENT, fMode) {
				.ABSTRACT {
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
				.ASYNC {
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
				.BITMASK {
					return @yep(AST.DeclarationSpecifier(@reqBitmaskStatement(@yes())))
				}
				.CLASS {
					return @yep(AST.DeclarationSpecifier(@reqClassStatement(@yes())))
				}
				.ENUM {
					return @yep(AST.DeclarationSpecifier(@reqEnumStatement(@yes())))
				}
				.FINAL {
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
				.FUNC {
					return @yep(AST.DeclarationSpecifier(@reqFunctionStatement(null, @yes())))
				}
				.IDENTIFIER {
					return @reqExportIdentifier(@reqIdentifier())
				}
				.MACRO {
					return @yep(AST.DeclarationSpecifier(@reqMacroStatement(@yes())))
				}
				.NAMESPACE {
					return @yep(AST.DeclarationSpecifier(@reqNamespaceStatement(@yes(), NO, fMode)))
				}
				.SEALED {
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
				.STRUCT {
					return @yep(AST.DeclarationSpecifier(@reqStructStatement(@yes())))
				}
				.SYNTIME {
					var first = @reqIdentifier()

					if @test(.NAMESPACE) {
						var declaration = @reqNamespaceStatement(@yes(), NO, .Nil)
						var statement = @yep(AST.SyntimeDeclaration([], [declaration], first, declaration))

						return @yep(AST.DeclarationSpecifier(statement))
					}
					else if @test(.MACRO) {
						var declaration = @reqMacroStatement(@yes())
						var statement = @yep(AST.SyntimeDeclaration([], [declaration], first, declaration))

						return @yep(AST.DeclarationSpecifier(statement))
					}
					else {
						return @reqExportIdentifier(first)
					}
				}
				.TUPLE {
					return @yep(AST.DeclarationSpecifier(@reqTupleStatement(@yes())))
				}
				.TYPE {
					return @yep(AST.DeclarationSpecifier(@reqTypeStatement(@yes(), @reqIdentifier())))
				}
				.VAR {
					return @yep(AST.DeclarationSpecifier(@reqVarStatement(@yes(), .NoAwait, .Nil)))
				}
				else {
					@throw()
				}
			}
		} # }}}

		reqExportIdentifier(
			identifier: Event<Ast(Identifier)>(Y)
		): Event<Ast(NamedSpecifier, PropertiesSpecifier)>(Y) ~ SyntaxError # {{{
		{
			var mut value: Event<Ast(Identifier, MemberExpression)>(Y) = identifier
			var mut topIdentifier: Event<Ast(Identifier)> = NO

			if @testNS(Token.DOT) {
				do {
					@commit()

					if @testNS(Token.ASTERISK) {
						var modifier = @yep(AST.Modifier(ModifierKind.Wildcard, @yes()))

						return @yep(AST.NamedSpecifier([modifier], value, NO, value, modifier))
					}
					else {
						topIdentifier = @reqIdentifier()

						value = @yep(AST.MemberExpression([], value, topIdentifier))
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

					return @yep(AST.NamedSpecifier([modifier], value, NO, value, modifier))
				}
				else if @test(Token.LEFT_CURLY) {
					var members = []

					@commit().NL_0M()

					until @test(Token.RIGHT_CURLY) {
						var internal = @reqIdentifier()

						if @test(Token.EQUALS_RIGHT_ANGLE) {
							@commit()

							var external = @reqIdentifier()

							members.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))
						}
						else {
							members.push(@yep(AST.NamedSpecifier([], internal, NO, internal, internal)))
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

					repeat {
						var internal = @reqIdentifier()

						if @test(Token.EQUALS_RIGHT_ANGLE) {
							@commit()

							var external = @reqIdentifier()

							members.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))
						}
						else {
							members.push(@yep(AST.NamedSpecifier([], internal, NO, internal, internal)))
						}

						if @test(Token.COMMA) {
							@commit()
						}
						else {
							break
						}
					}

					var last = members[members.length - 1]

					return @yep(AST.PropertiesSpecifier([], value, members, value, last))
				}
			}
			else {
				return @yep(AST.NamedSpecifier([], value, topIdentifier, value, value))
			}
		} # }}}

		reqExportModule(
			first: Event(Y)
		): Event<Ast(ExportDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var mut last = first
			var declarations = []

			if @match(Token.EQUALS, Token.IDENTIFIER, Token.LEFT_CURLY) == Token.EQUALS {
				var modifier = @yep(AST.Modifier(.Default, @yes()))
				var identifier = @reqIdentifier()

				declarations.push(@yep(AST.NamedSpecifier([modifier], identifier, NO, first, identifier)))
			}
			else if @token == Token.IDENTIFIER {

				repeat {
					var internal = @reqIdentifier()
					var external =
						if @test(Token.EQUALS_RIGHT_ANGLE) {
							@commit()

							set @reqIdentifier()
						}
						else {
							set internal
						}

					declarations.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))

					if @test(Token.COMMA) {
						@commit()
					}
					else {
						break
					}
				}

				last = declarations[declarations.length - 1]
			}
			else if @token == Token.LEFT_CURLY {
				@commit()

				while @until(Token.RIGHT_CURLY) {
					@commit()

					var internal = @reqIdentifier()
					var external =
						if @test(Token.EQUALS_RIGHT_ANGLE) {
							@commit()

							set @reqIdentifier()
						}
						else {
							set internal
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
			fMode: FunctionMode = .Nil
		): Event<Ast(ExportDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []

			var dyn last
			if @match(Token.ASTERISK, Token.LEFT_CURLY) == Token.ASTERISK {
				var asteriskFirst = @yes()

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

					declarations.push(@yep(AST.GroupSpecifier([modifier], elements, NO, modifier, last)))
				}
				else {
					var modifier = @yep(AST.Modifier(ModifierKind.Wildcard, asteriskFirst))

					declarations.push(@yep(AST.GroupSpecifier([modifier], [], NO, modifier, modifier)))

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

					declarator = @reqExportDeclarator(fMode)

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
				declarations.push(@reqExportDeclarator(fMode))

				while @test(Token.COMMA) {
					@commit()

					declarations.push(@reqExportDeclarator(fMode))
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
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(ExpressionStatement, IfStatement, UnlessStatement, ForStatement, RepeatStatement)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(eMode, fMode)

			if @match(Token.FOR, Token.IF, Token.REPEAT, Token.UNLESS) == Token.FOR {
				var first = @yes()
				var iteration = @reqIteration(null, fMode)

				return @yep(AST.ForStatement([iteration], @yep(AST.ExpressionStatement(expression)), NO, first, expression))
			}
			else if @token == Token.IF {
				@commit()

				var condition = @reqExpression(eMode, fMode)

				return @yep(AST.IfStatement(condition, @yep(AST.ExpressionStatement(expression)), NO, expression, condition))
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
		): Event<Ast(ClassDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()
			var typeParameters = @tryTypeParameterList()

			var extends =
				if @test(Token.EXTENDS) {
					@commit()

					set @reqIdentifier()
				}
				else {
					set NO
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

				return @yep(AST.ClassDeclaration(attributes, modifiers, name, typeParameters, NO, extends, implements, members, first, @yes()))
			}
			else {
				return @yep(AST.ClassDeclaration([], modifiers, name, typeParameters, NO, extends, implements, [], first, extends ?]] typeParameters ?]] name))
			}
		} # }}}

		reqExternClassField(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			type: Event<Ast(Type)>
			first: Event(Y)
		): Event<Ast(FieldDeclaration)>(Y) ~ SyntaxError # {{{
		{
			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, NO, first, type ?]] name))
		} # }}}

		reqExternClassMember(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)?
		): Event<Ast(FieldDeclaration, MethodDeclaration)>(Y) ~ SyntaxError # {{{
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
				return @reqExternClassField(attributes, modifiers, name, NO, first ?? name)
			}
		} # }}}

		reqExternClassMemberList(
			members: Event<Ast(ClassMember)>(Y)[]
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			round: Event
			first: Event(Y)
		): Event<Ast(MethodDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var typeParameters = @tryTypeParameterList()
			var parameters = @reqClassMethodParameterList(round, DestructuringMode.EXTERNAL_ONLY)
			var type = @tryFunctionReturns(.Method, false)

			@reqNL_1M()

			return @yep(AST.MethodDeclaration(attributes, modifiers, name, typeParameters, parameters, type, null, null, first, type ?]] parameters))
		} # }}}

		reqExternFunctionDeclaration(
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)
		): Event<Ast(FunctionDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()
			var typeParameters = @tryTypeParameterList()

			if @test(Token.LEFT_ROUND) {
				var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionDeclaration([], modifiers, name, typeParameters, parameters, type, throws, null, first, throws ?]] type ?]] parameters))
			}
			else {
				var position = @yep()
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionDeclaration([], modifiers, name, typeParameters, null, type, throws, null, first, throws ?]] type ?]] name))
			}
		} # }}}

		reqExternNamespaceDeclaration(
			first: Event(Y)
			modifiers: Event<ModifierData>(Y)[] = []
		): Event<Ast(NamespaceDeclaration)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(ExternOrImportDeclaration)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(ExternOrRequireDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.ExternOrRequireDeclaration(attributes, declarations, first, last))
		} # }}}

		reqExternStatement(
			first: Event(Y)
		): Event<Ast(ExternDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.ExternDeclaration(attributes, declarations, first, last))
		} # }}}

		reqExternVariableDeclarator(
			name: Event<Ast(Identifier)>(Y)
		): Event<Ast(VariableDeclarator, FunctionDeclaration)>(Y) ~ SyntaxError # {{{
		{
			if @match(Token.COLON, Token.LEFT_ROUND) == Token.COLON {
				@commit()

				var type = @reqType()

				return @yep(AST.VariableDeclarator([], name, type, name, type))
			}
			else if @token == Token.LEFT_ROUND {
				var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)

				return @yep(AST.FunctionDeclaration([], [], name, NO, parameters, type, null, null, name, type ?]] parameters))
			}
			else {
				return @yep(AST.VariableDeclarator([], name, NO, name, name))
			}
		} # }}}

		reqExternalDeclarations(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(DescriptiveType)>(Y)[]
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
						declarations.push(@yep(AST.VariableDeclarator([], identifier, NO, identifier, identifier)))

						while @test(Token.COMMA) {
							@commit()

							var declName = @reqIdentifier()

							if @test(Token.COLON) {
								@commit()

								var type = @reqTypeEntity()

								declarations.push(@yep(AST.VariableDeclarator([], declName, type, declName, type)))
							}
							else {
								declarations.push(@yep(AST.VariableDeclarator([], declName, NO, declName, declName)))
							}
						}
					}
					else if @test(Token.NEWLINE) {
						declarations.push(@yep(AST.VariableDeclarator([], identifier, NO, identifier, identifier)))
					}
					else if @test(Token.COLON) {
						@commit()

						var type = @tryTypeEntity()

						if type.ok {
							declarations.push(@yep(AST.VariableDeclarator([], identifier, type, identifier, type)))

							while @test(Token.COMMA) {
								@commit()

								var declName = @reqIdentifier()

								if @test(Token.COLON) {
									@commit()

									var declType = @reqTypeEntity()

									declarations.push(@yep(AST.VariableDeclarator([], declName, declType, declName, declType)))
								}
								else {
									declarations.push(@yep(AST.VariableDeclarator([], declName, NO, declName, declName)))
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
		): Event<Ast(FallthroughStatement)>(Y) { # {{{
			return @yep(AST.FallthroughStatement(first))
		} # }}}

		reqForStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(ForStatement)>(Y) ~ SyntaxError # {{{
		{
			var iterations = []

			var mut mark = @mark()

			@NL_0M()

			if @test(.LEFT_CURLY) {
				@commit().NL_0M()

				var mut attributes = @stackInlineAttributes([])

				if @test(.VAR) {
					while @test(.VAR) {
						iterations.push(@reqIteration(attributes, fMode))

						@NL_0M()

						attributes = @stackInlineAttributes([])
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
				else if ?#attributes {
					@throw('var')
				}
				else {
					@rollback(mark)

					iterations.push(@reqIteration(null, fMode))
				}
			}
			else {
				@rollback(mark)

				iterations.push(@reqIteration(null, fMode))
			}

			@NL_0M()

			var body = @reqBlock(NO, null, fMode)

			mark = @mark()

			@commit().NL_0M()

			var else =
				if @test(Token.ELSE) {
					@commit().NL_0M()

					set @reqBlock(NO, null, fMode)
				}
				else {
					@rollback(mark)

					set NO
				}

			return @yep(AST.ForStatement(iterations, body, else, first, else ?]] body))
		} # }}}

		reqFunctionBody(
			modifiers: Event<ModifierData>(Y)[]
			fMode: FunctionMode
		): Event<Ast(Block, Expression, IfStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			match @match(.LEFT_CURLY, .EQUALS_RIGHT_ANGLE) {
				.LEFT_CURLY {
					return @reqBlock(@yes(), null, fMode - FunctionMode.NoPipeline)
				}
				.EQUALS_RIGHT_ANGLE {
					@commit().NL_0M()

					var expression = @reqExpression(.NoRestriction, fMode)

					if @match(Token.IF, Token.UNLESS) == Token.IF {
						@commit()

						var condition = @reqExpression(.NoRestriction, fMode)
						var whenTrue = @yep(AST.ReturnStatement(expression, expression, expression))

						return @yep(AST.IfStatement(condition, whenTrue, NO, expression, condition))
					}
					else if @token == Token.UNLESS {
						@commit()

						var condition = @reqExpression(.NoRestriction, fMode)
						var whenTrue = @yep(AST.ReturnStatement(expression, expression, expression))

						return @yep(AST.UnlessStatement(condition, whenTrue, expression, condition))
					}
					else {
						return expression
					}
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
		): Event<Event<Ast(Parameter)>(Y)[]>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(FunctionDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()
			var typeParameters = @tryTypeParameterList()
			var parameters = @reqFunctionParameterList(.Nil)
			var type = @tryFunctionReturns()

			var throws = @tryFunctionThrows()
			var body = @reqFunctionBody(modifiers, .Nil)

			return @yep(AST.FunctionDeclaration([], modifiers, name, typeParameters, parameters, type, throws, body, first, body))
		} # }}}

		reqGeneric(): Event<Ast(Identifier)>(Y) ~ SyntaxError # {{{
		{
			return @reqIdentifier()
		} # }}}

		reqIdentifier(): Event<Ast(Identifier)>(Y) ~ SyntaxError # {{{
		{
			if @scanner.test(Token.IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				@throw('Identifier')
			}
		} # }}}

		reqIdentifierOrMember(): Event<Ast(Identifier, MemberExpression)>(Y) ~ SyntaxError # {{{
		{
			var mut name: Event<Ast(Identifier, MemberExpression)>(Y) = @reqIdentifier()

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

		reqIfDeclaration(
			fMode: FunctionMode
		): Event<Ast(VariableDeclaration)>(Y) ~ SyntaxError # {{{
		{
			if var declaration ?]= @tryIfDeclaration(null, fMode) {
				return declaration
			}
			else {
				@throw('Variable Declaration')
			}
		} # }}}

		reqIfDOC(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]?
			fMode: FunctionMode
		): Event<Ast(VariableDeclaration, Expression)[]>(Y) ~ SyntaxError # {{{
		{
			if var declaration ?]= @tryIfDeclaration(attributes, fMode) {
				@NL_0M()

				if @test(.SEMICOLON_SEMICOLON) {
					@commit().NL_0M()

					var condition = @reqExpression(.NoAnonymousFunction, fMode)

					return @yep([declaration.value, condition.value])
				}
				else {
					return @yep([declaration.value])
				}
			}
			else if ?#attributes {
				@throw('var')
			}

			var condition = @reqExpression(.NoAnonymousFunction, fMode)

			if @test(.SEMICOLON_SEMICOLON) {
				@commit().NL_0M()

				var declaration = @reqIfDeclaration(fMode)

				return @yep([condition.value, declaration.value])
			}
			else {
				return @yep([condition.value])
			}
		} # }}}

		reqIfStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(IfStatement)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var declarations =
				if @test(.LEFT_CURLY) {
					var mark = @mark()

					@commit().NL_0M()

					var attributes = @stackInlineAttributes([])

					if @test(.VAR) {
						var result = [@reqIfDOC(attributes, fMode).value]

						@NL_0M()

						while @until(.RIGHT_CURLY) {
							result.push(@reqIfDOC(null, fMode).value)

							@NL_0M()
						}

						unless @test(.RIGHT_CURLY) {
							@throw('}')
						}

						@commit().NL_0M()

						unless @test(.THEN) {
							@throw('then')
						}

						@commit()

						set result
					}
					else if ?#attributes {
						@throw('var')
					}
					else {
						@rollback(mark)

						set [@reqIfDOC(null, fMode).value]
					}
				}
				else {
					set [@reqIfDOC(null, fMode).value]
				}

			var condition =
				if #declarations == 1 && #declarations[0] == 1 && declarations[0][0].kind != AstKind.VariableDeclaration {
					set @yep(declarations.pop()[0])
				}
				else {
					set null
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

					return @yep(AST.IfStatement(condition ?? declarations, whenTrue, NO, first, whenTrue))
				}
			}
			else {
				return @yep(AST.IfStatement(condition ?? declarations, whenTrue, NO, first, whenTrue))
			}
		} # }}}

		reqImplementMemberList(
			members: Event<Ast(ClassMember)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var dyn first = null

			var attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier(.Opened)

			if ?]accessModifier && @test(Token.LEFT_CURLY) {
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
				if ?]accessModifier {
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
				var modifier = @yep(AST.Modifier(if @token == Token.OVERRIDE set ModifierKind.Override else ModifierKind.Overwrite, @yes()))
				var modifiers = [modifier]
				if ?]accessModifier {
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
					if ?]accessModifier {
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
					if ?]accessModifier {
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
							if ?]accessModifier {
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
						var modifier = @yep(AST.Modifier(if @token == Token.OVERRIDE set ModifierKind.Override else ModifierKind.Overwrite, @yes()))

						if @test(Token.LEFT_CURLY) {
							var modifiers = [finalModifier, modifier]
							if ?]accessModifier {
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
				if ?]accessModifier {
					modifiers.unshift(accessModifier)
				}

				if @test(Token.LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						if finalModifier.ok set MemberBits.Variable else MemberBits.Variable + MemberBits.FinalVariable
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

			if ?]accessModifier {
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
			bits: MemberBits
		): Event<Ast(ImplementDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var late interface: Event
			var late variable: Event(Y)

			var identifier = @reqIdentifierOrMember()

			if @test(Token.FOR) {
				@commit()

				interface = identifier
				variable = @reqIdentifierOrMember()
			}
			else {
				interface = NO
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

			if bits ~~ .Syntime {
				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					var name = @reqIdentifier()
					var parameters = @reqFunctionParameterList(.Nil)
					var body =
						if @match(.LEFT_CURLY, .EQUALS_RIGHT_ANGLE) == .LEFT_CURLY {
							set @reqBlock(@yes(), null, .Syntime)
						}
						else if @token == .EQUALS_RIGHT_ANGLE {
							@commit()

							if @test(.QUOTE) {
								set @reqQuoteExpression(@yes())
							}
							else {
								set @reqExpression(.Nil, .Nil)
							}
						}
						else {
							@throw('{', '=>')
						}

					var declaration = @yep(AST.MethodDeclaration([], [], name, NO, parameters, null, null, body, name, body))

					members.push(declaration)

					@NL_0M()
				}
			}
			else {
				until @test(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@reqImplementMemberList(members)
				}
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.ImplementDeclaration(attributes, variable, interface, members, first, @yes()))
		} # }}}

		reqImportDeclarator(): Event<Ast(ImportDeclarator)>(Y) ~ SyntaxError # {{{
		{
			var source = @reqString()
			var declaratorModifiers = []
			var mut arguments = null
			var mut last: Event(Y) = source

			if @test(Token.LEFT_ROUND) {
				@commit()

				arguments = []

				if @test(Token.DOT_DOT_DOT) {
					declaratorModifiers.push(AST.Modifier(ModifierKind.Autofill, @yes()))

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
			var mut type: Event = NO
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

					specifiers.push(@yep(AST.GroupSpecifier([modifier], elements, NO, modifier, last)))

					last = specifiers[specifiers.length - 1]
				}
				.EQUALS_RIGHT_ANGLE {
					var modifier = @yep(AST.Modifier(ModifierKind.Alias, @yes()))

					if type ?]= @tryTypeDescriptive(TypeMode.Module + TypeMode.NoIdentifier) {
						var value = type.value

						if ?value.name {
							specifiers.push(@yep(AST.NamedSpecifier([modifier], @yep(value.name), NO, modifier, type)))

							last = type
						}
						else {
							@throw()
						}
					}
					else {
						var elements = []
						var identifier = @reqIdentifier()

						elements.push(@yep(AST.NamedSpecifier(identifier)))

						if @test(Token.COMMA) {
							@commit()

							var element = @reqDestructuring(DestructuringMode.Nil, FunctionMode.Nil)

							elements.push(@yep(AST.NamedSpecifier(element)))
						}

						last = elements[elements.length - 1]

						specifiers.push(@yep(AST.GroupSpecifier([modifier], elements, NO, modifier, last)))
					}
				}
				.FOR {
					var first = @yes()
					var elements = []

					if @test(Token.LEFT_CURLY) {
						@commit().NL_0M()

						while @until(Token.RIGHT_CURLY) {
							var descType = @tryTypeDescriptive(TypeMode.Module + TypeMode.NoIdentifier)

							if descType.ok {
								if @test(Token.EQUALS_RIGHT_ANGLE) {
									@commit()

									@submitNamedGroupSpecifier([], descType, elements)
								}
								else {
									elements.push(@yep(AST.TypedSpecifier(descType, descType)))
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
						if var descType ?]= @tryTypeDescriptive(TypeMode.Module + TypeMode.NoIdentifier) {
							if @test(Token.EQUALS_RIGHT_ANGLE) {
								@commit()

								@submitNamedGroupSpecifier([], descType, elements)
							}
							else {
								elements.push(@yep(AST.TypedSpecifier(descType, descType)))
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

					specifiers.push(@yep(AST.GroupSpecifier([], elements, NO, first, last)))

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

						specifiers.push(@yep(AST.GroupSpecifier([modifier], elements, NO, modifier, last)))
					}
					else if @token == Token.FOR {
						@commit()

						var elements = []

						if @test(Token.ASTERISK) {
							var modifier = @yep(AST.Modifier(ModifierKind.Wildcard, @yes()))

							specifiers.push(@yep(AST.GroupSpecifier([modifier], [], NO, modifier, modifier)))

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

			return @yep(AST.ImportDeclarator(attributes, declaratorModifiers, source, arguments, type, specifiers, source, last))
		} # }}}

		reqImportStatement(
			first: Event(Y)
		): Event<Ast(ImportDeclaration)>(Y) ~ SyntaxError # {{{
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

		reqIncludeDeclarator(): Event<Ast(IncludeDeclarator)>(Y) ~ SyntaxError # {{{
		{
			unless @test(Token.STRING) {
				@throw('String')
			}

			var file = @yes(@value())

			return @yep(AST.IncludeDeclarator(file!!))
		} # }}}

		reqIncludeStatement(
			first: Event(Y)
		): Event<Ast(IncludeDeclaration)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(IncludeAgainDeclaration)>(Y) ~ SyntaxError # {{{
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
			mut attributes: Event<Ast(AttributeDeclaration)>(Y)[]?
			fMode: FunctionMode
		): Event<IterationData>(Y) ~ SyntaxError # {{{
		{
			var modifiers = []
			var mut first = null
			var mut declaration = false

			var mark = @mark()

			attributes ??= @stackInlineAttributes([])

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
			else if ?#attributes {
				@throw('var')
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
				destructuring = @tryDestructuring(if declaration set .Declaration else null, fMode)

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

					return @reqIterationIn(attributes, modifiers, destructuring, type1, identifier2, expression, first, fMode)
				}
				else if @token == Token.OF {
					@commit()

					return @reqIterationOf(attributes, modifiers, destructuring, type1, identifier2, first, fMode)
				}
				else {
					@throw('in', 'of')
				}
			}
			else if identifier2.ok {
				if @match(Token.IN, Token.OF) == Token.IN {
					@commit()

					return @reqIterationInRange(attributes, modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else if @token == Token.OF {
					@commit()

					return @reqIterationOf(attributes, modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					@throw('in', 'of')
				}
			}
			else if identifier1.ok {
				if @match(Token.FROM, Token.FROM_TILDE, Token.IN, Token.OF) == .FROM | .FROM_TILDE {
					return @reqIterationFrom(attributes, modifiers, identifier1, first, fMode)
				}
				else if @token == .IN {
					@commit()

					return @reqIterationInRange(attributes, modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else if @token == .OF {
					@commit()

					return @reqIterationOf(attributes, modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					@throw('from', 'in', 'of')
				}
			}
			else {
				if @test(.IN) {
					@commit()

					var expression = @reqExpression(.Nil, fMode)

					return @reqIterationIn(attributes, modifiers, identifier1, type1, identifier2, expression, first, fMode)
				}
				else if @test(.OF) {
					@commit()

					return @reqIterationOf(attributes, modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					@throw('in', 'of')
				}
			}
		} # }}}

		reqIterationFrom(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			variable: Event<Ast(Identifier)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(From)>(Y) ~ SyntaxError # {{{
		{
			var late from
			if @token == Token.FROM_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))

				from = @reqExpression(.Nil, fMode)

				AST.pushModifier(from.value, modifier, true)
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

			var late to
			if @match(Token.TO, Token.TO_TILDE) == Token.TO {
				@commit()

				to = @reqExpression(.Nil, fMode)
			}
			else if @token == Token.TO_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))

				to = @reqExpression(.Nil, fMode)

				AST.pushModifier(to.value, modifier, true)
			}
			else {
				@throw('to', 'to~')
			}

			@NL_0M()

			var late step
			if @test(Token.STEP) {
				@commit()

				step = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else {
				step = NO
			}

			var mut until: Event = NO
			var mut while: Event = NO
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

			var when =
				if @test(Token.WHEN) {
					var whenFirst = @yes()

					set @relocate(@reqExpression(.Nil, fMode), whenFirst, null)
				}
				else {
					set NO
				}

			return @yep(AST.IterationFrom(attributes, modifiers, variable, from, to, step, until, while, when, first, when ?]] while ?]] until ?]] step ?]] to))
		} # }}}

		reqIterationIn(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<Ast(Identifier, ArrayBinding, ObjectBinding)>
			type: Event<Ast(Type)>
			index: Event<Ast(Identifier)>
			expression: Event<Ast(Expression)>(Y)
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(Array)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var late from
			if @match(Token.FROM, Token.FROM_TILDE) == Token.FROM {
				@commit()

				from = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else if @token == Token.FROM_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))

				from = @reqExpression(.Nil, fMode)

				AST.pushModifier(from.value, modifier, true)

				@NL_0M()
			}
			else {
				from = NO
			}

			var late order
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
			else {
				order = NO
			}

			var late to
			if @match(Token.TO, Token.TO_TILDE) == Token.TO {
				@commit()

				to = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else if @token == Token.TO_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind.Ballpark, @yes()))

				to = @reqExpression(.Nil, fMode)

				AST.pushModifier(to.value, modifier, true)

				@NL_0M()
			}
			else {
				to = NO
			}

			var late step
			if @test(Token.STEP) {
				@commit()

				step = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else {
				step = NO
			}

			var late split
			if @test(Token.SPLIT) {
				@commit()

				split = @reqExpression(.Nil, fMode)

				@NL_0M()
			}
			else {
				split = NO
			}

			var mut until: Event = NO
			var mut while: Event = NO
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

			var when =
				if @test(Token.WHEN) {
					var whenFirst = @yes()

					set @relocate(@reqExpression(.Nil, fMode), whenFirst, null)
				}
				else {
					set NO
				}

			return @yep(AST.IterationArray(attributes, modifiers, value, type, index, expression, from, to, step, split, until, while, when, first, when ?]] while ?]] until ?]] split ?]] step ?]] to ?]] order ?]] from ?]] expression))
		} # }}}

		reqIterationInRange(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<Ast(Identifier, ArrayBinding, ObjectBinding)>
			type: Event<Ast(Type)>
			index: Event<Ast(Identifier)>
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(Array, Range)>(Y) ~ SyntaxError # {{{
		{
			var operand = @tryRangeOperand(ExpressionMode.InlineOnly, fMode)

			if operand.ok {
				if @test(Token.LEFT_ANGLE, Token.DOT_DOT) {
					if @token == Token.LEFT_ANGLE {
						AST.pushModifier(operand.value, @yep(AST.Modifier(ModifierKind.Ballpark, @yes())), false)

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
						AST.pushModifier(to.value, modifier, true)
					}

					var step =
						if @test(Token.DOT_DOT) {
							@commit()

							set @reqPrefixedOperand(.InlineOnly, fMode)
						}
						else {
							set NO
						}

					return @reqIterationRange(attributes, modifiers, value!!, index, operand, to, step, first, fMode)
				}
				else {
					var expression = @tryOperation(operand, .Nil, fMode)

					return @reqIterationIn(attributes, modifiers, value, type, index, expression!!, first, fMode)
				}
			}
			else {
				var expression = @reqExpression(.Nil, fMode)

				return @reqIterationIn(attributes, modifiers, value, type, index, expression, first, fMode)
			}
		} # }}}

		reqIterationOf(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<Ast(Identifier, ArrayBinding, ObjectBinding)>
			type: Event<Ast(Type)>
			key: Event<Ast(Identifier)>
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(Object)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(.Nil, fMode)

			var mut until: Event = NO
			var mut while: Event = NO
			if @match(Token.UNTIL, Token.WHILE) == Token.UNTIL {
				@commit()

				until = @reqExpression(.Nil, fMode)
			}
			else if @token == Token.WHILE {
				@commit()

				while = @reqExpression(.Nil, fMode)
			}

			@NL_0M()

			var when =
				if @test(Token.WHEN) {
					var whenFirst = @yes()

					set @relocate(@reqExpression(.Nil, fMode), whenFirst, null)
				}
				else {
					set NO
				}

			return @yep(AST.IterationObject(attributes, modifiers, value, type, key, expression, until, while, when, first, when ?]] while ?]] until ?]] expression))
		} # }}}

		reqIterationRange(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<Ast(Identifier)>
			index: Event<Ast(Identifier)>
			from: Event<Ast(Expression)>(Y)
			to: Event<Ast(Expression)>(Y)
			filter: Event<Ast(Expression)>
			first: Event(Y)
			fMode: FunctionMode
		): Event<IterationData(Range)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			var mut until: Event = NO
			var mut while: Event = NO
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

			var when =
				if @test(Token.WHEN) {
					var whenFirst = @yes()

					set @relocate(@reqExpression(.Nil, fMode), whenFirst, null)
				}
				else {
					set NO
				}

			return @yep(AST.IterationRange(attributes, modifiers, value, index, from, to, filter, until, while, when, first, when ?]] while ?]] until ?]] filter ?]] to))
		} # }}}

		reqJunctionExpression(
			operator: Event<BinaryOperatorData>(Y)
			mut eMode: ExpressionMode
			fMode: FunctionMode
			values: Ast(Expression, Type)[]
			type: Boolean
		): Ast(JunctionExpression) ~ SyntaxError # {{{
		{
			@NL_0M()

			eMode += ExpressionMode.ImplicitMember

			var operands: Ast(Expression, Type)[] = [values.pop()!?]

			if type {
				operands.push(@reqTypeLimited(false).value)
			}
			else {
				operands.push(@reqBinaryOperand(eMode, fMode).value)
			}

			var kind = operator.value.kind

			repeat {
				var mark = @mark()
				var op = @tryJunctionOperator()

				if op.ok && op.value.kind == kind {
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
		): Event<Ast(Block, Expression)>(Y) ~ SyntaxError # {{{
		{
			var body = @tryLambdaBody(modifiers, fMode)

			if body.ok {
				return body
			}
			else {
				@throw('=>')
			}
		} # }}}

		reqMacroStatement(
			modifiers: Event<ModifierData>(Y)[] = []
			first: Event(Y)
		): Event<Ast(MacroDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()
			var parameters = @reqFunctionParameterList(.Nil)
			var body =
				if @match(.LEFT_CURLY, .EQUALS_RIGHT_ANGLE) == .LEFT_CURLY {
					set @reqBlock(@yes(), null, .Syntime)
				}
				else if @token == .EQUALS_RIGHT_ANGLE {
					@commit()

					if @test(.QUOTE) {
						set @reqQuoteExpression(@yes())
					}
					else {
						set @reqExpression(.Nil, .Nil)
					}
				}
				else {
					@throw('{', '=>')
				}

			return @yep(AST.MacroDeclaration([], modifiers, name, parameters, body, first, body))
		} # }}}

		reqMatchBinding(
			fMode: FunctionMode
		): Event<Ast(VariableDeclarator, ArrayBinding, ObjectBinding)>(Y) ~ SyntaxError # {{{
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
					var late first: Event(Y)
					var mut name = null
					var mut type: Event = NO

					if @test(Token.VAR) {
						var varModifier = @yep(AST.Modifier(ModifierKind.Declarative, @yes()))

						first = varModifier

						var varDMode: DestructuringMode = .MODIFIER + .RECURSION + .TYPE
						var mark2 = @mark()
						var mut typing = true

						if @test(Token.MUT) {
							var mutModifier = @yep(AST.Modifier(ModifierKind.Mutable, @yes()))

							match @match(Token.LEFT_CURLY, Token.LEFT_SQUARE) {
								Token.LEFT_CURLY {
									name = @tryDestructuringObject(@yes(), varDMode, fMode)
								}
								Token.LEFT_SQUARE {
									name = @tryDestructuringArray(@yes(), varDMode, fMode)
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
									name = @tryDestructuringObject(@yes(), varDMode, fMode)
								}
								Token.LEFT_SQUARE {
									name = @tryDestructuringArray(@yes(), varDMode, fMode)
								}
								else {
									name = @tryIdentifier()
								}
							}

							if ?]name {
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

						first = name
					}

					return @yep(AST.VariableDeclarator(modifiers, name, type, first, type ?]] name))
				}
			}
		} # }}}

		reqMatchCaseExpression(
			fMode: FunctionMode
		): Event<Ast(Statement)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(MatchClause, SyntimeStatement)[]>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			unless @test(Token.LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var clauses = []

			until @test(Token.RIGHT_CURLY) {
				var attributes = @stackOuterAttributes([])

				if @test(.AT_SYNTIME) {
					var statement = @reqSyntimeStatement(@yes()).value

					AST.pushAttributes(statement, attributes)

					clauses.push(statement)

					@reqNL_1M()

					continue
				}

				var late binding, filter, body, first
				var conditions = []

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

					binding = filter = NO
				}
				else {
					if @test(Token.WITH, Token.WHEN) {
						first = @yep()
					}
					else {
						first = @reqMatchCondition(fMode)

						conditions.push(first)

						while @test(Token.COMMA) {
							@commit()

							conditions.push(@reqMatchCondition(fMode))
						}

						@NL_0M()
					}

					if @test(Token.WITH) {
						@commit()

						binding = @reqMatchBinding(fMode)

						@NL_0M()
					}
					else {
						binding = NO
					}

					if @test(Token.WHEN) {
						@commit()

						filter = @reqExpression(.ImplicitMember + .NoAnonymousFunction, fMode)

						@NL_0M()
					}
					else {
						filter = NO
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

				clauses.push(AST.MatchClause(conditions, binding, filter, body, first, body))
			}

			unless @test(Token.RIGHT_CURLY) {
				@throw('}')
			}

			return @yes(clauses)
		} # }}}

		reqMatchCondition(
			fMode: FunctionMode
		): Event<Ast(Expression, MatchConditionArray, MatchConditionObject, MatchConditionRange, MatchConditionType)>(Y) ~ SyntaxError # {{{
		{
			match @match(Token.LEFT_CURLY, Token.LEFT_SQUARE, Token.IS) {
				Token.IS {
					var first = @yes()
					var type = @reqType(.InlineOnly + .ImplicitMember)

					return @yep(AST.MatchConditionType(type, first, type))
				}
				Token.LEFT_CURLY {
					var first = @yes()
					var properties = []

					if !@test(Token.RIGHT_CURLY) {
						repeat {
							var name = @reqIdentifier()

							if @test(Token.COLON) {
								@commit()

								var value = @reqMatchConditionValue(fMode)

								properties.push(@yep(AST.ObjectMember([], [], name, NO, value, name, value)))
							}
							else {
								properties.push(@yep(AST.ObjectMember([], [], name, NO, NO, name, name)))
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
					var first = @yes()
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
		): Event<Ast(Expression, MatchConditionRange)>(Y) ~ SyntaxError # {{{
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
				var values: Ast(Expression)[] = [operand.value]

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
		): Event<Ast(Literal)>(Y) ~ SyntaxError # {{{
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
					@throw(if delimiter == Token.ML_DOUBLE_QUOTE set '"""' else "'''")
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
		): Event<Ast(TemplateExpression)>(Y) ~ SyntaxError # {{{
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
					@throw(if delimiter == Token.ML_BACKQUOTE set '```' else '~~~')
				}
				else {
					var line: [] = [currentIndent]

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

					for var [indent, firstToken? = null, ...rest], index in lines {
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
							else if previous.kind == AstKind.Literal {
								previous.value += '\n'
								previous.end.column += 1
							}
							else {
								previous = AST.Literal(null, '\n', {
									line: previous.end.line:!!!(Number)
									column: previous.end.column:!!!(Number) + 1
								}, {
									line: previous.end.line:!!!(Number)
									column: previous.end.column:!!!(Number) + 2
								})

								elements.push(@yep(previous))
							}
						}

						if ?firstToken {
							unless indent.startsWith(baseIndent) {
								throw @error(`Unexpected indentation`, firstToken.line:!!!(Number) + index + 1, 1)
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
								else if previous.kind == AstKind.Literal {
									previous.value += value
									previous.end.line += 1
									previous.end.column += indent.length
								}
								else {
									previous = AST.Literal(null, value, {
										line: previous.end.line:!!!(Number) + 1
										column: baseIndent.length
									}, {
										line: previous.end.line:!!!(Number) + 1
										column: indent.length
									})

									elements.push(@yep(previous))
								}
							}

							if ?previous && firstToken.value.kind == AstKind.Literal {
								previous.value += firstToken.value.value
								previous.end = firstToken.value.end

								if ?#rest {
									elements.push(...rest)

									previous = rest[rest.length - 1].value
								}
							}
							else {
								elements.push(firstToken)

								if ?#rest {
									elements.push(...rest)

									previous = rest[rest.length - 1].value
								}
								else {
									previous = firstToken.value
								}
							}
						}
					}
				}
				else {
					elements.push(...lines[0].slice(1)!?)

					if lines.length > 1 {
						var mut previous = elements[elements.length - 1].value

						for var [indent, firstToken? = null, ...rest], index in lines from 1 {
							if previous.kind == AstKind.Literal {
								previous.value += '\n'
								previous.end.column += 1
							}
							else {
								previous = AST.Literal(null, '\n', {
									line: previous.end.line:!!!(Number)
									column: previous.end.column:!!!(Number) + 1
								}, {
									line: previous.end.line:!!!(Number)
									column: previous.end.column:!!!(Number) + 2
								})

								elements.push(@yep(previous))
							}

							if ?firstToken {
								if firstToken.value.kind == AstKind.Literal {
									previous.value += firstToken.value.value
									previous.end = firstToken.value.end
								}
								else {
									elements.push(firstToken)
								}

								if ?#rest {
									elements.push(...rest)

									previous = rest[rest.length - 1].value
								}
								else {
									previous = firstToken.value
								}
							}
						}
					}
				}
			}

			var modifiers = [@yep(AST.Modifier(ModifierKind.MultiLine, first, last))]

			return @yep(AST.TemplateExpression(modifiers, elements, first, last:!!!(Range)))
		} # }}}

		reqNameIB(): Event<Ast(Identifier, ArrayBinding, ObjectBinding)>(Y) ~ SyntaxError # {{{
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
			mut name: Event<Ast(Identifier)>
			fMode: FunctionMode
		): Event<Ast(NamespaceDeclaration)>(Y) ~ SyntaxError # {{{
		{
			name ?]]= @reqIdentifier()

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
					statement = @reqExportStatement(@yes(), fMode)
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
					statement = @reqStatement(.Default, .Nil, fMode)
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

		reqNumber(): Event<Ast(NumericExpression)>(Y) ~ SyntaxError # {{{
		{
			var value = @tryNumber()

			if value.ok {
				return value
			}
			else {
				@throw('Number')
			}
		} # }}}

		reqNumeralIdentifier(): Event<Ast(Identifier)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(Parameter)>(Y) ~ SyntaxError # {{{
		{
			var mut firstAttr = null
			var attributes = @stackInlineAttributes([])
			if ?#attributes {
				firstAttr = attributes[0]
			}

			var mutMark = @mark()
			var mut mutModifier = null

			if @test(.MUT) {
				mutModifier = AST.Modifier(ModifierKind.Mutable, @yes())
			}

			var mut positionalModifier = null
			var mut namedModifier = null

			if @test(.HASH) {
				positionalModifier = AST.Modifier(ModifierKind.PositionOnly, @yes())
			}
			else if @test(.ASTERISK) {
				namedModifier = AST.Modifier(ModifierKind.NameOnly, @yes())
			}

			var mut external = null

			if ?namedModifier {
				var identifier = @tryIdentifier()

				if identifier.ok {
					if @test(.PERCENT) {
						@commit()

						external = identifier
					}
					else {
						var modifiers = []
						modifiers.push(mutModifier) if ?mutModifier
						modifiers.push(if ?positionalModifier set positionalModifier else namedModifier)

						return @reqParameterIdentifier(attributes, modifiers, null, identifier, true, true, true, true, firstAttr ?? mutModifier ?? positionalModifier ?? namedModifier, pMode, fMode)
					}
				}
			}

			if @test(.LEFT_CURLY, .LEFT_SQUARE) {
				@throw() if ?positionalModifier || (?namedModifier && !?external)

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier
				modifiers.push(namedModifier) if ?namedModifier

				var late internal
				if @token == .LEFT_CURLY {
					internal = @reqDestructuringObject(@yes(), pMode, fMode)
				}
				else {
					internal = @reqDestructuringArray(@yes(), pMode, fMode)
				}

				if @test(.AMPERSAND) {
					@commit()

					internal.value.alias = @reqIdentifier().value
				}

				return @reqParameterIdentifier(attributes, modifiers, external, internal, false, true, false, true, firstAttr ?? mutModifier ?? namedModifier ?? external ?? internal, pMode, fMode)
			}

			if @test(.DOT_DOT_DOT) {
				@throw() if ?positionalModifier || ?namedModifier

				var first = @yes()

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier

				return @reqParameterRest(attributes, modifiers, external, (firstAttr ?? mutModifier ?? first):!!!(Range), pMode, fMode)
			}

			if @test(.AMPERAT) {
				@throw() if ?mutModifier

				var modifiers = []
				modifiers.push(namedModifier) if ?namedModifier
				modifiers.push(positionalModifier) if ?positionalModifier

				return @reqParameterAt(attributes, modifiers, external, firstAttr ?? namedModifier ?? positionalModifier, pMode, fMode)
			}

			if @test(.UNDERSCORE) {
				@throw() if ?positionalModifier || (?namedModifier && !?external)

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier
				modifiers.push(namedModifier) if ?namedModifier

				var underscore = @yes()

				return @reqParameterIdentifier(attributes, modifiers, external, null, false, true, true, true, firstAttr ?? mutModifier ?? namedModifier ?? underscore, pMode, fMode)
			}

			if ?positionalModifier || ?namedModifier {
				var modifiers = []
					..push(mutModifier) if ?mutModifier
					..push(if ?positionalModifier set positionalModifier else namedModifier!?)

				return @reqParameterIdentifier(attributes, modifiers, external, null, true, true, true, true, firstAttr ?? mutModifier ?? namedModifier ?? positionalModifier, pMode, fMode)
			}

			do {
				var identifier = @tryIdentifier()

				if identifier.ok {
					var modifiers = []
					modifiers.push(mutModifier) if ?mutModifier

					if pMode !~ DestructuringMode.EXTERNAL_ONLY && @test(.PERCENT) {
						@commit()

						if @test(.UNDERSCORE) {
							@commit()

							return @reqParameterIdentifier(attributes, modifiers, identifier, null, false, true, true, true, firstAttr ?? mutModifier ?? identifier, pMode, fMode)
						}
						else if @test(.LEFT_CURLY, .LEFT_SQUARE) {
							var late internal
							if @token == .LEFT_CURLY {
								internal = @reqDestructuringObject(@yes(), pMode, fMode)
							}
							else {
								internal = @reqDestructuringArray(@yes(), pMode, fMode)
							}

							return @reqParameterIdentifier(attributes, modifiers, identifier, internal, true, true, true, true, firstAttr ?? mutModifier ?? identifier, pMode, fMode)
						}
						else if @test(.DOT_DOT_DOT) {
							@commit()

							return @reqParameterRest(attributes, modifiers, identifier, (firstAttr ?? mutModifier ?? identifier):!!!(Range), pMode, fMode)
						}
						else if @test(.AMPERAT) {
							@throw() if ?mutModifier

							return @reqParameterAt(attributes, modifiers, identifier, firstAttr ?? namedModifier ?? identifier, pMode, fMode)
						}
						else {
							return @reqParameterIdentifier(attributes, modifiers, identifier, null, true, true, true, true, firstAttr ?? mutModifier ?? identifier, pMode, fMode)
						}
					}
					else {
						return @reqParameterIdentifier(attributes, modifiers, identifier, identifier, true, true, true, true, firstAttr ?? mutModifier ?? identifier, pMode, fMode)
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			external: Event<Ast(Identifier)>(Y)?
			first: Range?
			pMode: DestructuringMode
			fMode: FunctionMode
		): Event<Ast(Parameter)>(Y) ~ SyntaxError # {{{
		{
			if fMode ~~ FunctionMode.Method && pMode ~~ DestructuringMode.THIS_ALIAS {
				var at = @yes()

				return @reqParameterThis(attributes, modifiers, external, first ?? at, fMode)
			}
			else {
				@throw()
			}
		} # }}}

		reqParameterIdentifier(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			mut external: Event<Ast(Identifier)>(Y)?
			mut internal: Event<Ast(Identifier, ArrayBinding, ObjectBinding)>(Y)?
			required: Boolean
			typed: Boolean
			nullable: Boolean
			valued: Boolean
			mut first: Range?
			pMode: DestructuringMode
			fMode: FunctionMode
		): Event<Ast(Parameter)>(Y) ~ SyntaxError # {{{
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

			if internal?.value is .Identifier && @test(.AMPERSAND) {
				@commit()

				var alias = internal

				if @test(.LEFT_CURLY) {
					internal = @reqDestructuringObject(@yes(), pMode, fMode)
				}
				else if @test(.LEFT_SQUARE) {
					internal = @reqDestructuringArray(@yes(), pMode, fMode)
				}
				else {
					@throw('{', '[')
				}

				internal.value.alias = alias.value
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

				var type = @reqTypeParameter(if fMode ~~ .Method set .Method else .PrimaryType)
				var operator = if valued set @tryDefaultAssignmentOperator(true) else NO

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
				var mut operator = if valued set @tryDefaultAssignmentOperator(true) else NO

				if operator.ok {
					var defaultValue = @reqExpression(.ImplicitMember, fMode)

					return @yep(AST.Parameter(attributes, modifiers, external, internal, null, operator, defaultValue, first!?, defaultValue))
				}
				else if nullable && @test(Token.QUESTION) {
					var modifier = AST.Modifier(ModifierKind.Nullable, @yes())

					modifiers.push(modifier)

					operator = if valued set @tryDefaultAssignmentOperator(true) else NO

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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			mut external: Event<Ast(Identifier)>?
			first: Range
			pMode: DestructuringMode
			fMode: FunctionMode
		): Event<Ast(Parameter)>(Y) ~ SyntaxError # {{{
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

			if @test(Token.AMPERAT) {
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

					return @reqParameterIdentifier(attributes, modifiers, external, identifier, false, true, true, true, first, pMode, fMode)
				}

				if ?external && !external.ok {
					external = null
				}

				return @reqParameterIdentifier(attributes, modifiers, external!!, null, false, true, true, true, first, pMode, fMode)
			}
		} # }}}

		reqParameterThis(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			external: Event<Ast(Identifier)>(Y)?
			first: Range
			fMode: FunctionMode
		): Event<Ast(Parameter)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqThisExpression(first)

			if @test(Token.EXCLAMATION_QUESTION) {
				modifiers.push(AST.Modifier(ModifierKind.NonNullable, @yes()))
			}

			var operator = @tryDefaultAssignmentOperator(true)

			if operator.ok {
				var defaultValue = @reqExpression(.ImplicitMember, fMode)

				return @yep(AST.Parameter(attributes, modifiers, external ?? @yep(name.value.name), name, null, operator, defaultValue, first, defaultValue))
			}
			else {
				return @yep(AST.Parameter(attributes, modifiers, external ?? @yep(name.value.name), name, null, null, null, first, name))
			}
		} # }}}

		reqParenthesis(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
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

				return expression!!
			}
			else {
				return @yep(AST.SequenceExpression(expressions, first, @yes()))
			}
		} # }}}

		reqPassStatement(
			first: Event(Y)
		): Event<Ast(PassStatement)>(Y) ~ SyntaxError # {{{
		{
			return @yep(AST.PassStatement(first))
		} # }}}

		reqPostfixedOperand(
			operand: Event<Ast(Expression)>(Y)?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
		{
			var operand = @tryPrefixedOperand(eMode, fMode)

			if operand.ok {
				return operand
			}
			else {
				@throw()
			}
		} # }}}

		reqQuoteElements(
			elements: Event<QuoteElementData>(Y)[]
			terminator: MacroTerminator
		): Void ~ SyntaxError # {{{
		{
			var history = []

			var dyn literal = null
			var dyn first, last

			var addLiteral = () => {
				if literal != null {
					elements.push(@yep(AST.QuoteElementLiteral(literal, first!?, last!?)))

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
				match @matchM(M.QUOTE) {
					.EOF {
						if history.length == 0 && terminator !~ MacroTerminator.NEWLINE {
							@throw()
						}

						break
					}
					.BACKSLASH_HASH |.BACKSLASH_LEFT_CURLY | .BACKSLASH_RIGHT_CURLY | .BACKSLASH_SPACE {
						addLiteral()

						elements.push(@yep(AST.QuoteElementEscape(@scanner.char(1), @yep(), @yes())))
					}
					.HASH_LEFT_ROUND {
						addLiteral()

						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, [], position, @yes())))
					}
					.HASH_A_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Argument, @position(1, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_AC_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Argument, @position(1, 1)), AST.Reification(.Code, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_AI_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Argument, @position(1, 1)), AST.Reification(.Identifier, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_AV_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Argument, @position(1, 1)), AST.Reification(.Value, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_B_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Block, @position(1, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_BC_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Block, @position(1, 1)), AST.Reification(.Code, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_BI_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Block, @position(1, 1)), AST.Reification(.Identifier, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_BV_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Block, @position(1, 1)), AST.Reification(.Value, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_C_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Code, @position(1, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_FOR {
						addLiteral()

						var position = @yes()
						var statement = @reqForStatement(position, .Syntime)

						elements.push(@yep(AST.QuoteElementStatement(statement, position, @yes())))
					}
					.HASH_I_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Identifier, @position(1, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.HASH_IF {
						addLiteral()

						var position = @yes()
						var statement = @reqIfStatement(position, .Syntime)

						elements.push(@yep(AST.QuoteElementStatement(statement, position, @yes())))
					}
					.HASH_J_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Join, @position(1, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(',') unless @test(Token.COMMA)

						@commit()

						var separator = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						var ast = AST.QuoteElementExpression(expression, reifications, position, @yes())

						ast.separator = separator.value

						elements.push(@yep(ast))
					}
					.HASH_JCC_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Join, @position(1, 1)), AST.Reification(.Code, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(',') unless @test(Token.COMMA)

						@commit()

						var separator = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						var ast = AST.QuoteElementExpression(expression, reifications, position, @yes())

						ast.separator = separator.value

						elements.push(@yep(ast))
					}
					.HASH_JIC_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Join, @position(1, 1)), AST.Reification(.Identifier, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(',') unless @test(Token.COMMA)

						@commit()

						var separator = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						var ast = AST.QuoteElementExpression(expression, reifications, position, @yes())

						ast.separator = separator.value

						elements.push(@yep(ast))
					}
					.HASH_JVC_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Join, @position(1, 1)), AST.Reification(.Value, @position(2, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(',') unless @test(Token.COMMA)

						@commit()

						var separator = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						var ast = AST.QuoteElementExpression(expression, reifications, position, @yes())

						ast.separator = separator.value

						elements.push(@yep(ast))
					}
					.HASH_V_LEFT_ROUND {
						addLiteral()

						var reifications = [AST.Reification(.Value, @position(1, 1))]
						var position = @yes()
						var expression = @reqExpression(.Nil, .Nil)

						@throw(')') unless @test(Token.RIGHT_ROUND)

						elements.push(@yep(AST.QuoteElementExpression(expression, reifications, position, @yes())))
					}
					.INVALID {
						addToLiteral()
					}
					.LEFT_CURLY {
						addToLiteral()

						history.unshift(Token.RIGHT_CURLY)
					}
					.LEFT_ROUND {
						addToLiteral()

						history.unshift(Token.RIGHT_ROUND)
					}
					.NEWLINE {
						if history.length == 0 && terminator ~~ MacroTerminator.NEWLINE {
							break
						}
						else {
							addLiteral()

							elements.push(@yep(AST.QuoteElementNewLine(@yes())))

							@scanner.skip()
						}
					}
					.RIGHT_CURLY {
						if ?#history && history[0] == Token.RIGHT_CURLY {
							addToLiteral()

							history.shift()
						}
						else if terminator ~~ MacroTerminator.RIGHT_CURLY {
							break
						}
						else {
							@throw()
						}
					}
					.RIGHT_ROUND {
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
					else {
						@throw()
					}
				}
			}

			unless !?#history {
				@throw()
			}

			if literal != null {
				elements.push(@yep(AST.QuoteElementLiteral(literal, first!?, last!?)))
			}
		} # }}}

		reqQuoteExpression(
			mut first: Event
			terminator: MacroTerminator = MacroTerminator.NEWLINE
		): Event<Ast(QuoteExpression)>(Y) ~ SyntaxError # {{{
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

				@reqQuoteElements(elements, MacroTerminator.RIGHT_CURLY)

				unless @test(Token.RIGHT_CURLY) {
					@throw('}')
				}

				return @yep(AST.QuoteExpression(elements, first, @yes()))
			}
			else {
				if !first.ok {
					first = @yep()
				}

				@reqQuoteElements(elements, terminator)

				return @yep(AST.QuoteExpression(elements, first, elements[elements.length - 1]))
			}
		} # }}}

		reqRepeatStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(RepeatStatement)>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			if @test(Token.LEFT_CURLY) {
				var block = @reqBlock(NO, null, fMode)

				return @yep(AST.RepeatStatement(NO, block, first, block))
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
		): Event<Ast(RequireDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.RequireDeclaration(attributes, declarations, first, last))
		} # }}}

		reqRequireOrExternStatement(
			first: Event(Y)
		): Event<Ast(RequireOrExternDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.RequireOrExternDeclaration(attributes, declarations, first, last))
		} # }}}

		reqRequireOrImportStatement(
			first: Event(Y)
		): Event<Ast(RequireOrImportDeclaration)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(IfStatement, ReturnStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
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
			object: Event<Ast(Expression)>(Y)
			modifiers: ModifierData[]
			eMode: ExpressionMode
			fMode: FunctionMode
			restrictive: Boolean
		): Event<Ast(RollingExpression)>(Y) ~ SyntaxError # {{{
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

					var values: Ast(Expression)[] = [
						operand.value
						AST.BinaryExpression(operator)
						@reqBinaryOperand(mode, fMode).value
					]

					repeat {
						mark = @mark()

						@NL_0M()

						var binOperator = @tryBinaryOperator(fMode)

						if binOperator.ok {
							values.push(AST.BinaryExpression(binOperator))

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
		): Event<Ast(IfStatement, SetStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(.NoRestriction, fMode)

			if @match(Token.IF, Token.UNLESS) == Token.IF {
				@commit()

				var condition = @reqExpression(.NoRestriction, fMode)
				var whenTrue = @yep(AST.SetStatement(expression, first, expression))

				return @yep(AST.IfStatement(condition, whenTrue, NO, first, condition))
			}
			else if @token == Token.UNLESS {
				@commit()

				var condition = @reqExpression(.NoRestriction, fMode)
				var whenTrue = @yep(AST.SetStatement(expression, first, expression))

				return @yep(AST.UnlessStatement(condition, whenTrue, first, condition))
			}
			else {
				return @yep(AST.SetStatement(expression, first, expression))
			}
		} # }}}

		reqStatement(
			sMode: StatementMode
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Statement)>(Y) ~ SyntaxError # {{{
		{
			var mark = @mark()

			var mut statement: Event = NO

			match @matchM(M.STATEMENT, eMode, fMode) {
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

						statement = @reqFunctionStatement(modifiers, first)
					}
					else {
						statement = NO
					}
				}
				.AT_SEMTIME {
					statement = @trySemtimeStatement(@yes(), fMode)
				}
				.AT_SYNTIME {
					statement = @reqSyntimeStatement(@yes())
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
					statement = @reqFunctionStatement(null, @yes())
				}
				Token.IF {
					statement = @reqIfStatement(@yes(), fMode)
				}
				Token.IMPL {
					statement = @reqImplementStatement(@yes(), .Method + .Variable)
				}
				Token.IMPORT {
					statement = @reqImportStatement(@yes())
				}
				.MACRO {
					statement = @reqMacroStatement(@yes())
				}
				Token.MATCH {
					statement = @tryMatchStatement(@yes(), fMode)
				}
				Token.NAMESPACE {
					statement = @tryNamespaceStatement(@yes(), fMode)
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
					statement = @tryReturnStatement(@yes(), .ImplicitMember, fMode)
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
				.SYNTIME {
					var first = @yes()

					if @test(.IMPL) {
						var declaration = @reqImplementStatement(@yes(), .Syntime)

						statement = @yep(AST.SyntimeDeclaration([], [declaration], first, declaration))
					}
					else if @test(Token.LEFT_CURLY) {
						@commit()

						statement = @reqSyntimeDeclaration(first)
					}
					else if @test(.MACRO) {
						var declaration = @reqMacroStatement(@yes())

						statement = @yep(AST.SyntimeDeclaration([], [declaration], first, declaration))
					}
					else if @test(.NAMESPACE) {
						var declaration = @reqNamespaceStatement(@yes(), NO, .Syntime)

						statement = @yep(AST.SyntimeDeclaration([], [declaration], first, declaration))
					}
					else {
						statement = NO
					}
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

			if !statement.ok {
				if sMode ~~ .Expression {
					@rollback(mark)

					statement = @tryAssignementStatement(eMode, fMode)

					if !statement.ok {
						@rollback(mark)

						statement = @reqExpressionStatement(eMode, fMode)
					}
				}
				else {
					@throw('statement')
				}
			}

			@reqNL_EOF_1M() if sMode ~~ .NewLine

			return statement
		} # }}}

		reqString(): Event<Ast(Literal)>(Y) ~ SyntaxError # {{{
		{
			if @test(Token.STRING) {
				return @yep(AST.Literal(null, @value()!!!, @yes()))
			}
			else {
				@throw('String')
			}
		} # }}}

		reqStructStatement(
			first: Event(Y)
		): Event<Ast(StructDeclaration)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryStructStatement(first)

			if statement.ok {
				return statement
			}
			else {
				@throw()
			}
		} # }}}

		reqSyntimeArgumentList(
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Argument, Expression, Statement)[]>(Y) ~ SyntaxError # {{{
		{
			@NL_0M()

			if @test(Token.RIGHT_ROUND) {
				return @yep([])
			}
			else {
				var arguments: Ast(Argument, Expression, Statement)[] = []
				var mut argument: Event<Ast(Argument, Expression, Statement)> = NO

				var mut subEMode: ExpressionMode = .ImplicitMember + .BinaryOperator

				if eMode ~~ ExpressionMode.Pipeline {
					subEMode += ExpressionMode.Pipeline
				}

				while @until(Token.RIGHT_ROUND) {
					if @test(Token.BACKSLASH) {
						var first = @yes()
						var identifier = @reqIdentifier()

						argument = @yep(AST.PositionalArgument([], identifier, identifier, identifier))
					}
					else if @test(Token.COLON) {
						var first = @yes()
						var identifier = @reqIdentifier()
						var expression = @yep(AST.NamedArgument([], identifier, identifier, first, identifier))

						argument = @altRestrictiveExpression(expression, fMode)
					}

					if argument.ok {
						arguments.push(argument.value)
					}
					else if var statement ?]= @tryStatement(.Nil, subEMode, fMode) {
						arguments.push(statement.value)
					}
					else if var expression ?]= @tryExpression(subEMode, fMode, MacroTerminator.List) {
						if expression.value is .Identifier && @test(Token.COLON) {
							@commit()

							var value = @reqExpression(subEMode, fMode, MacroTerminator.List)
							var namedArg = @yep(AST.NamedArgument([], expression, value, expression, value))

							arguments.push(@altRestrictiveExpression(namedArg, fMode).value)
						}
						else {
							arguments.push(expression.value)
						}
					}
					else {
						@throw()
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

		reqSyntimeDeclaration(
			first: Event(Y)
		): Event<Ast(SyntimeDeclaration)>(Y) ~ SyntaxError { # {{{
			@reqNL_1M()

			var declarations = []

			while @until(.RIGHT_CURLY) {
				var declaration =
					if @test(.IMPL) {
						set @reqImplementStatement(@yes(), .Syntime)
					}
					else if @test(.MACRO) {
						set @reqMacroStatement(@yes())
					}
					else if @test(.NAMESPACE) {
						set @reqNamespaceStatement(@yes(), NO, .Syntime)
					}
					else {
						@throw('impl', 'macro', 'namespace')
					}

				declarations.push(declaration)

				@reqNL_1M()
			}

			@throw('}') unless @test(.RIGHT_CURLY)

			return @yep(AST.SyntimeDeclaration([], declarations, first, @yes()))
		} # }}}

		reqSyntimeStatement(
			first: Event(Y)
		): Event<Ast(SyntimeStatement)>(Y) ~ SyntaxError { # {{{
			var body = @reqBlock(NO, .Nil, .Syntime)

			return @yep(AST.SyntimeStatement([], body, first, body))
		} # }}}

		reqTemplateExpression(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(TemplateExpression)>(Y) ~ SyntaxError # {{{
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

			return @yep(AST.TemplateExpression([], elements, first, @yes()))
		} # }}}

		reqThisExpression(
			first: Range
		): Event<Ast(ThisExpression)>(Y) ~ SyntaxError # {{{
		{
			var identifier = @reqIdentifier()

			return @yep(AST.ThisExpression(identifier, first, identifier))
		} # }}}

		reqThrowStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(IfStatement, ThrowStatement, UnlessStatement)>(Y) ~ SyntaxError # {{{
		{
			var expression = @reqExpression(.NoRestriction, fMode)

			if @match(Token.IF, Token.UNLESS) == Token.IF {
				@commit()

				var condition = @reqExpression(.NoRestriction, fMode)
				var whenTrue = @yep(AST.ThrowStatement(expression, first, expression))

				return @yep(AST.IfStatement(condition, whenTrue, NO, first, condition))
			}
			else if @token == Token.UNLESS {
				@commit()

				var condition = @reqExpression(.NoRestriction, fMode)
				var whenTrue = @yep(AST.ThrowStatement(expression, first, expression))

				return @yep(AST.UnlessStatement(condition, whenTrue, first, condition))
			}
			else {
				return @yep(AST.ThrowStatement(expression, first, expression))
			}
		} # }}}

		reqTryCatchClause(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(CatchClause)>(Y) ~ SyntaxError # {{{
		{
			var binding =
				if @test(Token.IDENTIFIER) {
					set @reqIdentifier()
				}
				else {
					set NO
				}

			@NL_0M()

			var body = @reqBlock(NO, null, fMode)

			return @yep(AST.CatchClause(binding, NO, body, first, body))
		} # }}}

		reqTryExpression(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(TryExpression)>(Y) ~ SyntaxError # {{{
		{
			var modifiers = []
			if @testNS(Token.EXCLAMATION) {
				modifiers.push(AST.Modifier(ModifierKind.Disabled, @yes()))
			}

			var operand = @reqPrefixedOperand(.Nil, fMode)

			var default =
				if @test(Token.TILDE) {
					@commit()

					set @reqPrefixedOperand(.Nil, fMode)
				}
				else {
					set NO
				}

			return @yep(AST.TryExpression(modifiers, operand, default, first, default ?]] operand))
		} # }}}

		reqTupleStatement(
			first: Event(Y)
		): Event<Ast(TupleDeclaration)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(Type)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(Type)>(Y) ~ SyntaxError # {{{
		{
			var properties: Event<Ast(PropertyType)>(Y)[] = []
			var mut rest: Event = NO

			@NL_0M()

			while @until(Token.RIGHT_SQUARE) {
				if @test(Token.COMMA) {
					var propToken = @yep()
					var property = @yep(AST.PropertyType([], NO, NO, propToken, propToken))

					properties.push(property)

					@commit().NL_0M()
				}
				else {
					@NL_0M()

					if @test(Token.DOT_DOT_DOT) {
						if ?]rest {
							@throw('Identifier')
						}

						var propToken = @yes()
						var modifier = @yep(AST.RestModifier(0, Infinity, propToken, propToken))
						var type = @tryType([], multiline, eMode)

						if type.ok {
							rest = @yep(AST.PropertyType([modifier], NO, type, propToken, type))
						}
						else {
							rest = @yep(AST.PropertyType([modifier], NO, NO, propToken, propToken))
						}
					}
					else {
						var type = @reqType([], multiline)

						var property = @yep(AST.PropertyType([], NO, type, type, type))

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
		): Event<Ast(Type)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(DescriptiveType)>(Y) ~ SyntaxError # {{{
		{
			var type = @tryTypeDescriptive(tMode)

			if type.ok {
				return type
			}
			else {
				@throw(...type.expecteds ?## 'type')
			}
		} # }}}

		reqTypeLimited(
			modifiers: Event<ModifierData>(Y)[] = []
			nullable: Boolean = true
			eMode: ExpressionMode = .Nil
		): Event<Ast(Type)>(Y) ~ SyntaxError # {{{
		{
			var type = @tryTypeLimited(modifiers, eMode)

			if type.ok {
				return @altTypeContainer(type, nullable)
			}
			else {
				@throw()
			}
		} # }}}

		reqTypeEntity(): Event<Ast(TypeReference)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifierOrMember()

			return @yep(AST.TypeReference(name))
		} # }}}

		reqTypeGeneric(
			first: Event(Y)
		): Event<Event<Ast(TypeReference)>[]>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(TypeList)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(TypeReference)>(Y) ~ SyntaxError # {{{
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
			first % top: Event(Y)
			eMode: ExpressionMode
		): Event<Ast(Type)>(Y) ~ SyntaxError # {{{
		{
			var properties = []
			var mut rest = null

			@NL_0M()

			until @test(Token.RIGHT_CURLY) {
				var mark = @mark()
				var mut nf = true

				if @test(Token.ASYNC) {
					var first = @yes()

					if @test(Token.FUNC) {
						@commit()
					}

					var identifier = @tryIdentifier()

					if identifier.ok && @test(Token.LEFT_ROUND) {
						var fnModifiers = [@yep(AST.Modifier(ModifierKind.Async, first))]
						var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
						var type = @tryFunctionReturns(eMode, false)
						var throws = @tryFunctionThrows()

						var objectType = @yep(AST.FunctionExpression(parameters, fnModifiers, type, throws, null, parameters, throws ?]] type ?]] parameters))

						var property = @yep(AST.PropertyType([], identifier, objectType, first, objectType))

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

						var objectType = @yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?]] type ?]] parameters))

						var property = @yep(AST.PropertyType([], identifier, objectType, first, objectType))

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

					if var type ?]= @tryType(eMode) {
						rest = @yep(AST.PropertyType([modifier], NO, type, first, type))
					}
					else {
						rest = @yep(AST.PropertyType([modifier], NO, NO, first, first))
					}

					nf = false
				}

				if nf ;; var identifier ?]= @tryIdentifier() {
					var propModifiers = []
					var mut type: Event = NO

					if @test(.LEFT_ROUND) {
						var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
						var return = @tryFunctionReturns(eMode)
						var throws = @tryFunctionThrows()

						type = @yep(AST.FunctionExpression(parameters, null, return, throws, null, parameters, throws ?]] return ?]] parameters))
					}
					else if @test(.COLON) {
						@commit()

						type = @reqType()
					}
					else if @test(.QUESTION) {
						propModifiers.push(@yep(AST.Modifier(.Nullable, @yes())))
					}

					var property = @yep(AST.PropertyType(propModifiers, identifier, type, identifier, type ?]] identifier))

					properties.push(property)

					nf = false
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

			var type = @yep(AST.ObjectType(modifiers, properties, rest, top, @yes()))

			return @altTypeContainer(type)
		} # }}}

		reqTypeParameter(
			eMode: ExpressionMode
		): Event<Ast(Type)>(Y) ~ SyntaxError # {{{
		{
			var type = @reqType(eMode)

			if @match(Token.PIPE_PIPE, Token.AMPERSAND_AMPERSAND) == Token.PIPE_PIPE {
				var types = [type]

				do {
					@commit()

					types.push(@reqType(eMode))
				}
				while @test(Token.PIPE_PIPE)

				return @yep(AST.UnionType(types, type, types[types.length - 1]))
			}
			else if @token == Token.AMPERSAND_AMPERSAND {
				var types = [type]

				do {
					@commit()

					types.push(@reqType(eMode))
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
		): Event<Ast(Type)>(Y) ~ SyntaxError # {{{
		{
			match @match(.NEW, .VALUEOF) {
				.NEW {
					var operator = @yep(AST.UnaryTypeOperator(.NewInstance, @yes()))
					var operand = @reqType(eMode)

					return @yep(AST.UnaryTypeExpression([], operator, operand, operator, operand))
				}
				.VALUEOF {
					var operator = @yep(AST.UnaryTypeOperator(.ValueOf, @yes()))
					var operand = @reqUnaryOperand(null, eMode, if eMode ~~ .AtThis set .Method else .Nil)

					return @yep(AST.UnaryTypeExpression([], operator, operand, operator, operand))
				}
				else {
					return @reqType(eMode)
				}
			}
		} # }}}

		reqTypeStatement(
			first: Event(Y)
			name: Event<Ast(Identifier)>(Y)
		): Event<Ast(TypeAliasDeclaration)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(VariableDeclarator)>(Y) ~ SyntaxError # {{{
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

					var type = @reqType(if fMode ~~ .Method set .Method else .PrimaryType)

					return @yep(AST.VariableDeclarator([], name, type, name, type))
				}
				else if questionable && @test(.QUESTION) {
					var modifier = @yep(AST.Modifier(.Nullable, @yes()))

					return @yep(AST.VariableDeclarator([modifier], name, NO, name, modifier))
				}
			}

			return @yep(AST.VariableDeclarator([], name, NO, name, name))
		} # }}}

		reqUnaryOperand(
			value: Event<Ast(Expression)>(Y)?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(UnlessStatement)>(Y) ~ SyntaxError # {{{
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
		): Event<Ast(VariableStatement)>(Y) ~ SyntaxError # {{{
		{
			var statement = @tryVarStatement(first, eMode, fMode)

			if statement.ok {
				return statement
			}
			else {
				@throw('Identifier', '{', '[')
			}
		} # }}}

		reqVariable(): Event<Ast(VariableDeclarator)>(Y) ~ SyntaxError # {{{
		{
			var name = @reqIdentifier()

			return @yep(AST.VariableDeclarator([], name, NO, name, name))
		} # }}}

		reqVariableIdentifier(
			fMode: FunctionMode
		): Event<Ast(Identifier, ArrayBinding, ObjectBinding)>(Y) ~ SyntaxError # {{{
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
			mut object: Event<Ast(Identifier, MemberExpression, ThisExpression)>
			fMode: FunctionMode
		): Event<Ast(Identifier, MemberExpression, ThisExpression)>(Y) ~ SyntaxError # {{{
		{
			if !object.ok {
				if fMode ~~ FunctionMode.Method && @test(Token.AMPERAT) {
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
			elements: Ast(VariantField)[]
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

					elements.push(AST.VariantField(names, NO, names[0], names[names.length - 1]))
				}
			}

			unless @test(.RIGHT_CURLY) {
				@throw('}')
			}
		} # }}}

		stackInlineAttributes(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
		): Event<Ast(AttributeDeclaration)>(Y)[] ~ SyntaxError # {{{
		{
			while @test(Token.HASH_LEFT_SQUARE) {
				attributes.push(@reqAttribute(@yes()))
			}

			return attributes
		} # }}}

		stackInnerAttributes(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]): Boolean ~ SyntaxError # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
		): Event<Ast(AttributeDeclaration)>(Y)[] ~ SyntaxError # {{{
		{
			while @test(Token.HASH_LEFT_SQUARE) {
				attributes.push(@reqAttribute(@yes()))

				@NL_0M()
			}

			return attributes
		} # }}}

		submitNamedGroupSpecifier(
			modifiers: Event<ModifierData>(Y)[]
			type: Event<Ast(DescriptiveType)>
			specifiers: Event<Ast(GroupSpecifier)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var elements = []

			repeat {
				var name = @reqNameIB()

				elements.push(@yep(AST.NamedSpecifier(name)))

				if @test(Token.COMMA) {
					@commit()
				}
				else {
					break
				}
			}

			var first = if ?#modifiers set modifiers[0] else elements[0]
			var last = elements[elements.length - 1]

			specifiers.push(@yep(AST.GroupSpecifier(modifiers, elements, type, first, last)))
		} # }}}

		submitNamedSpecifier(
			modifiers: Event<ModifierData>(Y)[]
			specifiers: Event<Ast(NamedSpecifier)>(Y)[]
		): Void ~ SyntaxError # {{{
		{
			var identifier = @reqIdentifier()

			if @test(Token.EQUALS_RIGHT_ANGLE) {
				@commit()

				var internal = @reqNameIB()

				specifiers.push(@yep(AST.NamedSpecifier(modifiers, internal, identifier, identifier, internal)))
			}
			else {
				specifiers.push(@yep(AST.NamedSpecifier(modifiers, identifier, NO, identifier, identifier)))
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
				.EXCLAMATION_QUESTION_PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NonFinite, @yes()))
				}
				.EXCLAMATION_QUESTION_RIGHT_SQUARE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.VariantNo, @yes()))
				}
				.LEFT_ANGLE_MINUS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Return, @yes()))
				}
				.MINUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Subtraction, @yes()))
				}
				.PERCENT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Remainder, @yes()))
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
				.QUESTION_PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.Finite, @yes()))
				}
				.QUESTION_PLUS_PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NonFiniteCoalescing, @yes()))
				}
				.QUESTION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.NullCoalescing, @yes()))
				}
				.QUESTION_RIGHT_SQUARE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.VariantYes, @yes()))
				}
				.QUESTION_RIGHT_SQUARE_RIGHT_SQUARE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind.VariantNoCoalescing, @yes()))
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
		): Event<Ast(ExpressionStatement)> ~ SyntaxError # {{{
		{
			var dyn identifier = NO

			var dMode: DestructuringMode = if fMode ~~ FunctionMode.Method {
				set DestructuringMode.Expression + DestructuringMode.THIS_ALIAS
			}
			else {
				set DestructuringMode.Expression
			}

			if @match(Token.IDENTIFIER, Token.LEFT_CURLY, Token.LEFT_SQUARE, Token.AMPERAT) == Token.IDENTIFIER {
				identifier = @tryUnaryOperand(@reqIdentifier(), eMode + .InlineOnly, fMode)
			}
			else if @token == Token.LEFT_CURLY {
				identifier = @tryDestructuringObject(@yes(), dMode, fMode)
			}
			else if @token == Token.LEFT_SQUARE {
				identifier = @tryDestructuringArray(@yes(), dMode, fMode)
			}
			else if fMode ~~ FunctionMode.Method && @token == Token.AMPERAT {
				identifier = @tryUnaryOperand(@reqThisExpression(@yes()), eMode, fMode)
			}

			unless identifier.ok {
				return NO
			}

			var expression =
				if @match(Token.COMMA, Token.EQUALS) == Token.COMMA {
					unless identifier.value.kind == AstKind.Identifier || identifier.value.kind == AstKind.ArrayBinding || identifier.value.kind == AstKind.ObjectBinding {
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

						set @yep(AST.AwaitExpression([], variables, operand, identifier, operand))
					}
					else {
						@throw('=')
					}
				}
				else if @token == Token.EQUALS {
					@validateAssignable(identifier.value)

					var equals = @yes()

					@NL_0M()

					var value = @reqExpression(eMode + .ImplicitMember + .NoRestriction, fMode)

					set @yep(AST.BinaryExpression(identifier, @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, equals)), value, identifier, value))
				}
				else {
					return NO
				}

			var statement = @altRestrictiveExpression(expression, fMode)

			return @yep(AST.ExpressionStatement(statement))
		} # }}}

		tryAwaitExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(AwaitExpression)> ~ SyntaxError # {{{
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
		): Event<Ast(Expression)> ~ SyntaxError # {{{
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
				.AMPERSAND_AMPERSAND {
					return @yep(AST.BinaryOperator(.LogicalAnd, @yes()))
				}
				.AMPERSAND_AMPERSAND_EQUALS {
					return @yep(AST.AssignmentOperator(.LogicalAnd, @yes()))
				}
				.ASTERISK {
					return @yep(AST.BinaryOperator(.Multiplication, @yes()))
				}
				.ASTERISK_ASTERISK {
					return @yep(AST.BinaryOperator(.Power, @yes()))
				}
				.ASTERISK_ASTERISK_EQUALS {
					return @yep(AST.AssignmentOperator(.Power, @yes()))
				}
				.ASTERISK_EQUALS {
					return @yep(AST.AssignmentOperator(.Multiplication, @yes()))
				}
				.ASTERISK_PIPE_RIGHT_ANGLE {
					var modifiers = [AST.Modifier(.Wildcard, @position(0, 1))]

					return @yep(AST.BinaryOperator(modifiers, .ForwardPipeline, @yes()))
				}
				.ASTERISK_PIPE_RIGHT_ANGLE_HASH {
					var modifiers = [AST.Modifier(.Wildcard, @position(0, 1)), AST.Modifier(.NonEmpty, @position(3, 1))]

					return @yep(AST.BinaryOperator(modifiers, .ForwardPipeline, @yes()))
				}
				.ASTERISK_PIPE_RIGHT_ANGLE_QUESTION {
					var modifiers = [AST.Modifier(.Wildcard, @position(0, 1)), AST.Modifier(.Existential, @position(3, 1))]

					return @yep(AST.BinaryOperator(modifiers, .ForwardPipeline, @yes()))
				}
				.CARET_CARET {
					return @yep(AST.BinaryOperator(.LogicalXor, @yes()))
				}
				.CARET_CARET_EQUALS {
					return @yep(AST.AssignmentOperator(.LogicalXor, @yes()))
				}
				.EQUALS {
					return @yep(AST.AssignmentOperator(.Equals, @yes()))
				}
				.EQUALS_EQUALS {
					return @yep(AST.BinaryOperator(.Equality, @yes()))
				}
				.EXCLAMATION_EQUALS {
					return @yep(AST.BinaryOperator(.Inequality, @yes()))
				}
				.EXCLAMATION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(.NonExistential, @yes()))
				}
				.EXCLAMATION_QUESTION_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(.Empty, @yes()))
				}
				.EXCLAMATION_QUESTION_PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(.NonFinite, @yes()))
				}
				.EXCLAMATION_QUESTION_RIGHT_SQUARE_EQUALS {
					return @yep(AST.AssignmentOperator(.VariantNo, @yes()))
				}
				.EXCLAMATION_TILDE {
					return @yep(AST.BinaryOperator(.Mismatch, @yes()))
				}
				.HASH_LEFT_ANGLE_PIPE {
					var modifiers = [AST.Modifier(.NonEmpty, @position(0, 1))]

					return @yep(AST.BinaryOperator(modifiers, .BackwardPipeline, @yes()))
				}
				.HASH_LEFT_ANGLE_PIPE_ASTERISK {
					var modifiers = [AST.Modifier(.NonEmpty, @position(0, 1)), AST.Modifier(.Wildcard, @position(3, 1))]

					return @yep(AST.BinaryOperator(modifiers, .BackwardPipeline, @yes()))
				}
				.LEFT_ANGLE {
					return @yep(AST.BinaryOperator(.LessThan, @yes()))
				}
				.LEFT_ANGLE_EQUALS {
					return @yep(AST.BinaryOperator(.LessThanOrEqual, @yes()))
				}
				.LEFT_ANGLE_MINUS {
					return @yep(AST.AssignmentOperator(.Return, @yes()))
				}
				.LEFT_ANGLE_PIPE {
					return @yep(AST.BinaryOperator(.BackwardPipeline, @yes()))
				}
				.LEFT_ANGLE_PIPE_ASTERISK {
					var modifiers = [AST.Modifier(.Wildcard, @position(2, 1))]

					return @yep(AST.BinaryOperator(modifiers, .BackwardPipeline, @yes()))
				}
				.MINUS {
					return @yep(AST.BinaryOperator(.Subtraction, @yes()))
				}
				.MINUS_EQUALS {
					return @yep(AST.AssignmentOperator(.Subtraction, @yes()))
				}
				.MINUS_RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(.LogicalImply, @yes()))
				}
				.PERCENT {
					return @yep(AST.BinaryOperator(.Remainder, @yes()))
				}
				.PERCENT_EQUALS {
					return @yep(AST.AssignmentOperator(.Remainder, @yes()))
				}
				.PERCENT_PERCENT {
					return @yep(AST.BinaryOperator(.Modulus, @yes()))
				}
				.PERCENT_PERCENT_EQUALS {
					return @yep(AST.AssignmentOperator(.Modulus, @yes()))
				}
				.PIPE_RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(.ForwardPipeline, @yes()))
				}
				.PIPE_RIGHT_ANGLE_HASH {
					var modifiers = [AST.Modifier(.NonEmpty, @position(2, 1))]

					return @yep(AST.BinaryOperator(modifiers, .ForwardPipeline, @yes()))
				}
				.PIPE_RIGHT_ANGLE_QUESTION {
					var modifiers = [AST.Modifier(.Existential, @position(2, 1))]

					return @yep(AST.BinaryOperator(modifiers, .ForwardPipeline, @yes()))
				}
				.PIPE_PIPE {
					return @yep(AST.BinaryOperator(.LogicalOr, @yes()))
				}
				.PIPE_PIPE_EQUALS {
					return @yep(AST.AssignmentOperator(.LogicalOr, @yes()))
				}
				.PLUS {
					return @yep(AST.BinaryOperator(.Addition, @yes()))
				}
				.PLUS_AMPERSAND {
					return @yep(AST.BinaryOperator(.BitwiseAnd, @yes()))
				}
				.PLUS_AMPERSAND_EQUALS {
					return @yep(AST.AssignmentOperator(.BitwiseAnd, @yes()))
				}
				.PLUS_CARET {
					return @yep(AST.BinaryOperator(.BitwiseXor, @yes()))
				}
				.PLUS_CARET_EQUALS {
					return @yep(AST.AssignmentOperator(.BitwiseXor, @yes()))
				}
				.PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(.Addition, @yes()))
				}
				.PLUS_LEFT_ANGLE {
					return @yep(AST.BinaryOperator(.BitwiseLeftShift, @yes()))
				}
				.PLUS_LEFT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(.BitwiseLeftShift, @yes()))
				}
				.PLUS_PIPE {
					return @yep(AST.BinaryOperator(.BitwiseOr, @yes()))
				}
				.PLUS_PIPE_EQUALS {
					return @yep(AST.AssignmentOperator(.BitwiseOr, @yes()))
				}
				.PLUS_RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(.BitwiseRightShift, @yes()))
				}
				.PLUS_RIGHT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(.BitwiseRightShift, @yes()))
				}
				.QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(.Existential, @yes()))
				}
				.QUESTION_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(.NonEmpty, @yes()))
				}
				.QUESTION_HASH_HASH {
					return @yep(AST.BinaryOperator(.EmptyCoalescing, @yes()))
				}
				.QUESTION_HASH_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(.EmptyCoalescing, @yes()))
				}
				.QUESTION_LEFT_ANGLE_PIPE {
					var modifiers = [AST.Modifier(.Existential, @position(0, 1))]

					return @yep(AST.BinaryOperator(modifiers, .BackwardPipeline, @yes()))
				}
				.QUESTION_LEFT_ANGLE_PIPE_ASTERISK {
					var modifiers = [AST.Modifier(.Existential, @position(0, 1)), AST.Modifier(.Wildcard, @position(3, 1))]

					return @yep(AST.BinaryOperator(modifiers, .BackwardPipeline, @yes()))
				}
				.QUESTION_PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(.Finite, @yes()))
				}
				.QUESTION_PLUS_PLUS {
					return @yep(AST.BinaryOperator(.NonFiniteCoalescing, @yes()))
				}
				.QUESTION_PLUS_PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(.NonFiniteCoalescing, @yes()))
				}
				.QUESTION_QUESTION {
					return @yep(AST.BinaryOperator(.NullCoalescing, @yes()))
				}
				.QUESTION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(.NullCoalescing, @yes()))
				}
				.QUESTION_RIGHT_SQUARE_EQUALS {
					return @yep(AST.AssignmentOperator(.VariantYes, @yes()))
				}
				.QUESTION_RIGHT_SQUARE_RIGHT_SQUARE {
					return @yep(AST.BinaryOperator(.VariantNoCoalescing, @yes()))
				}
				.QUESTION_RIGHT_SQUARE_RIGHT_SQUARE_EQUALS {
					return @yep(AST.AssignmentOperator(.VariantNoCoalescing, @yes()))
				}
				.RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(.GreaterThan, @yes()))
				}
				.RIGHT_ANGLE_EQUALS {
					return @yep(AST.BinaryOperator(.GreaterThanOrEqual, @yes()))
				}
				.SLASH {
					return @yep(AST.BinaryOperator(.Division, @yes()))
				}
				.SLASH_AMPERSAND {
					return @yep(AST.BinaryOperator(.EuclideanDivision, @yes()))
				}
				.SLASH_EQUALS {
					return @yep(AST.AssignmentOperator(.Division, @yes()))
				}
				.SLASH_HASH {
					return @yep(AST.BinaryOperator(.IntegerDivision, @yes()))
				}
				.SLASH_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(.IntegerDivision, @yes()))
				}
				.TILDE_TILDE {
					return @yep(AST.BinaryOperator(.Match, @yes()))
				}
			}

			return NO
		} # }}}

		tryBitmaskMember(
			mut attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			mut first: Range?
		): Event<Ast(BitmaskValue, MethodDeclaration)> ~ SyntaxError # {{{
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
		): Event<Ast(BitmaskDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()
			unless name.ok {
				return NO
			}

			var mut type: Event<Ast(Identifier)> = NO

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

			var attributes = []
			var members = []

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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<Ast(BitmaskValue)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			return NO unless name.ok

			var value =
				if @test(Token.EQUALS) {
					@commit()

					set @reqExpression(.ImplicitMember, .Method)
				}
				else {
					set NO
				}

			@reqNL_1M()

			return @yep(AST.BitmaskValue(attributes, modifiers, name, value, first ?? name, value ?]] name))
		} # }}}

		tryBlock(
			fMode: FunctionMode
		): Event<Ast(Block)> ~ SyntaxError # {{{
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
		): Event<Ast(BlockStatement)> ~ SyntaxError # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			staticModifier: Event<ModifierData>
			staticMark: Marker
			finalModifier: Event<ModifierData>
			finalMark: Marker
			first: Range?
		): Event<Ast(FieldDeclaration, MethodDeclaration, PropertyDeclaration, ProxyDeclaration)> ~ SyntaxError # {{{
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
			mut attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			mut first: Range?
		): Event<Ast(FieldDeclaration, MethodDeclaration, PropertyDeclaration, ProxyDeclaration)> ~ SyntaxError # {{{
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
				var methodMark = @mark()

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

					@rollback(methodMark)
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

					@rollback(methodMark)
				}
				else if bits ~~ MemberBits.AssistMethod && @test(.ASSIST) {
					var modifier = @yep(AST.Modifier(.Assist, @yes()))

					var method = @tryClassMethod(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if method.ok {
						return method
					}

					@rollback(methodMark)
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

					@rollback(methodMark)
				}
				else if bits ~~ MemberBits.OverwriteMethod && @test(Token.OVERWRITE) {
				}

				var method = @tryClassMethod(attributes, modifiers, bits, first)

				if method.ok {
					return method
				}

				@rollback(methodMark)
			}

			if bits ~~ MemberBits.Property {
				var propertyMark = @mark()

				if bits ~~ MemberBits.OverrideProperty && @test(Token.OVERRIDE) {
					var modifier = @yep(AST.Modifier(ModifierKind.Override, @yes()))
					var property = @tryClassProperty(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if property.ok {
						return property
					}

					@rollback(propertyMark)
				}

				var property = @tryClassProperty(attributes, modifiers, bits, first)

				if property.ok {
					return property
				}

				@rollback(propertyMark)
			}

			if bits ~~ MemberBits.Proxy && @test(Token.PROXY) {
				var proxyMark = @mark()
				var keyword = @yes()

				var proxy = @tryClassProxy(attributes, modifiers, first ?? keyword)

				if proxy.ok {
					return proxy
				}

				@rollback(proxyMark)
			}

			if bits ~~ MemberBits.Variable {
				var variableMark = @mark()

				if bits ~~ MemberBits.FinalVariable && @test(.FINAL) {
					var modifier = @yep(AST.Modifier(.Final, @yes()))
					var mark2 = @mark()

					if bits ~~ MemberBits.LateVariable && @test(.LATE) {
						var modifier2 = @yep(AST.Modifier(.LateInit, @yes()))
						var method = @tryClassVariable(
							attributes
							[...modifiers, modifier, modifier2]
							bits - MemberBits.RequiredAssignment
							NO
							NO
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
						NO
						NO
						first ?? modifier
					)

					if variable.ok {
						return variable
					}

					@rollback(variableMark)
				}
				else if bits ~~ MemberBits.LateVariable && @test(Token.LATE) {
					var modifier = @yep(AST.Modifier(ModifierKind.LateInit, @yes()))
					var method = @tryClassVariable(
						attributes
						[...modifiers, modifier]
						bits - MemberBits.RequiredAssignment
						NO
						NO
						first ?? modifier
					)

					if method.ok {
						return method
					}

					@rollback(variableMark)
				}

				var variable = @tryClassVariable(attributes, modifiers, bits, NO, NO, first)

				if variable.ok {
					return variable
				}
			}

			@rollback(mark)

			return NO
		} # }}}

		tryClassMethod(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<Ast(MethodDeclaration)> ~ SyntaxError # {{{
		{
			var dyn name
			if bits !~ .NoAsync && @test(Token.ASYNC) {
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<Ast(FieldDeclaration, PropertyDeclaration)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			if @test(Token.AMPERAT) {
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			mut first: Range?
		): Event<Ast(ProxyDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			unless @test(Token.EQUALS) {
				return NO
			}

			@commit()

			unless @test(Token.AMPERAT) {
				@throw('@')
			}

			var target = @reqExpression(.Nil, .Method)

			@reqNL_1M()

			return @yep(AST.ProxyDeclaration(attributes, modifiers, name, target, first ?? name, target))
		} # }}}

		tryClassStatement(
			modifiers: Event<ModifierData>(Y)[] = []
			first: Event(Y)
		): Event<Ast(ClassDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			return @reqClassStatementBody(modifiers, name, first)
		} # }}}

		tryClassVariable(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut name: Event<Ast(Identifier)>
			mut type: Event<Ast(Type)>
			mut first: Range?
		): Event<Ast(FieldDeclaration)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			if !?]name {
				if @test(Token.AMPERAT) {
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

			if !?]type {
				if @test(Token.COLON) {
					@commit()

					type = @reqType(Function.Method)
				}
				else if @test(Token.QUESTION) {
					modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind.Nullable, @yes()))]
				}
			}

			var value =
				if bits ~~ MemberBits.NoAssignment {
					set NO
				}
				else if @test(Token.EQUALS) {
					@commit()

					set @reqExpression(.ImplicitMember, .Method)
				}
				else if bits ~~ MemberBits.RequiredAssignment {
					@throw('=')
				}
				else {
					set NO
				}

			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, value, first ?? name, value ?]] type ?]] name))
		} # }}}

		tryCommaNL0M(): Boolean ~ SyntaxError # {{{
		{
			if @test(.COMMA) {
				@commit().NL_0M()

				return true
			}
			else if @test(.NEWLINE) {
				@commit().NL_0M()

				if @test(.COMMA) {
					@commit().NL_0M()
				}

				return true
			}
			else {
				return false
			}
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
		): Event<Ast(VariableStatement)> ~ SyntaxError # {{{
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
					return @yep(AST.AssignmentOperator(.Equals, @yes()))
				}
				else if @test(Token.QUESTION_QUESTION_EQUALS) {
					return @yep(AST.AssignmentOperator(.NullCoalescing, @yes()))
				}
				else if @test(Token.QUESTION_HASH_HASH_EQUALS) {
					return @yep(AST.AssignmentOperator(.EmptyCoalescing, @yes()))
				}
				else if @test(Token.QUESTION_PLUS_PLUS_EQUALS) {
					return @yep(AST.AssignmentOperator(.NonFiniteCoalescing, @yes()))
				}
				else if @test(Token.QUESTION_RIGHT_SQUARE_RIGHT_SQUARE_EQUALS) {
					return @yep(AST.AssignmentOperator(.VariantNoCoalescing, @yes()))
				}
			}
			else {
				if @test(Token.QUESTION_EQUALS) {
					return @yep(AST.AssignmentOperator(.Existential, @yes()))
				}
				else if @test(Token.QUESTION_HASH_EQUALS) {
					return @yep(AST.AssignmentOperator(.NonEmpty, @yes()))
				}
				else if @test(Token.QUESTION_PLUS_EQUALS) {
					return @yep(AST.AssignmentOperator(.Finite, @yes()))
				}
				else if @test(Token.QUESTION_RIGHT_SQUARE_EQUALS) {
					return @yep(AST.AssignmentOperator(.VariantYes, @yes()))
				}
			}

			return NO
		} # }}}

		tryDestructuring(
			mut dMode: DestructuringMode?
			fMode: FunctionMode
		): Event<Ast(ArrayBinding, ObjectBinding)> ~ SyntaxError # {{{
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
		): Event<Ast(ArrayBinding)> ~ SyntaxError # {{{
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
		): Event<Ast(ObjectBinding)> ~ SyntaxError # {{{
		{
			try {
				return @reqDestructuringObject(first, dMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}

		tryEnumMember(
			mut attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			mut bits: MemberBits
			mut first: Range?
		): Event<Ast(EnumValue, FieldDeclaration, MethodDeclaration)> ~ SyntaxError # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<Ast(MethodDeclaration)> ~ SyntaxError # {{{
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
		): Event<Ast(EnumDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()
			unless name.ok {
				return NO
			}

			var mut type: Event<Ast(TypeReference)> = NO
			var mut init: Event<Ast(Expression)> = NO
			var mut step: Event<Ast(Expression)> = NO

			if @test(Token.LEFT_ANGLE) {
				@commit()

				type = @reqTypeEntity()

				if @test(.SEMICOLON) {
					if @mode ~~ .Typing {
						@throw('>')
					}

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

			var nlMark = @mark()

			@NL_0M()

			if @test(Token.LEFT_CURLY) {
				@commit().NL_0M()
			}
			else if @mode ~~ .Typing {
				@rollback(nlMark)

				return @yep(AST.EnumDeclaration([], modifiers, name, type, NO, NO, [], first, name))
			}
			else {
				@throw('{')
			}

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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<Ast(EnumValue)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			return NO unless name.ok

			var mut arguments = null
			var mut value: Event<Ast(Expression)> = NO

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

			return @yep(AST.EnumValue(attributes, modifiers, name, value, arguments, first ?? name, value ?]] name))
		} # }}}

		tryEnumVariable(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			mut modifiers: Event<ModifierData>(Y)[]
			bits: MemberBits
			mut first: Range?
		): Event<Ast(FieldDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			return NO unless name.ok

			var type =
				if @test(Token.COLON) {
					@commit()

					set @reqType(Function.Method)
				}
				else {
					if @test(Token.QUESTION) {
						modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind.Nullable, @yes()))]
					}

					set NO
				}

			var value =
				if @test(Token.EQUALS) {
					@commit()

					set @reqExpression(.ImplicitMember, .Method)
				}
				else {
					set NO
				}

			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, value, first ?? name, value ?]] type ?]] name))
		} # }}}

		tryExpression(
			eMode!: ExpressionMode = .Nil
			fMode: FunctionMode
			terminator: MacroTerminator? = null
		): Event<Ast(Expression)> ~ SyntaxError # {{{
		{
			if fMode ~~ .Syntime && @test(.QUOTE) {
				return @reqQuoteExpression(@yes(), terminator)
			}
			else if @test(.CONST) {
				var mark = @mark()
				var operator = @yep(AST.UnaryOperator(.Constant, @yes()))
				var operand = @tryOperation(null, eMode, fMode)

				if operand.ok {
					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}

				@rollback(mark)
			}
			else if eMode ~~ .BinaryOperator {
				if var operator ?]= @tryBinaryOperator(fMode) {
					return @yep(AST.Operator(operator))
				}
			}

			return @tryOperation(null, eMode, fMode)
		} # }}}

		tryExternFunctionDeclaration(
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)
		): Event<Ast(FunctionDeclaration)> ~ SyntaxError # {{{
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
		): Event<Ast(Block, Expression, IfStatement, UnlessStatement)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			@NL_0M()

			if @test(.LEFT_CURLY, .EQUALS_RIGHT_ANGLE) {
				return @reqFunctionBody(modifiers, fMode)
			}
			else {
				@rollback(mark)

				return NO
			}
		} # }}}

		tryFunctionExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
			maxParameters: Number = Infinity
		): Event<Ast(FunctionExpression, LambdaExpression)> ~ SyntaxError # {{{
		{
			if eMode ~~ .NoAnonymousFunction {
				return NO
			}

			if @match(.ASYNC, .FUNC, .LEFT_ROUND, .IDENTIFIER) == .ASYNC {
				var first = @yes()
				var modifiers = [@yep(AST.Modifier(.Async, first))]

				if @test(Token.FUNC) {
					@commit()

					var parameters = @reqFunctionParameterList(.Nil, maxParameters)
					var type = @tryFunctionReturns(eMode)
					var throws = @tryFunctionThrows()
					var body = @reqFunctionBody(modifiers, .Nil)

					return @yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, first, body))
				}
				else {
					var parameters = @tryFunctionParameterList(fMode, maxParameters)
					if !parameters.ok {
						return NO
					}

					var type = @tryFunctionReturns(eMode)
					var throws = @tryFunctionThrows()
					var body = @reqLambdaBody(modifiers, fMode)

					return @yep(AST.LambdaExpression(parameters, modifiers, type, throws, body, first, body))
				}
			}
			else if @token == .FUNC {
				var first = @yes()

				var parameters = @tryFunctionParameterList(.Nil, maxParameters)
				if !parameters.ok {
					return NO
				}

				var modifiers = []
				var type = @tryFunctionReturns(eMode)
				var throws = @tryFunctionThrows()
				var body = @reqFunctionBody(modifiers, .Nil)

				return @yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, first, body))
			}
			else if @token == .LEFT_ROUND {
				var parameters = @tryFunctionParameterList(fMode, maxParameters)

				unless parameters.ok {
					return NO
				}

				var type = @tryFunctionReturns(eMode)
				var throws = @tryFunctionThrows()

				var modifiers = []
				var body = @tryLambdaBody(modifiers, fMode)

				unless body.ok {
					return NO
				}

				return @yep(AST.LambdaExpression(parameters, modifiers, type, throws, body, parameters, body))
			}
			else if @token == .IDENTIFIER {
				var name = @reqIdentifier()

				var modifiers = []
				var body = @tryLambdaBody(modifiers, fMode)

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
		): Event<Event<Ast(Parameter)>[]> ~ SyntaxError # {{{
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
		): Event<Ast(Type)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			@NL_0M()

			if @test(Token.COLON) {
				@commit()

				return @reqTypeReturn(eMode)
			}
			else {
				@rollback(mark)

				return NO
			}
		} # }}}

		tryFunctionThrows(): Event<Event<Ast(Identifier)>[]> ~ SyntaxError # {{{
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

				return NO
			}
		} # }}}

		tryIdentifier(): Event<Ast(Identifier)> ~ SyntaxError # {{{
		{
			if @scanner.test(Token.IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				return NO
			}
		} # }}}

		tryIdentifierOrMember(): Event<Ast(Identifier, MemberExpression)> ~ SyntaxError # {{{
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

		tryIfDeclaration(
			mut attributes: Event<Ast(AttributeDeclaration)>(Y)[]?
			fMode: FunctionMode
		): Event<Ast(VariableDeclaration)> ~ SyntaxError # {{{
		{
			attributes ??= @stackInlineAttributes([])

			if @test(.VAR) {
				var mark = @mark()
				var first = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, first))]

				if @test(.MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind.Mutable, @yes())))
				}

				if @test(.IDENTIFIER, .LEFT_CURLY, .LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					if @test(.COMMA) {
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

						return @yep(AST.VariableDeclaration(attributes, modifiers, variables, operator, expression, first, expression))
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(.ImplicitMember, fMode)

						return @yep(AST.VariableDeclaration(attributes, modifiers, [variable], operator, expression, first, expression))
					}
				}

				@rollback(mark)
			}

			return NO
		} # }}}

		tryIfExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(IfExpression)> ~ SyntaxError # {{{
		{
			unless @test(Token.IF) {
				return NO
			}

			var first = @yes()

			var tracker = @pushMode(.InlineStatement)

			var mark = @mark()

			var mut condition: Event = NO
			var mut declaration: Event = NO

			if @test(Token.VAR) {
				var varMark = @mark()
				var varFirst = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, varFirst))]

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

						declaration = @yep(AST.VariableDeclaration([], modifiers, variables, operator, expression, varFirst, expression))
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(.ImplicitMember, fMode)

						declaration = @yep(AST.VariableDeclaration([], modifiers, [variable], operator, expression, varFirst, expression))
					}

					@NL_0M()

					if @test(Token.SEMICOLON_SEMICOLON) {
						@commit().NL_0M()

						condition = @reqExpression(ExpressionMode.NoAnonymousFunction, fMode)
					}
				}
				else {
					@rollback(varMark)

					condition = @tryExpression(ExpressionMode.NoAnonymousFunction, fMode)
				}
			}
			else {
				condition = @tryExpression(ExpressionMode.NoAnonymousFunction, fMode)
			}

			unless ?]declaration || ?]condition {
				return NO
			}

			if !?]declaration && @test(.SET) {
				var firstTrue = @yes()

				var expressionTrue = @reqExpression(.ImplicitMember, fMode)

				unless @test(.ELSE) {
					@throw('else')
				}

				var firstFalse = @yes()

				var expressionFalse = @reqExpression(.ImplicitMember, fMode)

				@popMode(tracker)

				var whenTrue = @yep(AST.SetStatement(expressionTrue, firstTrue, expressionTrue))
				var whenFalse = @yep(AST.SetStatement(expressionFalse, firstFalse, expressionFalse))

				return @yep(AST.IfExpression(condition, declaration, whenTrue, whenFalse, first, whenFalse))
			}

			@NL_0M()

			unless @test(.LEFT_CURLY) {
				@rollback(mark)

				return NO
			}

			var whenTrue = @reqBlock(NO, null, fMode)

			@commit().NL_0M()

			unless @test(.ELSE) {
				@throw('else')
			}

			@commit().NL_0M()

			if var whenFalseIf ?]= @tryIfExpression(eMode, fMode) {
				@popMode(tracker)

				return @yep(AST.IfExpression(condition, declaration, whenTrue, whenFalseIf, first, whenFalseIf))
			}
			else {
				var whenFalseBlock = @reqBlock(NO, null, fMode)

				@popMode(tracker)

				return @yep(AST.IfExpression(condition, declaration, whenTrue, whenFalseBlock, first, whenFalseBlock))
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
		): Event<Ast(Block, Expression)> ~ SyntaxError # {{{
		{
			if @test(.EQUALS_RIGHT_ANGLE) {
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

		tryMatchExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(MatchExpression)> ~ SyntaxError # {{{
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
		): Event<Ast(MatchStatement)> ~ SyntaxError # {{{
		{
			var mut expression: Event = NO
			var mut declaration: Event = NO

			if @test(Token.VAR) {
				var mark = @mark()
				var varFirst = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, varFirst))]

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

						var operator =
							if @test(Token.EQUALS) {
								set @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
							}
							else {
								@throw('=')
							}

						unless @test(Token.AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(.Nil, fMode)
						var operation = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						declaration = @yep(AST.VariableDeclaration([], modifiers, variables, operator, operation, varFirst, operation))
					}
					else {
						var operator =
							if @test(Token.EQUALS) {
								set @yep(AST.AssignmentOperator(AssignmentOperatorKind.Equals, @yes()))
							}
							else {
								@throw('=')
							}

						var operation = @reqOperation(.ImplicitMember, fMode)

						declaration = @yep(AST.VariableDeclaration([], modifiers, [variable], operator, operation, varFirst, operation))
					}
				}
				else {
					@rollback(mark)

					unless expression ?]= @tryOperation(null, .Nil, fMode) {
						return NO
					}
				}
			}
			else {
				unless expression ?]= @tryOperation(null, .Nil, fMode) {
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
		): Event<Ast(Identifier, Literal, TemplateExpression)> ~ SyntaxError # {{{
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
			fMode: FunctionMode
		): Event<Ast(NamespaceDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			return @reqNamespaceStatement(first, name, fMode)
		} # }}}

		tryNumber(): Event<Ast(NumericExpression)> ~ SyntaxError # {{{
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
		): Event<Ast(Expression)> ~ SyntaxError # {{{
		{
			@NL_0M()

			var attributes = []
			var properties = []

			while @stackInnerAttributes(attributes) {
				pass
			}

			if @test(Token.RIGHT_CURLY) {
				return @yep(AST.ObjectExpression(attributes, properties, first, @yes()))
			}

			with var property = @tryObjectItem(true, first, eMode, fMode) {
				if !?]property || property.value is .ObjectComprehension {
					return property
				}

				properties.push(property)
			}

			if @tryCommaNL0M() {
				while @until(Token.RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					with var property = @tryObjectItem(false, first, eMode, fMode) {
						return property unless ?]property

						properties.push(property)
					}

					break unless @tryCommaNL0M()
				}
			}

			unless @test(Token.RIGHT_CURLY) {
				return @no('}')
			}

			return @yep(AST.ObjectExpression(attributes, properties, first, @yes()))
		} # }}}

		tryObjectComprehension(
			name: Event<Ast(ComputedPropertyName, TemplateExpression)>(Y)
			value: Event<Ast(Expression)>(Y)
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(ObjectComprehension)> ~ SyntaxError # {{{
		{
			var firstLoop = @yes()

			@NL_0M()

			var iteration = @reqIteration(null, fMode)

			@NL_0M()

			unless @test(Token.RIGHT_CURLY) {
				return @no('}')
			}

			return @yep(AST.ObjectComprehension(name, value, iteration, first, @yes()))
		} # }}}

		tryObjectItem(
			comprehension: Boolean
			topFirst: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)> ~ SyntaxError # {{{
		{
			var dyn first

			var attributes = @stackOuterAttributes([])
			if attributes.length > 0 {
				first = attributes[0]
			}

			var late name
			if @match(Token.AMPERAT, Token.DOT_DOT_DOT_QUESTION, Token.DOT_DOT_DOT, Token.IDENTIFIER, Token.LEFT_SQUARE, Token.STRING, Token.TEMPLATE_BEGIN) == Token.IDENTIFIER {
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
			else if fMode ~~ FunctionMode.Method && @token == Token.AMPERAT {
				var thisExpression = @reqThisExpression(@yes())
				var property = @yep(AST.ShorthandProperty(attributes, thisExpression, first ?? thisExpression, thisExpression))

				return @altRestrictiveExpression(property, fMode)
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
						var mut external: Event<Ast(Identifier)> = @reqIdentifier()
						var mut internal = external

						if @test(.PERCENT) {
							@commit()

							internal = @reqIdentifier()
						}
						else {
							external = NO
						}

						members.push(@yep(AST.NamedSpecifier([], internal, external, external ?]] internal, internal)))

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

			if @test(.COLON) {
				@commit()

				var value = @reqExpression(.ImplicitMember + .NoRestriction, fMode, .Object)

				if comprehension && name.value.kind == .ComputedPropertyName | .TemplateExpression && @test(.FOR) {
					return @tryObjectComprehension(name!!, value, topFirst, eMode, fMode)
				}

				var expression = @yep(AST.ObjectMember(attributes, [], name, NO, value, first ?? name, value))

				return @altRestrictiveExpression(expression, fMode)
			}
			else {
				var expression = @yep(AST.ShorthandProperty(attributes, name, first ?? name, name))

				return @altRestrictiveExpression(expression, fMode)
			}
		} # }}}

		tryOperand(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)> ~ SyntaxError # {{{
		{
			match @matchM(M.OPERAND, eMode, fMode) {
				.AMPERAT {
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
					return @reqArray(@yes(), eMode, fMode)
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
					return @yep(AST.Literal(null, @value()!!!, @yes()))
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
			mut operand: Event<Ast(Expression)>?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)> ~ SyntaxError # {{{
		{
			var mut mark = @mark()
			var mut operator = null

			if !?operand {
				var binding = @tryDestructuring(null, fMode)

				if binding.ok {
					@NL_0M()

					if (operator <- @tryAssignementOperator()).ok {
						@NL_0M()

						var binaryOperand = @reqBinaryOperand(eMode + ExpressionMode.ImplicitMember, fMode)

						return @yep(AST.BinaryExpression(binding, operator, binaryOperand, binding, binaryOperand))
					}
				}

				@rollback(mark)

				operand = @tryBinaryOperand(eMode, fMode)

				return operand unless operand.ok
			}

			var values: Ast(Expression, Type)[] = [operand.value]

			var mut type = false

			repeat {
				mark = @mark()

				@NL_0M()

				if operator ?]= @tryBinaryOperator(fMode) {
					var mut mode = eMode + ExpressionMode.ImplicitMember

					match operator.value.kind {
						BinaryOperatorKind.Assignment {
							@validateAssignable(values[values.length - 1]!!)
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
							var memberOperand = @yep(AST.MemberExpression([], NO, @reqNumeralIdentifier(), first))

							values.push(@reqUnaryOperand(memberOperand, mode, fMode).value)
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
								var array = @reqArray(first, eMode, fMode).value

								if array is .ArrayExpression && array.values.length == 1 && !@hasTopicReference(array) {
									var modifiers = [AST.Modifier(ModifierKind.Computed, first)]
									var memberOperand = @yep(AST.MemberExpression(modifiers, NO, @yep(array.values[0]), first, array))

									values.push(@reqUnaryOperand(memberOperand, mode, fMode).value)
								}
								else {
									values.push(array)
								}
							}
						}
						else {
							var functionMark = @mark()
							var functionOperand = @tryFunctionExpression(mode, fMode + FunctionMode.NoPipeline, 1)

							if functionOperand.ok {
								values.push(functionOperand.value)
							}
							else {
								@rollback(functionMark)

								var binary = @reqBinaryOperand(mode, fMode).value

								if binary is .Identifier && binary.name == 'await' {
									values.push(AST.AwaitExpression([], [], NO, binary, binary))
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
				else if (operator <- @tryJunctionOperator()).ok {
					values.push(@reqJunctionExpression(operator, eMode, fMode, values!!, type))
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
				return @yep(values[0]!!)!!!
			}
			else {
				return @yep(AST.reorderExpression(values!!))!!!
			}
		} # }}}

		tryParenthesis(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(Expression)> ~ SyntaxError # {{{
		{
			try {
				return @reqParenthesis(first, fMode)
			}
			catch {
				return NO
			}
		} # }}}

		tryPostfixedOperand(
			operand: Event<Ast(Expression)>(Y)?
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)> ~ SyntaxError # {{{
		{
			var unaryOperand = @tryUnaryOperand(operand, eMode, fMode)

			return unaryOperand unless unaryOperand.ok

			var modifiers = []
			var mut operator = null

			match @matchM(M.POSTFIX_OPERATOR) {
				.EXCLAMATION_EXCLAMATION {
					operator = @yep(AST.UnaryOperator(.TypeFitting, @yes()))
				}
				.EXCLAMATION_EXCLAMATION_EXCLAMATION {
					operator = @yep(AST.UnaryOperator(.TypeFitting, @yes()))
					modifiers.push(@yep(AST.Modifier(.Forced, operator)))
				}
				.EXCLAMATION_QUESTION {
					operator = @yep(AST.UnaryOperator(.TypeNotNull, @yes()))
					modifiers.push(@yep(AST.Modifier(.Nullable, operator)))
				}
				else {
					return unaryOperand
				}
			}

			var unaryExpression = @yep(AST.UnaryExpression(modifiers, operator, unaryOperand, unaryOperand, operator))

			return @tryPostfixedOperand(unaryExpression, eMode, fMode)
		} # }}}

		tryPrefixedOperand(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)> ~ SyntaxError # {{{
		{
			var mark = @mark()

			match @matchM(M.PREFIX_OPERATOR, eMode) {
				.DOT {
					var operator = @yep(AST.UnaryOperator(.Implicit, @yes()))
					var operand = @tryIdentifier()

					if operand.ok {
						return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
					}
					else {
						@rollback(mark)
					}
				}
				.DOT_DOT_DOT {
					if eMode ~~ .Pipeline {
						var position = @yes()
						var operand = @tryPrefixedOperand(eMode, fMode)

						if operand.ok {
							var operator = @yep(AST.UnaryOperator(.Spread, position))

							return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
						}
						else {
							var modifiers = [AST.Modifier(.Spread, position)]
							var operator = @yep(AST.TopicReference(modifiers, position))

							return @reqPostfixedOperand(operator, eMode, fMode)
						}
					}
					else {
						var operator = @yep(AST.UnaryOperator(.Spread, @yes()))
						var operand = @reqPrefixedOperand(eMode, fMode)

						return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
					}
				}
				.DOT_DOT_DOT_QUESTION {
					var operator = @yep(AST.UnaryOperator(.Spread, @yes()))
					var modifier = @yep(AST.Modifier(.Nullable, operator))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([modifier], operator, operand, operator, operand))
				}
				.EXCLAMATION {
					var operator = @yep(AST.UnaryOperator(.LogicalNegation, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				.HASH {
					var operator = @yep(AST.UnaryOperator(.Length, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				.QUESTION_HASH {
					var operator = @yep(AST.UnaryOperator(.NonEmpty, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				.QUESTION_PLUS {
					var operator = @yep(AST.UnaryOperator(.Finite, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				.QUESTION_RIGHT_SQUARE {
					var operator = @yep(AST.UnaryOperator(.VariantYes, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				.MINUS {
					var first = @yes()
					var operand = @reqPrefixedOperand(eMode, fMode)

					if operand.value is .NumericExpression {
						operand.value.value = -operand.value.value

						return @relocate(operand, first, null)
					}
					else {
						var operator = @yep(AST.UnaryOperator(.Negative, first))

						return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
					}
				}
				.PLUS_CARET {
					var operator = @yep(AST.UnaryOperator(.BitwiseNegation, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				.QUESTION {
					var operator = @yep(AST.UnaryOperator(.Existential, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression([], operator, operand, operator, operand))
				}
				.UNDERSCORE {
					return @reqPostfixedOperand(@yep(AST.TopicReference(@yes())), eMode, fMode)
				}
			}

			return @tryPostfixedOperand(null, eMode, fMode)
		} # }}}

		tryRangeOperand(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)> ~ SyntaxError # {{{
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
		): Event<Ast(IfStatement, ReturnStatement, UnlessStatement)> ~ SyntaxError # {{{
		{
			if @match(Token.IF, Token.UNLESS, Token.NEWLINE) == Token.IF {
				var mark = @mark()

				@commit()

				var condition = @reqExpression(eMode + .NoRestriction, fMode)

				if @test(Token.NEWLINE) || @token == Token.EOF {
					return @yep(AST.IfStatement(condition, @yep(AST.ReturnStatement(first)), NO, first, condition))
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

				return @yep(AST.IfStatement(condition, @yep(AST.ReturnStatement(expression, first, expression)), NO, first, condition))
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

		trySemtimeStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(SemtimeStatement)> ~ SyntaxError { # {{{
			var body =
				if @match(.LEFT_CURLY, .EQUALS_RIGHT_ANGLE) == .LEFT_CURLY {
					set @reqBlock(@yes(), null, .Nil)
				}
				else {
					set @tryExpression(.Nil, fMode)
				}

			return NO unless ?]body

			return @yep(AST.SemtimeStatement([], body, first, body))
		} # }}}

		tryShebang(): Event<Ast(ShebangDeclaration)> ~ SyntaxError # {{{
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

		tryStatement(
			sMode: StatementMode
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Statement)> ~ SyntaxError { # {{{
			try {
				return @reqStatement(sMode, eMode, fMode)
			}
			catch {
				return NO
			}
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
		): Event<Ast(StructDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			var attributes = []
			var elements = []
			var mut last: Range = name

			var extends =
				if @test(Token.EXTENDS) {
					@commit()

					set @reqTypeNamed([])
				}
				else {
					set NO
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

				@stackInnerAttributes(attributes)

				until @test(Token.RIGHT_CURLY) {
					var mark = @mark()
					var mut nf = true

					if @test(.VARIANT) {
						var variantFirst = @yes()
						var identifier = @tryIdentifier()

						if name.ok && @test(.COLON) {
							@commit()

							var enumName = @reqIdentifierOrMember()
							var enum = @yep(AST.TypeReference(enumName))
							var fields = []

							if @test(.LEFT_CURLY) {
								@commit()

								@reqVariantFieldList(fields)
							}

							var type = @yep(AST.VariantType(enum, fields, enum, @yes()))

							elements.push(AST.FieldDeclaration([], [], identifier!!, type, NO, variantFirst, type))

							nf = false
						}
						else {
							@rollback(mark)
						}
					}

					if nf {
						var fieldAttributes = @stackOuterAttributes([])
						var modifiers = []
						var fieldName = @reqIdentifier()

						var fieldFirst =
							if ?#fieldAttributes {
								set fieldAttributes[0]
							}
							else {
								set NO
							}
						var mut fieldLast: Event(Y) = fieldName

						var type =
							if @test(Token.COLON) {
								@commit()

								set @reqType()
							}
							else {
								if @test(Token.QUESTION) {
									var modifier = @yep(AST.Modifier(ModifierKind.Nullable, @yes()))

									modifiers.push(modifier)

									fieldLast = modifier
								}

								set NO
							}

						var defaultValue =
							if @test(Token.EQUALS) {
								@commit()

								set @reqExpression(.ImplicitMember, .Nil)
							}
							else {
								set NO
							}

						elements.push(AST.FieldDeclaration(fieldAttributes, modifiers, fieldName, type, defaultValue, fieldFirst ?]] fieldName, defaultValue ?]] type ?]] fieldLast))
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

		trySyntimeStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(SyntimeStatement)> ~ SyntaxError { # {{{
			return NO unless @test(.DO)

			@commit()

			var body = @reqBlock(NO, .Nil, .Syntime)

			return @yep(AST.SyntimeStatement([], body, first, body))
		} # }}}

		tryTryExpression(
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(TryExpression)> ~ SyntaxError # {{{
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
		): Event<Ast(TryStatement)> ~ SyntaxError # {{{
		{
			@NL_0M()

			var body = @tryBlock(fMode)

			unless body.ok {
				return NO
			}

			var mut last: Event(Y) = body
			var mut mark = @mark()
			var catchClauses = []

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

			var late catchClause
			if @test(Token.CATCH) {
				catchClause = @reqTryCatchClause(@yes(), fMode)

				mark = @mark()
			}
			else {
				catchClause = NO

				@rollback(mark)
			}

			@NL_0M()

			var finalizer =
				if @test(Token.FINALLY) {
					@commit()

					set @reqBlock(NO, null, fMode)
				}
				else {
					@rollback(mark)

					set NO
				}

			return @yep(AST.TryStatement(body, catchClauses, catchClause, finalizer, first, finalizer ?]] catchClause ?]] last))
		} # }}}

		tryTupleStatement(
			first: Event(Y)
		): Event<Ast(TupleDeclaration)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			var attributes = []
			var modifiers = []
			var elements = []
			var dyn last = name

			var extends =
				if @test(Token.EXTENDS) {
					@commit()

					set @reqIdentifier()
				}
				else {
					set NO
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
					var fieldModifiers = []
					var mut fieldFirst = null
					var mut fieldLast = null

					var fieldAttributes = @stackOuterAttributes([])
					if ?#fieldAttributes {
						fieldFirst = fieldAttributes[0]
					}

					var mut fieldName: Event = NO
					var mut type: Event = NO

					if @test(Token.COLON) {
						if ?fieldFirst {
							@commit()
						}
						else {
							fieldFirst = @yes()
						}

						type = @reqType()

						fieldLast = type
					}
					else {
						fieldName = @reqIdentifier()
						fieldFirst = fieldName

						if @test(Token.COLON) {
							@commit()

							type = @reqType()

							fieldLast = type
						}
						else if @test(Token.QUESTION) {
							var modifier = @yep(AST.Modifier(ModifierKind.Nullable, @yes()))

							fieldModifiers.push(modifier)

							fieldLast = modifier
						}
						else {
							fieldLast = fieldName
						}
					}

					var defaultValue =
						if @test(Token.EQUALS) {
							@commit()

							set @reqExpression(.ImplicitMember, .Nil)
						}
						else {
							set NO
						}

					elements.push(AST.TupleField(fieldAttributes, fieldModifiers, fieldName, type, defaultValue, fieldFirst, defaultValue ?]] fieldLast))

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
		): Event<Ast(Type)> ~ SyntaxError # {{{
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
		): Event<Ast(Type)> ~ SyntaxError # {{{
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
					var functionModifiers = [@yep(AST.Modifier(ModifierKind.Async, async))]
					var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
					var type = @tryFunctionReturns(eMode, false)
					var throws = @tryFunctionThrows()

					var func = @yep(AST.FunctionExpression(parameters, functionModifiers, type, throws, null, async, throws ?]] type ?]] parameters))

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

					var func = @yep(AST.FunctionExpression(parameters, null, type, throws, null, first, throws ?]] type ?]] parameters))

					return @altTypeContainer(func)
				}

				@rollback(mark)
			}

			if @test(.TYPEOF) {
				var operator = @yep(AST.UnaryTypeOperator(.TypeOf, @yes()))
				var operand = @tryUnaryOperand(null, eMode, if eMode ~~ .AtThis set .Method else .Nil)

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

				var func = @yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?]] type ?]] parameters))

				return @altTypeContainer(func)
			}

			var type = @tryTypeNamed(modifiers, eMode)

			if type.ok {
				return @altTypeContainer(type, eMode !~ .NoNull)
			}
			else {
				return NO
			}
		} # }}}

		tryTypeDescriptive(
			tMode: TypeMode = .Nil
		): Event<Ast(DescriptiveType)> ~ SyntaxError # {{{
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
							return @yep(AST.VariableDeclarator([sealed], name, NO, sealed, name))
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
							return @yep(AST.VariableDeclarator([system], name, NO, system, name))
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
						return @yep(AST.VariableDeclarator([], name, NO, first, name))
					}
				}
			}

			return NO
		} # }}}

		tryTypeEntity(): Event<Ast(TypeReference)> ~ SyntaxError # {{{
		{
			var name = @tryIdentifierOrMember()

			return NO unless name.ok

			return @yep(AST.TypeReference(name))
		} # }}}

		tryTypeNamed(
			modifiers: Event<ModifierData>(Y)[]
			eMode: ExpressionMode = .Nil
		): Event<Ast(TypeReference)> ~ SyntaxError # {{{
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
			var mut generic: Event = NO

			if @testNS(.LEFT_ANGLE) {
				var leftFirst = @yes()
				var types = [@reqType()]

				while @test(.COMMA) {
					@commit()

					types.push(@reqType())
				}

				unless @test(.RIGHT_ANGLE) {
					@throw('>')
				}

				last = generic = @yes(types, leftFirst)
			}

			var mut typeSubtypes: Event = NO

			if @testNS(.LEFT_ROUND) {
				var leftFirst = @yes()
				var mark = @mark()

				var modifier =
					if @test(Token.EXCLAMATION) {
						set AST.Modifier(ModifierKind.Exclusion, @yes())
					}
					else {
						set null
					}
				var exclusif = ?modifier

				var identifier = @tryIdentifier()

				if identifier.ok && (exclusif || @test(.COMMA, .RIGHT_ROUND)) {
					if exclusif {
						AST.pushModifier(identifier.value, @yep(modifier!?), true)
					}

					var names = [identifier]

					if exclusif {
						while @test(.COMMA) {
							@commit()

							unless @test(Token.EXCLAMATION) {
								@throw('!')
							}

							var mod = AST.Modifier(ModifierKind.Exclusion, @yes())
							var id = @reqIdentifier()

							AST.pushModifier(id.value, @yep(mod), true)

							names.push(id)
						}
					}
					else {
						while @test(.COMMA) {
							@commit()

							names.push(@reqIdentifier())
						}
					}

					unless @test(.RIGHT_ROUND) {
						@throw(')')
					}

					last = typeSubtypes = @yes(names, leftFirst)
				}
				else {
					@rollback(mark) if ?modifier

					var expression = @tryOperation(identifier, .InlineOnly, .Nil)

					unless expression.ok {
						@throw('expression')
					}

					unless @test(.RIGHT_ROUND) {
						@throw(')')
					}

					last = typeSubtypes = @yes(expression.value, leftFirst)
				}
			}

			return @yep(AST.TypeReference(modifiers, name, generic, typeSubtypes, first, last))
		} # }}}

		tryTypeLimited(
			modifiers: Event<ModifierData>(Y)[] = []
			eMode: ExpressionMode = .Nil
		): Event<Ast(Type)> ~ SyntaxError # {{{
		{
			if @test(Token.LEFT_ROUND) {
				var parameters = @reqFunctionParameterList(FunctionMode.Nil, DestructuringMode.EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?]] type ?]] parameters))
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

		tryTypeParameterList(): Event<Event<Ast(TypeParameter)>[]> ~ SyntaxError # {{{
		{
			unless @test(.LEFT_ANGLE) {
				return NO
			}

			@commit()

			var result = []
			var mut last = null

			do {
				@commit() if ?last

				var identifier = @reqIdentifier()

				var constraint =
					if @test(.IS) {
						@commit()

						set @reqType(.InlineOnly + .ImplicitMember)
					}
					else {
						set NO
					}

				result.push(@yep(AST.TypeParameter(identifier, constraint, identifier, constraint ?]] identifier)))

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
		): Event<Ast(TypeAliasDeclaration)> ~ SyntaxError # {{{
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
		): Event<Ast(VariableDeclarator)> ~ SyntaxError # {{{
		{
			try {
				return @reqTypedVariable(fMode, typeable, questionable)
			}
			catch {
				return NO
			}
		} # }}}

		tryUnaryOperand(
			mut value: Event<Ast(Expression)>(Y)?
			mut eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(Expression)> ~ SyntaxError # {{{
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
					.ASTERISK_DOLLAR_LEFT_ROUND {
						@commit()

						var arguments = @reqArgumentList(eMode, fMode)
						var scope = arguments.value.shift()

						if scope is not Event<Ast(Argument, Identifier, ObjectExpression)>(Y) {
							@throw('object scope')
						}

						value = @yep(AST.CallExpression([], AST.Scope(.Argument, scope), value, arguments, value, @yes()))
					}
					.CARET_CARET_LEFT_ROUND {
						@commit()

						var arguments = @reqArgumentList(eMode + .Curry, fMode)

						value = @yep(AST.CurryExpression(AST.Scope(.This), value, arguments, value, @yes()))
					}
					.CARET_DOLLAR_LEFT_ROUND {
						@commit()

						var arguments = @reqArgumentList(eMode + .Curry, fMode)
						var scope = arguments.value.shift()

						if scope is not Event<Ast(Argument, Identifier, ObjectExpression)>(Y) {
							@throw('object scope')
						}

						value = @yep(AST.CurryExpression(AST.Scope(.Argument, scope), value, arguments, value, @yes()))
					}
					.COLON_AMPERSAND_LEFT_ROUND {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([], .TypeAssertion, first))
						var type = @reqType(null, false, .ImplicitMember)

						unless @test(.RIGHT_ROUND) {
							@throw(')')
						}

						value = @yep(AST.BinaryExpression(value, operator, type, value, @yes()))
					}
					.COLON_AMPERSAND_QUESTION_LEFT_ROUND {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([AST.Modifier(.Nullable, first)], .TypeAssertion, first))
						var type = @reqType(null, false, .ImplicitMember)

						unless @test(.RIGHT_ROUND) {
							@throw(')')
						}

						value = @yep(AST.BinaryExpression(value, operator, type, value, @yes()))
					}
					.COLON_EXCLAMATION_EXCLAMATION_EXCLAMATION_LEFT_ROUND {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([AST.Modifier(.Forced, first)], .TypeSignalment, first))
						var type = @reqType(null, false, .ImplicitMember)

						unless @test(.RIGHT_ROUND) {
							@throw(')')
						}

						value = @yep(AST.BinaryExpression(value, operator, type, value, @yes()))
					}
					.COLON_EXCLAMATION_EXCLAMATION_LEFT_ROUND {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([], .TypeSignalment, first))
						var type = @reqType(null, false, .ImplicitMember)

						unless @test(.RIGHT_ROUND) {
							@throw(')')
						}

						value = @yep(AST.BinaryExpression(value, operator, type, value, @yes()))
					}
					.COLON_RIGHT_ANGLE_LEFT_ROUND {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([], .TypeCasting, first))
						var type = @reqType(null, false, .ImplicitMember)

						unless @test(.RIGHT_ROUND) {
							@throw(')')
						}

						value = @yep(AST.BinaryExpression(value, operator, type, value, @yes()))
					}
					.COLON_RIGHT_ANGLE_QUESTION_LEFT_ROUND {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([AST.Modifier(.Nullable, first)], .TypeCasting, first))
						var type = @reqType(null, false, .ImplicitMember)

						unless @test(.RIGHT_ROUND) {
							@throw(')')
						}

						value = @yep(AST.BinaryExpression(value, operator, type, value, @yes()))
					}
					.DOT {
						@commit()

						value = @yep(AST.MemberExpression([], value, @reqNumeralIdentifier()))
					}
					.DOT_DOT {
						if eMode ~~ .NoInlineCascade {
							break
						}

						value = @reqRollingExpression(value, [], eMode, fMode, false)
					}
					.EXCLAMATION_LEFT_ROUND {
						first = @yes()

						var arguments = @reqSyntimeArgumentList(eMode, fMode)

						value = @yep(AST.SyntimeCallExpression([], value, arguments, value, @yes()))
					}
					.LEFT_ANGLE {
						@commit()

						var mode: ExpressionMode = .InlineOnly + .NoNull
						var types = [@reqType(mode)]

						while @test(.COMMA) {
							@commit()

							types.push(@reqType(mode))
						}

						unless @test(.RIGHT_ANGLE) {
							@throw('>')
						}

						value = @yep(AST.TypedExpression([], value, types, value, @yes()))
					}
					.LEFT_SQUARE {
						var modifiers = [AST.Modifier(.Computed, @yes())]

						expression = @reqExpression(eMode, fMode)

						unless @test(.RIGHT_SQUARE) {
							@throw(']')
						}

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, @yes()))
					}
					.LEFT_ROUND {
						@commit()

						value = @yep(AST.CallExpression([], value, @reqArgumentList(eMode, fMode), value, @yes()))
					}
					.NEWLINE {
						if eMode ~~ .NoMultiLine {
							break
						}

						var mark = @mark()

						@commit().NL_0M()

						if @test(.DOT_DOT) {
							value = @reqRollingExpression(value, [], eMode, fMode, true)
						}
						else if @test(.DOT) {
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
						else if @test(.QUESTION_DOT) {
							var modifiers = [AST.Modifier(.Nullable, @yes())]

							value = @reqCascadeExpression(value, modifiers, null, eMode, fMode)
						}
						else {
							@rollback(mark)

							break
						}
					}
					.QUESTION_DOT {
						var modifiers = [AST.Modifier(.Nullable, @yes())]

						expression = @reqIdentifier()

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, expression))
					}
					.QUESTION_DOT_DOT {
						if eMode ~~ .NoInlineCascade {
							break
						}

						var modifiers = [AST.Modifier(.Nullable, @yes())]

						value = @reqRollingExpression(value, modifiers, eMode, fMode, true)
					}
					.QUESTION_LEFT_ROUND {
						var modifiers = [AST.Modifier(.Nullable, @yes())]

						value = @yep(AST.CallExpression(modifiers, AST.Scope(.This), value, @reqArgumentList(eMode, fMode), value, @yes()))
					}
					.QUESTION_LEFT_SQUARE {
						var position = @yes()
						var modifiers = [AST.Modifier(.Nullable, position), AST.Modifier(.Computed, position)]

						expression = @reqExpression(eMode, fMode)

						unless @test(.RIGHT_SQUARE) {
							@throw(']')
						}

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, @yes()))
					}
					.TEMPLATE_BEGIN {
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
		): Event<Ast(UntilStatement)> ~ SyntaxError # {{{
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

		tryVariable(): Event<Ast(VariableDeclarator)> ~ SyntaxError # {{{
		{
			if var name ?]= @tryIdentifier() {
				return @yep(AST.VariableDeclarator([], name, NO, name, name))
			}
			else {
				return NO
			}
		} # }}}

		tryVariableName(
			fMode: FunctionMode
		): Event<Ast(Identifier, MemberExpression, ThisExpression)> ~ SyntaxError # {{{
		{
			var dyn object
			if fMode ~~ FunctionMode.Method && @test(Token.AMPERAT) {
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
		): Event<Ast(VariantDeclaration)> ~ SyntaxError # {{{
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
		): Event<Ast(VariableStatement)> ~ SyntaxError # {{{
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
		): Event<Ast(VariableStatement)> ~ SyntaxError # {{{
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

							declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, value, variable, value)))
						}
						else {
							declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))
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

			var variables = []

			if var variable ?]= @tryTypedVariable(fMode, false, false) {
				variables.push(variable)
			}
			else {
				return NO
			}

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

					var declaration = @yep(AST.VariableDeclaration([], [], variables, NO, value, first, value))

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

					var declaration = @yep(AST.VariableDeclaration([], [], variables, NO, value, first, value))

					return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
				}
			}

			var declarations = []
			var mut last = null

			for var variable in variables {
				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))

				last = variable
			}

			while @test(Token.COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, false, false)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last))
		} # }}}

		tryVarImmuStatement(
			modifiers: Event<ModifierData>(Y)[]
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(VariableStatement)> ~ SyntaxError # {{{
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

						declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, value, variable, value)))

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

			var declaration = @yep(AST.VariableDeclaration([], [], variables, NO, value, variable, value))

			return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
		} # }}}

		tryVarLateStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(VariableStatement)> ~ SyntaxError # {{{
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

						declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))

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

			var declarations = []
			var mut last = null

			if var variable ?]= @tryTypedVariable(fMode, true, true) {
				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))

				last = variable
			}
			else {
				return NO
			}

			while @test(Token.COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, true, true)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last!?))
		} # }}}

		tryVarMutStatement(
			first: Event(Y)
			eMode: ExpressionMode
			fMode: FunctionMode
		): Event<Ast(VariableStatement)> ~ SyntaxError # {{{
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

							declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, value, variable, value)))
						}
						else if ?variable.value.type {
							declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))
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

			var variables = []

			if var variable ?]= @tryTypedVariable(fMode, true, true) {
				variables.push(variable)
			}
			else {
				return NO
			}

			if @test(Token.COMMA) {
				@commit()

				var variable = @tryTypedVariable(fMode, true, true)

				return NO unless variable.ok

				variables.push(variable)
			}

			if #variables == 1 {
				if @test(Token.EQUALS) {
					@commit().NL_0M()

					var value = @reqExpression(eMode + ExpressionMode.ImplicitMember, fMode)

					var declaration = @yep(AST.VariableDeclaration([], [], variables, NO, value, first, value))

					return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
				}
				else if ?variables[0].value.type {
					var declaration = @yep(AST.VariableDeclaration([], [], variables, NO, NO, first, variables[0]))

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

				var declaration = @yep(AST.VariableDeclaration([], [], variables, NO, value, first, value))

				return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
			}

			var declarations = []
			var mut last = null

			for var variable in variables {
				if !?variable.value.type {
					return NO
				}

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))

				last = variable
			}

			while @test(Token.COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, true, false)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], NO, NO, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last))
		} # }}}

		tryWhileStatement(
			first: Event(Y)
			fMode: FunctionMode
		): Event<Ast(WhileStatement)> ~ SyntaxError # {{{
		{
			var attributes = @stackInlineAttributes([])

			var dyn condition

			if @test(Token.VAR) {
				var mark = @mark()
				var varFirst = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind.Declarative, varFirst))]

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

						condition = @yep(AST.VariableDeclaration(attributes, modifiers, variables, operator, expression, varFirst, expression))
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(.Nil, fMode)

						condition = @yep(AST.VariableDeclaration(attributes, modifiers, [variable], operator, expression, varFirst, expression))
					}
				}
				else if ?#attributes {
					return NO
				}
				else {
					@rollback(mark)

					condition = @tryExpression(.Nil, fMode)
				}
			}
			else if ?#attributes {
				return NO
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
		): Event<Ast(BinaryExpression, VariableDeclaration)> ~ SyntaxError # {{{
		{
			var attributes = @stackInlineAttributes([])

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

						return @yep(AST.VariableDeclaration(attributes, modifiers, variables, NO, expression, first, expression))
					}
					else {
						if @test(Token.EQUALS) {
							@commit()
						}
						else {
							@throw('=')
						}

						var expression = @reqExpression(.Nil, fMode)

						return @yep(AST.VariableDeclaration(attributes, modifiers, [variable], NO, expression, first, expression))
					}
				}

				@rollback(mark)
			}

			if ?#attributes {
				return NO
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
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind.Remainder, @yes()))
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
		): Event<Ast(WithStatement)> ~ SyntaxError # {{{
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

					if variable.value.kind == AstKind.Identifier {
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

			mark = @mark()

			var finalizer =
				if @hasNL_1M() && @test(Token.FINALLY) {
					@commit()

					set @reqBlock(NO, null, fMode)
				}
				else {
					@rollback(mark)

					set NO
				}

			return @yep(AST.WithStatement(variables, body, finalizer, first, finalizer ?]] body))
		} # }}}

		validateAssignable(
			expression: Ast(Expression)
		): Void ~ SyntaxError # {{{
		{
			unless expression.kind == AstKind.ArrayBinding | AstKind.Identifier | AstKind.MemberExpression | AstKind.ObjectBinding | AstKind.ThisExpression {
				throw @error(`The left-hand side of an assignment expression must be a variable, a property access or a binding`, expression.start.line, expression.start.column)
			}
		} # }}}
	}

	func parse(data: String) ~ SyntaxError { # {{{
		var parser = Parser.new(data)

		return parser.parseModule()
	} # }}}

	func parseMatchClauses(data: String) ~ SyntaxError { # {{{
		var parser = Parser.new(data)

		return parser.parseMatchClauses()
	} # }}}

	func parseStatements(data: String, mode: FunctionMode) ~ SyntaxError { # {{{
		var parser = Parser.new(data)

		return parser.parseStatements(mode)
	} # }}}

	export {
		FunctionMode

		parse
		parseMatchClauses
		parseStatements
	}
}

export SyntaxAnalysis.parse
