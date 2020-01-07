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

		'./ast'
		'./scanner'
	}

	#[flags]
	enum DestructuringMode {
		Nil

		COMPUTED
		DEFAULT
		RECURSION
		THIS_ALIAS
		TYPE

		Declaration	= COMPUTED | DEFAULT | RECURSION | TYPE
		Expression	= COMPUTED | DEFAULT | RECURSION
		Function	= DEFAULT | RECURSION | TYPE
		Method		= DEFAULT | RECURSION | TYPE | THIS_ALIAS
	}

	#[flags]
	enum ExpressionMode {
		Default
		NoAnonymousFunction
		NoAwait
		NoObject
		WithMacro
	}

	#[flags]
	enum MacroTerminator {
		Nil

		COMMA
		NEWLINE
		RIGHT_CURLY
		RIGHT_ROUND
		RIGHT_SQUARE

		Array				= COMMA | NEWLINE | RIGHT_SQUARE
		List				= COMMA | NEWLINE | RIGHT_ROUND
		Object				= COMMA | NEWLINE | RIGHT_CURLY
		Parenthesis			= NEWLINE | RIGHT_ROUND
	}

	enum ParameterMode {
		Function
		Macro
		Method
	}

	#[flags]
	enum ParserMode {
		Default
		MacroExpression
	}

	struct Event {
		ok: Boolean
		value?			= null
		start?			= null
		end?			= null
	}

	const NO = Event(ok: false)

	class Parser {
		private {
			_history: Array		= []
			_mode: Number		= ParserMode::Default
			_scanner: Scanner
			_token
		}
		constructor(data: String) ~ SyntaxError { // {{{
			@scanner = new Scanner(data)
		} // }}}
		commit() { // {{{
			@token = @scanner.commit()

			return this
		} // }}}
		mark() => @scanner.mark()
		match(...tokens): Token => @token = @scanner.match(...tokens)
		matchM(matcher: Function): Token => @token = @scanner.matchM(matcher)
		position() => @scanner.position()
		relocate(node, first?, last?) { // {{{
			if first != null {
				node.start = node.value.start = first.start
			}

			if last != null {
				node.end = node.value.end = last.end
			}

			return node
		} // }}}
		rollback(mark): Boolean { // {{{
			@token = mark.token

			return @scanner.rollback(mark)
		} // }}}
		skipNewLine() { // {{{
			if @scanner.skipNewLine() == -1 {
				@token = Token::EOF
			}
			else {
				@token = Token::INVALID
			}
		} // }}}
		test(token): Boolean { // {{{
			if @scanner.test(token) {
				@token = token

				return true
			}
			else {
				return false
			}
		} // }}}
		test(...tokens): Boolean => tokens.indexOf(this.match(...tokens)) != -1
		testNS(token): Boolean { // {{{
			if @scanner.testNS(token) {
				@token = token

				return true
			}
			else {
				return false
			}
		} // }}}
		throw(): Never ~ SyntaxError { // {{{
			throw new SyntaxError(`Unexpected \(@scanner.toQuote()) at line \(@scanner.line()) and column \(@scanner.column())`)
		} // }}}
		throw(expected: String): Never ~ SyntaxError { // {{{
			throw new SyntaxError(`Expecting "\(expected)" but got \(@scanner.toQuote()) at line \(@scanner.line()) and column \(@scanner.column())`)
		} // }}}
		throw(expecteds: Array): Never ~ SyntaxError { // {{{
			throw new SyntaxError(`Expecting "\(expecteds.slice(0, expecteds.length - 1).join('", "'))" or "\(expecteds[expecteds.length - 1])" but got \(@scanner.toQuote()) at line \(@scanner.line()) and column \(@scanner.column())`)
		} // }}}
		until(token): Boolean => !@scanner.test(token) && !@scanner.isEOF()
		value() => @scanner.value(@token)
		yep(): Event { // {{{
			const position = @scanner.position()

			return Event(
				ok: true
				start: position.start
				end: position.end
			)
		} // }}}
		yep(value): Event { // {{{
			return Event(
				ok: true
				value: value
				start: value.start
				end: value.end
			)
		} // }}}
		yep(value, first, last): Event { // {{{
			return Event(
				ok: true
				value: value
				start: first.start
				end: last.end
			)
		} // }}}
		yes(): Event { // {{{
			const position = @scanner.position()

			this.commit()

			return Event(
				ok: true
				start: position.start
				end: position.end
			)
		} // }}}
		yes(value): Event { // {{{
			const start = value.start ?? @scanner.startPosition()
			const end = value.end ?? @scanner.endPosition()

			this.commit()

			return Event(
				ok: true
				value: value
				start: start
				end: end
			)
		} // }}}
		NL_0M() ~ SyntaxError { // {{{
			this.skipNewLine()
		} // }}}
		altArrayComprehension(expression, first) ~ SyntaxError { // {{{
			const loop = this.reqForExpression(this.yes())

			this.NL_0M()

			unless this.test(Token::RIGHT_SQUARE) {
				this.throw(']')
			}

			return this.yep(AST.ArrayComprehension(expression, loop, first, this.yes()))
		} // }}}
		altArrayList(expression, first) ~ SyntaxError { // {{{
			const values = [expression]

			while this.match(Token::RIGHT_SQUARE, Token::COMMA, Token::NEWLINE) != null {
				if @token == Token::RIGHT_SQUARE {
					return this.yep(AST.ArrayExpression(values, first, this.yes()))
				}
				else if @token == Token::COMMA {
					this.commit().NL_0M()

					values.push(this.reqExpression(null, MacroTerminator::Array))
				}
				else if @token == Token::NEWLINE {
					this.commit().NL_0M()

					if this.match(Token::RIGHT_SQUARE, Token::COMMA) == Token::COMMA {
						this.commit().NL_0M()

						values.push(this.reqExpression(null, MacroTerminator::Array))
					}
					else if @token == Token::RIGHT_SQUARE {
						return this.yep(AST.ArrayExpression(values, first, this.yes()))
					}
					else {
						values.push(this.reqExpression(null, MacroTerminator::Array))
					}
				}
				else {
					this.throw(']')
				}
			}
		} // }}}
		altForExpressionFrom(modifiers, variable, first) ~ SyntaxError { // {{{
			const from = this.reqExpression(ExpressionMode::Default)

			let til, to
			if this.match(Token::TIL, Token::TO) == Token::TIL {
				this.commit()

				til = this.reqExpression(ExpressionMode::Default)
			}
			else if @token == Token::TO {
				this.commit()

				to = this.reqExpression(ExpressionMode::Default)
			}
			else {
				this.throw(['til', 'to'])
			}

			let by
			if this.test(Token::BY) {
				this.commit()

				by = this.reqExpression(ExpressionMode::Default)
			}

			let until, while
			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				until = this.reqExpression(ExpressionMode::Default)
			}
			else if @token == Token::WHILE {
				this.commit()

				while = this.reqExpression(ExpressionMode::Default)
			}

			this.NL_0M()

			let whenExp
			if this.test(Token::WHEN) {
				const first = this.yes()

				whenExp = this.relocate(this.reqExpression(ExpressionMode::Default), first, null)
			}

			return this.yep(AST.ForFromStatement(modifiers, variable, from, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? from))
		} // }}}
		altForExpressionIn(modifiers, value, type, index, expression, first) ~ SyntaxError { // {{{
			let desc = null
			if this.test(Token::DESC) {
				desc = this.yes()

				modifiers.push(AST.Modifier(ModifierKind::Descending, desc))
			}

			this.NL_0M()

			let from, til, to, by
			if this.test(Token::FROM) {
				this.commit()

				from = this.reqExpression(ExpressionMode::Default)
			}
			if this.match(Token::TIL, Token::TO) == Token::TIL {
				this.commit()

				til = this.reqExpression(ExpressionMode::Default)
			}
			else if @token == Token::TO {
				this.commit()

				to = this.reqExpression(ExpressionMode::Default)
			}
			if this.test(Token::BY) {
				this.commit()

				by = this.reqExpression(ExpressionMode::Default)
			}

			this.NL_0M()

			let until, while
			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				until = this.reqExpression(ExpressionMode::Default)
			}
			else if @token == Token::WHILE {
				this.commit()

				while = this.reqExpression(ExpressionMode::Default)
			}

			this.NL_0M()

			let whenExp
			if this.test(Token::WHEN) {
				const first = this.yes()

				whenExp = this.relocate(this.reqExpression(ExpressionMode::Default), first, null)
			}

			return this.yep(AST.ForInStatement(modifiers, value, type, index, expression, from, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? from ?? desc ?? expression))
		} // }}}
		altForExpressionInRange(modifiers, value, type, index, first) ~ SyntaxError { // {{{
			let operand = this.tryRangeOperand(ExpressionMode::Default)

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

					const toOperand = this.reqPrefixedOperand(ExpressionMode::Default)

					let byOperand
					if this.test(Token::DOT_DOT) {
						this.commit()

						byOperand = this.reqPrefixedOperand(ExpressionMode::Default)
					}

					return this.altForExpressionRange(modifiers, value, index, then ? null : operand, then ? operand : null, til ? toOperand : null, til ? null : toOperand, byOperand, first)
				}
				else {
					return this.altForExpressionIn(modifiers, value, type, index, operand, first)
				}
			}
			else {
				return this.altForExpressionIn(modifiers, value, type, index, this.reqExpression(ExpressionMode::Default), first)
			}
		} // }}}
		altForExpressionOf(modifiers, value, type, key, first) ~ SyntaxError { // {{{
			const expression = this.reqExpression(ExpressionMode::Default)

			let until, while
			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				until = this.reqExpression(ExpressionMode::Default)
			}
			else if @token == Token::WHILE {
				this.commit()

				while = this.reqExpression(ExpressionMode::Default)
			}

			this.NL_0M()

			let whenExp
			if this.test(Token::WHEN) {
				const first = this.yes()

				whenExp = this.relocate(this.reqExpression(ExpressionMode::Default), first, null)
			}

			return this.yep(AST.ForOfStatement(modifiers, value, type, key, expression, until, while, whenExp, first, whenExp ?? while ?? until ?? expression))
		} // }}}
		altForExpressionRange(modifiers, value, index, from?, then?, til?, to?, by?, first) ~ SyntaxError { // {{{
			let until, while
			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				until = this.reqExpression(ExpressionMode::Default)
			}
			else if @token == Token::WHILE {
				this.commit()

				while = this.reqExpression(ExpressionMode::Default)
			}

			this.NL_0M()

			let whenExp
			if this.test(Token::WHEN) {
				const first = this.yes()

				whenExp = this.relocate(this.reqExpression(ExpressionMode::Default), first, null)
			}

			return this.yep(AST.ForRangeStatement(modifiers, value, index, from, then, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? then ?? from:Any))
		} // }}}
		reqAccessModifiers(modifiers: Array): Array ~ SyntaxError { // {{{
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
		} // }}}
		reqArray(first) ~ SyntaxError { // {{{
			if this.test(Token::RIGHT_SQUARE) {
				return this.yep(AST.ArrayExpression([], first, this.yes()))
			}

			const mark = this.mark()

			let operand = this.tryRangeOperand(ExpressionMode::Default)

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

				const toOperand = this.reqPrefixedOperand(ExpressionMode::Default)

				let byOperand
				if this.test(Token::DOT_DOT) {
					this.commit()

					byOperand = this.reqPrefixedOperand(ExpressionMode::Default)
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

				const expression = this.reqExpression(null, MacroTerminator::Array)

				if this.match(Token::RIGHT_SQUARE, Token::FOR, Token::NEWLINE) == Token::RIGHT_SQUARE {
					return this.yep(AST.ArrayExpression([expression], first, this.yes()))
				}
				else if @token == Token::FOR {
					return this.altArrayComprehension(expression, first)
				}
				else if @token == Token::NEWLINE {
					const mark = this.mark()

					this.commit().NL_0M()

					if this.match(Token::RIGHT_SQUARE, Token::FOR) == Token::RIGHT_SQUARE {
						return this.yep(AST.ArrayExpression([expression], first, this.yes()))
					}
					else if @token == Token::FOR {
						return this.altArrayComprehension(expression, first)
					}
					else {
						this.rollback(mark)

						return this.altArrayList(expression, first)
					}
				}
				else {
					return this.altArrayList(expression, first)
				}
			}
		} // }}}
		reqAttribute(first) ~ SyntaxError { // {{{
			const declaration = this.reqAttributeMember()

			unless this.test(Token::RIGHT_SQUARE) {
				this.throw(']')
			}

			const last = this.yes()

			unless this.test(Token::NEWLINE) {
				this.throw('NewLine')
			}

			this.commit()

			@token = @scanner.skipComments()

			return this.yep(AST.AttributeDeclaration(declaration, first, last))
		} // }}}
		reqAttributeIdentifier() ~ SyntaxError { // {{{
			if @scanner.test(Token::ATTRIBUTE_IDENTIFIER) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				this.throw('Identifier')
			}
		} // }}}
		reqAttributeMember() ~ SyntaxError { // {{{
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
		} // }}}
		reqAutoStatement(first, mode = ExpressionMode::Default) ~ SyntaxError { // {{{
			const variable = this.tryVariable()

			unless variable.ok {
				return NO
			}

			const modifiers = [AST.Modifier(ModifierKind::AutoTyping, first)]

			if this.test(Token::COMMA) {
				const variables = [variable]

				do {
					this.commit()

					variables.push(this.reqVariable())
				}
				while this.test(Token::COMMA)

				unless this.test(Token::EQUALS) {
					this.throw('=')
				}

				this.commit().NL_0M()

				unless this.test(Token::AWAIT) {
					this.throw('await')
				}

				this.commit()

				let operand = this.reqPrefixedOperand(mode)

				operand = this.yep(AST.AwaitExpression([], variables, operand, variable, operand))

				return this.yep(AST.VariableDeclaration(modifiers, variables, operand, first, operand))
			}
			else if this.test(Token::EQUALS) {
				this.commit().NL_0M()

				let init = this.reqExpression(mode)

				if this.match(Token::IF, Token::UNLESS) == Token::IF {
					const first = this.yes()
					const condition = this.reqExpression(ExpressionMode::Default)

					if this.test(Token::ELSE) {
						this.commit()

						const whenFalse = this.reqExpression(ExpressionMode::Default)

						init = this.yep(AST.IfExpression(condition, init, whenFalse, init, whenFalse))
					}
					else {
						init = this.yep(AST.IfExpression(condition, init, null, init, condition))
					}
				}
				else if @token == Token::UNLESS {
					this.commit()

					const condition = this.reqExpression(ExpressionMode::Default)

					init = this.yep(AST.UnlessExpression(condition, init, init, condition))
				}

				return this.yep(AST.VariableDeclaration(modifiers, [variable], init, first, init))
			}
			else {
				this.throw('=')
			}
		} // }}}
		reqAwaitExpression(first) ~ SyntaxError { // {{{
			const operand = this.reqPrefixedOperand(ExpressionMode::Default)

			return this.yep(AST.AwaitExpression([], null, operand, first, operand))
		} // }}}
		reqBinaryOperand(mode) ~ SyntaxError { // {{{
			const mark = this.mark()

			let expression
			if (expression = this.tryAwaitExpression(mode)).ok {
				return expression
			}
			else if this.rollback(mark) && (expression = this.tryFunctionExpression(mode)).ok {
				return expression
			}
			else if this.rollback(mark) && (expression = this.trySwitchExpression(mode)).ok {
				return expression
			}
			else if this.rollback(mark) && (expression = this.tryTryExpression(mode)).ok {
				return expression
			}

			this.rollback(mark)

			const operand = this.reqPrefixedOperand(mode)

			let operator
			switch this.matchM(M.TYPE_OPERATOR) {
				Token::AS => {
					operator = this.yep(AST.BinaryOperator(BinaryOperatorKind::TypeCasting, this.yes()))
				}
				Token::AS_EXCLAMATION => {
					const position = this.yes()

					operator = this.yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Forced, position)], BinaryOperatorKind::TypeCasting, position))
				}
				Token::AS_QUESTION => {
					const position = this.yes()

					operator = this.yep(AST.BinaryOperator([AST.Modifier(ModifierKind::Nullable, position)], BinaryOperatorKind::TypeCasting, position))
				}
				Token::IS => {
					operator = this.yep(AST.BinaryOperator(BinaryOperatorKind::TypeEquality, this.yes()))
				}
				Token::IS_NOT => {
					operator = this.yep(AST.BinaryOperator(BinaryOperatorKind::TypeInequality, this.yes()))
				}
				=> {
					return operand
				}
			}

			return this.yep(AST.BinaryExpression(operand, operator, this.reqTypeEntity(NO)))
		} // }}}
		reqBlock(first = NO) ~ SyntaxError { // {{{
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

				statement = this.reqStatement()

				if attrs.length > 0 {
					statement.value.attributes.unshift(...attrs)
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
		} // }}}
		reqBreakStatement(first) { // {{{
			return this.yep(AST.BreakStatement(first))
		} // }}}
		reqCatchOnClause(first) ~ SyntaxError { // {{{
			const type = this.reqIdentifier()

			let binding
			if this.test(Token::CATCH) {
				this.commit()

				binding = this.reqIdentifier()
			}

			this.NL_0M()

			const body = this.reqBlock()

			return this.yep(AST.CatchClause(binding, type, body, first, body))
		} // }}}
		reqClassAbstractMethod(attributes, modifiers, first?) ~ SyntaxError { // {{{
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

			return this.reqClassAbstractMethodBody(attributes, modifiers, name, first ?? name)
		} // }}}
		reqClassAbstractMethodBody(attributes, modifiers, name, first) ~ SyntaxError { // {{{
			const parameters = this.reqClassMethodParameterList()
			const type = this.tryMethodReturns(false)
			const throws = this.tryFunctionThrows()

			this.reqNL_1M()

			return this.yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, null, first, throws ?? type ?? parameters))
		} // }}}
		reqClassMember(attributes, modifiers, first?) ~ SyntaxError { // {{{
			const member = this.tryClassMember(attributes, modifiers, first)

			unless member.ok {
				this.throw(['Identifier', 'String', 'Template'])
			}

			return member
		} // }}}
		reqClassMemberList(members) ~ SyntaxError { // {{{
			let first = null

			const attributes = this.stackOuterAttributes([])
			if attributes.length != 0 {
				first = attributes[0]
			}

			const mark1 = this.mark()

			if this.test(Token::MACRO) {
				first = this.yes()

				if this.test(Token::LEFT_CURLY) {
					this.commit().NL_0M()

					while this.until(Token::RIGHT_CURLY) {
						members.push(this.reqMacroStatement(attributes))
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					this.commit().reqNL_1M()

					return
				}
				else if (identifier = this.tryIdentifier()).ok {
					members.push(this.reqMacroStatement(attributes, identifier, first))

					return
				}

				this.rollback(mark1)
				first = null
			}

			const modifiers = this.reqAccessModifiers([])

			if this.test(Token::FINAL) {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Final, this.yes())))
			}

			const mark2 = this.mark()

			if this.test(Token::ABSTRACT) {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Abstract, this.yes())))

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

						members.push(this.reqClassAbstractMethod(attrs, modifiers, first))
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					this.commit().reqNL_1M()
				}
				else {
					const member = this.tryClassAbstractMethod(attributes, modifiers, first ?? modifiers[0])

					if member.ok {
						members.push(member)
					}
					else {
						this.rollback(mark2)

						modifiers.pop()

						members.push(this.reqClassMember(attributes, modifiers, first ?? modifiers[0]))
					}
				}
			}
			else if this.test(Token::OVERRIDE) {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Override, this.yes())))

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

						members.push(this.reqClassMethod(attrs, modifiers, first))
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					this.commit().reqNL_1M()
				}
				else {
					const member = this.tryClassMethod(attributes, modifiers, first ?? modifiers[0])

					if member.ok {
						members.push(member)
					}
					else {
						this.rollback(mark2)

						modifiers.pop()

						members.push(this.reqClassMember(attributes, modifiers, first ?? modifiers[0]))
					}
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

						members.push(this.reqClassMember(attrs, modifiers, first))
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					this.commit().reqNL_1M()
				}
				else {
					const member = this.tryClassMember(attributes, modifiers, first)

					if member.ok {
						members.push(member)
					}
					else {
						if modifiers.length == 2 {
							this.rollback(mark2)
						}
						else {
							this.rollback(mark1)
						}

						modifiers.pop()

						members.push(this.reqClassMember(attributes, modifiers, first))
					}
				}
			}
		} // }}}
		reqClassMethod(attributes, modifiers, first?) ~ SyntaxError { // {{{
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

			return this.reqClassMethod(attributes, modifiers, name, null, first ?? name)
		} // }}}
		reqClassMethod(attributes, modifiers, name, round?, first) ~ SyntaxError { // {{{
			const parameters = this.reqClassMethodParameterList(round)

			const type = this.tryMethodReturns()
			const throws = this.tryFunctionThrows()
			const body = this.tryFunctionBody()

			this.reqNL_1M()

			return this.yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, body, first, body ?? throws ?? type ?? parameters))

		} // }}}
		reqClassMethodParameterList(top = NO) ~ SyntaxError { // {{{
			if !top.ok {
				unless this.test(Token::LEFT_ROUND) {
					this.throw('(')
				}

				top = this.yes()
			}

			const parameters = []

			while this.until(Token::RIGHT_ROUND) {
				while this.reqParameter(parameters, ParameterMode::Method) {
				}
			}

			unless this.test(Token::RIGHT_ROUND) {
				this.throw(')')
			}

			return this.yep(parameters, top, this.yes())
		} // }}}
		reqClassProperty(attributes, modifiers, name, type?, first) ~ SyntaxError { // {{{
			let defaultValue, accessor, mutator
			if this.test(Token::NEWLINE) {
				this.commit().NL_0M()

				if this.match(Token::GET, Token::SET) == Token::GET {
					const first = this.yes()

					if this.match(Token::EQUALS_RIGHT_ANGLE, Token::LEFT_CURLY) == Token::EQUALS_RIGHT_ANGLE {
						this.commit()

						const expression = this.reqExpression(ExpressionMode::Default)

						accessor = this.yep(AST.AccessorDeclaration(expression, first, expression))
					}
					else if @token == Token::LEFT_CURLY {
						const block = this.reqBlock()

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

							const expression = this.reqExpression(ExpressionMode::Default)

							mutator = this.yep(AST.MutatorDeclaration(expression, first, expression))
						}
						else if @token == Token::LEFT_CURLY {
							const block = this.reqBlock()

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

						const expression = this.reqExpression(ExpressionMode::Default)

						mutator = this.yep(AST.MutatorDeclaration(expression, first, expression))
					}
					else if @token == Token::LEFT_CURLY {
						const block = this.reqBlock()

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

				defaultValue = this.reqExpression(ExpressionMode::Default)
			}

			this.reqNL_1M()

			return this.yep(AST.PropertyDeclaration(attributes, modifiers, name, type, defaultValue, accessor, mutator, first, defaultValue ?? last))
		} // }}}
		reqClassStatement(first, modifiers = []) ~ SyntaxError { // {{{
			return this.reqClassStatementBody(this.reqIdentifier(), first, modifiers)
		} // }}}
		reqClassStatementBody(name, first, modifiers = []) ~ SyntaxError { // {{{
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
		} // }}}
		reqComputedPropertyName(first) ~ SyntaxError { // {{{
			const expression = this.reqExpression(ExpressionMode::Default)

			unless this.test(Token::RIGHT_SQUARE) {
				this.throw(']')
			}

			return this.yep(AST.ComputedPropertyName(expression, first, this.yes()))
		} // }}}
		reqConstStatement(first, mode = ExpressionMode::Default) ~ SyntaxError { // {{{
			const variable = this.reqTypedVariable()
			const modifiers = [AST.Modifier(ModifierKind::Immutable, first)]

			if this.test(Token::COMMA) {
				const variables = [variable]

				do {
					this.commit()

					variables.push(this.reqTypedVariable())
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

				let operand = this.reqPrefixedOperand(mode)

				operand = this.yep(AST.AwaitExpression([], variables, operand, variable, operand))

				return this.yep(AST.VariableDeclaration(modifiers, variables, operand, first, operand))
			}
			else {
				unless this.test(Token::EQUALS) {
					this.throw('=')
				}

				this.commit()

				const expression = this.reqExpression(mode)

				return this.yep(AST.VariableDeclaration(modifiers, [variable], expression, first, expression))
			}
		} // }}}
		reqContinueStatement(first) { // {{{
			return this.yep(AST.ContinueStatement(first))
		} // }}}
		reqCreateExpression(first) ~ SyntaxError { // {{{
			if this.test(Token::LEFT_ROUND) {
				this.commit()

				const class = this.reqExpression(ExpressionMode::Default)

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				this.commit()

				unless this.test(Token::LEFT_ROUND) {
					this.throw('(')
				}

				this.commit()

				return this.yep(AST.CreateExpression(class, this.reqExpression0CNList(), first, this.yes()))
			}

			let class = this.reqVariableName()

			if this.match(Token::LEFT_ANGLE, Token::LEFT_SQUARE) == Token::LEFT_ANGLE {
				const generic = this.reqTypeGeneric(this.yes())

				class = this.yep(AST.TypeReference([], class, generic, class, generic))
			}

			if this.test(Token::LEFT_ROUND) {
				this.commit()

				return this.yep(AST.CreateExpression(class, this.reqExpression0CNList(), first, this.yes()))
			}
			else {
				return this.yep(AST.CreateExpression(class, this.yep([]), first, class))
			}
		} // }}}
		reqDestructuringArray(first, mode = DestructuringMode::Nil) ~ SyntaxError { // {{{
			this.NL_0M()

			const elements = []

			while true {
				elements.push(this.reqDestructuringArrayItem(mode))

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
		} // }}}
		reqDestructuringArrayItem(mode) ~ SyntaxError { // {{{
			const modifiers = []
			let first = null
			let name = null
			let type = null

			if this.test(Token::DOT_DOT_DOT) {
				modifiers.push(AST.Modifier(ModifierKind::Rest, first = this.yes()))

				if mode & DestructuringMode::THIS_ALIAS != 0 && this.test(Token::AT) {
					modifiers.push(AST.Modifier(ModifierKind::ThisAlias, this.yes()))

					name = this.reqIdentifier()
				}
				else if this.test(Token::IDENTIFIER) {
					name = this.yep(AST.Identifier(@scanner.value(), this.yes()))
				}
			}
			else if mode & DestructuringMode::RECURSION != 0 && this.test(Token::LEFT_CURLY) {
				name = this.reqDestructuringObject(this.yes(), mode)
			}
			else if mode & DestructuringMode::RECURSION != 0 && this.test(Token::LEFT_SQUARE) {
				name = this.reqDestructuringArray(this.yes(), mode)
			}
			else if mode & DestructuringMode::THIS_ALIAS != 0 && this.test(Token::AT) {
				modifiers.push(AST.Modifier(ModifierKind::ThisAlias, this.yes()))

				name = this.reqIdentifier()
			}
			else if this.test(Token::IDENTIFIER) {
				name = this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else if this.test(Token::UNDERSCORE) {
				first = this.yes()
			}
			else {
				if mode & DestructuringMode::RECURSION != 0 {
					this.throw(['...', '_', '[', '{', 'Identifier'])
				}
				else {
					this.throw(['...', '_', 'Identifier'])
				}
			}

			if mode & DestructuringMode::TYPE != 0 && this.test(Token::COLON) {
				this.commit()

				type = this.reqTypeVar()
			}

			if name != null {
				let defaultValue = null

				if mode & DestructuringMode::DEFAULT != 0 && this.test(Token::EQUALS) {
					this.commit()

					defaultValue = this.reqExpression(ExpressionMode::Default)
				}

				return this.yep(AST.ArrayBindingElement(modifiers, name, type, defaultValue, first ?? name, defaultValue ?? type ?? name))
			}
			else {
				return this.yep(AST.ArrayBindingElement(modifiers, null, type, null, first ?? type ?? this.yep(), type ?? first ?? this.yep()))
			}
		} // }}}
		reqDestructuringObject(first, mode = DestructuringMode::Nil) ~ SyntaxError { // {{{
			this.NL_0M()

			const elements = []

			while true {
				elements.push(this.reqDestructuringObjectItem(mode))

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
		} // }}}
		reqDestructuringObjectItem(mode) ~ SyntaxError { // {{{
			let first
			const modifiers = []
			let name = null
			let alias = null
			let defaultValue = null

			if this.test(Token::DOT_DOT_DOT) {
				modifiers.push(AST.Modifier(ModifierKind::Rest, first = this.yes()))

				if mode & DestructuringMode::THIS_ALIAS != 0 && this.test(Token::AT) {
					modifiers.push(AST.Modifier(ModifierKind::ThisAlias, this.yes()))
				}

				name = this.reqIdentifier()
			}
			else {
				if mode & DestructuringMode::COMPUTED != 0 && this.test(Token::LEFT_SQUARE) {
					const first = this.yes()

					if mode & DestructuringMode::THIS_ALIAS != 0 && this.test(Token::AT) {
						modifiers.push(AST.Modifier(ModifierKind::ThisAlias, this.yes()))
					}

					name = this.reqIdentifier()

					unless this.test(Token::RIGHT_SQUARE) {
						this.throw(']')
					}

					modifiers.push(AST.Modifier(ModifierKind::Computed, first, this.yes()))
				}
				else {
					if mode & DestructuringMode::THIS_ALIAS != 0 && this.test(Token::AT) {
						modifiers.push(AST.Modifier(ModifierKind::ThisAlias, this.yes()))
					}

					name = this.reqIdentifier()
				}

				if this.test(Token::COLON) {
					this.commit()

					if mode & DestructuringMode::RECURSION != 0 && this.test(Token::LEFT_CURLY) {
						alias = this.reqDestructuringObject(this.yes(), mode)
					}
					else if mode & DestructuringMode::RECURSION != 0 && this.test(Token::LEFT_SQUARE) {
						alias = this.reqDestructuringArray(this.yes(), mode)
					}
					else {
						if mode & DestructuringMode::THIS_ALIAS != 0 && this.test(Token::AT) {
							modifiers.push(AST.Modifier(ModifierKind::ThisAlias, this.yes()))
						}

						alias = this.reqIdentifier()
					}
				}
			}

			if mode & DestructuringMode::DEFAULT != 0 && this.test(Token::EQUALS) {
				this.commit()

				defaultValue = this.reqExpression(ExpressionMode::Default)
			}

			return this.yep(AST.ObjectBindingElement(modifiers, name, alias, defaultValue, first ?? name, defaultValue ?? alias ?? name))
		} // }}}
		reqDiscloseStatement(first) ~ SyntaxError { // {{{
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
		} // }}}
		reqDoStatement(first) ~ SyntaxError { // {{{
			this.NL_0M()

			const body = this.reqBlock()

			this.reqNL_1M()

			if this.match(Token::UNTIL, Token::WHILE) == Token::UNTIL {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default)

				return this.yep(AST.DoUntilStatement(condition, body, first, condition))
			}
			else if @token == Token::WHILE {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default)

				return this.yep(AST.DoWhileStatement(condition, body, first, condition))
			}
			else {
				this.throw(['until', 'while'])
			}
		} // }}}
		reqEnumStatement(first) ~ SyntaxError { // {{{
			const name = this.reqIdentifier()

			let type
			if this.test(Token::LEFT_ANGLE) {
				this.commit()

				type = this.reqTypeEntity(NO)

				unless this.test(Token::RIGHT_ANGLE) {
					this.throw('>')
				}

				this.commit()
			}

			unless this.test(Token::LEFT_CURLY) {
				this.throw('{')
			}

			this.commit()

			this.NL_0M()

			const members = []

			let identifier
			until this.test(Token::RIGHT_CURLY) {
				identifier = this.reqIdentifier()

				if this.test(Token::EQUALS) {
					this.commit()

					members.push(AST.EnumMember(identifier, this.reqExpression(ExpressionMode::Default)))
				}
				else {
					members.push(AST.EnumMember(identifier))
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

			return this.yep(AST.EnumDeclaration(name, type, members, first, this.yes()))
		} // }}}
		reqExportDeclarator() ~ SyntaxError { // {{{
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
				Token::AUTO => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqAutoStatement(this.yes(), ExpressionMode::NoAwait)))
				}
				Token::CLASS => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqClassStatement(this.yes())))
				}
				Token::CONST => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqConstStatement(this.yes(), ExpressionMode::NoAwait)))
				}
				Token::ENUM => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqEnumStatement(this.yes())))
				}
				Token::FINAL => {
					const first = this.yes()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Final, first))]

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
				Token::FUNC => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqFunctionStatement(this.yes())))
				}
				Token::IDENTIFIER => {
					return this.reqExportIdentifier(this.reqIdentifier())
				}
				Token::LET => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqLetStatement(this.yes(), ExpressionMode::NoAwait)))
				}
				Token::MACRO => {
					if @mode & ParserMode::MacroExpression == 0 {
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
				Token::TYPE => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqTypeStatement(this.yes(), this.reqIdentifier())))
				}
				=> {
					this.throw()
				}
			}
		} // }}}
		reqExportIdentifier(value) ~ SyntaxError { // {{{
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
		} // }}}
		reqExportStatement(first) ~ SyntaxError { // {{{
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

						declarator.value.declaration.attributes.unshift(...attrs)
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
		} // }}}
		reqExpression(mode?, terminator = null) ~ SyntaxError { // {{{
			if mode == null {
				if @mode & ParserMode::MacroExpression != 0 &&
					@scanner.test(Token::IDENTIFIER) &&
					@scanner.value() == 'macro'
				{
					return this.reqMacroExpression(this.yes(), terminator)
				}
				else {
					mode = ExpressionMode::Default
				}
			}

			return this.reqOperation(mode)
		} // }}}
		reqExpression0CNList() ~ SyntaxError { // {{{
			this.NL_0M()

			if this.test(Token::RIGHT_ROUND) {
				return this.yep([])
			}
			else {
				const expressions = []

				while true {
					const expression = this.reqExpression(null, MacroTerminator::List)

					if expression.value.kind == NodeKind::Identifier {
						if this.test(Token::COLON) {
							this.commit()

							const value = this.reqExpression(null, MacroTerminator::List)

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
		} // }}}
		reqExpressionStatement() ~ SyntaxError { // {{{
			const expression = this.reqExpression(ExpressionMode::Default)

			if this.match(Token::FOR, Token::IF, Token::UNLESS) == Token::FOR {
				const statement = this.reqForExpression(this.yes())

				statement.value.body = expression.value

				this.relocate(statement, expression, null)

				return statement
			}
			else if @token == Token::IF {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default)

				return this.yep(AST.IfStatement(condition, expression, null, expression, condition))
			}
			else if @token == Token::UNLESS {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default)

				return this.yep(AST.UnlessStatement(condition, expression, expression, condition))
			}
			else {
				return this.yep(AST.ExpressionStatement(expression))
			}
		} // }}}
		reqExternClassDeclaration(first, modifiers = []) ~ SyntaxError { // {{{
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
		} // }}}
		reqExternClassField(attributes, modifiers, name, type?, first) ~ SyntaxError { // {{{
			this.reqNL_1M()

			return this.yep(AST.FieldDeclaration(attributes, modifiers, name, type, null, first, type ?? name))
		} // }}}
		reqExternClassMember(attributes, modifiers, first?) ~ SyntaxError { // {{{
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
		} // }}}
		reqExternClassMemberList(members) ~ SyntaxError { // {{{
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

						members.push(this.reqClassAbstractMethod(attrs, modifiers, first))
					}

					unless this.test(Token::RIGHT_CURLY) {
						this.throw('}')
					}

					this.commit().reqNL_1M()
				}
				else {
					members.push(this.reqClassAbstractMethod(attributes, modifiers, first))
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
		} // }}}
		reqExternClassMethod(attributes, modifiers, name, round, first) ~ SyntaxError { // {{{
			const parameters = this.reqClassMethodParameterList(round)
			const type = this.tryMethodReturns(false)

			this.reqNL_1M()

			return this.yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, null, null, first, type ?? parameters))
		} // }}}
		reqExternDeclarator(ns = false) ~ SyntaxError { // {{{
			switch this.matchM(M.EXTERN_STATEMENT) {
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

						return this.reqExternFunctionDeclaration(first, modifiers)
					}
					else {
						const fn = this.tryExternFunctionDeclaration(first, modifiers)
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
				Token::CONST where ns => {
					const first = this.yes()
					const name = this.reqIdentifier()
					const modifiers = [AST.Modifier(ModifierKind::Immutable, first)]

					if this.test(Token::COLON) {
						this.commit()

						const type = this.reqTypeVar()

						return this.yep(AST.VariableDeclarator(modifiers, name, type, first, type))
					}
					else {
						return this.yep(AST.VariableDeclarator(modifiers, name, null, first, name))
					}
				}
				Token::ENUM => {
					return this.reqExternEnumDeclaration(this.yes())
				}
				Token::FINAL => {
					const first = this.yes()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Final, first))]

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
					return this.reqExternFunctionDeclaration(first, [])
				}
				Token::IDENTIFIER => {
					return this.reqExternVariableDeclarator(this.reqIdentifier())
				}
				Token::NAMESPACE => {
					return this.reqExternNamespaceDeclaration(this.yes(), [])
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

						return this.reqExternNamespaceDeclaration(sealed, [sealed])
					}
					else {
						this.throw(['class', 'namespace'])
					}
				}
				Token::STRUCT => {
					return this.reqStructStatement(this.yes())
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

						return this.reqExternNamespaceDeclaration(systemic, [systemic])
					}
					else {
						this.throw(['class', 'namespace'])
					}
				}
				Token::LET where ns => {
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
		} // }}}
		reqExternEnumDeclaration(first) ~ SyntaxError { // {{{
			const name = this.reqIdentifier()

			let type
			if this.test(Token::LEFT_ANGLE) {
				this.commit()

				type = this.reqTypeEntity(NO)

				unless this.test(Token::RIGHT_ANGLE) {
					this.throw('>')
				}

				this.commit()
			}

			unless this.test(Token::LEFT_CURLY) {
				this.throw('{')
			}

			this.commit()

			this.NL_0M()

			const members = []

			until this.test(Token::RIGHT_CURLY) {
				members.push(AST.EnumMember(this.reqIdentifier()))

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

			return this.yep(AST.EnumDeclaration(name, type, members, first, this.yes()))
		} // }}}
		reqExternFunctionDeclaration(first, modifiers) ~ SyntaxError { // {{{
			const name = this.reqIdentifier()

			if this.test(Token::LEFT_ROUND) {
				const parameters = this.reqFunctionParameterList()
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
		} // }}}
		reqExternNamespaceDeclaration(first, modifiers = []) ~ SyntaxError { // {{{
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

					statement = this.reqExternDeclarator(true)

					this.reqNL_1M()

					if attrs.length > 0 {
						statement.value.attributes.unshift(...attrs)
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
		} // }}}
		reqExternOrImportStatement(first) ~ SyntaxError { // {{{
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
						declarator.value.attributes.unshift(...attrs)
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
		} // }}}
		reqExternOrRequireStatement(first) ~ SyntaxError { // {{{
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

					declarator = this.reqExternDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...attrs)
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
				declarations.push(this.reqExternDeclarator())

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqExternDeclarator())
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.ExternOrRequireDeclaration(attributes, declarations, first, last))
		} // }}}
		reqExternStatement(first) ~ SyntaxError { // {{{
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

					declarator = this.reqExternDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...attrs)
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
				declarations.push(this.reqExternDeclarator())

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqExternDeclarator())
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.ExternDeclaration(attributes, declarations, first, last))
		} // }}}
		reqExternVariableDeclarator(name) ~ SyntaxError { // {{{
			if this.match(Token::COLON, Token::LEFT_ROUND) == Token::COLON {
				this.commit()

				const type = this.reqTypeVar()

				return this.yep(AST.VariableDeclarator([], name, type, name, type))
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.reqFunctionParameterList()
				const type = this.tryFunctionReturns(false)

				return this.yep(AST.FunctionDeclaration(name, parameters, [], type, null, null, name, type ?? parameters))
			}
			else {
				return this.yep(AST.VariableDeclarator([], name, null, name, name))
			}
		} // }}}
		reqFallthroughStatement(first) { // {{{
			return this.yep(AST.FallthroughStatement(first))
		} // }}}
		reqForExpression(first) ~ SyntaxError { // {{{
			const modifiers = []

			if this.test(Token::LET) {
				modifiers.push(AST.Modifier(ModifierKind::Declarative, this.yes()))
			}
			else if this.test(Token::CONST) {
				const position = this.yes()

				modifiers.push(AST.Modifier(ModifierKind::Declarative, position), AST.Modifier(ModifierKind::Immutable, position))
			}
			else if this.test(Token::AUTO) {
				const position = this.yes()

				modifiers.push(AST.Modifier(ModifierKind::Declarative, position), AST.Modifier(ModifierKind::AutoTyping, position))
			}

			let identifier1 = NO
			let type1 = NO
			let identifier2 = NO
			let destructuring = NO

			if this.test(Token::UNDERSCORE) {
				this.commit()
			}
			else if !(destructuring = this.tryDestructuring()).ok {
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

					return this.altForExpressionIn(modifiers, destructuring, type1, identifier2, this.reqExpression(ExpressionMode::Default), first)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(modifiers, destructuring, type1, identifier2, first)
				}
				else {
					this.throw(['in', 'of'])
				}
			}
			else if identifier2.ok {
				if this.match(Token::IN, Token::OF) == Token::IN {
					this.commit()

					return this.altForExpressionInRange(modifiers, identifier1, type1, identifier2, first)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(modifiers, identifier1, type1, identifier2, first)
				}
				else {
					this.throw(['in', 'of'])
				}
			}
			else {
				if this.match(Token::FROM, Token::IN, Token::OF) == Token::FROM {
					this.commit()

					return this.altForExpressionFrom(modifiers, identifier1, first)
				}
				else if @token == Token::IN {
					this.commit()

					return this.altForExpressionInRange(modifiers, identifier1, type1, identifier2, first)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(modifiers, identifier1, type1, identifier2, first)
				}
				else {
					this.throw(['from', 'in', 'of'])
				}
			}
		} // }}}
		reqForStatement(first) ~ SyntaxError { // {{{
			const statement = this.reqForExpression(first)

			this.NL_0M()

			const block = this.reqBlock()

			statement.value.body = block.value
			this.relocate(statement, null, block)

			return statement
		} // }}}
		reqFunctionBody() ~ SyntaxError { // {{{
			this.NL_0M()

			if this.match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				return this.reqBlock(this.yes())
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				this.commit().NL_0M()

				const expression = this.reqExpression(ExpressionMode::Default)

				if this.match(Token::IF, Token::UNLESS) == Token::IF {
					this.commit()

					const condition = this.reqExpression(ExpressionMode::Default)

					if this.match(Token::ELSE, Token::NEWLINE) == Token::ELSE {
						this.commit()

						const whenFalse = this.reqExpression(ExpressionMode::Default)

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

					const condition = this.reqExpression(ExpressionMode::Default)

					return this.yep(AST.UnlessStatement(condition, this.yep(AST.ReturnStatement(expression, expression, expression)), expression, condition))
				}
				else {
					return expression
				}
			}
			else {
				this.throw(['{', '=>'])
			}
		} // }}}
		reqFunctionParameterList() ~ SyntaxError { // {{{
			unless this.test(Token::LEFT_ROUND) {
				this.throw('(')
			}

			const first = this.yes()

			const parameters = []

			unless this.test(Token::RIGHT_ROUND) {
				while this.reqParameter(parameters, ParameterMode::Function) {
				}

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}
			}

			return this.yep(parameters, first, this.yes())
		} // }}}
		reqFunctionStatement(first, modifiers = []) ~ SyntaxError { // {{{
			const name = this.reqIdentifier()
			const parameters = this.reqFunctionParameterList()
			const type = this.tryFunctionReturns()
			const throws = this.tryFunctionThrows()
			const body = this.reqFunctionBody()

			return this.yep(AST.FunctionDeclaration(name, parameters, modifiers, type, throws, body, first, body))
		} // }}}
		reqIdentifier(): Event ~ SyntaxError { // {{{
			if @scanner.test(Token::IDENTIFIER) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				this.throw('Identifier')
			}
		} // }}}
		reqIfStatement(first) ~ SyntaxError { // {{{
			let condition
			if this.test(Token::LET, Token::CONST, Token::AUTO) {
				const token = @token

				const mark = this.mark()
				const first = this.yes()

				const modifiers = []
				if token == Token::CONST {
					modifiers.push(AST.Modifier(ModifierKind::Immutable, first))
				}
				else if token == Token::AUTO {
					modifiers.push(AST.Modifier(ModifierKind::AutoTyping, first))
				}

				if this.test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					const variable = this.reqTypedVariable()

					if this.test(Token::COMMA) {
						const variables = [variable]

						do {
							this.commit()

							variables.push(this.reqTypedVariable())
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

						const operand = this.reqPrefixedOperand(ExpressionMode::Default)

						condition = this.yep(AST.VariableDeclaration(modifiers, variables, operand, first, operand))
					}
					else {
						unless this.test(Token::EQUALS) {
							this.throw('=')
						}

						this.commit()

						const expression = this.reqExpression(ExpressionMode::Default)

						condition = this.yep(AST.VariableDeclaration(modifiers, [variable], expression, first, expression))
					}
				}
				else {
					this.rollback(mark)

					condition = this.reqExpression(ExpressionMode::NoAnonymousFunction)
				}
			}
			else {
				this.NL_0M()

				condition = this.reqExpression(ExpressionMode::NoAnonymousFunction)
			}

			this.NL_0M()

			const whenTrue = this.reqBlock()

			if this.test(Token::NEWLINE) {
				const mark = this.mark()

				this.commit().NL_0M()

				if this.match(Token::ELSE_IF, Token::ELSE) == Token::ELSE_IF {
					const position = this.yes()

					position.start.column += 5

					const whenFalse = this.reqIfStatement(position)

					return this.yep(AST.IfStatement(condition, whenTrue, whenFalse, first, whenFalse))
				}
				else if @token == Token::ELSE {
					this.commit().NL_0M()

					const whenFalse = this.reqBlock()

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
		} // }}}
		reqImplementMemberList(members) ~ SyntaxError { // {{{
			let first = null

			const attributes = this.stackOuterAttributes([])

			let mark = this.mark()

			const modifiers = this.reqAccessModifiers([])

			if this.match(Token::OVERRIDE, Token::OVERWRITE, Token::STATIC) == Token::OVERRIDE {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Override, this.yes())))

				mark = this.mark() if modifiers.length > 1
			}
			else if @token == Token::OVERWRITE {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Overwrite, this.yes())))

				mark = this.mark() if modifiers.length > 1
			}
			else if @token == Token::STATIC {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Static, this.yes())))

				mark = this.mark() if modifiers.length > 1
			}

			if modifiers.length != 0 {
				first = modifiers[0]
			}

			if this.test(Token::LEFT_CURLY) {
				this.commit()

				this.NL_0M()

				let attrs
				until this.test(Token::RIGHT_CURLY) {
					attrs = this.stackOuterAttributes([])

					if attrs.length > 0 {
						first = attrs[0]
						attrs.unshift(...attributes)
					}

					members.push(this.reqClassMember(attrs, modifiers, first))
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				this.commit()

				this.reqNL_1M()
			}
			else {
				const member = this.tryClassMember(attributes, modifiers, first)

				if member.ok {
					members.push(member)
				}
				else {
					this.rollback(mark)

					modifiers.pop()

					members.push(this.reqClassMember(attributes, modifiers, first))
				}
			}
		} // }}}
		reqImplementStatement(first) ~ SyntaxError { // {{{
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
		} // }}}
		reqImportDeclarator() ~ SyntaxError { // {{{
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
					let name = this.reqExpression(ExpressionMode::Default)
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

								const value = this.reqExpression(ExpressionMode::Default)

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
					imported = this.reqExternDeclarator()

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
		} // }}}
		reqImportSpecifiers(attributes, specifiers) ~ SyntaxError { // {{{
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
					imported = this.reqExternDeclarator()

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
					specifier.value.attributes.unshift(...attrs)
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
		} // }}}
		reqImportStatement(first) ~ SyntaxError { // {{{
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
						declarator.value.attributes.unshift(...attrs)
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
		} // }}}
		reqIncludeDeclarator() ~ SyntaxError { // {{{
			unless this.test(Token::STRING) {
				this.throw('String')
			}

			const file = this.yes(this.value())

			return this.yep(AST.IncludeDeclarator(file))
		} // }}}
		reqIncludeStatement(first) ~ SyntaxError { // {{{
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
						declarator.value.attributes.unshift(...attrs)
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
		} // }}}
		reqIncludeAgainStatement(first) ~ SyntaxError { // {{{
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
						declarator.value.attributes.unshift(...attrs)
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
		} // }}}
		reqLateInitStatement(first) ~ SyntaxError { // {{{
			const modifiers = [AST.Modifier(ModifierKind::LateInit, first)]
			const variables = []

			if this.match(Token::AUTO, Token::CONST, Token::LET) == Token::AUTO {
				modifiers.push(AST.Modifier(ModifierKind::AutoTyping, this.yes()))

				variables.push(last = this.reqVariable())

				while this.test(Token::COMMA) {
					this.commit()

					variables.push(last = this.reqVariable())
				}

				return this.yep(AST.VariableDeclaration(modifiers, variables, null, first, last))
			}
			else if @token == Token::CONST {
				modifiers.push(AST.Modifier(ModifierKind::Immutable, this.yes()))

				variables.push(last = this.reqTypedVariable())

				while this.test(Token::COMMA) {
					this.commit()

					variables.push(last = this.reqTypedVariable())
				}

				return this.yep(AST.VariableDeclaration(modifiers, variables, null, first, last))
			}
			else if @token == Token::LET {
				this.commit()

				variables.push(last = this.reqTypedVariable())

				while this.test(Token::COMMA) {
					this.commit()

					variables.push(last = this.reqTypedVariable())
				}

				return this.yep(AST.VariableDeclaration(modifiers, variables, null, first, last))
			}
			else {
				return NO
			}
		} // }}}
		reqLetStatement(first, mode = ExpressionMode::Default) ~ SyntaxError { // {{{
			const variable = this.reqTypedVariable()
			const modifiers = []

			if this.test(Token::COMMA) {
				const variables = [variable]

				do {
					this.commit()

					variables.push(this.reqTypedVariable())
				}
				while this.test(Token::COMMA)

				if this.test(Token::EQUALS) {
					this.commit().NL_0M()

					unless this.test(Token::AWAIT) {
						this.throw('await')
					}

					this.commit()

					let operand = this.reqPrefixedOperand(mode)

					operand = this.yep(AST.AwaitExpression([], variables, operand, variable, operand))

					return this.yep(AST.VariableDeclaration(modifiers, variables, operand, first, operand))
				}
				else {
					return this.yep(AST.VariableDeclaration(modifiers, variables, null, first, variables[variables.length - 1]))
				}
			}
			else {
				if this.test(Token::EQUALS) {
					this.commit().NL_0M()

					let init = this.reqExpression(mode)

					if this.match(Token::IF, Token::UNLESS) == Token::IF {
						const first = this.yes()
						const condition = this.reqExpression(ExpressionMode::Default)

						if this.test(Token::ELSE) {
							this.commit()

							const whenFalse = this.reqExpression(ExpressionMode::Default)

							init = this.yep(AST.IfExpression(condition, init, whenFalse, init, whenFalse))
						}
						else {
							init = this.yep(AST.IfExpression(condition, init, null, init, condition))
						}
					}
					else if @token == Token::UNLESS {
						this.commit()

						const condition = this.reqExpression(ExpressionMode::Default)

						init = this.yep(AST.UnlessExpression(condition, init, init, condition))
					}

					return this.yep(AST.VariableDeclaration(modifiers, [variable], init, first, init))
				}
				else {
					return this.yep(AST.VariableDeclaration(modifiers, [variable], null, first, variable))
				}
			}
		} // }}}
		reqMacroElements(elements, terminator) ~ SyntaxError { // {{{
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
						if history.length == 0 && terminator & MacroTerminator::NEWLINE == 0 {
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

								const expression = this.reqExpression(ExpressionMode::Default)

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

								const expression = this.reqExpression(ExpressionMode::Default)

								unless this.test(Token::COMMA) {
									this.throw(',')
								}

								this.commit()

								const separator = this.reqExpression(ExpressionMode::Default)

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

							const expression = this.reqExpression(ExpressionMode::Default)

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
						if history.length == 0 && terminator & MacroTerminator::NEWLINE != 0 {
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
							if terminator & MacroTerminator::RIGHT_CURLY == 0 {
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
							if terminator & MacroTerminator::RIGHT_ROUND == 0 {
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
		} // }}}
		reqMacroExpression(first, terminator = MacroTerminator::NEWLINE) ~ SyntaxError { // {{{
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
		} // }}}
		reqMacroParameterList() ~ SyntaxError { // {{{
			unless this.test(Token::LEFT_ROUND) {
				this.throw('(')
			}

			const first = this.yes()

			const parameters = []

			unless this.test(Token::RIGHT_ROUND) {
				while this.reqParameter(parameters, ParameterMode::Macro) {
				}

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}
			}

			return this.yep(parameters, first, this.yes())
		} // }}}
		reqMacroBody() ~ SyntaxError { // {{{
			if this.match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				@mode |= ParserMode::MacroExpression

				const body = this.reqBlock(this.yes())

				@mode ^= ParserMode::MacroExpression

				return body
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				return this.reqMacroExpression(this.yes())
			}
			else {
				this.throw(['{', '=>'])
			}
		} // }}}
		reqMacroStatement(attributes = []) ~ SyntaxError { // {{{
			const name = this.reqIdentifier()
			const parameters = this.reqMacroParameterList()

			const body = this.reqMacroBody()

			this.reqNL_1M()

			return this.yep(AST.MacroDeclaration(attributes, name, parameters, body, name, body))
		} // }}}
		reqMacroStatement(attributes = [], name, first) ~ SyntaxError { // {{{
			const parameters = this.reqMacroParameterList()

			const body = this.reqMacroBody()

			this.reqNL_1M()

			return this.yep(AST.MacroDeclaration(attributes, name, parameters, body, first, body))
		} // }}}
		reqModule() ~ SyntaxError { // {{{
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
						statement = this.reqStatement().value
					}
				}

				if attrs.length > 0 {
					statement.attributes.unshift(...attrs)
					statement.start = statement.attributes[0].start

					attrs = []
				}

				body.push(statement)

				this.NL_0M()
			}

			return AST.Module(attributes, body, this)
		} // }}}
		reqNameIST() ~ SyntaxError { // {{{
			if this.match(Token::IDENTIFIER, Token::STRING, Token::TEMPLATE_BEGIN) == Token::IDENTIFIER {
				return this.reqIdentifier()
			}
			else if @token == Token::STRING {
				return this.reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return this.reqTemplateExpression(this.yes())
			}
			else {
				this.throw(['Identifier', 'String', 'Template'])
			}
		} // }}}
		reqNamespaceStatement(first, name) ~ SyntaxError { // {{{
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
					statement = this.reqStatement()
				}

				if attrs.length > 0 {
					statement.value.attributes.unshift(...attrs)
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
		} // }}}
		reqNumber() ~ SyntaxError { // {{{
			if (value = this.tryNumber()).ok {
				return value
			}
			else {
				this.throw('Number')
			}
		} // }}}
		reqNumeralIdentifier() ~ SyntaxError { // {{{
			if this.test(Token::IDENTIFIER, Token::NUMERAL) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				this.throw('Identifier')
			}
		} // }}}
		reqNL_1M() ~ SyntaxError { // {{{
			if this.test(Token::NEWLINE) {
				this.commit()

				this.skipNewLine()
			}
			else {
				this.throw('NewLine')
			}
		} // }}}
		reqNL_EOF_1M() ~ SyntaxError { // {{{
			if this.match(Token::NEWLINE) == Token::NEWLINE {
				this.commit()

				this.skipNewLine()
			}
			else if @token != Token::EOF {
				this.throw(['NewLine', 'EOF'])
			}
		} // }}}
		reqObject(first) ~ SyntaxError { // {{{
			this.NL_0M()

			const attributes = []
			const properties = []

			until this.test(Token::RIGHT_CURLY) {
				if this.stackInnerAttributes(attributes) {
					continue
				}

				properties.push(this.reqObjectItem())

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
		} // }}}
		reqObjectItem() ~ SyntaxError { // {{{
			let first

			const attributes = this.stackOuterAttributes([])
			if attributes.length > 0 {
				first = attributes[0]
			}

			if this.test(Token::ASYNC) {
				const marker = this.mark()

				const async = this.yes()

				const name = this.tryNameIST()
				if name.ok {
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, async))]
					const parameters = this.reqFunctionParameterList()
					const type = this.tryFunctionReturns()
					const throws = this.tryFunctionThrows()
					const body = this.reqFunctionBody()

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
				name = this.reqComputedPropertyName(this.yes())
			}
			else if @token == Token::STRING {
				name = this.reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				name = this.reqTemplateExpression(this.yes())
			}
			else if @token == Token::AT {
				name = this.reqThisExpression(this.yes())

				return this.yep(AST.ShorthandProperty(attributes, name, first ?? name, name))
			}
			else if @token == Token::DOT_DOT_DOT {
				const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Spread, this.yes()))
				const operand = this.reqPrefixedOperand(ExpressionMode::Default)

				return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
			}
			else {
				this.throw(['Identifier', 'String', 'Template', 'Computed Property Name'])
			}

			if this.test(Token::COLON) {
				this.commit()

				const value = this.reqExpression(null, MacroTerminator::Object)

				return this.yep(AST.ObjectMember(attributes, name, value, first ?? name, value))
			}
			else if this.test(Token::LEFT_ROUND) {
				const parameters = this.reqFunctionParameterList()
				const type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()
				const body = this.reqFunctionBody()

				return this.yep(AST.ObjectMember(attributes, name, this.yep(AST.FunctionExpression(parameters, null, type, throws, body, parameters, body)), first ?? name, body))
			}
			else {
				return this.yep(AST.ShorthandProperty(attributes, name, first ?? name, name))
			}
		} // }}}
		reqOperand(mode) ~ SyntaxError { // {{{
			if (value = this.tryOperand(mode)).ok {
				return value
			}
			else {
				this.throw()
			}
		} // }}}
		reqOperation(mode) ~ SyntaxError { // {{{
			let mark = this.mark()

			let operand, operator

			if (operand = this.tryDestructuring()).ok {
				this.NL_0M()

				if (operator = this.tryAssignementOperator()).ok {
					const values = [operand.value, AST.BinaryExpression(operator)]

					this.NL_0M()

					values.push(this.reqBinaryOperand(mode).value)

					return this.yep(AST.reorderExpression(values))
				}
			}

			this.rollback(mark)

			operand = this.reqBinaryOperand(mode)

			const values = [operand.value]

			while true {
				mark = this.mark()

				this.NL_0M()

				if (operator = this.tryBinaryOperator()).ok {
					values.push(AST.BinaryExpression(operator))

					this.NL_0M()

					values.push(this.reqBinaryOperand(mode).value)
				}
				else if this.test(Token::QUESTION) {
					values.push(AST.ConditionalExpression(this.yes()))

					values.push(this.reqExpression(ExpressionMode::Default).value)

					unless this.test(Token::COLON) {
						this.throw(':')
					}

					this.commit()

					values.push(this.reqExpression(ExpressionMode::Default).value)
				}
				else {
					this.rollback(mark)

					break
				}
			}

			if values.length == 1 {
				return operand
			}
			else {
				return this.yep(AST.reorderExpression(values))
			}
		} // }}}
		reqParameter(parameters, mode) ~ SyntaxError { // {{{
			const modifiers = []

			if this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY || @token == Token::LEFT_SQUARE {
				if mode == ParameterMode::Macro {
					this.throw()
				}

				const destructuringMode = mode & ParameterMode::Function != 0 ? DestructuringMode::Function : DestructuringMode::Method

				let name
				if @token == Token::LEFT_CURLY {
					name = this.reqDestructuringObject(this.yes(), destructuringMode)
				}
				else {
					name = this.reqDestructuringArray(this.yes(), destructuringMode)
				}

				if this.match(Token::COLON, Token::EQUALS) == Token::COLON {
					this.commit()

					const type = this.reqTypeVar()

					if this.test(Token::EQUALS) {
						this.commit()

						const defaultValue = this.reqExpression(ExpressionMode::Default)

						parameters.push(this.yep(AST.Parameter(name, type, modifiers, defaultValue, name, defaultValue)))
					}
					else {
						parameters.push(this.yep(AST.Parameter(name, type, modifiers, null, name, type)))
					}
				}
				else if @token == Token::EQUALS {
					this.commit()

					const defaultValue = this.reqExpression(ExpressionMode::Default)

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
				let first

				if mode == ParameterMode::Macro {
					modifiers.push(AST.Modifier(ModifierKind::AutoEvaluate, first = this.yes()))
				}
				else if mode == ParameterMode::Method {
					modifiers.push(AST.Modifier(ModifierKind::ThisAlias, first = this.yes()))
				}
				else {
					this.throw()
				}

				parameters.push(this.reqParameterIdendifier(modifiers, first))

				if mode == ParameterMode::Method && this.test(Token::LEFT_ROUND) {
					let first = this.yes()

					unless this.test(Token::RIGHT_ROUND) {
						this.throw(')')
					}

					modifiers.push(AST.Modifier(ModifierKind::SetterAlias, first, this.yes()))
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

				parameters.push(this.reqParameterIdendifier(modifiers, first))

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
		} // }}}
		reqParameterIdendifier(modifiers, first?) ~ SyntaxError { // {{{
			const identifier = this.reqIdentifier()

			if this.test(Token::EXCLAMATION) {
				modifiers.push(AST.Modifier(ModifierKind::Required, this.yes()))
			}

			if this.match(Token::COLON, Token::EQUALS, Token::QUESTION) == Token::COLON {
				this.commit()

				const type = this.reqTypeVar()

				if this.test(Token::EQUALS) {
					this.commit()

					const defaultValue = this.reqExpression(ExpressionMode::Default)

					return this.yep(AST.Parameter(identifier, type, modifiers, defaultValue, first ?? identifier, defaultValue))
				}
				else {
					return this.yep(AST.Parameter(identifier, type, modifiers, null, first ?? identifier, type))
				}
			}
			else if @token == Token::EQUALS {
				this.commit()

				const defaultValue = this.reqExpression(ExpressionMode::Default)

				return this.yep(AST.Parameter(identifier, null, modifiers, defaultValue, first ?? identifier, defaultValue))
			}
			else if @token == Token::QUESTION {
				const type = this.yep(AST.Nullable(this.yes()))

				if this.test(Token::EQUALS) {
					this.commit()

					const defaultValue = this.reqExpression(ExpressionMode::Default)

					return this.yep(AST.Parameter(identifier, type, modifiers, defaultValue, first ?? identifier, defaultValue))
				}
				else {
					return this.yep(AST.Parameter(identifier, type, modifiers, null, first ?? identifier, type))
				}
			}
			else {
				return this.yep(AST.Parameter(identifier, null, modifiers, null, first ?? identifier, identifier))
			}
		} // }}}
		reqParenthesis(first) ~ SyntaxError { // {{{
			if this.test(Token::NEWLINE) {
				this.commit().NL_0M()

				const expression = this.reqExpression(null, MacroTerminator::Parenthesis)

				this.NL_0M()

				unless this.test(Token::RIGHT_ROUND) {
					this.throw(')')
				}

				this.relocate(expression, first, this.yes())

				return expression
			}
			else {
				const expressions = [this.reqExpression(null, MacroTerminator::List)]

				while this.test(Token::COMMA) {
					this.commit()

					expressions.push(this.reqExpression(null, MacroTerminator::List))
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
		} // }}}
		reqPostfixedOperand(mode, operand = null) ~ SyntaxError { // {{{
			operand = this.reqUnaryOperand(mode, operand)

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

			return this.reqPostfixedOperand(mode, this.yep(AST.UnaryExpression(operator, operand, operand, operator)))
		} // }}}
		reqPrefixedOperand(mode) ~ SyntaxError { // {{{
			switch this.matchM(M.PREFIX_OPERATOR) {
				Token::DOT_DOT_DOT => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Spread, this.yes()))
					const operand = this.reqPrefixedOperand(mode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::EXCLAMATION => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Negation, this.yes()))
					const operand = this.reqPrefixedOperand(mode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::MINUS => {
					const first = this.yes()
					const operand = this.reqPrefixedOperand(mode)

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
					const operand = this.reqPrefixedOperand(mode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::PLUS_PLUS => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::IncrementPrefix, this.yes()))
					const operand = this.reqPrefixedOperand(mode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::QUESTION => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::Existential, this.yes()))
					const operand = this.reqPrefixedOperand(mode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				Token::TILDE => {
					const operator = this.yep(AST.UnaryOperator(UnaryOperatorKind::BitwiseNot, this.yes()))
					const operand = this.reqPrefixedOperand(mode)

					return this.yep(AST.UnaryExpression(operator, operand, operator, operand))
				}
				=> {
					return this.reqPostfixedOperand(mode)
				}
			}
		} // }}}
		reqRequireStatement(first) ~ SyntaxError { // {{{
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

					declarator = this.reqExternDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...attrs)
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
				declarations.push(this.reqExternDeclarator())

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqExternDeclarator())
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.RequireDeclaration(attributes, declarations, first, last))
		} // }}}
		reqRequireOrExternStatement(first) ~ SyntaxError { // {{{
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

					declarator = this.reqExternDeclarator()

					if attrs.length > 0 {
						declarator.value.attributes.unshift(...attrs)
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
				declarations.push(this.reqExternDeclarator())

				while this.test(Token::COMMA) {
					this.commit()

					declarations.push(this.reqExternDeclarator())
				}

				last = declarations[declarations.length - 1]
			}

			this.reqNL_EOF_1M()

			return this.yep(AST.RequireOrExternDeclaration(attributes, declarations, first, last))
		} // }}}
		reqRequireOrImportStatement(first) ~ SyntaxError { // {{{
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
						declarator.value.attributes.unshift(...attrs)
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
		} // }}}
		reqReturnStatement(first) ~ SyntaxError { // {{{
			if this.match(Token::IF, Token::UNLESS, Token::NEWLINE) == Token::IF {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default)

				return this.yep(AST.IfStatement(condition, this.yep(AST.ReturnStatement(first)), null, first, condition))
			}
			else if @token == Token::NEWLINE || @token == Token::EOF {
				return this.yep(AST.ReturnStatement(first))
			}
			else if @token == Token::UNLESS {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default)

				return this.yep(AST.UnlessStatement(condition, this.yep(AST.ReturnStatement(first)), first, condition))
			}
			else {
				const expression = this.tryExpression(ExpressionMode::Default)

				unless expression.ok {
					return NO
				}

				if this.match(Token::IF, Token::UNLESS, Token::NEWLINE) == Token::IF {
					this.commit()

					const condition = this.reqExpression(ExpressionMode::Default)

					if this.match(Token::ELSE, Token::NEWLINE) == Token::ELSE {
						this.commit()

						const whenFalse = this.reqExpression(ExpressionMode::Default)

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

					const condition = this.reqExpression(ExpressionMode::Default)

					return this.yep(AST.UnlessStatement(condition, this.yep(AST.ReturnStatement(expression, first, expression)), first, condition))
				}
				else {
					this.throw()
				}
			}
		} // }}}
		reqStatement() ~ SyntaxError { // {{{
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
				Token::AUTO => {
					statement = this.reqAutoStatement(this.yes())
				}
				Token::BREAK => {
					statement = this.reqBreakStatement(this.yes())
				}
				Token::CLASS => {
					statement = this.tryClassStatement(this.yes())
				}
				Token::CONST => {
					statement = this.reqConstStatement(this.yes())
				}
				Token::CONTINUE => {
					statement = this.reqContinueStatement(this.yes())
				}
				Token::DELETE => {
					statement = this.tryDestroyStatement(this.yes())
				}
				Token::DO => {
					statement = this.reqDoStatement(this.yes())
				}
				Token::ENUM => {
					statement = this.reqEnumStatement(this.yes())
				}
				Token::FALLTHROUGH => {
					statement = this.reqFallthroughStatement(this.yes())
				}
				Token::FINAL => {
					const first = this.yes()
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Final, first))]

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
				Token::FOR => {
					statement = this.reqForStatement(this.yes())
				}
				Token::FUNC => {
					statement = this.reqFunctionStatement(this.yes())
				}
				Token::IF => {
					statement = this.reqIfStatement(this.yes())
				}
				Token::IMPL => {
					statement = this.reqImplementStatement(this.yes())
				}
				Token::IMPORT => {
					statement = this.reqImportStatement(this.yes())
				}
				Token::LATEINIT => {
					statement = this.reqLateInitStatement(this.yes())
				}
				Token::LET => {
					statement = this.reqLetStatement(this.yes())
				}
				Token::MACRO => {
					if @mode & ParserMode::MacroExpression == 0 {
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
					statement = this.reqReturnStatement(this.yes())
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
					statement = this.reqSwitchStatement(this.yes())
				}
				Token::THROW => {
					statement = this.reqThrowStatement(this.yes())
				}
				Token::TRY => {
					statement = this.reqTryStatement(this.yes())
				}
				Token::TYPE => {
					statement = this.tryTypeStatement(this.yes())
				}
				Token::UNLESS => {
					statement = this.reqUnlessStatement(this.yes())
				}
				Token::UNTIL => {
					statement = this.tryUntilStatement(this.yes())
				}
				Token::WHILE => {
					statement = this.tryWhileStatement(this.yes())
				}
			}

			unless statement.ok {
				this.rollback(mark)

				if !(statement = this.tryAssignementStatement()).ok {
					this.rollback(mark)

					statement = this.reqExpressionStatement()
				}
			}

			this.reqNL_EOF_1M()

			return statement
		} // }}}
		reqString() ~ SyntaxError { // {{{
			if this.test(Token::STRING) {
				return this.yep(AST.Literal(this.value(), this.yes()))
			}
			else {
				this.throw('String')
			}
		} // }}}
		reqStructStatement(first) ~ SyntaxError { // {{{
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

			if this.test(Token::LEFT_CURLY) {
				const first = this.yes()

				this.NL_0M()

				modifiers.push(AST.Modifier(ModifierKind::Object, first))

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

						defaultValue = this.reqExpression(ExpressionMode::Default)
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
			else if extends == null && this.test(Token::LEFT_ROUND) {
				const first = this.yes()

				this.NL_0M()

				modifiers.push(AST.Modifier(ModifierKind::Array, first))

				this.stackInnerAttributes(attributes)

				until this.test(Token::RIGHT_ROUND) {
					const type = this.reqTypeVar()

					if this.test(Token::EQUALS) {
						this.commit()

						const defaultValue = this.reqExpression(ExpressionMode::Default)

						elements.push(AST.StructField(null, type, defaultValue, type, defaultValue))
					}
					else {
						elements.push(AST.StructField(null, type, null, type, type))
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
			else if this.test(Token::LEFT_SQUARE) {
				const first = this.yes()

				this.NL_0M()

				modifiers.push(AST.Modifier(ModifierKind::Array, first), AST.Modifier(ModifierKind::Named, first))

				this.stackInnerAttributes(attributes)

				until this.test(Token::RIGHT_SQUARE) {
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

						defaultValue = this.reqExpression(ExpressionMode::Default)
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

				unless this.test(Token::RIGHT_SQUARE) {
					this.throw(']')
				}

				last = this.yes()
			}

			return this.yep(AST.StructDeclaration(attributes, modifiers, name, extends, elements, first, last))
		} // }}}
		reqSwitchBinding() ~ SyntaxError { // {{{
			const bindings = [this.reqSwitchBindingValue()]

			while this.test(Token::COMMA) {
				this.commit()

				bindings.push(this.reqSwitchBindingValue())
			}

			return this.yep(bindings)
		} // }}}
		reqSwitchBindingValue() ~ SyntaxError { // {{{
			switch this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) {
				Token::LEFT_CURLY => {
					return this.reqDestructuringObject(this.yes())
				}
				Token::LEFT_SQUARE => {
					return this.reqDestructuringArray(this.yes())
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
		} // }}}
		reqSwitchCaseExpression() ~ SyntaxError { // {{{
			switch this.match(Token::LEFT_CURLY, Token::RETURN, Token::THROW) {
				Token::LEFT_CURLY => {
					return this.reqBlock(this.yes())
				}
				Token::RETURN => {
					const first = this.yes()
					const expression = this.reqExpression(ExpressionMode::Default)

					return this.yep(AST.ReturnStatement(expression, first, expression))
				}
				Token::THROW => {
					const first = this.yes()
					const expression = this.reqExpression(ExpressionMode::Default)

					return this.yep(AST.ThrowStatement(expression, first, expression))
				}
				=> {
					return this.reqExpression(ExpressionMode::Default)
				}
			}
		} // }}}
		reqSwitchCaseList() ~ SyntaxError { // {{{
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
					body = this.reqSwitchCaseExpression()
				}
				else {
					if this.test(Token::UNDERSCORE) {
						first = this.yes()
					}
					else if !(this.test(Token::WITH) || this.test(Token::WHERE)) {
						first = this.reqSwitchCondition()

						conditions = [first]

						while this.test(Token::COMMA) {
							this.commit()

							conditions.push(this.reqSwitchCondition())
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

						bindings = this.reqSwitchBinding()

						this.NL_0M()
					}

					if this.test(Token::WHERE) {
						if first == null {
							first = this.yes()
						}
						else {
							this.commit()
						}

						filter = this.reqExpression(ExpressionMode::NoAnonymousFunction)

						this.NL_0M()
					}

					unless this.test(Token::EQUALS_RIGHT_ANGLE) {
						this.throw('=>')
					}

					this.commit()

					body = this.reqSwitchCaseExpression()
				}

				this.reqNL_1M()

				clauses.push(AST.SwitchClause(conditions, bindings, filter, body, first!?, body))
			}

			unless this.test(Token::RIGHT_CURLY) {
				this.throw('}')
			}

			return this.yes(clauses)
		} // }}}
		reqSwitchCondition() ~ SyntaxError { // {{{
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

								members.push(this.yep(AST.ObjectMember(name, this.reqSwitchConditionValue())))
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
							values.push(this.reqSwitchConditionValue())
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
					return this.reqSwitchConditionValue()
				}
			}
		} // }}}
		reqSwitchConditionValue() ~ SyntaxError { // {{{
			const operand = this.reqPrefixedOperand(ExpressionMode::Default)

			if this.match(Token::LEFT_ANGLE, Token::DOT_DOT) == Token::DOT_DOT {
				this.commit()

				if this.test(Token::LEFT_ANGLE) {
					this.commit()

					return this.yep(AST.SwitchConditionRangeFI(operand, this.reqPrefixedOperand(ExpressionMode::Default)))
				}
				else {
					return this.yep(AST.SwitchConditionRangeFO(operand, this.reqPrefixedOperand(ExpressionMode::Default)))
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

					return this.yep(AST.SwitchConditionRangeTI(operand, this.reqPrefixedOperand(ExpressionMode::Default)))
				}
				else {
					return this.yep(AST.SwitchConditionRangeTO(operand, this.reqPrefixedOperand(ExpressionMode::Default)))
				}
			}
			else {
				return operand
			}
			} // }}}
		reqSwitchStatement(first) ~ SyntaxError { // {{{
			const expression = this.reqOperation(ExpressionMode::Default)
			const clauses = this.reqSwitchCaseList()

			return this.yep(AST.SwitchStatement(expression, clauses, first, clauses))
		} // }}}
		reqTemplateExpression(first) ~ SyntaxError { // {{{
			const elements = []

			while true {
				if this.matchM(M.TEMPLATE) == Token::TEMPLATE_ELEMENT {
					this.commit()

					elements.push(this.reqExpression(ExpressionMode::Default))

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
		} // }}}
		reqThisExpression(first) ~ SyntaxError { // {{{
			const identifier = this.reqIdentifier()

			return this.yep(AST.ThisExpression(identifier, first, identifier))
		} // }}}
		reqThrowStatement(first) ~ SyntaxError { // {{{
			const expression = this.reqExpression(ExpressionMode::Default)

			if this.match(Token::IF, Token::UNLESS, Token::NEWLINE) == Token::IF {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default)

				if this.match(Token::ELSE, Token::NEWLINE) == Token::ELSE {
					this.commit()

					const whenFalse = this.reqExpression(ExpressionMode::Default)

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

				const condition = this.reqExpression(ExpressionMode::Default)

				return this.yep(AST.UnlessStatement(condition, this.yep(AST.ThrowStatement(expression, first, expression)), first, condition))
			}
			else {
				this.throw()
			}
		} // }}}
		reqTryCatchClause(first) ~ SyntaxError { // {{{
			let binding
			if this.test(Token::IDENTIFIER) {
				binding = this.reqIdentifier()
			}

			this.NL_0M()

			const body = this.reqBlock()

			return this.yep(AST.CatchClause(binding, null, body, first, body))
		} // }}}
		reqTryExpression(first) ~ SyntaxError { // {{{
			const modifiers = []
			if this.testNS(Token::EXCLAMATION) {
				modifiers.push(AST.Modifier(ModifierKind::Disabled, this.yes()))
			}

			const operand = this.reqPrefixedOperand(ExpressionMode::Default)

			let default = null

			if this.test(Token::TILDE_TILDE) {
				this.commit()

				default = this.reqPrefixedOperand(ExpressionMode::Default)
			}

			return this.yep(AST.TryExpression(modifiers, operand, default, first, default ?? operand))
		} // }}}
		reqTryStatement(first) ~ SyntaxError { // {{{
			this.NL_0M()

			const body = this.tryBlock()

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
					catchClauses.push(last = this.reqCatchOnClause(this.yes()))

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
				catchClause = last = this.reqTryCatchClause(this.yes())

				mark = this.mark()
			}
			else {
				this.rollback(mark)
			}

			this.NL_0M()

			if this.test(Token::FINALLY) {
				this.commit()

				finalizer = last = this.reqBlock()
			}
			else {
				this.rollback(mark)
			}

			return this.yep(AST.TryStatement(body, catchClauses, catchClause, finalizer, first, last))
		} // }}}
		reqTypeEntity(nullable = null) ~ SyntaxError { // {{{
			const marker = this.mark()

			if this.match(Token::ASYNC, Token::FUNC, Token::LEFT_ROUND) == Token::ASYNC {
				const async = this.yes()

				if this.test(Token::FUNC) {
					this.commit()
				}

				if this.test(Token::LEFT_ROUND) {
					const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, async))]
					const parameters = this.reqFunctionParameterList()
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
					const parameters = this.reqFunctionParameterList()
					const type = this.tryFunctionReturns(false)
					const throws = this.tryFunctionThrows()

					return this.yep(AST.FunctionExpression(parameters, null, type, throws, null, first, throws ?? type ?? parameters))
				}
				else {
					this.rollback(marker)
				}
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.reqFunctionParameterList()
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
		} // }}}
		reqTypeGeneric(first) ~ SyntaxError { // {{{
			const entities = [this.reqTypeEntity()]

			while this.test(Token::COMMA) {
				this.commit()

				entities.push(this.reqTypeEntity())
			}

			unless this.test(Token::RIGHT_ANGLE) {
				this.throw('>')
			}

			return this.yes(entities)
		} // }}}
		reqTypeStatement(first, name) ~ SyntaxError { // {{{
			unless this.test(Token::EQUALS) {
				this.throw('=')
			}

			this.commit()

			const type = this.reqTypeVar(true)

			return this.yep(AST.TypeAliasDeclaration(name, type, first, type))
		} // }}}
		reqTypeVar(isMultiLines = false) ~ SyntaxError { // {{{
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
		} // }}}
		reqTypeObjectMember() ~ SyntaxError { // {{{
			const identifier = this.reqIdentifier()

			let type
			if this.test(Token::COLON) {
				this.commit()

				type = this.reqTypeVar()
			}
			else {
				const parameters = this.reqFunctionParameterList()
				type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()

				type = this.yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?? type ?? parameters))
			}

			return this.yep(AST.ObjectMemberReference(identifier, type))
		} // }}}
		reqTypeReference(isMultiLines: Boolean) ~ SyntaxError { // {{{
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
							const parameters = this.reqFunctionParameterList()
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
							const parameters = this.reqFunctionParameterList()
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
		} // }}}
		reqTypedVariable() ~ SyntaxError { // {{{
			let name = null
			let type = null

			if this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY {
				name = this.reqDestructuringObject(this.yes(), DestructuringMode::Declaration)
			}
			else if @token == Token::LEFT_SQUARE {
				name = this.reqDestructuringArray(this.yes(), DestructuringMode::Declaration)
			}
			else {
				name = this.reqIdentifier()
			}

			if this.test(Token::COLON) {
				this.commit()

				type = this.reqTypeVar()
			}

			return this.yep(AST.VariableDeclarator([], name, type, name, type ?? name))
		} // }}}
		reqUnaryOperand(mode, value = null) ~ SyntaxError { // {{{
			if value == null {
				value = this.reqOperand(mode)
			}

			let expression, mark, first

			while true {
				switch this.matchM(M.OPERAND_JUNCTION) {
					Token::ASTERISK_ASTERISK_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CallExpression([], AST.Scope(ScopeKind::Null), value, this.reqExpression0CNList(), value, this.yes()))
					}
					Token::ASTERISK_DOLLAR_LEFT_ROUND => {
						this.commit()

						const arguments = this.reqExpression0CNList()

						value = this.yep(AST.CallExpression([], AST.Scope(ScopeKind::Argument, arguments.value.shift()), value, arguments, value, this.yes()))
					}
					Token::CARET_AT_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CurryExpression(AST.Scope(ScopeKind::This), value, this.reqExpression0CNList(), value, this.yes()))
					}
					Token::CARET_CARET_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CurryExpression(AST.Scope(ScopeKind::Null), value, this.reqExpression0CNList(), value, this.yes()))
					}
					Token::CARET_DOLLAR_LEFT_ROUND => {
						this.commit()

						const arguments = this.reqExpression0CNList()

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

						value = this.yep(AST.CallMacroExpression(value, this.reqExpression0CNList(), value, this.yes()))
					}
					Token::LEFT_SQUARE => {
						const modifiers = [AST.Modifier(ModifierKind::Computed, this.yes())]

						expression = this.reqExpression(ExpressionMode::Default)

						unless this.test(Token::RIGHT_SQUARE) {
							this.throw(']')
						}

						value = this.yep(AST.MemberExpression(modifiers, value, expression, value, this.yes()))
					}
					Token::LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CallExpression([], value, this.reqExpression0CNList(), value, this.yes()))
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

						value = this.yep(AST.CallExpression(modifiers, AST.Scope(ScopeKind::This), value, this.reqExpression0CNList(), value, this.yes()))
					}
					Token::QUESTION_LEFT_SQUARE => {
						const position = this.yes()
						const modifiers = [AST.Modifier(ModifierKind::Nullable, position), AST.Modifier(ModifierKind::Computed, position)]

						expression = this.reqExpression(ExpressionMode::Default)

						unless this.test(Token::RIGHT_SQUARE) {
							this.throw(']')
						}

						value = this.yep(AST.MemberExpression(modifiers, value, expression, value, this.yes()))
					}
					Token::TEMPLATE_BEGIN => {
						value = this.yep(AST.TaggedTemplateExpression(value, this.reqTemplateExpression(this.yes()), value, this.yes()))
					}
					=> {
						break
					}
				}
			}

			return value
		} // }}}
		reqUnlessStatement(first) ~ SyntaxError { // {{{
			const condition = this.reqExpression(ExpressionMode::Default)
			const whenFalse = this.reqBlock()

			return this.yep(AST.UnlessStatement(condition, whenFalse, first, whenFalse))
		} // }}}
		reqVariable() ~ SyntaxError { // {{{
			const name = this.reqIdentifier()

			return this.yep(AST.VariableDeclarator([], name, null, name, name))
		} // }}}
		reqVariableIdentifier() ~ SyntaxError { // {{{
			if this.match(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::IDENTIFIER {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else if @token == Token::LEFT_CURLY {
				return this.reqDestructuringObject(this.yes(), DestructuringMode::Expression)
			}
			else if @token == Token::LEFT_SQUARE {
				return this.reqDestructuringArray(this.yes(), DestructuringMode::Expression)
			}
			else {
				this.throw(['Identifier', '{', '['])
			}
		} // }}}
		reqVariableName(object = NO) ~ SyntaxError { // {{{
			if !object.ok {
				if this.test(Token::AT) {
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

					property = this.reqExpression(ExpressionMode::Default)

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
		} // }}}
		stackInnerAttributes(attributes: Array): Boolean ~ SyntaxError { // {{{
			if this.test(Token::HASH_EXCLAMATION_LEFT_SQUARE) {
				do {
					const first = this.yes()
					const declaration = this.reqAttributeMember()

					unless this.test(Token::RIGHT_SQUARE) {
						this.throw(']')
					}

					attributes.push(AST.AttributeDeclaration(declaration, first, this.yes()))

					this.reqNL_EOF_1M()
				}
				while this.test(Token::HASH_EXCLAMATION_LEFT_SQUARE)

				return true
			}
			else {
				return false
			}
		} // }}}
		stackOuterAttributes(attributes: Array): Array ~ SyntaxError { // {{{
			while this.test(Token::HASH_LEFT_SQUARE) {
				attributes.push(this.reqAttribute(this.yes()).value)

				this.NL_0M()
			}

			return attributes
		} // }}}
		tryAssignementOperator() ~ SyntaxError { // {{{
			switch this.matchM(M.ASSIGNEMENT_OPERATOR) {
				Token::AMPERSAND_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseAnd, this.yes()))
				}
				Token::ASTERISK_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Multiplication, this.yes()))
				}
				Token::CARET_EQUALS => {
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
				Token::PIPE_EQUALS => {
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
		} // }}}
		tryAssignementStatement() ~ SyntaxError { // {{{
			let identifier = NO

			if this.match(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE, Token::AT) == Token::IDENTIFIER {
				identifier = this.reqUnaryOperand(ExpressionMode::Default, this.reqIdentifier())
			}
			else if @token == Token::LEFT_CURLY {
				identifier = this.tryDestructuringObject(this.yes())
			}
			else if @token == Token::LEFT_SQUARE {
				identifier = this.tryDestructuringArray(this.yes())
			}
			else if @token == Token::AT {
				identifier = this.reqUnaryOperand(ExpressionMode::Default, this.reqThisExpression(this.yes()))
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

					variables.push(this.reqVariableIdentifier())
				}
				while this.test(Token::COMMA)

				if this.test(Token::EQUALS) {
					this.commit().NL_0M()

					unless this.test(Token::AWAIT) {
						this.throw('await')
					}

					const operand = this.reqPrefixedOperand(ExpressionMode::Default)

					statement = this.yep(AST.AwaitExpression([], variables, operand, identifier, operand))
				}
				else {
					this.throw('=')
				}
			}
			else if @token == Token::EQUALS {
				const equals = this.yes()

				this.NL_0M()

				const expression = this.reqExpression(ExpressionMode::Default)

				statement = this.yep(AST.BinaryExpression(identifier, this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Equality, equals)), expression, identifier, expression))
			}
			else {
				return NO
			}

			if this.match(Token::IF, Token::UNLESS) == Token::IF {
				const first = this.yes()
				const condition = this.reqExpression(ExpressionMode::Default)

				if this.test(Token::ELSE) {
					this.commit()

					const whenFalse = this.reqExpression(ExpressionMode::Default)

					statement.value.right = AST.IfExpression(condition, this.yep(statement.value.right), whenFalse, first, whenFalse)

					this.relocate(statement, statement, whenFalse)
				}
				else {
					statement = this.yep(AST.IfExpression(condition, statement, null, statement, condition))
				}
			}
			else if @token == Token::UNLESS {
				this.commit()

				const condition = this.reqExpression(ExpressionMode::Default)

				statement = this.yep(AST.UnlessExpression(condition, statement, statement, condition))
			}

			return this.yep(AST.ExpressionStatement(statement))
		} // }}}
		tryAwaitExpression(mode) ~ SyntaxError { // {{{
			unless this.test(Token::AWAIT) {
				return NO
			}

			try {
				return this.reqAwaitExpression(this.yes())
			}
			catch {
				return NO
			}
		} // }}}
		tryBinaryOperator() ~ SyntaxError { // {{{
			switch this.matchM(M.BINARY_OPERATOR) {
				Token::AMPERSAND => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseAnd, this.yes()))
				}
				Token::AMPERSAND_AMPERSAND => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::And, this.yes()))
				}
				Token::AMPERSAND_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseAnd, this.yes()))
				}
				Token::ASTERISK => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Multiplication, this.yes()))
				}
				Token::ASTERISK_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::Multiplication, this.yes()))
				}
				Token::CARET => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseXor, this.yes()))
				}
				Token::CARET_CARET => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Xor, this.yes()))
				}
				Token::CARET_EQUALS => {
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
				Token::EXCLAMATION_QUESTION_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::NonExistential, this.yes()))
				}
				Token::LEFT_ANGLE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::LessThan, this.yes()))
				}
				Token::LEFT_ANGLE_EQUALS => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::LessThanOrEqual, this.yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseLeftShift, this.yes()))
				}
				Token::LEFT_ANGLE_LEFT_ANGLE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseLeftShift, this.yes()))
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
				Token::PIPE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseOr, this.yes()))
				}
				Token::PIPE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseOr, this.yes()))
				}
				Token::PIPE_PIPE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::Or, this.yes()))
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
				Token::RIGHT_ANGLE_RIGHT_ANGLE => {
					return this.yep(AST.BinaryOperator(BinaryOperatorKind::BitwiseRightShift, this.yes()))
				}
				Token::RIGHT_ANGLE_RIGHT_ANGLE_EQUALS => {
					return this.yep(AST.AssignmentOperator(AssignmentOperatorKind::BitwiseRightShift, this.yes()))
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
				=> {
					return NO
				}
			}
		} // }}}
		tryBlock() ~ SyntaxError { // {{{
			try {
				return this.reqBlock()
			}
			catch {
				return NO
			}
		} // }}}
		tryClassAbstractMethod(attributes, modifiers, first?) ~ SyntaxError { // {{{
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

			return this.reqClassAbstractMethodBody(attributes, modifiers, name, first ?? name)
		} // }}}
		tryClassMember(attributes, modifiers, first?) ~ SyntaxError { // {{{
			const mark = this.mark()

			if this.test(Token::ASYNC) {
				const modifier = this.yep(AST.Modifier(ModifierKind::Async, this.yes()))
				const name = this.tryIdentifier()

				if name.ok {
					return this.reqClassMethod(attributes, [...modifiers, modifier], name, null, first ?? modifier)
				}
				else {
					this.rollback(mark)
				}
			}
			else if this.test(Token::AT) {
				const modifier = this.yep(AST.Modifier(ModifierKind::ThisAlias, this.yes()))
				const name = this.reqNameIST()

				let type
				if this.test(Token::COLON) {
					this.commit()

					type = this.reqTypeVar()
				}

				let defaultValue
				if this.test(Token::EQUALS) {
					this.commit()

					defaultValue = this.reqExpression(ExpressionMode::Default)
				}

				this.reqNL_1M()

				return this.yep(AST.FieldDeclaration(attributes, [...modifiers, modifier], name, type, defaultValue, first ?? modifier, defaultValue ?? type ?? name))
			}
			else if this.test(Token::AUTO) {
				const modifier = this.yep(AST.Modifier(ModifierKind::AutoTyping, this.yes()))

				lateinit const name
				if this.test(Token::AT) {
					modifiers = [...modifiers, modifier, this.yep(AST.Modifier(ModifierKind::ThisAlias, this.yes()))]

					name = this.reqNameIST()
				}
				else {
					name = this.tryNameIST()

					if name.ok {
						modifiers = [...modifiers, modifier]
					}
					else {
						this.rollback(mark)
					}
				}

				if name.ok {
					let defaultValue
					if this.test(Token::EQUALS) {
						this.commit()

						defaultValue = this.reqExpression(ExpressionMode::Default)
					}

					this.reqNL_1M()

					return this.yep(AST.FieldDeclaration(attributes, modifiers, name, null, defaultValue, first ?? modifier, defaultValue ?? name))
				}
			}
			else if this.test(Token::CONST) {
				const modifier = this.yep(AST.Modifier(ModifierKind::Immutable, this.yes()))

				lateinit const name
				if this.test(Token::AT) {
					modifiers = [...modifiers, modifier, this.yep(AST.Modifier(ModifierKind::ThisAlias, this.yes()))]

					name = this.reqNameIST()
				}
				else {
					name = this.tryNameIST()

					if name.ok {
						modifiers = [...modifiers, modifier]
					}
					else {
						this.rollback(mark)
					}
				}

				if name.ok {
					let type
					if this.test(Token::COLON) {
						this.commit()

						type = this.reqTypeVar()
					}

					unless this.test(Token::EQUALS) {
						this.throw('=')
					}

					this.commit()

					const defaultValue = this.reqExpression(ExpressionMode::Default)

					this.reqNL_1M()

					return this.yep(AST.FieldDeclaration(attributes, modifiers, name, type, defaultValue, first ?? modifier, defaultValue))
				}
			}
			else if this.test(Token::LATEINIT) {
				const modifier = this.yep(AST.Modifier(ModifierKind::LateInit, this.yes()))
				const mark2 = this.mark()
				const modifiers = [...modifiers, modifier]

				let name, type
				if this.test(Token::AT) {
					modifiers.push(this.yep(AST.Modifier(ModifierKind::ThisAlias, this.yes())))

					name = this.reqNameIST()

					if this.test(Token::COLON) {
						this.commit()

						type = this.reqTypeVar()
					}
				}
				else if this.test(Token::AUTO) {
					const modifier = this.yep(AST.Modifier(ModifierKind::AutoTyping, this.yes()))

					if this.test(Token::AT) {
						modifiers.push(modifier, this.yep(AST.Modifier(ModifierKind::ThisAlias, this.yes())))

						name = this.reqNameIST()
					}
					else {
						name = this.tryNameIST()

						if name.ok {
							modifiers.push(modifier)
						}
						else {
							this.rollback(mark2)

							name = this.reqNameIST()

							if this.test(Token::COLON) {
								this.commit()

								type = this.reqTypeVar()
							}
						}
					}
				}
				else if this.test(Token::CONST) {
					const modifier = this.yep(AST.Modifier(ModifierKind::Immutable, this.yes()))

					if this.test(Token::AT) {
						modifiers.push(modifier, this.yep(AST.Modifier(ModifierKind::ThisAlias, this.yes())))

						name = this.reqNameIST()
					}
					else {
						name = this.tryNameIST()

						if name.ok {
							modifiers.push(modifier)
						}
						else {
							this.rollback(mark2)

							name = this.reqNameIST()
						}
					}

					if this.test(Token::COLON) {
						this.commit()

						type = this.reqTypeVar()
					}
				}
				else {
					name = this.tryNameIST()

					if name.ok {
						if this.test(Token::COLON) {
							this.commit()

							type = this.reqTypeVar()
						}
					}
					else {
						this.rollback(mark)
					}
				}

				if name.ok {
					this.reqNL_1M()

					return this.yep(AST.FieldDeclaration(attributes, modifiers, name, type, null, first ?? modifier, type ?? name))
				}
			}

			const name = this.tryNameIST()

			unless name.ok {
				return NO
			}

			if this.match(Token::COLON, Token::LEFT_CURLY, Token::LEFT_ROUND) == Token::COLON {
				this.commit()

				const type = this.reqTypeVar()

				if this.test(Token::LEFT_CURLY) {
					this.commit()

					return this.reqClassProperty(attributes, modifiers, name, type, first ?? name)
				}
				else {
					let defaultValue
					if this.test(Token::EQUALS) {
						this.commit()

						defaultValue = this.reqExpression(ExpressionMode::Default)
					}

					this.reqNL_1M()

					return this.yep(AST.FieldDeclaration(attributes, modifiers, name, type, defaultValue, first ?? name, defaultValue ?? type ?? name))
				}
			}
			else if @token == Token::LEFT_CURLY {
				this.commit()

				return this.reqClassProperty(attributes, modifiers, name, null, first ?? name)
			}
			else if @token == Token::LEFT_ROUND {
				return this.reqClassMethod(attributes, modifiers, name, this.yes(), first ?? name)
			}
			else {
				let defaultValue
				if this.test(Token::EQUALS) {
					this.commit()

					defaultValue = this.reqExpression(ExpressionMode::Default)
				}

				this.reqNL_1M()

				return this.yep(AST.FieldDeclaration(attributes, modifiers, name, null, defaultValue, first ?? name, defaultValue ?? name))
			}
		} // }}}
		tryClassMethod(attributes, modifiers, first?) ~ SyntaxError { // {{{
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

			return this.reqClassMethod(attributes, modifiers, name, null, first ?? name)
		} // }}}
		tryClassStatement(first, modifiers = []) ~ SyntaxError { // {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			return this.reqClassStatementBody(name, first, modifiers)
		} // }}}
		tryDestroyStatement(first) ~ SyntaxError { // {{{
			const variable = this.tryVariableName()

			if variable.ok {
				return this.yep(AST.DestroyStatement(variable, first, variable))
			}
			else {
				return NO
			}
		} // }}}
		tryDestructuring() ~ SyntaxError { // {{{
			if this.match(Token::LEFT_CURLY, Token::LEFT_SQUARE) == Token::LEFT_CURLY {
				try {
					return this.reqDestructuringObject(this.yes(), DestructuringMode::Expression)
				}
			}
			else if @token == Token::LEFT_SQUARE {
				try {
					return this.reqDestructuringArray(this.yes(), DestructuringMode::Expression)
				}
			}

			return NO
		} // }}}
		tryDestructuringArray(first) ~ SyntaxError { // {{{
			try {
				return this.reqDestructuringArray(first, DestructuringMode::Expression)
			}
			catch {
				return NO
			}
		} // }}}
		tryDestructuringObject(first) ~ SyntaxError { // {{{
			try {
				return this.reqDestructuringObject(first, DestructuringMode::Expression)
			}
			catch {
				return NO
			}
		} // }}}
		tryExpression(mode = ExpressionMode::Default) ~ SyntaxError { // {{{
			try {
				return this.reqExpression(mode)
			}
			catch {
				return NO
			}
		} // }}}
		tryExternFunctionDeclaration(first, modifiers) ~ SyntaxError { // {{{
			try {
				return this.reqExternFunctionDeclaration(first, modifiers)
			}
			catch {
				return NO
			}
		} // }}}
		tryFunctionBody() ~ SyntaxError { // {{{
			const mark = this.mark()

			this.NL_0M()

			if this.test(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) {
				return this.reqFunctionBody()
			}
			else {
				this.rollback(mark)

				return null
			}
		} // }}}
		tryFunctionExpression(mode) ~ SyntaxError { // {{{
			if mode & ExpressionMode::NoAnonymousFunction != 0 {
				return NO
			}

			if this.match(Token::ASYNC, Token::FUNC, Token::LEFT_ROUND, Token::IDENTIFIER) == Token::ASYNC {
				const first = this.yes()
				const modifiers = [this.yep(AST.Modifier(ModifierKind::Async, first))]

				if this.test(Token::FUNC) {
					this.commit()

					const parameters = this.reqFunctionParameterList()
					const type = this.tryFunctionReturns()
					const throws = this.tryFunctionThrows()
					const body = this.reqFunctionBody()

					return this.yep(AST.FunctionExpression(parameters, modifiers, type, throws, body, first, body))
				}
				else {
					const parameters = this.tryFunctionParameterList()
					if !parameters.ok {
						return NO
					}

					const type = this.tryFunctionReturns()
					const throws = this.tryFunctionThrows()
					const body = this.reqFunctionBody()

					return this.yep(AST.LambdaExpression(parameters, modifiers, type, throws, body, first, body))
				}
			}
			else if @token == Token::FUNC {
				const first = this.yes()

				const parameters = this.tryFunctionParameterList()
				if !parameters.ok {
					return NO
				}

				const type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()
				const body = this.reqFunctionBody()

				return this.yep(AST.FunctionExpression(parameters, null, type, throws, body, first, body))
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.tryFunctionParameterList()
				const type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()

				if !parameters.ok || !this.test(Token::EQUALS_RIGHT_ANGLE) {
					return NO
				}

				this.commit()

				if this.test(Token::LEFT_CURLY) {
					const body = this.reqBlock()

					return this.yep(AST.LambdaExpression(parameters, null, type, throws, body, parameters, body))
				}
				else {
					const body = this.reqExpression(mode | ExpressionMode::NoObject)

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
					const body = this.reqBlock()

					return this.yep(AST.LambdaExpression(parameters, null, null, null, body, parameters, body))
				}
				else {
					const body = this.reqExpression(mode | ExpressionMode::NoObject)

					return this.yep(AST.LambdaExpression(parameters, null, null, null, body, parameters, body))
				}
			}
			else {
				return NO
			}
		} // }}}
		tryFunctionParameterList() ~ SyntaxError { // {{{
			unless this.test(Token::LEFT_ROUND) {
				return NO
			}

			const first = this.yes()

			const parameters = []

			unless this.test(Token::RIGHT_ROUND) {
				try {
					while this.reqParameter(parameters, ParameterMode::Function) {
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
		} // }}}
		tryFunctionReturns(isAllowingAuto: Boolean = true) ~ SyntaxError { // {{{
			const mark = this.mark()

			this.NL_0M()

			if this.test(Token::COLON) {
				this.commit()

				const mark = this.mark()

				if @scanner.test(Token::IDENTIFIER) {
					const value = @scanner.value()

					if value == 'this' || (!isAllowingAuto && value == 'auto') {
						throw new SyntaxError(`The return type "\(value)" can't be used at line \(@scanner.line()) and column \(@scanner.column())`)
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
		} // }}}
		tryFunctionThrows() ~ SyntaxError { // {{{
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
		} // }}}
		tryIdentifier() ~ SyntaxError { // {{{
			if @scanner.test(Token::IDENTIFIER) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				return NO
			}
		} // }}}
		tryMacroStatement(first) ~ SyntaxError { // {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			const parameters = this.reqMacroParameterList()

			const body = this.reqMacroBody()

			return this.yep(AST.MacroDeclaration([], name, parameters, body, first, body))
		} // }}}
		tryMethodReturns(isAllowingAuto: Boolean = true) ~ SyntaxError { // {{{
			const mark = this.mark()

			this.NL_0M()

			if this.test(Token::COLON) {
				this.commit()

				const mark = this.mark()

				if @scanner.test(Token::IDENTIFIER) {
					const value = @scanner.value()

					if !isAllowingAuto && value == 'auto' {
						throw new SyntaxError(`The return type "auto" can't be used at line \(@scanner.line()) and column \(@scanner.column())`)
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
		} // }}}
		tryNameIST() ~ SyntaxError { // {{{
			if this.match(Token::IDENTIFIER, Token::STRING, Token::TEMPLATE_BEGIN) == Token::IDENTIFIER {
				return this.reqIdentifier()
			}
			else if @token == Token::STRING {
				return this.reqString()
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return this.reqTemplateExpression(this.yes())
			}
			else {
				return NO
			}
		} // }}}
		tryNamespaceStatement(first) ~ SyntaxError { // {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			return this.reqNamespaceStatement(first, name)
		} // }}}
		tryNumber() ~ SyntaxError { // {{{
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
		} // }}}
		tryOperand(mode): Event ~ SyntaxError { // {{{
			if this.matchM(M.OPERAND) == Token::AT {
				return this.reqThisExpression(this.yes())
			}
			else if @token == Token::IDENTIFIER {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else if @token == Token::LEFT_CURLY {
				return this.reqObject(this.yes())
			}
			else if @token == Token::LEFT_ROUND {
				return this.reqParenthesis(this.yes())
			}
			else if @token == Token::LEFT_SQUARE {
				return this.reqArray(this.yes())
			}
			else if @token == Token::NEW {
				return this.reqCreateExpression(this.yes())
			}
			else if @token == Token::REGEXP {
				return this.yep(AST.RegularExpression(@scanner.value(), this.yes()))
			}
			else if @token == Token::STRING {
				return this.yep(AST.Literal(this.value(), this.yes()))
			}
			else if @token == Token::TEMPLATE_BEGIN {
				return this.reqTemplateExpression(this.yes())
			}
			else {
				return this.tryNumber()
			}
		} // }}}
		tryRangeOperand(mode) ~ SyntaxError { // {{{
			const operand = this.tryOperand(mode)
			if !operand.ok {
				return NO
			}

			return this.reqPostfixedOperand(mode, operand)
		} // }}}
		trySwitchExpression(mode) ~ SyntaxError { // {{{
			unless this.test(Token::SWITCH) {
				return NO
			}

			const first = this.yes()

			const expression = this.reqOperation(mode)
			const clauses = this.reqSwitchCaseList()

			return this.yep(AST.SwitchExpression(expression, clauses, first, clauses))
		} // }}}
		tryTryExpression(mode) ~ SyntaxError { // {{{
			unless this.test(Token::TRY) {
				return NO
			}

			try {
				return this.reqTryExpression(this.yes())
			}
			catch {
				return NO
			}
		} // }}}
		tryTypeStatement(first) ~ SyntaxError { // {{{
			const name = this.tryIdentifier()

			unless name.ok {
				return NO
			}

			return this.reqTypeStatement(first, name)
		} // }}}
		tryUntilStatement(first) ~ SyntaxError { // {{{
			const condition = this.tryExpression()

			unless condition.ok {
				return NO
			}

			let body
			if this.match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				body = this.reqBlock(this.yes())
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				this.commit()

				body = this.reqExpression(ExpressionMode::Default)
			}
			else {
				this.throw(['{', '=>'])
			}

			return this.yep(AST.UntilStatement(condition, body, first, body))
		} // }}}
		tryVariable() ~ SyntaxError { // {{{
			const name = this.tryIdentifier()

			if name.ok {
				return this.yep(AST.VariableDeclarator([], name, null, name, name))
			}
			else {
				return NO
			}
		} // }}}
		tryVariableName() ~ SyntaxError { // {{{
			let object
			if this.test(Token::AT) {
				object = this.reqThisExpression(this.yes())
			}
			else {
				object = this.tryIdentifier()

				unless object.ok {
					return NO
				}
			}

			return this.reqVariableName(object)
		} // }}}}
		tryWhileStatement(first) ~ SyntaxError { // {{{
			let condition

			if this.test(Token::LET, Token::CONST, Token::AUTO) {
				const token = @token

				const mark = this.mark()
				const first = this.yes()

				const modifiers = []
				if token == Token::CONST {
					modifiers.push(AST.Modifier(ModifierKind::Immutable, first))
				}
				else if token == Token::AUTO {
					modifiers.push(AST.Modifier(ModifierKind::AutoTyping, first))
				}

				if this.test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					const variable = this.reqTypedVariable()

					if this.test(Token::COMMA) {
						const variables = [variable]

						do {
							this.commit()

							variables.push(this.reqTypedVariable())
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

						const operand = this.reqPrefixedOperand(ExpressionMode::Default)

						condition = this.yep(AST.VariableDeclaration(modifiers, variables, operand, first, operand))
					}
					else {
						unless this.test(Token::EQUALS) {
							this.throw('=')
						}

						this.commit()

						const expression = this.reqExpression(ExpressionMode::Default)

						condition = this.yep(AST.VariableDeclaration(modifiers, [variable], expression, first, expression))
					}
				}
				else {
					this.rollback(mark)

					condition = this.tryExpression()
				}
			}
			else {
				condition = this.tryExpression()
			}

			unless condition.ok {
				return NO
			}

			let body
			if this.match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) == Token::LEFT_CURLY {
				body = this.reqBlock(this.yes())
			}
			else if @token == Token::EQUALS_RIGHT_ANGLE {
				this.commit()

				body = this.reqExpression(ExpressionMode::Default)
			}
			else {
				this.throw(['{', '=>'])
			}

			return this.yep(AST.WhileStatement(condition, body, first, body))
		} // }}}
	}

	export func parse(data: String) ~ SyntaxError { // {{{
		const parser = new Parser(data)

		return parser.reqModule()
	} // }}}
}

export Parser.parse