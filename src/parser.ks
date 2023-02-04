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

import '@kaoscript/ast'

export namespace Parser {
	include {
		'./util'

		'./types'

		'./ast'
		'./scanner'
	}

	struct AmbiguityResult {
		token: Token?	= null
		identifier: Event?		= null
	}

	bitmask ClassBits {
		AbstractMethod		 = 1
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
		Variable
	}

	bitmask DestructuringMode {
		Nil

		COMPUTED
		DEFAULT
		EXTERNAL_ONLY
		RECURSION
		THIS_ALIAS
		TYPE

		Declaration			= COMPUTED + DEFAULT + RECURSION + TYPE
		Expression			= COMPUTED + DEFAULT + RECURSION
		Parameter			= DEFAULT + RECURSION + TYPE
	}

	bitmask ExpressionMode {
		Default
		Arrow
		EndOfLine
		ImplicitMember
		NoAnonymousFunction
		NoAwait
		NoObject
		NoRestriction
		WithMacro
	}

	enum FunctionMode {
		Function
		Macro
		Method
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

	bitmask ParserMode {
		Default
		InlineStatement
		MacroExpression
		Typing
	}

	enum TypeMode {
		Default
		Module
		NoIdentifier
	}

	var NO = Event(ok: false)
	var YES = Event(ok: true)

	class Parser {
		private {
			@mode: ParserMode	= ParserMode::Default
			@scanner: Scanner
			@token: Token?
		}
		constructor(data: String) ~ SyntaxError { # {{{
			@scanner = new Scanner(data)
		} # }}}
		commit(): this { # {{{
			@token = @scanner.commit()
		} # }}}
		error(message: String, lineNumber: Number = @scanner.line(), columnNumber: Number = @scanner.column()): SyntaxError { # {{{
			var error = new SyntaxError(message)

			error.lineNumber = lineNumber
			error.columnNumber = columnNumber

			return error
		} # }}}
		mark(): Marker => @scanner.mark()
		match(...tokens: Token): Token => @token <- @scanner.match(...tokens)
		matchM(matcher: Function, mode? = null): Token => @token <- @scanner.matchM(matcher, mode)
		matchNS(...tokens: Token): Token => @token <- @scanner.matchNS(...tokens)
		no(...expecteds: String): Event => Event( # {{{
			ok: false
			value: expecteds
		) # }}}
		position(): Range => @scanner.position()
		printDebug(prefix: String? = null): Void { # {{{
			if ?prefix {
				console.log(prefix, @scanner.toDebug())
			}
			else {
				console.log(@scanner.toDebug())
			}
		} # }}}
		relocate(event: Event, mut first: Event?, last: Event?): Event { # {{{
			if first != null {
				event.start = event.value.start = first.start
			}

			if last != null {
				event.end = event.value.end = last.end
			}

			return event
		} # }}}
		rollback(mark: Marker): Boolean { # {{{
			return @scanner.rollback(mark)
		} # }}}
		skipNewLine(): Void { # {{{
			if @scanner.skipNewLine() == -1 {
				@token = Token::EOF
			}
			else {
				@token = Token::INVALID
			}
		} # }}}
		test(token: Token): Boolean { # {{{
			if @scanner.test(token) {
				@token = token

				return true
			}
			else {
				return false
			}
		} # }}}
		test(...tokens: Token): Boolean => tokens.indexOf(@match(...tokens)) != -1
		testNS(...tokens: Token): Boolean => tokens.indexOf(@matchNS(...tokens)) != -1
		throw(): Never ~ SyntaxError { # {{{
			throw @error(`Unexpected \(@scanner.toQuote())`)
		} # }}}
		throw(expected: String): Never ~ SyntaxError { # {{{
			throw @error(`Expecting "\(expected)" but got \(@scanner.toQuote())`)
		} # }}}
		throw(...expecteds: String): Never ~ SyntaxError { # {{{
			throw @error(`Expecting "\(expecteds.slice(0, expecteds.length - 1).join('", "'))" or "\(expecteds[expecteds.length - 1])" but got \(@scanner.toQuote())`)
		} # }}}
		until(token): Boolean => !@scanner.test(token) && !@scanner.isEOF()
		value(): String | Array<String> => @scanner.value(@token!?)
		yep(): Event { # {{{
			var position = @scanner.position()

			return Event(
				ok: true
				start: position.start
				end: position.end
			)
		} # }}}
		yep(value): Event { # {{{
			return Event(
				ok: true
				value: value
				start: value.start
				end: value.end
			)
		} # }}}
		yep(value, first, last): Event { # {{{
			return Event(
				ok: true
				value: value
				start: first.start
				end: last.end
			)
		} # }}}
		yes(): Event { # {{{
			var position = @scanner.position()

			@commit()

			return Event(
				ok: true
				start: position.start
				end: position.end
			)
		} # }}}
		yes(value): Event { # {{{
			var start: Position = value.start ?? @scanner.startPosition()
			var end: Position = value.end ?? @scanner.endPosition()

			@commit()

			return Event(
				ok: true
				value: value
				start: start
				end: end
			)
		} # }}}
		yes(value, first): Event { # {{{
			var end: Position = value.end ?? @scanner.endPosition()

			@commit()

			return Event(
				ok: true
				value: value
				start: first.start
				end: end
			)
		} # }}}
		NL_0M() ~ SyntaxError { # {{{
			@skipNewLine()
		} # }}}
		altArrayComprehensionFor(expression: Event, mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var loop = @reqForExpression(@yes(), fMode)

			@NL_0M()

			unless @test(Token::RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ArrayComprehension(expression, loop, first, @yes()))
		} # }}}
		altArrayComprehensionRepeat(expression: Event, mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@commit().NL_0M()

			var condition = @reqExpression(ExpressionMode::Default, fMode)

			unless @test(Token::TIMES) {
				@throw('times')
			}

			var loop = @yep(AST.RepeatStatement(condition, null, first, @yes()))

			@NL_0M()

			unless @test(Token::RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ArrayComprehension(expression, loop, first, @yes()))
		} # }}}
		altArrayList(expression: Event, mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var values = [expression]

			do {
				if @match(Token::RIGHT_SQUARE, Token::COMMA, Token::NEWLINE) == Token::RIGHT_SQUARE {
					return @yep(AST.ArrayExpression(values, first, @yes()))
				}
				else if @token == Token::COMMA {
					@commit().NL_0M()

					values.push(@reqExpression(null, fMode, MacroTerminator::Array))
				}
				else if @token == Token::NEWLINE {
					@commit().NL_0M()

					if @match(Token::RIGHT_SQUARE, Token::COMMA) == Token::COMMA {
						@commit().NL_0M()

						values.push(@reqExpression(null, fMode, MacroTerminator::Array))
					}
					else if @token == Token::RIGHT_SQUARE {
						return @yep(AST.ArrayExpression(values, first, @yes()))
					}
					else {
						values.push(@reqExpression(null, fMode, MacroTerminator::Array))
					}
				}
				else {
					break
				}
			}
			while true

			@throw(']')
		} # }}}
		altForExpressionFrom(modifiers, variable: Event, mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var late from: Event
			if @token == Token::FROM_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind::Ballpark, @yes()))

				from = @reqExpression(ExpressionMode::Default, fMode)

				AST.pushModifier(from.value, modifier)
			}
			else {
				@commit()

				from = @reqExpression(ExpressionMode::Default, fMode)
			}

			@NL_0M()

			if @match(Token::DOWN, Token::UP) == Token::DOWN {
				modifiers.push(AST.Modifier(ModifierKind::Descending, @yes()))

				@NL_0M()
			}
			else if @token == Token::UP {
				modifiers.push(AST.Modifier(ModifierKind::Ascending, @yes()))

				@NL_0M()
			}

			var late to: Event
			if @match(Token::TO, Token::TO_TILDE) == Token::TO {
				@commit()

				to = @reqExpression(ExpressionMode::Default, fMode)
			}
			else if @token == Token::TO_TILDE {
				var modifier = @yep(AST.Modifier(ModifierKind::Ballpark, @yes()))

				to = @reqExpression(ExpressionMode::Default, fMode)

				AST.pushModifier(to.value, modifier)
			}
			else {
				@throw('to', 'to~')
			}

			@NL_0M()

			var mut step: Event? = null
			if @test(Token::STEP) {
				@commit()

				step = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}

			var mut until: Event? = null
			var mut while: Event? = null
			if @match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				@commit()

				until = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}
			else if @token == Token::WHILE {
				@commit()

				while = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}

			var mut when: Event? = null
			if @test(Token::WHEN) {
				var first = @yes()

				when = @relocate(@reqExpression(ExpressionMode::Default, fMode), first, null)
			}

			return @yep(AST.ForFromStatement(modifiers, variable, from, to, step, until, while, when, first, when ?? while ?? until ?? step ?? to))
		} # }}}
		altForExpressionIn(modifiers, value: Event, type: Event, index: Event, expression: Event, mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			var mut from: Event? = null
			if @match(Token::FROM, Token::FROM_TILDE) == Token::FROM {
				@commit()

				from = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}
			else if @token == Token::FROM_TILDE {
				modifier = @yep(AST.Modifier(ModifierKind::Ballpark, @yes()))

				from = @reqExpression(ExpressionMode::Default, fMode)

				AST.pushModifier(from.value, modifier)

				@NL_0M()
			}

			var mut order: Event? = null
			if @match(Token::DOWN, Token::UP) == Token::DOWN {
				order = @yes()

				modifiers.push(AST.Modifier(ModifierKind::Descending, order))

				@NL_0M()
			}
			else if @token == Token::UP {
				order = @yes()

				modifiers.push(AST.Modifier(ModifierKind::Ascending, order))

				@NL_0M()
			}

			var mut to: Event? = null
			if @match(Token::TO, Token::TO_TILDE) == Token::TO {
				@commit()

				to = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}
			else if @token == Token::TO_TILDE {
				modifier = @yep(AST.Modifier(ModifierKind::Ballpark, @yes()))

				to = @reqExpression(ExpressionMode::Default, fMode)

				AST.pushModifier(to.value, modifier)

				@NL_0M()
			}

			var mut step: Event? = null
			if @test(Token::STEP) {
				@commit()

				step = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}

			var mut split: Event? = null
			if @test(Token::SPLIT) {
				@commit()

				split = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}

			var mut until: Event? = null
			var mut while: Event? = null
			if @match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				@commit()

				until = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}
			else if @token == Token::WHILE {
				@commit()

				while = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}

			var mut when: Event? = null
			if @test(Token::WHEN) {
				var first = @yes()

				when = @relocate(@reqExpression(ExpressionMode::Default, fMode), first, null)
			}

			return @yep(AST.ForInStatement(modifiers, value, type, index, expression, from, to, step, split, until, while, when, first, when ?? while ?? until ?? split ?? step ?? to ?? order ?? from ?? expression))
		} # }}}
		altForExpressionInRange(modifiers, value: Event, type: Event, index: Event, mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var operand = @tryRangeOperand(ExpressionMode::Default, fMode)

			if operand.ok {
				if @test(Token::LEFT_ANGLE, Token::DOT_DOT) {
					if @token == Token::LEFT_ANGLE {
						AST.pushModifier(operand.value, @yep(AST.Modifier(ModifierKind::Ballpark, @yes())))

						unless @test(Token::DOT_DOT) {
							@throw('..')
						}

						@commit()
					}
					else {
						@commit()
					}

					var mut modifier: Event? = null
					if @test(Token::LEFT_ANGLE) {
						modifier = @yep(AST.Modifier(ModifierKind::Ballpark, @yes()))
					}

					var to = @reqPrefixedOperand(ExpressionMode::Default, fMode)

					if ?modifier {
						AST.pushModifier(to.value, modifier)
					}

					var mut step: Event? = null
					if @test(Token::DOT_DOT) {
						@commit()

						step = @reqPrefixedOperand(ExpressionMode::Default, fMode)
					}

					return @altForExpressionRange(modifiers, value, index, operand, to, step, first, fMode)
				}
				else {
					return @altForExpressionIn(modifiers, value, type, index, operand, first, fMode)
				}
			}
			else {
				return @altForExpressionIn(modifiers, value, type, index, @reqExpression(ExpressionMode::Default, fMode), first, fMode)
			}
		} # }}}
		altForExpressionOf(modifiers, value: Event, type: Event, key: Event, mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var expression = @reqExpression(ExpressionMode::Default, fMode)

			var dyn until, while
			if @match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				@commit()

				until = @reqExpression(ExpressionMode::Default, fMode)
			}
			else if @token == Token::WHILE {
				@commit()

				while = @reqExpression(ExpressionMode::Default, fMode)
			}

			@NL_0M()

			var dyn whenExp
			if @test(Token::WHEN) {
				var first = @yes()

				whenExp = @relocate(@reqExpression(ExpressionMode::Default, fMode), first, null)
			}

			return @yep(AST.ForOfStatement(modifiers, value, type, key, expression, until, while, whenExp, first, whenExp ?? while ?? until ?? expression))
		} # }}}
		altForExpressionRange(modifiers, value: Event, index: Event, from: Event, to: Event, filter: Event?, first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			var mut until: Event? = null
			var mut while: Event? = null
			if @match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				@commit()

				until = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}
			else if @token == Token::WHILE {
				@commit()

				while = @reqExpression(ExpressionMode::Default, fMode)

				@NL_0M()
			}

			var mut when: Event? = null
			if @test(Token::WHEN) {
				var first = @yes()

				when = @relocate(@reqExpression(ExpressionMode::Default, fMode), first, null)
			}

			return @yep(AST.ForRangeStatement(modifiers, value, index, from, to, filter, until, while, when, first, when ?? while ?? until ?? filter ?? to ?? from))
		} # }}}
		altRestrictiveExpression(expression: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var mark = @mark()

			if @test(Token::IF, Token::UNLESS) {
				var kind = @token == Token::IF ? RestrictiveOperatorKind::If : RestrictiveOperatorKind::Unless
				var operator = @yep(AST.RestrictiveOperator(kind, @yes()))
				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::EndOfLine, fMode)

				if @test(Token::NEWLINE) || @token == Token::EOF {
					return @yep(AST.RestrictiveExpression(operator, condition, expression, expression, condition))
				}
				else {
					@rollback(mark)
				}
			}

			return expression
		} # }}}
		altTypeContainer(mut type: Event, nullable: Boolean = true): Event ~ SyntaxError { # {{{
			var mut mark = @mark()

			while @testNS(Token::QUESTION, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
				if @token == Token::QUESTION {
					var modifier = @yep(AST.Modifier(ModifierKind::Nullable, @yes()))

					if !@testNS(Token::LEFT_CURLY, Token::LEFT_SQUARE) {
						@rollback(mark)

						break
					}

					AST.pushModifier(type.value, modifier)
				}

				if @token == Token::LEFT_CURLY {
					@commit()

					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					var property = @yep(AST.PropertyType([], null, type, type, type))

					type = @yep(AST.ObjectType([], [], property, property, @yes()))
				}
				else {
					@commit()

					unless @test(Token::RIGHT_SQUARE) {
						@throw(']')
					}

					var property = @yep(AST.PropertyType([], null, type, type, type))

					type = @yep(AST.ArrayType([], [], property, property, @yes()))
				}

				mark = @mark()
			}

			if nullable && @testNS(Token::QUESTION) {
				var modifier = @yep(AST.Modifier(ModifierKind::Nullable, @yes()))

				return @yep(AST.pushModifier(type.value, modifier))
			}
			else {
				return type
			}
		} # }}}
		isAmbiguousIdentifier(result: AmbiguityResult): Boolean ~ SyntaxError { # {{{
			if @test(Token::IDENTIFIER) {
				result.token = null
				result.identifier = @yep(AST.Identifier(@scanner.value(), @yes()))

				return true
			}
			else {
				return false
			}
		} # }}}
		isAmbiguousAccessModifierForEnum(modifiers: Array<Event>, result: AmbiguityResult): Boolean ~ SyntaxError { # {{{
			var late identifier
			var late token: Token

			if @test(Token::PRIVATE, Token::PUBLIC, Token::INTERNAL) {
				token = @token!?
				identifier = AST.Identifier(@scanner.value(), @yes())
			}
			else {
				return false
			}

			if @test(Token::EQUALS, Token::LEFT_ROUND) {
				result.token = @token
				result.identifier = @yep(identifier)

				return true
			}
			else {
				if token == Token::PRIVATE {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Private, identifier)))
				}
				else if token == Token::PUBLIC {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Public, identifier)))
				}
				else {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Internal, identifier)))
				}

				result.token = null
				result.identifier = @yep(identifier)

				return false
			}
		} # }}}
		isAmbiguousAsyncModifier(modifiers: Array<Event>, result: AmbiguityResult): Boolean ~ SyntaxError { # {{{
			unless @test(Token::ASYNC) {
				return false
			}

			var identifier = AST.Identifier(@scanner.value(), @yes())

			if @test(Token::IDENTIFIER) {
				modifiers.push(@yep(AST.Modifier(ModifierKind::Async, identifier)))

				result.token = @token
				result.identifier = @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				result.token = null
				result.identifier = @yep(identifier)
			}

			return true
		} # }}}
		isAmbiguousStaticModifier(modifiers: Array<Event>, result: AmbiguityResult): Boolean ~ SyntaxError { # {{{
			var late identifier

			if @test(Token::STATIC) {
				identifier = AST.Identifier(@scanner.value(), @yes())
			}
			else {
				return false
			}

			if @test(Token::EQUALS, Token::LEFT_ROUND) {
				result.token = @token
				result.identifier = @yep(identifier)

				return true
			}
			else {
				modifiers.push(@yep(AST.Modifier(ModifierKind::Static, identifier)))

				result.token = null
				result.identifier = @yep(identifier)

				return false
			}
		} # }}}
		parseModule() ~ SyntaxError { # {{{
			var attributes = []
			var body = []

			var dyn attrs = []
			var dyn statement

			if (statement = @tryShebang()).ok {
				body.push(statement.value)
			}

			@NL_0M()

			until @scanner.isEOF() {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				match @matchM(M.MODULE_STATEMENT) {
					Token::DISCLOSE {
						statement = @reqDiscloseStatement(@yes()).value
					}
					Token::EXPORT {
						statement = @reqExportStatement(@yes()).value
					}
					Token::EXTERN {
						statement = @reqExternStatement(@yes()).value
					}
					Token::EXTERN_IMPORT {
						statement = @reqExternOrImportStatement(@yes()).value
					}
					Token::EXTERN_REQUIRE {
						statement = @reqExternOrRequireStatement(@yes()).value
					}
					Token::INCLUDE {
						statement = @reqIncludeStatement(@yes()).value
					}
					Token::INCLUDE_AGAIN {
						statement = @reqIncludeAgainStatement(@yes()).value
					}
					Token::REQUIRE {
						statement = @reqRequireStatement(@yes()).value
					}
					Token::REQUIRE_EXTERN {
						statement = @reqRequireOrExternStatement(@yes()).value
					}
					Token::REQUIRE_IMPORT {
						statement = @reqRequireOrImportStatement(@yes()).value
					}
					else {
						statement = @reqStatement(FunctionMode::Function).value
					}
				}

				AST.pushAttributes(statement, attrs)

				body.push(statement)

				@NL_0M()
			}

			return AST.Module(attributes, body, this)
		} # }}}
		parseModuleType() ~ SyntaxError { # {{{
			@NL_0M()

			var types = []
			var attributes = []
			var mut attrs = []
			var mut type = NO

			until @scanner.isEOF() {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				var type = @reqTypeDescriptive(TypeMode::Module)

				@reqNL_EOF_1M()

				AST.pushAttributes(type.value, attrs)

				types.push(type)
			}

			return AST.TypeList(attributes, types, attributes[0] ?? types[0], types[types.length - 1])
		} # }}}
		parseStatements(mode: FunctionMode) ~ SyntaxError { # {{{
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

				var statement = @reqStatement(mode).value

				AST.pushAttributes(statement, attrs)

				body.push(statement)

				@NL_0M()
			}

			var last = @yep()

			unless @scanner.isEOF() {
				@throw('EOF')
			}

			return {
				attributes: [attribute.value for attribute in attributes]
				body
				start: first.start
				end: last.end
			}
		} # }}}
		reqAccessModifiers(modifiers: Array<Event>): Array<Event> ~ SyntaxError { # {{{
			if @match(Token::PRIVATE, Token::PROTECTED, Token::PUBLIC, Token::INTERNAL) == Token::PRIVATE {
				modifiers.push(@yep(AST.Modifier(ModifierKind::Private, @yes())))
			}
			else if @token == Token::PROTECTED {
				modifiers.push(@yep(AST.Modifier(ModifierKind::Protected, @yes())))
			}
			else if @token == Token::PUBLIC {
				modifiers.push(@yep(AST.Modifier(ModifierKind::Public, @yes())))
			}
			else if @token == Token::INTERNAL {
				modifiers.push(@yep(AST.Modifier(ModifierKind::Internal, @yes())))
			}

			return modifiers
		} # }}}
		reqArgumentList(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			if @test(Token::RIGHT_ROUND) {
				return @yep([])
			}
			else {
				var arguments = []

				while @until(Token::RIGHT_ROUND) {
					if @test(Token::BACKSLASH) {
						var first = @yes()

						if fMode == FunctionMode::Method && @test(Token::AT) {
							var alias = @reqThisExpression(@yes())

							arguments.push(@yep(AST.PositionalArgument(alias)))
						}
						else {
							var identifier = @reqIdentifier()

							arguments.push(@yep(AST.PositionalArgument(identifier)))
						}
					}
					else if @test(Token::COLON) {
						var first = @yes()

						var late expression

						if fMode == FunctionMode::Method && @test(Token::AT) {
							var alias = @reqThisExpression(@yes())

							expression = @yep(AST.NamedArgument(@yep(alias.value.name), alias, first, alias))
						}
						else {
							var identifier = @reqIdentifier()

							expression = @yep(AST.NamedArgument(identifier, identifier, first, identifier))
						}

						arguments.push(@altRestrictiveExpression(expression, fMode))
					}
					else {
						var argument = @reqExpression(ExpressionMode::ImplicitMember, fMode, MacroTerminator::List)

						if argument.value.kind == NodeKind::Identifier {
							if @test(Token::COLON) {
								@commit()

								var value = @reqExpression(ExpressionMode::ImplicitMember, fMode, MacroTerminator::List)
								var expression = @yep(AST.NamedArgument(argument, value))

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

					if @match(Token::COMMA, Token::NEWLINE) == Token::COMMA || @token == Token::NEWLINE {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				@throw(')') unless @test(Token::RIGHT_ROUND)

				return @yep(arguments)
			}
		} # }}}
		reqArray(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @test(Token::RIGHT_SQUARE) {
				return @yep(AST.ArrayExpression([], first, @yes()))
			}

			var mark = @mark()

			var dyn operand = @tryRangeOperand(ExpressionMode::Default, fMode)

			if operand.ok && (@match(Token::LEFT_ANGLE, Token::DOT_DOT) == Token::LEFT_ANGLE || @token == Token::DOT_DOT) {
				var then = @token == Token::LEFT_ANGLE
				if then {
					@commit()

					unless @test(Token::DOT_DOT) {
						@throw('..')
					}

					@commit()
				}
				else {
					@commit()
				}

				var til = @test(Token::LEFT_ANGLE)
				if til {
					@commit()
				}

				var toOperand = @reqPrefixedOperand(ExpressionMode::Default, fMode)

				var dyn byOperand
				if @test(Token::DOT_DOT) {
					@commit()

					byOperand = @reqPrefixedOperand(ExpressionMode::Default, fMode)
				}

				unless @test(Token::RIGHT_SQUARE) {
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

				if @test(Token::RIGHT_SQUARE) {
					return @yep(AST.ArrayExpression([], first, @yes()))
				}

				var expression = @reqExpression(null, fMode, MacroTerminator::Array)

				if @match(Token::RIGHT_SQUARE, Token::FOR, Token::NEWLINE, Token::REPEAT) == Token::RIGHT_SQUARE {
					return @yep(AST.ArrayExpression([expression], first, @yes()))
				}
				else if @token == Token::FOR {
					return @altArrayComprehensionFor(expression, first, fMode)
				}
				else if @token == Token::NEWLINE {
					var mark = @mark()

					@commit().NL_0M()

					if @match(Token::RIGHT_SQUARE, Token::FOR, Token::REPEAT) == Token::RIGHT_SQUARE {
						return @yep(AST.ArrayExpression([expression], first, @yes()))
					}
					else if @token == Token::FOR {
						return @altArrayComprehensionFor(expression, first, fMode)
					}
					else if @token == Token::REPEAT {
						return @altArrayComprehensionRepeat(expression, first, fMode)
					}
					else {
						@rollback(mark)

						return @altArrayList(expression, first, fMode)
					}
				}
				else if @token == Token::REPEAT {
					return @altArrayComprehensionRepeat(expression, first, fMode)
				}
				else {
					return @altArrayList(expression, first, fMode)
				}
			}
		} # }}}
		reqAttribute(mut first: Event, isStatement: Boolean): Event ~ SyntaxError { # {{{
			var declaration = @reqAttributeMember()

			unless @test(Token::RIGHT_SQUARE) {
				@throw(']')
			}

			var last = @yes()

			if isStatement {
				unless @test(Token::NEWLINE) {
					@throw('NewLine')
				}

				@commit()
			}

			@scanner.skipComments()

			return @yep(AST.AttributeDeclaration(declaration, first, last))
		} # }}}
		reqAttributeIdentifier(): Event ~ SyntaxError { # {{{
			if @scanner.test(Token::ATTRIBUTE_IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				@throw('Identifier')
			}
		} # }}}
		reqAttributeMember(): Event ~ SyntaxError { # {{{
			var identifier = @reqAttributeIdentifier()

			if @match(Token::EQUALS, Token::LEFT_ROUND) == Token::EQUALS {
				@commit()

				var value = @reqString()

				return @yep(AST.AttributeOperation(identifier, value, identifier, value))
			}
			else if @token == Token::LEFT_ROUND {
				@commit()

				var arguments = [@reqAttributeMember()]

				while @test(Token::COMMA) {
					@commit()

					arguments.push(@reqAttributeMember())
				}

				if !@test(Token::RIGHT_ROUND) {
					@throw(')')
				}

				return @yep(AST.AttributeExpression(identifier, arguments, identifier, @yes()))
			}
			else {
				return identifier
			}
		} # }}}
		reqAwaitExpression(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)

			return @yep(AST.AwaitExpression([], null, operand, first, operand))
		} # }}}
		reqBinaryOperand(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var mark = @mark()

			var dyn expression
			if (expression = @tryAwaitExpression(eMode, fMode)).ok {
				return expression
			}
			else if @rollback(mark) && (expression = @tryFunctionExpression(eMode, fMode)).ok {
				return expression
			}
			else if @rollback(mark) && (expression = @tryIfExpression(eMode, fMode)).ok {
				return expression
			}
			else if @rollback(mark) && (expression = @tryMatchExpression(eMode, fMode)).ok {
				return expression
			}
			else if @rollback(mark) && (expression = @tryTryExpression(eMode, fMode)).ok {
				return expression
			}

			@rollback(mark)

			return @reqPrefixedOperand(eMode, fMode)
		} # }}}
		reqBitmaskStatement(mut first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()
			unless name.ok {
				return NO
			}

			var mut type = null

			if @test(Token::LEFT_ANGLE) {
				@commit()

				var identifier = @tryIdentifier()

				if identifier.ok {
					unless identifier.value.name == 'u8' | 'u16' | 'u32' | 'u48' | 'u64' | 'u128' | 'u256' {
						@throw('u8', 'u16', 'u32', 'u48', 'u64', 'u128', 'u256')
					}

					type = identifier
				}

				unless @test(Token::RIGHT_ANGLE) {
					@throw('>')
				}

				@commit()
			}

			@NL_0M()

			unless @test(Token::LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var attributes = []
			var members = []

			while @until(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					pass
				}
				else {
					@reqEnumMember(members)
				}
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.BitmaskDeclaration(attributes, modifiers, name, type, members, first, @yes()))
		} # }}}
		reqBlock(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if !first.ok {
				unless @test(Token::LEFT_CURLY) {
					@throw('{')
				}

				first = @yes()
			}

			@NL_0M()

			var attributes = []
			var statements = []

			var dyn attrs = []
			var dyn statement
			while @match(Token::RIGHT_CURLY, Token::HASH_EXCLAMATION_LEFT_SQUARE, Token::HASH_LEFT_SQUARE) != Token::EOF && @token != Token::RIGHT_CURLY {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				statement = @reqStatement(fMode)

				AST.pushAttributes(statement.value, attrs)

				statements.push(statement)

				@NL_0M()
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.Block(attributes, statements, first, @yes()))
		} # }}}
		reqBreakStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @match(Token::IF, Token::UNLESS) == Token::IF {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.IfStatement(condition, null, @yep(AST.BreakStatement(null, first, first)), null, first, condition))
				}
				else {
					return @yep(AST.BreakStatement(label, first, label))
				}
			}
			else if @token == Token::UNLESS {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

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
					if @match(Token::IF, Token::UNLESS) == Token::IF {
						@commit()

						var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

						return @yep(AST.IfStatement(condition, null, @yep(AST.BreakStatement(label, first, label)), null, first, condition))
					}
					else if @token == Token::UNLESS {
						@commit()

						var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

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
		reqCatchOnClause(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var type = @reqIdentifier()

			var dyn binding
			if @test(Token::CATCH) {
				@commit()

				binding = @reqIdentifier()
			}

			@NL_0M()

			var body = @reqBlock(NO, fMode)

			return @yep(AST.CatchClause(binding, type, body, first, body))
		} # }}}
		reqClassMember(attributes, modifiers, mut bits: ClassBits, mut first: Event?): Event ~ SyntaxError { # {{{
			var member = @tryClassMember(attributes, modifiers, bits, first)

			unless member.ok {
				@throw('Identifier', 'String', 'Template')
			}

			return member
		} # }}}
		reqClassMemberBlock(attributes, modifiers, mut bits: ClassBits, members: Array<Event>): Void ~ SyntaxError { # {{{
			@commit().NL_0M()

			var dyn attrs = [...attributes]

			bits += ClassBits::Attribute

			while @until(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attrs) {
					continue
				}

				members.push(@reqClassMember(attrs, modifiers, bits, null))
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			@commit().reqNL_1M()
		} # }}}
		reqClassMemberList(members: Array<Event>): Void ~ SyntaxError { # {{{
			var dyn first = null

			var attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			var macroMark = @mark()

			if @test(Token::MACRO) {
				var second = @yes()

				if @test(Token::LEFT_CURLY) {
					@commit().NL_0M()

					while @until(Token::RIGHT_CURLY) {
						members.push(@reqMacroStatement(attributes))
					}

					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					@commit().reqNL_1M()

					return
				}
				else if (identifier = @tryIdentifier()).ok {
					members.push(@reqMacroStatement(attributes, identifier, first ?? second))

					return
				}

				@rollback(macroMark)
			}

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier()

			if accessModifier.ok && @test(Token::LEFT_CURLY) {
				return @reqClassMemberBlock(
					attributes
					[accessModifier]
					ClassBits::Variable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method + ClassBits::OverrideMethod + ClassBits::Proxy
					members
				)
			}

			if @test(Token::ABSTRACT) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(ModifierKind::Abstract, @yes()))

				if @test(Token::LEFT_CURLY) {
					var modifiers = [modifier]
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					return @reqClassMemberBlock(
						attributes
						modifiers
						ClassBits::Method + ClassBits::Property + ClassBits::NoBody
						members
					)
				}

				@rollback(mark)
			}
			else if @test(Token::OVERRIDE) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(ModifierKind::Override, @yes()))

				if @test(Token::LEFT_CURLY) {
					var modifiers = [modifier]
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					return @reqClassMemberBlock(
						attributes
						modifiers
						ClassBits::Method + ClassBits::Property
						members
					)
				}

				@rollback(mark)
			}

			var staticMark = @mark()
			var dyn staticModifier = NO

			if @test(Token::STATIC) {
				staticModifier = @yep(AST.Modifier(ModifierKind::Static, @yes()))

				var modifiers = [staticModifier]
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(Token::LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						ClassBits::Variable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method + ClassBits::FinalMethod + ClassBits::Proxy
						members
					)
				}
				else if @test(Token::PROXY) {
					var mark = @mark()

					@commit()

					if @test(Token::LEFT_CURLY) {
						return @reqClassProxyBlock(
							attributes
							modifiers
							members
						)
					}
					else if @test(Token::AT) {
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
			else if @test(Token::PROXY) {
				var mark = @mark()
				var first = @yes()

				var modifiers = []
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(Token::LEFT_CURLY) {
					return @reqClassProxyBlock(
						attributes
						modifiers
						members
					)
				}
				else if @test(Token::AT) {
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
						accessModifier[0] ?? first
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

			if @test(Token::FINAL) {
				finalModifier = @yep(AST.Modifier(ModifierKind::Immutable, @yes()))

				if @test(Token::LEFT_CURLY) {
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
							ClassBits::Variable + ClassBits::LateVariable + ClassBits::RequiredAssignment + ClassBits::Property + ClassBits::Method
							members
						)
					}
					else {
						return @reqClassMemberBlock(
							attributes
							modifiers
							ClassBits::Variable + ClassBits::LateVariable + ClassBits::RequiredAssignment + ClassBits::Property + ClassBits::OverrideProperty + ClassBits::Method + ClassBits::OverrideMethod
							members
						)
					}
				}
				else if !staticModifier.ok && @test(Token::OVERRIDE) {
					var mark = @mark()
					var modifier = @yep(AST.Modifier(ModifierKind::Override, @yes()))

					if @test(Token::LEFT_CURLY) {
						var modifiers = [finalModifier, modifier]
						if accessModifier.ok {
							modifiers.unshift(accessModifier)
						}

						return @reqClassMemberBlock(
							attributes
							modifiers
							ClassBits::Method + ClassBits::Property
							members
						)
					}

					@rollback(mark)
				}
			}

			if @test(Token::LATE) {
				var lateMark = @mark()
				var lateModifier = @yep(AST.Modifier(ModifierKind::LateInit, @yes()))

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

				if @test(Token::LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						finalModifier.ok ? ClassBits::Variable : ClassBits::Variable + ClassBits::FinalVariable
						members
					)
				}

				var member = @tryClassMember(
					attributes
					modifiers
					ClassBits::Variable + ClassBits::NoAssignment
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
		reqClassMethod(attributes, modifiers, mut bits: ClassBits, name: Event, round: Event?, mut first: Event): Event ~ SyntaxError { # {{{
			var parameters = @reqClassMethodParameterList(round, bits ~~ ClassBits::NoBody ? DestructuringMode::EXTERNAL_ONLY : null)

			var type = @tryMethodReturns(bits !~ ClassBits::NoBody)
			var throws = @tryFunctionThrows()

			if bits ~~ ClassBits::NoBody {
				@reqNL_1M()

				return @yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, null, first, throws ?? type ?? parameters))
			}
			else {
				var body = @tryFunctionBody(FunctionMode::Method)

				@reqNL_1M()

				return @yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, body, first, body ?? throws ?? type ?? parameters))
			}
		} # }}}
		reqClassMethodParameterList(mut top: Event = NO, mut pMode: DestructuringMode = DestructuringMode::Nil): Event ~ SyntaxError { # {{{
			if !top.ok {
				unless @test(Token::LEFT_ROUND) {
					@throw('(')
				}

				top = @yes()
			}

			var parameters = []

			@NL_0M()

			pMode += DestructuringMode::Parameter + DestructuringMode::THIS_ALIAS

			while @until(Token::RIGHT_ROUND) {
				parameters.push(@reqParameter(pMode, FunctionMode::Method))

				@reqSeparator(Token::RIGHT_ROUND)
			}

			unless @test(Token::RIGHT_ROUND) {
				@throw(')')
			}

			return @yep(parameters, top, @yes())
		} # }}}
		reqClassProperty(attributes, modifiers, name: Event, type: Event?, mut first: Event): Event ~ SyntaxError { # {{{
			var dyn defaultValue, accessor, mutator

			if @test(Token::NEWLINE) {
				@commit().NL_0M()

				if @match(Token::GET, Token::SET) == Token::GET {
					var first = @yes()

					if @match(Token::EQUALS_RIGHT_ANGLE, Token::LEFT_CURLY) == Token::EQUALS_RIGHT_ANGLE {
						@commit()

						var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Method)

						accessor = @yep(AST.AccessorDeclaration(expression, first, expression))
					}
					else if @token == Token::LEFT_CURLY {
						var block = @reqBlock(NO, FunctionMode::Method)

						accessor = @yep(AST.AccessorDeclaration(block, first, block))
					}
					else {
						accessor = @yep(AST.AccessorDeclaration(first))
					}

					@reqNL_1M()

					if @test(Token::SET) {
						var first = @yes()

						if @match(Token::EQUALS_RIGHT_ANGLE, Token::LEFT_CURLY) == Token::EQUALS_RIGHT_ANGLE {
							@commit()

							var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Method)

							mutator = @yep(AST.MutatorDeclaration(expression, first, expression))
						}
						else if @token == Token::LEFT_CURLY {
							var block = @reqBlock(NO, FunctionMode::Method)

							mutator = @yep(AST.MutatorDeclaration(block, first, block))
						}
						else {
							mutator = @yep(AST.MutatorDeclaration(first))
						}

						@reqNL_1M()
					}
				}
				else if @token == Token::SET {
					var first = @yes()

					if @match(Token::EQUALS_RIGHT_ANGLE, Token::LEFT_CURLY) == Token::EQUALS_RIGHT_ANGLE {
						@commit()

						var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Method)

						mutator = @yep(AST.MutatorDeclaration(expression, first, expression))
					}
					else if @token == Token::LEFT_CURLY {
						var block = @reqBlock(NO, FunctionMode::Method)

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
				if @match(Token::GET, Token::SET) == Token::GET {
					accessor = @yep(AST.AccessorDeclaration(@yes()))

					if @test(Token::COMMA) {
						@commit()

						if @test(Token::SET) {
							mutator = @yep(AST.MutatorDeclaration(@yes()))
						}
						else {
							@throw('set')
						}
					}
				}
				else if @token == Token::SET {
					mutator = @yep(AST.MutatorDeclaration(@yes()))
				}
				else {
					@throw('get', 'set')
				}
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			var dyn last = @yes()

			if @test(Token::EQUALS) {
				@commit()

				defaultValue = @reqExpression(ExpressionMode::Default, FunctionMode::Method)
			}

			@reqNL_1M()

			return @yep(AST.PropertyDeclaration(attributes, modifiers, name, type, defaultValue, accessor, mutator, first, defaultValue ?? last))
		} # }}}
		reqClassProxy(attributes, modifiers, mut first: Event?): Event ~ SyntaxError { # {{{
			var member = @tryClassProxy(attributes, modifiers, first)

			unless member.ok {
				@throw('Identifier')
			}

			return member
		} # }}}
		reqClassProxyBlock(attributes, modifiers, members: Array<Event>): Void ~ SyntaxError { # {{{
			@commit().NL_0M()

			var dyn attrs = [...attributes]

			while @until(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attrs) {
					continue
				}

				members.push(@reqClassProxy(attrs, modifiers, null))
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			@commit().reqNL_1M()
		} # }}}
		reqClassProxyGroup(attributes, modifiers, members: Array<Event>, first: Event): Void ~ SyntaxError { # {{{
			var recipient = @reqExpression(ExpressionMode::Default, FunctionMode::Method)

			@throw('{') unless @test(Token::LEFT_CURLY)

			@commit().reqNL_1M()

			var dyn attrs = [...attributes]
			var elements = []

			while @until(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attrs) {
					continue
				}

				var external = @reqIdentifier()
				var mut internal = external

				if @test(Token::EQUALS_RIGHT_ANGLE) {
					@commit()

					internal = @reqIdentifier()
				}

				@reqNL_1M()

				elements.push(@yep(AST.ProxyDeclaration(attrs, modifiers, internal, external, external, internal)))
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			members.push(@yep(AST.ProxyGroupDeclaration(attrs, modifiers, recipient, elements, first, @yes())))

			@reqNL_1M()
		} # }}}
		reqClassStatement(mut first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			return @reqClassStatementBody(@reqIdentifier(), first, modifiers)
		} # }}}
		reqClassStatementBody(name: Event, mut first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			var dyn generic
			if @test(Token::LEFT_ANGLE) {
				generic = @reqTypeGeneric(@yes())
			}

			var dyn version
			if @test(Token::AT) {
				@commit()

				unless @test(Token::CLASS_VERSION) {
					@throw('Class Version')
				}

				var data = @value()

				version = @yes({
					major: data[0]
					minor: data.length > 1 ? data[1] : 0
					patch: data.length > 2 ? data[2] : 0
				})
				version.value.start = version.start
				version.value.end = version.end
			}

			var dyn extends
			if @test(Token::EXTENDS) {
				@commit()

				extends = @reqIdentifier()

				if @testNS(Token::DOT) {
					var dyn property

					do {
						@commit()

						property = @reqIdentifier()

						extends = @yep(AST.MemberExpression([], extends, property))
					}
					while @testNS(Token::DOT)
				}
			}

			unless @test(Token::LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var attributes = []
			var members = []

			while @until(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@reqClassMemberList(members)
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.ClassDeclaration(attributes, name, version, extends, modifiers, members, first, @yes()))
		} # }}}
		reqClassVariable(attributes, modifiers, mut bits: ClassBits, name: Event?, mut first: Event?): Event ~ SyntaxError { # {{{
			var variable = @tryClassVariable(attributes, modifiers, bits, name, null, first)

			unless variable.ok {
				@throw('Identifier', 'String', 'Template')
			}

			return variable
		} # }}}
		reqComputedPropertyName(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var expression = @reqExpression(ExpressionMode::Default, fMode)

			unless @test(Token::RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ComputedPropertyName(expression, first, @yes()))
		} # }}}
		reqConditionAssignment(): Event ~ SyntaxError { # {{{
			if @test(Token::QUESTION_EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Existential, @yes()))
			}
			else if @test(Token::HASH_EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind::NonEmpty, @yes()))
			}

			@throw('?=', '#=')
		} # }}}
		reqContinueStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @match(Token::IF, Token::UNLESS) == Token::IF {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				if condition.ok {
					return @yep(AST.IfStatement(condition, null, @yep(AST.ContinueStatement(null, first, first)), null, first, condition))
				}
				else {
					return @yep(AST.ContinueStatement(label, first, label))
				}
			}
			else if @token == Token::UNLESS {
				var label = @yep(AST.Identifier(@scanner.value(), @yes()))

				var condition = @tryExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

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
					if @match(Token::IF, Token::UNLESS) == Token::IF {
						@commit()

						var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

						return @yep(AST.IfStatement(condition, null, @yep(AST.ContinueStatement(label, first, label)), null, first, condition))
					}
					else if @token == Token::UNLESS {
						@commit()

						var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

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
		reqDestructuringArray(mut first: Event, dMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			var elements = []

			while @until(Token::RIGHT_SQUARE) {
				elements.push(@reqDestructuringArrayItem(dMode, fMode))

				var separator = @trySeparator(Token::RIGHT_SQUARE)

				unless separator.ok {
					break
				}
			}

			unless @test(Token::RIGHT_SQUARE) {
				@throw(']')
			}

			return @yep(AST.ArrayBinding(elements, first, @yes()))
		} # }}}
		reqDestructuringArrayItem(dMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var modifiers = []
			var dyn first = null
			var dyn name = null
			var dyn type = null
			var dyn notThis = true

			if @test(Token::DOT_DOT_DOT) {
				modifiers.push(AST.Modifier(ModifierKind::Rest, first <- @yes()))

				if dMode ~~ DestructuringMode::THIS_ALIAS && @test(Token::AT) {
					name = @reqThisExpression(@yes())
					notThis = false
				}
				else if @test(Token::IDENTIFIER) {
					name = @yep(AST.Identifier(@scanner.value(), @yes()))
				}
			}
			else if dMode ~~ DestructuringMode::RECURSION && @test(Token::LEFT_CURLY) {
				name = @reqDestructuringObject(@yes(), dMode, fMode)
			}
			else if dMode ~~ DestructuringMode::RECURSION && @test(Token::LEFT_SQUARE) {
				name = @reqDestructuringArray(@yes(), dMode, fMode)
			}
			else if dMode ~~ DestructuringMode::THIS_ALIAS && @test(Token::AT) {
				name = @reqThisExpression(@yes())
				notThis = false
			}
			else if @test(Token::IDENTIFIER) {
				name = @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else if @test(Token::UNDERSCORE) {
				first = @yes()
			}
			else {
				if dMode ~~ DestructuringMode::RECURSION {
					@throw('...', '_', '[', '{', 'Identifier')
				}
				else {
					@throw('...', '_', 'Identifier')
				}
			}

			if notThis && dMode ~~ DestructuringMode::TYPE && @test(Token::COLON) {
				@commit()

				type = @reqType()
			}

			if name != null {
				var dyn defaultValue = null

				if dMode ~~ DestructuringMode::DEFAULT && @test(Token::EQUALS) {
					@commit()

					defaultValue = @reqExpression(ExpressionMode::Default, fMode)
				}

				return @yep(AST.ArrayBindingElement(modifiers, name, type, defaultValue, first ?? name, defaultValue ?? type ?? name))
			}
			else {
				return @yep(AST.ArrayBindingElement(modifiers, null, type, null, first ?? type ?? @yep(), type ?? first ?? @yep()))
			}
		} # }}}
		reqDestructuringObject(mut first: Event, dMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			var elements = []

			do {
				elements.push(@reqDestructuringObjectItem(dMode, fMode))

				@reqSeparator(Token::RIGHT_CURLY)
			}
			while @until(Token::RIGHT_CURLY)

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.ObjectBinding(elements, first, @yes()))
		} # }}}
		reqDestructuringObjectItem(dMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var dyn first
			var modifiers = []
			var dyn name = null
			var dyn alias = null
			var dyn defaultValue = null
			var dyn notThis = true

			if @test(Token::DOT_DOT_DOT) {
				modifiers.push(AST.Modifier(ModifierKind::Rest, first <- @yes()))

				if dMode ~~ DestructuringMode::THIS_ALIAS && @test(Token::AT) {
					name = @reqThisExpression(@yes())
					notThis = false
				}
				else {
					name = @reqIdentifier()
				}
			}
			else {
				if dMode ~~ DestructuringMode::COMPUTED && @test(Token::LEFT_SQUARE) {
					first = @yes()

					if dMode ~~ DestructuringMode::THIS_ALIAS && @test(Token::AT) {
						name = @reqThisExpression(@yes())
						notThis = false
					}
					else {
						name = @reqIdentifier()
					}

					unless @test(Token::RIGHT_SQUARE) {
						@throw(']')
					}

					modifiers.push(AST.Modifier(ModifierKind::Computed, first, @yes()))
				}
				else {
					if dMode ~~ DestructuringMode::THIS_ALIAS && @test(Token::AT) {
						name = @reqThisExpression(@yes())
						notThis = false
					}
					else {
						name = @reqIdentifier()
					}
				}

				if notThis && @test(Token::COLON) {
					@commit()

					if dMode ~~ DestructuringMode::RECURSION && @test(Token::LEFT_CURLY) {
						alias = @reqDestructuringObject(@yes(), dMode, fMode)
					}
					else if dMode ~~ DestructuringMode::RECURSION && @test(Token::LEFT_SQUARE) {
						alias = @reqDestructuringArray(@yes(), dMode, fMode)
					}
					else if dMode ~~ DestructuringMode::THIS_ALIAS && @test(Token::AT) {
						alias = @reqThisExpression(@yes())
					}
					else {
						alias = @reqIdentifier()
					}
				}
			}

			if dMode ~~ DestructuringMode::DEFAULT && @test(Token::EQUALS) {
				@commit()

				defaultValue = @reqExpression(ExpressionMode::Default, fMode)
			}

			return @yep(AST.ObjectBindingElement(modifiers, name, alias, defaultValue, first ?? name, defaultValue ?? alias ?? name))
		} # }}}
		reqDiscloseStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var name = @reqIdentifier()

			unless @test(Token::LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var members = []

			while @until(Token::RIGHT_CURLY) {
				@reqExternClassMemberList(members)
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.DiscloseDeclaration(name, members, first, @yes()))
		} # }}}
		reqDoStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			var body = @reqBlock(NO, fMode)

			@reqNL_1M()

			if @match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default, fMode)

				return @yep(AST.DoUntilStatement(condition, body, first, condition))
			}
			else if @token == Token::WHILE {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default, fMode)

				return @yep(AST.DoWhileStatement(condition, body, first, condition))
			}
			else {
				@throw('until', 'while')
			}
		} # }}}
		reqEnumMember(members: Array): Void ~ SyntaxError { # {{{
			var attributes = @stackOuterAttributes([])
			var modifiers = []
			var result = AmbiguityResult()

			if @isAmbiguousAccessModifierForEnum(modifiers, result) {
				@submitEnumMember(attributes, modifiers, result.identifier!?, result.token, members)
			}
			else if @isAmbiguousStaticModifier(modifiers, result) {
				@submitEnumMember(attributes, modifiers, result.identifier!?, result.token, members)
			}
			else if @isAmbiguousAsyncModifier(modifiers, result) {
				var {identifier, token} = result

				var first = attributes[0] ?? modifiers[0] ?? identifier

				if token == Token::IDENTIFIER {
					members.push(@reqEnumMethod(attributes, modifiers, identifier!?, first).value)
				}
				else {
					@submitEnumMember(attributes, modifiers, identifier!?, null, members)
				}
			}
			else if @isAmbiguousIdentifier(result) {
				@submitEnumMember(attributes, modifiers, result.identifier!?, null, members)
			}
			else {
				var mark = @mark()

				@NL_0M()

				if @test(Token::LEFT_CURLY) {
					@commit().NL_0M()

					var dyn attrs

					while @until(Token::RIGHT_CURLY) {
						attrs = @stackOuterAttributes([])

						if attrs.length != 0 {
							attrs.unshift(...attributes)
						}
						else {
							attrs = attributes
						}

						members.push(@reqEnumMethod(attrs, modifiers, attrs[0]).value)
					}

					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					@commit().reqNL_1M()
				}
				else {
					@rollback(mark)

					@submitEnumMember(attributes, [], result.identifier!?, null, members)
				}
			}
		} # }}}
		reqEnumMethod(attributes, mut modifiers, mut first: Event?): Event ~ SyntaxError { # {{{
			var dyn name
			if @test(Token::ASYNC) {
				var dyn async = @reqIdentifier()

				name = @tryIdentifier()

				if name.ok {
					modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind::Async, async))]
				}
				else {
					name = async
				}
			}
			else {
				name = @reqIdentifier()
			}

			return @reqEnumMethod(attributes, modifiers, name, first ?? name)
		} # }}}
		reqEnumMethod(attributes, modifiers, name: Event, first): Event ~ SyntaxError { # {{{
			var parameters = @reqFunctionParameterList(FunctionMode::Function)

			var type = @tryFunctionReturns()
			var throws = @tryFunctionThrows()

			var body = @mode ~~ ParserMode::Typing ? null : @reqFunctionBody(FunctionMode::Method)

			@reqNL_1M()

			return @yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, body, first, body ?? throws ?? type ?? parameters))

		} # }}}
		reqEnumStatement(mut first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()
			unless name.ok {
				return NO
			}

			var dyn type
			if @test(Token::LEFT_ANGLE) {
				@commit()

				type = @reqTypeEntity()

				unless @test(Token::RIGHT_ANGLE) {
					@throw('>')
				}

				@commit()
			}

			@NL_0M()

			unless @test(Token::LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var attributes = []
			var members = []

			while @until(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					pass
				}
				else {
					@reqEnumMember(members)
				}
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.EnumDeclaration(attributes, modifiers, name, type, members, first, @yes()))
		} # }}}
		reqExportDeclarator(): Event ~ SyntaxError { # {{{
			match @matchM(M.EXPORT_STATEMENT) {
				Token::ABSTRACT {
					var first = @yes()

					if @test(Token::CLASS) {
						@commit()

						var modifiers = [@yep(AST.Modifier(ModifierKind::Abstract, first))]

						return @yep(AST.DeclarationSpecifier(@reqClassStatement(first, modifiers)))
					}
					else {
						@throw('class')
					}
				}
				Token::ASYNC {
					var first = @reqIdentifier()

					if @test(Token::FUNC) {
						@commit()

						var modifiers = [@yep(AST.Modifier(ModifierKind::Async, first))]

						return @yep(AST.DeclarationSpecifier(@reqFunctionStatement(first, modifiers)))
					}
					else {
						return @reqExportIdentifier(first)
					}
				}
				Token::BITMASK {
					return @yep(AST.DeclarationSpecifier(@reqBitmaskStatement(@yes())))
				}
				Token::CLASS {
					return @yep(AST.DeclarationSpecifier(@reqClassStatement(@yes())))
				}
				Token::ENUM {
					return @yep(AST.DeclarationSpecifier(@reqEnumStatement(@yes())))
				}
				Token::FINAL {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(ModifierKind::Immutable, first))]

					if @test(Token::CLASS) {
						@commit()

						return @yep(AST.DeclarationSpecifier(@reqClassStatement(first, modifiers)))
					}
					else if @test(Token::ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(ModifierKind::Abstract, @yes())))

						if @test(Token::CLASS) {
							@commit()

							return @yep(AST.DeclarationSpecifier(@reqClassStatement(first, modifiers)))
						}
						else {
							@throw('class')
						}
					}
					else {
						@throw('class')
					}
				}
				Token::FUNC {
					return @yep(AST.DeclarationSpecifier(@reqFunctionStatement(@yes())))
				}
				Token::IDENTIFIER {
					return @reqExportIdentifier(@reqIdentifier())
				}
				Token::MACRO {
					if @mode !~ ParserMode::MacroExpression {
						return @yep(AST.DeclarationSpecifier(@tryMacroStatement(@yes())))
					}
					else {
						return @yep(AST.DeclarationSpecifier(@reqMacroExpression(@yes())))
					}
				}
				Token::NAMESPACE {
					return @yep(AST.DeclarationSpecifier(@tryNamespaceStatement(@yes())))
				}
				Token::SEALED {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(ModifierKind::Sealed, first))]

					if @test(Token::CLASS) {
						@commit()

						return @yep(AST.DeclarationSpecifier(@reqClassStatement(first, modifiers)))
					}
					else if @test(Token::ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(ModifierKind::Abstract, @yes())))

						if @test(Token::CLASS) {
							@commit()

							return @yep(AST.DeclarationSpecifier(@reqClassStatement(first, modifiers)))
						}
						else {
							@throw('class')
						}
					}
					else {
						@throw('class')
					}
				}
				Token::STRUCT {
					return @yep(AST.DeclarationSpecifier(@reqStructStatement(@yes())))
				}
				Token::TUPLE {
					return @yep(AST.DeclarationSpecifier(@reqTupleStatement(@yes())))
				}
				Token::TYPE {
					return @yep(AST.DeclarationSpecifier(@reqTypeStatement(@yes(), @reqIdentifier())))
				}
				Token::VAR {
					return @yep(AST.DeclarationSpecifier(@reqVarStatement(@yes(), ExpressionMode::NoAwait, FunctionMode::Function)))
				}
				else {
					@throw()
				}
			}
		} # }}}
		reqExportIdentifier(mut value: Event): Event ~ SyntaxError { # {{{
			var dyn identifier = null

			if @testNS(Token::DOT) {
				do {
					@commit()

					if @testNS(Token::ASTERISK) {
						var modifier = @yep(AST.Modifier(ModifierKind::Wildcard, @yes()))

						return @yep(AST.NamedSpecifier([modifier], value, null, value, modifier))
					}
					else {
						identifier = @reqIdentifier()

						value = @yep(AST.MemberExpression([], value, identifier))
					}
				}
				while @testNS(Token::DOT)
			}

			if @test(Token::EQUALS_RIGHT_ANGLE) {
				@commit()

				var external = @reqIdentifier()

				return @yep(AST.NamedSpecifier([], value, external, value, external))
			}
			else if @test(Token::FOR) {
				@commit()

				if @test(Token::ASTERISK) {
					var modifier = @yep(AST.Modifier(ModifierKind::Wildcard, @yes()))

					return @yep(AST.NamedSpecifier([modifier], value, null, value, modifier))
				}
				else if @test(Token::LEFT_CURLY) {
					var members = []

					@commit().NL_0M()

					until @test(Token::RIGHT_CURLY) {
						identifier = @reqIdentifier()

						if @test(Token::EQUALS_RIGHT_ANGLE) {
							@commit()

							var external = @reqIdentifier()

							members.push(@yep(AST.NamedSpecifier([], identifier, external, identifier, external)))
						}
						else {
							members.push(@yep(AST.NamedSpecifier([], identifier, null, identifier, identifier)))
						}

						if @test(Token::COMMA) {
							@commit()
						}

						@reqNL_1M()
					}

					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.PropertiesSpecifier([], value, members, value, @yes()))
				}
				else {
					var members = []

					identifier = @reqIdentifier()

					if @test(Token::EQUALS_RIGHT_ANGLE) {
						@commit()

						var external = @reqIdentifier()

						members.push(@yep(AST.NamedSpecifier([], identifier, external, identifier, external)))
					}
					else {
						members.push(@yep(AST.NamedSpecifier([], identifier, null, identifier, identifier)))
					}

					while @test(Token::COMMA) {
						@commit()

						identifier = @reqIdentifier()

						if @test(Token::EQUALS_RIGHT_ANGLE) {
							@commit()

							var external = @reqIdentifier()

							members.push(@yep(AST.NamedSpecifier([], identifier, external, identifier, external)))
						}
						else {
							members.push(@yep(AST.NamedSpecifier([], identifier, null, identifier, identifier)))
						}
					}

					last = members[members.length - 1]

					return @yep(AST.PropertiesSpecifier([], value, members, value, last))
				}
			}
			else {
				return @yep(AST.NamedSpecifier([], value, identifier, value, identifier ?? value))
			}
		} # }}}
		reqExportModule(first: Event): Event ~ SyntaxError { # {{{
			var mut last = first
			var declarations = []

			if @match(Token::EQUALS, Token::IDENTIFIER, Token::LEFT_CURLY) == Token::EQUALS {
				var modifier = @yep(AST.Modifier(ModifierKind::Default, @yes()))
				var identifier = @reqIdentifier()

				declarations.push(@yep(AST.NamedSpecifier([modifier], identifier, null, first, identifier)))
			}
			else if @token == Token::IDENTIFIER {
				var internal = @reqIdentifier()
				var mut external = internal

				if @test(Token::EQUALS_RIGHT_ANGLE) {
					@commit()

					external = @reqIdentifier()
				}

				declarations.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))

				while @until(Token::COMMA) {
					@commit()

					var internal = @reqIdentifier()
					var mut external = internal

					if @test(Token::EQUALS_RIGHT_ANGLE) {
						@commit()

						external = @reqIdentifier()
					}

					declarations.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))
				}

				last = declarations[declarations.length - 1]
			}
			else if @token == Token::LEFT_CURLY {
				@commit()

				while @until(Token::RIGHT_CURLY) {
					@commit()

					var internal = @reqIdentifier()
					var mut external = internal

					if @test(Token::EQUALS_RIGHT_ANGLE) {
						@commit()

						external = @reqIdentifier()
					}

					declarations.push(@yep(AST.NamedSpecifier([], internal, external, internal, external)))
				}

				@throw('}') unless @test(Token::RIGHT_CURLY)

				last = @yes()
			}
			else {
				@throw('Idendifier', '{', '=')
			}

			return @yep(AST.ExportDeclaration([], declarations, first, last))
		} # }}}
		reqExportStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var attributes = []
			var declarations = []

			var dyn last
			if @match(Token::ASTERISK, Token::LEFT_CURLY) == Token::ASTERISK {
				var first = @yes()

				if @test(Token::BUT) {
					var modifier = @yep(AST.Modifier(ModifierKind::Exclusion, @yes()))
					var elements = []

					if @test(Token::LEFT_CURLY) {
						@commit().NL_0M()

						until @test(Token::RIGHT_CURLY) {
							elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))

							@reqNL_1M()
						}

						@throw('}') unless @test(Token::RIGHT_CURLY)

						last = @yes()
					}
					else {
						elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))

						while @test(Token::COMMA) {
							@commit()

							elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))
						}

						last = elements[elements.length - 1]
					}

					declarations.push(@yep(AST.GroupSpecifier([modifier], elements, null, modifier, last)))
				}
				else {
					var modifier = @yep(AST.Modifier(ModifierKind::Wildcard, first))

					declarations.push(@yep(AST.GroupSpecifier([modifier], [], null, modifier, modifier)))

					last = modifier
				}
			}
			else if @token == Token::LEFT_CURLY {
				@commit().NL_0M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqExportDeclarator()

					if attrs.length > 0 {
						if declarator.value.kind != NodeKind::DeclarationSpecifier {
							@throw()
						}

						AST.pushAttributes(declarator.value.declaration, attrs)

						declarator.value.start = declarator.value.declaration.start
					}

					declarations.push(declarator)

					@reqNL_1M()
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(@reqExportDeclarator())

				while @test(Token::COMMA) {
					@commit()

					declarations.push(@reqExportDeclarator())
				}

				last = declarations[declarations.length - 1]
			}

			@reqNL_EOF_1M()

			return @yep(AST.ExportDeclaration(attributes, declarations, first, last))
		} # }}}
		reqExpression(mut eMode: ExpressionMode?, fMode: FunctionMode, terminator: MacroTerminator? = null): Event ~ SyntaxError { # {{{
			if eMode == null | ExpressionMode::ImplicitMember {
				if @mode ~~ ParserMode::MacroExpression &&
					@scanner.test(Token::IDENTIFIER) &&
					@scanner.value() == 'macro'
				{
					return @reqMacroExpression(@yes(), terminator)
				}
				else if eMode == null {
					eMode = ExpressionMode::Default
				}
				else {
					eMode += ExpressionMode::Default
				}
			}

			return @reqOperation(eMode, fMode)
		} # }}}
		reqExpressionStatement(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var expression = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

			if @match(Token::FOR, Token::IF, Token::REPEAT, Token::UNLESS) == Token::FOR {
				var statement = @reqForExpression(@yes(), fMode)

				statement.value.body = expression.value

				@relocate(statement, expression, null)

				return statement
			}
			else if @token == Token::IF {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				return @yep(AST.IfStatement(condition, null, expression, null, expression, condition))
			}
			else if @token == Token::REPEAT {
				@commit().NL_0M()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				unless @test(Token::TIMES) {
					@throw('times')
				}

				return @yep(AST.RepeatStatement(condition, expression, expression, @yes()))
			}
			else if @token == Token::UNLESS {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				return @yep(AST.UnlessStatement(condition, expression, expression, condition))
			}
			else {
				return @yep(AST.ExpressionStatement(expression))
			}
		} # }}}
		reqExternClassDeclaration(mut first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			var name = @reqIdentifier()

			var dyn generic
			if @test(Token::LEFT_ANGLE) {
				generic = @reqTypeGeneric(@yes())
			}

			var dyn extends
			if @test(Token::EXTENDS) {
				@commit()

				extends = @reqIdentifier()
			}

			if @test(Token::LEFT_CURLY) {
				@commit().NL_0M()

				var attributes = []
				var members = []

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@reqExternClassMemberList(members)
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				return @yep(AST.ClassDeclaration(attributes, name, null, extends, modifiers, members, first, @yes()))
			}
			else {
				return @yep(AST.ClassDeclaration([], name, null, extends, modifiers, [], first, extends ?? generic ?? name))
			}
		} # }}}
		reqExternClassField(attributes, modifiers, name: Event, type: Event?, mut first: Event): Event ~ SyntaxError { # {{{
			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, null, first, type ?? name))
		} # }}}
		reqExternClassMember(attributes, modifiers, mut first: Event?): Event ~ SyntaxError { # {{{
			var name = @reqIdentifier()

			if @match(Token::COLON, Token::LEFT_CURLY, Token::LEFT_ROUND) == Token::COLON {
				@commit()

				var type = @reqType()

				if @test(Token::LEFT_CURLY) {
					@throw()
				}
				else {
					return @reqExternClassField(attributes, modifiers, name, type, first ?? name)
				}
			}
			else if @token == Token::LEFT_CURLY {
				@throw()
			}
			else if @token == Token::LEFT_ROUND {
				return @reqExternClassMethod(attributes, modifiers, name, @yes(), first ?? name)
			}
			else {
				return @reqExternClassField(attributes, modifiers, name, null, first ?? name)
			}
		} # }}}
		reqExternClassMemberList(members): Void ~ SyntaxError { # {{{
			var dyn first = null

			var attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			var modifiers = @reqAccessModifiers([])

			if @test(Token::ABSTRACT) {
				modifiers.push(@yep(AST.Modifier(ModifierKind::Abstract, @yes())))

				first = modifiers[0]

				if @test(Token::LEFT_CURLY) {
					@commit().NL_0M()

					first = null

					var dyn attrs
					while @until(Token::RIGHT_CURLY) {
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
							ClassBits::Method + ClassBits::NoBody
							first
						))
					}

					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					@commit().reqNL_1M()
				}
				else {
					members.push(@reqClassMember(
						attributes
						modifiers
						ClassBits::Method + ClassBits::NoBody
						first
					))
				}
			}
			else {
				if @test(Token::STATIC) {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Static, @yes())))
				}
				if first == null && modifiers.length != 0 {
					first = modifiers[0]
				}

				if modifiers.length != 0 && @test(Token::LEFT_CURLY) {
					@commit().NL_0M()

					first = null

					var dyn attrs
					while @until(Token::RIGHT_CURLY) {
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

					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					@commit().reqNL_1M()
				}
				else {
					members.push(@reqExternClassMember(attributes, modifiers, first))
				}
			}
		} # }}}
		reqExternClassMethod(attributes, modifiers, name: Event, round: Event, first): Event ~ SyntaxError { # {{{
			var parameters = @reqClassMethodParameterList(round, DestructuringMode::EXTERNAL_ONLY)
			var type = @tryMethodReturns(false)

			@reqNL_1M()

			return @yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, null, null, first, type ?? parameters))
		} # }}}
		reqExternFunctionDeclaration(modifiers, mut first: Event): Event ~ SyntaxError { # {{{
			var name = @reqIdentifier()

			if @test(Token::LEFT_ROUND) {
				var parameters = @reqFunctionParameterList(FunctionMode::Function, DestructuringMode::EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionDeclaration(name, parameters, modifiers, type, throws, null, first, throws ?? type ?? parameters))
			}
			else {
				var position = @yep()
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionDeclaration(name, null, modifiers, type, throws, null, first, throws ?? type ?? name))
			}
		} # }}}
		reqExternNamespaceDeclaration(mut first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			var name = @reqIdentifier()

			if @test(Token::LEFT_CURLY) {
				@commit().NL_0M()

				var attributes = []
				var statements = []

				var dyn attrs = []
				var dyn statement

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					statement = @reqTypeDescriptive()

					@reqNL_1M()

					AST.pushAttributes(statement.value, attrs)

					statements.push(statement)
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				return @yep(AST.NamespaceDeclaration(attributes, modifiers, name, statements, first, @yes()))
			}
			else {
				return @yep(AST.NamespaceDeclaration([], modifiers, name, [], first, name))
			}
		} # }}}
		reqExternOrImportStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token::LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqImportDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token::NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_CURLY) {
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
		reqExternOrRequireStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.ExternOrRequireDeclaration(attributes, declarations, first, last))
		} # }}}
		reqExternStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.ExternDeclaration(attributes, declarations, first, last))
		} # }}}
		reqExternVariableDeclarator(name: Event): Event ~ SyntaxError { # {{{
			if @match(Token::COLON, Token::LEFT_ROUND) == Token::COLON {
				@commit()

				var type = @reqType()

				return @yep(AST.VariableDeclarator([], name, type, name, type))
			}
			else if @token == Token::LEFT_ROUND {
				var parameters = @reqFunctionParameterList(FunctionMode::Function, DestructuringMode::EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)

				return @yep(AST.FunctionDeclaration(name, parameters, [], type, null, null, name, type ?? parameters))
			}
			else {
				return @yep(AST.VariableDeclarator([], name, null, name, name))
			}
		} # }}}
		reqExternalDeclarations(attributes: [], declarations: []): Event ~ SyntaxError { # {{{
			var late last: Event

			if @test(Token::LEFT_CURLY) {
				@commit().NL_0M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqTypeDescriptive()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					@reqNL_1M()
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				var mark = @mark()

				var identifier = @tryIdentifier()
				if identifier.ok {
					if @test(Token::COMMA) {
						declarations.push(@yep(AST.VariableDeclarator([], identifier, null, identifier, identifier)))

						while @test(Token::COMMA) {
							@commit()

							var identifier = @reqIdentifier()

							if @test(Token::COLON) {
								@commit()

								var type = @reqTypeEntity()

								declarations.push(@yep(AST.VariableDeclarator([], identifier, type, identifier, type)))
							}
							else {
								declarations.push(@yep(AST.VariableDeclarator([], identifier, null, identifier, identifier)))
							}
						}
					}
					else if @test(Token::NEWLINE) {
						declarations.push(@yep(AST.VariableDeclarator([], identifier, null, identifier, identifier)))
					}
					else if @test(Token::COLON) {
						@commit()

						var type = @tryTypeEntity()

						if type.ok {
							declarations.push(@yep(AST.VariableDeclarator([], identifier, type, identifier, type)))

							while @test(Token::COMMA) {
								@commit()

								var identifier = @reqIdentifier()

								if @test(Token::COLON) {
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
		reqFallthroughStatement(mut first: Event): Event { # {{{
			return @yep(AST.FallthroughStatement(first))
		} # }}}
		reqForExpression(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var modifiers = []

			var mark = @mark()

			if @test(Token::VAR) {
				var mark2 = @mark()
				var first = @yes()

				var dyn modifier
				if @test(Token::MUT) {
					modifier = AST.Modifier(ModifierKind::Mutable, @yes())
				}
				else {
					modifier = AST.Modifier(ModifierKind::Immutable, first)
				}

				if @test(Token::COMMA) {
					@rollback(mark)
				}
				else if @test(Token::FROM, Token::IN, Token::OF) {
					@commit()

					if @test(Token::FROM, Token::IN, Token::OF) {
						modifiers.push(AST.Modifier(ModifierKind::Declarative, first), modifier)

						@rollback(mark2)
					}
					else {
						@rollback(mark)
					}
				}
				else {
					modifiers.push(AST.Modifier(ModifierKind::Declarative, first), modifier)
				}
			}


			var dyn identifier1 = NO
			var dyn type1 = NO
			var dyn identifier2 = NO
			var dyn destructuring = NO

			if @test(Token::UNDERSCORE) {
				@commit()
			}
			else if !(destructuring = @tryDestructuring(fMode)).ok {
				identifier1 = @reqIdentifier()

				if @test(Token::COLON) {
					@commit()

					type1 = @reqType()
				}
			}

			if @test(Token::COMMA) {
				@commit()

				identifier2 = @reqIdentifier()
			}

			@NL_0M()

			if destructuring.ok {
				if @match(Token::IN, Token::OF) == Token::IN {
					@commit()

					return @altForExpressionIn(modifiers, destructuring, type1, identifier2, @reqExpression(ExpressionMode::Default, fMode), first, fMode)
				}
				else if @token == Token::OF {
					@commit()

					return @altForExpressionOf(modifiers, destructuring, type1, identifier2, first, fMode)
				}
				else {
					@throw('in', 'of')
				}
			}
			else if identifier2.ok {
				if @match(Token::IN, Token::OF) == Token::IN {
					@commit()

					return @altForExpressionInRange(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else if @token == Token::OF {
					@commit()

					return @altForExpressionOf(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					@throw('in', 'of')
				}
			}
			else {
				if @match(Token::FROM, Token::FROM_TILDE, Token::IN, Token::OF) == Token::FROM | Token::FROM_TILDE {
					return @altForExpressionFrom(modifiers, identifier1, first, fMode)
				}
				else if @token == Token::IN {
					@commit()

					return @altForExpressionInRange(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else if @token == Token::OF {
					@commit()

					return @altForExpressionOf(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					@throw('from', 'in', 'of')
				}
			}
		} # }}}
		reqForStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var statement = @reqForExpression(first, fMode)

			@NL_0M()

			var block = @reqBlock(NO, fMode)

			statement.value.body = block.value
			@relocate(statement, null, block)

			if statement.value.kind == NodeKind::ForFromStatement | NodeKind::ForInStatement | NodeKind::ForOfStatement {
				var mark = @mark()

				@commit().NL_0M()

				if @test(Token::ELSE) {
					@commit().NL_0M()

					var block = @reqBlock(NO, fMode)

					statement.value.else = block.value
				}
				else {
					@rollback(mark)
				}
			}

			return statement
		} # }}}
		reqFunctionBody(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			if @match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				return @reqBlock(@yes(), fMode)
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				@commit().NL_0M()

				var expression = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				if @match(Token::IF, Token::UNLESS) == Token::IF {
					@commit()

					var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

					return @yep(AST.IfStatement(condition, null, @yep(AST.ReturnStatement(expression, expression, expression)), null, expression, condition))
				}
				else if @token == Token::UNLESS {
					@commit()

					var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

					return @yep(AST.UnlessStatement(condition, @yep(AST.ReturnStatement(expression, expression, expression)), expression, condition))
				}
				else {
					return expression
				}
			}
			else {
				@throw('{', '=>')
			}
		} # }}}
		reqFunctionParameterList(fMode: FunctionMode, mut pMode: DestructuringMode = DestructuringMode::Nil): Event ~ SyntaxError { # {{{
			unless @test(Token::LEFT_ROUND) {
				@throw('(')
			}

			var first = @yes()

			@NL_0M()

			var parameters = []

			pMode += DestructuringMode::Parameter

			while @until(Token::RIGHT_ROUND) {
				parameters.push(@reqParameter(pMode, fMode))

				@reqSeparator(Token::RIGHT_ROUND)
			}

			unless @test(Token::RIGHT_ROUND) {
				@throw(')')
			}

			return @yep(parameters, first, @yes())
		} # }}}
		reqFunctionStatement(mut first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			var name = @reqIdentifier()
			var parameters = @reqFunctionParameterList(FunctionMode::Function)
			var type = @tryFunctionReturns()
			var throws = @tryFunctionThrows()
			var body = @reqFunctionBody(FunctionMode::Function)

			return @yep(AST.FunctionDeclaration(name, parameters, modifiers, type, throws, body, first, body))
		} # }}}
		reqIdentifier(): Event ~ SyntaxError { # {{{
			if @scanner.test(Token::IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				@throw('Identifier')
			}
		} # }}}
		reqIfStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var mut condition: Event? = null
			var mut declaration: Event? = null

			if @test(Token::VAR) {
				var mark = @mark()
				var first = @yes()

				var modifiers = []
				if @test(Token::MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Mutable, @yes())))
				}
				else {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Immutable, @yes())))
				}

				if @test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					if @test(Token::COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token::COMMA)

						var operator = @reqConditionAssignment()

						unless @test(Token::AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						declaration = @yep(AST.VariableDeclaration([], modifiers, variables, operator, expression, first, expression))
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(ExpressionMode::Default + ExpressionMode::ImplicitMember, fMode)

						declaration = @yep(AST.VariableDeclaration([], modifiers, [variable], operator, expression, first, expression))
					}

					@NL_0M()

					if @test(Token::SEMICOLON) {
						@commit().NL_0M()

						condition = @reqExpression(ExpressionMode::NoAnonymousFunction, fMode)
					}
				}
				else {
					@rollback(mark)

					condition = @reqExpression(ExpressionMode::NoAnonymousFunction, fMode)
				}
			}
			else {
				@NL_0M()

				condition = @reqExpression(ExpressionMode::NoAnonymousFunction, fMode)
			}

			@NL_0M()

			var whenTrue = @reqBlock(NO, fMode)

			if @test(Token::NEWLINE) {
				var mark = @mark()

				@commit().NL_0M()

				if @match(Token::ELSE_IF, Token::ELSE) == Token::ELSE_IF {
					var position = @yes()

					position.start.column += 5

					var whenFalse = @reqIfStatement(position, fMode)

					return @yep(AST.IfStatement(condition, declaration, whenTrue, whenFalse, first, whenFalse))
				}
				else if @token == Token::ELSE {
					@commit().NL_0M()

					var whenFalse = @reqBlock(NO, fMode)

					return @yep(AST.IfStatement(condition, declaration, whenTrue, whenFalse, first, whenFalse))
				}
				else {
					@rollback(mark)

					return @yep(AST.IfStatement(condition, declaration, whenTrue, null, first, whenTrue))
				}
			}
			else {
				return @yep(AST.IfStatement(condition, declaration, whenTrue, null, first, whenTrue))
			}
		} # }}}
		reqImplementMemberList(members): Void ~ SyntaxError { # {{{
			var dyn first = null

			var attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			var accessMark = @mark()
			var accessModifier = @tryAccessModifier()

			if accessModifier.ok && @test(Token::LEFT_CURLY) {
				return @reqClassMemberBlock(
					attributes
					[accessModifier]
					ClassBits::Variable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method
					members
				)
			}

			if @test(Token::OVERRIDE, Token::OVERWRITE) {
				var mark = @mark()
				var modifier = @yep(AST.Modifier(@token == Token::OVERRIDE ? ModifierKind::Override : ModifierKind::Overwrite, @yes()))
				var modifiers = [modifier]
				if accessModifier.ok {
					modifiers.unshift(accessModifier)
				}

				if @test(Token::LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						ClassBits::Method + ClassBits::Property
						members
					)
				}

				var member = @tryClassMember(
					attributes
					modifiers
					ClassBits::Method + ClassBits::Property
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

			if @test(Token::STATIC) {
				staticModifier = @yep(AST.Modifier(ModifierKind::Static, @yes()))

				if @test(Token::LEFT_CURLY) {
					var modifiers = [staticModifier]
					if accessModifier.ok {
						modifiers.unshift(accessModifier)
					}

					return @reqClassMemberBlock(
						attributes
						modifiers
						ClassBits::Variable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method + ClassBits::FinalMethod
						members
					)
				}
			}

			var finalMark = @mark()
			var dyn finalModifier = NO

			if @test(Token::FINAL) {
				finalModifier = @yep(AST.Modifier(ModifierKind::Immutable, @yes()))

				if @test(Token::LEFT_CURLY) {
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
							ClassBits::Variable + ClassBits::LateVariable + ClassBits::RequiredAssignment + ClassBits::Property + ClassBits::Method
							members
						)
					}
					else {
						return @reqClassMemberBlock(
							attributes
							modifiers
							ClassBits::Variable + ClassBits::LateVariable + ClassBits::RequiredAssignment +
							ClassBits::Property + ClassBits::OverrideProperty + ClassBits::OverwriteProperty +
							ClassBits::Method + ClassBits::OverrideMethod + ClassBits::OverwriteMethod
							members
						)
					}
				}
				else if !staticModifier.ok && @test(Token::OVERRIDE, Token::OVERWRITE) {
					var mark = @mark()
					var modifier = @yep(AST.Modifier(@token == Token::OVERRIDE ? ModifierKind::Override : ModifierKind::Overwrite, @yes()))

					if @test(Token::LEFT_CURLY) {
						var modifiers = [finalModifier, modifier]
						if accessModifier.ok {
							modifiers.unshift(accessModifier)
						}

						return @reqClassMemberBlock(
							attributes
							modifiers
							ClassBits::Method + ClassBits::Property
							members
						)
					}

					@rollback(mark)
				}
			}

			if @test(Token::LATE) {
				var lateMark = @mark()
				var lateModifier = @yep(AST.Modifier(ModifierKind::LateInit, @yes()))

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

				if @test(Token::LEFT_CURLY) {
					return @reqClassMemberBlock(
						attributes
						modifiers
						finalModifier.ok ? ClassBits::Variable : ClassBits::Variable + ClassBits::FinalVariable
						members
					)
				}

				var member = @tryClassMember(
					attributes
					modifiers
					ClassBits::Variable + ClassBits::NoAssignment
					first ?? modifiers[0]
				)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(lateMark)
			}
			else if @test(Token::OVERRIDE) {
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
		reqImplementStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var variable = @reqIdentifier()

			if @test(Token::LEFT_ANGLE) {
				@reqTypeGeneric(@yes())
			}

			unless @test(Token::LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var attributes = []
			var members = []

			until @test(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@reqImplementMemberList(members)
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.ImplementDeclaration(attributes, variable, members, first, @yes()))
		} # }}}
		reqImportDeclarator(): Event ~ SyntaxError { # {{{
			var source = @reqString()
			var modifiers = []
			var dyn arguments = null
			var mut last = source

			if @test(Token::LEFT_ROUND) {
				@commit()

				arguments = []

				if @test(Token::DOT_DOT_DOT) {
					modifiers.push(AST.Modifier(ModifierKind::Autofill, @yes()))

					if @test(Token::COMMA) {
						@commit()
					}
				}

				while @until(Token::RIGHT_ROUND) {
					var dyn name = @reqExpression(ExpressionMode::Default, FunctionMode::Function)
					var modifiers = []

					if name.value.kind == NodeKind::Identifier {
						if name.value.name == 'require' && !@test(Token::COLON, Token::COMMA, Token::RIGHT_ROUND) {
							var first = name

							modifiers.push(AST.Modifier(ModifierKind::Required, name))

							name = @reqIdentifier()

							if @test(Token::COLON) {
								@commit()

								var value = @reqIdentifier()

								arguments.push(AST.Argument(modifiers, name, value, first, value))
							}
							else {
								arguments.push(AST.Argument(modifiers, null, name, first, name))
							}
						}
						else {
							if @test(Token::COLON) {
								@commit()

								var value = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

								arguments.push(AST.Argument(modifiers, name, value, name, value))
							}
							else {
								arguments.push(AST.Argument(modifiers, null, name, name, name))
							}
						}
					}
					else {
						arguments.push(AST.Argument(modifiers, null, name, name, name))
					}

					if @test(Token::COMMA) {
						@commit()
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_ROUND) {
					@throw(')')
				}

				@commit()
			}

			var attributes = []
			var mut type = null
			var specifiers = []

			if @match(Token::BUT, Token::EQUALS_RIGHT_ANGLE, Token::FOR, Token::LEFT_CURLY) == Token::BUT {
				var modifier = @yep(AST.Modifier(ModifierKind::Exclusion, @yes()))
				var elements = []

				if @test(Token::LEFT_CURLY) {
					@commit().NL_0M()

					until @test(Token::RIGHT_CURLY) {
						elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))

						@reqNL_1M()
					}

					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					last = @yes()
				}
				else {
					elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))

					while @test(Token::COMMA) {
						@commit()

						elements.push(@yep(AST.NamedSpecifier(@reqIdentifier())))
					}

					last = elements[elements.length - 1]
				}

				specifiers.push(@yep(AST.GroupSpecifier([modifier], elements, null, modifier, last)))

				last = specifiers[specifiers.length - 1]
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				var modifier = @yep(AST.Modifier(ModifierKind::Alias, @yes()))

				@submitNamedGroupSpecifier([modifier], null, specifiers)

				last = specifiers[specifiers.length - 1]
			}
			else if @token == Token::FOR {
				var first = @yes()
				var elements = []

				if @test(Token::LEFT_CURLY) {
					@commit().NL_0M()

					while @until(Token::RIGHT_CURLY) {
						var type = @tryTypeDescriptive(TypeMode::NoIdentifier)

						if type.ok {
							if @test(Token::EQUALS_RIGHT_ANGLE) {
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

					@throw('}') unless @test(Token::RIGHT_CURLY)

					@commit()
				}
				else {
					var type = @tryTypeDescriptive(TypeMode::NoIdentifier)

					if type.ok {
						if @test(Token::EQUALS_RIGHT_ANGLE) {
							@commit()

							@submitNamedGroupSpecifier([], type, elements)
						}
						else {
							elements.push(@yep(AST.TypedSpecifier(type, type)))
						}
					}
					else {
						@submitNamedSpecifier([], elements)

						while @test(Token::COMMA) {
							@commit()

							@submitNamedSpecifier([], elements)
						}
					}
				}

				last = elements[elements.length - 1]

				specifiers.push(@yep(AST.GroupSpecifier([], elements, null, first, last)))

				last = specifiers[specifiers.length - 1]
			}
			else if @token == Token::LEFT_CURLY {
				type = @reqTypeModule(@yes())

				if @match(Token::EQUALS_RIGHT_ANGLE, Token::FOR) == Token::EQUALS_RIGHT_ANGLE {
					var modifier = @yep(AST.Modifier(ModifierKind::Alias, @yes()))

					@submitNamedGroupSpecifier([modifier], null, specifiers)

					last = specifiers[specifiers.length - 1]
				}
				else if @token == Token::FOR {
					@commit()

					var elements = []

					if @test(Token::ASTERISK) {
						var modifier = @yep(AST.Modifier(ModifierKind::Wildcard, @yes()))

						specifiers.push(@yep(AST.GroupSpecifier([modifier], [], null, modifier, modifier)))

						last = modifier
					}
					else if @test(Token::LEFT_CURLY) {
						@commit().NL_0M()

						while @until(Token::RIGHT_CURLY) {
							@submitNamedSpecifier([], specifiers)

							@reqNL_1M()
						}

						@throw('}') unless @test(Token::RIGHT_CURLY)

						last = @yes()
					}
					else {
						@submitNamedSpecifier([], specifiers)

						while @test(Token::COMMA) {
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

			return @yep(AST.ImportDeclarator(attributes, modifiers, source, arguments, type, specifiers, source, last))
		} # }}}
		reqImportStatement(mut first: Event): Event ~ SyntaxError { # {{{
			@NL_0M()

			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token::LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqImportDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token::NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(last <- @reqImportDeclarator())
			}

			return @yep(AST.ImportDeclaration(attributes, declarations, first, last))
		} # }}}
		reqIncludeDeclarator(): Event ~ SyntaxError { # {{{
			unless @test(Token::STRING) {
				@throw('String')
			}

			var file = @yes(@value())

			return @yep(AST.IncludeDeclarator(file))
		} # }}}
		reqIncludeStatement(mut first: Event): Event ~ SyntaxError { # {{{
			@NL_0M()

			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token::LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqIncludeDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token::NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(last <- @reqIncludeDeclarator())
			}

			return @yep(AST.IncludeDeclaration(attributes, declarations, first, last))
		} # }}}
		reqIncludeAgainStatement(mut first: Event): Event ~ SyntaxError { # {{{
			@NL_0M()

			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token::LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqIncludeDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token::NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}
			else {
				declarations.push(last <- @reqIncludeDeclarator())
			}

			return @yep(AST.IncludeAgainDeclaration(attributes, declarations, first, last))
		} # }}}
		reqJunctionExpression(operator, eMode, fMode, values, type: Boolean) ~ SyntaxError { # {{{
			@NL_0M()

			var operands = [values.pop()]

			if type {
				operands.push(@reqTypeLimited(false).value)
			}
			else {
				operands.push(@reqBinaryOperand(eMode, fMode).value)
			}

			var kind = operator.value.kind

			while true {
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
		reqMacroElements(elements, terminator: MacroTerminator): Void ~ SyntaxError { # {{{
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

			while true {
				match @matchM(M.MACRO) {
					Token::EOF {
						if history.length == 0 && terminator !~ MacroTerminator::NEWLINE {
							@throw()
						}

						break
					}
					Token::HASH_LEFT_ROUND {
						addLiteral()

						var first = @yes()
						var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

						@throw(')') unless @test(Token::RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, null, first, @yes())))
					}
					Token::HASH_A_LEFT_ROUND {
						addLiteral()

						var reification = AST.Modifier(ReificationKind::Argument, @yes())
						var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

						@throw(')') unless @test(Token::RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, reification, reification, @yes())))
					}
					Token::HASH_E_LEFT_ROUND {
						addLiteral()

						var reification = AST.Modifier(ReificationKind::Expression, @yes())
						var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

						@throw(')') unless @test(Token::RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, reification, reification, @yes())))
					}
					Token::HASH_J_LEFT_ROUND {
						addLiteral()

						var reification = AST.Modifier(ReificationKind::Join, @yes())
						var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

						@throw(',') unless @test(Token::COMMA)

						@commit()

						var separator = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

						@throw(')') unless @test(Token::RIGHT_ROUND)

						var ast = AST.MacroElementExpression(expression, reification, reification, @yes())

						ast.separator = separator.value

						elements.push(@yep(ast))
					}
					Token::HASH_S_LEFT_ROUND {
						addLiteral()

						var reification = AST.Modifier(ReificationKind::Statement, @yes())
						var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

						@throw(')') unless @test(Token::RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, reification, reification, @yes())))
					}
					Token::HASH_W_LEFT_ROUND {
						addLiteral()

						var reification = AST.Modifier(ReificationKind::Write, @yes())
						var expression = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

						@throw(')') unless @test(Token::RIGHT_ROUND)

						elements.push(@yep(AST.MacroElementExpression(expression, reification, reification, @yes())))
					}
					Token::INVALID {
						addToLiteral()
					}
					Token::LEFT_CURLY {
						addToLiteral()

						history.unshift(Token::RIGHT_CURLY)
					}
					Token::LEFT_ROUND {
						addToLiteral()

						history.unshift(Token::RIGHT_ROUND)
					}
					Token::NEWLINE {
						if history.length == 0 && terminator ~~ MacroTerminator::NEWLINE {
							break
						}
						else {
							addLiteral()

							elements.push(@yep(AST.MacroElementNewLine(@yes())))

							@scanner.skip()
						}
					}
					Token::RIGHT_CURLY {
						if history.length == 0 {
							if terminator !~ MacroTerminator::RIGHT_CURLY {
								addToLiteral()
							}
							else {
								break
							}
						}
						else {
							addToLiteral()

							if history[0] == Token::RIGHT_CURLY {
								history.shift()
							}
						}
					}
					Token::RIGHT_ROUND {
						if history.length == 0 {
							if terminator !~ MacroTerminator::RIGHT_ROUND {
								addToLiteral()
							}
							else {
								break
							}
						}
						else {
							addToLiteral()

							if history[0] == Token::RIGHT_ROUND {
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
		reqMacroExpression(mut first: Event, terminator: MacroTerminator = MacroTerminator::NEWLINE): Event ~ SyntaxError { # {{{
			var elements = []

			if @test(Token::LEFT_CURLY) {
				if first.ok {
					@commit()
				}
				else {
					first = @yes()
				}

				@reqNL_1M()

				@reqMacroElements(elements, MacroTerminator::RIGHT_CURLY)

				unless @test(Token::RIGHT_CURLY) {
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
		reqMacroParameterList(): Event ~ SyntaxError { # {{{
			unless @test(Token::LEFT_ROUND) {
				@throw('(')
			}

			var first = @yes()

			@NL_0M()

			var parameters = []

			while @until(Token::RIGHT_ROUND) {
				parameters.push(@reqParameter(DestructuringMode::Parameter, FunctionMode::Macro))

				@reqSeparator(Token::RIGHT_ROUND)
			}

			unless @test(Token::RIGHT_ROUND) {
				@throw(')')
			}

			return @yep(parameters, first, @yes())
		} # }}}
		reqMacroBody(): Event ~ SyntaxError { # {{{
			if @match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				@mode += ParserMode::MacroExpression

				var body = @reqBlock(@yes(), FunctionMode::Function)

				@mode -= ParserMode::MacroExpression

				return body
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				return @reqMacroExpression(@yes())
			}
			else {
				@throw('{', '=>')
			}
		} # }}}
		reqMacroStatement(attributes = []): Event ~ SyntaxError { # {{{
			var name = @reqIdentifier()
			var parameters = @reqMacroParameterList()

			var body = @reqMacroBody()

			@reqNL_1M()

			return @yep(AST.MacroDeclaration(attributes, name, parameters, body, name, body))
		} # }}}
		reqMacroStatement(attributes = [], name: Event, mut first: Event): Event ~ SyntaxError { # {{{
			var parameters = @reqMacroParameterList()

			var body = @reqMacroBody()

			@reqNL_1M()

			return @yep(AST.MacroDeclaration(attributes, name, parameters, body, first, body))
		} # }}}
		reqMatchBinding(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var bindings = [@reqMatchBindingValue(fMode)]

			while @test(Token::COMMA) {
				@commit()

				bindings.push(@reqMatchBindingValue(fMode))
			}

			return @yep(bindings)
		} # }}}
		reqMatchBindingValue(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			match @match(Token::LEFT_CURLY, Token::LEFT_SQUARE) {
				Token::LEFT_CURLY {
					return @reqDestructuringObject(@yes(), DestructuringMode::Nil, fMode)
				}
				Token::LEFT_SQUARE {
					return @reqDestructuringArray(@yes(), DestructuringMode::Nil, fMode)
				}
				else {
					var mark = @mark()

					var modifiers = []
					var mut modifier = null
					var mut name = null
					var mut type = null

					if @test(Token::MUT) {
						modifier = @yep(AST.Modifier(ModifierKind::Mutable, @yes()))

						name = @tryIdentifier()

						if name.ok {
							modifiers.push(modifier)
						}
						else {
							@rollback(mark)

							name = @reqIdentifier()
						}
					}
					else {
						name = @reqIdentifier()
					}

					if @test(Token::COLON) {
						@commit()

						type = @reqType()
					}

					return @yep(AST.VariableDeclarator(modifiers, name, type, modifier ?? name, type ?? name))
				}
			}
		} # }}}
		reqMatchCaseExpression(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			match @match(Token::BREAK, Token::CONTINUE, Token::PASS, Token::RETURN, Token::THROW) {
				Token::BREAK {
					return @reqBreakStatement(@yes(), fMode)
				}
				Token::CONTINUE {
					return @reqContinueStatement(@yes(), fMode)
				}
				Token::PASS {
					return @reqPassStatement(@yes())
				}
				Token::RETURN {
					return @reqReturnStatement(@yes(), fMode)
				}
				Token::THROW {
					var first = @yes()
					var expression = @reqExpression(ExpressionMode::Default, fMode)

					return @yep(AST.ThrowStatement(expression, first, expression))
				}
				else {
					return @reqExpression(ExpressionMode::Default + ExpressionMode::Arrow, fMode)
				}
			}
		} # }}}
		reqMatchCaseList(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			unless @test(Token::LEFT_CURLY) {
				@throw('{')
			}

			@commit().NL_0M()

			var clauses = []

			var dyn conditions, bindings, filter, body, first
			until @test(Token::RIGHT_CURLY) {
				first = conditions = bindings = filter = null

				if @test(Token::ELSE) {
					first = @yes()

					if @test(Token::LEFT_CURLY) {
						body = @reqBlock(@yes(), fMode)
					}
					else if @test(Token::EQUALS_RIGHT_ANGLE) {
						@commit()

						body = @reqMatchCaseExpression(fMode)
					}
					else {
						@throw('=>', '{')
					}
				}
				else {
					if !@test(Token::WITH, Token::WHEN) {
						first = @reqMatchCondition(fMode)

						conditions = [first]

						while @test(Token::COMMA) {
							@commit()

							conditions.push(@reqMatchCondition(fMode))
						}

						@NL_0M()
					}

					if @test(Token::WITH) {
						if ?first {
							@commit()
						}
						else {
							first = @yes()
						}

						bindings = @reqMatchBinding(fMode)

						@NL_0M()
					}

					if @test(Token::WHEN) {
						if ?first {
							@commit()
						}
						else {
							first = @yes()
						}

						filter = @reqExpression(ExpressionMode::NoAnonymousFunction, fMode)

						@NL_0M()
					}

					if @test(Token::LEFT_CURLY) {
						body = @reqBlock(@yes(), fMode)
					}
					else if @test(Token::EQUALS_RIGHT_ANGLE) {
						@commit()

						body = @reqMatchCaseExpression(fMode)
					}
					else {
						@throw('=>', '{')
					}
				}

				@reqNL_1M()

				clauses.push(AST.MatchClause(conditions, bindings, filter, body, first!?, body))
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yes(clauses)
		} # }}}
		reqMatchCondition(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			match @match(Token::LEFT_CURLY, Token::LEFT_SQUARE, Token::IS) {
				Token::IS {
					var first = @yes()
					var type = @reqType()

					return @yep(AST.MatchConditionType(type, first, type))
				}
				Token::LEFT_CURLY {
					var dyn first = @yes()

					var members = []

					if !@test(Token::RIGHT_CURLY) {
						var dyn name

						while true {
							name = @reqIdentifier()

							if @test(Token::COLON) {
								@commit()

								var value = @reqMatchConditionValue(fMode)

								members.push(@yep(AST.ObjectMember([], [], name, null, value, name, value)))
							}
							else {
								members.push(@yep(AST.ObjectMember([], [], name, null, null, name, name)))
							}

							if @test(Token::COMMA) {
								@commit()
							}
							else {
								break
							}
						}
					}

					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.MatchConditionObject(members, first, @yes()))
				}
				Token::LEFT_SQUARE {
					var dyn first = @yes()

					var values = []

					until @test(Token::RIGHT_SQUARE) {
						if @test(Token::UNDERSCORE) {
							values.push(@yep(AST.OmittedExpression([], @yes())))
						}
						else if @test(Token::DOT_DOT_DOT) {
							modifier = AST.Modifier(ModifierKind::Rest, @yes())

							values.push(@yep(AST.OmittedExpression([modifier], modifier)))
						}
						else {
							values.push(@reqMatchConditionValue(fMode))
						}

						if @test(Token::COMMA) {
							@commit()

							if @test(Token::RIGHT_SQUARE) {
								values.push(@yep(AST.OmittedExpression([], @yep())))
							}
						}
						else {
							break
						}
					}

					unless @test(Token::RIGHT_SQUARE) {
						@throw(']')
					}

					return @yep(AST.MatchConditionArray(values, first, @yes()))
				}
				else {
					return @reqMatchConditionValue(fMode)
				}
			}
		} # }}}
		reqMatchConditionValue(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var eMode = ExpressionMode::Default + ExpressionMode::ImplicitMember
			var operand = @reqPrefixedOperand(eMode, fMode)
			var mut operator = NO

			if @match(Token::LEFT_ANGLE, Token::DOT_DOT) == Token::DOT_DOT {
				@commit()

				if @test(Token::LEFT_ANGLE) {
					@commit()

					return @yep(AST.MatchConditionRangeFI(operand, @reqPrefixedOperand(ExpressionMode::Default, fMode)))
				}
				else {
					return @yep(AST.MatchConditionRangeFO(operand, @reqPrefixedOperand(ExpressionMode::Default, fMode)))
				}
			}
			else if @token == Token::LEFT_ANGLE {
				@commit()

				unless @test(Token::DOT_DOT) {
					@throw('..')
				}

				@commit()

				if @test(Token::LEFT_ANGLE) {
					@commit()

					return @yep(AST.MatchConditionRangeTI(operand, @reqPrefixedOperand(ExpressionMode::Default, fMode)))
				}
				else {
					return @yep(AST.MatchConditionRangeTO(operand, @reqPrefixedOperand(ExpressionMode::Default, fMode)))
				}
			}
			else if (operator = @tryJunctionOperator()).ok {
				var values = [operand.value]

				values.push(@reqJunctionExpression(operator, eMode, fMode, values, false))

				return @yep(AST.reorderExpression(values))
			}
			else {
				return operand
			}
		} # }}}
		reqMultiLineString(first: Event, delimiter: Token): Event ~ SyntaxError { # {{{
			if @test(Token::NEWLINE) {
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
				else if @token == Token::EOF {
					@throw(delimiter == Token::ML_DOUBLE_QUOTE ? '"""' : "'''")
				}
				else {
					lines.push(currentIndent, @scanner.readLine())

					if @test(Token::NEWLINE) {
						@commit()
					}
					else {
						@throw('NewLine')
					}
				}
			}

			var mut value = ''

			if #baseIndent {
				for var [indent, line], index in lines split 2 {
					if index > 0 {
						value += '\n'
					}

					if #line {
						if indent.startsWith(baseIndent) {
							value += indent.substr(baseIndent.length) + line
						}
						else {
							throw @error(`Unexpected indentation`, first.start!?.line + (index / 2) + 1, 1)
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

			var modifiers = [@yep(AST.Modifier(ModifierKind::MultiLine, first, last))]

			return @yep(AST.Literal(modifiers, value, first, last))
		} # }}}
		reqMultiLineTemplate(first: Event, fMode: FunctionMode, delimiter: Token): Event ~ SyntaxError { # {{{
			if @test(Token::NEWLINE) {
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
				else if @token == Token::EOF {
					@throw(delimiter == Token::ML_BACKQUOTE ? '```' : '~~~')
				}
				else {
					var line = [currentIndent]

					repeat {
						if @matchM(M.TEMPLATE) == Token::TEMPLATE_ELEMENT {
							@commit()

							line.push(@reqExpression(ExpressionMode::Default, fMode))

							unless @test(Token::RIGHT_ROUND) {
								@throw(')')
							}

							@commit()
						}
						else if @token == Token::TEMPLATE_VALUE {
							line.push(@yep(AST.Literal(null, @scanner.value(), @yes())))
						}
						else {
							break
						}
					}

					if @test(Token::NEWLINE) {
						lines.push(line)

						@commit()
					}
					else {
						@throw('NewLine')
					}
				}
			}

			var elements = []

			if #lines {
				if #baseIndent {
					var firstLine = first.start!?.line + 1
					var mut previous = null

					for var [indent, first, ...rest], index in lines {
						if index > 0 {
							if !?previous {
								previous = AST.Literal(null, '\n', Position(
									line: firstLine
									column: 1
								), Position(
									line: firstLine
									column: 2
								))

								elements.push(previous)
							}
							else if previous.kind == NodeKind::Literal {
								previous.value += '\n'
								previous.end.column += 1
							}
							else {
								previous = AST.Literal(null, '\n', Position(
									line: previous.end.line:Number
									column: previous.end.column:Number + 1
								), Position(
									line: previous.end.line:Number
									column: previous.end.column:Number + 2
								))

								elements.push(previous)
							}
						}

						if ?first {
							unless indent.startsWith(baseIndent) {
								throw @error(`Unexpected indentation`, first.line:Number + index + 1, 1)
							}

							if var value #= indent.substr(baseIndent.length) {
								if !?previous {
									previous = AST.Literal(null, value, Position(
										line: firstLine
										column: baseIndent.length
									), Position(
										line: firstLine
										column: indent.length
									))

									elements.push(previous)
								}
								else if previous.kind == NodeKind::Literal {
									previous.value += value
									previous.end.line += 1
									previous.end.column += indent.length
								}
								else {
									previous = AST.Literal(null, value, Position(
										line: previous.end.line:Number + 1
										column: baseIndent.length
									), Position(
										line: previous.end.line:Number + 1
										column: indent.length
									))

									elements.push(previous)
								}
							}

							if ?previous && first.value.kind == NodeKind::Literal {
								previous.value += first.value.value
								previous.end = first.value.end
							}
							else {
								elements.push(first)
							}

							if #rest {
								elements.push(...rest)

								previous = rest[rest.length - 1].value
							}
							else {
								previous = first.value
							}
						}
					}
				}
				else {
					elements.push(...lines[0].slice(1))

					if lines.length > 1 {
						var mut previous = elements[elements.length - 1].value

						for var [indent, first, ...rest], index in lines from 1 {
							if previous.kind == NodeKind::Literal {
								previous.value += '\n'
								previous.end.column += 1
							}
							else {
								previous = AST.Literal(null, '\n', Position(
									line: previous.end.line:Number
									column: previous.end.column:Number + 1
								), Position(
									line: previous.end.line:Number
									column: previous.end.column:Number + 2
								))

								elements.push(previous)
							}

							if first.value.kind == NodeKind::Literal {
								previous.value += first.value.value
								previous.end = first.value.end
							}
							else {
								elements.push(first)
							}

							if #rest {
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

			var modifiers = [@yep(AST.Modifier(ModifierKind::MultiLine, first, last))]

			return @yep(AST.TemplateExpression(modifiers, elements, first, last))
		} # }}}
		reqNameIB(): Event ~ SyntaxError { # {{{
			if @match(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::IDENTIFIER {
				return @reqIdentifier()
			}
			else if @token == Token::LEFT_CURLY {
				return @reqDestructuringObject(@yes(), DestructuringMode::Nil, FunctionMode::Function)
			}
			else if @token == Token::LEFT_SQUARE {
				return @reqDestructuringArray(@yes(), DestructuringMode::Nil, FunctionMode::Function)
			}
			else {
				@throw('Identifier', 'Destructuring')
			}
		} # }}}
		reqNameIST(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @match(Token::IDENTIFIER, Token::STRING, Token::TEMPLATE_BEGIN) == Token::IDENTIFIER {
				return @reqIdentifier()
			}
			else if @token == Token::STRING {
				return @reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return @reqTemplateExpression(@yes(), fMode)
			}
			else {
				@throw('Identifier', 'String', 'Template')
			}
		} # }}}
		reqNamespaceStatement(mut first: Event, name: Event): Event ~ SyntaxError { # {{{
			@NL_0M()

			unless @test(Token::LEFT_CURLY) {
				@throw('{')
			}

			@commit()

			@NL_0M()

			var attributes = []
			var statements = []

			var dyn attrs = []
			var dyn statement

			until @test(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				if @matchM(M.MODULE_STATEMENT) == Token::EXPORT {
					statement = @reqExportStatement(@yes())
				}
				else if @token == Token::EXTERN {
					statement = @reqExternStatement(@yes())
				}
				else if @token == Token::INCLUDE {
					statement = @reqIncludeStatement(@yes())
				}
				else if @token == Token::INCLUDE_AGAIN {
					statement = @reqIncludeAgainStatement(@yes())
				}
				else {
					statement = @reqStatement(FunctionMode::Function)
				}

				AST.pushAttributes(statement.value, attrs)

				statements.push(statement)

				@NL_0M()
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.NamespaceDeclaration(attributes, [], name, statements, first, @yes()))
		} # }}}
		reqNumber(): Event ~ SyntaxError { # {{{
			if (value = @tryNumber()).ok {
				return value
			}
			else {
				@throw('Number')
			}
		} # }}}
		reqNumeralIdentifier(): Event ~ SyntaxError { # {{{
			if @test(Token::IDENTIFIER, Token::NUMERAL) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				@throw('Identifier')
			}
		} # }}}
		reqNL_1M(): Void ~ SyntaxError { # {{{
			if @test(Token::NEWLINE) {
				@commit()

				@skipNewLine()
			}
			else {
				@throw('NewLine')
			}
		} # }}}
		reqNL_EOF_1M(): Void ~ SyntaxError { # {{{
			if @match(Token::NEWLINE) == Token::NEWLINE {
				@commit()

				@skipNewLine()
			}
			else if @token != Token::EOF {
				@throw('NewLine', 'EOF')
			}
		} # }}}
		reqObject(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			var attributes = []
			var properties = []

			until @test(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				properties.push(@reqObjectItem(fMode))

				if @match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
					@commit().NL_0M()
				}
				else if @token == Token::NEWLINE {
					@commit().NL_0M()

					if @test(Token::COMMA) {
						@commit().NL_0M()
					}
				}
				else {
					break
				}
			}

			unless @test(Token::RIGHT_CURLY) {
				@throw('}')
			}

			return @yep(AST.ObjectExpression(attributes, properties, first, @yes()))
		} # }}}
		reqObjectItem(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var dyn first

			var attributes = @stackOuterAttributes([])
			if attributes.length > 0 {
				first = attributes[0]
			}

			if @test(Token::ASYNC) {
				var marker = @mark()

				var async = @yes()

				var name = @tryNameIST(fMode)
				if name.ok {
					var modifiers = [@yep(AST.Modifier(ModifierKind::Async, async))]
					var parameters = @reqFunctionParameterList(fMode)
					var type = @tryFunctionReturns()
					var throws = @tryFunctionThrows()
					var body = @reqFunctionBody(fMode)

					return @yep(AST.ObjectMember(attributes, [], name, null, @yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, parameters, body)), first ?? async ?? name, body))
				}
				else {
					@rollback(marker)
				}
			}

			var late name
			if @match(Token::AT, Token::DOT_DOT_DOT, Token::IDENTIFIER, Token::LEFT_SQUARE, Token::STRING, Token::TEMPLATE_BEGIN) == Token::IDENTIFIER {
				name = @reqIdentifier()
			}
			else if @token == Token::LEFT_SQUARE {
				name = @reqComputedPropertyName(@yes(), fMode)
			}
			else if @token == Token::STRING {
				name = @reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				name = @reqTemplateExpression(@yes(), fMode)
			}
			else if fMode == FunctionMode::Method && @token == Token::AT {
				var name = @reqThisExpression(@yes())
				var expression = @yep(AST.ShorthandProperty(attributes, name, first ?? name, name))

				return @altRestrictiveExpression(expression, fMode)
			}
			else if @token == Token::DOT_DOT_DOT {
				var operator = @yep(AST.UnaryOperator(UnaryOperatorKind::Spread, @yes()))
				var operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)
				var expression = @yep(AST.UnaryExpression(operator, operand, operator, operand))

				return @altRestrictiveExpression(expression, fMode)
			}
			else {
				@throw('Identifier', 'String', 'Template', 'Computed Property Name')
			}

			if @test(Token::COLON) {
				@commit()

				var value = @reqExpression(ExpressionMode::ImplicitMember + ExpressionMode::NoRestriction, fMode, MacroTerminator::Object)
				var expression = @yep(AST.ObjectMember(attributes, [], name, null, value, first ?? name, value))

				return @altRestrictiveExpression(expression, fMode)
			}
			else if @test(Token::LEFT_ROUND) {
				var parameters = @reqFunctionParameterList(fMode)
				var type = @tryFunctionReturns()
				var throws = @tryFunctionThrows()
				var body = @reqFunctionBody(fMode)

				return @yep(AST.ObjectMember(attributes, [], name, null, @yep(AST.FunctionExpression(parameters, null, type, throws, body, parameters, body)), first ?? name, body))
			}
			else if name.value.kind == NodeKind::Identifier {
				var expression = @yep(AST.ShorthandProperty(attributes, name, first ?? name, name))

				return @altRestrictiveExpression(expression, fMode)
			}
			else {
				@throw(':', '(')
			}
		} # }}}
		reqOperand(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var value = @tryOperand(eMode, fMode)

			if value.ok {
				return value
			}
			else {
				@throw()
			}
		} # }}}
		reqOperation(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var dyn mark = @mark()

			var dyn operand, operator

			if (operand = @tryDestructuring(fMode)).ok {
				@NL_0M()

				if (operator = @tryAssignementOperator()).ok {
					var values = [operand.value, AST.BinaryExpression(operator)]

					@NL_0M()

					values.push(@reqBinaryOperand(eMode + ExpressionMode::ImplicitMember, fMode).value)

					return @yep(AST.reorderExpression(values))
				}
			}

			@rollback(mark)

			operand = @reqBinaryOperand(eMode, fMode)

			var values = [operand.value]

			var mut type = false

			repeat {
				mark = @mark()

				@NL_0M()

				if (operator = @tryBinaryOperator()).ok {
					values.push(AST.BinaryExpression(operator))

					@NL_0M()

					values.push(@reqBinaryOperand(eMode + ExpressionMode::ImplicitMember, fMode).value)
				}
				else if !type && (operator = @tryTypeOperator()).ok {
					if mark.line != operator.start.line {
						@rollback(mark)

						break
					}
					else {
						values.push(AST.BinaryExpression(operator), @reqTypeLimited(false).value)

						type = true

						continue
					}
				}
				else if @test(Token::QUESTION_OPERATOR) {
					values.push(AST.ConditionalExpression(@yes()))

					values.push(@reqExpression(ExpressionMode::Default, fMode).value)

					unless @test(Token::COLON) {
						@throw(':')
					}

					@commit()

					values.push(@reqExpression(ExpressionMode::Default, fMode).value)
				}
				else if (operator = @tryJunctionOperator()).ok {
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
		reqParameter(pMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var mut firstAttr = null
			var attributes = @stackInlineAttributes([])
			if attributes.length > 0 {
				firstAttr = attributes[0]
			}

			var mutMark = @mark()
			var mut mutModifier = null

			if @test(Token::MUT) {
				mutModifier = AST.Modifier(ModifierKind::Mutable, @yes())
			}

			var mut positionalModifier = null
			var mut namedModifier = null

			if @test(Token::HASH) {
				positionalModifier = AST.Modifier(ModifierKind::PositionOnly, @yes())
			}
			else if @test(Token::ASTERISK) {
				namedModifier = AST.Modifier(ModifierKind::NameOnly, @yes())
			}

			var mut external = null

			if ?namedModifier {
				var identifier = @tryIdentifier()

				if identifier.ok {
					if @test(Token::PERCENT) {
						@commit()

						external = identifier
					}
					else {
						var modifiers = []
						modifiers.push(mutModifier) if ?mutModifier
						modifiers.push(?positionalModifier ? positionalModifier : namedModifier)

						return @reqParameterIdendifier(attributes, modifiers, null, identifier, true, true, true, true, firstAttr ?? mutModifier ?? positionalModifier ?? namedModifier, fMode)
					}
				}
			}

			if @test(Token::LEFT_CURLY, Token::LEFT_SQUARE) {
				@throw() if fMode == FunctionMode::Macro
				@throw() if ?positionalModifier || (?namedModifier && !?external)

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier
				modifiers.push(namedModifier) if ?namedModifier

				var late internal
				if @token == Token::LEFT_CURLY {
					internal = @reqDestructuringObject(@yes(), pMode, fMode)
				}
				else {
					internal = @reqDestructuringArray(@yes(), pMode, fMode)
				}

				return @reqParameterIdendifier(attributes, modifiers, external, internal, false, true, false, true, firstAttr ?? mutModifier ?? namedModifier ?? external ?? internal, fMode)
			}

			if @test(Token::DOT_DOT_DOT) {
				@throw() if ?positionalModifier || ?namedModifier

				var first = @yes()

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier

				return @reqParameterRest(attributes, modifiers, external, firstAttr ?? mutModifier ?? first, pMode, fMode)
			}

			if @test(Token::AT) {
				@throw() if ?mutModifier

				var modifiers = []
				modifiers.push(namedModifier) if ?namedModifier
				modifiers.push(positionalModifier) if ?positionalModifier

				return @reqParameterAt(attributes, modifiers, external, firstAttr ?? namedModifier ?? positionalModifier, pMode, fMode)
			}

			if @test(Token::UNDERSCORE) {
				@throw() if ?positionalModifier || (?namedModifier && !?external)

				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier
				modifiers.push(namedModifier) if ?namedModifier

				var underscore = @yes()

				return @reqParameterIdendifier(attributes, modifiers, external, null, false, true, true, true, firstAttr ?? mutModifier ?? namedModifier ?? underscore, fMode)
			}

			if ?positionalModifier || ?namedModifier {
				var modifiers = []
				modifiers.push(mutModifier) if ?mutModifier
				modifiers.push(?positionalModifier ? positionalModifier : namedModifier)

				return @reqParameterIdendifier(attributes, modifiers, external, null, true, true, true, true, firstAttr ?? mutModifier ?? namedModifier ?? positionalModifier, fMode)
			}

			do {
				var identifier = @tryIdentifier()

				if identifier.ok {
					var modifiers = []
					modifiers.push(mutModifier) if ?mutModifier

					if pMode !~ DestructuringMode::EXTERNAL_ONLY && @test(Token::PERCENT) {
						@commit()

						if @test(Token::UNDERSCORE) {
							@commit()

							return @reqParameterIdendifier(attributes, modifiers, identifier, null, false, true, true, true, firstAttr ?? mutModifier ?? identifier, fMode)
						}
						else if @test(Token::LEFT_CURLY, Token::LEFT_SQUARE) {
							var late internal
							if @token == Token::LEFT_CURLY {
								internal = @reqDestructuringObject(@yes(), pMode, fMode)
							}
							else {
								internal = @reqDestructuringArray(@yes(), pMode, fMode)
							}

							return @reqParameterIdendifier(attributes, modifiers, identifier, internal, true, true, true, true, firstAttr ?? mutModifier ?? identifier, fMode)
						}
						else if @test(Token::DOT_DOT_DOT) {
							@commit()

							return @reqParameterRest(attributes, modifiers, identifier, firstAttr ?? mutModifier ?? identifier, pMode, fMode)
						}
						else if @test(Token::AT) {
							@throw() if ?mutModifier

							return @reqParameterAt(attributes, modifiers, identifier, firstAttr ?? namedModifier ?? identifier, pMode, fMode)
						}
						else {
							return @reqParameterIdendifier(attributes, modifiers, identifier, null, true, true, true, true, firstAttr ?? mutModifier ?? identifier, fMode)
						}
					}
					else {
						return @reqParameterIdendifier(attributes, modifiers, identifier, identifier, true, true, true, true, firstAttr ?? mutModifier ?? identifier, fMode)
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
		reqParameterAt(attributes, modifiers, external?, first?, pMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if fMode == FunctionMode::Macro {
				var at = @yes()

				modifiers.push(AST.Modifier(ModifierKind::AutoEvaluate, at))

				var internal = @reqIdentifier()

				return @reqParameterIdendifier(attributes, modifiers, external ?? internal, internal, true, true, true, true, first ?? at, fMode)
			}
			else if fMode == FunctionMode::Method && pMode ~~ DestructuringMode::THIS_ALIAS {
				var at = @yes()

				return @reqParameterThis(attributes, modifiers, external, first ?? at, fMode)
			}
			else {
				@throw()
			}
		} # }}}
		reqParameterIdendifier(attributes, modifiers, mut external?, mut internal?, required: Boolean, typed: Boolean, nullable: Boolean, valued: Boolean, mut first?, fMode: FunctionMode): Event ~ SyntaxError { # {{{
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

						if @test(Token::PERCENT) {
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

			if required && ?internal && valued && @test(Token::EXCLAMATION) {
				var modifier = AST.Modifier(ModifierKind::Required, @yes())

				modifiers.push(modifier)

				requireDefault = true
				last = modifier
			}

			if typed && @test(Token::COLON) {
				@commit()

				var type = @reqTypeParameter()
				var operator = @tryParameterAssignment(valued)

				if operator.ok {
					var defaultValue = @reqExpression(ExpressionMode::Default, fMode)

					return @yep(AST.Parameter(attributes, modifiers, external, internal, type, operator, defaultValue, first, defaultValue))
				}
				else if requireDefault {
					@throw('=', '%%=', '##=')
				}
				else {
					return @yep(AST.Parameter(attributes, modifiers, external, internal, type, null, null, first, type))
				}
			}
			else {
				var operator = @tryParameterAssignment(valued)

				if operator.ok {
					var defaultValue = @reqExpression(ExpressionMode::Default, fMode)

					return @yep(AST.Parameter(attributes, modifiers, external, internal, null, operator, defaultValue, first, defaultValue))
				}
				else if nullable && @test(Token::QUESTION) {
					var modifier = AST.Modifier(ModifierKind::Nullable, @yes())

					modifiers.push(modifier)

					var operator = @tryParameterAssignment(valued)

					if operator.ok {
						var defaultValue = @reqExpression(ExpressionMode::Default, fMode)

						return @yep(AST.Parameter(attributes, modifiers, external, internal, null, operator, defaultValue, first, defaultValue))
					}
					else if requireDefault {
						@throw('=', '%%=', '##=')
					}
					else {
						return @yep(AST.Parameter(attributes, modifiers, external, internal, null, null, null, first, modifier))
					}
				}
				else if requireDefault {
					@throw('=', '%%=', '##=')
				}
				else {
					return @yep(AST.Parameter(attributes, modifiers, external, internal, null, null, null, first, last))
				}
			}
		} # }}}
		reqParameterRest(attributes, modifiers, mut external?, first, pMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @test(Token::LEFT_CURLY) {
				@commit()

				var dyn min, max

				if @test(Token::COMMA) {
					@commit()

					min = 0
					max = @reqNumber().value.value
				}
				else {
					min = @reqNumber().value.value

					if @test(Token::COMMA) {
						@commit()

						if @test(Token::RIGHT_CURLY) {
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

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				modifiers.push(AST.RestModifier(min, max, first, @yes()))
			}
			else {
				modifiers.push(AST.RestModifier(0, Infinity, first, first))
			}

			if @test(Token::AT) {
				if fMode == FunctionMode::Method && pMode ~~ DestructuringMode::THIS_ALIAS {
					@commit()

					return @reqParameterThis(attributes, modifiers, external, first, fMode)
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

					return @reqParameterIdendifier(attributes, modifiers, external, identifier, false, true, true, true, first, fMode)
				}

				if ?external && !external.ok {
					external = null
				}

				return @reqParameterIdendifier(attributes, modifiers, external, null, false, true, true, true, first, fMode)
			}
		} # }}}
		reqParameterThis(attributes, modifiers, external?, first, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var name = @reqThisExpression(first)
			var operator = @tryParameterAssignment(true)

			if operator.ok {
				var defaultValue = @reqExpression(ExpressionMode::Default, fMode)

				return @yep(AST.Parameter(attributes, modifiers, external ?? @yep(name.value.name), name, null, operator, defaultValue, first ?? name, defaultValue))
			}
			else {
				return @yep(AST.Parameter(attributes, modifiers, external ?? @yep(name.value.name), name, null, null, null, first ?? name, name))
			}
		} # }}}
		reqParenthesis(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @test(Token::NEWLINE) {
				@commit().NL_0M()

				var expression = @reqExpression(null, fMode, MacroTerminator::Parenthesis)

				@NL_0M()

				unless @test(Token::RIGHT_ROUND) {
					@throw(')')
				}

				@relocate(expression, first, @yes())

				return expression
			}
			else {
				var expressions = [@reqExpression(null, fMode, MacroTerminator::List)]

				while @test(Token::COMMA) {
					@commit()

					expressions.push(@reqExpression(null, fMode, MacroTerminator::List))
				}

				unless @test(Token::RIGHT_ROUND) {
					@throw(')')
				}

				if expressions.length == 1 {
					@relocate(expressions[0], first, @yes())

					return expressions[0]
				}
				else {
					return @yep(AST.SequenceExpression(expressions, first, @yes()))
				}
			}
		} # }}}
		reqPassStatement(first: Event): Event ~ SyntaxError { # {{{
			return @yep(AST.PassStatement(first))
		} # }}}
		reqPickStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var expression = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

			if @match(Token::IF, Token::UNLESS) == Token::IF {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				return @yep(AST.IfStatement(condition, null, @yep(AST.PickStatement(expression, first, expression)), null, first, condition))
			}
			else if @token == Token::UNLESS {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				return @yep(AST.UnlessStatement(condition, @yep(AST.PickStatement(expression, first, expression)), first, condition))
			}
			else {
				return @yep(AST.PickStatement(expression, first, expression))
			}
		} # }}}
		reqPostfixedOperand(mut operand: Event?, mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			operand = @reqUnaryOperand(operand, eMode, fMode)

			var dyn operator
			match @matchM(M.POSTFIX_OPERATOR) {
				Token::EXCLAMATION_EXCLAMATION {
					operator = @yep(AST.UnaryOperator(UnaryOperatorKind::ForcedTypeCasting, @yes()))
				}
				Token::EXCLAMATION_QUESTION {
					operator = @yep(AST.UnaryOperator(UnaryOperatorKind::NullableTypeCasting, @yes()))
				}
				else {
					return operand
				}
			}

			return @reqPostfixedOperand(@yep(AST.UnaryExpression(operator, operand, operand, operator)), eMode, fMode)
		} # }}}
		reqPrefixedOperand(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var mark = @mark()

			match @matchM(M.PREFIX_OPERATOR, eMode) {
				Token::DOT {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind::Implicit, @yes()))
					var operand = @tryIdentifier()

					if operand.ok {
						return @yep(AST.UnaryExpression(operator, operand, operator, operand))
					}
					else {
						@rollback(mark)
					}
				}
				Token::DOT_DOT_DOT {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind::Spread, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::EXCLAMATION {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind::Negation, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::HASH {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind::NonEmpty, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::MINUS {
					var first = @yes()
					var operand = @reqPrefixedOperand(eMode, fMode)

					if operand.value.kind == NodeKind::NumericExpression {
						operand.value.value = -operand.value.value

						return @relocate(operand, first, null)
					}
					else {
						var operator = @yep(AST.UnaryOperator(UnaryOperatorKind::Negative, first))

						return @yep(AST.UnaryExpression(operator, operand, operator, operand))
					}
				}
				Token::QUESTION {
					var operator = @yep(AST.UnaryOperator(UnaryOperatorKind::Existential, @yes()))
					var operand = @reqPrefixedOperand(eMode, fMode)

					return @yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
			}

			return @reqPostfixedOperand(null, eMode, fMode)
		} # }}}
		reqRepeatStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			if @test(Token::LEFT_CURLY) {
				var block = @reqBlock(NO, fMode)

				return @yep(AST.RepeatStatement(null, block, first, block))
			}
			else {
				var expression = @reqExpression(ExpressionMode::Default, fMode)

				unless @test(Token::TIMES) {
					@throw('times')
				}

				@commit().NL_0M()

				var block = @reqBlock(NO, fMode)

				return @yep(AST.RepeatStatement(expression, block, first, block))
			}
		} # }}}
		reqRequireStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.RequireDeclaration(attributes, declarations, first, last))
		} # }}}
		reqRequireOrExternStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var attributes = []
			var declarations = []
			var last = @reqExternalDeclarations(attributes, declarations)

			return @yep(AST.RequireOrExternDeclaration(attributes, declarations, first, last))
		} # }}}
		reqRequireOrImportStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var attributes = []
			var declarations = []

			var dyn last
			if @test(Token::LEFT_CURLY) {
				@commit().reqNL_1M()

				var dyn attrs = []
				var dyn declarator

				until @test(Token::RIGHT_CURLY) {
					if @stackInnerAttributes(attributes) {
						continue
					}

					@stackOuterAttributes(attrs)

					declarator = @reqImportDeclarator()

					AST.pushAttributes(declarator.value, attrs)

					declarations.push(declarator)

					if @test(Token::NEWLINE) {
						@commit().NL_0M()
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_CURLY) {
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
		reqReturnStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @match(Token::IF, Token::UNLESS, Token::NEWLINE) == Token::IF {
				var mark = @mark()

				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				if @test(Token::NEWLINE) || @token == Token::EOF {
					return @yep(AST.IfStatement(condition, null, @yep(AST.ReturnStatement(first)), null, first, condition))
				}
				else {
					@rollback(mark)
				}
			}
			else if @token == Token::NEWLINE || @token == Token::EOF {
				return @yep(AST.ReturnStatement(first))
			}
			else if @token == Token::UNLESS {
				var mark = @mark()

				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				if @test(Token::NEWLINE) || @token == Token::EOF {
					return @yep(AST.UnlessStatement(condition, @yep(AST.ReturnStatement(first)), first, condition))
				}
				else {
					@rollback(mark)
				}
			}

			var expression = @tryExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

			unless expression.ok {
				return NO
			}

			if @match(Token::IF, Token::UNLESS) == Token::IF {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				return @yep(AST.IfStatement(condition, null, @yep(AST.ReturnStatement(expression, first, expression)), null, first, condition))
			}
			else if @token == Token::UNLESS {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				return @yep(AST.UnlessStatement(condition, @yep(AST.ReturnStatement(expression, first, expression)), first, condition))
			}
			else {
				return @yep(AST.ReturnStatement(expression, first, expression))
			}
		} # }}}
		reqSeparator(token: Token): Void ~ SyntaxError { # {{{
			if @match(Token::COMMA, Token::NEWLINE, token) == Token::COMMA {
				@commit()

				if @test(token) {
					@throw()
				}

				@skipNewLine()
			}
			else if @token == Token::NEWLINE {
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
		reqStatement(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var mark = @mark()

			var dyn statement = NO

			match @matchM(M.STATEMENT, @mode) {
				Token::ABSTRACT {
					var first = @yes()

					if @test(Token::CLASS) {
						@commit()

						var modifiers = [@yep(AST.Modifier(ModifierKind::Abstract, first))]

						statement = @reqClassStatement(first, modifiers)
					}
					else {
						statement = NO
					}
				}
				Token::ASYNC {
					var first = @yes()

					if @test(Token::FUNC) {
						@commit()

						var modifiers = [@yep(AST.Modifier(ModifierKind::Async, first))]

						statement = @reqFunctionStatement(first, modifiers)
					}
					else {
						statement = NO
					}
				}
				Token::BITMASK {
					statement = @reqBitmaskStatement(@yes())
				}
				Token::BLOCK {
					statement = @tryBlockStatement(@yes(), fMode)
				}
				Token::BREAK {
					statement = @reqBreakStatement(@yes(), fMode)
				}
				Token::CLASS {
					statement = @tryClassStatement(@yes())
				}
				Token::CONTINUE {
					statement = @reqContinueStatement(@yes(), fMode)
				}
				Token::DELETE {
					statement = @tryDestroyStatement(@yes(), fMode)
				}
				Token::DO {
					statement = @reqDoStatement(@yes(), fMode)
				}
				Token::ENUM {
					statement = @reqEnumStatement(@yes())
				}
				Token::FALLTHROUGH {
					statement = @reqFallthroughStatement(@yes())
				}
				Token::FINAL {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(ModifierKind::Immutable, first))]

					if @test(Token::CLASS) {
						@commit()

						statement = @reqClassStatement(first, modifiers)
					}
					else if @test(Token::ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(ModifierKind::Abstract, @yes())))

						if @test(Token::CLASS) {
							@commit()

							statement = @reqClassStatement(first, modifiers)
						}
						else {
							@throw('class')
						}
					}
					else {
						statement = NO
					}
				}
				Token::FOR {
					statement = @reqForStatement(@yes(), fMode)
				}
				Token::FUNC {
					statement = @reqFunctionStatement(@yes())
				}
				Token::IF {
					statement = @reqIfStatement(@yes(), fMode)
				}
				Token::IMPL {
					statement = @reqImplementStatement(@yes())
				}
				Token::IMPORT {
					statement = @reqImportStatement(@yes())
				}
				Token::MACRO {
					if @mode !~ ParserMode::MacroExpression {
						statement = @tryMacroStatement(@yes())
					}
					else {
						statement = @reqMacroExpression(@yes())
					}
				}
				Token::MATCH {
					statement = @tryMatchStatement(@yes(), fMode)
				}
				Token::NAMESPACE {
					statement = @tryNamespaceStatement(@yes())
				}
				Token::PASS {
					statement = @reqPassStatement(@yes())
				}
				Token::PICK {
					statement = @reqPickStatement(@yes(), fMode)
				}
				Token::REPEAT {
					statement = @reqRepeatStatement(@yes(), fMode)
				}
				Token::RETURN {
					statement = @reqReturnStatement(@yes(), fMode)
				}
				Token::SEALED {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(ModifierKind::Sealed, first))]

					if @test(Token::CLASS) {
						@commit()

						statement = @reqClassStatement(first, modifiers)
					}
					else if @test(Token::ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(ModifierKind::Abstract, @yes())))

						if @test(Token::CLASS) {
							@commit()

							statement = @reqClassStatement(first, modifiers)
						}
						else {
							@throw('class')
						}
					}
					else {
						statement = NO
					}
				}
				Token::STRUCT {
					statement = @reqStructStatement(@yes())
				}
				Token::THROW {
					statement = @reqThrowStatement(@yes(), fMode)
				}
				Token::TRY {
					statement = @reqTryStatement(@yes(), fMode)
				}
				Token::TUPLE {
					statement = @reqTupleStatement(@yes())
				}
				Token::TYPE {
					statement = @tryTypeStatement(@yes())
				}
				Token::UNLESS {
					statement = @reqUnlessStatement(@yes(), fMode)
				}
				Token::UNTIL {
					statement = @tryUntilStatement(@yes(), fMode)
				}
				Token::VAR {
					statement = @tryVarStatement(@yes(), ExpressionMode::Default, fMode)
				}
				Token::WHILE {
					statement = @tryWhileStatement(@yes(), fMode)
				}
				Token::WITH {
					statement = @tryWithStatement(@yes(), fMode)
				}
			}

			unless statement.ok {
				@rollback(mark)

				if !(statement = @tryAssignementStatement(fMode)).ok {
					@rollback(mark)

					statement = @reqExpressionStatement(fMode)
				}
			}

			@reqNL_EOF_1M()

			return statement
		} # }}}
		reqString(): Event ~ SyntaxError { # {{{
			if @test(Token::STRING) {
				return @yep(AST.Literal(null, @value(), @yes()))
			}
			else {
				@throw('String')
			}
		} # }}}
		reqStructStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			var attributes = []
			var elements = []
			var dyn extends = null
			var dyn last = name

			if @test(Token::EXTENDS) {
				@commit()

				extends = @reqIdentifier()
			}

			if @test(Token::LEFT_CURLY) {
				var first = @yes()

				@NL_0M()

				@stackInnerAttributes(attributes)

				until @test(Token::RIGHT_CURLY) {
					var mut first = null

					var attributes = @stackOuterAttributes([])
					if attributes.length != 0 {
						first = attributes[0]
					}

					var modifiers = []

					var name = @reqIdentifier()

					var mut last = name

					var mut type = null
					if @test(Token::COLON) {
						@commit()

						type = @reqType()

						last = type
					}
					else if @test(Token::QUESTION) {
						var modifier = @yep(AST.Modifier(ModifierKind::Nullable, @yes()))

						modifiers.push(modifier)

						last = modifier
					}

					var dyn defaultValue = null
					if @test(Token::EQUALS) {
						@commit()

						defaultValue = @reqExpression(ExpressionMode::Default + ExpressionMode::ImplicitMember, FunctionMode::Function)

						last = defaultValue
					}

					elements.push(AST.StructField(attributes, modifiers, name, type, defaultValue, first ?? name, last))

					if @match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
						@commit().NL_0M()
					}
					else if @token == Token::NEWLINE {
						@commit().NL_0M()

						if @test(Token::COMMA) {
							@commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				last = @yes()
			}

			return @yep(AST.StructDeclaration(attributes, [], name, extends, elements, first, last))
		} # }}}
		reqTemplateExpression(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var elements = []

			repeat {
				if @matchM(M.TEMPLATE) == Token::TEMPLATE_ELEMENT {
					@commit()

					elements.push(@reqExpression(ExpressionMode::Default, fMode))

					unless @test(Token::RIGHT_ROUND) {
						@throw(')')
					}

					@commit()
				}
				else if @token == Token::TEMPLATE_VALUE {
					elements.push(@yep(AST.Literal(null, @scanner.value(), @yes())))
				}
				else {
					break
				}
			}

			unless @test(Token::TEMPLATE_END) {
				@throw('`')
			}

			return @yep(AST.TemplateExpression(null, elements, first, @yes()))
		} # }}}
		reqThisExpression(mut first: Event): Event ~ SyntaxError { # {{{
			var identifier = @reqIdentifier()

			return @yep(AST.ThisExpression(identifier, first, identifier))
		} # }}}
		reqThrowStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var expression = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

			if @match(Token::IF, Token::UNLESS) == Token::IF {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				return @yep(AST.IfStatement(condition, null, @yep(AST.ThrowStatement(expression, first, expression)), null, first, condition))
			}
			else if @token == Token::UNLESS {
				@commit()

				var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::NoRestriction, fMode)

				return @yep(AST.UnlessStatement(condition, @yep(AST.ThrowStatement(expression, first, expression)), first, condition))
			}
			else {
				return @yep(AST.ThrowStatement(expression, first, expression))
			}
		} # }}}
		reqTryCatchClause(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var dyn binding
			if @test(Token::IDENTIFIER) {
				binding = @reqIdentifier()
			}

			@NL_0M()

			var body = @reqBlock(NO, fMode)

			return @yep(AST.CatchClause(binding, null, body, first, body))
		} # }}}
		reqTryExpression(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var modifiers = []
			if @testNS(Token::EXCLAMATION) {
				modifiers.push(AST.Modifier(ModifierKind::Disabled, @yes()))
			}

			var operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)

			var dyn default = null

			if @test(Token::TILDE) {
				@commit()

				default = @reqPrefixedOperand(ExpressionMode::Default, fMode)
			}

			return @yep(AST.TryExpression(modifiers, operand, default, first, default ?? operand))
		} # }}}
		reqTryStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			@NL_0M()

			var body = @tryBlock(fMode)

			unless body.ok {
				return NO
			}

			var mut last = body

			var mut mark = @mark()

			var catchClauses = []
			var dyn catchClause, finalizer

			@NL_0M()

			if @test(Token::ON) {
				do {
					catchClauses.push(last <- @reqCatchOnClause(@yes(), fMode))

					mark = @mark()

					@NL_0M()
				}
				while @test(Token::ON)
			}
			else {
				@rollback(mark)

				@NL_0M()
			}

			if @test(Token::CATCH) {
				catchClause = last = @reqTryCatchClause(@yes(), fMode)

				mark = @mark()
			}
			else {
				@rollback(mark)
			}

			@NL_0M()

			if @test(Token::FINALLY) {
				@commit()

				finalizer = last = @reqBlock(NO, fMode)
			}
			else {
				@rollback(mark)
			}

			return @yep(AST.TryStatement(body, catchClauses, catchClause, finalizer, first, last))
		} # }}}
		reqTupleStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			var attributes = []
			var modifiers = []
			var elements = []
			var dyn extends = null
			var dyn last = name

			if @test(Token::EXTENDS) {
				@commit()

				extends = @reqIdentifier()
			}

			if extends == null && @test(Token::LEFT_ROUND) {
				var first = @yes()

				@NL_0M()

				@stackInnerAttributes(attributes)

				until @test(Token::RIGHT_ROUND) {
					var mut first = null

					var attributes = @stackOuterAttributes([])
					if attributes.length != 0 {
						first = attributes[0]
					}

					var type = @reqType()

					if @test(Token::EQUALS) {
						@commit()

						var defaultValue = @reqExpression(ExpressionMode::Default + ExpressionMode::ImplicitMember, FunctionMode::Function)

						elements.push(AST.TupleField(attributes, [], null, type, defaultValue, first ?? type, defaultValue))
					}
					else {
						elements.push(AST.TupleField(attributes, [], null, type, null, first ?? type, type))
					}

					if @match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
						@commit().NL_0M()
					}
					else if @token == Token::NEWLINE {
						@commit().NL_0M()

						if @test(Token::COMMA) {
							@commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_ROUND) {
					@throw(')')
				}

				last = @yes()

				if @test(Token::EXTENDS) {
					@commit()

					last = extends = @reqIdentifier()
				}
			}
			else if @test(Token::LEFT_CURLY) {
				var first = @yes()

				@NL_0M()

				modifiers.push(@yep(AST.Modifier(ModifierKind::Named, first)))

				@stackInnerAttributes(attributes)

				until @test(Token::RIGHT_CURLY) {
					var mut first = null

					var attributes = @stackOuterAttributes([])
					if attributes.length != 0 {
						first = attributes[0]
					}

					var modifiers = []

					var name = @reqIdentifier()

					var mut last = name

					var mut type = null
					if @test(Token::COLON) {
						@commit()

						type = @reqType()

						last = name
					}
					else if @test(Token::QUESTION) {
						var modifier = @yep(AST.Modifier(ModifierKind::Nullable, @yes()))

						modifiers.push(modifier)

						last = modifier
					}

					var dyn defaultValue = null
					if @test(Token::EQUALS) {
						@commit()

						defaultValue = @reqExpression(ExpressionMode::Default + ExpressionMode::ImplicitMember, FunctionMode::Function)

						last = defaultValue
					}

					elements.push(AST.TupleField(attributes, modifiers, name, type, defaultValue, first ?? name, last))

					if @match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
						@commit().NL_0M()
					}
					else if @token == Token::NEWLINE {
						@commit().NL_0M()

						if @test(Token::COMMA) {
							@commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw(']')
				}

				last = @yes()
			}

			return @yep(AST.TupleDeclaration(attributes, modifiers, name, extends, elements, first, last))
		} # }}}
		reqType(modifiers: Array = [], multiline: Boolean = false): Event ~ SyntaxError { # {{{
			var type = @tryType(modifiers, multiline)

			if type.ok {
				return type
			}
			else {
				@throw('type')
			}
		} # }}}
		reqTypeCore(modifiers: Array = [], multiline: Boolean): Event ~ SyntaxError { # {{{
			var type = @tryTypeCore(modifiers, multiline)

			if type.ok {
				return type
			}
			else {
				@throw('type')
			}
		} # }}}
		reqTypeDescriptive(tMode: TypeMode = TypeMode::Default): Event ~ SyntaxError { # {{{
			var type = @tryTypeDescriptive(tMode)

			if type.ok {
				return type
			}
			else if #type.value {
				@throw(...type.value)
			}
			else {
				@throw('type')
			}
		} # }}}
		reqTypeLimited(modifiers: Array = [], nullable: Boolean = true): Event ~ SyntaxError { # {{{
			var type = @tryTypeLimited(modifiers)

			if type.ok {
				return @altTypeContainer(type, nullable)
			}
			else {
				return NO
			}
		} # }}}
		reqTypeEntity(): Event ~ SyntaxError { # {{{
			var mut name = @reqIdentifier()

			if @testNS(Token::DOT) {
				do {
					@commit()

					var property = @reqIdentifier()

					name = @yep(AST.MemberExpression([], name, property))
				}
				while @testNS(Token::DOT)
			}

			return @yep(AST.TypeReference([], name, null, name, name))
		} # }}}
		reqTypeGeneric(mut first: Event): Event ~ SyntaxError { # {{{
			var types = [@reqTypeEntity()]

			while @test(Token::COMMA) {
				@commit()

				types.push(@reqTypeEntity())
			}

			unless @test(Token::RIGHT_ANGLE) {
				@throw('>')
			}

			return @yes(types)
		} # }}}
		reqTypeModule(first: Event): Event ~ SyntaxError { # {{{
			@reqNL_1M()

			var types = []
			var attributes = []
			var mut attrs = []

			while @until(Token::RIGHT_CURLY) {
				if @stackInnerAttributes(attributes) {
					continue
				}

				@stackOuterAttributes(attrs)

				var type = @reqTypeDescriptive(TypeMode::Module)

				@reqNL_1M()

				AST.pushAttributes(type.value, attrs)

				types.push(type)
			}

			@throw('}') unless @test(Token::RIGHT_CURLY)

			return @yep(AST.TypeList(attributes, types, first, @yes()))
		} # }}}
		reqTypeParameter(): Event ~ SyntaxError { # {{{
			var type = @tryType()

			if @match(Token::PIPE_PIPE, Token::AMPERSAND_AMPERSAND) == Token::PIPE_PIPE {
				var types = [type]

				do {
					@commit()

					types.push(@reqType())
				}
				while @test(Token::PIPE_PIPE)

				return @yep(AST.UnionType(types, type, types[types.length - 1]))
			}
			else if @token == Token::AMPERSAND_AMPERSAND {
				var types = [type]

				do {
					@commit()

					types.push(@reqType())
				}
				while @test(Token::AMPERSAND_AMPERSAND)

				return @yep(AST.UnionType(types, type, types[types.length - 1]))
			}
			else {
				return type
			}
		} # }}}
		reqTypeStatement(mut first: Event, name: Event): Event ~ SyntaxError { # {{{
			unless @test(Token::EQUALS) {
				@throw('=')
			}

			@commit().NL_0M()

			var type = @reqType(true)

			return @yep(AST.TypeAliasDeclaration(name, type, first, type))
		} # }}}
		reqTypedVariable(fMode: FunctionMode, typeable: Boolean = true, questionable: Boolean = true): Event ~ SyntaxError { # {{{
			var mut name = null

			if @match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY {
				name = @reqDestructuringObject(@yes(), DestructuringMode::Declaration, fMode)
			}
			else if @token == Token::LEFT_SQUARE {
				name = @reqDestructuringArray(@yes(), DestructuringMode::Declaration, fMode)
			}
			else {
				name = @tryIdentifier()

				@throw('Identifier', '{', '[') unless name.ok
			}

			if typeable {
				if @test(Token::COLON) {
					@commit()

					var type = @reqType()

					return @yep(AST.VariableDeclarator([], name, type, name, type))
				}
				else if questionable && @test(Token::QUESTION) {
					var modifier = @yep(AST.Modifier(ModifierKind::Nullable, @yes()))

					return @yep(AST.VariableDeclarator([modifier], name, null, name, modifier))
				}
			}

			return @yep(AST.VariableDeclarator([], name, null, name, name))
		} # }}}
		reqUnaryOperand(mut value: Event?, mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if value == null {
				value = @reqOperand(eMode, fMode)
			}

			var mut broken: [Event, Event]? = null

			var dyn expression, mark, first

			repeat {
				match @matchM(M.OPERAND_JUNCTION) {
					Token::ASTERISK_ASTERISK_LEFT_ROUND {
						@commit()

						value = @yep(AST.CallExpression([], AST.Scope(ScopeKind::Null), value, @reqArgumentList(fMode), value, @yes()))
					}
					Token::ASTERISK_DOLLAR_LEFT_ROUND {
						@commit()

						var arguments = @reqArgumentList(fMode)

						value = @yep(AST.CallExpression([], AST.Scope(ScopeKind::Argument, arguments.value.shift()), value, arguments, value, @yes()))
					}
					Token::CARET_AT_LEFT_ROUND {
						@commit()

						value = @yep(AST.CurryExpression(AST.Scope(ScopeKind::This), value, @reqArgumentList(fMode), value, @yes()))
					}
					Token::CARET_CARET_LEFT_ROUND {
						@commit()

						value = @yep(AST.CurryExpression(AST.Scope(ScopeKind::Null), value, @reqArgumentList(fMode), value, @yes()))
					}
					Token::CARET_DOLLAR_LEFT_ROUND {
						@commit()

						var arguments = @reqArgumentList(fMode)

						value = @yep(AST.CurryExpression(AST.Scope(ScopeKind::Argument, arguments.value.shift()), value, arguments, value, @yes()))
					}
					Token::COLON {
						first = @yes()

						expression = @reqIdentifier()

						value = @yep(AST.BinaryExpression(value, @yep(AST.BinaryOperator(BinaryOperatorKind::TypeCasting, first)), @yep(AST.TypeReference(expression)), value, expression))
					}
					Token::COLON_COLON {
						@commit()

						expression = @reqIdentifier()

						value = @yep(AST.EnumExpression(value, expression))
					}
					Token::COLON_EXCLAMATION {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Forced, first)], BinaryOperatorKind::TypeCasting, first))

						expression = @reqIdentifier()

						value = @yep(AST.BinaryExpression(value, operator, @yep(AST.TypeReference(expression)), value, expression))
					}
					Token::COLON_QUESTION {
						first = @yes()

						var operator = @yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Nullable, first)], BinaryOperatorKind::TypeCasting, first))

						expression = @reqIdentifier()

						value = @yep(AST.BinaryExpression(value, operator, @yep(AST.TypeReference(expression)), value, expression))
					}
					Token::DOT {
						@commit()

						value = @yep(AST.MemberExpression([], value, @reqNumeralIdentifier()))
					}
					Token::LEFT_SQUARE {
						var modifiers = [AST.Modifier(ModifierKind::Computed, @yes())]

						expression = @reqExpression(ExpressionMode::Default, fMode)

						unless @test(Token::RIGHT_SQUARE) {
							@throw(']')
						}

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, @yes()))
					}
					Token::LEFT_ROUND {
						@commit()

						value = @yep(AST.CallExpression([], value, @reqArgumentList(fMode), value, @yes()))
					}
					Token::NEWLINE {
						if eMode ~~ ExpressionMode::EndOfLine {
							break
						}

						mark = @mark()

						@commit().NL_0M()

						if @test(Token::DOT) {
							@commit()

							var oldValue = value

							value = @yep(AST.MemberExpression([], value, @reqIdentifier()))

							if eMode ~~ ExpressionMode::Arrow {
								if @test(Token::EQUALS_RIGHT_ANGLE) {
									@rollback(mark)

									return oldValue
								}
							}

							broken = [oldValue, value]
						}
						else {
							@rollback(mark)

							break
						}
					}
					Token::QUESTION_DOT {
						var modifiers = [AST.Modifier(ModifierKind::Nullable, @yes())]

						expression = @reqIdentifier()

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, expression))
					}
					Token::QUESTION_LEFT_ROUND {
						var modifiers = [AST.Modifier(ModifierKind::Nullable, @yes())]

						value = @yep(AST.CallExpression(modifiers, AST.Scope(ScopeKind::This), value, @reqArgumentList(fMode), value, @yes()))
					}
					Token::QUESTION_LEFT_SQUARE {
						var position = @yes()
						var modifiers = [AST.Modifier(ModifierKind::Nullable, position), AST.Modifier(ModifierKind::Computed, position)]

						expression = @reqExpression(ExpressionMode::Default, fMode)

						unless @test(Token::RIGHT_SQUARE) {
							@throw(']')
						}

						value = @yep(AST.MemberExpression(modifiers, value, expression, value, @yes()))
					}
					Token::TEMPLATE_BEGIN {
						value = @yep(AST.TaggedTemplateExpression(value, @reqTemplateExpression(@yes(), fMode), value, @yes()))
					}
					else {
						break
					}
				}

				if eMode !~ ExpressionMode::NoRestriction || ?broken {
					mark = @mark()

					if @test(Token::IF, Token::UNLESS) {
						var kind = @token == Token::IF ? RestrictiveOperatorKind::If : RestrictiveOperatorKind::Unless
						var operator = @yep(AST.RestrictiveOperator(kind, @yes()))
						var condition = @reqExpression(ExpressionMode::Default + ExpressionMode::EndOfLine, fMode)

						if @test(Token::NEWLINE) || @token == Token::EOF {
							if var [mainExpression, disruptedExpression] ?= broken {
								disruptedExpression.value.object = AST.Reference('main', disruptedExpression.value.object)

								value = @yep(AST.DisruptiveExpression(operator, condition, mainExpression, value, mainExpression, condition))

								if eMode !~ ExpressionMode::Arrow {
									mark = @mark()

									@commit().NL_0M()

									if @test(Token::DOT) {
										@commit()

										var oldValue = value

										value = @yep(AST.MemberExpression([], value, @reqIdentifier()))

										broken = [oldValue, value]
									}
									else {
										@rollback(mark)

										break
									}
								}
							}
							else {
								return @yep(AST.RestrictiveExpression(operator, condition, value, value, condition))
							}
						}
						else {
							@rollback(mark)
						}
					}
				}
			}

			return value
		} # }}}
		reqUnlessStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var condition = @reqExpression(ExpressionMode::Default, fMode)

			@NL_0M()

			var whenFalse = @reqBlock(NO, fMode)

			return @yep(AST.UnlessStatement(condition, whenFalse, first, whenFalse))
		} # }}}
		reqVarStatement(mut first: Event, mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var statement = @tryVarStatement(first, eMode, fMode)

			if statement.ok {
				return statement
			}
			else {
				@throw('Identifier', '{', '[')
			}
		} # }}}
		reqVariable(): Event ~ SyntaxError { # {{{
			var name = @reqIdentifier()

			return @yep(AST.VariableDeclarator([], name, null, name, name))
		} # }}}
		reqVariableIdentifier(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @match(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::IDENTIFIER {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else if @token == Token::LEFT_CURLY {
				return @reqDestructuringObject(@yes(), DestructuringMode::Expression, fMode)
			}
			else if @token == Token::LEFT_SQUARE {
				return @reqDestructuringArray(@yes(), DestructuringMode::Expression, fMode)
			}
			else {
				@throw('Identifier', '{', '[')
			}
		} # }}}
		reqVariableName(mut object: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if !object.ok {
				if fMode == FunctionMode::Method && @test(Token::AT) {
					object = @reqThisExpression(@yes())
				}
				else {
					object = @reqIdentifier()
				}
			}

			var dyn property
			while true {
				if @match(Token::DOT, Token::LEFT_SQUARE) == Token::DOT {
					@commit()

					property = @reqIdentifier()

					object = @yep(AST.MemberExpression([], object, property))
				}
				else if @token == Token::LEFT_SQUARE {
					var modifiers = [AST.Modifier(ModifierKind::Computed, @yes())]

					property = @reqExpression(ExpressionMode::Default, fMode)

					unless @test(Token::RIGHT_SQUARE) {
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
		stackInlineAttributes(attributes: Array): Array ~ SyntaxError { # {{{
			while @test(Token::HASH_LEFT_SQUARE) {
				attributes.push(@reqAttribute(@yes(), false))
			}

			return attributes
		} # }}}
		stackInnerAttributes(attributes: Array): Boolean ~ SyntaxError { # {{{
			if @test(Token::HASH_EXCLAMATION_LEFT_SQUARE) {
				do {
					var first = @yes()
					var declaration = @reqAttributeMember()

					unless @test(Token::RIGHT_SQUARE) {
						@throw(']')
					}

					attributes.push(@yep(AST.AttributeDeclaration(declaration, first, @yes())))

					@reqNL_EOF_1M()
				}
				while @test(Token::HASH_EXCLAMATION_LEFT_SQUARE)

				return true
			}
			else {
				return false
			}
		} # }}}
		stackOuterAttributes(attributes: Array): Array ~ SyntaxError { # {{{
			while @test(Token::HASH_LEFT_SQUARE) {
				attributes.push(@reqAttribute(@yes(), true))

				@NL_0M()
			}

			return attributes
		} # }}}
		submitEnumMember(attributes: Array, modifiers: Array, identifier: Event, token: Token?, members: Array): Void ~ SyntaxError { # {{{
			var first = attributes[0] ?? modifiers[0] ?? identifier

			match token ?? @match(Token::EQUALS, Token::LEFT_ROUND)  {
				Token::EQUALS {
					if @mode ~~ ParserMode::Typing {
						@throw()
					}

					@commit()

					var value = @reqExpression(ExpressionMode::Default, FunctionMode::Function)

					members.push(AST.FieldDeclaration(attributes, modifiers, identifier, null, value, first, value))

					@reqNL_1M()
				}
				Token::LEFT_ROUND {
					members.push(@reqEnumMethod(attributes, modifiers, identifier, first).value)
				}
				when token == null {
					members.push(AST.FieldDeclaration(attributes, modifiers, identifier, null, null, first, identifier))

					@reqNL_1M()
				}
			}
		} # }}}
		submitNamedGroupSpecifier(modifiers: Array, type: Event?, specifiers: Array): Void ~ SyntaxError { # {{{
			var elements = []

			var name = @reqNameIB()

			elements.push(@yep(AST.NamedSpecifier(name)))

			while @test(Token::COMMA) {
				@commit()

				var name = @reqNameIB()

				elements.push(@yep(AST.NamedSpecifier(name)))
			}

			var first = #modifiers ? modifiers[0] : name
			var last = elements[elements.length - 1]

			specifiers.push(@yep(AST.GroupSpecifier(modifiers, elements, type, first, last)))
		} # }}}
		submitNamedSpecifier(modifiers: Array, specifiers: Array): Void ~ SyntaxError { # {{{
			var identifier = @reqIdentifier()

			if @test(Token::EQUALS_RIGHT_ANGLE) {
				@commit()

				var internal = @reqNameIB()

				specifiers.push(@yep(AST.NamedSpecifier(modifiers, internal, identifier, identifier, internal)))
			}
			else {
				specifiers.push(@yep(AST.NamedSpecifier(modifiers, identifier, null, identifier, identifier)))
			}
		} # }}}
		tryAccessModifier(): Event ~ SyntaxError { # {{{
			if @match(Token::PRIVATE, Token::PROTECTED, Token::PUBLIC, Token::INTERNAL) == Token::PRIVATE {
				return @yep(AST.Modifier(ModifierKind::Private, @yes()))
			}
			else if @token == Token::PROTECTED {
				return @yep(AST.Modifier(ModifierKind::Protected, @yes()))
			}
			else if @token == Token::PUBLIC {
				return @yep(AST.Modifier(ModifierKind::Public, @yes()))
			}
			else if @token == Token::INTERNAL {
				return @yep(AST.Modifier(ModifierKind::Internal, @yes()))
			}

			return NO
		} # }}}
		tryAssignementOperator(): Event ~ SyntaxError { # {{{
			match @matchM(M.ASSIGNEMENT_OPERATOR) {
				Token::AMPERSAND_AMPERSAND_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::And, @yes()))
				}
				Token::ASTERISK_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Multiplication, @yes()))
				}
				Token::CARET_CARET_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Xor, @yes()))
				}
				Token::EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Equals, @yes()))
				}
				Token::EXCLAMATION_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Empty, @yes()))
				}
				Token::EXCLAMATION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::NonExistential, @yes()))
				}
				Token::HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::NonEmpty, @yes()))
				}
				Token::HASH_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::EmptyCoalescing, @yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::LeftShift, @yes()))
				}
				Token::LEFT_ANGLE_MINUS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Return, @yes()))
				}
				Token::MINUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Subtraction, @yes()))
				}
				Token::PERCENT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Modulo, @yes()))
				}
				Token::PIPE_PIPE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Or, @yes()))
				}
				Token::PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Addition, @yes()))
				}
				Token::QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Existential, @yes()))
				}
				Token::QUESTION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::NullCoalescing, @yes()))
				}
				Token::RIGHT_ANGLE_RIGHT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::RightShift, @yes()))
				}
				Token::SLASH_DOT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Quotient, @yes()))
				}
				Token::SLASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Division, @yes()))
				}
			}

			return NO
		} # }}}
		tryAssignementStatement(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var dyn identifier = NO

			if @match(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE, Token::AT) == Token::IDENTIFIER {
				identifier = @reqUnaryOperand(@reqIdentifier(), ExpressionMode::Default, fMode)
			}
			else if @token == Token::LEFT_CURLY {
				identifier = @tryDestructuringObject(@yes(), fMode)
			}
			else if @token == Token::LEFT_SQUARE {
				identifier = @tryDestructuringArray(@yes(), fMode)
			}
			else if fMode == FunctionMode::Method && @token == Token::AT {
				identifier = @reqUnaryOperand(@reqThisExpression(@yes()), ExpressionMode::Default, fMode)
			}

			unless identifier.ok {
				return NO
			}

			var dyn statement
			if @match(Token::COMMA, Token::EQUALS) == Token::COMMA {
				unless identifier.value.kind == NodeKind::Identifier || identifier.value.kind == NodeKind::ArrayBinding || identifier.value.kind == NodeKind::ObjectBinding {
					return NO
				}

				var variables = [identifier]

				do {
					@commit()

					variables.push(@reqVariableIdentifier(fMode))
				}
				while @test(Token::COMMA)

				if @test(Token::EQUALS) {
					@commit().NL_0M()

					unless @test(Token::AWAIT) {
						@throw('await')
					}

					var operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)

					statement = @yep(AST.AwaitExpression([], variables, operand, identifier, operand))
				}
				else {
					@throw('=')
				}
			}
			else if @token == Token::EQUALS {
				var equals = @yes()

				@NL_0M()

				var expression = @reqExpression(ExpressionMode::Default + ExpressionMode::ImplicitMember + ExpressionMode::NoRestriction, fMode)

				statement = @yep(AST.BinaryExpression(identifier, @yep(AST.AssignmentOperator(AssignmentOperatorKind::Equals, equals)), expression, identifier, expression))
			}
			else {
				return NO
			}

			statement = @altRestrictiveExpression(statement, fMode)

			return @yep(AST.ExpressionStatement(statement))
		} # }}}
		tryAwaitExpression(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless @test(Token::AWAIT) {
				return NO
			}

			try {
				return @reqAwaitExpression(@yes(), fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryBinaryOperator(): Event ~ SyntaxError { # {{{
			match @matchM(M.BINARY_OPERATOR) {
				Token::AMPERSAND_AMPERSAND {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::And, @yes()))
				}
				Token::AMPERSAND_AMPERSAND_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::And, @yes()))
				}
				Token::ASTERISK {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Multiplication, @yes()))
				}
				Token::ASTERISK_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Multiplication, @yes()))
				}
				Token::CARET_CARET {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Xor, @yes()))
				}
				Token::CARET_CARET_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Xor, @yes()))
				}
				Token::EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Equals, @yes()))
				}
				Token::EQUALS_EQUALS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Equality, @yes()))
				}
				Token::EXCLAMATION_EQUALS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Inequality, @yes()))
				}
				Token::EXCLAMATION_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Empty, @yes()))
				}
				Token::EXCLAMATION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::NonExistential, @yes()))
				}
				Token::EXCLAMATION_TILDE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Mismatch, @yes()))
				}
				Token::HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::NonEmpty, @yes()))
				}
				Token::HASH_HASH {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::EmptyCoalescing, @yes()))
				}
				Token::HASH_HASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::EmptyCoalescing, @yes()))
				}
				Token::LEFT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::LessThan, @yes()))
				}
				Token::LEFT_ANGLE_EQUALS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::LessThanOrEqual, @yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::LeftShift, @yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::LeftShift, @yes()))
				}
				Token::LEFT_ANGLE_MINUS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Return, @yes()))
				}
				Token::MINUS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Subtraction, @yes()))
				}
				Token::MINUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Subtraction, @yes()))
				}
				Token::MINUS_RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Imply, @yes()))
				}
				Token::PERCENT {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Modulo, @yes()))
				}
				Token::PERCENT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Modulo, @yes()))
				}
				Token::PIPE_PIPE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Or, @yes()))
				}
				Token::PIPE_PIPE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Or, @yes()))
				}
				Token::PLUS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Addition, @yes()))
				}
				Token::PLUS_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Addition, @yes()))
				}
				Token::QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Existential, @yes()))
				}
				Token::QUESTION_QUESTION {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::NullCoalescing, @yes()))
				}
				Token::QUESTION_QUESTION_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::NullCoalescing, @yes()))
				}
				Token::RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::GreaterThan, @yes()))
				}
				Token::RIGHT_ANGLE_EQUALS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::GreaterThanOrEqual, @yes()))
				}
				Token::RIGHT_ANGLE_RIGHT_ANGLE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::RightShift, @yes()))
				}
				Token::RIGHT_ANGLE_RIGHT_ANGLE_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::RightShift, @yes()))
				}
				Token::SLASH {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Division, @yes()))
				}
				Token::SLASH_DOT {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Quotient, @yes()))
				}
				Token::SLASH_DOT_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Quotient, @yes()))
				}
				Token::SLASH_EQUALS {
					return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Division, @yes()))
				}
				Token::TILDE_TILDE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Match, @yes()))
				}
			}

			return NO
		} # }}}
		tryBlock(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			try {
				return @reqBlock(NO, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryBlockStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var label = @tryIdentifier()

			unless label.ok {
				return NO
			}

			unless @test(Token::LEFT_CURLY) {
				@throw('{')
			}

			var body = @reqBlock(@yes(), fMode)

			return @yep(AST.BlockStatement(label, body, first, body))
		} # }}}
		tryClassMember(attributes, modifiers, staticModifier: Event?, staticMark: Marker, finalModifier: Event?, finalMark: Marker, mut first: Event?) ~ SyntaxError { # {{{
			if staticModifier.ok {
				if finalModifier.ok {
					var member = @tryClassMember(
						attributes
						[...modifiers, staticModifier, finalModifier]
						ClassBits::Variable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method
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
					ClassBits::Variable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method + ClassBits::FinalMethod + ClassBits::Proxy
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
					ClassBits::Variable + ClassBits::RequiredAssignment + ClassBits::Property + ClassBits::Method
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
				ClassBits::Variable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method + ClassBits::OverrideMethod + ClassBits::AbstractMethod + ClassBits::Proxy
				first
			)
		} # }}}
		tryClassMember(mut attributes, modifiers, mut bits: ClassBits, mut first: Event?): Event ~ SyntaxError { # {{{
			var mark = @mark()

			if bits ~~ ClassBits::Attribute {
				var attrs = @stackOuterAttributes([])
				if attrs.length != 0 {
					attributes = [...attributes, ...attrs]
					first ??= attrs[0]
				}
			}

			if bits ~~ ClassBits::Method {
				var mark = @mark()

				if bits ~~ ClassBits::AbstractMethod && @test(Token::ABSTRACT) {
					var modifier = @yep(AST.Modifier(ModifierKind::Abstract, @yes()))

					var method = @tryClassMethod(
						attributes
						[...modifiers, modifier]
						bits + ClassBits::NoBody
						first ?? modifier
					)

					if method.ok {
						return method
					}

					@rollback(mark)
				}
				else if bits ~~ ClassBits::FinalMethod && @test(Token::FINAL) {
					var modifier = @yep(AST.Modifier(ModifierKind::Immutable, @yes()))
					var mark2 = @mark()

					if bits ~~ ClassBits::OverrideMethod && @test(Token::OVERRIDE) {
						var modifier2 = @yep(AST.Modifier(ModifierKind::Override, @yes()))
						var method = @tryClassMethod(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

						if method.ok {
							return method
						}

						if bits ~~ ClassBits::OverrideProperty {
							var property = @tryClassProperty(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

							if property.ok {
								return property
							}
						}

						@rollback(mark2)
					}
					else if bits ~~ ClassBits::OverwriteMethod && @test(Token::OVERWRITE) {
						var modifier2 = @yep(AST.Modifier(ModifierKind::Overwrite, @yes()))
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
				else if bits ~~ ClassBits::OverrideMethod && @test(Token::OVERRIDE) {
					var modifier = @yep(AST.Modifier(ModifierKind::Override, @yes()))

					var method = @tryClassMethod(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if method.ok {
						return method
					}

					if bits ~~ ClassBits::OverrideProperty {
						var property = @tryClassProperty(attributes, [...modifiers, modifier], bits, first ?? modifier)

						if property.ok {
							return property
						}
					}

					@rollback(mark)
				}
				else if bits ~~ ClassBits::OverwriteMethod && @test(Token::OVERWRITE) {
				}

				var method = @tryClassMethod(attributes, modifiers, bits, first)

				if method.ok {
					return method
				}

				@rollback(mark)
			}

			if bits ~~ ClassBits::Property {
				var mark = @mark()

				if bits ~~ ClassBits::OverrideProperty && @test(Token::OVERRIDE) {
					var modifier = @yep(AST.Modifier(ModifierKind::Override, @yes()))
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

			if bits ~~ ClassBits::Proxy && @test(Token::PROXY) {
				var mark = @mark()
				var keyword = @yes()

				var proxy = @tryClassProxy(attributes, modifiers, first ?? keyword)

				if proxy.ok {
					return proxy
				}

				@rollback(mark)
			}

			if bits ~~ ClassBits::Variable {
				var mark = @mark()

				if bits ~~ ClassBits::FinalVariable && @test(Token::FINAL) {
					var modifier = @yep(AST.Modifier(ModifierKind::Immutable, @yes()))
					var mark2 = @mark()

					if bits ~~ ClassBits::LateVariable && @test(Token::LATE) {
						var modifier2 = @yep(AST.Modifier(ModifierKind::LateInit, @yes()))
						var method = @tryClassVariable(
							attributes
							[...modifiers, modifier, modifier2]
							bits - ClassBits::RequiredAssignment
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
						bits + ClassBits::RequiredAssignment
						null
						null
						first ?? modifier
					)

					if variable.ok {
						return variable
					}

					@rollback(mark)
				}
				else if bits ~~ ClassBits::LateVariable && @test(Token::LATE) {
					var modifier = @yep(AST.Modifier(ModifierKind::LateInit, @yes()))
					var method = @tryClassVariable(
						attributes
						[...modifiers, modifier]
						bits - ClassBits::RequiredAssignment
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
		tryClassMethod(attributes, mut modifiers, mut bits: ClassBits, mut first: Event?): Event ~ SyntaxError { # {{{
			var dyn name
			if @test(Token::ASYNC) {
				var dyn modifier = @reqIdentifier()

				name = @tryIdentifier()

				if name.ok {
					modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind::Async, modifier))]
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

			if @test(Token::LEFT_ROUND) {
				return @reqClassMethod(attributes, modifiers, bits, name, null, first ?? name)
			}

			return NO
		} # }}}
		tryClassProperty(attributes, mut modifiers, mut bits: ClassBits, mut first: Event?): Event ~ SyntaxError { # {{{
			var mark = @mark()

			if @test(Token::AT) {
				var modifier = @yep(AST.Modifier(ModifierKind::ThisAlias, @yes()))

				modifiers = [...modifiers, modifier]
				first ??= modifier
			}

			var name = @tryIdentifier()

			unless name.ok {
				@rollback(mark)

				return NO
			}

			var dyn type = NO
			if @test(Token::COLON) {
				@commit()

				type = @reqType()
			}

			if @test(Token::LEFT_CURLY) {
				@commit()

				return @reqClassProperty(attributes, modifiers, name, type, first ?? name)
			}
			else if type.ok && bits ~~ ClassBits::Variable {
				return @tryClassVariable(attributes, modifiers, bits, name, type, first)
			}

			return NO
		} # }}}
		tryClassProxy(attributes, mut modifiers, mut first: Event?): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			unless @test(Token::EQUALS) {
				return NO
			}

			@commit()

			unless @test(Token::AT) {
				@throw('@')
			}

			var target = @reqExpression(ExpressionMode::Default, FunctionMode::Method)

			@reqNL_1M()

			return @yep(AST.ProxyDeclaration(attributes, modifiers, name, target, first ?? name, target ?? name))
		} # }}}
		tryClassStatement(mut first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			return @reqClassStatementBody(name, first, modifiers)
		} # }}}
		tryClassVariable(attributes, mut modifiers, bits: ClassBits, mut name: Event?, mut type: Event?, mut first: Event?): Event ~ SyntaxError { # {{{
			var mark = @mark()

			if !?name {
				if @test(Token::AT) {
					var modifier = @yep(AST.Modifier(ModifierKind::ThisAlias, @yes()))

					modifiers = [...modifiers, modifier]
					first ??= modifier
				}

				name = @tryIdentifier()

				unless name.ok {
					@rollback(mark)

					return NO
				}
			}

			if !?type {
				if @test(Token::COLON) {
					@commit()

					type = @reqType()
				}
				else if @test(Token::QUESTION) {
					modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind::Nullable, @yes()))]
				}
			}

			var dyn value
			if bits ~~ ClassBits::NoAssignment {
				pass
			}
			else if @test(Token::EQUALS) {
				@commit()

				value = @reqExpression(ExpressionMode::Default + ExpressionMode::ImplicitMember, FunctionMode::Method)
			}
			else if bits ~~ ClassBits::RequiredAssignment {
				@throw('=')
			}

			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, value, first ?? name, value ?? type ?? name))
		} # }}}
		tryCreateExpression(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @test(Token::LEFT_ROUND) {
				@commit()

				var class = @reqExpression(ExpressionMode::Default, fMode)

				unless @test(Token::RIGHT_ROUND) {
					@throw(')')
				}

				@commit()

				unless @test(Token::LEFT_ROUND) {
					@throw('(')
				}

				@commit()

				return @yep(AST.CreateExpression(class, @reqArgumentList(fMode), first, @yes()))
			}

			var dyn class = @tryVariableName(fMode)

			unless class.ok {
				return NO
			}

			// if @match(Token::LEFT_ANGLE, Token::LEFT_SQUARE) == Token::LEFT_ANGLE {
			// 	var generic = @reqTypeGeneric(@yes())
			// 	class = @yep(AST.TypeReference([], class, generic, class, generic))
			// }

			if @test(Token::LEFT_ROUND) {
				@commit()

				return @yep(AST.CreateExpression(class, @reqArgumentList(fMode), first, @yes()))
			}
			else {
				return @yep(AST.CreateExpression(class, @yep([]), first, class))
			}
		} # }}}
		tryDestroyStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var variable = @tryVariableName(fMode)

			if variable.ok {
				return @yep(AST.DestroyStatement(variable, first, variable))
			}
			else {
				return NO
			}
		} # }}}
		tryDestructuring(fMode): Event ~ SyntaxError { # {{{
			if @match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY {
				try {
					return @reqDestructuringObject(@yes(), DestructuringMode::Expression, fMode)
				}
			}
			else if @token == Token::LEFT_SQUARE {
				try {
					return @reqDestructuringArray(@yes(), DestructuringMode::Expression, fMode)
				}
			}

			return NO
		} # }}}
		tryDestructuringArray(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var late dMode: DestructuringMode

			if fMode == FunctionMode::Method {
				dMode = DestructuringMode::Expression + DestructuringMode::THIS_ALIAS
			}
			else {
				dMode = DestructuringMode::Expression
			}

			try {
				return @reqDestructuringArray(first, dMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryDestructuringObject(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var late dMode: DestructuringMode

			if fMode == FunctionMode::Method {
				dMode = DestructuringMode::Expression + DestructuringMode::THIS_ALIAS
			}
			else {
				dMode = DestructuringMode::Expression
			}

			try {
				return @reqDestructuringObject(first, dMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryEnumMethod(attributes, mut modifiers, mut first: Event?): Event ~ SyntaxError { # {{{
			var dyn name
			if @test(Token::ASYNC) {
				var dyn first = @reqIdentifier()

				name = @tryIdentifier()

				if name.ok {
					modifiers = [...modifiers, @yep(AST.Modifier(ModifierKind::Async, first))]
				}
				else {
					name = first
				}
			}
			else {
				name = @tryIdentifier()

				unless name.ok {
					return NO
				}
			}

			return @reqEnumMethod(attributes, modifiers, name, first ?? name)
		} # }}}
		tryExpression(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			try {
				return @reqExpression(eMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryExternFunctionDeclaration(modifiers, mut first: Event): Event ~ SyntaxError { # {{{
			try {
				return @reqExternFunctionDeclaration(modifiers, first)
			}
			catch {
				return NO
			}
		} # }}}
		tryFunctionBody(fMode: FunctionMode): Event? ~ SyntaxError { # {{{
			var mark = @mark()

			@NL_0M()

			if @test(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) {
				return @reqFunctionBody(fMode)
			}
			else {
				@rollback(mark)

				return null
			}
		} # }}}
		tryFunctionExpression(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if eMode ~~ ExpressionMode::NoAnonymousFunction {
				return NO
			}

			if @match(Token::ASYNC, Token::FUNC, Token::LEFT_ROUND, Token::IDENTIFIER) == Token::ASYNC {
				var first = @yes()
				var modifiers = [@yep(AST.Modifier(ModifierKind::Async, first))]

				if @test(Token::FUNC) {
					@commit()

					var parameters = @reqFunctionParameterList(FunctionMode::Function)
					var type = @tryFunctionReturns()
					var throws = @tryFunctionThrows()
					var body = @reqFunctionBody(FunctionMode::Function)

					return @yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, first, body))
				}
				else {
					var parameters = @tryFunctionParameterList(fMode)
					if !parameters.ok {
						return NO
					}

					var type = @tryFunctionReturns()
					var throws = @tryFunctionThrows()
					var body = @reqFunctionBody(fMode)

					return @yep(AST.LambdaExpression(parameters, modifiers, type, throws, body, first, body))
				}
			}
			else if @token == Token::FUNC {
				var first = @yes()

				var parameters = @tryFunctionParameterList(FunctionMode::Function)
				if !parameters.ok {
					return NO
				}

				var type = @tryFunctionReturns()
				var throws = @tryFunctionThrows()
				var body = @reqFunctionBody(FunctionMode::Function)

				return @yep(AST.FunctionExpression(parameters, null, type, throws, body, first, body))
			}
			else if @token == Token::LEFT_ROUND {
				var parameters = @tryFunctionParameterList(fMode)
				var type = @tryFunctionReturns()
				var throws = @tryFunctionThrows()

				if !parameters.ok || !@test(Token::EQUALS_RIGHT_ANGLE) {
					return NO
				}

				@commit()

				if @test(Token::LEFT_CURLY) {
					var body = @reqBlock(NO, fMode)

					return @yep(AST.LambdaExpression(parameters, null, type, throws, body, parameters, body))
				}
				else {
					var body = @reqExpression(eMode + ExpressionMode::NoObject, fMode)

					return @yep(AST.LambdaExpression(parameters, null, type, throws, body, parameters, body))
				}
			}
			else if @token == Token::IDENTIFIER {
				var name = @reqIdentifier()

				unless @test(Token::EQUALS_RIGHT_ANGLE) {
					return NO
				}

				@commit()

				var parameters = @yep([@yep(AST.Parameter(name))], name, name)

				if @test(Token::LEFT_CURLY) {
					var body = @reqBlock(NO, fMode)

					return @yep(AST.LambdaExpression(parameters, null, null, null, body, parameters, body))
				}
				else {
					var body = @reqExpression(eMode + ExpressionMode::NoObject, fMode)

					return @yep(AST.LambdaExpression(parameters, null, null, null, body, parameters, body))
				}
			}
			else {
				return NO
			}
		} # }}}
		tryFunctionParameterList(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless @test(Token::LEFT_ROUND) {
				return NO
			}

			var first = @yes()

			@NL_0M()

			var parameters = []

			while @until(Token::RIGHT_ROUND) {
				try {
					parameters.push(@reqParameter(DestructuringMode::Parameter, fMode))
				}
				catch {
					return NO
				}

				var separator = @trySeparator(Token::RIGHT_ROUND)

				unless separator.ok {
					return NO
				}
			}

			unless @test(Token::RIGHT_ROUND) {
				return NO
			}

			return @yep(parameters, first, @yes())
		} # }}}
		tryFunctionReturns(isAllowingAuto: Boolean = true): Event? ~ SyntaxError { # {{{
			var mark = @mark()

			@NL_0M()

			if @test(Token::COLON) {
				@commit()

				var mark = @mark()

				var number = @tryNumber()

				if number.ok {
					return number
				}

				return @reqType()
			}
			else {
				@rollback(mark)

				return null
			}
		} # }}}
		tryFunctionThrows(): Event? ~ SyntaxError { # {{{
			var mark = @mark()

			@NL_0M()

			if @test(Token::TILDE) {
				@commit()

				var exceptions = [@reqIdentifier()]

				while @test(Token::COMMA) {
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
		tryIdentifier(): Event ~ SyntaxError { # {{{
			if @scanner.test(Token::IDENTIFIER) {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else {
				return NO
			}
		} # }}}
		tryIfExpression(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless @test(Token::IF) {
				return NO
			}

			var first = @yes()

			@mode += ParserMode::InlineStatement

			var mark = @mark()

			var mut condition: Event? = null
			var mut declaration: Event? = null

			if @test(Token::VAR) {
				var mark = @mark()
				var first = @yes()

				var modifiers = []
				if @test(Token::MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Mutable, @yes())))
				}
				else {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Immutable, @yes())))
				}

				if @test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					if @test(Token::COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token::COMMA)

						var operator = @reqConditionAssignment()

						unless @test(Token::AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						declaration = @yep(AST.VariableDeclaration([], modifiers, variables, operator, expression, first, expression))
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(ExpressionMode::Default + ExpressionMode::ImplicitMember, fMode)

						declaration = @yep(AST.VariableDeclaration([], modifiers, [variable], operator, expression, first, expression))
					}

					@NL_0M()

					if @test(Token::SEMICOLON) {
						@commit().NL_0M()

						condition = @reqExpression(ExpressionMode::NoAnonymousFunction, fMode)
					}
				}
				else {
					@rollback(mark)

					condition = @tryExpression(ExpressionMode::NoAnonymousFunction, fMode)
				}
			}
			else {
				@NL_0M()

				condition = @tryExpression(ExpressionMode::NoAnonymousFunction, fMode)
			}

			unless ?declaration || condition.ok {
				return NO
			}

			@NL_0M()

			unless @test(Token::LEFT_CURLY) {
				@rollback(mark)

				return NO
			}

			var whenTrue = @reqBlock(NO, fMode)

			@commit().NL_0M()

			unless @test(Token::ELSE) {
				@throw('else')
			}

			@commit().NL_0M()

			var whenFalse = @tryIfExpression(eMode, fMode)

			if whenFalse.ok {
				return @yep(AST.IfExpression(condition, declaration, whenTrue, whenFalse, first, whenFalse))
			}
			else {
				var whenFalse = @reqBlock(NO, fMode)

				return @yep(AST.IfExpression(condition, declaration, whenTrue, whenFalse, first, whenFalse))
			}
		} # }}}
		tryJunctionOperator(): Event ~ SyntaxError { # {{{
			match @matchM(M.JUNCTION_OPERATOR) {
				Token::AMPERSAND {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::And, @yes()))
				}
				Token::CARET {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Xor, @yes()))
				}
				Token::PIPE {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::Or, @yes()))
				}
				else {
					return NO
				}
			}
		} # }}}
		tryMacroStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			var parameters = @reqMacroParameterList()

			var body = @reqMacroBody()

			return @yep(AST.MacroDeclaration([], name, parameters, body, first, body))
		} # }}}
		tryMatchExpression(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless @test(Token::MATCH) {
				return NO
			}

			var first = @yes()

			var expression = @tryOperation(eMode, fMode)

			unless expression.ok && @test(Token::LEFT_CURLY) {
				return NO
			}

			@mode += ParserMode::InlineStatement

			var clauses = @reqMatchCaseList(fMode)

			@mode -= ParserMode::InlineStatement

			return @yep(AST.MatchExpression(expression, clauses, first, clauses))
		} # }}}
		tryMatchStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var expression = @tryOperation(ExpressionMode::Default, fMode)

			unless expression.ok && @test(Token::LEFT_CURLY) {
				return NO
			}

			var clauses = @reqMatchCaseList(fMode)

			return @yep(AST.MatchStatement(expression, clauses, first, clauses))
		} # }}}
		tryMethodReturns(isAllowingAuto: Boolean = true): Event? ~ SyntaxError { # {{{
			var mark = @mark()

			@NL_0M()

			if @test(Token::COLON) {
				@commit()

				var mark = @mark()

				var number = @tryNumber()

				if number.ok {
					return number
				}

				if @test(Token::AT) {
					return @reqThisExpression(@yes())
				}
				else {
					return @reqType()
				}
			}
			else {
				@rollback(mark)

				return null
			}
		} # }}}
		tryNameIST(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @match(Token::IDENTIFIER, Token::STRING, Token::TEMPLATE_BEGIN) == Token::IDENTIFIER {
				return @reqIdentifier()
			}
			else if @token == Token::STRING {
				return @reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return @reqTemplateExpression(@yes(), fMode)
			}
			else {
				return NO
			}
		} # }}}
		tryNamespaceStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			return @reqNamespaceStatement(first, name)
		} # }}}
		tryNumber(): Event ~ SyntaxError { # {{{
			if @matchM(M.NUMBER) == Token::BINARY_NUMBER {
				return @yep(AST.NumericExpression(parseInt(@scanner.value().slice(2).replace(/\_/g, ''), 2), @yes()))
			}
			else if @token == Token::OCTAL_NUMBER {
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

				return @yep(AST.NumericExpression(value, @yes()))
			}
			else if @token == Token::HEX_NUMBER {
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

				return @yep(AST.NumericExpression(value, @yes()))
			}
			else if @token == Token::RADIX_NUMBER {
				var data = /^(\d+)r(.*)$/.exec(@scanner.value())

				return @yep(AST.NumericExpression(parseInt(data[2]!?.replace(/\_/g, ''), parseInt(data[1])), @yes()))
			}
			else if @token == Token::DECIMAL_NUMBER {
				return @yep(AST.NumericExpression(parseFloat(@scanner.value().replace(/\_/g, ''), 10), @yes()))
			}
			else {
				return NO
			}
		} # }}}
		tryNL_1M(): Event ~ SyntaxError { # {{{
			if @test(Token::NEWLINE) {
				@commit()

				@skipNewLine()

				return YES
			}
			else {
				return NO
			}
		} # }}}
		tryOperand(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @matchM(M.OPERAND) == Token::AT && fMode == FunctionMode::Method {
				return @reqThisExpression(@yes())
			}
			else if @token == Token::IDENTIFIER {
				return @yep(AST.Identifier(@scanner.value(), @yes()))
			}
			else if @token == Token::LEFT_CURLY {
				return @reqObject(@yes(), fMode)
			}
			else if @token == Token::LEFT_ROUND {
				return @tryParenthesis(@yes(), fMode)
			}
			else if @token == Token::LEFT_SQUARE {
				return @reqArray(@yes(), fMode)
			}
			else if @token == Token::ML_BACKQUOTE | Token::ML_TILDE {
				var delimiter = @token

				return @reqMultiLineTemplate(@yes(), fMode, delimiter)
			}
			else if @token == Token::ML_DOUBLE_QUOTE | Token::ML_SINGLE_QUOTE {
				var delimiter = @token

				return @reqMultiLineString(@yes(), delimiter)
			}
			else if @token == Token::NEW {
				var first = @yep(AST.Identifier(@scanner.value(), @yes()))

				var operand = @tryCreateExpression(first, fMode)
				if operand.ok {
					return operand
				}
				else {
					return first
				}
			}
			else if @token == Token::REGEXP {
				return @yep(AST.RegularExpression(@scanner.value(), @yes()))
			}
			else if @token == Token::STRING {
				return @yep(AST.Literal(null, @value(), @yes()))
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return @reqTemplateExpression(@yes(), fMode)
			}
			else {
				return @tryNumber()
			}
		} # }}}
		tryOperation(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			try {
				return @reqOperation(eMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryParameterAssignment(valued: Boolean): Event ~ SyntaxError { # {{{
			return NO unless valued

			if @test(Token::EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind::Equals, @yes()))
			}
			else if @test(Token::QUESTION_QUESTION_EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind::NullCoalescing, @yes()))
			}
			else if @test(Token::HASH_HASH_EQUALS) {
				return @yep(AST.AssignmentOperator(AssignmentOperatorKind::EmptyCoalescing, @yes()))
			}

			return NO
		} # }}}
		tryParenthesis(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			try {
				return @reqParenthesis(first, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryRangeOperand(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var operand = @tryOperand(eMode, fMode)
			if !operand.ok {
				return NO
			}

			return @reqPostfixedOperand(operand, eMode, fMode)
		} # }}}
		trySeparator(token: Token): Event ~ SyntaxError { # {{{
			if @match(Token::COMMA, Token::NEWLINE, token) == Token::COMMA {
				@commit()

				if @test(token) {
					return NO
				}

				@skipNewLine()

				return YES
			}
			else if @token == Token::NEWLINE {
				@commit()

				@skipNewLine()

				return YES
			}
			else if @token == token {
				return YES
			}
			else {
				return NO
			}
		} # }}}
		tryShebang(): Event ~ SyntaxError { # {{{
			if @test(Token::HASH_EXCLAMATION) {
				var first = @yes()
				var command = @scanner.readLine()
				var last = @yep()

				@reqNL_1M()

				return @yep(AST.ShebangDeclaration(command, first, last))
			}

			return NO
		} # }}}
		tryTryExpression(mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless @test(Token::TRY) {
				return NO
			}

			try {
				return @reqTryExpression(@yes(), fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryType(modifiers: Array = [], multiline: Boolean = false): Event ~ SyntaxError { # {{{
			var type = @tryTypeCore(modifiers, multiline)

			return NO unless type.ok

			var dyn mark = @mark()

			if multiline {
				var types = [type]

				@NL_0M()

				if @match(Token::PIPE, Token::AMPERSAND, Token::CARET) == Token::PIPE {
					do {
						@commit()

						if @test(Token::PIPE) {
							@commit()
						}

						@NL_0M()

						if @test(Token::QUESTION) {
							var name = @yep(AST.Identifier('Null', @yes()))

							types.push(@yep(AST.TypeReference([], name, null, name, name)))
						}
						else {
							types.push(@reqTypeCore(true))
						}

						mark = @mark()

						@NL_0M()
					}
					while @test(Token::PIPE)

					@rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return @yep(AST.UnionType(types, type, types[types.length - 1]))
					}
				}
				else if @token == Token::AMPERSAND {
					do {
						@commit()

						if @test(Token::AMPERSAND) {
							@commit()
						}

						@NL_0M()

						types.push(@reqTypeCore(true))

						mark = @mark()

						@NL_0M()
					}
					while @test(Token::AMPERSAND)

					@rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return @yep(AST.FusionType(types, type, types[types.length - 1]))
					}
				}
				else if @token == Token::CARET {
					do {
						@commit()

						if @test(Token::CARET) {
							@commit()
						}

						@NL_0M()

						types.push(@reqTypeCore(true))

						mark = @mark()

						@NL_0M()
					}
					while @test(Token::CARET)

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
				if @match(Token::PIPE_PIPE, Token::PIPE, Token::AMPERSAND_AMPERSAND, Token::AMPERSAND, Token::CARET_CARET, Token::CARET) == Token::PIPE {
					@commit()

					if @test(Token::NEWLINE) {
						@rollback(mark)

						return type
					}

					var types = [type]

					do {
						@commit()

						if @test(Token::QUESTION) {
							var name = @yep(AST.Identifier('Null', @yes()))

							types.push(@yep(AST.TypeReference([], name, null, name, name)))
						}
						else {
							types.push(@reqTypeCore(false))
						}
					}
					while @test(Token::PIPE)

					return @yep(AST.UnionType(types, type, types[types.length - 1]))
				}
				else if @token == Token::AMPERSAND {
					@commit()

					if @test(Token::NEWLINE) {
						@rollback(mark)

						return type
					}

					var types = [type]

					do {
						@commit()

						types.push(@reqTypeCore(false))
					}
					while @test(Token::AMPERSAND)

					return @yep(AST.FusionType(types, type, types[types.length - 1]))
				}
				else if @token == Token::CARET {
					@commit()

					if @test(Token::NEWLINE) {
						@rollback(mark)

						return type
					}

					var types = [type]

					do {
						@commit()

						types.push(@reqTypeCore(false))
					}
					while @test(Token::CARET)

					return @yep(AST.ExclusionType(types, type, types[types.length - 1]))
				}
			}

			return type
		} # }}}
		tryTypeCore(modifiers: Array = [], multiline: Boolean): Event ~ SyntaxError { # {{{
			if @test(Token::LEFT_CURLY) {
				var first = @yes()
				var properties = []
				var mut rest = null

				@NL_0M()

				until @test(Token::RIGHT_CURLY) {
					var mark = @mark()
					var mut nf = true

					if @test(Token::ASYNC) {
						var async = @yes()

						if @test(Token::FUNC) {
							@commit()
						}

						var identifier = @tryIdentifier()

						if identifier.ok && @test(Token::LEFT_ROUND) {
							var modifiers = [@yep(AST.Modifier(ModifierKind::Async, async))]
							var parameters = @reqFunctionParameterList(FunctionMode::Function, DestructuringMode::EXTERNAL_ONLY)
							var type = @tryFunctionReturns(false)
							var throws = @tryFunctionThrows()

							var objectType = @yep(AST.FunctionExpression(parameters, modifiers, type, throws, null, parameters, throws ?? type ?? parameters))

							var property = @yep(AST.PropertyType([], identifier, objectType, identifier, objectType))

							properties.push(property)

							nf = false
						}
						else {
							@rollback(mark)
						}
					}

					if nf && @test(Token::FUNC) {
						var first = @yes()
						var identifier = @tryIdentifier()

						if identifier.ok && @test(Token::LEFT_ROUND) {
							var parameters = @reqFunctionParameterList(FunctionMode::Function, DestructuringMode::EXTERNAL_ONLY)
							var type = @tryFunctionReturns(false)
							var throws = @tryFunctionThrows()

							var objectType = @yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?? type ?? parameters))

							var property = @yep(AST.PropertyType([], identifier, objectType, identifier, objectType))

							properties.push(property)

							nf = false
						}
						else {
							@rollback(mark)
						}
					}

					if nf && @test(Token::DOT_DOT_DOT) {
						if ?rest {
							@throw('Identifier')
						}

						var first = @yes()
						var modifier = @yep(AST.RestModifier(0, Infinity, first, first))
						var type = @tryType()

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
							var mut type = null

							if @test(Token::LEFT_ROUND) {
								var parameters = @reqFunctionParameterList(FunctionMode::Function, DestructuringMode::EXTERNAL_ONLY)
								var return = @tryFunctionReturns()
								var throws = @tryFunctionThrows()

								type = @yep(AST.FunctionExpression(parameters, null, return, throws, null, parameters, throws ?? return ?? parameters))
							}
							else if @test(Token::COLON) {
								@commit()

								type = @reqType()
							}

							var property = @yep(AST.PropertyType([], identifier, type, identifier, type ?? identifier))

							properties.push(property)

							nf = false
						}
					}

					if nf {
						@throw('Identifier', '...')
					}
					else {
						if @test(Token::COMMA) {
							@commit().NL_0M()
						}
						else if @test(Token::NEWLINE) {
							@commit().NL_0M()

							if @test(Token::COMMA) {
								@commit().NL_0M()
							}
						}
						else {
							break
						}
					}
				}

				unless @test(Token::RIGHT_CURLY) {
					@throw('}')
				}

				var type = @yep(AST.ObjectType([], properties, rest, first, @yes()))

				return @altTypeContainer(type)
			}

			if @test(Token::LEFT_SQUARE) {
				var first = @yes()
				var properties = []
				var mut rest = null

				@NL_0M()

				while @until(Token::RIGHT_SQUARE) {
					if @test(Token::COMMA) {
						var first = @yep()
						var property = @yep(AST.PropertyType([], null, null, first, first))

						properties.push(property)

						@commit().NL_0M()
					}
					else {
						@NL_0M()

						if @test(Token::DOT_DOT_DOT) {
							if ?rest {
								@throw('Identifier')
							}

							var first = @yes()
							var modifier = @yep(AST.RestModifier(0, Infinity, first, first))
							var type = @tryType([], multiline)

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

						if @test(Token::COMMA) {
							@commit().NL_0M()
						}
						else if @test(Token::NEWLINE) {
							@commit().NL_0M()
						}
						else {
							break
						}
					}
				}

				unless @test(Token::RIGHT_SQUARE) {
					@throw(']')
				}

				var type = @yep(AST.ArrayType([], properties, rest, first, @yes()))

				return @altTypeContainer(type)
			}

			var mark = @mark()

			if @test(Token::ASYNC) {
				var async = @yes()

				if @test(Token::FUNC) {
					@commit()
				}

				if @test(Token::LEFT_ROUND) {
					var modifiers = [@yep(AST.Modifier(ModifierKind::Async, async))]
					var parameters = @reqFunctionParameterList(FunctionMode::Function, DestructuringMode::EXTERNAL_ONLY)
					var type = @tryFunctionReturns(false)
					var throws = @tryFunctionThrows()

					var func = @yep(AST.FunctionExpression(parameters, modifiers, type, throws, null, async, throws ?? type ?? parameters))

					return @altTypeContainer(func)
				}

				@rollback(mark)
			}

			if @test(Token::FUNC) {
				var first = @yes()

				if @test(Token::LEFT_ROUND) {
					var parameters = @reqFunctionParameterList(FunctionMode::Function, DestructuringMode::EXTERNAL_ONLY)
					var type = @tryFunctionReturns(false)
					var throws = @tryFunctionThrows()

					var func = @yep(AST.FunctionExpression(parameters, null, type, throws, null, first, throws ?? type ?? parameters))

					return @altTypeContainer(func)
				}

				@rollback(mark)
			}

			var type = @tryTypeLimited(modifiers)

			if type.ok {
				return @altTypeContainer(type)
			}
			else {
				return NO
			}
		} # }}}
		tryTypeDescriptive(tMode: TypeMode = TypeMode::Default): Event ~ SyntaxError { # {{{
			match @matchM(M.DESCRIPTIVE_TYPE) {
				Token::ABSTRACT {
					var abstract = @yep(AST.Modifier(ModifierKind::Abstract, @yes()))

					if @test(Token::CLASS) {
						@commit()

						return @reqExternClassDeclaration(abstract, [abstract])
					}
					else {
						return @no('class')
					}
				}
				Token::ASYNC {
					var first = @reqIdentifier()
					var modifiers = [@yep(AST.Modifier(ModifierKind::Async, first))]

					if @test(Token::FUNC) {
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
				Token::BITMASK {
					with @mode += ParserMode::Typing {
						return @reqBitmaskStatement(@yes())
					}
				}
				Token::CLASS {
					return @reqExternClassDeclaration(@yes(), [])
				}
				Token::ENUM {
					with @mode += ParserMode::Typing {
						return @reqEnumStatement(@yes())
					}
				}
				Token::EXPORT {
					if tMode == TypeMode::Module {
						return NO
					}
					else {
						return @reqExportModule(@yes())
					}
				}
				Token::FINAL {
					var first = @yes()
					var modifiers = [@yep(AST.Modifier(ModifierKind::Immutable, first))]

					if @test(Token::CLASS) {
						@commit()

						return @reqExternClassDeclaration(first, modifiers)
					}
					else if @test(Token::ABSTRACT) {
						modifiers.push(@yep(AST.Modifier(ModifierKind::Abstract, @yes())))

						if @test(Token::CLASS) {
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
				Token::FUNC {
					var first = @yes()
					return @reqExternFunctionDeclaration([], first)
				}
				Token::IDENTIFIER {
					if tMode == TypeMode::NoIdentifier {
						return NO
					}
					else {
						return @reqExternVariableDeclarator(@reqIdentifier())
					}
				}
				Token::NAMESPACE {
					return @reqExternNamespaceDeclaration(@yes(), [])
				}
				Token::SEALED {
					var sealed = @yep(AST.Modifier(ModifierKind::Sealed, @yes()))

					if @matchM(M.DESCRIPTIVE_TYPE) == Token::ABSTRACT {
						var abstract = @yep(AST.Modifier(ModifierKind::Abstract, @yes()))

						if @test(Token::CLASS) {
							@commit()

							return @reqExternClassDeclaration(sealed, [sealed, abstract])
						}
						else {
							return @no('class')
						}
					}
					else if @token == Token::CLASS {
						@commit()

						return @reqExternClassDeclaration(sealed, [sealed])
					}
					else if @token == Token::IDENTIFIER {
						var name = @reqIdentifier()

						if @test(Token::COLON) {
							@commit()

							var type = @reqType()

							return @yep(AST.VariableDeclarator([sealed], name, type, sealed, type))
						}
						else {
							return @yep(AST.VariableDeclarator([sealed], name, null, sealed, name))
						}
					}
					else if @token == Token::NAMESPACE {
						@commit()

						return @reqExternNamespaceDeclaration(sealed, [sealed])
					}
					else {
						return @no('class', 'namespace')
					}
				}
				Token::STRUCT {
					return @reqStructStatement(@yes())
				}
				Token::SYSTEM {
					var system = @yep(AST.Modifier(ModifierKind::System, @yes()))

					if @matchM(M.DESCRIPTIVE_TYPE) == Token::CLASS {
						@commit()

						return @reqExternClassDeclaration(system, [system])
					}
					else if @token == Token::IDENTIFIER {
						var name = @reqIdentifier()

						if @test(Token::COLON) {
							@commit()

							var type = @reqType()

							return @yep(AST.VariableDeclarator([system], name, type, system, type))
						}
						else {
							return @yep(AST.VariableDeclarator([system], name, null, system, name))
						}
					}
					else if @token == Token::NAMESPACE {
						@commit()

						return @reqExternNamespaceDeclaration(system, [system])
					}
					else {
						return @no('class', 'namespace')
					}
				}
				Token::TUPLE {
					return @reqTupleStatement(@yes())
				}
				Token::TYPE {
					return @reqTypeStatement(@yes(), @reqIdentifier())
				}
				Token::VAR {
					var first = @yes()
					var name = @reqIdentifier()

					if @test(Token::COLON) {
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
		tryTypeEntity(): Event ~ SyntaxError { # {{{
			var mut name = @tryIdentifier()

			return NO unless name.ok

			if @testNS(Token::DOT) {
				do {
					@commit()

					var property = @tryIdentifier()

					return NO unless property.ok

					name = @yep(AST.MemberExpression([], name, property))
				}
				while @testNS(Token::DOT)
			}

			return @yep(AST.TypeReference([], name, null, name, name))
		} # }}}
		tryTypeLimited(modifiers: Array = []): Event ~ SyntaxError { # {{{
			if @test(Token::LEFT_ROUND) {
				var parameters = @reqFunctionParameterList(FunctionMode::Function, DestructuringMode::EXTERNAL_ONLY)
				var type = @tryFunctionReturns(false)
				var throws = @tryFunctionThrows()

				return @yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?? type ?? parameters))
			}

			var mut name = @tryIdentifier()

			return NO unless name.ok

			if @testNS(Token::DOT) {
				do {
					@commit()

					var property = @reqIdentifier()

					name = @yep(AST.MemberExpression([], name, property))
				}
				while @testNS(Token::DOT)
			}

			var first = modifiers[0] ?? name
			var mut last = name

			var mut generic = null
			if @testNS(Token::LEFT_ANGLE) {
				var first = @yes()
				var types = [@reqTypeLimited()]

				while @test(Token::COMMA) {
					@commit()

					types.push(@reqTypeLimited())
				}

				unless @test(Token::RIGHT_ANGLE) {
					@throw('>')
				}

				last = generic = @yes(types, first)
			}

			return @yep(AST.TypeReference(modifiers, name, generic, first, last))
		} # }}}
		tryTypeOperator(): Event ~ SyntaxError { # {{{
			match @matchM(M.TYPE_OPERATOR) {
				Token::AS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::TypeCasting, @yes()))
				}
				Token::AS_EXCLAMATION {
					var position = @yes()

					return @yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Forced, position)], BinaryOperatorKind::TypeCasting, position))
				}
				Token::AS_QUESTION {
					var position = @yes()

					return @yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Nullable, position)], BinaryOperatorKind::TypeCasting, position))
				}
				Token::IS {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::TypeEquality, @yes()))
				}
				Token::IS_NOT {
					return @yep(AST.BinaryOperator(BinaryOperatorKind::TypeInequality, @yes()))
				}
				else {
					return NO
				}
			}
		} # }}}
		tryTypeStatement(mut first: Event): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()

			unless name.ok {
				return NO
			}

			return @reqTypeStatement(first, name)
		} # }}}
		tryTypedVariable(fMode: FunctionMode, typeable: Boolean = true, questionable: Boolean = true): Event ~ SyntaxError { # {{{
			try {
				return @reqTypedVariable(fMode, typeable, questionable)
			}
			catch {
				return NO
			}
		} # }}}
		tryUntilStatement(mut first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var condition = @tryExpression(ExpressionMode::Default, fMode)

			unless condition.ok {
				return NO
			}

			var dyn body
			if @match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				body = @reqBlock(@yes(), fMode)
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				@commit()

				body = @reqExpression(ExpressionMode::Default, fMode)
			}
			else {
				@throw('{', '=>')
			}

			return @yep(AST.UntilStatement(condition, body, first, body))
		} # }}}
		tryVariable(): Event ~ SyntaxError { # {{{
			var name = @tryIdentifier()

			if name.ok {
				return @yep(AST.VariableDeclarator([], name, null, name, name))
			}
			else {
				return NO
			}
		} # }}}
		tryVariableName(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var dyn object
			if fMode == FunctionMode::Method && @test(Token::AT) {
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
		tryVarStatement(mut first: Event, mut eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var mark = @mark()

			if @test(Token::MUT) {
				var statement = @tryVarMutStatement(first, eMode, fMode)
				if statement.ok {
					return statement
				}

				@rollback(mark)
			}

			if @test(Token::DYN) {
				var statement = @tryVarDynStatement(first, eMode, fMode)
				if statement.ok {
					return statement
				}

				@rollback(mark)
			}

			if @test(Token::LATE) {
				var statement = @tryVarLateStatement(first, eMode, fMode)
				if statement.ok {
					return statement
				}

				@rollback(mark)
			}

			if @test(Token::LEFT_CURLY) {
				@commit()

				var declarations = []
				var mut ok = @tryNL_1M().ok

				if ok {
					while @until(Token::RIGHT_CURLY) {
						var variable = @tryTypedVariable(fMode, true, false)
						if !variable.ok {
							ok = false

							break
						}

						if @test(Token::EQUALS) {
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
					unless @test(Token::RIGHT_CURLY) {
						@throw('}')
					}

					return @yep(AST.VariableStatement([], [], declarations, first, @yes()))
				}
				else {
					@rollback(mark)
				}
			}

			var variable = @tryTypedVariable(fMode, true, false)

			return NO unless variable.ok

			var variables = [variable]

			if @test(Token::COMMA) {
				@commit()

				variables.push(@reqTypedVariable(fMode, true, false))
			}

			if @test(Token::EQUALS) {
				@commit()
			}
			else {
				@throw('=')
			}

			@NL_0M()

			var late value: Event

			if variables.length == 1 {
				value = @reqExpression(eMode + ExpressionMode::ImplicitMember, fMode)
			}
			else {
				unless @test(Token::AWAIT) {
					@throw('await')
				}

				@commit()

				var operand = @reqPrefixedOperand(eMode, fMode)

				value = @yep(AST.AwaitExpression([], variables, operand, variable, operand))
			}

			var declaration = @yep(AST.VariableDeclaration([], [], variables, null, value, variable, value))

			return @yep(AST.VariableStatement([], [], [declaration], first, declaration))
		} # }}}
		tryVarDynStatement(first: Event, eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var modifiers = [@yep(AST.Modifier(ModifierKind::Dynamic, @yes()))]

			var mark = @mark()

			if @test(Token::LEFT_CURLY) {
				@commit()

				var declarations = []
				var mut ok = @tryNL_1M().ok

				if ok {
					while @until(Token::RIGHT_CURLY) {
						var variable = @tryTypedVariable(fMode, false, false)
						if !variable.ok {
							ok = false

							break
						}

						if @test(Token::EQUALS) {
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
					unless @test(Token::RIGHT_CURLY) {
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

			if @test(Token::COMMA) {
				@commit()

				var variable = @tryTypedVariable(fMode, false, false)

				return NO unless variable.ok

				variables.push(variable)
			}

			if @test(Token::EQUALS) {
				@commit().NL_0M()

				if variables.length == 1 {
					value = @reqExpression(eMode + ExpressionMode::ImplicitMember, fMode)

					var declaration = @yep(AST.VariableDeclaration([], [], variables, null, value, first, value))

					return @yep(AST.VariableStatement([], modifiers, [declaration], first, declaration))
				}
				else {
					if @test(Token::AWAIT) {
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

			while @test(Token::COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, false, false)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last))
		} # }}}
		tryVarLateStatement(first: Event, eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var modifiers = [@yep(AST.Modifier(ModifierKind::LateInit, @yes()))]

			var mark = @mark()

			if @test(Token::LEFT_CURLY) {
				@commit()

				var declarations = []
				var mut ok = @tryNL_1M().ok

				if ok {
					while @until(Token::RIGHT_CURLY) {
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
					unless @test(Token::RIGHT_CURLY) {
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

			while @test(Token::COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, true, true)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last))
		} # }}}
		tryVarMutStatement(first: Event, eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var modifiers = [@yep(AST.Modifier(ModifierKind::Mutable, @yes()))]

			var mark = @mark()

			if @test(Token::LEFT_CURLY) {
				@commit()

				var declarations = []
				var mut ok = @tryNL_1M().ok

				if ok {
					while @until(Token::RIGHT_CURLY) {
						var variable = @tryTypedVariable(fMode, true, true)
						if !variable.ok {
							ok = false

							break
						}

						if @test(Token::EQUALS) {
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
					unless @test(Token::RIGHT_CURLY) {
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

			if @test(Token::COMMA) {
				@commit()

				var variable = @tryTypedVariable(fMode, true, true)

				return NO unless variable.ok

				variables.push(variable)
			}

			if variables.length == 1 {
				if @test(Token::EQUALS) {
					@commit().NL_0M()

					value = @reqExpression(eMode + ExpressionMode::ImplicitMember, fMode)

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

			if @test(Token::EQUALS) {
				@commit().NL_0M()

				if @test(Token::AWAIT) {
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

			while @test(Token::COMMA) {
				@commit()

				var variable = @reqTypedVariable(fMode, true, false)

				declarations.push(@yep(AST.VariableDeclaration([], [], [variable], null, null, variable, variable)))

				last = variable
			}

			return @yep(AST.VariableStatement([], modifiers, declarations, first, last))
		} # }}}
		tryWhileStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var dyn condition

			if @test(Token::VAR) {
				var mark = @mark()
				var first = @yes()

				var modifiers = []
				if @test(Token::MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Mutable, @yes())))
				}
				else {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Immutable, @yes())))
				}

				if @test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					if @test(Token::COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token::COMMA)

						var operator = @reqConditionAssignment()

						unless @test(Token::AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						condition = @yep(AST.VariableDeclaration([], modifiers, variables, operator, expression, first, expression))
					}
					else {
						var operator = @reqConditionAssignment()
						var expression = @reqExpression(ExpressionMode::Default, fMode)

						condition = @yep(AST.VariableDeclaration([], modifiers, [variable], operator, expression, first, expression))
					}
				}
				else {
					@rollback(mark)

					condition = @tryExpression(ExpressionMode::Default, fMode)
				}
			}
			else {
				condition = @tryExpression(ExpressionMode::Default, fMode)
			}

			unless condition.ok {
				return NO
			}

			var dyn body
			if @match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				body = @reqBlock(@yes(), fMode)
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				@commit()

				body = @reqExpression(ExpressionMode::Default, fMode)
			}
			else {
				@throw('{', '=>')
			}

			return @yep(AST.WhileStatement(condition, body, first, body))
		} # }}}
		tryWithVariable(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if @test(Token::VAR) {
				var mark = @mark()
				var first = @yes()

				var modifiers = []
				if @test(Token::MUT) {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Mutable, @yes())))
				}
				else {
					modifiers.push(@yep(AST.Modifier(ModifierKind::Immutable, @yes())))
				}

				if @test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					var variable = @reqTypedVariable(fMode)

					if @test(Token::COMMA) {
						var variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token::COMMA)

						if @test(Token::EQUALS) {
							@commit()
						}
						else {
							@throw('=')
						}

						unless @test(Token::AWAIT) {
							@throw('await')
						}

						@commit()

						var operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)
						var expression = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))

						return @yep(AST.VariableDeclaration([], modifiers, variables, null, expression, first, expression))
					}
					else {
						if @test(Token::EQUALS) {
							@commit()
						}
						else {
							@throw('=')
						}

						var expression = @reqExpression(ExpressionMode::Default, fMode)

						return @yep(AST.VariableDeclaration([], modifiers, [variable], null, expression, first, expression))
					}
				}

				@rollback(mark)
			}

			var variable = @tryVariableName(fMode)

			return NO unless variable.ok

			var late operator: Event

			match @matchM(M.ASSIGNEMENT_OPERATOR) {
				Token::AMPERSAND_AMPERSAND_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::And, @yes()))
				}
				Token::ASTERISK_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Multiplication, @yes()))
				}
				Token::CARET_CARET_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Xor, @yes()))
				}
				Token::EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Equals, @yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::LeftShift, @yes()))
				}
				Token::MINUS_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Subtraction, @yes()))
				}
				Token::PERCENT_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Modulo, @yes()))
				}
				Token::PIPE_PIPE_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Or, @yes()))
				}
				Token::PLUS_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Addition, @yes()))
				}
				Token::RIGHT_ANGLE_RIGHT_ANGLE_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::RightShift, @yes()))
				}
				Token::SLASH_DOT_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Quotient, @yes()))
				}
				Token::SLASH_EQUALS {
					operator = @yep(AST.AssignmentOperator(AssignmentOperatorKind::Division, @yes()))
				}
				else {
					@throw('=', '+=', '-=', '*=', '/=', '/.=', '%=', '&&=', '||=', '^^=', '<<=', '>>=')
				}
			}

			var value = @reqExpression(null, fMode)

			return @yep(AST.BinaryExpression(variable, operator, value, variable, value))
		} # }}}
		tryWithStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			var mut mark = @mark()
			var variables = []

			if @test(Token::LEFT_CURLY) {
				@commit()

				var mut ok = @tryNL_1M().ok

				if ok {
					while @until(Token::RIGHT_CURLY) {
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

				if @test(Token::RIGHT_CURLY) {
					@commit()
				}
				else {
					@throw('}')
				}

				@reqNL_1M()

				if @test(Token::THEN) {
					@commit()
				}
				else {
					@throw('then')
				}
			}
			else {
				var variable = @tryWithVariable(fMode)

				return NO unless variable.ok

				variables.push(variable)
			}

			var body = @reqBlock(NO, fMode)
			var mut finalizer = null

			mark = @mark()

			if @tryNL_1M().ok && @test(Token::FINALLY) {
				@commit()

				finalizer = @reqBlock(NO, fMode)
			}
			else {
				@rollback(mark)
			}

			return @yep(AST.WithStatement(variables, body, finalizer, first, finalizer ?? body))
		} # }}}
	}

	func parse(data: String) ~ SyntaxError { # {{{
		var parser = new Parser(data)

		return parser.parseModule()
	} # }}}

	func parseStatements(data: String, mode: FunctionMode) ~ SyntaxError { # {{{
		var parser = new Parser(data)

		return parser.parseStatements(mode)
	} # }}}

	export {
		FunctionMode

		parse
		parseStatements
	}
}

export Parser.parse
