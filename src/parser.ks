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
		identifier		= null
	}

	flagged enum DestructuringMode {
		Nil

		COMPUTED
		DEFAULT
		RECURSION
		THIS_ALIAS
		TYPE

		Declaration			= COMPUTED + DEFAULT + RECURSION + TYPE
		Expression			= COMPUTED + DEFAULT + RECURSION
		Parameter			= DEFAULT + RECURSION + TYPE
	}

	flagged enum ExpressionMode {
		Default
		NoAnonymousFunction
		NoAwait
		NoObject
		WithMacro
	}

	flagged enum ExternMode {
		Default
		Fallthrough
		Namespace
	}

	enum FunctionMode {
		Function
		Macro
		Method
	}

	flagged enum MacroTerminator {
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

	flagged enum ParserMode {
		Default
		MacroExpression
		Typing
	}

	flagged enum ClassBits {
		AbstractMethod		 = 1
		Attribute
		DynamicVariable
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
		RequiredAssignment
		Variable
	}

	const NO = Event(ok: false)

	class Parser {
		private {
			_mode: ParserMode	= ParserMode::Default
			_scanner: Scanner
			_token: Token?
		}
		constructor(data: String) ~ SyntaxError { # {{{
			@scanner = new Scanner(data)
		} # }}}
		commit(): this { # {{{
			@token = @scanner.commit()
		} # }}}
		error(message: String): SyntaxError { # {{{
			const error = new SyntaxError(message)

			error.lineNumber = @scanner.line()
			error.columnNumber = @scanner.column()

			return error
		} # }}}
		mark(): Marker => @scanner.mark()
		match(...tokens: Token): Token => @token = @scanner.match(...tokens)
		matchM(matcher: Function): Token => @token = @scanner.matchM(matcher)
		position(): Range => @scanner.position()
		printDebug(prefix: String? = null): Void { # {{{
			if prefix? {
				console.log(prefix, @scanner.toDebug())
			}
			else {
				console.log(@scanner.toDebug())
			}
		} # }}}
		relocate(event: Event, first: Event?, last: Event?): Event { # {{{
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
		testNS(token): Boolean { # {{{
			if @scanner.testNS(token) {
				@token = token

				return true
			}
			else {
				return false
			}
		} # }}}
		throw(): Never ~ SyntaxError { # {{{
			throw @error(`Unexpected \(@scanner.toQuote())`)
		} # }}}
		throw(expected: String): Never ~ SyntaxError { # {{{
			throw @error(`Expecting "\(expected)" but got \(@scanner.toQuote())`)
		} # }}}
		throw(expecteds: Array): Never ~ SyntaxError { # {{{
			throw @error(`Expecting "\(expecteds.slice(0, expecteds.length - 1).join('", "'))" or "\(expecteds[expecteds.length - 1])" but got \(@scanner.toQuote())`)
		} # }}}
		until(token): Boolean => !@scanner.test(token) && !@scanner.isEOF()
		value(): String | Array<String> => @scanner.value(@token!?)
		yep(): Event { # {{{
			const position = @scanner.position()

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
			const position = @scanner.position()

			this.commit()

			return Event(
				ok: true
				start: position.start
				end: position.end
			)
		} # }}}
		yes(value): Event { # {{{
			const start: Position = value.start ?? @scanner.startPosition()
			const end: Position = value.end ?? @scanner.endPosition()

			this.commit()

			return Event(
				ok: true
				value: value
				start: start
				end: end
			)
		} # }}}
		NL_0M() ~ SyntaxError { # {{{
			@skipNewLine()
		} # }}}
		altArrayComprehension(expression: Event, first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const loop = this.reqForExpression(this.yes(), fMode)

			this.NL_0M()

			unless this.test(Token::RIGHT_SQUARE) {
				this.throw(']')
			}

			return this.yep(AST.ArrayComprehension(expression, loop, first, this.yes()))
		} # }}}
		altArrayList(expression: Event, first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const values = [expression]

			do {
				if this.match(Token::RIGHT_SQUARE, Token::COMMA, Token::NEWLINE) == Token::RIGHT_SQUARE {
					return this.yep(AST.ArrayExpression(values, first, this.yes()))
				}
				else if @token == Token::COMMA {
					this.commit().NL_0M()

					values.push(this.reqExpression(null, fMode, MacroTerminator::Array))
				}
				else if @token == Token::NEWLINE {
					this.commit().NL_0M()

					if this.match(Token::RIGHT_SQUARE, Token::COMMA) == Token::COMMA {
						this.commit().NL_0M()

						values.push(this.reqExpression(null, fMode, MacroTerminator::Array))
					}
					else if @token == Token::RIGHT_SQUARE {
						return this.yep(AST.ArrayExpression(values, first, this.yes()))
					}
					else {
						values.push(this.reqExpression(null, fMode, MacroTerminator::Array))
					}
				}
				else {
					break
				}
			}
			while true

			this.throw(']')
		} # }}}
		altForExpressionFrom(modifiers, variable: Event, first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const from = this.reqExpression(ExpressionMode::Default, fMode)

			let til, to
			if this.match(Token::TIL, Token::TO) == Token::TIL {
				this.commit()

				til = this.reqExpression(ExpressionMode::Default, fMode)
			}
			else if @token == Token::TO {
				this.commit()

				to = this.reqExpression(ExpressionMode::Default, fMode)
			}
			else {
				this.throw(['til', 'to'])
			}

			let by
			if this.test(Token::BY) {
				this.commit()

				by = this.reqExpression(ExpressionMode::Default, fMode)
			}

			let until, while
			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				until = this.reqExpression(ExpressionMode::Default, fMode)
			}
			else if @token == Token::WHILE {
				this.commit()

				while = this.reqExpression(ExpressionMode::Default, fMode)
			}

			this.NL_0M()

			let whenExp
			if this.test(Token::WHEN) {
				const first = this.yes()

				whenExp = this.relocate(this.reqExpression(ExpressionMode::Default, fMode), first, null)
			}

			return this.yep(AST.ForFromStatement(modifiers, variable, from, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? from))
		} # }}}
		altForExpressionIn(modifiers, value: Event, type: Event, index: Event, expression: Event, first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let desc = null
			if this.test(Token::DESC) {
				desc = this.yes()

				modifiers.push(AST.Modifier(ModifierKind::Descending, desc))
			}

			this.NL_0M()

			let from, til, to, by
			if this.test(Token::FROM) {
				this.commit()

				from = this.reqExpression(ExpressionMode::Default, fMode)
			}
			if this.match(Token::TIL, Token::TO) == Token::TIL {
				this.commit()

				til = this.reqExpression(ExpressionMode::Default, fMode)
			}
			else if @token == Token::TO {
				this.commit()

				to = this.reqExpression(ExpressionMode::Default, fMode)
			}
			if this.test(Token::BY) {
				this.commit()

				by = this.reqExpression(ExpressionMode::Default, fMode)
			}

			this.NL_0M()

			let until, while
			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				until = this.reqExpression(ExpressionMode::Default, fMode)
			}
			else if @token == Token::WHILE {
				this.commit()

				while = this.reqExpression(ExpressionMode::Default, fMode)
			}

			this.NL_0M()

			let whenExp
			if this.test(Token::WHEN) {
				const first = this.yes()

				whenExp = this.relocate(this.reqExpression(ExpressionMode::Default, fMode), first, null)
			}

			return this.yep(AST.ForInStatement(modifiers, value, type, index, expression, from, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? from ?? desc ?? expression))
		} # }}}
		altForExpressionInRange(modifiers, value: Event, type: Event, index: Event, first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let operand = this.tryRangeOperand(ExpressionMode::Default, fMode)

			if operand.ok {
				if this.match(Token::LEFT_ANGLE, Token::DOT_DOT) == Token::LEFT_ANGLE || @token == Token::DOT_DOT {
					const then = @token == Token::LEFT_ANGLE
					if then {
						this.commit()

						unless this.test(Token::DOT_DOT) {
							this.throw('..')
						}

						this.commit()
					}
					else {
						this.commit()
					}

					const til = this.test(Token::LEFT_ANGLE)
					if til {
						this.commit()
					}

					const toOperand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)

					let byOperand
					if this.test(Token::DOT_DOT) {
						this.commit()

						byOperand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)
					}

					return this.altForExpressionRange(modifiers, value, index, then ? null : operand, then ? operand : null, til ? toOperand : null, til ? null : toOperand, byOperand, first, fMode)
				}
				else {
					return this.altForExpressionIn(modifiers, value, type, index, operand, first, fMode)
				}
			}
			else {
				return this.altForExpressionIn(modifiers, value, type, index, this.reqExpression(ExpressionMode::Default, fMode), first, fMode)
			}
		} # }}}
		altForExpressionOf(modifiers, value: Event, type: Event, key: Event, first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const expression = this.reqExpression(ExpressionMode::Default, fMode)

			let until, while
			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				until = this.reqExpression(ExpressionMode::Default, fMode)
			}
			else if @token == Token::WHILE {
				this.commit()

				while = this.reqExpression(ExpressionMode::Default, fMode)
			}

			this.NL_0M()

			let whenExp
			if this.test(Token::WHEN) {
				const first = this.yes()

				whenExp = this.relocate(this.reqExpression(ExpressionMode::Default, fMode), first, null)
			}

			return this.yep(AST.ForOfStatement(modifiers, value, type, key, expression, until, while, whenExp, first, whenExp ?? while ?? until ?? expression))
		} # }}}
		altForExpressionRange(modifiers, value: Event, index: Event, from: Event?, then: Event?, til: Event?, to: Event?, by: Event?, first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let until, while
			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				until = this.reqExpression(ExpressionMode::Default, fMode)
			}
			else if @token == Token::WHILE {
				this.commit()

				while = this.reqExpression(ExpressionMode::Default, fMode)
			}

			this.NL_0M()

			let whenExp
			if this.test(Token::WHEN) {
				const first = this.yes()

				whenExp = this.relocate(this.reqExpression(ExpressionMode::Default, fMode), first, null)
			}

			return this.yep(AST.ForRangeStatement(modifiers, value, index, from, then, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? then ?? from:Any))
		} # }}}
		isAmbiguousIdentifier(result: AmbiguityResult): Boolean ~ SyntaxError { # {{{
			if this.test(Token::IDENTIFIER) {
				result.token = null
				result.identifier = this.yep(AST.Identifier(@scanner.value(), this.yes()))

				return true
			}
			else {
				return false
			}
		} # }}}
		isAmbiguousAccessModifierForEnum(modifiers: Array<Event>, result: AmbiguityResult): Boolean ~ SyntaxError { # {{{
			lateinit const identifier
			lateinit const token: Token

			if this.test(Token::PRIVATE, Token::PUBLIC, Token::INTERNAL) {
				token = @token!?
				identifier = AST.Identifier(@scanner.value(), this.yes())
			}
			else {
				return false
			}

			if this.test(Token::EQUALS, Token::LEFT_ROUND) {
				result.token = @token
				result.identifier = this.yep(identifier)

				return true
			}
			else {
				if token == Token::PRIVATE {
					modifiers.push(this.yep(AST.Modifier(ModifierKind::Private, identifier)))
				}
				else if token == Token::PUBLIC {
					modifiers.push(this.yep(AST.Modifier(ModifierKind::Public, identifier)))
				}
				else {
					modifiers.push(this.yep(AST.Modifier(ModifierKind::Internal, identifier)))
				}

				result.token = null
				result.identifier = this.yep(identifier)

				return false
			}
		} # }}}
		isAmbiguousAsyncModifier(modifiers: Array<Event>, result: AmbiguityResult): Boolean ~ SyntaxError { # {{{
			unless this.test(Token::ASYNC) {
				return false
			}

			const identifier = AST.Identifier(@scanner.value(), this.yes())

			if this.test(Token::IDENTIFIER) {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Async, identifier)))

				result.token = @token
				result.identifier = this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				result.token = null
				result.identifier = this.yep(identifier)
			}

			return true
		} # }}}
		isAmbiguousStaticModifier(modifiers: Array<Event>, result: AmbiguityResult): Boolean ~ SyntaxError { # {{{
			lateinit const identifier

			if this.test(Token::STATIC) {
				identifier = AST.Identifier(@scanner.value(), this.yes())
			}
			else {
				return false
			}

			if this.test(Token::EQUALS, Token::LEFT_ROUND) {
				result.token = @token
				result.identifier = this.yep(identifier)

				return true
			}
			else {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Static, identifier)))

				result.token = null
				result.identifier = this.yep(identifier)

				return false
			}
		} # }}}
		reqAccessModifiers(modifiers: Array<Event>): Array<Event> ~ SyntaxError { # {{{
			if this.match(Token::PRIVATE, Token::PROTECTED, Token::PUBLIC, Token::INTERNAL) == Token::PRIVATE {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Private, this.yes())))
			}
			else if @token == Token::PROTECTED {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Protected, this.yes())))
			}
			else if @token == Token::PUBLIC {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Public, this.yes())))
			}
			else if @token == Token::INTERNAL {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Internal, this.yes())))
			}

			return modifiers
		} # }}}
		reqArray(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if this.test(Token::RIGHT_SQUARE) {
				return this.yep(AST.ArrayExpression([], first, this.yes()))
			}

			const mark = this.mark()

			let operand = this.tryRangeOperand(ExpressionMode::Default, fMode)

			if operand.ok && (this.match(Token::LEFT_ANGLE, Token::DOT_DOT) == Token::LEFT_ANGLE || @token == Token::DOT_DOT) {
				const then = @token == Token::LEFT_ANGLE
				if then {
					this.commit()

					unless this.test(Token::DOT_DOT) {
						this.throw('..')
					}

					this.commit()
				}
				else {
					this.commit()
				}

				const til = this.test(Token::LEFT_ANGLE)
				if til {
					this.commit()
				}

				const toOperand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)

				let byOperand
				if this.test(Token::DOT_DOT) {
					this.commit()

					byOperand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)
				}

				unless this.test(Token::RIGHT_SQUARE) {
					this.throw(']')
				}

				if then {
					if til {
						return this.yep(AST.ArrayRangeTI(operand, toOperand, byOperand, first, this.yes()))
					}
					else {
						return this.yep(AST.ArrayRangeTO(operand, toOperand, byOperand, first, this.yes()))
					}
				}
				else {
					if til {
						return this.yep(AST.ArrayRangeFI(operand, toOperand, byOperand, first, this.yes()))
					}
					else {
						return this.yep(AST.ArrayRangeFO(operand, toOperand, byOperand, first, this.yes()))
					}
				}
			}
			else {
				this.rollback(mark)

				this.NL_0M()

				if this.test(Token::RIGHT_SQUARE) {
					return this.yep(AST.ArrayExpression([], first, this.yes()))
				}

				const expression = this.reqExpression(null, fMode, MacroTerminator::Array)

				if this.match(Token::RIGHT_SQUARE, Token::FOR, Token::NEWLINE) == Token::RIGHT_SQUARE {
					return this.yep(AST.ArrayExpression([expression], first, this.yes()))
				}
				else if @token == Token::FOR {
					return this.altArrayComprehension(expression, first, fMode)
				}
				else if @token == Token::NEWLINE {
					const mark = this.mark()

					this.commit().NL_0M()

					if this.match(Token::RIGHT_SQUARE, Token::FOR) == Token::RIGHT_SQUARE {
						return this.yep(AST.ArrayExpression([expression], first, this.yes()))
					}
					else if @token == Token::FOR {
						return this.altArrayComprehension(expression, first, fMode)
					}
					else {
						this.rollback(mark)

						return this.altArrayList(expression, first, fMode)
					}
				}
				else {
					return this.altArrayList(expression, first, fMode)
				}
			}
		} # }}}
		reqAttribute(first: Event): Event ~ SyntaxError { # {{{
			const declaration = this.reqAttributeMember()

			unless this.test(Token::RIGHT_SQUARE) {
				this.throw(']')
			}

			const last = this.yes()

			unless this.test(Token::NEWLINE) {
				this.throw('NewLine')
			}

			this.commit()

			@scanner.skipComments()

			return this.yep(AST.AttributeDeclaration(declaration, first, last))
		} # }}}
		reqAttributeIdentifier(): Event ~ SyntaxError { # {{{
			if @scanner.test(Token::ATTRIBUTE_IDENTIFIER) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				this.throw('Identifier')
			}
		} # }}}
		reqAttributeMember(): Event ~ SyntaxError { # {{{
			const identifier = this.reqAttributeIdentifier()

			if this.match(Token::EQUALS, Token::LEFT_ROUND) == Token::EQUALS {
				this.commit()

				const value = this.reqString()

				return this.yep(AST.AttributeOperation(identifier, value, identifier, value))
			}
			else if @token == Token::LEFT_ROUND {
				this.commit()

				const arguments = [this.reqAttributeMember()]

				while this.test(Token::COMMA) {
					this.commit()

					arguments.push(this.reqAttributeMember())
				}

				if !this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				return this.yep(AST.AttributeExpression(identifier, arguments, identifier, this.yes()))
			}
			else {
				return identifier
			}
		} # }}}
		reqAwaitExpression(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const operand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)

			return this.yep(AST.AwaitExpression([], null, operand, first, operand))
		} # }}}
		reqBinaryOperand(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const mark = this.mark()

			let expression
			if (expression = this.tryAwaitExpression(eMode, fMode)).ok {
				return expression
			}
			else if this.rollback(mark) && (expression = this.tryFunctionExpression(eMode, fMode)).ok {
				return expression
			}
			else if this.rollback(mark) && (expression = this.trySwitchExpression(eMode, fMode)).ok {
				return expression
			}
			else if this.rollback(mark) && (expression = this.tryTryExpression(eMode, fMode)).ok {
				return expression
			}

			this.rollback(mark)

			return this.reqPrefixedOperand(eMode, fMode)
		} # }}}
		reqBlock(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if !first.ok {
				unless this.test(Token::LEFT_CURLY) {
					this.throw('{')
				}

				first = this.yes()
			}

			this.NL_0M()

			const attributes = []
			const statements = []

			let attrs = []
			let statement
			while this.match(Token::RIGHT_CURLY, Token::HASH_EXCLAMATION_LEFT_SQUARE, Token::HASH_LEFT_SQUARE) != Token::EOF && @token != Token::RIGHT_CURLY {
				if this.stackInnerAttributes(attributes) {
					continue
				}

				this.stackOuterAttributes(attrs)

				statement = this.reqStatement(fMode)

				if attrs.length > 0 {
					statement.value.attributes.unshift(...[attr.value for const attr in attrs])
					statement.value.start = statement.value.attributes[0].start

					attrs = []
				}

				statements.push(statement)

				this.NL_0M()
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yep(AST.Block(attributes, statements, first, this.yes()))
		} # }}}
		reqBreakStatement(first: Event): Event { # {{{
			return this.yep(AST.BreakStatement(first))
		} # }}}
		reqCatchOnClause(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const type = this.reqIdentifier()

			let binding
			if this.test(Token::CATCH) {
				this.commit()

				binding = this.reqIdentifier()
			}

			this.NL_0M()

			const body = this.reqBlock(NO, fMode)

			return this.yep(AST.CatchClause(binding, type, body, first, body))
		} # }}}
		reqClassMember(attributes, modifiers, bits: ClassBits, first: Event?): Event ~ SyntaxError { # {{{
			const member = @tryClassMember(attributes, modifiers, bits, first)

			unless member.ok {
				@throw(['Identifier', 'String', 'Template'])
			}

			return member
		} # }}}
		reqClassMemberBlock(attributes, modifiers, bits: ClassBits, members: Array<Event>): Void ~ SyntaxError { # {{{
			@commit().NL_0M()

			let attrs = [...attributes]

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
			let first = null

			const attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			const macroMark = @mark()

			if @test(Token::MACRO) {
				const second = @yes()

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

			const accessMark = @mark()
			const accessModifier = @tryAccessModifier()

			if accessModifier.ok && @test(Token::LEFT_CURLY) {
				return @reqClassMemberBlock(
					attributes
					[accessModifier]
					ClassBits::Variable + ClassBits::DynamicVariable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method
					members
				)
			}

			if @test(Token::ABSTRACT) {
				const mark = @mark()
				const modifier = @yep(AST.Modifier(ModifierKind::Abstract, @yes()))

				if @test(Token::LEFT_CURLY) {
					const modifiers = [modifier]
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
				const mark = @mark()
				const modifier = @yep(AST.Modifier(ModifierKind::Override, @yes()))

				if @test(Token::LEFT_CURLY) {
					const modifiers = [modifier]
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

			const staticMark = @mark()
			let staticModifier = NO

			if @test(Token::STATIC) {
				staticModifier = @yep(AST.Modifier(ModifierKind::Static, @yes()))

				if @test(Token::LEFT_CURLY) {
					const modifiers = [staticModifier]
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

			const finalMark = @mark()
			let finalModifier = NO

			if @test(Token::FINAL) {
				finalModifier = @yep(AST.Modifier(ModifierKind::Immutable, @yes()))

				if @test(Token::LEFT_CURLY) {
					const modifiers = [finalModifier]
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
					const mark = @mark()
					const modifier = @yep(AST.Modifier(ModifierKind::Override, @yes()))

					if @test(Token::LEFT_CURLY) {
						const modifiers = [finalModifier, modifier]
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
				const lateMark = @mark()
				const lateModifier = @yep(AST.Modifier(ModifierKind::LateInit, @yes()))

				const modifiers = [lateModifier]
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
						finalModifier.ok ? ClassBits::Variable : ClassBits::Variable + ClassBits::FinalVariable + ClassBits::DynamicVariable
						members
					)
				}

				const member = @tryClassMember(
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
				const member = @tryClassMember(attributes, [accessModifier], staticModifier, staticMark, finalModifier, finalMark, first ?? accessModifier)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(accessMark)
			}

			const member = @tryClassMember(attributes, [], staticModifier, staticMark, finalModifier, finalMark, first)

			unless member.ok {
				@throw(['Identifier', 'String', 'Template'])
			}

			members.push(member)
		} # }}}
		reqClassMethod(attributes, modifiers, bits: ClassBits, name: Event, round: Event?, first: Event?): Event ~ SyntaxError { # {{{
			const parameters = this.reqClassMethodParameterList(round)
			const type = this.tryMethodReturns(bits !~ ClassBits::NoBody)
			const throws = this.tryFunctionThrows()

			if bits ~~ ClassBits::NoBody {
				this.reqNL_1M()

				return this.yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, null, first, throws ?? type ?? parameters))
			}
			else {
				const body = this.tryFunctionBody(FunctionMode::Method)

				this.reqNL_1M()

				return this.yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, body, first, body ?? throws ?? type ?? parameters))
			}
		} # }}}
		reqClassMethodParameterList(top: Event = NO): Event ~ SyntaxError { # {{{
			if !top.ok {
				unless this.test(Token::LEFT_ROUND) {
					this.throw('(')
				}

				top = this.yes()
			}

			const parameters = []
			const pMode = DestructuringMode::Parameter ||| DestructuringMode::THIS_ALIAS

			while this.until(Token::RIGHT_ROUND) {
				while this.reqParameter(parameters, pMode, FunctionMode::Method) {
				}
			}

			unless this.test(Token::RIGHT_ROUND) {
				this.throw(')')
			}

			return this.yep(parameters, top, this.yes())
		} # }}}
		reqClassProperty(attributes, modifiers, name: Event, type: Event?, first: Event): Event ~ SyntaxError { # {{{
			let defaultValue, accessor, mutator

			if this.test(Token::NEWLINE) {
				this.commit().NL_0M()

				if this.match(Token::GET, Token::SET) == Token::GET {
					const first = this.yes()

					if this.match(Token::EQUALS_RIGHT_ANGLE, Token::LEFT_CURLY) == Token::EQUALS_RIGHT_ANGLE {
						this.commit()

						const expression = this.reqExpression(ExpressionMode::Default, FunctionMode::Method)

						accessor = this.yep(AST.AccessorDeclaration(expression, first, expression))
					}
					else if @token == Token::LEFT_CURLY {
						const block = this.reqBlock(NO, FunctionMode::Method)

						accessor = this.yep(AST.AccessorDeclaration(block, first, block))
					}
					else {
						accessor = this.yep(AST.AccessorDeclaration(first))
					}

					this.reqNL_1M()

					if this.test(Token::SET) {
						const first = this.yes()

						if this.match(Token::EQUALS_RIGHT_ANGLE, Token::LEFT_CURLY) == Token::EQUALS_RIGHT_ANGLE {
							this.commit()

							const expression = this.reqExpression(ExpressionMode::Default, FunctionMode::Method)

							mutator = this.yep(AST.MutatorDeclaration(expression, first, expression))
						}
						else if @token == Token::LEFT_CURLY {
							const block = this.reqBlock(NO, FunctionMode::Method)

							mutator = this.yep(AST.MutatorDeclaration(block, first, block))
						}
						else {
							mutator = this.yep(AST.MutatorDeclaration(first))
						}

						this.reqNL_1M()
					}
				}
				else if @token == Token::SET {
					const first = this.yes()

					if this.match(Token::EQUALS_RIGHT_ANGLE, Token::LEFT_CURLY) == Token::EQUALS_RIGHT_ANGLE {
						this.commit()

						const expression = this.reqExpression(ExpressionMode::Default, FunctionMode::Method)

						mutator = this.yep(AST.MutatorDeclaration(expression, first, expression))
					}
					else if @token == Token::LEFT_CURLY {
						const block = this.reqBlock(NO, FunctionMode::Method)

						mutator = this.yep(AST.MutatorDeclaration(block, first, block))
					}
					else {
						mutator = this.yep(AST.MutatorDeclaration(first))
					}

					this.reqNL_1M()
				}
				else {
					this.throw(['get', 'set'])
				}
			}
			else {
				if this.match(Token::GET, Token::SET) == Token::GET {
					accessor = this.yep(AST.AccessorDeclaration(this.yes()))

					if this.test(Token::COMMA) {
						this.commit()

						if this.test(Token::SET) {
							mutator = this.yep(AST.MutatorDeclaration(this.yes()))
						}
						else {
							this.throw('set')
						}
					}
				}
				else if @token == Token::SET {
					mutator = this.yep(AST.MutatorDeclaration(this.yes()))
				}
				else {
					this.throw(['get', 'set'])
				}
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			let last = this.yes()

			if this.test(Token::EQUALS) {
				this.commit()

				defaultValue = this.reqExpression(ExpressionMode::Default, FunctionMode::Method)
			}

			this.reqNL_1M()

			return this.yep(AST.PropertyDeclaration(attributes, modifiers, name, type, defaultValue, accessor, mutator, first, defaultValue ?? last))
		} # }}}
		reqClassStatement(first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			return this.reqClassStatementBody(this.reqIdentifier(), first, modifiers)
		} # }}}
		reqClassStatementBody(name: Event, first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			let generic
			if this.test(Token::LEFT_ANGLE) {
				generic = this.reqTypeGeneric(this.yes())
			}

			let version
			if this.test(Token::AT) {
				this.commit()

				unless this.test(Token::CLASS_VERSION) {
					this.throw('Class Version')
				}

				const data = this.value()

				version = this.yes({
					major: data[0]
					minor: data.length > 1 ? data[1] : 0
					patch: data.length > 2 ? data[2] : 0
				})
				version.value.start = version.start
				version.value.end = version.end
			}

			let extends
			if this.test(Token::EXTENDS) {
				this.commit()

				extends = this.reqIdentifier()

				if this.testNS(Token::DOT) {
					let property

					do {
						this.commit()

						property = this.reqIdentifier()

						extends = this.yep(AST.MemberExpression([], extends, property))
					}
					while this.testNS(Token::DOT)
				}
			}

			unless this.test(Token::LEFT_CURLY) {
				this.throw('{')
			}

			this.commit().NL_0M()

			const attributes = []
			const members = []

			while this.until(Token::RIGHT_CURLY) {
				if this.stackInnerAttributes(attributes) {
					continue
				}

				this.reqClassMemberList(members)
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yep(AST.ClassDeclaration(attributes, name, version, extends, modifiers, members, first, this.yes()))
		} # }}}
		reqClassVariable(attributes, modifiers, bits: ClassBits, name: Event?, first: Event?): Event ~ SyntaxError { # {{{
			const variable = @tryClassVariable(attributes, modifiers, bits, name, null, first)

			unless variable.ok {
				@throw(['Identifier', 'String', 'Template'])
			}

			return variable
		} # }}}
		reqComputedPropertyName(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const expression = this.reqExpression(ExpressionMode::Default, fMode)

			unless this.test(Token::RIGHT_SQUARE) {
				this.throw(']')
			}

			return this.yep(AST.ComputedPropertyName(expression, first, this.yes()))
		} # }}}
		reqContinueStatement(first: Event): Event { # {{{
			return this.yep(AST.ContinueStatement(first))
		} # }}}
		reqDestructuringArray(first: Event, dMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const elements = []

			while true {
				elements.push(this.reqDestructuringArrayItem(dMode, fMode))

				if this.match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
					this.commit().NL_0M()

					continue
				}
				else if @token == Token::NEWLINE {
					this.commit().NL_0M()

					if this.test(Token::RIGHT_SQUARE) {
						break
					}
				}
				else {
					break
				}
			}

			unless this.test(Token::RIGHT_SQUARE) {
				this.throw(']')
			}

			return this.yep(AST.ArrayBinding(elements, first, this.yes()))
		} # }}}
		reqDestructuringArrayItem(dMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const modifiers = []
			let first = null
			let name = null
			let type = null
			let notThis = true

			if this.test(Token::DOT_DOT_DOT) {
				modifiers.push(AST.Modifier(ModifierKind::Rest, first = this.yes()))

				if dMode ~~ DestructuringMode::THIS_ALIAS && this.test(Token::AT) {
					name = this.reqThisExpression(this.yes())
					notThis = false
				}
				else if this.test(Token::IDENTIFIER) {
					name = this.yep(AST.Identifier(@scanner.value(), this.yes()))
				}
			}
			else if dMode ~~ DestructuringMode::RECURSION && this.test(Token::LEFT_CURLY) {
				name = this.reqDestructuringObject(this.yes(), dMode, fMode)
			}
			else if dMode ~~ DestructuringMode::RECURSION && this.test(Token::LEFT_SQUARE) {
				name = this.reqDestructuringArray(this.yes(), dMode, fMode)
			}
			else if dMode ~~ DestructuringMode::THIS_ALIAS && this.test(Token::AT) {
				name = this.reqThisExpression(this.yes())
				notThis = false
			}
			else if this.test(Token::IDENTIFIER) {
				name = this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else if this.test(Token::UNDERSCORE) {
				first = this.yes()
			}
			else {
				if dMode ~~ DestructuringMode::RECURSION {
					this.throw(['...', '_', '[', '{', 'Identifier'])
				}
				else {
					this.throw(['...', '_', 'Identifier'])
				}
			}

			if notThis && dMode ~~ DestructuringMode::TYPE && this.test(Token::COLON) {
				this.commit()

				type = this.reqTypeVar()
			}

			if name != null {
				let defaultValue = null

				if dMode ~~ DestructuringMode::DEFAULT && this.test(Token::EQUALS) {
					this.commit()

					defaultValue = this.reqExpression(ExpressionMode::Default, fMode)
				}

				return this.yep(AST.ArrayBindingElement(modifiers, name, type, defaultValue, first ?? name, defaultValue ?? type ?? name))
			}
			else {
				return this.yep(AST.ArrayBindingElement(modifiers, null, type, null, first ?? type ?? this.yep(), type ?? first ?? this.yep()))
			}
		} # }}}
		reqDestructuringObject(first: Event, dMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const elements = []

			while true {
				elements.push(this.reqDestructuringObjectItem(dMode, fMode))

				if this.match(Token::COMMA, Token::NEWLINE) == Token::COMMA || @token == Token::NEWLINE {
					this.commit().NL_0M()
				}
				else {
					break
				}

				if this.test(Token::RIGHT_CURLY) {
					break
				}
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yep(AST.ObjectBinding(elements, first, this.yes()))
		} # }}}
		reqDestructuringObjectItem(dMode: DestructuringMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let first
			const modifiers = []
			let name = null
			let alias = null
			let defaultValue = null
			let notThis = true

			if this.test(Token::DOT_DOT_DOT) {
				modifiers.push(AST.Modifier(ModifierKind::Rest, first = this.yes()))

				if dMode ~~ DestructuringMode::THIS_ALIAS && this.test(Token::AT) {
					name = this.reqThisExpression(this.yes())
					notThis = false
				}
				else {
					name = this.reqIdentifier()
				}
			}
			else {
				if dMode ~~ DestructuringMode::COMPUTED && this.test(Token::LEFT_SQUARE) {
					first = this.yes()

					if dMode ~~ DestructuringMode::THIS_ALIAS && this.test(Token::AT) {
						name = this.reqThisExpression(this.yes())
						notThis = false
					}
					else {
						name = this.reqIdentifier()
					}

					unless this.test(Token::RIGHT_SQUARE) {
						this.throw(']')
					}

					modifiers.push(AST.Modifier(ModifierKind::Computed, first, this.yes()))
				}
				else {
					if dMode ~~ DestructuringMode::THIS_ALIAS && this.test(Token::AT) {
						name = this.reqThisExpression(this.yes())
						notThis = false
					}
					else {
						name = this.reqIdentifier()
					}
				}

				if notThis && this.test(Token::COLON) {
					this.commit()

					if dMode ~~ DestructuringMode::RECURSION && this.test(Token::LEFT_CURLY) {
						alias = this.reqDestructuringObject(this.yes(), dMode, fMode)
					}
					else if dMode ~~ DestructuringMode::RECURSION && this.test(Token::LEFT_SQUARE) {
						alias = this.reqDestructuringArray(this.yes(), dMode, fMode)
					}
					else if dMode ~~ DestructuringMode::THIS_ALIAS && this.test(Token::AT) {
						alias = this.reqThisExpression(this.yes())
					}
					else {
						alias = this.reqIdentifier()
					}
				}
			}

			if dMode ~~ DestructuringMode::DEFAULT && this.test(Token::EQUALS) {
				this.commit()

				defaultValue = this.reqExpression(ExpressionMode::Default, fMode)
			}

			return this.yep(AST.ObjectBindingElement(modifiers, name, alias, defaultValue, first ?? name, defaultValue ?? alias ?? name))
		} # }}}
		reqDiscloseStatement(first: Event): Event ~ SyntaxError { # {{{
			const name = this.reqIdentifier()

			unless this.test(Token::LEFT_CURLY) {
				this.throw('{')
			}

			this.commit().NL_0M()

			const members = []

			while this.until(Token::RIGHT_CURLY) {
				this.reqExternClassMemberList(members)
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yep(AST.DiscloseDeclaration(name, members, first, this.yes()))
		} # }}}
		reqDoStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const body = this.reqBlock(NO, fMode)

			this.reqNL_1M()

			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.DoUntilStatement(condition, body, first, condition))
			}
			else if @token == Token::WHILE {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.DoWhileStatement(condition, body, first, condition))
			}
			else {
				this.throw(['until', 'while'])
			}
		} # }}}
		reqEnumMember(members: Array): Void ~ SyntaxError { # {{{
			const attributes = this.stackOuterAttributes([])
			const modifiers = []
			const result = AmbiguityResult()

			if this.isAmbiguousAccessModifierForEnum(modifiers, result) {
				this.submitEnumMember(attributes, modifiers, result.identifier, result.token, members)
			}
			else if this.isAmbiguousStaticModifier(modifiers, result) {
				this.submitEnumMember(attributes, modifiers, result.identifier, result.token, members)
			}
			else if this.isAmbiguousAsyncModifier(modifiers, result) {
				const {identifier, token} = result

				const first = attributes[0] ?? modifiers[0] ?? identifier

				if token == Token::IDENTIFIER {
					members.push(this.reqEnumMethod(attributes, modifiers, identifier, first).value)
				}
				else {
					this.submitEnumMember(attributes, modifiers, identifier, null, members)
				}
			}
			else if this.isAmbiguousIdentifier(result) {
				this.submitEnumMember(attributes, modifiers, result.identifier, null, members)
			}
			else {
				const mark = this.mark()

				this.NL_0M()

				if this.test(Token::LEFT_CURLY) {
					this.commit().NL_0M()

					let attrs

					while this.until(Token::RIGHT_CURLY) {
						attrs = this.stackOuterAttributes([])

						if attrs.length != 0 {
							attrs.unshift(...attributes)
						}
						else {
							attrs = attributes
						}

						members.push(this.reqEnumMethod(attrs, modifiers, attrs[0]).value)
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					this.commit().reqNL_1M()
				}
				else {
					this.rollback(mark)

					this.submitEnumMember(attributes, [], result.identifier, null, members)
				}
			}
		} # }}}
		reqEnumMethod(attributes, modifiers, first: Event?): Event ~ SyntaxError { # {{{
			let name
			if this.test(Token::ASYNC) {
				let async = this.reqIdentifier()

				name = this.tryIdentifier()

				if name.ok {
					modifiers = [...modifiers, this.yep(AST.Modifier(ModifierKind::Async, async))]
				}
				else {
					name = async
				}
			}
			else {
				name = this.reqIdentifier()
			}

			return this.reqEnumMethod(attributes, modifiers, name, first ?? name)
		} # }}}
		reqEnumMethod(attributes, modifiers, name: Event, first): Event ~ SyntaxError { # {{{
			const parameters = this.reqFunctionParameterList(FunctionMode::Function)

			const type = this.tryFunctionReturns()
			const throws = this.tryFunctionThrows()

			const body = @mode ~~ ParserMode::Typing ? null : this.reqFunctionBody(FunctionMode::Method)

			this.reqNL_1M()

			return this.yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, body, first, body ?? throws ?? type ?? parameters))

		} # }}}
		reqEnumStatement(first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			const name = this.tryIdentifier()
			unless name.ok {
				return NO
			}

			let type
			if this.test(Token::LEFT_ANGLE) {
				this.commit()

				type = this.reqTypeEntity(NO)

				unless this.test(Token::RIGHT_ANGLE) {
					this.throw('>')
				}

				this.commit()
			}

			this.NL_0M()

			unless this.test(Token::LEFT_CURLY) {
				this.throw('{')
			}

			this.commit().NL_0M()

			const attributes = []
			const members = []

			while this.until(Token::RIGHT_CURLY) {
				if this.stackInnerAttributes(attributes) {
					// do nothing
				}
				else {
					this.reqEnumMember(members)
				}
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yep(AST.EnumDeclaration(attributes, modifiers, name, type, members, first, this.yes()))
		} # }}}
		reqExportDeclarator(): Event ~ SyntaxError { # {{{
			switch this.matchM(M.EXPORT_STATEMENT) {
				Token::ABSTRACT => {
					const first = this.yes()

					if this.test(Token::CLASS) {
						this.commit()

						const modifiers = [this.yep(AST.Modifier(ModifierKind::Abstract, first))]

						return this.yep(AST.ExportDeclarationSpecifier(this.reqClassStatement(first, modifiers)))
					}
					else {
						this.throw('class')
					}
				}
				Token::ASYNC => {
					const first = this.reqIdentifier()

					if this.test(Token::FUNC) {
						this.commit()

						const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, first))]

						return this.yep(AST.ExportDeclarationSpecifier(this.reqFunctionStatement(first, modifiers)))
					}
					else {
						return this.reqExportIdentifier(first)
					}
				}
				Token::CLASS => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqClassStatement(this.yes())))
				}
				Token::ENUM => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqEnumStatement(this.yes())))
				}
				Token::FINAL => {
					const first = this.yes()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Immutable, first))]

					if this.test(Token::CLASS) {
						this.commit()

						return this.yep(AST.ExportDeclarationSpecifier(this.reqClassStatement(first, modifiers)))
					}
					else if this.test(Token::ABSTRACT) {
						modifiers.push(this.yep(AST.Modifier(ModifierKind::Abstract, this.yes())))

						if this.test(Token::CLASS) {
							this.commit()

							return this.yep(AST.ExportDeclarationSpecifier(this.reqClassStatement(first, modifiers)))
						}
						else {
							this.throw('class')
						}
					}
					else {
						this.throw('class')
					}
				}
				Token::FLAGGED => {
					const first = this.yes()

					if this.test(Token::ENUM) {
						this.commit()

						const modifiers = [this.yep(AST.Modifier(ModifierKind::Flagged, first))]

						return this.yep(AST.ExportDeclarationSpecifier(this.reqEnumStatement(first, modifiers)))
					}
					else {
						this.throw('enum')
					}
				}
				Token::FUNC => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqFunctionStatement(this.yes())))
				}
				Token::IDENTIFIER => {
					return this.reqExportIdentifier(this.reqIdentifier())
				}
				Token::MACRO => {
					if @mode !~ ParserMode::MacroExpression {
						return this.yep(AST.ExportDeclarationSpecifier(this.tryMacroStatement(this.yes())))
					}
					else {
						return this.yep(AST.ExportDeclarationSpecifier(this.reqMacroExpression(this.yes())))
					}
				}
				Token::NAMESPACE => {
					return this.yep(AST.ExportDeclarationSpecifier(this.tryNamespaceStatement(this.yes())))
				}
				Token::SEALED => {
					const first = this.yes()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Sealed, first))]

					if this.test(Token::CLASS) {
						this.commit()

						return this.yep(AST.ExportDeclarationSpecifier(this.reqClassStatement(first, modifiers)))
					}
					else if this.test(Token::ABSTRACT) {
						modifiers.push(this.yep(AST.Modifier(ModifierKind::Abstract, this.yes())))

						if this.test(Token::CLASS) {
							this.commit()

							return this.yep(AST.ExportDeclarationSpecifier(this.reqClassStatement(first, modifiers)))
						}
						else {
							this.throw('class')
						}
					}
					else {
						this.throw('class')
					}
				}
				Token::STRUCT => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqStructStatement(this.yes())))
				}
				Token::TUPLE => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqTupleStatement(this.yes())))
				}
				Token::TYPE => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqTypeStatement(this.yes(), this.reqIdentifier())))
				}
				Token::VAR => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqVarStatement(this.yes(), ExpressionMode::NoAwait, FunctionMode::Function)))
				}
				=> {
					this.throw()
				}
			}
		} # }}}
		reqExportIdentifier(value: Event): Event ~ SyntaxError { # {{{
			let identifier = null

			if this.testNS(Token::DOT) {
				do {
					this.commit()

					if this.testNS(Token::ASTERISK) {
						return this.yep(AST.ExportWildcardSpecifier(value, this.yes()))
					}
					else {
						identifier = this.reqIdentifier()

						value = this.yep(AST.MemberExpression([], value, identifier))
					}
				}
				while this.testNS(Token::DOT)
			}

			if this.test(Token::EQUALS_RIGHT_ANGLE) {
				this.commit()

				return this.yep(AST.ExportNamedSpecifier(value, this.reqIdentifier()))
			}
			else if this.test(Token::FOR) {
				this.commit()

				if this.test(Token::ASTERISK) {
					return this.yep(AST.ExportWildcardSpecifier(value, this.yes()))
				}
				else if this.test(Token::LEFT_CURLY) {
					const members = []

					this.commit().NL_0M()

					until this.test(Token::RIGHT_CURLY) {
						identifier = this.reqIdentifier()

						if this.test(Token::EQUALS_RIGHT_ANGLE) {
							this.commit()

							members.push(AST.ExportNamedSpecifier(identifier, this.reqIdentifier()))
						}
						else {
							members.push(AST.ExportNamedSpecifier(identifier, identifier))
						}

						if this.test(Token::COMMA) {
							this.commit()
						}

						this.reqNL_1M()
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					return this.yep(AST.ExportPropertiesSpecifier(value, members, this.yes()))
				}
				else {
					const members = []

					identifier = this.reqIdentifier()

					if this.test(Token::EQUALS_RIGHT_ANGLE) {
						this.commit()

						members.push(AST.ExportNamedSpecifier(identifier, this.reqIdentifier()))
					}
					else {
						members.push(AST.ExportNamedSpecifier(identifier, identifier))
					}

					while this.test(Token::COMMA) {
						this.commit()

						identifier = this.reqIdentifier()

						if this.test(Token::EQUALS_RIGHT_ANGLE) {
							this.commit()

							members.push(AST.ExportNamedSpecifier(identifier, this.reqIdentifier()))
						}
						else {
							members.push(AST.ExportNamedSpecifier(identifier, identifier))
						}
					}

					return this.yep(AST.ExportPropertiesSpecifier(value, members, this.yep()))
				}
			}
			else {
				return this.yep(AST.ExportNamedSpecifier(value, identifier ?? value))
			}
		} # }}}
		reqExportStatement(first: Event): Event ~ SyntaxError { # {{{
			const attributes = []
			const declarations = []

			let last
			if this.match(Token::ASTERISK, Token::LEFT_CURLY) == Token::ASTERISK {
				const first = this.yes()

				if this.test(Token::BUT) {
					this.commit()

					const exclusions = []

					if this.test(Token::LEFT_CURLY) {
						this.commit().NL_0M()

						until this.test(Token::RIGHT_CURLY) {
							exclusions.push(this.reqIdentifier())

							this.reqNL_1M()
						}

						unless this.test(Token::RIGHT_CURLY) {
							this.throw('}')
						}

						last = this.yes()
					}
					else {
						exclusions.push(this.reqIdentifier())

						while this.test(Token::COMMA) {
							this.commit()

							exclusions.push(this.reqIdentifier())
						}

						last = exclusions[exclusions.length - 1]
					}

					declarations.push(this.yep(AST.ExportExclusionSpecifier(exclusions, first, last)))
				}
				else {
					last = this.yep()

					declarations.push(this.yep(AST.ExportExclusionSpecifier([], first, last)))
				}
			}
			else if @token == Token::LEFT_CURLY {
				this.commit().NL_0M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqExportDeclarator()

					if attrs.length > 0 {
						if declarator.value.kind != NodeKind::ExportDeclarationSpecifier {
							this.throw()
						}

						declarator.value.declaration.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.declaration.start = attrs[0].start

						attrs = []
					}

					declarations.push(declarator)

					this.reqNL_1M()
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(this.reqExportDeclarator())

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqExportDeclarator())
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.ExportDeclaration(attributes, declarations, first, last))
		} # }}}
		reqExpression(eMode: ExpressionMode?, fMode: FunctionMode, terminator: MacroTerminator = null): Event ~ SyntaxError { # {{{
			if eMode == null {
				if @mode ~~ ParserMode::MacroExpression &&
					@scanner.test(Token::IDENTIFIER) &&
					@scanner.value() == 'macro'
				{
					return this.reqMacroExpression(this.yes(), terminator)
				}
				else {
					eMode = ExpressionMode::Default
				}
			}

			return this.reqOperation(eMode, fMode)
		} # }}}
		reqExpression0CNList(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			this.NL_0M()

			if this.test(Token::RIGHT_ROUND) {
				return this.yep([])
			}
			else {
				const expressions = []

				while true {
					const expression = this.reqExpression(null, fMode, MacroTerminator::List)

					if expression.value.kind == NodeKind::Identifier {
						if this.test(Token::COLON) {
							this.commit()

							const value = this.reqExpression(null, fMode, MacroTerminator::List)

							expressions.push(this.yep(AST.NamedArgument(expression, value)))
						}
						else {
							expressions.push(expression)
						}
					}
					else {
						expressions.push(expression)
					}

					if this.match(Token::COMMA, Token::NEWLINE) == Token::COMMA || @token == Token::NEWLINE {
						this.commit().NL_0M()
					}
					else {
						break
					}

					if this.test(Token::RIGHT_ROUND) {
						break
					}
				}

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				return this.yep(expressions)
			}
		} # }}}
		reqExpressionStatement(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const expression = this.reqExpression(ExpressionMode::Default, fMode)

			if this.match(Token::FOR, Token::IF, Token::UNLESS) == Token::FOR {
				const statement = this.reqForExpression(this.yes(), fMode)

				statement.value.body = expression.value

				this.relocate(statement, expression, null)

				return statement
			}
			else if @token == Token::IF {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.IfStatement(condition, expression, null, expression, condition))
			}
			else if @token == Token::UNLESS {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.UnlessStatement(condition, expression, expression, condition))
			}
			else {
				return this.yep(AST.ExpressionStatement(expression))
			}
		} # }}}
		reqExternClassDeclaration(first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			const name = this.reqIdentifier()

			let generic
			if this.test(Token::LEFT_ANGLE) {
				generic = this.reqTypeGeneric(this.yes())
			}

			let extends
			if this.test(Token::EXTENDS) {
				this.commit()

				extends = this.reqIdentifier()
			}

			if this.test(Token::LEFT_CURLY) {
				this.commit().NL_0M()

				const attributes = []
				const members = []

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.reqExternClassMemberList(members)
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				return this.yep(AST.ClassDeclaration(attributes, name, null, extends, modifiers, members, first, this.yes()))
			}
			else {
				return this.yep(AST.ClassDeclaration([], name, null, extends, modifiers, [], first, extends ?? generic ?? name))
			}
		} # }}}
		reqExternClassField(attributes, modifiers, name: Event, type: Event?, first: Event): Event ~ SyntaxError { # {{{
			this.reqNL_1M()

			return this.yep(AST.FieldDeclaration(attributes, modifiers, name, type, null, first, type ?? name))
		} # }}}
		reqExternClassMember(attributes, modifiers, first: Event?): Event ~ SyntaxError { # {{{
			const name = this.reqIdentifier()

			if this.match(Token::COLON, Token::LEFT_CURLY, Token::LEFT_ROUND) == Token::COLON {
				this.commit()

				const type = this.reqTypeVar()

				if this.test(Token::LEFT_CURLY) {
					this.throw()
				}
				else {
					return this.reqExternClassField(attributes, modifiers, name, type, first ?? name)
				}
			}
			else if @token == Token::LEFT_CURLY {
				this.throw()
			}
			else if @token == Token::LEFT_ROUND {
				return this.reqExternClassMethod(attributes, modifiers, name, this.yes(), first ?? name)
			}
			else {
				return this.reqExternClassField(attributes, modifiers, name, null, first ?? name)
			}
		} # }}}
		reqExternClassMemberList(members): Void ~ SyntaxError { # {{{
			let first = null

			const attributes = this.stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			const modifiers = this.reqAccessModifiers([])

			if this.test(Token::ABSTRACT) {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Abstract, this.yes())))

				first = modifiers[0]

				if this.test(Token::LEFT_CURLY) {
					this.commit().NL_0M()

					first = null

					let attrs
					while this.until(Token::RIGHT_CURLY) {
						attrs = this.stackOuterAttributes([])

						if attrs.length != 0 {
							first = attrs[0]
							attrs.unshift(...attributes)
						}
						else {
							attrs = attributes
						}

						members.push(this.reqClassMember(
							attrs
							modifiers
							ClassBits::Method + ClassBits::NoBody
							first
						))
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					this.commit().reqNL_1M()
				}
				else {
					members.push(this.reqClassMember(
						attributes
						modifiers
						ClassBits::Method + ClassBits::NoBody
						first
					))
				}
			}
			else {
				if this.test(Token::STATIC) {
					modifiers.push(this.yep(AST.Modifier(ModifierKind::Static, this.yes())))
				}
				if first == null && modifiers.length != 0 {
					first = modifiers[0]
				}

				if modifiers.length != 0 && this.test(Token::LEFT_CURLY) {
					this.commit().NL_0M()

					first = null

					let attrs
					while this.until(Token::RIGHT_CURLY) {
						attrs = this.stackOuterAttributes([])

						if attrs.length != 0 {
							first = attrs[0]
							attrs.unshift(...attributes)
						}
						else {
							attrs = attributes
						}

						members.push(this.reqExternClassMember(attrs, modifiers, first))
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					this.commit().reqNL_1M()
				}
				else {
					members.push(this.reqExternClassMember(attributes, modifiers, first))
				}
			}
		} # }}}
		reqExternClassMethod(attributes, modifiers, name: Event, round: Event, first): Event ~ SyntaxError { # {{{
			const parameters = this.reqClassMethodParameterList(round)
			const type = this.tryMethodReturns(false)

			this.reqNL_1M()

			return this.yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, null, null, first, type ?? parameters))
		} # }}}
		reqExternDeclarator(mode: ExternMode): Event ~ SyntaxError { # {{{
			const token = this.matchM(M.EXTERN_STATEMENT)
			switch token {
				Token::ABSTRACT => {
					const abstract = this.yep(AST.Modifier(ModifierKind::Abstract, this.yes()))

					if this.test(Token::CLASS) {
						this.commit()

						return this.reqExternClassDeclaration(abstract, [abstract])
					}
					else {
						this.throw('class')
					}
				}
				Token::ASYNC => {
					const first = this.reqIdentifier()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, first))]

					if this.test(Token::FUNC) {
						this.commit()

						return this.reqExternFunctionDeclaration(modifiers, first)
					}
					else {
						const fn = this.tryExternFunctionDeclaration(modifiers, first)
						if fn.ok {
							return fn
						}
						else {
							return this.reqExternVariableDeclarator(first)
						}
					}
				}
				Token::CLASS => {
					return this.reqExternClassDeclaration(this.yes(), [])
				}
				Token::FINAL => {
					const first = this.yes()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Immutable, first))]

					if this.test(Token::CLASS) {
						this.commit()

						return this.reqExternClassDeclaration(first, modifiers)
					}
					else if this.test(Token::ABSTRACT) {
						modifiers.push(this.yep(AST.Modifier(ModifierKind::Abstract, this.yes())))

						if this.test(Token::CLASS) {
							this.commit()

							return this.reqExternClassDeclaration(first, modifiers)
						}
						else {
							this.throw('class')
						}
					}
					else {
						this.throw('class')
					}
				}
				Token::FUNC => {
					const first = this.yes()
					return this.reqExternFunctionDeclaration([], first)
				}
				Token::IDENTIFIER when mode !~ ExternMode::Fallthrough || mode ~~ ExternMode::Namespace => {
					return this.reqExternVariableDeclarator(this.reqIdentifier())
				}
				Token::NAMESPACE => {
					return this.reqExternNamespaceDeclaration(mode, this.yes(), [])
				}
				Token::SEALED => {
					const sealed = this.yep(AST.Modifier(ModifierKind::Sealed, this.yes()))

					if this.matchM(M.EXTERN_STATEMENT) == Token::ABSTRACT {
						const abstract = this.yep(AST.Modifier(ModifierKind::Abstract, this.yes()))

						if this.test(Token::CLASS) {
							this.commit()

							return this.reqExternClassDeclaration(sealed, [sealed, abstract])
						}
						else {
							this.throw('class')
						}
					}
					else if @token == Token::CLASS {
						this.commit()

						return this.reqExternClassDeclaration(sealed, [sealed])
					}
					else if @token == Token::IDENTIFIER {
						const name = this.reqIdentifier()
						const modifiers = [sealed.value]

						if this.test(Token::COLON) {
							this.commit()

							const type = this.reqTypeVar()

							return this.yep(AST.VariableDeclarator(modifiers, name, type, sealed, type))
						}
						else {
							return this.yep(AST.VariableDeclarator(modifiers, name, null, sealed, name))
						}
					}
					else if @token == Token::NAMESPACE {
						this.commit()

						return this.reqExternNamespaceDeclaration(mode, sealed, [sealed])
					}
					else {
						this.throw(['class', 'namespace'])
					}
				}
				Token::SYSTEMIC => {
					const systemic = this.yep(AST.Modifier(ModifierKind::Systemic, this.yes()))

					if this.matchM(M.EXTERN_STATEMENT) == Token::CLASS {
						this.commit()

						return this.reqExternClassDeclaration(systemic, [systemic])
					}
					else if @token == Token::IDENTIFIER {
						const name = this.reqIdentifier()
						const modifiers = [systemic.value]

						if this.test(Token::COLON) {
							this.commit()

							const type = this.reqTypeVar()

							return this.yep(AST.VariableDeclarator(modifiers, name, type, systemic, type))
						}
						else {
							return this.yep(AST.VariableDeclarator(modifiers, name, null, systemic, name))
						}
					}
					else if @token == Token::NAMESPACE {
						this.commit()

						return this.reqExternNamespaceDeclaration(mode, systemic, [systemic])
					}
					else {
						this.throw(['class', 'namespace'])
					}
				}
				Token::VAR when mode ~~ ExternMode::Namespace => {
					const first = this.yes()
					const name = this.reqIdentifier()

					if this.test(Token::COLON) {
						this.commit()

						const type = this.reqTypeVar()

						return this.yep(AST.VariableDeclarator([], name, type, first, type))
					}
					else {
						return this.yep(AST.VariableDeclarator([], name, null, first, name))
					}
				}
				=> {
					this.throw()
				}
			}
		} # }}}
		reqExternFunctionDeclaration(modifiers, first: Event): Event ~ SyntaxError { # {{{
			const name = this.reqIdentifier()

			if this.test(Token::LEFT_ROUND) {
				const parameters = this.reqFunctionParameterList(FunctionMode::Function)
				const type = this.tryFunctionReturns(false)
				const throws = this.tryFunctionThrows()

				return this.yep(AST.FunctionDeclaration(name, parameters, modifiers, type, throws, null, first, throws ?? type ?? parameters))
			}
			else {
				const position = this.yep()
				const type = this.tryFunctionReturns(false)
				const throws = this.tryFunctionThrows()

				return this.yep(AST.FunctionDeclaration(name, null, modifiers, type, throws, null, first, throws ?? type ?? name))
			}
		} # }}}
		reqExternNamespaceDeclaration(mode: ExternMode, first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			const name = this.reqIdentifier()

			if this.test(Token::LEFT_CURLY) {
				this.commit().NL_0M()

				const attributes = []
				const statements = []

				let attrs = []
				let statement

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					statement = this.reqExternDeclarator(mode + ExternMode::Namespace)

					this.reqNL_1M()

					if attrs.length > 0 {
						statement.value.attributes.unshift(...[attr.value for const attr in attrs])
						statement.value.start = statement.value.attributes[0].start

						attrs = []
					}

					statements.push(statement)
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				return this.yep(AST.NamespaceDeclaration(attributes, modifiers, name, statements, first, this.yes()))
			}
			else {
				return this.yep(AST.NamespaceDeclaration([], modifiers, name, [], first, name))
			}
		} # }}}
		reqExternOrImportStatement(first: Event): Event ~ SyntaxError { # {{{
			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().reqNL_1M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqImportDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					if this.test(Token::NEWLINE) {
						this.commit().NL_0M()
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(last = this.reqImportDeclarator())
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.ExternOrImportDeclaration(attributes, declarations, first, last))
		} # }}}
		reqExternOrRequireStatement(first: Event): Event ~ SyntaxError { # {{{
			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().NL_0M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqExternDeclarator(ExternMode::Default)

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					this.reqNL_1M()
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(this.reqExternDeclarator(ExternMode::Default))

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqExternDeclarator(ExternMode::Default))
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.ExternOrRequireDeclaration(attributes, declarations, first, last))
		} # }}}
		reqExternStatement(first: Event): Event ~ SyntaxError { # {{{
			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().NL_0M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqExternDeclarator(ExternMode::Default)

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					this.reqNL_1M()
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(this.reqExternDeclarator(ExternMode::Default))

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqExternDeclarator(ExternMode::Default))
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.ExternDeclaration(attributes, declarations, first, last))
		} # }}}
		reqExternVariableDeclarator(name: Event): Event ~ SyntaxError { # {{{
			if this.match(Token::COLON, Token::LEFT_ROUND) == Token::COLON {
				this.commit()

				const type = this.reqTypeVar()

				return this.yep(AST.VariableDeclarator([], name, type, name, type))
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.reqFunctionParameterList(FunctionMode::Function)
				const type = this.tryFunctionReturns(false)

				return this.yep(AST.FunctionDeclaration(name, parameters, [], type, null, null, name, type ?? parameters))
			}
			else {
				return this.yep(AST.VariableDeclarator([], name, null, name, name))
			}
		} # }}}
		reqFallthroughStatement(first: Event): Event { # {{{
			return this.yep(AST.FallthroughStatement(first))
		} # }}}
		reqForExpression(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const modifiers = []

			const mark = @mark()

			if @test(Token::VAR) {
				const mark2 = @mark()
				const first = @yes()

				let modifier
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
					this.commit()

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


			let identifier1 = NO
			let type1 = NO
			let identifier2 = NO
			let destructuring = NO

			if this.test(Token::UNDERSCORE) {
				this.commit()
			}
			else if !(destructuring = this.tryDestructuring(fMode)).ok {
				identifier1 = this.reqIdentifier()

				if this.test(Token::COLON) {
					this.commit()

					type1 = this.reqTypeVar()
				}
			}

			if this.test(Token::COMMA) {
				this.commit()

				identifier2 = this.reqIdentifier()
			}

			this.NL_0M()

			if destructuring.ok {
				if this.match(Token::IN, Token::OF) == Token::IN {
					this.commit()

					return this.altForExpressionIn(modifiers, destructuring, type1, identifier2, this.reqExpression(ExpressionMode::Default, fMode), first, fMode)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(modifiers, destructuring, type1, identifier2, first, fMode)
				}
				else {
					this.throw(['in', 'of'])
				}
			}
			else if identifier2.ok {
				if this.match(Token::IN, Token::OF) == Token::IN {
					this.commit()

					return this.altForExpressionInRange(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					this.throw(['in', 'of'])
				}
			}
			else {
				if this.match(Token::FROM, Token::IN, Token::OF) == Token::FROM {
					this.commit()

					return this.altForExpressionFrom(modifiers, identifier1, first, fMode)
				}
				else if @token == Token::IN {
					this.commit()

					return this.altForExpressionInRange(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(modifiers, identifier1, type1, identifier2, first, fMode)
				}
				else {
					this.throw(['from', 'in', 'of'])
				}
			}
		} # }}}
		reqForStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const statement = this.reqForExpression(first, fMode)

			this.NL_0M()

			const block = this.reqBlock(NO, fMode)

			statement.value.body = block.value
			this.relocate(statement, null, block)

			return statement
		} # }}}
		reqFunctionBody(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			this.NL_0M()

			if this.match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				return this.reqBlock(this.yes(), fMode)
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				this.commit().NL_0M()

				const expression = this.reqExpression(ExpressionMode::Default, fMode)

				if this.match(Token::IF, Token::UNLESS) == Token::IF {
					this.commit()

					const condition = this.reqExpression(ExpressionMode::Default, fMode)

					if this.match(Token::ELSE, Token::NEWLINE) == Token::ELSE {
						this.commit()

						const whenFalse = this.reqExpression(ExpressionMode::Default, fMode)

						return this.yep(AST.ReturnStatement(this.yep(AST.IfExpression(condition, expression, whenFalse, expression, whenFalse)), expression, whenFalse))
					}
					else if @token == Token::NEWLINE || @token == Token::EOF {
						return this.yep(AST.IfStatement(condition, this.yep(AST.ReturnStatement(expression, expression, expression)), null, expression, condition))
					}
					else {
						this.throw()
					}
				}
				else if @token == Token::UNLESS {
					this.commit()

					const condition = this.reqExpression(ExpressionMode::Default, fMode)

					return this.yep(AST.UnlessStatement(condition, this.yep(AST.ReturnStatement(expression, expression, expression)), expression, condition))
				}
				else {
					return expression
				}
			}
			else {
				this.throw(['{', '=>'])
			}
		} # }}}
		reqFunctionParameterList(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless this.test(Token::LEFT_ROUND) {
				this.throw('(')
			}

			const first = this.yes()

			const parameters = []

			unless this.test(Token::RIGHT_ROUND) {
				while this.reqParameter(parameters, DestructuringMode::Parameter, fMode) {
				}

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}
			}

			return this.yep(parameters, first, this.yes())
		} # }}}
		reqFunctionStatement(first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			const name = this.reqIdentifier()
			const parameters = this.reqFunctionParameterList(FunctionMode::Function)
			const type = this.tryFunctionReturns()
			const throws = this.tryFunctionThrows()
			const body = this.reqFunctionBody(FunctionMode::Function)

			return this.yep(AST.FunctionDeclaration(name, parameters, modifiers, type, throws, body, first, body))
		} # }}}
		reqIdentifier(): Event ~ SyntaxError { # {{{
			if @scanner.test(Token::IDENTIFIER) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				this.throw('Identifier')
			}
		} # }}}
		reqIfStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let condition

			if @test(Token::VAR) {
				const mark = @mark()
				const first = @yes()

				const modifiers = []
				if @test(Token::MUT) {
					modifiers.push(AST.Modifier(ModifierKind::Mutable, @yes()))
				}

				if this.test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					const variable = this.reqTypedVariable(fMode)

					if this.test(Token::COMMA) {
						const variables = [variable]

						do {
							this.commit()

							variables.push(this.reqTypedVariable(fMode))
						}
						while this.test(Token::COMMA)

						unless this.test(Token::EQUALS) {
							this.throw('=')
						}

						this.commit()

						unless this.test(Token::AWAIT) {
							this.throw('await')
						}

						this.commit()

						const operand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)

						condition = this.yep(AST.VariableDeclaration(modifiers, variables, operand, first, operand))
					}
					else {
						unless this.test(Token::EQUALS) {
							this.throw('=')
						}

						this.commit()

						const expression = this.reqExpression(ExpressionMode::Default, fMode)

						condition = this.yep(AST.VariableDeclaration(modifiers, [variable], expression, first, expression))
					}
				}
				else {
					this.rollback(mark)

					condition = this.reqExpression(ExpressionMode::NoAnonymousFunction, fMode)
				}
			}
			else {
				this.NL_0M()

				condition = this.reqExpression(ExpressionMode::NoAnonymousFunction, fMode)
			}

			this.NL_0M()

			const whenTrue = this.reqBlock(NO, fMode)

			if this.test(Token::NEWLINE) {
				const mark = this.mark()

				this.commit().NL_0M()

				if this.match(Token::ELSE_IF, Token::ELSE) == Token::ELSE_IF {
					const position = this.yes()

					position.start.column += 5

					const whenFalse = this.reqIfStatement(position, fMode)

					return this.yep(AST.IfStatement(condition, whenTrue, whenFalse, first, whenFalse))
				}
				else if @token == Token::ELSE {
					this.commit().NL_0M()

					const whenFalse = this.reqBlock(NO, fMode)

					return this.yep(AST.IfStatement(condition, whenTrue, whenFalse, first, whenFalse))
				}
				else {
					this.rollback(mark)

					return this.yep(AST.IfStatement(condition, whenTrue, null, first, whenTrue))
				}
			}
			else {
				return this.yep(AST.IfStatement(condition, whenTrue, null, first, whenTrue))
			}
		} # }}}
		reqImplementMemberList(members): Void ~ SyntaxError { # {{{
			let first = null

			const attributes = @stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			const accessMark = @mark()
			const accessModifier = @tryAccessModifier()

			if accessModifier.ok && @test(Token::LEFT_CURLY) {
				return @reqClassMemberBlock(
					attributes
					[accessModifier]
					ClassBits::Variable + ClassBits::DynamicVariable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method
					members
				)
			}

			if @test(Token::OVERRIDE, Token::OVERWRITE) {
				const mark = @mark()
				const modifier = @yep(AST.Modifier(@token == Token::OVERRIDE ? ModifierKind::Override : ModifierKind::Overwrite, @yes()))
				const modifiers = [modifier]
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

				const member = @tryClassMember(
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

			const staticMark = @mark()
			let staticModifier = NO

			if @test(Token::STATIC) {
				staticModifier = @yep(AST.Modifier(ModifierKind::Static, @yes()))

				if @test(Token::LEFT_CURLY) {
					const modifiers = [staticModifier]
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

			const finalMark = @mark()
			let finalModifier = NO

			if @test(Token::FINAL) {
				finalModifier = @yep(AST.Modifier(ModifierKind::Immutable, @yes()))

				if @test(Token::LEFT_CURLY) {
					const modifiers = [finalModifier]
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
					const mark = @mark()
					const modifier = @yep(AST.Modifier(@token == Token::OVERRIDE ? ModifierKind::Override : ModifierKind::Overwrite, @yes()))

					if @test(Token::LEFT_CURLY) {
						const modifiers = [finalModifier, modifier]
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
				const lateMark = @mark()
				const lateModifier = @yep(AST.Modifier(ModifierKind::LateInit, @yes()))

				const modifiers = [lateModifier]
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
						finalModifier.ok ? ClassBits::Variable : ClassBits::Variable + ClassBits::FinalVariable + ClassBits::DynamicVariable
						members
					)
				}

				const member = @tryClassMember(
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
				const member = @tryClassMember(attributes, [accessModifier], staticModifier, staticMark, finalModifier, finalMark, first ?? accessModifier)

				if member.ok {
					members.push(member)

					return
				}

				@rollback(accessMark)
			}

			const member = @tryClassMember(attributes, [], staticModifier, staticMark, finalModifier, finalMark, first)

			unless member.ok {
				@throw(['Identifier', 'String', 'Template'])
			}

			members.push(member)
		} # }}}
		reqImplementStatement(first: Event): Event ~ SyntaxError { # {{{
			const variable = this.reqIdentifier()

			if this.test(Token::LEFT_ANGLE) {
				this.reqTypeGeneric(this.yes())
			}

			unless this.test(Token::LEFT_CURLY) {
				this.throw('{')
			}

			this.commit().NL_0M()

			const attributes = []
			const members = []

			until this.test(Token::RIGHT_CURLY) {
				if this.stackInnerAttributes(attributes) {
					continue
				}

				this.reqImplementMemberList(members)
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yep(AST.ImplementDeclaration(attributes, variable, members, first, this.yes()))
		} # }}}
		reqImportDeclarator(): Event ~ SyntaxError { # {{{
			const source = this.reqString()
			const modifiers = []
			let arguments = null
			let last = source

			if this.test(Token::LEFT_ROUND) {
				this.commit()

				arguments = []

				if this.test(Token::DOT_DOT_DOT) {
					modifiers.push(AST.Modifier(ModifierKind::Autofill, this.yes()))

					if this.test(Token::COMMA) {
						this.commit()
					}
				}

				while this.until(Token::RIGHT_ROUND) {
					let name = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)
					const modifiers = []

					if name.value.kind == NodeKind::Identifier {
						if name.value.name == 'require' && !this.test(Token::COLON, Token::COMMA, Token::RIGHT_ROUND) {
							const first = name

							modifiers.push(AST.Modifier(ModifierKind::Required, name))

							name = this.reqIdentifier()

							if this.test(Token::COLON) {
								this.commit()

								const value = this.reqIdentifier()

								arguments.push(AST.ImportArgument(modifiers, name, value, first, value))
							}
							else {
								arguments.push(AST.ImportArgument(modifiers, null, name, first, name))
							}
						}
						else {
							if this.test(Token::COLON) {
								this.commit()

								const value = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)

								arguments.push(AST.ImportArgument(modifiers, name, value, name, value))
							}
							else {
								arguments.push(AST.ImportArgument(modifiers, null, name, name, name))
							}
						}
					}
					else {
						arguments.push(AST.ImportArgument(modifiers, null, name, name, name))
					}

					if this.test(Token::COMMA) {
						this.commit()
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				this.commit()
			}

			const attributes = []
			const specifiers = []

			if this.match(Token::BUT, Token::EQUALS_RIGHT_ANGLE, Token::FOR, Token::LEFT_CURLY) == Token::BUT {
				const first = this.yes()

				const exclusions = []

				if this.test(Token::LEFT_CURLY) {
					this.commit().NL_0M()

					until this.test(Token::RIGHT_CURLY) {
						exclusions.push(this.reqIdentifier())

						this.reqNL_1M()
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					last = this.yes()
				}
				else {
					exclusions.push(this.reqIdentifier())

					while this.test(Token::COMMA) {
						this.commit()

						exclusions.push(this.reqIdentifier())
					}

					last = exclusions[exclusions.length - 1]
				}

				specifiers.push(this.yep(AST.ImportExclusionSpecifier(exclusions, first, last)))
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				this.commit()

				last = this.reqIdentifier()

				if this.test(Token::LEFT_CURLY) {
					specifiers.push(this.yep(AST.ImportNamespaceSpecifier(last, this.reqImportSpecifiers(attributes, []), last, this.yes())))
				}
				else {
					specifiers.push(this.yep(AST.ImportNamespaceSpecifier(last, null, last, last)))
				}
			}
			else if @token == Token::FOR {
				this.commit()

				let imported, local
				while this.until(Token::NEWLINE) {
					imported = this.reqExternDeclarator(ExternMode::Default)

					if this.test(Token::EQUALS_RIGHT_ANGLE) {
						this.commit()

						local = this.reqIdentifier()

						specifiers.push(this.yep(AST.ImportSpecifier(imported, local, imported, local)))
					}
					else {
						specifiers.push(this.yep(AST.ImportSpecifier(imported, this.yep(imported.value.name), imported, imported)))
					}

					if this.test(Token::COMMA) {
						this.commit()
					}
					else {
						break
					}
				}
			}
			else if @token == Token::LEFT_CURLY {
				this.reqImportSpecifiers(attributes, specifiers)

				last = this.yes()
			}

			return this.yep(AST.ImportDeclarator(attributes, modifiers, source, specifiers, arguments, source, last))
		} # }}}
		reqImportSpecifiers(attributes, specifiers): Event ~ SyntaxError { # {{{
			this.commit().reqNL_1M()

			let first, imported, local
			let attrs = []
			let specifier

			until this.test(Token::RIGHT_CURLY) {
				if this.stackInnerAttributes(attributes) {
					continue
				}

				this.stackOuterAttributes(attrs)

				if this.match(Token::ASTERISK) == Token::ASTERISK {
					first = this.yes()

					unless this.test(Token::EQUALS_RIGHT_ANGLE) {
						this.throw('=>')
					}

					this.commit()

					local = this.reqIdentifier()

					specifier = this.yep(AST.ImportNamespaceSpecifier(local, null, first, local))
				}
				else {
					imported = this.reqExternDeclarator(ExternMode::Default)

					if this.test(Token::EQUALS_RIGHT_ANGLE) {
						this.commit()

						local = this.reqIdentifier()

						specifier = this.yep(AST.ImportSpecifier(imported, local, imported, local))
					}
					else {
						specifier = this.yep(AST.ImportSpecifier(imported, this.yep(imported.value.name), imported, imported))
					}
				}

				if attrs.length > 0 {
					specifier.value.attributes.unshift(...[attr.value for const attr in attrs])
					specifier.value.start = specifier.value.attributes[0].start

					attrs = []
				}

				specifiers.push(specifier)

				if this.test(Token::NEWLINE) {
					this.commit().NL_0M()
				}
				else {
					break
				}
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return specifiers
		} # }}}
		reqImportStatement(first: Event): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().reqNL_1M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqImportDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					if this.test(Token::NEWLINE) {
						this.commit().NL_0M()
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(last = this.reqImportDeclarator())
			}

			return this.yep(AST.ImportDeclaration(attributes, declarations, first, last))
		} # }}}
		reqIncludeDeclarator(): Event ~ SyntaxError { # {{{
			unless this.test(Token::STRING) {
				this.throw('String')
			}

			const file = this.yes(this.value())

			return this.yep(AST.IncludeDeclarator(file))
		} # }}}
		reqIncludeStatement(first: Event): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().reqNL_1M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqIncludeDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					if this.test(Token::NEWLINE) {
						this.commit().NL_0M()
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(last = this.reqIncludeDeclarator())
			}

			return this.yep(AST.IncludeDeclaration(attributes, declarations, first, last))
		} # }}}
		reqIncludeAgainStatement(first: Event): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().reqNL_1M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqIncludeDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					if this.test(Token::NEWLINE) {
						this.commit().NL_0M()
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(last = this.reqIncludeDeclarator())
			}

			return this.yep(AST.IncludeAgainDeclaration(attributes, declarations, first, last))
		} # }}}
		reqJunctionExpression(operator, eMode, fMode, values, type) ~ SyntaxError { # {{{
			this.NL_0M()

			const operands = [values.pop()]

			if type {
				operands.push(this.reqTypeEntity(NO).value)
			}
			else {
				operands.push(this.reqBinaryOperand(eMode, fMode).value)
			}

			const kind = operator.value.kind

			while true {
				const mark = this.mark()
				const operator = this.tryJunctionOperator()

				if operator.ok && operator.value.kind == kind {
					this.NL_0M()

					if type {
						operands.push(this.reqTypeEntity(NO).value)
					}
					else {
						operands.push(this.reqBinaryOperand(eMode, fMode).value)
					}
				}
				else {
					this.rollback(mark)

					break
				}
			}

			return AST.JunctionExpression(operator, operands)
		} # }}}
		reqMacroElements(elements, terminator: MacroTerminator): Void ~ SyntaxError { # {{{
			const history = []

			let literal = null
			let first, last

			const addLiteral = () => {
				if literal != null {
					elements.push(this.yep(AST.MacroElementLiteral(literal, first!?, last!?)))

					literal = null
				}
			}

			const addToLiteral = () => {
				if literal == null {
					literal = @scanner.value()
					first = last = this.yep()
				}
				else {
					literal += @scanner.value()
					last = this.yep()
				}

				this.commit()
			}

			const pushToLiteral = (value, position) => {
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
				switch this.matchM(M.MACRO) {
					Token::EOF => {
						if history.length == 0 && terminator !~ MacroTerminator::NEWLINE {
							this.throw()
						}

						break
					}
					Token::HASH => {
						const first = this.yes()

						if this.testNS(Token::IDENTIFIER) {
							addLiteral()

							const identifier = @scanner.value()
							const last = this.yes()
							const mark = this.mark()

							if identifier.length == 1 && (identifier == 'a' || identifier == 'e' || identifier == 's' || identifier == 'w') && this.test(Token::LEFT_ROUND) {
								const reification = AST.MacroReification(identifier, last)

								this.commit()

								const expression = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)

								unless this.test(Token::RIGHT_ROUND) {
									this.throw(')')
								}

								elements.push(this.yep(AST.MacroElementExpression(expression, reification, first, this.yes())))
							}
							else if identifier.length == 1 && identifier == 'j' {
								const reification = AST.MacroReification(identifier, last)

								this.commit()

								unless this.test(Token::LEFT_ROUND) {
									this.throw('(')
								}

								this.commit()

								const expression = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)

								unless this.test(Token::COMMA) {
									this.throw(',')
								}

								this.commit()

								const separator = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)

								unless this.test(Token::RIGHT_ROUND) {
									this.throw(')')
								}

								const ast = AST.MacroElementExpression(expression, reification, first, this.yes())

								ast.separator = separator.value

								elements.push(this.yep(ast))
							}
							else {
								this.rollback(mark)

								const expression = this.yep(AST.Identifier(identifier, last))

								elements.push(this.yep(AST.MacroElementExpression(expression, null, first, expression)))
							}
						}
						else if this.testNS(Token::LEFT_ROUND) {
							addLiteral()

							this.commit()

							const expression = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)

							unless this.test(Token::RIGHT_ROUND) {
								this.throw(')')
							}

							elements.push(this.yep(AST.MacroElementExpression(expression, null, first, this.yes())))
						}
						else {
							pushToLiteral('#', first)
						}
					}
					Token::INVALID => {
						addToLiteral()
					}
					Token::LEFT_CURLY => {
						addToLiteral()

						history.unshift(Token::RIGHT_CURLY)
					}
					Token::LEFT_ROUND => {
						addToLiteral()

						history.unshift(Token::RIGHT_ROUND)
					}
					Token::NEWLINE => {
						if history.length == 0 && terminator ~~ MacroTerminator::NEWLINE {
							break
						}
						else {
							addLiteral()

							elements.push(this.yep(AST.MacroElementNewLine(this.yes())))

							@scanner.skip()
						}
					}
					Token::RIGHT_CURLY => {
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
					Token::RIGHT_ROUND => {
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
				this.throw()
			}

			if literal != null {
				elements.push(this.yep(AST.MacroElementLiteral(literal, first!?, last!?)))
			}
		} # }}}
		reqMacroExpression(first: Event, terminator: MacroTerminator = MacroTerminator::NEWLINE): Event ~ SyntaxError { # {{{
			const elements = []

			if this.test(Token::LEFT_CURLY) {
				if first.ok {
					this.commit()
				}
				else {
					first = this.yes()
				}

				this.reqNL_1M()

				this.reqMacroElements(elements, MacroTerminator::RIGHT_CURLY)

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				return this.yep(AST.MacroExpression(elements, first, this.yes()))
			}
			else {
				if !first.ok {
					first = this.yep()
				}

				this.reqMacroElements(elements, terminator)

				return this.yep(AST.MacroExpression(elements, first, elements[elements.length - 1]))
			}
		} # }}}
		reqMacroParameterList(): Event ~ SyntaxError { # {{{
			unless this.test(Token::LEFT_ROUND) {
				this.throw('(')
			}

			const first = this.yes()

			const parameters = []

			unless this.test(Token::RIGHT_ROUND) {
				while this.reqParameter(parameters, DestructuringMode::Parameter, FunctionMode::Macro) {
				}

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}
			}

			return this.yep(parameters, first, this.yes())
		} # }}}
		reqMacroBody(): Event ~ SyntaxError { # {{{
			if this.match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				@mode += ParserMode::MacroExpression

				const body = this.reqBlock(this.yes(), FunctionMode::Function)

				@mode -= ParserMode::MacroExpression

				return body
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				return this.reqMacroExpression(this.yes())
			}
			else {
				this.throw(['{', '=>'])
			}
		} # }}}
		reqMacroStatement(attributes = []): Event ~ SyntaxError { # {{{
			const name = this.reqIdentifier()
			const parameters = this.reqMacroParameterList()

			const body = this.reqMacroBody()

			this.reqNL_1M()

			return this.yep(AST.MacroDeclaration(attributes, name, parameters, body, name, body))
		} # }}}
		reqMacroStatement(attributes = [], name: Event, first: Event): Event ~ SyntaxError { # {{{
			const parameters = this.reqMacroParameterList()

			const body = this.reqMacroBody()

			this.reqNL_1M()

			return this.yep(AST.MacroDeclaration(attributes, name, parameters, body, first, body))
		} # }}}
		reqModule(): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const attributes = []
			const body = []

			let attrs = []
			let statement
			until @scanner.isEOF() {
				if this.stackInnerAttributes(attributes) {
					continue
				}

				this.stackOuterAttributes(attrs)

				switch this.matchM(M.MODULE_STATEMENT) {
					Token::DISCLOSE => {
						statement = this.reqDiscloseStatement(this.yes()).value
					}
					Token::EXPORT => {
						statement = this.reqExportStatement(this.yes()).value
					}
					Token::EXTERN => {
						statement = this.reqExternStatement(this.yes()).value
					}
					Token::EXTERN_IMPORT => {
						statement = this.reqExternOrImportStatement(this.yes()).value
					}
					Token::EXTERN_REQUIRE => {
						statement = this.reqExternOrRequireStatement(this.yes()).value
					}
					Token::INCLUDE => {
						statement = this.reqIncludeStatement(this.yes()).value
					}
					Token::INCLUDE_AGAIN => {
						statement = this.reqIncludeAgainStatement(this.yes()).value
					}
					Token::REQUIRE => {
						statement = this.reqRequireStatement(this.yes()).value
					}
					Token::REQUIRE_EXTERN => {
						statement = this.reqRequireOrExternStatement(this.yes()).value
					}
					Token::REQUIRE_IMPORT => {
						statement = this.reqRequireOrImportStatement(this.yes()).value
					}
					=> {
						statement = this.reqStatement(FunctionMode::Function).value
					}
				}

				if attrs.length > 0 {
					statement.attributes.unshift(...[attr.value for const attr in attrs])
					statement.start = statement.attributes[0].start

					attrs = []
				}

				body.push(statement)

				this.NL_0M()
			}

			return AST.Module(attributes, body, this)
		} # }}}
		reqNameIST(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if this.match(Token::IDENTIFIER, Token::STRING, Token::TEMPLATE_BEGIN) == Token::IDENTIFIER {
				return this.reqIdentifier()
			}
			else if @token == Token::STRING {
				return this.reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return this.reqTemplateExpression(this.yes(), fMode)
			}
			else {
				this.throw(['Identifier', 'String', 'Template'])
			}
		} # }}}
		reqNamespaceStatement(first: Event, name: Event): Event ~ SyntaxError { # {{{
			this.NL_0M()

			unless this.test(Token::LEFT_CURLY) {
				this.throw('{')
			}

			this.commit()

			this.NL_0M()

			const attributes = []
			const statements = []

			let attrs = []
			let statement

			until this.test(Token::RIGHT_CURLY) {
				if this.stackInnerAttributes(attributes) {
					continue
				}

				this.stackOuterAttributes(attrs)

				if this.matchM(M.MODULE_STATEMENT) == Token::EXPORT {
					statement = this.reqExportStatement(this.yes())
				}
				else if @token == Token::EXTERN {
					statement = this.reqExternStatement(this.yes())
				}
				else if @token == Token::INCLUDE {
					statement = this.reqIncludeStatement(this.yes())
				}
				else if @token == Token::INCLUDE_AGAIN {
					statement = this.reqIncludeAgainStatement(this.yes())
				}
				else {
					statement = this.reqStatement(FunctionMode::Function)
				}

				if attrs.length > 0 {
					statement.value.attributes.unshift(...[attr.value for const attr in attrs])
					statement.value.start = statement.value.attributes[0].start

					attrs = []
				}

				statements.push(statement)

				this.NL_0M()
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yep(AST.NamespaceDeclaration(attributes, [], name, statements, first, this.yes()))
		} # }}}
		reqNumber(): Event ~ SyntaxError { # {{{
			if (value = this.tryNumber()).ok {
				return value
			}
			else {
				this.throw('Number')
			}
		} # }}}
		reqNumeralIdentifier(): Event ~ SyntaxError { # {{{
			if this.test(Token::IDENTIFIER, Token::NUMERAL) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				this.throw('Identifier')
			}
		} # }}}
		reqNL_1M(): Void ~ SyntaxError { # {{{
			if this.test(Token::NEWLINE) {
				this.commit()

				this.skipNewLine()
			}
			else {
				this.throw('NewLine')
			}
		} # }}}
		reqNL_EOF_1M(): Void ~ SyntaxError { # {{{
			if this.match(Token::NEWLINE) == Token::NEWLINE {
				this.commit()

				this.skipNewLine()
			}
			else if @token != Token::EOF {
				this.throw(['NewLine', 'EOF'])
			}
		} # }}}
		reqObject(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const attributes = []
			const properties = []

			until this.test(Token::RIGHT_CURLY) {
				if this.stackInnerAttributes(attributes) {
					continue
				}

				properties.push(this.reqObjectItem(fMode))

				if this.match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
					this.commit().NL_0M()
				}
				else if @token == Token::NEWLINE {
					this.commit().NL_0M()

					if this.test(Token::COMMA) {
						this.commit().NL_0M()
					}
				}
				else {
					break
				}
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yep(AST.ObjectExpression(attributes, properties, first, this.yes()))
		} # }}}
		reqObjectItem(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let first

			const attributes = this.stackOuterAttributes([])
			if attributes.length > 0 {
				first = attributes[0]
			}

			if this.test(Token::ASYNC) {
				const marker = this.mark()

				const async = this.yes()

				const name = this.tryNameIST(fMode)
				if name.ok {
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, async))]
					const parameters = this.reqFunctionParameterList(fMode)
					const type = this.tryFunctionReturns()
					const throws = this.tryFunctionThrows()
					const body = this.reqFunctionBody(fMode)

					return this.yep(AST.ObjectMember(attributes, name, this.yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, parameters, body)), first ?? async ?? name, body))
				}
				else {
					this.rollback(marker)
				}
			}

			let name
			if this.match(Token::AT, Token::DOT_DOT_DOT, Token::IDENTIFIER, Token::LEFT_SQUARE, Token::STRING, Token::TEMPLATE_BEGIN) == Token::IDENTIFIER {
				name = this.reqIdentifier()
			}
			else if @token == Token::LEFT_SQUARE {
				name = this.reqComputedPropertyName(this.yes(), fMode)
			}
			else if @token == Token::STRING {
				name = this.reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				name = this.reqTemplateExpression(this.yes(), fMode)
			}
			else if fMode == FunctionMode::Method && @token == Token::AT {
				name = this.reqThisExpression(this.yes())

				return this.yep(AST.ShorthandProperty(attributes, name, first ?? name, name))
			}
			else if @token == Token::DOT_DOT_DOT {
				const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Spread, this.yes()))
				const operand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)

				return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
			}
			else {
				this.throw(['Identifier', 'String', 'Template', 'Computed Property Name'])
			}

			if this.test(Token::COLON) {
				this.commit()

				const value = this.reqExpression(null, fMode, MacroTerminator::Object)

				return this.yep(AST.ObjectMember(attributes, name, value, first ?? name, value))
			}
			else if this.test(Token::LEFT_ROUND) {
				const parameters = this.reqFunctionParameterList(fMode)
				const type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()
				const body = this.reqFunctionBody(fMode)

				return this.yep(AST.ObjectMember(attributes, name, this.yep(AST.FunctionExpression(parameters, null, type, throws, body, parameters, body)), first ?? name, body))
			}
			else {
				return this.yep(AST.ShorthandProperty(attributes, name, first ?? name, name))
			}
		} # }}}
		reqOperand(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if (value = this.tryOperand(eMode, fMode)).ok {
				return value
			}
			else {
				this.throw()
			}
		} # }}}
		reqOperation(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let mark = this.mark()

			let operand, operator

			if (operand = this.tryDestructuring(fMode)).ok {
				this.NL_0M()

				if (operator = this.tryAssignementOperator()).ok {
					const values = [operand.value, AST.BinaryExpression(operator)]

					this.NL_0M()

					values.push(this.reqBinaryOperand(eMode, fMode).value)

					return this.yep(AST.reorderExpression(values))
				}
			}

			this.rollback(mark)

			operand = this.reqBinaryOperand(eMode, fMode)

			const values = [operand.value]

			auto type = false

			while true {
				mark = this.mark()

				this.NL_0M()

				if (operator = this.tryBinaryOperator()).ok {
					values.push(AST.BinaryExpression(operator))

					this.NL_0M()

					values.push(this.reqBinaryOperand(eMode, fMode).value)
				}
				else if !type && (operator = this.tryTypeOperator()).ok {
					if mark.line != operator.start.line {
						this.rollback(mark)

						break
					}
					else {
						values.push(AST.BinaryExpression(operator), this.reqTypeEntity(NO).value)

						type = true

						continue
					}
				}
				else if this.test(Token::QUESTION) {
					values.push(AST.ConditionalExpression(this.yes()))

					values.push(this.reqExpression(ExpressionMode::Default, fMode).value)

					unless this.test(Token::COLON) {
						this.throw(':')
					}

					this.commit()

					values.push(this.reqExpression(ExpressionMode::Default, fMode).value)
				}
				else if (operator = this.tryJunctionOperator()).ok {
					values.push(this.reqJunctionExpression(operator, eMode, fMode, values, type))
				}
				else {
					this.rollback(mark)

					break
				}

				if type {
					type = false
				}
			}

			if values.length == 1 {
				return this.yep(values[0]!?)
			}
			else {
				return this.yep(AST.reorderExpression(values))
			}
		} # }}}
		reqParameter(parameters: Array<Event>, pMode: DestructuringMode, fMode: FunctionMode): Boolean ~ SyntaxError { # {{{
			const modifiers = []

			if this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY || @token == Token::LEFT_SQUARE {
				if fMode == FunctionMode::Macro {
					this.throw()
				}

				let name
				if @token == Token::LEFT_CURLY {
					name = this.reqDestructuringObject(this.yes(), pMode, fMode)
				}
				else {
					name = this.reqDestructuringArray(this.yes(), pMode, fMode)
				}

				if this.match(Token::COLON, Token::EQUALS) == Token::COLON {
					this.commit()

					const type = this.reqTypeVar()

					if this.test(Token::EQUALS) {
						this.commit()

						const defaultValue = this.reqExpression(ExpressionMode::Default, fMode)

						parameters.push(this.yep(AST.Parameter(name, type, modifiers, defaultValue, name, defaultValue)))
					}
					else {
						parameters.push(this.yep(AST.Parameter(name, type, modifiers, null, name, type)))
					}
				}
				else if @token == Token::EQUALS {
					this.commit()

					const defaultValue = this.reqExpression(ExpressionMode::Default, fMode)

					parameters.push(this.yep(AST.Parameter(name, null, modifiers, defaultValue, name, defaultValue)))
				}
				else {
					parameters.push(this.yep(AST.Parameter(name, null, modifiers, null, name, name)))
				}

				if this.test(Token::COMMA) {
					this.commit()

					return true
				}
				else {
					return false
				}
			}

			if this.test(Token::DOT_DOT_DOT) {
				const first = this.yes()

				if this.test(Token::LEFT_CURLY) {
					this.commit()

					let min, max

					if this.test(Token::COMMA) {
						this.commit()

						min = 0
						max = this.reqNumber().value.value
					}
					else {
						min = this.reqNumber().value.value

						if this.test(Token::COMMA) {
							this.commit()

							if this.test(Token::RIGHT_CURLY) {
								max = Infinity
							}
							else {
								max = this.reqNumber().value.value
							}
						}
						else {
							max = min
						}
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					modifiers.push(AST.RestModifier(min, max, first, this.yes()))
				}
				else {
					modifiers.push(AST.RestModifier(0, Infinity, first, first))
				}
			}

			if this.test(Token::AT) {
				if fMode == FunctionMode::Macro {
					const first = this.yes()

					modifiers.push(AST.Modifier(ModifierKind::AutoEvaluate, first))

					parameters.push(this.reqParameterIdendifier(modifiers, first, fMode))
				}
				else if fMode == FunctionMode::Method && pMode ~~ DestructuringMode::THIS_ALIAS {
					parameters.push(this.reqParameterThis(modifiers, this.yes(), fMode))
				}
				else {
					this.throw()
				}

				if this.test(Token::COMMA) {
					this.commit()
				}
				else {
					return false
				}
			}
			else if this.test(Token::IDENTIFIER) {
				const first = modifiers.length == 0 ? null : modifiers[0]

				parameters.push(this.reqParameterIdendifier(modifiers, first, fMode))

				if this.test(Token::COMMA) {
					this.commit()
				}
				else {
					return false
				}
			}
			else if this.test(Token::UNDERSCORE) {
				const first = this.yes()

				if this.test(Token::EXCLAMATION) {
					modifiers.push(AST.Modifier(ModifierKind::Required, this.yes()))
				}

				if this.test(Token::COLON) {
					this.commit()

					const type = this.reqTypeVar()

					parameters.push(this.yep(AST.Parameter(null, type, modifiers, null, first, type)))
				}
				else if this.test(Token::QUESTION) {
					const type = this.yep(AST.Nullable(this.yes()))

					parameters.push(this.yep(AST.Parameter(null, type, modifiers, null, first, type)))
				}
				else {
					parameters.push(this.yep(AST.Parameter(null, null, modifiers, null, first, first)))
				}

				if this.test(Token::COMMA) {
					this.commit()
				}
				else {
					return false
				}
			}
			else if modifiers.length != 0 {
				parameters.push(this.yep(AST.Parameter(null, null, modifiers, null, modifiers[0], modifiers[0])))

				if this.test(Token::COMMA) {
					this.commit()
				}
				else {
					return false
				}
			}
			else {
				this.throw()
			}

			return true
		} # }}}
		reqParameterIdendifier(modifiers, first?, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const identifier = this.reqIdentifier()

			if this.test(Token::EXCLAMATION) {
				modifiers.push(AST.Modifier(ModifierKind::Required, this.yes()))
			}

			if this.match(Token::COLON, Token::EQUALS, Token::QUESTION) == Token::COLON {
				this.commit()

				const type = this.reqTypeVar()

				if this.test(Token::EQUALS) {
					this.commit()

					const defaultValue = this.reqExpression(ExpressionMode::Default, fMode)

					return this.yep(AST.Parameter(identifier, type, modifiers, defaultValue, first ?? identifier, defaultValue))
				}
				else {
					return this.yep(AST.Parameter(identifier, type, modifiers, null, first ?? identifier, type))
				}
			}
			else if @token == Token::EQUALS {
				this.commit()

				const defaultValue = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.Parameter(identifier, null, modifiers, defaultValue, first ?? identifier, defaultValue))
			}
			else if @token == Token::QUESTION {
				const type = this.yep(AST.Nullable(this.yes()))

				if this.test(Token::EQUALS) {
					this.commit()

					const defaultValue = this.reqExpression(ExpressionMode::Default, fMode)

					return this.yep(AST.Parameter(identifier, type, modifiers, defaultValue, first ?? identifier, defaultValue))
				}
				else {
					return this.yep(AST.Parameter(identifier, type, modifiers, null, first ?? identifier, type))
				}
			}
			else {
				return this.yep(AST.Parameter(identifier, null, modifiers, null, first ?? identifier, identifier))
			}
		} # }}}
		reqParameterThis(modifiers, first, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const name = this.reqThisExpression(first)

			if this.test(Token::EQUALS) {
				this.commit()

				const defaultValue = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.Parameter(name, null, modifiers, defaultValue, first ?? name, defaultValue))
			}
			else {
				return this.yep(AST.Parameter(name, null, modifiers, null, first ?? name, name))
			}
		} # }}}
		reqParenthesis(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if this.test(Token::NEWLINE) {
				this.commit().NL_0M()

				const expression = this.reqExpression(null, fMode, MacroTerminator::Parenthesis)

				this.NL_0M()

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				this.relocate(expression, first, this.yes())

				return expression
			}
			else {
				const expressions = [this.reqExpression(null, fMode, MacroTerminator::List)]

				while this.test(Token::COMMA) {
					this.commit()

					expressions.push(this.reqExpression(null, fMode, MacroTerminator::List))
				}

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				if expressions.length == 1 {
					this.relocate(expressions[0], first, this.yes())

					return expressions[0]
				}
				else {
					return this.yep(AST.SequenceExpression(expressions, first, this.yes()))
				}
			}
		} # }}}
		reqPostfixedOperand(operand: Event?, eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			operand = this.reqUnaryOperand(operand, eMode, fMode)

			let operator
			switch this.matchM(M.POSTFIX_OPERATOR) {
				Token::EXCLAMATION_EXCLAMATION => {
					operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::ForcedTypeCasting, this.yes()))
				}
				Token::EXCLAMATION_QUESTION => {
					operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::NullableTypeCasting, this.yes()))
				}
				Token::MINUS_MINUS => {
					operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::DecrementPostfix, this.yes()))
				}
				Token::PLUS_PLUS => {
					operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::IncrementPostfix, this.yes()))
				}
				Token::QUESTION => {
					operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Existential, this.yes()))
				}
				=> {
					return operand
				}
			}

			return this.reqPostfixedOperand(this.yep(AST.UnaryExpression(operator, operand, operand, operator)), eMode, fMode)
		} # }}}
		reqPrefixedOperand(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			switch this.matchM(M.PREFIX_OPERATOR) {
				Token::DOT_DOT_DOT => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Spread, this.yes()))
					const operand = this.reqPrefixedOperand(eMode, fMode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::EXCLAMATION => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Negation, this.yes()))
					const operand = this.reqPrefixedOperand(eMode, fMode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::MINUS => {
					const first = this.yes()
					const operand = this.reqPrefixedOperand(eMode, fMode)

					if operand.value.kind == NodeKind::NumericExpression {
						operand.value.value = -operand.value.value

						return this.relocate(operand, first, null)
					}
					else {
						const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Negative, first))

						return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
					}
				}
				Token::MINUS_MINUS => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::DecrementPrefix, this.yes()))
					const operand = this.reqPrefixedOperand(eMode, fMode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::PLUS_PLUS => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::IncrementPrefix, this.yes()))
					const operand = this.reqPrefixedOperand(eMode, fMode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::QUESTION => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Existential, this.yes()))
					const operand = this.reqPrefixedOperand(eMode, fMode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::TILDE_TILDE_TILDE => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::BitwiseNot, this.yes()))
					const operand = this.reqPrefixedOperand(eMode, fMode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				=> {
					return this.reqPostfixedOperand(null, eMode, fMode)
				}
			}
		} # }}}
		reqRequireDeclarator(): Event ~ SyntaxError { # {{{
			const declarator = this.tryExternDeclarator(ExternMode::Fallthrough)
			if declarator.ok {
				return declarator
			}

			switch this.matchM(M.REQUIRE_STATEMENT) {
				Token::ENUM => {
					@mode += ParserMode::Typing

					const declarator = this.reqEnumStatement(this.yes())

					@mode -= ParserMode::Typing

					return declarator
				}
				Token::FLAGGED => {
					const first = this.reqIdentifier()

					if this.test(Token::ENUM) {
						this.commit()

						const modifiers = [this.yep(AST.Modifier(ModifierKind::Flagged, first))]

						@mode += ParserMode::Typing

						const declarator = this.reqEnumStatement(first, modifiers)

						@mode -= ParserMode::Typing

						return declarator
					}
					else {
						return this.reqExternVariableDeclarator(first)
					}
				}
				Token::IDENTIFIER => {
					return this.reqExternVariableDeclarator(this.reqIdentifier())
				}
				Token::STRUCT => {
					return this.reqStructStatement(this.yes())
				}
				Token::TUPLE => {
					return this.reqTupleStatement(this.yes())
				}
				=> {
					this.throw()
				}
			}
		} # }}}
		reqRequireStatement(first: Event): Event ~ SyntaxError { # {{{
			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().NL_0M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqRequireDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					this.reqNL_1M()
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(this.reqRequireDeclarator())

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqRequireDeclarator())
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.RequireDeclaration(attributes, declarations, first, last))
		} # }}}
		reqRequireOrExternStatement(first: Event): Event ~ SyntaxError { # {{{
			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().NL_0M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqExternDeclarator(ExternMode::Default)

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					this.reqNL_1M()
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(this.reqExternDeclarator(ExternMode::Default))

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqExternDeclarator(ExternMode::Default))
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.RequireOrExternDeclaration(attributes, declarations, first, last))
		} # }}}
		reqRequireOrImportStatement(first: Event): Event ~ SyntaxError { # {{{
			const attributes = []
			const declarations = []

			let last
			if this.test(Token::LEFT_CURLY) {
				this.commit().reqNL_1M()

				let attrs = []
				let declarator

				until this.test(Token::RIGHT_CURLY) {
					if this.stackInnerAttributes(attributes) {
						continue
					}

					this.stackOuterAttributes(attrs)

					declarator = this.reqImportDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...[attr.value for const attr in attrs])
						declarator.value.start = declarator.value.attributes[0].start

						attrs = []
					}

					declarations.push(declarator)

					if this.test(Token::NEWLINE) {
						this.commit().NL_0M()
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}
			else {
				declarations.push(last = this.reqImportDeclarator())
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.RequireOrImportDeclaration(attributes, declarations, first, last))
		} # }}}
		reqReturnStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if this.match(Token::IF, Token::UNLESS, Token::NEWLINE) == Token::IF {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.IfStatement(condition, this.yep(AST.ReturnStatement(first)), null, first, condition))
			}
			else if @token == Token::NEWLINE || @token == Token::EOF {
				return this.yep(AST.ReturnStatement(first))
			}
			else if @token == Token::UNLESS {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.UnlessStatement(condition, this.yep(AST.ReturnStatement(first)), first, condition))
			}
			else {
				const expression = this.tryExpression(ExpressionMode::Default, fMode)

				unless expression.ok {
					return NO
				}

				if this.match(Token::IF, Token::UNLESS, Token::NEWLINE) == Token::IF {
					this.commit()

					const condition = this.reqExpression(ExpressionMode::Default, fMode)

					if this.match(Token::ELSE, Token::NEWLINE) == Token::ELSE {
						this.commit()

						const whenFalse = this.reqExpression(ExpressionMode::Default, fMode)

						return this.yep(AST.ReturnStatement(this.yep(AST.IfExpression(condition, expression, whenFalse, expression, whenFalse)), first, whenFalse))
					}
					else if @token == Token::NEWLINE || @token == Token::EOF {
						return this.yep(AST.IfStatement(condition, this.yep(AST.ReturnStatement(expression, first, expression)), null, first, condition))
					}
					else {
						this.throw()
					}
				}
				else if @token == Token::NEWLINE || @token == Token::EOF {
					return this.yep(AST.ReturnStatement(expression, first, expression))
				}
				else if @token == Token::UNLESS {
					this.commit()

					const condition = this.reqExpression(ExpressionMode::Default, fMode)

					return this.yep(AST.UnlessStatement(condition, this.yep(AST.ReturnStatement(expression, first, expression)), first, condition))
				}
				else {
					this.throw()
				}
			}
		} # }}}
		reqStatement(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const mark = this.mark()

			let statement = NO

			switch this.matchM(M.STATEMENT) {
				Token::ABSTRACT => {
					const first = this.yes()

					if this.test(Token::CLASS) {
						this.commit()

						const modifiers = [this.yep(AST.Modifier(ModifierKind::Abstract, first))]

						statement = this.reqClassStatement(first, modifiers)
					}
					else {
						statement = NO
					}
				}
				Token::ASYNC => {
					const first = this.yes()

					if this.test(Token::FUNC) {
						this.commit()

						const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, first))]

						statement = this.reqFunctionStatement(first, modifiers)
					}
					else {
						statement = NO
					}
				}
				Token::BREAK => {
					statement = this.reqBreakStatement(this.yes())
				}
				Token::CLASS => {
					statement = this.tryClassStatement(this.yes())
				}
				Token::CONTINUE => {
					statement = this.reqContinueStatement(this.yes())
				}
				Token::DELETE => {
					statement = this.tryDestroyStatement(this.yes(), fMode)
				}
				Token::DO => {
					statement = this.reqDoStatement(this.yes(), fMode)
				}
				Token::ENUM => {
					statement = this.reqEnumStatement(this.yes())
				}
				Token::FALLTHROUGH => {
					statement = this.reqFallthroughStatement(this.yes())
				}
				Token::FINAL => {
					const first = this.yes()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Immutable, first))]

					if this.test(Token::CLASS) {
						this.commit()

						statement = this.reqClassStatement(first, modifiers)
					}
					else if this.test(Token::ABSTRACT) {
						modifiers.push(this.yep(AST.Modifier(ModifierKind::Abstract, this.yes())))

						if this.test(Token::CLASS) {
							this.commit()

							statement = this.reqClassStatement(first, modifiers)
						}
						else {
							this.throw('class')
						}
					}
					else {
						statement = NO
					}
				}
				Token::FLAGGED => {
					const first = this.yes()

					if this.test(Token::ENUM) {
						this.commit()

						const modifiers = [this.yep(AST.Modifier(ModifierKind::Flagged, first))]

						statement = this.reqEnumStatement(first, modifiers)
					}
					else {
						statement = NO
					}
				}
				Token::FOR => {
					statement = this.reqForStatement(this.yes(), fMode)
				}
				Token::FUNC => {
					statement = this.reqFunctionStatement(this.yes())
				}
				Token::IF => {
					statement = this.reqIfStatement(this.yes(), fMode)
				}
				Token::IMPL => {
					statement = this.reqImplementStatement(this.yes())
				}
				Token::IMPORT => {
					statement = this.reqImportStatement(this.yes())
				}
				Token::MACRO => {
					if @mode !~ ParserMode::MacroExpression {
						statement = this.tryMacroStatement(this.yes())
					}
					else {
						statement = this.reqMacroExpression(this.yes())
					}
				}
				Token::NAMESPACE => {
					statement = this.tryNamespaceStatement(this.yes())
				}
				Token::RETURN => {
					statement = this.reqReturnStatement(this.yes(), fMode)
				}
				Token::SEALED => {
					const first = this.yes()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Sealed, first))]

					if this.test(Token::CLASS) {
						this.commit()

						statement = this.reqClassStatement(first, modifiers)
					}
					else if this.test(Token::ABSTRACT) {
						modifiers.push(this.yep(AST.Modifier(ModifierKind::Abstract, this.yes())))

						if this.test(Token::CLASS) {
							this.commit()

							statement = this.reqClassStatement(first, modifiers)
						}
						else {
							this.throw('class')
						}
					}
					else {
						statement = NO
					}
				}
				Token::STRUCT => {
					statement = this.reqStructStatement(this.yes())
				}
				Token::SWITCH => {
					statement = this.reqSwitchStatement(this.yes(), fMode)
				}
				Token::THROW => {
					statement = this.reqThrowStatement(this.yes(), fMode)
				}
				Token::TRY => {
					statement = this.reqTryStatement(this.yes(), fMode)
				}
				Token::TUPLE => {
					statement = this.reqTupleStatement(this.yes())
				}
				Token::TYPE => {
					statement = this.tryTypeStatement(this.yes())
				}
				Token::UNLESS => {
					statement = this.reqUnlessStatement(this.yes(), fMode)
				}
				Token::UNTIL => {
					statement = this.tryUntilStatement(this.yes(), fMode)
				}
				Token::VAR => {
					statement = this.reqVarStatement(this.yes(), ExpressionMode::Default, fMode)
				}
				Token::WHILE => {
					statement = this.tryWhileStatement(this.yes(), fMode)
				}
			}

			unless statement.ok {
				this.rollback(mark)

				if !(statement = this.tryAssignementStatement(fMode)).ok {
					this.rollback(mark)

					statement = this.reqExpressionStatement(fMode)
				}
			}

			this.reqNL_EOF_1M()

			return statement
		} # }}}
		reqString(): Event ~ SyntaxError { # {{{
			if this.test(Token::STRING) {
				return this.yep(AST.Literal(this.value(), this.yes()))
			}
			else {
				this.throw('String')
			}
		} # }}}
		reqStructStatement(first: Event): Event ~ SyntaxError { # {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			const attributes = []
			const elements = []
			let extends = null
			let last = name

			if this.test(Token::EXTENDS) {
				this.commit()

				extends = this.reqIdentifier()
			}

			if this.test(Token::LEFT_CURLY) {
				const first = this.yes()

				this.NL_0M()

				this.stackInnerAttributes(attributes)

				until this.test(Token::RIGHT_CURLY) {
					const name = this.reqIdentifier()

					let type = null
					if this.test(Token::COLON) {
						this.commit()

						type = this.reqTypeVar()
					}
					else if this.test(Token::QUESTION) {
						type = this.yep(AST.Nullable(this.yes()))
					}

					let defaultValue = null
					if this.test(Token::EQUALS) {
						this.commit()

						defaultValue = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)
					}

					elements.push(AST.StructField(name, type, defaultValue, name, defaultValue ?? type ?? name))

					if this.match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
						this.commit().NL_0M()
					}
					else if @token == Token::NEWLINE {
						this.commit().NL_0M()

						if this.test(Token::COMMA) {
							this.commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				last = this.yes()
			}

			return this.yep(AST.StructDeclaration(attributes, name, extends, elements, first, last))
		} # }}}
		reqSwitchBinding(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const bindings = [this.reqSwitchBindingValue(fMode)]

			while this.test(Token::COMMA) {
				this.commit()

				bindings.push(this.reqSwitchBindingValue(fMode))
			}

			return this.yep(bindings)
		} # }}}
		reqSwitchBindingValue(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			switch this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) {
				Token::LEFT_CURLY => {
					return this.reqDestructuringObject(this.yes(), DestructuringMode::Nil, fMode)
				}
				Token::LEFT_SQUARE => {
					return this.reqDestructuringArray(this.yes(), DestructuringMode::Nil, fMode)
				}
				=> {
					const name = this.reqIdentifier()

					if this.test(Token::AS) {
						this.commit()

						const type = this.reqTypeVar()

						return this.yep(AST.SwitchTypeCasting(name, type))
					}
					else {
						return name
					}
				}
			}
		} # }}}
		reqSwitchCaseExpression(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			switch this.match(Token::LEFT_CURLY, Token::RETURN, Token::THROW) {
				Token::LEFT_CURLY => {
					return this.reqBlock(this.yes(), fMode)
				}
				Token::RETURN => {
					return this.reqReturnStatement(this.yes(), fMode)
				}
				Token::THROW => {
					const first = this.yes()
					const expression = this.reqExpression(ExpressionMode::Default, fMode)

					return this.yep(AST.ThrowStatement(expression, first, expression))
				}
				=> {
					return this.reqExpression(ExpressionMode::Default, fMode)
				}
			}
		} # }}}
		reqSwitchCaseList(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			this.NL_0M()

			unless this.test(Token::LEFT_CURLY) {
				this.throw('{')
			}

			this.commit().NL_0M()

			const clauses = []

			let conditions, bindings, filter, body, first
			until this.test(Token::RIGHT_CURLY) {
				first = conditions = bindings = filter = null

				if this.test(Token::EQUALS_RIGHT_ANGLE) {
					first = this.yes()
					body = this.reqSwitchCaseExpression(fMode)
				}
				else {
					if this.test(Token::UNDERSCORE) {
						first = this.yes()
					}
					else if !this.test(Token::WITH, Token::WHEN) {
						first = this.reqSwitchCondition(fMode)

						conditions = [first]

						while this.test(Token::COMMA) {
							this.commit()

							conditions.push(this.reqSwitchCondition(fMode))
						}

						this.NL_0M()
					}

					if this.test(Token::WITH) {
						if first == null {
							first = this.yes()
						}
						else {
							this.commit()
						}

						bindings = this.reqSwitchBinding(fMode)

						this.NL_0M()
					}

					if this.test(Token::WHEN) {
						if first == null {
							first = this.yes()
						}
						else {
							this.commit()
						}

						filter = this.reqExpression(ExpressionMode::NoAnonymousFunction, fMode)

						this.NL_0M()
					}

					unless this.test(Token::EQUALS_RIGHT_ANGLE) {
						this.throw('=>')
					}

					this.commit()

					body = this.reqSwitchCaseExpression(fMode)
				}

				this.reqNL_1M()

				clauses.push(AST.SwitchClause(conditions, bindings, filter, body, first!?, body))
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yes(clauses)
		} # }}}
		reqSwitchCondition(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			switch this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE, Token::IS, Token::COLON) {
				Token::COLON => {
					throw new Error('Not Implemented')
				}
				Token::IS => {
					const first = this.yes()
					const type = this.reqTypeVar()

					return this.yep(AST.SwitchConditionType(type, first, type))
				}
				Token::LEFT_CURLY => {
					let first = this.yes()

					const members = []

					if !this.test(Token::RIGHT_CURLY) {
						let name

						while true {
							name = this.reqIdentifier()

							if this.test(Token::COLON) {
								this.commit()

								members.push(this.yep(AST.ObjectMember(name, this.reqSwitchConditionValue(fMode))))
							}
							else {
								members.push(this.yep(AST.ObjectMember(name)))
							}

							if this.test(Token::COMMA) {
								this.commit()
							}
							else {
								break
							}
						}
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					return this.yep(AST.SwitchConditionObject(members, first, this.yes()))
				}
				Token::LEFT_SQUARE => {
					let first = this.yes()

					const values = []

					until this.test(Token::RIGHT_SQUARE) {
						if this.test(Token::UNDERSCORE) {
							values.push(this.yep(AST.OmittedExpression([], this.yes())))
						}
						else if this.test(Token::DOT_DOT_DOT) {
							modifier = AST.Modifier(ModifierKind::Rest, this.yes())

							values.push(this.yep(AST.OmittedExpression([modifier], modifier)))
						}
						else {
							values.push(this.reqSwitchConditionValue(fMode))
						}

						if this.test(Token::COMMA) {
							this.commit()

							if this.test(Token::RIGHT_SQUARE) {
								values.push(this.yep(AST.OmittedExpression([], this.yep())))
							}
						}
						else {
							break
						}
					}

					unless this.test(Token::RIGHT_SQUARE) {
						this.throw(']')
					}

					return this.yep(AST.SwitchConditionArray(values, first, this.yes()))
				}
				=> {
					return this.reqSwitchConditionValue(fMode)
				}
			}
		} # }}}
		reqSwitchConditionValue(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const operand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)

			if this.match(Token::LEFT_ANGLE, Token::DOT_DOT) == Token::DOT_DOT {
				this.commit()

				if this.test(Token::LEFT_ANGLE) {
					this.commit()

					return this.yep(AST.SwitchConditionRangeFI(operand, this.reqPrefixedOperand(ExpressionMode::Default, fMode)))
				}
				else {
					return this.yep(AST.SwitchConditionRangeFO(operand, this.reqPrefixedOperand(ExpressionMode::Default, fMode)))
				}
			}
			else if @token == Token::LEFT_ANGLE {
				this.commit()

				unless this.test(Token::DOT_DOT) {
					this.throw('..')
				}

				this.commit()

				if this.test(Token::LEFT_ANGLE) {
					this.commit()

					return this.yep(AST.SwitchConditionRangeTI(operand, this.reqPrefixedOperand(ExpressionMode::Default, fMode)))
				}
				else {
					return this.yep(AST.SwitchConditionRangeTO(operand, this.reqPrefixedOperand(ExpressionMode::Default, fMode)))
				}
			}
			else {
				return operand
			}
			} # }}}
		reqSwitchStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const expression = this.reqOperation(ExpressionMode::Default, fMode)
			const clauses = this.reqSwitchCaseList(fMode)

			return this.yep(AST.SwitchStatement(expression, clauses, first, clauses))
		} # }}}
		reqTemplateExpression(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const elements = []

			while true {
				if this.matchM(M.TEMPLATE) == Token::TEMPLATE_ELEMENT {
					this.commit()

					elements.push(this.reqExpression(ExpressionMode::Default, fMode))

					unless this.test(Token::RIGHT_ROUND) {
						this.throw(')')
					}

					this.commit()
				}
				else if @token == Token::TEMPLATE_VALUE {
					elements.push(this.yep(AST.Literal(@scanner.value(), this.yes())))
				}
				else {
					break
				}
			}

			unless this.test(Token::TEMPLATE_END) {
				this.throw('`')
			}

			return this.yep(AST.TemplateExpression(elements, first, this.yes()))
		} # }}}
		reqThisExpression(first: Event): Event ~ SyntaxError { # {{{
			const identifier = this.reqIdentifier()

			return this.yep(AST.ThisExpression(identifier, first, identifier))
		} # }}}
		reqThrowStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const expression = this.reqExpression(ExpressionMode::Default, fMode)

			if this.match(Token::IF, Token::UNLESS, Token::NEWLINE) == Token::IF {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				if this.match(Token::ELSE, Token::NEWLINE) == Token::ELSE {
					this.commit()

					const whenFalse = this.reqExpression(ExpressionMode::Default, fMode)

					return this.yep(AST.ThrowStatement(this.yep(AST.IfExpression(condition, expression, whenFalse, expression, whenFalse)), first, whenFalse))
				}
				else if @token == Token::NEWLINE || @token == Token::EOF {
					return this.yep(AST.IfStatement(condition, this.yep(AST.ThrowStatement(expression, first, expression)), null, first, condition))
				}
				else {
					this.throw()
				}
			}
			else if @token == Token::NEWLINE || @token == Token::EOF {
				return this.yep(AST.ThrowStatement(expression, first, expression))
			}
			else if @token == Token::UNLESS {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				return this.yep(AST.UnlessStatement(condition, this.yep(AST.ThrowStatement(expression, first, expression)), first, condition))
			}
			else {
				this.throw()
			}
		} # }}}
		reqTryCatchClause(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let binding
			if this.test(Token::IDENTIFIER) {
				binding = this.reqIdentifier()
			}

			this.NL_0M()

			const body = this.reqBlock(NO, fMode)

			return this.yep(AST.CatchClause(binding, null, body, first, body))
		} # }}}
		reqTryExpression(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const modifiers = []
			if this.testNS(Token::EXCLAMATION) {
				modifiers.push(AST.Modifier(ModifierKind::Disabled, this.yes()))
			}

			const operand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)

			let default = null

			if this.test(Token::TILDE) {
				this.commit()

				default = this.reqPrefixedOperand(ExpressionMode::Default, fMode)
			}

			return this.yep(AST.TryExpression(modifiers, operand, default, first, default ?? operand))
		} # }}}
		reqTryStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			this.NL_0M()

			const body = this.tryBlock(fMode)

			unless body.ok {
				return NO
			}

			let last = body

			let mark = this.mark()

			const catchClauses = []
			let catchClause, finalizer

			this.NL_0M()

			if this.test(Token::ON) {
				do {
					catchClauses.push(last = this.reqCatchOnClause(this.yes(), fMode))

					mark = this.mark()

					this.NL_0M()
				}
				while this.test(Token::ON)
			}
			else {
				this.rollback(mark)

				this.NL_0M()
			}

			if this.test(Token::CATCH) {
				catchClause = last = this.reqTryCatchClause(this.yes(), fMode)

				mark = this.mark()
			}
			else {
				this.rollback(mark)
			}

			this.NL_0M()

			if this.test(Token::FINALLY) {
				this.commit()

				finalizer = last = this.reqBlock(NO, fMode)
			}
			else {
				this.rollback(mark)
			}

			return this.yep(AST.TryStatement(body, catchClauses, catchClause, finalizer, first, last))
		} # }}}
		reqTupleStatement(first: Event): Event ~ SyntaxError { # {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			const attributes = []
			const modifiers = []
			const elements = []
			let extends = null
			let last = name

			if this.test(Token::EXTENDS) {
				this.commit()

				extends = this.reqIdentifier()
			}

			if extends == null && this.test(Token::LEFT_ROUND) {
				const first = this.yes()

				this.NL_0M()

				this.stackInnerAttributes(attributes)

				until this.test(Token::RIGHT_ROUND) {
					const type = this.reqTypeVar()

					if this.test(Token::EQUALS) {
						this.commit()

						const defaultValue = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)

						elements.push(AST.TupleField(null, type, defaultValue, type, defaultValue))
					}
					else {
						elements.push(AST.TupleField(null, type, null, type, type))
					}

					if this.match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
						this.commit().NL_0M()
					}
					else if @token == Token::NEWLINE {
						this.commit().NL_0M()

						if this.test(Token::COMMA) {
							this.commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				last = this.yes()

				if this.test(Token::EXTENDS) {
					this.commit()

					last = extends = this.reqIdentifier()
				}
			}
			else if this.test(Token::LEFT_CURLY) {
				const first = this.yes()

				this.NL_0M()

				modifiers.push(AST.Modifier(ModifierKind::Named, first))

				this.stackInnerAttributes(attributes)

				until this.test(Token::RIGHT_CURLY) {
					const name = this.reqIdentifier()

					let type = null
					if this.test(Token::COLON) {
						this.commit()

						type = this.reqTypeVar()
					}
					else if this.test(Token::QUESTION) {
						type = this.yep(AST.Nullable(this.yes()))
					}

					let defaultValue = null
					if this.test(Token::EQUALS) {
						this.commit()

						defaultValue = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)
					}

					elements.push(AST.TupleField(name, type, defaultValue, name, defaultValue ?? type ?? name))

					if this.match(Token::COMMA, Token::NEWLINE) == Token::COMMA {
						this.commit().NL_0M()
					}
					else if @token == Token::NEWLINE {
						this.commit().NL_0M()

						if this.test(Token::COMMA) {
							this.commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw(']')
				}

				last = this.yes()
			}

			return this.yep(AST.TupleDeclaration(attributes, modifiers, name, extends, elements, first, last))
		} # }}}
		reqTypeEntity(nullable = null): Event ~ SyntaxError { # {{{
			const marker = this.mark()

			if this.match(Token::ASYNC, Token::FUNC, Token::LEFT_ROUND) == Token::ASYNC {
				const async = this.yes()

				if this.test(Token::FUNC) {
					this.commit()
				}

				if this.test(Token::LEFT_ROUND) {
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, async))]
					const parameters = this.reqFunctionParameterList(FunctionMode::Function)
					const type = this.tryFunctionReturns(false)
					const throws = this.tryFunctionThrows()

					return this.yep(AST.FunctionExpression(parameters, modifiers, type, throws, null, async, throws ?? type ?? parameters))
				}
				else {
					this.rollback(marker)
				}
			}
			else if @token == Token::FUNC {
				const first = this.yes()

				if this.test(Token::LEFT_ROUND) {
					const parameters = this.reqFunctionParameterList(FunctionMode::Function)
					const type = this.tryFunctionReturns(false)
					const throws = this.tryFunctionThrows()

					return this.yep(AST.FunctionExpression(parameters, null, type, throws, null, first, throws ?? type ?? parameters))
				}
				else {
					this.rollback(marker)
				}
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.reqFunctionParameterList(FunctionMode::Function)
				const type = this.tryFunctionReturns(false)
				const throws = this.tryFunctionThrows()

				return this.yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?? type ?? parameters))
			}

			let name = this.reqIdentifier()

			if this.testNS(Token::DOT) {
				let property

				do {
					this.commit()

					property = this.reqIdentifier()

					name = this.yep(AST.MemberExpression([], name, property))
				}
				while this.testNS(Token::DOT)
			}
			let last = name

			let generic
			if this.testNS(Token::LEFT_ANGLE) {
				generic = last = this.reqTypeGeneric(this.yes())
			}

			const modifiers =[]

			if nullable == null && this.testNS(Token::QUESTION) {
				last = this.yes()

				modifiers.push(AST.Modifier(ModifierKind::Nullable, last))
			}

			return this.yep(AST.TypeReference(modifiers, name, generic, name, last))
		} # }}}
		reqTypeGeneric(first: Event): Event ~ SyntaxError { # {{{
			const entities = [this.reqTypeEntity()]

			while this.test(Token::COMMA) {
				this.commit()

				entities.push(this.reqTypeEntity())
			}

			unless this.test(Token::RIGHT_ANGLE) {
				this.throw('>')
			}

			return this.yes(entities)
		} # }}}
		reqTypeStatement(first: Event, name: Event): Event ~ SyntaxError { # {{{
			unless this.test(Token::EQUALS) {
				this.throw('=')
			}

			this.commit()

			const type = this.reqTypeVar(true)

			return this.yep(AST.TypeAliasDeclaration(name, type, first, type))
		} # }}}
		reqTypeVar(isMultiLines: Boolean = false): Event ~ SyntaxError { # {{{
			this.NL_0M() if isMultiLines

			const type = this.reqTypeReference(isMultiLines)

			let mark = this.mark()

			if isMultiLines {
				const types = [type]

				this.NL_0M()

				if this.match(Token::PIPE, Token::AMPERSAND, Token::CARET) == Token::PIPE {
					do {
						this.commit()

						if this.test(Token::PIPE) {
							this.commit()
						}

						this.NL_0M()

						types.push(this.reqTypeReference(true))

						mark = this.mark()

						this.NL_0M()
					}
					while this.test(Token::PIPE)

					this.rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return this.yep(AST.UnionType(types, type, types[types.length - 1]))
					}
				}
				else if @token == Token::AMPERSAND {
					do {
						this.commit()

						if this.test(Token::AMPERSAND) {
							this.commit()
						}

						this.NL_0M()

						types.push(this.reqTypeReference(true))

						mark = this.mark()

						this.NL_0M()
					}
					while this.test(Token::AMPERSAND)

					this.rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return this.yep(AST.FusionType(types, type, types[types.length - 1]))
					}
				}
				else if @token == Token::CARET {
					do {
						this.commit()

						if this.test(Token::CARET) {
							this.commit()
						}

						this.NL_0M()

						types.push(this.reqTypeReference(true))

						mark = this.mark()

						this.NL_0M()
					}
					while this.test(Token::CARET)

					this.rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return this.yep(AST.ExclusionType(types, type, types[types.length - 1]))
					}
				}
				else {
					this.rollback(mark)
				}
			}
			else {
				if this.match(Token::PIPE_PIPE, Token::PIPE, Token::AMPERSAND_AMPERSAND, Token::AMPERSAND, Token::CARET_CARET, Token::CARET) == Token::PIPE {
					this.commit()

					if this.test(Token::NEWLINE) {
						this.rollback(mark)

						return type
					}

					const types = [type]

					do {
						this.commit()

						types.push(this.reqTypeReference(false))
					}
					while this.test(Token::PIPE)

					return this.yep(AST.UnionType(types, type, types[types.length - 1]))
				}
				else if @token == Token::AMPERSAND {
					this.commit()

					if this.test(Token::NEWLINE) {
						this.rollback(mark)

						return type
					}

					const types = [type]

					do {
						this.commit()

						types.push(this.reqTypeReference(false))
					}
					while this.test(Token::AMPERSAND)

					return this.yep(AST.FusionType(types, type, types[types.length - 1]))
				}
				else if @token == Token::CARET {
					this.commit()

					if this.test(Token::NEWLINE) {
						this.rollback(mark)

						return type
					}

					const types = [type]

					do {
						this.commit()

						types.push(this.reqTypeReference(false))
					}
					while this.test(Token::CARET)

					return this.yep(AST.ExclusionType(types, type, types[types.length - 1]))
				}
			}

			return type
		} # }}}
		reqTypeObjectMember(): Event ~ SyntaxError { # {{{
			const identifier = this.reqIdentifier()

			let type
			if this.test(Token::COLON) {
				this.commit()

				type = this.reqTypeVar()
			}
			else {
				const parameters = this.reqFunctionParameterList(FunctionMode::Function)
				type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()

				type = this.yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?? type ?? parameters))
			}

			return this.yep(AST.ObjectMemberReference(identifier, type))
		} # }}}
		reqTypeReference(isMultiLines: Boolean): Event ~ SyntaxError { # {{{
			if this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY {
				const first = this.yes()
				const properties = []

				this.NL_0M()

				until this.test(Token::RIGHT_CURLY) {
					if this.match(Token::ASYNC, Token::FUNC, Token::IDENTIFIER) == Token::IDENTIFIER {
						properties.push(this.reqTypeObjectMember())
					}
					else if @token == Token::ASYNC {
						const marker = this.mark()
						const async = this.yes()

						if this.test(Token::FUNC) {
							this.commit()
						}

						const identifier = this.reqIdentifier()

						if this.test(Token::LEFT_ROUND) {
							const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, async))]
							const parameters = this.reqFunctionParameterList(FunctionMode::Function)
							const type = this.tryFunctionReturns(false)
							const throws = this.tryFunctionThrows()

							const objectType = this.yep(AST.FunctionExpression(parameters, modifiers, type, throws, null, parameters, throws ?? type ?? parameters))

							properties.push(this.yep(AST.ObjectMemberReference(identifier, objectType)))
						}
						else {
							this.rollback(marker)

							properties.push(this.reqTypeObjectMember())
						}
					}
					else if @token == Token::FUNC {
						const marker = this.mark()
						const first = this.yes()

						const identifier = this.reqIdentifier()

						if this.test(Token::LEFT_ROUND) {
							const parameters = this.reqFunctionParameterList(FunctionMode::Function)
							const type = this.tryFunctionReturns(false)
							const throws = this.tryFunctionThrows()

							const objectType = this.yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?? type ?? parameters))

							properties.push(this.yep(AST.ObjectMemberReference(identifier, objectType)))
						}
						else {
							this.rollback(marker)

							properties.push(this.reqTypeObjectMember())
						}
					}
					else {
						this.throw(['async', 'func', 'Identifier'])
					}


					if this.test(Token::COMMA) {
						this.commit().NL_0M()
					}
					else if this.test(Token::NEWLINE) {
						this.commit().NL_0M()

						if this.test(Token::COMMA) {
							this.commit().NL_0M()
						}
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				return this.yep(AST.ObjectReference(properties, first, this.yes()))
			}
			else if @token == Token::LEFT_SQUARE {
				const first = this.yes()
				const elements = []

				this.NL_0M()

				while this.until(Token::RIGHT_SQUARE) {
					if this.test(Token::COMMA) {
						elements.push(AST.OmittedReference(this.yep()))

						this.commit().NL_0M()
					}
					else {
						elements.push(this.reqTypeVar(isMultiLines))

						if this.test(Token::COMMA) {
							this.commit().NL_0M()
						}
						else if this.test(Token::NEWLINE) {
							this.commit().NL_0M()
						}
						else {
							break
						}
					}
				}

				unless this.test(Token::RIGHT_SQUARE) {
					this.throw(']')
				}

				return this.yep(AST.ArrayReference(elements, first, this.yes()))
			}
			else {
				return this.reqTypeEntity()
			}
		} # }}}
		reqTypedVariable(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let name = null
			let type = null

			if this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY {
				name = this.reqDestructuringObject(this.yes(), DestructuringMode::Declaration, fMode)
			}
			else if @token == Token::LEFT_SQUARE {
				name = this.reqDestructuringArray(this.yes(), DestructuringMode::Declaration, fMode)
			}
			else {
				name = this.reqIdentifier()
			}

			if this.test(Token::COLON) {
				this.commit()

				type = this.reqTypeVar()
			}

			return this.yep(AST.VariableDeclarator([], name, type, name, type ?? name))
		} # }}}
		reqUnaryOperand(value: Event?, eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if value == null {
				value = this.reqOperand(eMode, fMode)
			}

			let expression, mark, first

			while true {
				switch this.matchM(M.OPERAND_JUNCTION) {
					Token::ASTERISK_ASTERISK_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CallExpression([], AST.Scope(ScopeKind::Null), value, this.reqExpression0CNList(fMode), value, this.yes()))
					}
					Token::ASTERISK_DOLLAR_LEFT_ROUND => {
						this.commit()

						const arguments = this.reqExpression0CNList(fMode)

						value = this.yep(AST.CallExpression([], AST.Scope(ScopeKind::Argument, arguments.value.shift()), value, arguments, value, this.yes()))
					}
					Token::CARET_AT_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CurryExpression(AST.Scope(ScopeKind::This), value, this.reqExpression0CNList(fMode), value, this.yes()))
					}
					Token::CARET_CARET_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CurryExpression(AST.Scope(ScopeKind::Null), value, this.reqExpression0CNList(fMode), value, this.yes()))
					}
					Token::CARET_DOLLAR_LEFT_ROUND => {
						this.commit()

						const arguments = this.reqExpression0CNList(fMode)

						value = this.yep(AST.CurryExpression(AST.Scope(ScopeKind::Argument, arguments.value.shift()), value, arguments, value, this.yes()))
					}
					Token::COLON => {
						first = this.yes()

						expression = this.reqIdentifier()

						value = this.yep(AST.BinaryExpression(value, this.yep(AST.BinaryOperator(BinaryOperatorKind::TypeCasting, first)), this.yep(AST.TypeReference(expression)), value, expression))
					}
					Token::COLON_COLON => {
						this.commit()

						expression = this.reqIdentifier()

						value = this.yep(AST.EnumExpression(value, expression))
					}
					Token::COLON_EXCLAMATION => {
						first = this.yes()

						const operator = this.yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Forced, first)], BinaryOperatorKind::TypeCasting, first))

						expression = this.reqIdentifier()

						value = this.yep(AST.BinaryExpression(value, operator, this.yep(AST.TypeReference(expression)), value, expression))
					}
					Token::COLON_QUESTION => {
						first = this.yes()

						const operator = this.yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Nullable, first)], BinaryOperatorKind::TypeCasting, first))

						expression = this.reqIdentifier()

						value = this.yep(AST.BinaryExpression(value, operator, this.yep(AST.TypeReference(expression)), value, expression))
					}
					Token::DOT => {
						this.commit()

						value = this.yep(AST.MemberExpression([], value, this.reqNumeralIdentifier()))
					}
					Token::EXCLAMATION_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CallMacroExpression(value, this.reqExpression0CNList(fMode), value, this.yes()))
					}
					Token::LEFT_SQUARE => {
						const modifiers = [AST.Modifier(ModifierKind::Computed, this.yes())]

						expression = this.reqExpression(ExpressionMode::Default, fMode)

						unless this.test(Token::RIGHT_SQUARE) {
							this.throw(']')
						}

						value = this.yep(AST.MemberExpression(modifiers, value, expression, value, this.yes()))
					}
					Token::LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CallExpression([], value, this.reqExpression0CNList(fMode), value, this.yes()))
					}
					Token::NEWLINE => {
						mark = this.mark()

						this.commit().NL_0M()

						if this.test(Token::DOT) {
							this.commit()

							value = this.yep(AST.MemberExpression([], value, this.reqIdentifier()))
						}
						else {
							this.rollback(mark)

							break
						}
					}
					Token::QUESTION_DOT => {
						const modifiers = [AST.Modifier(ModifierKind::Nullable, this.yes())]

						expression = this.reqIdentifier()

						value = this.yep(AST.MemberExpression(modifiers, value, expression, value, expression))
					}
					Token::QUESTION_LEFT_ROUND => {
						const modifiers = [AST.Modifier(ModifierKind::Nullable, this.yes())]

						value = this.yep(AST.CallExpression(modifiers, AST.Scope(ScopeKind::This), value, this.reqExpression0CNList(fMode), value, this.yes()))
					}
					Token::QUESTION_LEFT_SQUARE => {
						const position = this.yes()
						const modifiers = [AST.Modifier(ModifierKind::Nullable, position), AST.Modifier(ModifierKind::Computed, position)]

						expression = this.reqExpression(ExpressionMode::Default, fMode)

						unless this.test(Token::RIGHT_SQUARE) {
							this.throw(']')
						}

						value = this.yep(AST.MemberExpression(modifiers, value, expression, value, this.yes()))
					}
					Token::TEMPLATE_BEGIN => {
						value = this.yep(AST.TaggedTemplateExpression(value, this.reqTemplateExpression(this.yes(), fMode), value, this.yes()))
					}
					=> {
						break
					}
				}
			}

			return value
		} # }}}
		reqUnlessStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const condition = this.reqExpression(ExpressionMode::Default, fMode)
			const whenFalse = this.reqBlock(NO, fMode)

			return this.yep(AST.UnlessStatement(condition, whenFalse, first, whenFalse))
		} # }}}
		reqVarStatement(first: Event, eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const mark = @mark()
			const modifiers = []

			let immutable = false
			let lateinit = false

			if @match(Token::DYN, Token::LATE, Token::MUT) == Token::INVALID {
				immutable = true
			}
			else {
				let modifier

				if @token == Token::DYN {
					modifier = AST.Modifier(ModifierKind::Dynamic, @yes())
				}
				else if @token == Token::LATE {
					modifier = AST.Modifier(ModifierKind::LateInit, @yes())

					lateinit = true
				}
				else if @token == Token::MUT {
					modifier = AST.Modifier(ModifierKind::Mutable, @yes())
				}

				if @test(Token::COLON, Token::EQUALS, Token::NEWLINE) {
					@rollback(mark)
				}
				else {
					modifiers.push(modifier)
				}
			}

			const variables = [@reqTypedVariable(fMode)]

			if @test(Token::COMMA) {
				do {
					@commit()

					variables.push(@reqTypedVariable(fMode))
				}
				while @test(Token::COMMA)
			}

			if @test(Token::EQUALS) {
				@throw([':', ',', 'NewLine']) if lateinit

				@commit().NL_0M()

				let init
				if variables.length == 1 {
					init = @reqExpression(eMode, fMode)
				}
				else {
					unless @test(Token::AWAIT) {
						@throw('await')
					}

					@commit()

					const operand = @reqPrefixedOperand(eMode, fMode)

					init = @yep(AST.AwaitExpression([], variables, operand, variables[0], operand))
				}

				if @match(Token::IF, Token::UNLESS) == Token::IF {
					const first = @yes()
					const condition = @reqExpression(ExpressionMode::Default, fMode)

					if @test(Token::ELSE) {
						@commit()

						const whenFalse = @reqExpression(ExpressionMode::Default, fMode)

						init = @yep(AST.IfExpression(condition, init, whenFalse, init, whenFalse))
					}
					else {
						init = @yep(AST.IfExpression(condition, init, null, init, condition))
					}
				}
				else if @token == Token::UNLESS {
					@commit()

					const condition = @reqExpression(ExpressionMode::Default, fMode)

					init = @yep(AST.UnlessExpression(condition, init, init, condition))
				}

				return @yep(AST.VariableDeclaration(modifiers, variables, init, first, init))
			}
			else {
				@throw('=') if immutable

				return @yep(AST.VariableDeclaration(modifiers, variables, null, first, variables[variables.length - 1]))
			}
		} # }}}
		reqVariable(): Event ~ SyntaxError { # {{{
			const name = this.reqIdentifier()

			return this.yep(AST.VariableDeclarator([], name, null, name, name))
		} # }}}
		reqVariableIdentifier(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if this.match(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::IDENTIFIER {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else if @token == Token::LEFT_CURLY {
				return this.reqDestructuringObject(this.yes(), DestructuringMode::Expression, fMode)
			}
			else if @token == Token::LEFT_SQUARE {
				return this.reqDestructuringArray(this.yes(), DestructuringMode::Expression, fMode)
			}
			else {
				this.throw(['Identifier', '{', '['])
			}
		} # }}}
		reqVariableName(object: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if !object.ok {
				if fMode == FunctionMode::Method && this.test(Token::AT) {
					object = this.reqThisExpression(this.yes())
				}
				else {
					object = this.reqIdentifier()
				}
			}

			let property
			while true {
				if this.match(Token::DOT, Token::LEFT_SQUARE) == Token::DOT {
					this.commit()

					property = this.reqIdentifier()

					object = this.yep(AST.MemberExpression([], object, property))
				}
				else if @token == Token::LEFT_SQUARE {
					const modifiers = [AST.Modifier(ModifierKind::Computed, this.yes())]

					property = this.reqExpression(ExpressionMode::Default, fMode)

					unless this.test(Token::RIGHT_SQUARE) {
						this.throw(']')
					}

					object = this.yep(AST.MemberExpression(modifiers, object, property, object, this.yes()))
				}
				else {
					break
				}
			}

			return object
		} # }}}
		stackInnerAttributes(attributes: Array): Boolean ~ SyntaxError { # {{{
			if this.test(Token::HASH_EXCLAMATION_LEFT_SQUARE) {
				do {
					const first = this.yes()
					const declaration = this.reqAttributeMember()

					unless this.test(Token::RIGHT_SQUARE) {
						this.throw(']')
					}

					attributes.push(this.yep(AST.AttributeDeclaration(declaration, first, this.yes())))

					this.reqNL_EOF_1M()
				}
				while this.test(Token::HASH_EXCLAMATION_LEFT_SQUARE)

				return true
			}
			else {
				return false
			}
		} # }}}
		stackOuterAttributes(attributes: Array): Array ~ SyntaxError { # {{{
			while this.test(Token::HASH_LEFT_SQUARE) {
				attributes.push(this.reqAttribute(this.yes()))

				this.NL_0M()
			}

			return attributes
		} # }}}
		submitEnumMember(attributes: Array, modifiers: Array, identifier: Event, token: Token?, members: Array): Void ~ SyntaxError { # {{{
			const first = attributes[0] ?? modifiers[0] ?? identifier

			switch token ?? this.match(Token::EQUALS, Token::LEFT_ROUND)  {
				Token::EQUALS => {
					if @mode ~~ ParserMode::Typing {
						this.throw()
					}

					this.commit()

					const value = this.reqExpression(ExpressionMode::Default, FunctionMode::Function)

					members.push(AST.FieldDeclaration(attributes, modifiers, identifier, null, value, first, value))

					this.reqNL_1M()
				}
				Token::LEFT_ROUND => {
					members.push(this.reqEnumMethod(attributes, modifiers, identifier, first).value)
				}
				when token == null => {
					members.push(AST.FieldDeclaration(attributes, modifiers, identifier, null, null, first, identifier))

					this.reqNL_1M()
				}
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
			switch this.matchM(M.ASSIGNEMENT_OPERATOR) {
				Token::AMPERSAND_AMPERSAND_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseAnd, this.yes()))
				}
				Token::ASTERISK_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Multiplication, this.yes()))
				}
				Token::CARET_CARET_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseXor, this.yes()))
				}
				Token::EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Equality, this.yes()))
				}
				Token::EXCLAMATION_QUESTION_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::NonExistential, this.yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseLeftShift, this.yes()))
				}
				Token::MINUS_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Subtraction, this.yes()))
				}
				Token::PERCENT_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Modulo, this.yes()))
				}
				Token::PIPE_PIPE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseOr, this.yes()))
				}
				Token::PLUS_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Addition, this.yes()))
				}
				Token::QUESTION_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Existential, this.yes()))
				}
				Token::QUESTION_QUESTION_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::NullCoalescing, this.yes()))
				}
				Token::RIGHT_ANGLE_RIGHT_ANGLE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseRightShift, this.yes()))
				}
				Token::SLASH_DOT_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Quotient, this.yes()))
				}
				Token::SLASH_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Division, this.yes()))
				}
				=> {
					return NO
				}
			}
		} # }}}
		tryAssignementStatement(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let identifier = NO

			if this.match(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE, Token::AT) == Token::IDENTIFIER {
				identifier = this.reqUnaryOperand(this.reqIdentifier(), ExpressionMode::Default, fMode)
			}
			else if @token == Token::LEFT_CURLY {
				identifier = this.tryDestructuringObject(this.yes(), fMode)
			}
			else if @token == Token::LEFT_SQUARE {
				identifier = this.tryDestructuringArray(this.yes(), fMode)
			}
			else if fMode == FunctionMode::Method && @token == Token::AT {
				identifier = this.reqUnaryOperand(this.reqThisExpression(this.yes()), ExpressionMode::Default, fMode)
			}

			unless identifier.ok {
				return NO
			}

			let statement
			if this.match(Token::COMMA, Token::EQUALS) == Token::COMMA {
				unless identifier.value.kind == NodeKind::Identifier || identifier.value.kind == NodeKind::ArrayBinding || identifier.value.kind == NodeKind::ObjectBinding {
					return NO
				}

				const variables = [identifier]

				do {
					this.commit()

					variables.push(this.reqVariableIdentifier(fMode))
				}
				while this.test(Token::COMMA)

				if this.test(Token::EQUALS) {
					this.commit().NL_0M()

					unless this.test(Token::AWAIT) {
						this.throw('await')
					}

					const operand = this.reqPrefixedOperand(ExpressionMode::Default, fMode)

					statement = this.yep(AST.AwaitExpression([], variables, operand, identifier, operand))
				}
				else {
					this.throw('=')
				}
			}
			else if @token == Token::EQUALS {
				const equals = this.yes()

				this.NL_0M()

				const expression = this.reqExpression(ExpressionMode::Default, fMode)

				statement = this.yep(AST.BinaryExpression(identifier, this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Equality, equals)), expression, identifier, expression))
			}
			else {
				return NO
			}

			if this.match(Token::IF, Token::UNLESS) == Token::IF {
				const first = this.yes()
				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				if this.test(Token::ELSE) {
					this.commit()

					const whenFalse = this.reqExpression(ExpressionMode::Default, fMode)

					statement.value.right = AST.IfExpression(condition, this.yep(statement.value.right), whenFalse, first, whenFalse)

					this.relocate(statement, statement, whenFalse)
				}
				else {
					statement = this.yep(AST.IfExpression(condition, statement, null, statement, condition))
				}
			}
			else if @token == Token::UNLESS {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default, fMode)

				statement = this.yep(AST.UnlessExpression(condition, statement, statement, condition))
			}

			return this.yep(AST.ExpressionStatement(statement))
		} # }}}
		tryAwaitExpression(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless this.test(Token::AWAIT) {
				return NO
			}

			try {
				return this.reqAwaitExpression(this.yes(), fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryBinaryOperator(): Event ~ SyntaxError { # {{{
			switch this.matchM(M.BINARY_OPERATOR) {
				Token::AMPERSAND_AMPERSAND => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::And, this.yes()))
				}
				Token::AMPERSAND_AMPERSAND_AMPERSAND => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseAnd, this.yes()))
				}
				Token::AMPERSAND_AMPERSAND_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseAnd, this.yes()))
				}
				Token::ASTERISK => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Multiplication, this.yes()))
				}
				Token::ASTERISK_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Multiplication, this.yes()))
				}
				Token::CARET_CARET => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Xor, this.yes()))
				}
				Token::CARET_CARET_CARET => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseXor, this.yes()))
				}
				Token::CARET_CARET_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseXor, this.yes()))
				}
				Token::EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Equality, this.yes()))
				}
				Token::EQUALS_EQUALS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Equality, this.yes()))
				}
				Token::EXCLAMATION_EQUALS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Inequality, this.yes()))
				}
				Token::EXCLAMATION_TILDE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Mismatch, this.yes()))
				}
				Token::EXCLAMATION_QUESTION_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::NonExistential, this.yes()))
				}
				Token::LEFT_ANGLE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::LessThan, this.yes()))
				}
				Token::LEFT_ANGLE_EQUALS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::LessThanOrEqual, this.yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseLeftShift, this.yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE_LEFT_ANGLE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseLeftShift, this.yes()))
				}
				Token::MINUS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Subtraction, this.yes()))
				}
				Token::MINUS_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Subtraction, this.yes()))
				}
				Token::MINUS_RIGHT_ANGLE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Imply, this.yes()))
				}
				Token::PERCENT => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Modulo, this.yes()))
				}
				Token::PERCENT_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Modulo, this.yes()))
				}
				Token::PIPE_PIPE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Or, this.yes()))
				}
				Token::PIPE_PIPE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseOr, this.yes()))
				}
				Token::PIPE_PIPE_PIPE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseOr, this.yes()))
				}
				Token::PLUS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Addition, this.yes()))
				}
				Token::PLUS_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Addition, this.yes()))
				}
				Token::QUESTION_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Existential, this.yes()))
				}
				Token::QUESTION_QUESTION => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::NullCoalescing, this.yes()))
				}
				Token::QUESTION_QUESTION_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::NullCoalescing, this.yes()))
				}
				Token::RIGHT_ANGLE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::GreaterThan, this.yes()))
				}
				Token::RIGHT_ANGLE_EQUALS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::GreaterThanOrEqual, this.yes()))
				}
				Token::RIGHT_ANGLE_RIGHT_ANGLE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseRightShift, this.yes()))
				}
				Token::RIGHT_ANGLE_RIGHT_ANGLE_RIGHT_ANGLE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseRightShift, this.yes()))
				}
				Token::SLASH => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Division, this.yes()))
				}
				Token::SLASH_DOT => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Quotient, this.yes()))
				}
				Token::SLASH_DOT_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Quotient, this.yes()))
				}
				Token::SLASH_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Division, this.yes()))
				}
				Token::TILDE_TILDE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Match, this.yes()))
				}
				=> {
					return NO
				}
			}
		} # }}}
		tryBlock(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			try {
				return this.reqBlock(NO, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryClassMember(attributes, modifiers, staticModifier: Event?, staticMark: Marker, finalModifier: Event?, finalMark: Marker, first: Event?) ~ SyntaxError { # {{{
			if staticModifier.ok {
				if finalModifier.ok {
					const member = @tryClassMember(
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

				const member = @tryClassMember(
					attributes
					[...modifiers, staticModifier]
					ClassBits::Variable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method + ClassBits::FinalMethod
					first ?? staticModifier
				)

				if member.ok {
					return member
				}

				@rollback(staticMark)
			}
			else if finalModifier.ok {
				const member = @tryClassMember(
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
				ClassBits::Variable + ClassBits::DynamicVariable + ClassBits::FinalVariable + ClassBits::LateVariable + ClassBits::Property + ClassBits::Method + ClassBits::OverrideMethod + ClassBits::AbstractMethod
				first
			)
		} # }}}
		tryClassMember(attributes, modifiers, bits: ClassBits, first: Event?): Event ~ SyntaxError { # {{{
			const mark = @mark()

			if bits ~~ ClassBits::Attribute {
				const attrs = @stackOuterAttributes([])
				if attrs.length != 0 {
					attributes = [...attributes, ...attrs]
					first ??= attrs[0]
				}
			}

			if bits ~~ ClassBits::Method {
				const mark = @mark()

				if bits ~~ ClassBits::AbstractMethod && @test(Token::ABSTRACT) {
					const modifier = @yep(AST.Modifier(ModifierKind::Abstract, @yes()))

					const method = @tryClassMethod(
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
					const modifier = @yep(AST.Modifier(ModifierKind::Immutable, @yes()))
					const mark2 = @mark()

					if bits ~~ ClassBits::OverrideMethod && @test(Token::OVERRIDE) {
						const modifier2 = @yep(AST.Modifier(ModifierKind::Override, @yes()))
						const method = @tryClassMethod(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

						if method.ok {
							return method
						}

						if bits ~~ ClassBits::OverrideProperty {
							const property = @tryClassProperty(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

							if property.ok {
								return property
							}
						}

						@rollback(mark2)
					}
					else if bits ~~ ClassBits::OverwriteMethod && @test(Token::OVERWRITE) {
						const modifier2 = @yep(AST.Modifier(ModifierKind::Overwrite, @yes()))
						const method = @tryClassMethod(attributes, [...modifiers, modifier, modifier2], bits, first ?? modifier)

						if method.ok {
							return method
						}

						@rollback(mark2)
					}

					const method = @tryClassMethod(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if method.ok {
						return method
					}

					@rollback(mark)
				}
				else if bits ~~ ClassBits::OverrideMethod && @test(Token::OVERRIDE) {
					const modifier = @yep(AST.Modifier(ModifierKind::Override, @yes()))

					const method = @tryClassMethod(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if method.ok {
						return method
					}

					if bits ~~ ClassBits::OverrideProperty {
						const property = @tryClassProperty(attributes, [...modifiers, modifier], bits, first ?? modifier)

						if property.ok {
							return property
						}
					}

					@rollback(mark)
				}
				else if bits ~~ ClassBits::OverwriteMethod && @test(Token::OVERWRITE) {
				}

				const method = @tryClassMethod(attributes, modifiers, bits, first)

				if method.ok {
					return method
				}

				@rollback(mark)
			}

			if bits ~~ ClassBits::Property {
				const mark = @mark()

				if bits ~~ ClassBits::OverrideProperty && @test(Token::OVERRIDE) {
					const modifier = @yep(AST.Modifier(ModifierKind::Override, @yes()))
					const property = @tryClassProperty(attributes, [...modifiers, modifier], bits, first ?? modifier)

					if property.ok {
						return property
					}

					@rollback(mark)
				}

				const property = @tryClassProperty(attributes, modifiers, bits, first)

				if property.ok {
					return property
				}

				@rollback(mark)
			}

			if bits ~~ ClassBits::Variable {
				const mark = @mark()

				if bits ~~ ClassBits::DynamicVariable && @test(Token::DYN) {
					const modifier = @yep(AST.Modifier(ModifierKind::Dynamic, @yes()))

					const variable = @tryClassVariable(attributes, [...modifiers, modifier], bits, null, null, first ?? modifier)

					if variable.ok {
						return variable
					}

					@rollback(mark)
				}
				else if bits ~~ ClassBits::FinalVariable && @test(Token::FINAL) {
					const modifier = @yep(AST.Modifier(ModifierKind::Immutable, @yes()))
					const mark2 = @mark()

					if bits ~~ ClassBits::LateVariable && @test(Token::LATE) {
						const modifier2 = @yep(AST.Modifier(ModifierKind::LateInit, @yes()))
						const method = @tryClassVariable(
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

					const variable = @tryClassVariable(
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
					const modifier = @yep(AST.Modifier(ModifierKind::LateInit, @yes()))
					const method = @tryClassVariable(
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

				const variable = @tryClassVariable(attributes, modifiers, bits, null, null, first)

				if variable.ok {
					return variable
				}
			}

			@rollback(mark)

			return NO
		} # }}}
		tryClassMethod(attributes, modifiers, bits: ClassBits, first: Event?): Event ~ SyntaxError { # {{{
			let name
			if @test(Token::ASYNC) {
				let modifier = @reqIdentifier()

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
		tryClassProperty(attributes, modifiers, bits: ClassBits, first: Event?): Event ~ SyntaxError { # {{{
			const mark = @mark()

			if @test(Token::AT) {
				const modifier = @yep(AST.Modifier(ModifierKind::ThisAlias, @yes()))

				modifiers = [...modifiers, modifier]
				first ??= modifier
			}

			const name = @tryIdentifier()

			unless name.ok {
				@rollback(mark)

				return NO
			}

			let type = NO
			if @test(Token::COLON) {
				@commit()

				type = @reqTypeVar()
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
		tryClassStatement(first: Event, modifiers = []): Event ~ SyntaxError { # {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			return this.reqClassStatementBody(name, first, modifiers)
		} # }}}
		tryClassVariable(attributes, modifiers, bits: ClassBits, name: Event?, type: Event?, first: Event?): Event ~ SyntaxError { # {{{
			const mark = @mark()

			if !?name {
				if @test(Token::AT) {
					const modifier = @yep(AST.Modifier(ModifierKind::ThisAlias, @yes()))

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

					type = @reqTypeVar()
				}
			}

			let value
			if bits ~~ ClassBits::NoAssignment {
				// do nothing
			}
			else if @test(Token::EQUALS) {
				@commit()

				value = @reqExpression(ExpressionMode::Default, FunctionMode::Method)
			}
			else if bits ~~ ClassBits::RequiredAssignment {
				@throw('=')
			}

			@reqNL_1M()

			return @yep(AST.FieldDeclaration(attributes, modifiers, name, type, value, first ?? name, value ?? type ?? name))
		} # }}}
		tryCreateExpression(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if this.test(Token::LEFT_ROUND) {
				this.commit()

				const class = this.reqExpression(ExpressionMode::Default, fMode)

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				this.commit()

				unless this.test(Token::LEFT_ROUND) {
					this.throw('(')
				}

				this.commit()

				return this.yep(AST.CreateExpression(class, this.reqExpression0CNList(fMode), first, this.yes()))
			}

			let class = this.tryVariableName(fMode)

			unless class.ok {
				return NO
			}

			if this.match(Token::LEFT_ANGLE, Token::LEFT_SQUARE) == Token::LEFT_ANGLE {
				const generic = this.reqTypeGeneric(this.yes())

				class = this.yep(AST.TypeReference([], class, generic, class, generic))
			}

			if this.test(Token::LEFT_ROUND) {
				this.commit()

				return this.yep(AST.CreateExpression(class, this.reqExpression0CNList(fMode), first, this.yes()))
			}
			else {
				return this.yep(AST.CreateExpression(class, this.yep([]), first, class))
			}
		} # }}}
		tryDestroyStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const variable = this.tryVariableName(fMode)

			if variable.ok {
				return this.yep(AST.DestroyStatement(variable, first, variable))
			}
			else {
				return NO
			}
		} # }}}
		tryDestructuring(fMode): Event ~ SyntaxError { # {{{
			if this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY {
				try {
					return this.reqDestructuringObject(this.yes(), DestructuringMode::Expression, fMode)
				}
			}
			else if @token == Token::LEFT_SQUARE {
				try {
					return this.reqDestructuringArray(this.yes(), DestructuringMode::Expression, fMode)
				}
			}

			return NO
		} # }}}
		tryDestructuringArray(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			lateinit const dMode: DestructuringMode

			if fMode == FunctionMode::Method {
				dMode = DestructuringMode::Expression ||| DestructuringMode::THIS_ALIAS
			}
			else {
				dMode = DestructuringMode::Expression
			}

			try {
				return this.reqDestructuringArray(first, dMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryDestructuringObject(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			lateinit const dMode: DestructuringMode

			if fMode == FunctionMode::Method {
				dMode = DestructuringMode::Expression ||| DestructuringMode::THIS_ALIAS
			}
			else {
				dMode = DestructuringMode::Expression
			}

			try {
				return this.reqDestructuringObject(first, dMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryEnumMethod(attributes, modifiers, first: Event?): Event ~ SyntaxError { # {{{
			let name
			if this.test(Token::ASYNC) {
				let first = this.reqIdentifier()

				name = this.tryIdentifier()

				if name.ok {
					modifiers = [...modifiers, this.yep(AST.Modifier(ModifierKind::Async, first))]
				}
				else {
					name = first
				}
			}
			else {
				name = this.tryIdentifier()

				unless name.ok {
					return NO
				}
			}

			return this.reqEnumMethod(attributes, modifiers, name, first ?? name)
		} # }}}
		tryExpression(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			try {
				return this.reqExpression(eMode, fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryExternDeclarator(mode: ExternMode): Event ~ SyntaxError { # {{{
			try {
				return this.reqExternDeclarator(mode)
			}
			catch {
				return NO
			}
		} # }}}
		tryExternFunctionDeclaration(modifiers, first: Event): Event ~ SyntaxError { # {{{
			try {
				return this.reqExternFunctionDeclaration(modifiers, first)
			}
			catch {
				return NO
			}
		} # }}}
		tryFunctionBody(fMode: FunctionMode): Event? ~ SyntaxError { # {{{
			const mark = this.mark()

			this.NL_0M()

			if this.test(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) {
				return this.reqFunctionBody(fMode)
			}
			else {
				this.rollback(mark)

				return null
			}
		} # }}}
		tryFunctionExpression(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if eMode ~~ ExpressionMode::NoAnonymousFunction {
				return NO
			}

			if this.match(Token::ASYNC, Token::FUNC, Token::LEFT_ROUND, Token::IDENTIFIER) == Token::ASYNC {
				const first = this.yes()
				const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, first))]

				if this.test(Token::FUNC) {
					this.commit()

					const parameters = this.reqFunctionParameterList(FunctionMode::Function)
					const type = this.tryFunctionReturns()
					const throws = this.tryFunctionThrows()
					const body = this.reqFunctionBody(FunctionMode::Function)

					return this.yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, first, body))
				}
				else {
					const parameters = this.tryFunctionParameterList(fMode)
					if !parameters.ok {
						return NO
					}

					const type = this.tryFunctionReturns()
					const throws = this.tryFunctionThrows()
					const body = this.reqFunctionBody(fMode)

					return this.yep(AST.LambdaExpression(parameters, modifiers, type, throws, body, first, body))
				}
			}
			else if @token == Token::FUNC {
				const first = this.yes()

				const parameters = this.tryFunctionParameterList(FunctionMode::Function)
				if !parameters.ok {
					return NO
				}

				const type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()
				const body = this.reqFunctionBody(FunctionMode::Function)

				return this.yep(AST.FunctionExpression(parameters, null, type, throws, body, first, body))
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.tryFunctionParameterList(fMode)
				const type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()

				if !parameters.ok || !this.test(Token::EQUALS_RIGHT_ANGLE) {
					return NO
				}

				this.commit()

				if this.test(Token::LEFT_CURLY) {
					const body = this.reqBlock(NO, fMode)

					return this.yep(AST.LambdaExpression(parameters, null, type, throws, body, parameters, body))
				}
				else {
					const body = this.reqExpression(eMode ||| ExpressionMode::NoObject, fMode)

					return this.yep(AST.LambdaExpression(parameters, null, type, throws, body, parameters, body))
				}
			}
			else if @token == Token::IDENTIFIER {
				const name = this.reqIdentifier()

				unless this.test(Token::EQUALS_RIGHT_ANGLE) {
					return NO
				}

				this.commit()

				const parameters = this.yep([this.yep(AST.Parameter(name))], name, name)

				if this.test(Token::LEFT_CURLY) {
					const body = this.reqBlock(NO, fMode)

					return this.yep(AST.LambdaExpression(parameters, null, null, null, body, parameters, body))
				}
				else {
					const body = this.reqExpression(eMode ||| ExpressionMode::NoObject, fMode)

					return this.yep(AST.LambdaExpression(parameters, null, null, null, body, parameters, body))
				}
			}
			else {
				return NO
			}
		} # }}}
		tryFunctionParameterList(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless this.test(Token::LEFT_ROUND) {
				return NO
			}

			const first = this.yes()

			const parameters = []

			unless this.test(Token::RIGHT_ROUND) {
				try {
					while this.reqParameter(parameters, DestructuringMode::Parameter, fMode) {
					}
				}
				catch {
					return NO
				}

				unless this.test(Token::RIGHT_ROUND) {
					return NO
				}
			}

			return this.yep(parameters, first, this.yes())
		} # }}}
		tryFunctionReturns(isAllowingAuto: Boolean = true): Event? ~ SyntaxError { # {{{
			const mark = this.mark()

			this.NL_0M()

			if this.test(Token::COLON) {
				this.commit()

				const mark = this.mark()

				if @scanner.test(Token::IDENTIFIER) {
					const value = @scanner.value()

					if value == 'this' || (!isAllowingAuto && value == 'auto') {
						throw @error(`The return type "\(value)" can't be used`)
					}
					else if value == 'auto' {
						const identifier = this.yep(AST.Identifier(@scanner.value(), this.yes()))

						return this.yep(AST.ReturnTypeReference(identifier))
					}
					else {
						this.rollback(mark)

						return this.reqTypeVar()
					}
				}
				else {
					return this.reqTypeVar()
				}
			}
			else {
				this.rollback(mark)

				return null
			}
		} # }}}
		tryFunctionThrows(): Event? ~ SyntaxError { # {{{
			const mark = this.mark()

			this.NL_0M()

			if this.test(Token::TILDE) {
				this.commit()

				const exceptions = [this.reqIdentifier()]

				while this.test(Token::COMMA) {
					this.commit()

					exceptions.push(this.reqIdentifier())
				}

				return this.yep(exceptions)
			}
			else {
				this.rollback(mark)

				return null
			}
		} # }}}
		tryIdentifier(): Event ~ SyntaxError { # {{{
			if @scanner.test(Token::IDENTIFIER) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				return NO
			}
		} # }}}
		tryJunctionOperator(): Event ~ SyntaxError { # {{{
			switch this.matchM(M.JUNCTION_OPERATOR) {
				Token::AMPERSAND => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::And, this.yes()))
				}
				Token::CARET => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Xor, this.yes()))
				}
				Token::PIPE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Or, this.yes()))
				}
				=> {
					return NO
				}
			}
		} # }}}
		tryMacroStatement(first: Event): Event ~ SyntaxError { # {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			const parameters = this.reqMacroParameterList()

			const body = this.reqMacroBody()

			return this.yep(AST.MacroDeclaration([], name, parameters, body, first, body))
		} # }}}
		tryMethodReturns(isAllowingAuto: Boolean = true): Event? ~ SyntaxError { # {{{
			const mark = this.mark()

			this.NL_0M()

			if this.test(Token::COLON) {
				this.commit()

				const mark = this.mark()

				if @scanner.test(Token::IDENTIFIER) {
					const value = @scanner.value()

					if !isAllowingAuto && value == 'auto' {
						throw @error(`The return type "auto" can't be used`)
					}
					else if value == 'this' || value == 'auto' {
						const identifier = this.yep(AST.Identifier(@scanner.value(), this.yes()))

						return this.yep(AST.ReturnTypeReference(identifier))
					}
					else {
						this.rollback(mark)

						return this.reqTypeVar()
					}
				}
				else if this.test(Token::AT) {
					const alias = this.reqThisExpression(this.yes())

					return this.yep(AST.ReturnTypeReference(alias))
				}
				else {
					return this.reqTypeVar()
				}
			}
			else {
				this.rollback(mark)

				return null
			}
		} # }}}
		tryNameIST(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if this.match(Token::IDENTIFIER, Token::STRING, Token::TEMPLATE_BEGIN) == Token::IDENTIFIER {
				return this.reqIdentifier()
			}
			else if @token == Token::STRING {
				return this.reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return this.reqTemplateExpression(this.yes(), fMode)
			}
			else {
				return NO
			}
		} # }}}
		tryNamespaceStatement(first: Event): Event ~ SyntaxError { # {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			return this.reqNamespaceStatement(first, name)
		} # }}}
		tryNumber(): Event ~ SyntaxError { # {{{
			if this.matchM(M.NUMBER) == Token::BINARY_NUMBER {
				return this.yep(AST.NumericExpression(parseInt(@scanner.value().slice(2).replace(/\_/g, ''), 2), this.yes()))
			}
			else if @token == Token::OCTAL_NUMBER {
				const radix = 8

				const number = @scanner.value().slice(2).replace(/\_/g, '').split('p')
				const literals = number[0].split('.')

				let value = parseInt(literals[0], radix)
				if literals.length > 1 {
					const floating = literals[1]
					let power = 1

					for const i from 0 til floating.length {
						power *= radix

						value += parseInt(floating[i], radix) / power
					}
				}

				if number.length > 1 && number[1] != '0' {
					value *= Math.pow(2, parseInt(number[1]))
				}

				return this.yep(AST.NumericExpression(value, this.yes()))
			}
			else if @token == Token::HEX_NUMBER {
				const radix = 16

				const number = @scanner.value().slice(2).replace(/\_/g, '').split('p')
				const literals = number[0].split('.')

				let value = parseInt(literals[0], radix)
				if literals.length > 1 {
					const floating = literals[1]
					let power = 1

					for const i from 0 til floating.length {
						power *= radix

						value += parseInt(floating[i], radix) / power
					}
				}

				if number.length > 1 && number[1] != '0' {
					value *= Math.pow(2, parseInt(number[1]))
				}

				return this.yep(AST.NumericExpression(value, this.yes()))
			}
			else if @token == Token::RADIX_NUMBER {
				const data = /^(\d+)r(.*)$/.exec(@scanner.value())

				return this.yep(AST.NumericExpression(parseInt(data[2]!?.replace(/\_/g, ''), parseInt(data[1])), this.yes()))
			}
			else if @token == Token::DECIMAL_NUMBER {
				return this.yep(AST.NumericExpression(parseFloat(@scanner.value().replace(/\_/g, ''), 10), this.yes()))
			}
			else {
				return NO
			}
		} # }}}
		tryOperand(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			if this.matchM(M.OPERAND) == Token::AT && fMode == FunctionMode::Method {
				return this.reqThisExpression(this.yes())
			}
			else if @token == Token::IDENTIFIER {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else if @token == Token::LEFT_CURLY {
				return this.reqObject(this.yes(), fMode)
			}
			else if @token == Token::LEFT_ROUND {
				return this.reqParenthesis(this.yes(), fMode)
			}
			else if @token == Token::LEFT_SQUARE {
				return this.reqArray(this.yes(), fMode)
			}
			else if @token == Token::NEW {
				const first = this.yep(AST.Identifier(@scanner.value(), this.yes()))

				const operand = this.tryCreateExpression(first, fMode)
				if operand.ok {
					return operand
				}
				else {
					return first
				}
			}
			else if @token == Token::REGEXP {
				return this.yep(AST.RegularExpression(@scanner.value(), this.yes()))
			}
			else if @token == Token::STRING {
				return this.yep(AST.Literal(this.value(), this.yes()))
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return this.reqTemplateExpression(this.yes(), fMode)
			}
			else {
				return this.tryNumber()
			}
		} # }}}
		tryRangeOperand(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const operand = this.tryOperand(eMode, fMode)
			if !operand.ok {
				return NO
			}

			return this.reqPostfixedOperand(operand, eMode, fMode)
		} # }}}
		trySwitchExpression(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless this.test(Token::SWITCH) {
				return NO
			}

			const first = this.yes()

			const expression = this.reqOperation(eMode, fMode)
			const clauses = this.reqSwitchCaseList(fMode)

			return this.yep(AST.SwitchExpression(expression, clauses, first, clauses))
		} # }}}
		tryTryExpression(eMode: ExpressionMode, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			unless this.test(Token::TRY) {
				return NO
			}

			try {
				return this.reqTryExpression(this.yes(), fMode)
			}
			catch {
				return NO
			}
		} # }}}
		tryTypeOperator(): Event ~ SyntaxError { # {{{
			switch this.matchM(M.TYPE_OPERATOR) {
				Token::AS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::TypeCasting, this.yes()))
				}
				Token::AS_EXCLAMATION => {
					const position = this.yes()

					return this.yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Forced, position)], BinaryOperatorKind::TypeCasting, position))
				}
				Token::AS_QUESTION => {
					const position = this.yes()

					return this.yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Nullable, position)], BinaryOperatorKind::TypeCasting, position))
				}
				Token::IS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::TypeEquality, this.yes()))
				}
				Token::IS_NOT => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::TypeInequality, this.yes()))
				}
				=> {
					return NO
				}
			}
		} # }}}
		tryTypeStatement(first: Event): Event ~ SyntaxError { # {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			return this.reqTypeStatement(first, name)
		} # }}}
		tryUntilStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			const condition = this.tryExpression(ExpressionMode::Default, fMode)

			unless condition.ok {
				return NO
			}

			let body
			if this.match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				body = this.reqBlock(this.yes(), fMode)
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				this.commit()

				body = this.reqExpression(ExpressionMode::Default, fMode)
			}
			else {
				this.throw(['{', '=>'])
			}

			return this.yep(AST.UntilStatement(condition, body, first, body))
		} # }}}
		tryVariable(): Event ~ SyntaxError { # {{{
			const name = this.tryIdentifier()

			if name.ok {
				return this.yep(AST.VariableDeclarator([], name, null, name, name))
			}
			else {
				return NO
			}
		} # }}}
		tryVariableName(fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let object
			if fMode == FunctionMode::Method && this.test(Token::AT) {
				object = this.reqThisExpression(this.yes())
			}
			else {
				object = this.tryIdentifier()

				unless object.ok {
					return NO
				}
			}

			return this.reqVariableName(object, fMode)
		} # }}}}
		tryWhileStatement(first: Event, fMode: FunctionMode): Event ~ SyntaxError { # {{{
			let condition

			if @test(Token::VAR) {
				const mark = @mark()
				const first = @yes()

				const modifiers = []
				if @test(Token::MUT) {
					modifiers.push(AST.Modifier(ModifierKind::Mutable, @yes()))
				}

				if @test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					const variable = @reqTypedVariable(fMode)

					if @test(Token::COMMA) {
						const variables = [variable]

						do {
							@commit()

							variables.push(@reqTypedVariable(fMode))
						}
						while @test(Token::COMMA)

						unless @test(Token::EQUALS) {
							@throw('=')
						}

						@commit()

						unless @test(Token::AWAIT) {
							@throw('await')
						}

						@commit()

						const operand = @reqPrefixedOperand(ExpressionMode::Default, fMode)

						condition = @yep(AST.VariableDeclaration(modifiers, variables, operand, first, operand))
					}
					else {
						unless @test(Token::EQUALS) {
							@throw('=')
						}

						@commit()

						const expression = @reqExpression(ExpressionMode::Default, fMode)

						condition = @yep(AST.VariableDeclaration(modifiers, [variable], expression, first, expression))
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

			let body
			if @match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				body = @reqBlock(@yes(), fMode)
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				@commit()

				body = @reqExpression(ExpressionMode::Default, fMode)
			}
			else {
				@throw(['{', '=>'])
			}

			return @yep(AST.WhileStatement(condition, body, first, body))
		} # }}}
	}

	export func parse(data: String) ~ SyntaxError { # {{{
		const parser = new Parser(data)

		return parser.reqModule()
	} # }}}
}

export Parser.parse
