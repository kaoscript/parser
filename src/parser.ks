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
	extern {
		console
		parseFloat
		parseInt
		sealed class SyntaxError
	}

	include {
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

	const NO = {
		ok: false
	}

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
		commit()  { // {{{
			@token = @scanner.commit()

			return this
		} // }}}
		mark() =>  @scanner.mark()
		match(...tokens) => @token = @scanner.match(...tokens)
		matchM(matcher: Function) => @token = @scanner.matchM(matcher)
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
		rollback(mark) { // {{{
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
		test(token) { // {{{
			if @scanner.test(token) {
				@token = token

				return true
			}
			else {
				return false
			}
		} // }}}
		test(...tokens) => tokens.indexOf(this.match(...tokens)) != -1
		testNS(token) { // {{{
			if @scanner.testNS(token) {
				@token = token

				return true
			}
			else {
				return false
			}
		} // }}}
		throw() ~ SyntaxError { // {{{
			throw new SyntaxError(`Unexpected \(@scanner.toQuote()) at line \(@scanner.line()) and column \(@scanner.column())`)
		} // }}}
		throw(expected: String) ~ SyntaxError { // {{{
			throw new SyntaxError(`Expecting "\(expected)" but got \(@scanner.toQuote()) at line \(@scanner.line()) and column \(@scanner.column())`)
		} // }}}
		throw(expecteds: Array) ~ SyntaxError { // {{{
			throw new SyntaxError(`Expecting "\(expecteds.slice(0, expecteds.length - 1).join('", "'))" or "\(expecteds[expecteds.length - 1])" but got \(@scanner.toQuote()) at line \(@scanner.line()) and column \(@scanner.column())`)
		} // }}}
		until(token) => !@scanner.test(token) && !@scanner.isEOF()
		value() => @scanner.value(@token)
		yep() { // {{{
			const position = @scanner.position()

			return {
				ok: true
				start: position.start
				end: position.end
			}
		} // }}}
		yep(value) { // {{{
			return {
				ok: true
				value: value
				start: value.start
				end: value.end
			}
		} // }}}
		yep(value, first, last) { // {{{
			return {
				ok: true
				value: value
				start: first.start
				end: last.end
			}
		} // }}}
		yes() { // {{{
			const position = @scanner.position()

			this.commit()

			return {
				ok: true
				start: position.start
				end: position.end
			}
		} // }}}
		yes(value) { // {{{
			const start = value.start ?? @scanner.startPosition()
			const end = value.end ?? @scanner.endPosition()

			this.commit()

			return {
				ok: true
				value: value
				start: start
				end: end
			}
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
		altForExpressionFrom(declaration, rebindable, variable, first) ~ SyntaxError { // {{{
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

			return this.yep(AST.ForFromStatement(declaration, rebindable, variable, from, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? from))
		} // }}}
		altForExpressionIn(declaration, rebindable, value, index, expression, first) ~ SyntaxError { // {{{
			let desc = null
			if this.test(Token::DESC) {
				desc = this.yes()
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

			return this.yep(AST.ForInStatement(declaration, rebindable, value, index, expression, desc, from, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? from ?? desc ?? expression))
		} // }}}
		altForExpressionInRange(declaration, rebindable, value, index, first) ~ SyntaxError { // {{{
			let operand = this.tryPrefixedOperand(ExpressionMode::Default)

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

					return this.altForExpressionRange(declaration, rebindable, value, index, then ? null : operand, then ? operand : null, til ? toOperand : null, til ? null : toOperand, byOperand, first)
				}
				else {
					return this.altForExpressionIn(declaration, rebindable, value, index, operand, first)
				}
			}
			else {
				return this.altForExpressionIn(declaration, rebindable, value, index, this.reqExpression(ExpressionMode::Default), first)
			}
		} // }}}
		altForExpressionOf(declaration, rebindable, key?, value?, first) ~ SyntaxError { // {{{
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

			return this.yep(AST.ForOfStatement(declaration, rebindable, key, value, expression, until, while, whenExp, first, whenExp ?? while ?? until ?? expression))
		} // }}}
		altForExpressionRange(declaration, rebindable, value, index, from?, then?, til?, to?, by?, first) ~ SyntaxError { // {{{
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

			return this.yep(AST.ForRangeStatement(declaration, rebindable, value, index, from, then, til, to, by, until, while, whenExp, first, whenExp ?? while ?? until ?? by ?? to ?? til ?? then ?? from:Any))
		} // }}}
		reqArray(first) ~ SyntaxError { // {{{
			if this.test(Token::RIGHT_SQUARE) {
				return this.yep(AST.ArrayExpression([], first, this.yes()))
			}

			const mark = this.mark()

			let operand = this.tryPrefixedOperand(ExpressionMode::Default)

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
		reqAwaitExpression(first) ~ SyntaxError { // {{{
			const operand = this.reqPrefixedOperand(ExpressionMode::Default)

			return this.yep(AST.AwaitExpression(null, false, operand, first, operand))
		} // }}}
		reqBinaryOperand(mode) ~ SyntaxError { // {{{
			const mark = this.mark()

			let expression
			if (expression = this.tryFunctionExpression(mode)).ok {
				return expression
			}
			else if this.rollback(mark) && (expression = this.trySwitchExpression(mode)).ok {
				return expression
			}

			this.rollback(mark)

			const operand = this.reqPrefixedOperand(mode)

			let operator
			switch this.matchM(M.TYPE_OPERATOR) {
				Token::AS => {
					operator = this.yep(AST.BinaryOperator(BinaryOperatorKind::TypeCasting, this.yes()))
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
					modifiers.push(this.yep(AST.Modifier(ModifierKind::Async, async)))
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
			const type = this.tryFunctionReturns()
			const throws = this.tryFunctionThrows()

			this.reqNL_1M()

			return this.yep(AST.MethodDeclaration(attributes, modifiers, name, parameters, type, throws, null, first, throws ?? type ?? parameters))
		} // }}}
		reqClassField(attributes, modifiers, name, type?, first) ~ SyntaxError { // {{{
			let defaultValue
			if this.test(Token::EQUALS) {
				this.commit()

				defaultValue = this.reqExpression(ExpressionMode::Default)
			}

			this.reqNL_1M()

			return this.yep(AST.FieldDeclaration(attributes, modifiers, name, type, defaultValue, first, defaultValue ?? type ?? name))
		} // }}}
		reqClassMember(attributes, modifiers, first?) ~ SyntaxError { // {{{
			let name
			if this.test(Token::ASYNC) {
				let async = this.reqIdentifier()

				name = this.tryNameIST()

				if name.ok {
					modifiers.push(this.yep(AST.Modifier(ModifierKind::Async, async)))

					return this.reqClassMethod(attributes, modifiers, name, null, first ?? async)
				}
				else {
					name = async
				}
			}
			else if this.test(Token::AT) {
				const modifier = this.yep(AST.Modifier(ModifierKind::ThisAlias, this.yes()))
				const name = this.reqNameIST()

				if this.test(Token::COLON) {
					this.commit()

					const type = this.reqTypeVar()

					return this.reqClassField(attributes, [...modifiers, modifier], name, type, first ?? modifier)
				}
				else {
					return this.reqClassField(attributes, [...modifiers, modifier], name, null, first ?? modifier)
				}
			}
			else {
				name = this.reqNameIST()
			}

			return this.reqClassMemberBody(attributes, modifiers, name, first ?? name)
		} // }}}
		reqClassMemberBody(attributes, modifiers, name, first) ~ SyntaxError { // {{{
			if this.match(Token::COLON, Token::LEFT_CURLY, Token::LEFT_ROUND) == Token::COLON {
				this.commit()

				const type = this.reqTypeVar()

				if this.test(Token::LEFT_CURLY) {
					this.commit()

					return this.reqClassProperty(attributes, modifiers, name, type, first)
				}
				else {
					return this.reqClassField(attributes, modifiers, name, type, first)
				}
			}
			else if @token == Token::LEFT_CURLY {
				this.commit()

				return this.reqClassProperty(attributes, modifiers, name, null, first)
			}
			else if @token == Token::LEFT_ROUND {
				return this.reqClassMethod(attributes, modifiers, name, this.yes(), first)
			}
			else {
				return this.reqClassField(attributes, modifiers, name, null, first)
			}
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

			const modifiers = []
			if this.match(Token::PRIVATE, Token::PROTECTED, Token::PUBLIC) == Token::PRIVATE {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Private, this.yes())))
			}
			else if @token == Token::PROTECTED {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Protected, this.yes())))
			}
			else if @token == Token::PUBLIC {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Public, this.yes())))
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
					first ??= modifiers[0]

					const member = this.tryClassAbstractMethod(attributes, modifiers, first)

					if member.ok {
						members.push(member)
					}
					else {
						this.rollback(mark2)

						modifiers.pop()

						members.push(this.reqClassMember(attributes, modifiers, first))
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
		reqClassMethod(attributes, modifiers, name, round?, first) ~ SyntaxError { // {{{
			const parameters = this.reqClassMethodParameterList(round)

			const type = this.tryFunctionReturns()
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

						extends = this.yep(AST.MemberExpression(extends, property, false, false))
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

			if this.test(Token::COMMA) {
				const variables = [variable]

				do {
					this.commit()

					variables.push(this.reqTypedVariable())
				}
				while this.test(Token::COMMA)

				const equals = this.reqVariableEquals()

				unless this.test(Token::AWAIT) {
					this.throw('await')
				}

				this.commit()

				let operand = this.reqPrefixedOperand(mode)

				operand = this.yep(AST.AwaitExpression(variables, false, operand, variable, operand))

				return this.yep(AST.VariableDeclaration(variables, false, equals, operand, first, operand))
			}
			else {
				const equals = this.reqVariableEquals()

				if this.test(Token::AWAIT) {
					this.commit()

					const variables = [variable]

					let operand = this.reqPrefixedOperand(mode)

					operand = this.yep(AST.AwaitExpression(variables, false, operand, variable, operand))

					return this.yep(AST.VariableDeclaration(variables, false, equals, operand, first, operand))
				}
				else {
					const expression = this.reqExpression(mode)

					return this.yep(AST.VariableDeclaration([variable], false, equals, expression, first, expression))
				}
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

				class = this.yep(AST.TypeReference(class, generic, null, class, generic))
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
			let first
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
				Token::CLASS => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqClassStatement(this.yes())))
				}
				Token::CONST => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqConstStatement(this.yes(), ExpressionMode::NoAwait)))
				}
				Token::ENUM => {
					return this.yep(AST.ExportDeclarationSpecifier(this.reqEnumStatement(this.yes())))
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

						value = this.yep(AST.MemberExpression(value, identifier, false, false))
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
					expressions.push(this.reqExpression(null, MacroTerminator::List))

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
		reqExternClassField(attributes, modifiers, name, type, first) ~ SyntaxError { // {{{
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

			const modifiers = []
			if this.match( Token::PRIVATE, Token::PROTECTED, Token::PUBLIC) == Token::PRIVATE {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Private, this.yes())))
			}
			else if @token == Token::PROTECTED {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Protected, this.yes())))
			}
			else if @token == Token::PUBLIC {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Public, this.yes())))
			}

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
			const type = this.tryFunctionReturns()

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

					if this.test(Token::COLON) {
						this.commit()

						const type = this.reqTypeVar()

						return this.yep(AST.VariableDeclarator(name, type, true, first, type))
					}
					else {
						return this.yep(AST.VariableDeclarator(name, null, true, first, name))
					}
				}
				Token::ENUM => {
					return this.reqExternEnumDeclaration(this.yes())
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

						if this.test(Token::COLON) {
							this.commit()

							const type = this.reqTypeVar()

							return this.yep(AST.VariableDeclarator(name, type, true, sealed, type))
						}
						else {
							return this.yep(AST.VariableDeclarator(name, null, true, sealed, name))
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
				Token::LET where ns => {
					const first = this.yes()
					const name = this.reqIdentifier()

					if this.test(Token::COLON) {
						this.commit()

						const type = this.reqTypeVar()

						return this.yep(AST.VariableDeclarator(name, type, false, first, type))
					}
					else {
						return this.yep(AST.VariableDeclarator(name, null, false, first, name))
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
				const type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()

				return this.yep(AST.FunctionDeclaration(name, parameters, modifiers, type, throws, null, first, throws ?? type ?? parameters))
			}
			else {
				const position = this.yep()
				const type = this.tryFunctionReturns()
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

				return this.yep(AST.VariableDeclarator(name, type, name, type))
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.reqFunctionParameterList()
				const type = this.tryFunctionReturns()

				return this.yep(AST.FunctionDeclaration(name, parameters, [], type, null, null, name, type ?? parameters))
			}
			else {
				return this.yep(AST.VariableDeclarator(name, null, name, name))
			}
		} // }}}
		reqForExpression(first) ~ SyntaxError { // {{{
			let declaration = false
			let rebindable = true

			if this.test(Token::LET) {
				this.commit()

				declaration = true
			}
			else if this.test(Token::CONST) {
				this.commit()

				declaration = true
				rebindable = false
			}

			let identifier1 = NO
			let identifier2 = NO
			let destructuring = NO

			if this.test(Token::COLON) {
				this.commit()

				identifier2 = this.reqIdentifier()
			}
			else {
				if !(destructuring = this.tryDestructuring()).ok {
					identifier1 = this.reqIdentifier()
				}

				if this.test(Token::COMMA) {
					this.commit()

					identifier2 = this.reqIdentifier()
				}
			}

			this.NL_0M()

			if destructuring.ok {
				if this.match(Token::IN, Token::OF) == Token::IN {
					this.commit()

					return this.altForExpressionIn(declaration, rebindable, destructuring, identifier2, this.reqExpression(ExpressionMode::Default), first)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(declaration, rebindable, destructuring, identifier2, first)
				}
				else {
					this.throw(['in', 'of'])
				}
			}
			else if identifier2.ok {
				if this.match(Token::IN, Token::OF) == Token::IN {
					this.commit()

					return this.altForExpressionInRange(declaration, rebindable, identifier1, identifier2, first)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(declaration, rebindable, identifier1, identifier2, first)
				}
				else {
					this.throw(['in', 'of'])
				}
			}
			else {
				if this.match(Token::FROM, Token::IN, Token::OF) == Token::FROM {
					this.commit()

					return this.altForExpressionFrom(declaration, rebindable, identifier1, first)
				}
				else if @token == Token::IN {
					this.commit()

					return this.altForExpressionInRange(declaration, rebindable, identifier1, identifier2, first)
				}
				else if @token == Token::OF {
					this.commit()

					return this.altForExpressionOf(declaration, rebindable, identifier1, identifier2, first)
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
		reqIdentifier() ~ SyntaxError { // {{{
			if @scanner.test(Token::IDENTIFIER) {
				return this.yep(AST.Identifier(@scanner.value(), this.yes()))
			}
			else {
				this.throw('Identifier')
			}
		} // }}}
		reqIfStatement(first) ~ SyntaxError { // {{{
			let condition
			if this.test(Token::LET, Token::CONST) {
				const mark = this.mark()
				const mutable = @token == Token::LET

				const first = this.yes()

				if this.test(Token::IDENTIFIER, Token::LEFT_CURLY, Token::LEFT_SQUARE) {
					const variable = this.reqTypedVariable()

					if this.test(Token::COMMA) {
						const variables = [variable]

						do {
							this.commit()

							variables.push(this.reqTypedVariable())
						}
						while this.test(Token::COMMA)

						const equals = this.reqVariableEquals()

						unless this.test(Token::AWAIT) {
							this.throw('await')
						}

						this.commit()

						const operand = this.reqPrefixedOperand(ExpressionMode::Default)

						condition = this.yep(AST.VariableDeclaration(variables, mutable, equals, operand, first, operand))
					}
					else {
						const equals = this.reqVariableEquals()

						if this.test(Token::AWAIT) {
							this.commit()

							const operand = this.reqPrefixedOperand(ExpressionMode::Default)

							condition = this.yep(AST.VariableDeclaration([variable], mutable, equals, operand, first, operand))
						}
						else {
							const expression = this.reqExpression(ExpressionMode::Default)

							condition = this.yep(AST.VariableDeclaration([variable], mutable, equals, expression, first, expression))
						}
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

			const modifiers = []

			if this.test(Token::OVERRIDE) {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Override, this.yes())))
			}

			if this.match(Token::PRIVATE, Token::PROTECTED, Token::PUBLIC) == Token::PRIVATE {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Private, this.yes())))

				mark = this.mark() if modifiers.length > 1
			}
			else if @token == Token::PROTECTED {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Protected, this.yes())))

				mark = this.mark() if modifiers.length > 1
			}
			else if @token == Token::PUBLIC {
				modifiers.push(this.yep(AST.Modifier(ModifierKind::Public, this.yes())))

				mark = this.mark() if modifiers.length > 1
			}

			if this.test(Token::STATIC) {
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
			let last = source

			let arguments = null
			if this.test(Token::LEFT_ROUND) {
				this.commit()

				arguments = []

				let name, modifiers
				while this.until(Token::RIGHT_ROUND) {
					name = this.reqExpression(ExpressionMode::Default)
					modifiers = []

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

			return this.yep(AST.ImportDeclarator(attributes, source, specifiers, arguments, source, last))
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
		reqIncludeStatement(first) ~ SyntaxError { // {{{
			if this.test(Token::LEFT_CURLY) {
				this.commit().reqNL_1M()

				const files = []

				until this.test(Token::RIGHT_CURLY) {
					if this.test(Token::STRING) {
						files.push(this.value())

						this.commit().reqNL_1M()
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				const last = this.yes()

				this.reqNL_EOF_1M()

				return this.yep(AST.IncludeDeclaration(files, first, last))
			}
			else {
				unless this.test(Token::STRING) {
					this.throw('String')
				}

				const files = [this.value()]
				const last = this.yes()

				this.reqNL_EOF_1M()

				return this.yep(AST.IncludeDeclaration(files, first, last))
			}
		} // }}}
		reqIncludeAgainStatement(first) ~ SyntaxError { // {{{
			if this.test(Token::LEFT_CURLY) {
				this.commit().reqNL_1M()

				const files = []

				until this.test(Token::RIGHT_CURLY) {
					if this.test(Token::STRING) {
						files.push(this.value())

						this.commit().reqNL_1M()
					}
					else {
						break
					}
				}

				unless this.test(Token::RIGHT_CURLY) {
					this.throw('}')
				}

				const last = this.yes()

				this.reqNL_EOF_1M()

				return this.yep(AST.IncludeAgainDeclaration(files, first, last))
			}
			else {
				unless this.test(Token::STRING) {
					this.throw('String')
				}

				const files = [this.value()]
				const last = this.yes()

				this.reqNL_EOF_1M()

				return this.yep(AST.IncludeAgainDeclaration(files, first, last))
			}
		} // }}}
		reqLetStatement(first, mode = ExpressionMode::Default) ~ SyntaxError { // {{{
			const variable = this.reqTypedVariable()

			if this.test(Token::COMMA) {
				const variables = [variable]

				do {
					this.commit()

					variables.push(this.reqTypedVariable())
				}
				while this.test(Token::COMMA)

				const equals = this.tryVariableEquals()

				if equals.ok {
					this.NL_0M()

					unless this.test(Token::AWAIT) {
						this.throw('await')
					}

					this.commit()

					let operand = this.reqPrefixedOperand(mode)

					operand = this.yep(AST.AwaitExpression(variables, false, operand, variable, operand))

					return this.yep(AST.VariableDeclaration(variables, true, equals, operand, first, operand))
				}
				else {
					return this.yep(AST.VariableDeclaration(variables, true, first, variables[variables.length - 1]))
				}
			}
			else {
				const equals = this.tryVariableEquals()

				if equals.ok {
					this.NL_0M()

					if this.test(Token::AWAIT) {
						this.commit()

						const variables = [variable]

						let operand = this.reqPrefixedOperand(mode)

						operand = this.yep(AST.AwaitExpression(variables, false, operand, variable, operand))

						return this.yep(AST.VariableDeclaration(variables, true, equals, operand, first, operand))
					}
					else {
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

						return this.yep(AST.VariableDeclaration([variable], true, equals, init, first, init))
					}
				}
				else {
					return this.yep(AST.VariableDeclaration([variable], true, first, variable))
				}
			}
		} // }}}
		reqMacroElements(elements, terminator) ~ SyntaxError { // {{{
			const history = []

			let literal = null
			let first, last

			const addLiteral = () => {
				if literal != null {
					elements.push(this.yep(AST.MacroElementLiteral(literal, first, last)))

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

							if identifier.length == 1 && (identifier == 'a' || identifier == 'b' || identifier == 'e' || identifier == 'i') && this.test(Token::LEFT_ROUND) {
								const reification = AST.MacroReification(identifier, last)

								this.commit()

								const expression = this.reqExpression(ExpressionMode::Default)

								unless this.test(Token::RIGHT_ROUND) {
									this.throw(')')
								}

								elements.push(this.yep(AST.MacroElementExpression(expression, reification, first, this.yes())))
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
				elements.push(this.yep(AST.MacroElementLiteral(literal, first, last)))
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

				return this.yep(AST.MacroExpression(elements, true, first, this.yes()))
			}
			else {
				if !first.ok {
					first = this.yep()
				}

				this.reqMacroElements(elements, terminator)

				return this.yep(AST.MacroExpression(elements, false, first, elements[elements.length - 1]))
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
				else if @token == Token::IMPORT {
					statement = this.reqImportStatement(this.yes())
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
			else {
				let first = modifiers.length == 0 ? null : modifiers[0]

				if this.match(Token::COLON, Token::COMMA, Token::IDENTIFIER) == Token::COLON {
					if first == null {
						first = this.yes()
					}
					else {
						this.commit()
					}

					const type = this.reqTypeVar()

					parameters.push(this.yep(AST.Parameter(null, type, modifiers, null, first, type)))

					if this.test(Token::COMMA) {
						this.commit()
					}
					else {
						return false
					}
				}
				else if @token == Token::COMMA {
					if first == null {
						first = this.yes()
						first.end = first.start
					}
					else {
						this.commit()
					}

					parameters.push(this.yep(AST.Parameter(null, null, modifiers, null, first, first)))
				}
				else if @token == Token::IDENTIFIER {
					parameters.push(this.reqParameterIdendifier(modifiers, first))

					if this.test(Token::COMMA) {
						this.commit()
					}
					else {
						return false
					}
				}
				else if this.test(Token::RIGHT_ROUND) {
					if first == null {
						first = this.yep()
						first.end = first.start
					}

					parameters.push(this.yep(AST.Parameter(null, null, modifiers, null, first, first)))

					return false
				}
				else {
					this.throw()
				}
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
				const expression = this.reqExpression(ExpressionMode::Default)

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
				conditions = bindings = filter = null

				switch this.match(Token::WITH, Token::WHERE, Token::EQUALS_RIGHT_ANGLE) {
					Token::EQUALS_RIGHT_ANGLE => {
						first = this.yes()
						body = this.reqSwitchCaseExpression()
					}
					Token::WHERE => {
						first = this.yes()

						filter = this.reqExpression(ExpressionMode::NoAnonymousFunction)

						this.NL_0M()

						unless this.test(Token::EQUALS_RIGHT_ANGLE) {
							this.throw('=>')
						}

						this.commit()

						body = this.reqSwitchCaseExpression()
					}
					Token::WITH => {
						first = this.yes()
						bindings = this.reqSwitchBinding()

						this.NL_0M()

						switch this.match(Token::WHERE, Token::EQUALS_RIGHT_ANGLE) {
							Token::EQUALS_RIGHT_ANGLE => {
								this.commit()

								body = this.reqSwitchCaseExpression()
							}
							Token::WHERE => {
								this.commit()

								filter = this.reqExpression(ExpressionMode::NoAnonymousFunction)

								this.NL_0M()

								unless this.test(Token::EQUALS_RIGHT_ANGLE) {
									this.throw('=>')
								}

								this.commit()

								body = this.reqSwitchCaseExpression()
							}
							=> {
								this.throw(['where', '=>'])
							}
						}
					}
					=> {
						first = this.reqSwitchCondition()

						conditions = [first]

						while this.test(Token::COMMA) {
							this.commit()

							conditions.push(this.reqSwitchCondition())
						}

						this.NL_0M()

						switch this.match(Token::WITH, Token::WHERE, Token::EQUALS_RIGHT_ANGLE) {
							Token::EQUALS_RIGHT_ANGLE => {
								this.commit()

								body = this.reqSwitchCaseExpression()
							}
							Token::WHERE => {
								this.commit()

								filter = this.reqExpression(ExpressionMode::NoAnonymousFunction)

								this.NL_0M()

								unless this.test(Token::EQUALS_RIGHT_ANGLE) {
									this.throw('=>')
								}

								this.commit()

								body = this.reqSwitchCaseExpression()
							}
							Token::WITH => {
								this.commit()

								bindings = this.reqSwitchBinding()

								this.NL_0M()

								switch this.match(Token::WHERE, Token::EQUALS_RIGHT_ANGLE) {
									Token::EQUALS_RIGHT_ANGLE => {
										this.commit()

										body = this.reqSwitchCaseExpression()
									}
									Token::WHERE => {
										this.commit()

										filter = this.reqExpression(ExpressionMode::NoAnonymousFunction)

										this.NL_0M()

										unless this.test(Token::EQUALS_RIGHT_ANGLE) {
											this.throw('=>')
										}

										this.commit()

										body = this.reqSwitchCaseExpression()
									}
									=> {
										this.throw(['where', '=>'])
									}
								}
							}
							=> {
								this.throw(['where', 'with', '=>'])
							}
						}
					}
				}

				this.reqNL_1M()

				clauses.push(AST.SwitchClause(conditions, bindings, filter, body, first, body))
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
						if this.test(Token::COMMA) {
							values.push(this.yep(AST.OmittedExpression([], this.yep())))
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
		reqTryStatement(first) ~ SyntaxError { // {{{
			this.NL_0M()

			const body = this.reqBlock()

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
					const type = this.tryFunctionReturns()
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
					const type = this.tryFunctionReturns()
					const throws = this.tryFunctionThrows()

					return this.yep(AST.FunctionExpression(parameters, null, type, throws, null, first, throws ?? type ?? parameters))
				}
				else {
					this.rollback(marker)
				}
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.reqFunctionParameterList()
				const type = this.tryFunctionReturns()
				const throws = this.tryFunctionThrows()

				return this.yep(AST.FunctionExpression(parameters, null, type, throws, null, parameters, throws ?? type ?? parameters))
			}

			let name = this.reqIdentifier()

			if this.testNS(Token::DOT) {
				let property

				do {
					this.commit()

					property = this.reqIdentifier()

					name = this.yep(AST.MemberExpression(name, property, false, false))
				}
				while this.testNS(Token::DOT)
			}
			let last = name

			let generic
			if this.testNS(Token::LEFT_ANGLE) {
				generic = last = this.reqTypeGeneric(this.yes())
			}

			if nullable == null && this.testNS(Token::QUESTION) {
				nullable = last = this.yes(true)
			}

			return this.yep(AST.TypeReference(name, generic, nullable, name, last))
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
							const type = this.tryFunctionReturns()
							const throws = this.tryFunctionThrows()

							const objectType = this.yep(AST.FunctionExpression(parameters, modifiers, type, null, null, parameters, type ?? parameters))

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
							const type = this.tryFunctionReturns()
							const throws = this.tryFunctionThrows()

							const objectType = this.yep(AST.FunctionExpression(parameters, null, type, null, null, parameters, type ?? parameters))

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
				const type = this.reqTypeEntity()

				let mark = this.mark()

				if isMultiLines {
					const types = [type]

					this.NL_0M()

					while this.test(Token::PIPE) {
						this.commit()

						if this.test(Token::PIPE) {
							this.commit()
						}

						this.NL_0M()

						types.push(this.reqTypeEntity())

						mark = this.mark()

						this.NL_0M()
					}

					this.rollback(mark)

					if types.length == 1 {
						return types[0]
					}
					else {
						return this.yep(AST.UnionType(types, type, types[types.length - 1]))
					}
				}
				else if this.match(Token::PIPE_PIPE, Token::PIPE) == Token::PIPE {
					this.commit()

					if this.test(Token::NEWLINE) {
						this.rollback(mark)

						return type
					}

					const types = [type]

					do {
						this.commit()

						types.push(this.reqTypeEntity())
					}
					while this.test(Token::PIPE)

					return this.yep(AST.UnionType(types, type, types[types.length - 1]))
				}
				else {
					return type
				}
			}
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

				type = this.yep(AST.FunctionExpression(parameters, null, type, null, null, parameters, type ?? parameters))
			}

			return this.yep(AST.ObjectMemberReference(identifier, type))
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

			return this.yep(AST.VariableDeclarator(name, type, name, type ?? name))
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

						value = this.yep(AST.CallExpression(AST.Scope(ScopeKind::Null), value, this.reqExpression0CNList(), false, value, this.yes()))
					}
					Token::ASTERISK_DOLLAR_LEFT_ROUND => {
						this.commit()

						const arguments = this.reqExpression0CNList()

						value = this.yep(AST.CallExpression(AST.Scope(ScopeKind::Argument, arguments.value.shift()), value, arguments, false, value, this.yes()))
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
					Token::DOT => {
						this.commit()

						value = this.yep(AST.MemberExpression(value, this.reqIdentifier(), false, false))
					}
					Token::EXCLAMATION_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CallMacroExpression(value, this.reqExpression0CNList(), value, this.yes()))
					}
					Token::LEFT_SQUARE => {
						this.commit()

						expression = this.reqExpression(ExpressionMode::Default)

						unless this.test(Token::RIGHT_SQUARE) {
							this.throw(']')
						}

						value = this.yep(AST.MemberExpression(value, expression, true, false, value, this.yes()))
					}
					Token::LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CallExpression(value, this.reqExpression0CNList(), value, this.yes()))
					}
					Token::NEWLINE => {
						mark = this.mark()

						this.commit().NL_0M()

						if this.test(Token::DOT) {
							this.commit()

							value = this.yep(AST.MemberExpression(value, this.reqIdentifier(), false, false))
						}
						else {
							this.rollback(mark)

							break
						}
					}
					Token::QUESTION_DOT => {
						this.commit()

						expression = this.reqIdentifier()

						value = this.yep(AST.MemberExpression(value, expression, false, true, value, expression))
					}
					Token::QUESTION_LEFT_ROUND => {
						this.commit()

						value = this.yep(AST.CallExpression(AST.Scope(ScopeKind::This), value, this.reqExpression0CNList(), true, value, this.yes()))
					}
					Token::QUESTION_LEFT_SQUARE => {
						this.commit()

						expression = this.reqExpression(ExpressionMode::Default)

						unless this.test(Token::RIGHT_SQUARE) {
							this.throw(']')
						}

						value = this.yep(AST.MemberExpression(value, expression, true, true, value, this.yes()))
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
		reqVariableEquals() ~ SyntaxError { // {{{
			if this.match(Token::EQUALS, Token::COLON_EQUALS) == Token::EQUALS {
				return this.yes(false)
			}
			else if @token == Token::COLON_EQUALS {
				return this.yes(true)
			}
			else {
				this.throw(['=', ':='])
			}
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

					object = this.yep(AST.MemberExpression(object, property, false, false))
				}
				else if @token == Token::LEFT_SQUARE {
					this.commit()

					property = this.reqExpression(ExpressionMode::Default)

					unless this.test(Token::RIGHT_SQUARE) {
						this.throw(']')
					}

					object = this.yep(AST.MemberExpression(object, property, true, false, object, this.yes()))
				}
				else {
					break
				}
			}

			return object
		} // }}}
		stackInnerAttributes(attributes) ~ SyntaxError { // {{{
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
		stackOuterAttributes(attributes) ~ SyntaxError { // {{{
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

					statement = this.yep(AST.AwaitExpression(variables, false, operand, identifier, operand))
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
		tryClassAbstractMethod(attributes, modifiers, first?) ~ SyntaxError { // {{{
			let name
			if this.test(Token::ASYNC) {
				let first = this.reqIdentifier()

				name = this.tryIdentifier()

				if name.ok {
					modifiers.push(this.yep(AST.Modifier(ModifierKind::Async, first)))
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
			let name
			if this.test(Token::ASYNC) {
				let async = this.reqIdentifier()

				name = this.tryIdentifier()

				if name.ok {
					modifiers.push(this.yep(AST.Modifier(ModifierKind::Async, async)))

					return this.reqClassMethod(attributes, modifiers, name, null, first ?? async)
				}
				else {
					name = async
				}
			}
			else if this.test(Token::AT) {
				const modifier = this.yep(AST.Modifier(ModifierKind::ThisAlias, this.yes()))
				const name = this.reqNameIST()

				if this.test(Token::COLON) {
					this.commit()

					const type = this.reqTypeVar()

					return this.reqClassField(attributes, [...modifiers, modifier], name, type, first ?? modifier)
				}
				else {
					return this.reqClassField(attributes, [...modifiers, modifier], name, null, first ?? modifier)
				}
			}
			else {
				name = this.tryIdentifier()

				unless name.ok {
					return NO
				}
			}

			return this.reqClassMemberBody(attributes, modifiers, name, first ?? name)
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
		tryExpression() ~ SyntaxError { // {{{
			try {
				return this.reqExpression(ExpressionMode::Default)
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

			if this.match(Token::LEFT_CURLY, Token::EQUALS_RIGHT_ANGLE) {
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
					const body = this.reqFunctionBody()

					return this.yep(AST.FunctionExpression(parameters, modifiers, type, null, body, first, body))
				}
				else {
					const parameters = this.tryFunctionParameterList()
					if !parameters.ok {
						return NO
					}

					const type = this.tryFunctionReturns()
					const body = this.reqFunctionBody()

					return this.yep(AST.LambdaExpression(parameters, modifiers, type, body, first, body))
				}
			}
			else if @token == Token::FUNC {
				const first = this.yes()

				const parameters = this.tryFunctionParameterList()
				if !parameters.ok {
					return NO
				}

				const type = this.tryFunctionReturns()
				const body = this.reqFunctionBody()

				return this.yep(AST.FunctionExpression(parameters, null, type, null, body, first, body))
			}
			else if @token == Token::LEFT_ROUND {
				const parameters = this.tryFunctionParameterList()
				const type = this.tryFunctionReturns()

				if !parameters.ok || !this.test(Token::EQUALS_RIGHT_ANGLE) {
					return NO
				}

				this.commit()

				if this.test(Token::LEFT_CURLY) {
					const body = this.reqBlock()

					return this.yep(AST.LambdaExpression(parameters, null, type, body, parameters, body))
				}
				else {
					const body = this.reqExpression(mode | ExpressionMode::NoObject)

					return this.yep(AST.LambdaExpression(parameters, null, type, body, parameters, body))
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

					return this.yep(AST.LambdaExpression(parameters, null, null, body, parameters, body))
				}
				else {
					const body = this.reqExpression(mode | ExpressionMode::NoObject)

					return this.yep(AST.LambdaExpression(parameters, null, null, body, parameters, body))
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
				while this.tryParameter(parameters, ParameterMode::Function) {
				}

				unless this.test(Token::RIGHT_ROUND) {
					return NO
				}
			}

			return this.yep(parameters, first, this.yes())
		} // }}}
		tryFunctionReturns() ~ SyntaxError { // {{{
			const mark = this.mark()

			this.NL_0M()

			if this.test(Token::COLON) {
				this.commit()

				return this.reqTypeVar()
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

				return this.yep(AST.NumericExpression(parseInt(data[2].replace(/\_/g, ''), parseInt(data[1])), this.yes()))
			}
			else if @token == Token::DECIMAL_NUMBER {
				return this.yep(AST.NumericExpression(parseFloat(@scanner.value().replace(/\_/g, ''), 10), this.yes()))
			}
			else {
				return NO
			}
		} // }}}
		tryOperand(mode) ~ SyntaxError { // {{{
			if this.matchM(M.OPERAND) == Token::AT {
				return this.reqThisExpression(this.yes())
			}
			else if @token == Token::AWAIT {
				return this.reqAwaitExpression(this.yes())
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
		tryParameter(parameters, mode) { // {{{
			try {
				return this.reqParameter(parameters, mode)
			}
			catch {
				return false
			}
		} // }}}
		tryPrefixedOperand(mode) ~ SyntaxError { // {{{
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
		tryVariableEquals() ~ SyntaxError { // {{{
			if this.match(Token::EQUALS, Token::COLON_EQUALS) == Token::EQUALS {
				return this.yes(false)
			}
			else if @token == Token::COLON_EQUALS {
				return this.yes(true)
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

			return this.yep(AST.WhileStatement(condition, body, first, body))
		} // }}}
	}

	export func parse(data: String) ~ SyntaxError { // {{{
		const parser = new Parser(data)

		return parser.reqModule()
	} // }}}
}

export Parser.parse