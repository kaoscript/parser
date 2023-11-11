namespace AST {
	# {{{
	var $comparison: Object<Boolean, BinaryOperatorKind> = {
		[BinaryOperatorKind.Addition]: false
		[BinaryOperatorKind.Assignment]: false
		[BinaryOperatorKind.BackwardPipeline]: false
		[BinaryOperatorKind.BitwiseAnd]: false
		[BinaryOperatorKind.BitwiseOr]: false
		[BinaryOperatorKind.BitwiseXor]: false
		[BinaryOperatorKind.BitwiseLeftShift]: false
		[BinaryOperatorKind.BitwiseRightShift]: false
		[BinaryOperatorKind.Division]: false
		[BinaryOperatorKind.Equality]: true
		[BinaryOperatorKind.EmptyCoalescing]: false
		[BinaryOperatorKind.ForwardPipeline]: false
		[BinaryOperatorKind.GreaterThan]: true
		[BinaryOperatorKind.GreaterThanOrEqual]: true
		[BinaryOperatorKind.Inequality]: true
		[BinaryOperatorKind.LessThan]: true
		[BinaryOperatorKind.LessThanOrEqual]: true
		[BinaryOperatorKind.LogicalAnd]: false
		[BinaryOperatorKind.LogicalImply]: false
		[BinaryOperatorKind.LogicalOr]: false
		[BinaryOperatorKind.LogicalXor]: false
		[BinaryOperatorKind.Match]: false
		[BinaryOperatorKind.Mismatch]: false
		[BinaryOperatorKind.Modulo]: false
		[BinaryOperatorKind.Multiplication]: false
		[BinaryOperatorKind.NullCoalescing]: false
		[BinaryOperatorKind.Quotient]: false
		[BinaryOperatorKind.Subtraction]: false
		[BinaryOperatorKind.TypeCasting]: false
		[BinaryOperatorKind.TypeEquality]: false
		[BinaryOperatorKind.TypeInequality]: false
	}

	var $polyadic: Object<Boolean, BinaryOperatorKind> = {
		[BinaryOperatorKind.Addition]: true
		[BinaryOperatorKind.Assignment]: false
		[BinaryOperatorKind.BitwiseAnd]: true
		[BinaryOperatorKind.BitwiseOr]: true
		[BinaryOperatorKind.BitwiseXor]: true
		[BinaryOperatorKind.BitwiseLeftShift]: true
		[BinaryOperatorKind.BitwiseRightShift]: true
		[BinaryOperatorKind.Division]: true
		[BinaryOperatorKind.EmptyCoalescing]: true
		[BinaryOperatorKind.LogicalAnd]: true
		[BinaryOperatorKind.LogicalImply]: true
		[BinaryOperatorKind.LogicalOr]: true
		[BinaryOperatorKind.LogicalXor]: true
		[BinaryOperatorKind.Modulo]: true
		[BinaryOperatorKind.Multiplication]: true
		[BinaryOperatorKind.NullCoalescing]: true
		[BinaryOperatorKind.Quotient]: true
		[BinaryOperatorKind.Subtraction]: true
		[BinaryOperatorKind.TypeCasting]: false
		[BinaryOperatorKind.TypeEquality]: false
		[BinaryOperatorKind.TypeInequality]: false
	}

	var $precedence: Object<Number, BinaryOperatorKind> = {
		[BinaryOperatorKind.Addition]: 13
		[BinaryOperatorKind.Assignment]: 3
		[BinaryOperatorKind.BackwardPipeline]: 20
		[BinaryOperatorKind.BitwiseAnd]: 12
		[BinaryOperatorKind.BitwiseOr]: 12
		[BinaryOperatorKind.BitwiseXor]: 12
		[BinaryOperatorKind.BitwiseLeftShift]: 12
		[BinaryOperatorKind.BitwiseRightShift]: 12
		[BinaryOperatorKind.Division]: 14
		[BinaryOperatorKind.Equality]: 8
		[BinaryOperatorKind.EmptyCoalescing]: 15
		[BinaryOperatorKind.ForwardPipeline]: 16
		[BinaryOperatorKind.GreaterThan]: 8
		[BinaryOperatorKind.GreaterThanOrEqual]: 8
		[BinaryOperatorKind.Inequality]: 8
		[BinaryOperatorKind.LessThan]: 8
		[BinaryOperatorKind.LessThanOrEqual]: 8
		[BinaryOperatorKind.LogicalAnd]: 6
		[BinaryOperatorKind.LogicalImply]: 5
		[BinaryOperatorKind.LogicalOr]: 5
		[BinaryOperatorKind.LogicalXor]: 5
		[BinaryOperatorKind.Match]: 8
		[BinaryOperatorKind.Mismatch]: 8
		[BinaryOperatorKind.Modulo]: 14
		[BinaryOperatorKind.Multiplication]: 14
		[BinaryOperatorKind.NullCoalescing]: 15
		[BinaryOperatorKind.Quotient]: 14
		[BinaryOperatorKind.Subtraction]: 13
		[BinaryOperatorKind.TypeCasting]: 8
		[BinaryOperatorKind.TypeEquality]: 8
		[BinaryOperatorKind.TypeInequality]: 8
	}

	var $rtl: Object<Boolean, BinaryOperatorKind> = {
		[BinaryOperatorKind.BackwardPipeline]: true
	}
	# }}}

	var CONDITIONAL_PRECEDENCE = 4

	func location(descriptor, start: Position, end: Position) { # {{{
		descriptor.start = start
		descriptor.end = end

		return descriptor
	} # }}}

	func location(descriptor, firstToken, lastToken? = null) { # {{{
		if lastToken == null {
			if !?descriptor.start {
				descriptor.start = firstToken.start
			}

			descriptor.end = firstToken.end
		}
		else {
			descriptor.start = firstToken.start

			descriptor.end = lastToken.end
		}

		return descriptor
	} # }}}

	export func pushAttributes(data, attributes: Array): Void { # {{{
		if #attributes {
			data.start = attributes[0].value.start

			while #attributes {
				data.attributes.unshift(attributes.pop().value)
			}
		}
	} # }}}

	export func pushModifier(data, modifier: Event) { # {{{
		data.modifiers.push(modifier.value)

		return location(data, modifier)
	} # }}}

	export func reorderExpression(operations) { # {{{
		var precedences = {}
		var mut precedenceList = []

		for var mut i from 1 to~ operations.length step 2 {
			if operations[i].kind == NodeKind.ConditionalExpression {
				if ?precedences[CONDITIONAL_PRECEDENCE] {
					precedences[CONDITIONAL_PRECEDENCE] += 1
				}
				else {
					precedences[CONDITIONAL_PRECEDENCE] = 1
				}

				precedenceList.push(CONDITIONAL_PRECEDENCE)

				i += 1
			}
			else {
				var precedence = $precedence[operations[i].operator.kind]

				if ?precedences[precedence] {
					precedences[precedence] += 1
				}
				else {
					precedences[precedence] = 1
				}

				precedenceList.push(precedence)
			}
		}

		precedenceList.sort(func(a, b) {
			return b - a
		})

		var dyn count, k, operator, left
		for var precedence in precedenceList {
			count = precedences[precedence]

			for k from 1 to~ operations.length step 2 while count > 0 {
				if operations[k].kind == NodeKind.ConditionalExpression {
					if precedence == CONDITIONAL_PRECEDENCE {
						count -= 1

						operator = operations[k]

						operator.condition = operations[k - 1]
						operator.whenTrue = operations[k + 1]
						operator.whenFalse = operations[k + 2]

						operator.start = operator.condition.start
						operator.end = operator.whenFalse.end

						operations.splice(k - 1, 4, operator)

						k -= 3
					}
					else {
						k += 1
					}
				}
				else if $precedence[operations[k].operator.kind] == precedence {
					if operations[k].kind == NodeKind.BinaryExpression && $rtl[operations[k].operator.kind] {
						var mut end = operations.length - 1

						for var i from k + 2 to~ operations.length step 2 {
							if !$rtl[operations[i].operator.kind] {
								end = i - 1
							}
						}

						var mut c = 0

						for var i from end - 1 down to k step 2 {
							operator = operations[i]

							operator.left = operations[i - 1]
							operator.right = operations[i + 1]

							operator.start = operator.left.start
							operator.end = operator.right.end

							operations[i - 1] = operator

							count -= 1
							c += 2
						}

						operations.splice(k, c)

						k -= c
					}
					else {
						count -= 1

						operator = operations[k]

						if operator.kind == NodeKind.BinaryExpression {
							left = operations[k - 1]

							if left.kind == NodeKind.BinaryExpression && operator.operator.kind == left.operator.kind && $polyadic[operator.operator.kind] {
								operator.kind = NodeKind.PolyadicExpression
								operator.start = left.start
								operator.end = operations[k + 1].end

								operator.operands = [left.left, left.right, operations[k + 1]]
							}
							else if left.kind == NodeKind.PolyadicExpression && operator.operator.kind == left.operator.kind {
								left.operands.push(operations[k + 1])
								left.end = operations[k + 1].end

								operator = left
							}
							else if $comparison[operator.operator.kind] {
								if left.kind == NodeKind.ComparisonExpression {
									left.values.push(operator.operator, operations[k + 1])
									left.end = operations[k + 1].end

									operator = left
								}
								else {
									operator = ComparisonExpression([left, operator.operator, operations[k + 1]])
								}
							}
							else if left.kind == NodeKind.BinaryExpression && operator.operator.kind == BinaryOperatorKind.Assignment && left.operator.kind == BinaryOperatorKind.Assignment && operator.operator.assignment == left.operator.assignment {
								operator.left = left.right
								operator.right = operations[k + 1]

								operator.start = operator.left.start
								operator.end = operator.right.end

								left.right = operator

								left.end = left.right.end

								operator = left
							}
							else {
								operator.left = left
								operator.right = operations[k + 1]

								operator.start = operator.left.start
								operator.end = operator.right.end
							}
						}
						else {
							operator.left = operations[k - 1]
							operator.right = operations[k + 1]

							operator.start = operator.left.start
							operator.end = operator.right.end
						}

						operations.splice(k - 1, 3, operator)

						k -= 2
					}
				}
			}
		}

		return operations[0]
	} # }}}

	export {
		func AccessorDeclaration(first) { # {{{
			return location({
				kind: NodeKind.AccessorDeclaration
			}, first)
		} # }}}

		func AccessorDeclaration(body, first, last) { # {{{
			return location({
				kind: NodeKind.AccessorDeclaration
				body: body.value
			}, first, last)
		} # }}}

		func ArrayBinding(elements, first, last) { # {{{
			return location({
				kind: NodeKind.ArrayBinding
				elements: [element.value for var element in elements]
			}, first, last)
		} # }}}

		func ArrayBindingElement(modifiers, internal?, type?, operator?, defaultValue?, first, last) { # {{{
			return location({
				kind: NodeKind.BindingElement
				modifiers
				internal: internal.value if ?internal
				type: type.value if ?type
				operator: operator.value if ?operator
				defaultValue: defaultValue.value if ?defaultValue
			}, first, last)
		} # }}}

		func ArrayComprehension(expression, loop, first, last) { # {{{
			return location({
				kind: NodeKind.ArrayComprehension
				modifiers: []
				expression: expression.value
				loop: loop.value
			}, first, last)
		} # }}}

		func ArrayExpression(values, first, last) { # {{{
			return location({
				kind: NodeKind.ArrayExpression
				modifiers: []
				values: [value.value for var value in values]
			}, first, last)
		} # }}}

		func ArrayRangeFI(from, til, by?, first, last) { # {{{
			var node = location({
				kind: NodeKind.ArrayRange
				from: from.value
				til: til.value
			}, first, last)

			if ?by {
				node.by = by.value
			}

			return node
		} # }}}

		func ArrayRangeFO(from, to, by?, first, last) { # {{{
			var node = location({
				kind: NodeKind.ArrayRange
				from: from.value
				to: to.value
			}, first, last)

			if ?by {
				node.by = by.value
			}

			return node
		} # }}}

		func ArrayRangeTI(then, til, by?, first, last) { # {{{
			var node = location({
				kind: NodeKind.ArrayRange
				then: then.value
				til: til.value
			}, first, last)

			if ?by {
				node.by = by.value
			}

			return node
		} # }}}

		func ArrayRangeTO(then, to, by?, first, last) { # {{{
			var node = location({
				kind: NodeKind.ArrayRange
				then: then.value
				to: to.value
			}, first, last)

			if ?by {
				node.by = by.value
			}

			return node
		} # }}}

		func ArrayType(modifiers, properties, rest?, first, last) { # {{{
			var node = location({
				kind: NodeKind.ArrayType
				modifiers: [modifier.value for var modifier in modifiers]
				properties: [property.value for var property in properties]
			}, first, last)

			if rest != null {
				node.rest = rest.value
			}

			return node
		} # }}}

		func AssignmentOperator(operator: AssignmentOperatorKind, first) { # {{{
			return location({
				kind: BinaryOperatorKind.Assignment
				assignment: operator
			}, first)
		} # }}}

		func AttributeDeclaration(declaration, first, last) { # {{{
			return location({
				kind: NodeKind.AttributeDeclaration
				declaration: declaration.value
			}, first, last)
		} # }}}

		func AttributeExpression(name, arguments, first, last) { # {{{
			return location({
				kind: NodeKind.AttributeExpression
				name: name.value
				arguments: [argument.value for var argument in arguments]
			}, first, last)
		} # }}}

		func AttributeOperation(name, value, first, last) { # {{{
			return location({
				kind: NodeKind.AttributeOperation
				name: name.value
				value: value.value
			}, first, last)
		} # }}}

		func AwaitExpression(modifiers, variables?, operand?, first, last) { # {{{
			return location({
				kind: NodeKind.AwaitExpression
				modifiers
				variables: [variable.value for var variable in variables] if ?variables
				operation: operand.value if ?operand
			}, first, last)
		} # }}}

		func BinaryExpression(operator) { # {{{
			return location({
				kind: NodeKind.BinaryExpression
				modifiers: []
				operator: operator.value
			}, operator)
		} # }}}

		func BinaryExpression(left, operator, right, first = left, last = right) { # {{{
			return location({
				kind: NodeKind.BinaryExpression
				modifiers: []
				operator: operator.value
				left: left.value
				right: right.value
			}, first, last)
		} # }}}

		func BinaryOperator(operator: BinaryOperatorKind, first) { # {{{
			return location({
				kind: operator
				modifiers: []
			}, first)
		} # }}}

		func BinaryOperator(modifiers, operator: BinaryOperatorKind, first) { # {{{
			return location({
				kind: operator
				modifiers
			}, first)
		} # }}}

		func BitmaskDeclaration(attributes, modifiers, name, type?, members, first, last) { # {{{
			var node = location({
				kind: NodeKind.BitmaskDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				members: members
			}, first, last)

			if type != null {
				node.type = type.value
			}

			return node
		} # }}}

		func Block(attributes, statements, first, last) { # {{{
			return location({
				kind: NodeKind.Block
				attributes: [attribute.value for var attribute in attributes]
				statements: [statement.value for var statement in statements]
			}, first, last)
		} # }}}

		func BlockStatement(label, body, first, last) { # {{{
			return location({
				kind: NodeKind.BlockStatement
				attributes: []
				label: label.value
				body: body.value
			}, first, last)
		} # }}}

		func BreakStatement(label?, first, last) { # {{{
			return location({
				kind: NodeKind.BreakStatement
				attributes: []
				label: label.value if ?label
			}, first, last)
		} # }}}

		func CallExpression(modifiers, scope = { kind: ScopeKind.This }, callee, arguments, first, last) { # {{{
			return location({
				kind: NodeKind.CallExpression
				modifiers
				scope
				callee: callee.value
				arguments: [argument.value for var argument in arguments.value]
			}, first, last)
		} # }}}

		func CatchClause(binding?, type?, body, first, last) { # {{{
			var node = location({
				kind: NodeKind.CatchClause
				body: body.value
			}, first, last)

			if binding != null {
				node.binding = binding.value
			}
			if type != null {
				node.type = type.value
			}

			return node
		} # }}}

		func ClassDeclaration(attributes, modifiers, name, version?, extends?, implements, members, first, last) { # {{{
			return location({
				kind: NodeKind.ClassDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				version: version.value if ?version
				extends: extends.value if ?extends
				implements: [implement.value for var implement in implements] if #implements
				members: [member.value for var member in members]
			}, first, last)
		} # }}}

		func ComparisonExpression(values) { # {{{
			return location({
				kind: NodeKind.ComparisonExpression
				modifiers: []
				values
			}, values[0], values[values.length - 1])
		} # }}}

		func ComputedPropertyName(expression, first, last) { # {{{
			return location({
				kind: NodeKind.ComputedPropertyName
				expression: expression.value
			}, first, last)
		} # }}}

		func ConditionalExpression(first) { # {{{
			return location({
				kind: NodeKind.ConditionalExpression
				modifiers: []
			}, first)
		} # }}}

		func ConditionalExpression(condition, whenTrue, whenFalse) { # {{{
			return location({
				kind: NodeKind.ConditionalExpression
				modifiers: []
				condition: condition.value
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value
			}, condition, whenFalse)
		} # }}}

		func ContinueStatement(label?, first, last) { # {{{
			return location({
				kind: NodeKind.ContinueStatement
				attributes: []
				label: label.value if ?label
			}, first, last)
		} # }}}

		func CurryExpression(scope, callee, arguments, first, last) { # {{{
			return location({
				kind: NodeKind.CurryExpression
				modifiers: []
				scope: scope
				callee: callee.value
				arguments: [argument.value for var argument in arguments.value]
			}, first, last)
		} # }}}

		func DeclarationSpecifier(declaration) { # {{{
			return location({
				kind: NodeKind.DeclarationSpecifier
				declaration: declaration.value
			}, declaration)
		} # }}}

		func DiscloseDeclaration(name, members, first, last) { # {{{
			return location({
				kind: NodeKind.DiscloseDeclaration
				attributes: []
				name: name.value
				members: [member.value for var member in members]
			}, first, last)
		} # }}}

		func DisruptiveExpression(operator: Event, condition: Event, mainExpression: Event, disruptedExpression: Event, first, last) { # {{{
			return location({
				kind: NodeKind.DisruptiveExpression
				operator: operator.value
				condition: condition.value
				mainExpression: mainExpression.value
				disruptedExpression: disruptedExpression.value
			}, first, last)
		} # }}}

		func DoUntilStatement(condition, body, first, last) { # {{{
			return location({
				kind: NodeKind.DoUntilStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} # }}}

		func DoWhileStatement(condition, body, first, last) { # {{{
			return location({
				kind: NodeKind.DoWhileStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} # }}}

		func EnumDeclaration(attributes, modifiers, name, type?, members, first, last) { # {{{
			var node = location({
				kind: NodeKind.EnumDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				members: members
			}, first, last)

			if type != null {
				node.type = type.value
			}

			return node
		} # }}}

		func ExclusionType(types, first, last) { # {{{
			return location({
				kind: NodeKind.ExclusionType
				types: [type.value for var type in types]
			}, first, last)
		} # }}}

		func ExportDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.ExportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
			}, first, last)
		} # }}}

		func ExpressionStatement(expression) { # {{{
			return location({
				kind: NodeKind.ExpressionStatement
				attributes: []
				expression: expression.value
			}, expression)
		} # }}}

		func ExternDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.ExternDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
			}, first, last)
		} # }}}

		func ExternOrImportDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.ExternOrImportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
			}, first, last)
		} # }}}

		func ExternOrRequireDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.ExternOrRequireDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
			}, first, last)
		} # }}}

		func FallthroughStatement(first) { # {{{
			return location({
				kind: NodeKind.FallthroughStatement
				attributes: []
			}, first)
		} # }}}

		func FieldDeclaration(attributes, modifiers, name, type?, value?, first, last) { # {{{
			var node = location({
				kind: NodeKind.FieldDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
			}, first, last)

			if type != null && type.ok {
				node.type = type.value
			}
			if value != null {
				node.value = value.value
			}

			return node
		} # }}}

		func ForStatement(iterations, body, else?, first, last) { # {{{
			return  location({
				kind: NodeKind.ForStatement
				attributes: []
				iterations: [iteration.value for var iteration in iterations]
				body: body.value
				else: else.value if ?else
			}, first, last)
		} # }}}

		func ForStatement(iteration, first, last) { # {{{
			return  location({
				kind: NodeKind.ForStatement
				attributes: []
				iteration: iteration.value
			}, first, last)
		} # }}}

		func FunctionDeclaration(name, typeParameters?, parameters?, modifiers?, type?, throws?, body?, first, last) { # {{{
			var node = location({
				kind: NodeKind.FunctionDeclaration
				attributes: []
				name: name.value
				typeParameters: [parameter.value for var parameter in typeParameters.value] if ?typeParameters
			}, first, last)

			if parameters != null {
				node.parameters = [parameter.value for var parameter in parameters.value]
			}

			if modifiers == null {
				node.modifiers = []
			}
			else {
				node.modifiers = [modifier.value for var modifier in modifiers]
			}

			if type != null {
				node.type = type.value
			}

			if throws == null {
				node.throws = []
			}
			else {
				node.throws = [throw.value for var throw in throws.value]
			}

			if body != null {
				node.body = body.value
			}

			return node
		} # }}}

		func FunctionExpression(parameters, modifiers?, type?, throws?, body?, first, last) { # {{{
			var node = location({
				kind: NodeKind.FunctionExpression
				parameters: [parameter.value for var parameter in parameters.value]
			}, first, last)

			if modifiers == null {
				node.modifiers = []
			}
			else {
				node.modifiers = [modifier.value for var modifier in modifiers]
			}

			if type != null {
				node.type = type.value
			}

			if throws == null {
				node.throws = []
			}
			else {
				node.throws = [throw.value for var throw in throws.value]
			}

			if body != null {
				node.body = body.value
			}

			return node
		} # }}}

		func FusionType(types, first, last) { # {{{
			return location({
				kind: NodeKind.FusionType
				types: [type.value for var type in types]
			}, first, last)
		} # }}}

		func GroupSpecifier(modifiers, elements, type?, first, last) { # {{{
			var node = location({
				kind: NodeKind.GroupSpecifier
				modifiers: [modifier.value for var modifier in modifiers]
				elements: [element.value for var element in elements]
			}, first, last)

			if type != null {
				node.type = type.value
			}

			return node
		} # }}}

		func IfExpression(condition?, declaration?, whenTrue, whenFalse, first, last) { # {{{
			var node = location({
				kind: NodeKind.IfExpression
				attributes: []
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value
			}, first, last)

			if condition != null {
				node.condition = condition.value
			}

			if declaration != null {
				node.declaration = declaration.value
			}

			return node
		} # }}}

		func IfStatement(condition: Event, whenTrue: Event, whenFalse: Event?, first, last) { # {{{
			return location({
				kind: NodeKind.IfStatement
				attributes: []
				condition: condition.value
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value if ?whenFalse
			}, first, last)
		} # }}}

		func IfStatement(declarations: [], whenTrue: Event, whenFalse: Event?, first, last) { # {{{
			return location({
				kind: NodeKind.IfStatement
				attributes: []
				declarations
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value if ?whenFalse
			}, first, last)
		} # }}}

		func ImplementDeclaration(attributes, variable, interface?, properties, first, last) { # {{{
			return location({
				kind: NodeKind.ImplementDeclaration
				attributes: [attribute.value for var attribute in attributes]
				variable: variable.value
				interface: interface.value if ?interface
				properties: [property.value for var property in properties]
			}, first, last)
		} # }}}

		func ImportDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.ImportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
			}, first, last)
		} # }}}

		func ImportDeclarator(attributes, modifiers, source, arguments?, type?, specifiers, first, last) { # {{{
			return location({
				kind: NodeKind.ImportDeclarator
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				source: source.value
				arguments: arguments if ?arguments
				type: type.value if ?type
				specifiers: [specifier.value for var specifier in specifiers]
			}, first, last)
		} # }}}

		func Identifier(name, first) { # {{{
			return location({
				kind: NodeKind.Identifier
				modifiers: []
				name: name
			}, first)
		} # }}}

		func IncludeAgainDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.IncludeAgainDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
			}, first, last)
		} # }}}

		func IncludeDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.IncludeDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
			}, first, last)
		} # }}}

		func IncludeDeclarator(file) { # {{{
			return location({
				kind: NodeKind.IncludeDeclarator
				attributes: []
				file: file.value
			}, file, file)
		} # }}}

		func IterationArray(modifiers, value, type, index, expression, from?, to?, step?, split?, until?, while?, when?, first, last) { # {{{
			return location({
				kind: IterationKind.Array
				modifiers
				expression: expression.value
				value: value.value if value.ok
				type: type.value if type.ok
				index: index.value if index.ok
				from: from.value if ?from
				to: to.value if ?to
				step: step.value if ?step
				split: split.value if ?split
				until: until.value if ?until
				while: while.value if ?while
				when: when.value if ?when
			}, first, last)
		} # }}}

		func IterationFrom(modifiers, variable, from, to, step?, until?, while?, when?, first, last) { # {{{
			return location({
				kind: IterationKind.From
				modifiers
				variable: variable.value
				from: from.value
				to: to.value
				step: step.value if ?step
				until: until.value if ?until
				while: while.value if ?while
				when: when.value if ?when
			}, first, last)
		} # }}}

		func IterationObject(modifiers, value, type, key, expression, until?, while?, when?, first, last) { # {{{
			return location({
				kind: IterationKind.Object
				modifiers
				expression: expression.value
				value: value.value if value.ok
				type: type.value if type.ok
				key: key.value if key.ok
				until: until.value if ?until
				while: while.value if ?while
				when: when.value if ?when
			}, first, last)
		} # }}}

		func IterationRange(modifiers, value, index, from, to, step?, until?, while?, when?, first, last) { # {{{
			return location({
				kind: IterationKind.Range
				modifiers
				value: value.value
				index: index.value if index.ok
				from: from.value
				to: to.value
				step: step.value if ?step
				until: until.value if ?until
				while: while.value if ?while
				when: when.value if ?when
			}, first, last)
		} # }}}

		func JunctionExpression(operator, operands) { # {{{
			return location({
				kind: NodeKind.JunctionExpression
				modifiers: []
				operator: operator.value
				operands
			}, operands[0], operands[operands.length - 1])
		} # }}}

		func LambdaExpression(parameters, modifiers?, type?, throws?, body, first, last) { # {{{
			var node = location({
				kind: NodeKind.LambdaExpression
				modifiers: []
				parameters: [parameter.value for var parameter in parameters.value]
				body: body.value
			}, first, last)

			if modifiers != null {
				node.modifiers = [modifier.value for var modifier in modifiers]
			}

			if type != null {
				node.type = type.value
			}

			if throws == null {
				node.throws = []
			}
			else {
				node.throws = [throw.value for var throw in throws.value]
			}

			return node
		} # }}}

		func Literal(modifiers?, value, first, last? = null) { # {{{
			return location({
				kind: NodeKind.Literal
				modifiers: ?modifiers ? [modifier.value for var modifier in modifiers] : []
				value
			}, first, last)
		} # }}}

		func MacroDeclaration(attributes, name, parameters, body, first, last) { # {{{
			return location({
				kind: NodeKind.MacroDeclaration
				attributes: [attribute.value for var attribute in attributes]
				name: name.value
				parameters: [parameter.value for var parameter in parameters.value]
				body: body.value
			}, first, last)
		} # }}}

		func MacroExpression(elements, first, last) { # {{{
			return location({
				kind: NodeKind.MacroExpression
				attributes: []
				elements: [element.value for var element in elements]
			}, first, last)
		} # }}}

		func MacroElementExpression(expression, reification?, first, last) { # {{{
			var node = location({
				kind: MacroElementKind.Expression
				expression: expression.value
			}, first, last)

			if reification != null {
				node.reification = reification
			}

			return node
		} # }}}

		func MacroElementLiteral(value, first, last) { # {{{
			return location({
				kind: MacroElementKind.Literal
				value: value
			}, first, last)
		} # }}}

		func MacroElementNewLine(first) { # {{{
			return location({
				kind: MacroElementKind.NewLine
			}, first)
		} # }}}

		func MatchClause(conditions?, binding?, filter?, body, first, last) { # {{{
			return location({
				kind: NodeKind.MatchClause
				conditions: if ?conditions {
						set [condition.value for var condition in conditions]
					}
					else {
						set []
					}
				binding: binding.value if ?binding
				filter: filter.value if ?filter
				body: body.value
			}, first, last)
		} # }}}

		func MatchConditionArray(values, first, last) { # {{{
			return location({
				kind: NodeKind.MatchConditionArray
				values: [value.value for var value in values]
			}, first, last)
		} # }}}

		func MatchConditionObject(properties, first, last) { # {{{
			return location({
				kind: NodeKind.MatchConditionObject
				properties: [property.value for var property in properties]
			}, first, last)
		} # }}}

		func MatchConditionRangeFI(from, til) { # {{{
			return location({
				kind: NodeKind.MatchConditionRange
				from: from.value
				til: til.value
			}, from, til)
		} # }}}

		func MatchConditionRangeFO(from, to) { # {{{
			return location({
				kind: NodeKind.MatchConditionRange
				from: from.value
				to: to.value
			}, from, to)
		} # }}}

		func MatchConditionRangeTI(then, til) { # {{{
			return location({
				kind: NodeKind.MatchConditionRange
				then: then.value
				til: til.value
			}, then, til)
		} # }}}

		func MatchConditionRangeTO(then, to) { # {{{
			return location({
				kind: NodeKind.MatchConditionRange
				then: then.value
				to: to.value
			}, then, to)
		} # }}}

		func MatchConditionType(type, first, last) { # {{{
			return location({
				kind: NodeKind.MatchConditionType
				type: type.value
			}, first, last)
		} # }}}

		func MatchExpression(expression, clauses, first, last) { # {{{
			return location({
				kind: NodeKind.MatchExpression
				attributes: []
				expression: expression.value
				clauses: [clause for var clause in clauses.value]
			}, first, last)
		} # }}}

		func MatchStatement(expression?, declaration?, clauses, first, last) { # {{{
			return location({
				kind: NodeKind.MatchStatement
				attributes: []
				expression: expression.value if ?expression
				declaration: declaration.value if ?declaration
				clauses: [clause for var clause in clauses.value]
			}, first, last)
		} # }}}

		func MemberExpression(modifiers, object?, property, first = object, last = property) { # {{{
			return location({
				kind: NodeKind.MemberExpression
				modifiers
				object: object.value if ?object
				property: property.value
			}, first, last)
		} # }}}

		func MethodDeclaration(attributes, typeParameters?, modifiers, name, parameters, type?, throws?, body?, first, last) { # {{{
			var node = location({
				kind: NodeKind.MethodDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				typeParameters: [parameter.value for var parameter in typeParameters.value] if ?typeParameters
				parameters: [parameter.value for var parameter in parameters.value]
			}, first, last)

			if type != null {
				node.type = type.value
			}

			if throws == null {
				node.throws = []
			}
			else {
				node.throws = [throw.value for var throw in throws.value]
			}

			if body != null {
				node.body = body.value
			}

			return node
		} # }}}

		func Modifier(kind: ModifierKind, first, last? = null) { # {{{
			return location({
				kind: kind
			}, first, last)
		} # }}}

		func Module(attributes, body, parser: Parser) { # {{{
			return location({
				kind: NodeKind.Module
				attributes: [attribute.value for var attribute in attributes]
				body: body,
				start: {
					line: 1
					column: 1
				}
			}, parser.position())
		} # }}}

		func MutatorDeclaration(first) { # {{{
			return location({
				kind: NodeKind.MutatorDeclaration
			}, first)
		} # }}}

		func MutatorDeclaration(body, first, last) { # {{{
			return location({
				kind: NodeKind.MutatorDeclaration
				body: body.value
			}, first, last)
		} # }}}

		func NamedArgument(modifiers, name, value, first, last) { # {{{
			return location({
				kind: NodeKind.NamedArgument
				modifiers
				name: name.value
				value: value.value
			}, first, last)
		} # }}}

		func NamedSpecifier(internal) { # {{{
			return location({
				kind: NodeKind.NamedSpecifier
				modifiers: []
				internal: internal.value
			}, internal, internal)
		} # }}}

		func NamedSpecifier(modifiers, internal, external?, first, last) { # {{{
			return location({
				kind: NodeKind.NamedSpecifier
				modifiers: [modifier.value for var modifier in modifiers]
				internal: internal.value
				external: external.value if ?external
			}, first, last)
		} # }}}

		func NamespaceDeclaration(attributes, modifiers, name, statements, first, last) { # {{{
			return location({
				kind: NodeKind.NamespaceDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				statements: [statement.value for var statement in statements]
			}, first, last)
		} # }}}

		func NumericExpression(value, radix, first) { # {{{
			return location({
				kind: NodeKind.NumericExpression
				modifiers: []
				value
				radix
			}, first)
		} # }}}

		func ObjectBinding(elements, first, last) { # {{{
			return location({
				kind: NodeKind.ObjectBinding
				elements: [element.value for var element in elements]
			}, first, last)
		} # }}}

		func ObjectBindingElement(modifiers, external?, internal?, type?, operator?, defaultValue?, first, last) { # {{{
			return location({
				kind: NodeKind.BindingElement
				modifiers
				external: external.value if ?external
				internal: internal.value if ?internal
				type: type.value if ?type
				operator: operator.value if ?operator
				defaultValue: defaultValue.value if ?defaultValue
			}, first, last)
		} # }}}

		func ObjectExpression(attributes, properties, first, last) { # {{{
			return location({
				kind: NodeKind.ObjectExpression
				modifiers: []
				attributes: [attribute.value for var attribute in attributes]
				properties: [property.value for var property in properties]
			}, first, last)
		} # }}}

		func ObjectMember(attributes, modifiers, name?, type?, value?, first, last) { # {{{
			var node = location({
				kind: NodeKind.ObjectMember
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
			}, first, last)

			if name != null {
				node.name = name.value
			}
			if type != null {
				node.type = type.value
			}
			if value != null {
				node.value = value.value
			}

			return node
		} # }}}

		func ObjectType(modifiers, properties, rest?, first, last) { # {{{
			var node = location({
				kind: NodeKind.ObjectType
				modifiers: [modifier.value for var modifier in modifiers]
				properties: [property.value for var property in properties]
			}, first, last)

			if rest != null {
				node.rest = rest.value
			}

			return node
		} # }}}

		func OmittedExpression(modifiers, first) { # {{{
			var node = location({
				kind: NodeKind.OmittedExpression
				modifiers
			}, first, first)

			return node
		} # }}}

		func OmittedReference(first) { # {{{
			return location({
				kind: NodeKind.TypeReference
				modifiers: []
			}, first, first)
		} # }}}

		func PassStatement(first) { # {{{
			return location({
				kind: NodeKind.PassStatement
				attributes: []
			}, first, first)
		} # }}}

		func Parameter(name) { # {{{
			return location({
				kind: NodeKind.Parameter
				attributes: []
				modifiers: []
				internal: name.value
				external: name.value
			}, name, name)
		} # }}}

		func Parameter(attributes, modifiers, external?, internal?, type?, operator?, defaultValue?, first, last) { # {{{
			return location({
				kind: NodeKind.Parameter
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				external: external.value if ?external
				internal: internal.value if ?internal
				type: type.value if ?type
				operator: operator.value if ?operator
				defaultValue: defaultValue.value if ?defaultValue
			}, first, last)
		} # }}}

		func PlaceholderArgument(modifiers, index?, first, last) { # {{{
			return location({
				kind: NodeKind.PlaceholderArgument
				modifiers: [modifier.value for var modifier in modifiers]
				index: index.value if ?index
			}, first, last)
		} # }}}

		func PositionalArgument(modifiers, value, first, last) { # {{{
			return location({
				kind: NodeKind.PositionalArgument
				modifiers
				value: value.value
			}, first, last)
		} # }}}

		func PropertiesSpecifier(modifiers, object, properties, first, last) { # {{{
			return location({
				kind: NodeKind.PropertiesSpecifier
				modifiers: [modifier.value for var modifier in modifiers]
				object: object.value
				properties: [property.value for var property in properties]
			}, first, last)
		} # }}}

		func PropertyDeclaration(attributes, modifiers, name, type?, defaultValue?, accessor?, mutator?, first, last) { # {{{
			var node = location({
				kind: NodeKind.PropertyDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
			}, first, last)

			if type != null && type.ok {
				node.type = type.value
			}
			if defaultValue != null {
				node.defaultValue = defaultValue.value
			}
			if accessor != null {
				node.accessor = accessor.value
			}
			if mutator != null {
				node.mutator = mutator.value
			}

			return node
		} # }}}

		func PropertyType(modifiers, name?, type?, first, last) { # {{{
			var node = location({
				kind: NodeKind.PropertyType
				modifiers: [modifier.value for var modifier in modifiers]
			}, first, last)

			if name != null {
				node.name = name.value
			}
			if type != null {
				node.type = type.value
			}

			return node
		} # }}}

		func ProxyDeclaration(attributes, modifiers, internal, external, first, last) { # {{{
			return location({
				kind: NodeKind.ProxyDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				internal: internal.value
				external: external.value
			}, first, last)
		} # }}}

		func ProxyGroupDeclaration(attributes, modifiers, recipient, elements, first, last) { # {{{
			return location({
				kind: NodeKind.ProxyGroupDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				recipient: recipient.value
				elements: [element.value for var element in elements]
			}, first, last)
		} # }}}

		func Reference(name: String, first) { # {{{
			return location({
				kind: NodeKind.Reference
				name
			}, first)
		} # }}}

		func RegularExpression(value, first) { # {{{
			return location({
				kind: NodeKind.RegularExpression
				modifiers: []
				value: value
			}, first)
		} # }}}

		func Reification(kind: ReificationKind, first: Event, last: Event? = null) { # {{{
			return location({
				kind: kind
			}, first, last)
		} # }}}

		func RepeatStatement(expression?, body?, first, last) { # {{{
			return location({
				kind: NodeKind.RepeatStatement
				attributes: []
				expression: expression.value if ?expression
				body: body.value if ?body
			}, first, last)
		} # }}}

		func RequireDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.RequireDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
			}, first, last)
		} # }}}

		func RequireOrExternDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.RequireOrExternDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
			}, first, last)
		} # }}}

		func RequireOrImportDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.RequireOrImportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
			}, first, last)
		} # }}}

		func RestModifier(min, max, first, last) { # {{{
			return location({
				kind: ModifierKind.Rest
				arity: {
					min: min
					max: max
				}
			}, first, last)
		} # }}}

		func RestrictiveExpression(operator: Event, condition: Event, expression: Event, first, last) { # {{{
			return location({
				kind: NodeKind.RestrictiveExpression
				operator: operator.value
				condition: condition.value
				expression: expression.value
			}, first, last)
		} # }}}

		func RestrictiveOperator(operator: RestrictiveOperatorKind, first) { # {{{
			return location({
				kind: operator
				modifiers: []
			}, first)
		} # }}}

		func ReturnStatement(first) { # {{{
			return location({
				kind: NodeKind.ReturnStatement
				attributes: []
			}, first, first)
		} # }}}

		func ReturnStatement(value, first, last) { # {{{
			return location({
				kind: NodeKind.ReturnStatement
				attributes: []
				value: value.value
			}, first, last)
		} # }}}

		func RollingExpression(modifiers, object, expressions, first, last) { # {{{
			return location({
				kind: NodeKind.RollingExpression
				modifiers
				object: object.value
				expressions: [expression.value for var expression in expressions]
			}, first, last)
		} # }}}

		func Scope(scope: ScopeKind) { # {{{
			return {
				kind: scope
			}
		} # }}}

		func Scope(scope: ScopeKind, value) { # {{{
			return {
				kind: scope
				value: value.value
			}
		} # }}}

		func SequenceExpression(expressions, first, last) { # {{{
			return location({
				kind: NodeKind.SequenceExpression
				modifiers: []
				expressions: [expression.value for var expression in expressions]
			}, first, last)
		} # }}}

		func SetStatement(first) { # {{{
			return location({
				kind: NodeKind.SetStatement
				attributes: []
			}, first, first)
		} # }}}

		func SetStatement(value, first, last) { # {{{
			return location({
				kind: NodeKind.SetStatement
				attributes: []
				value: value.value
			}, first, last)
		} # }}}

		func ShebangDeclaration(command, first, last) { # {{{
			return location({
				kind: NodeKind.ShebangDeclaration
				command
			}, first, last)
		} # }}}

		func ShorthandProperty(attributes, name, first, last) { # {{{
			return location({
				kind: NodeKind.ShorthandProperty
				attributes: [attribute.value for var attribute in attributes]
				name: name.value
			}, first, last)
		} # }}}

		func SpreadExpression(modifiers, operand, members, first, last) { # {{{
			return location({
				kind: NodeKind.SpreadExpression
				attributes: []
				modifiers: [modifier.value for var modifier in modifiers]
				operand: operand.value
				members: [member.value for var member in members]
			}, first, last)
		} # }}}

		func StructDeclaration(attributes, modifiers, name, extends?, implements, fields, first, last) { # {{{
			return location({
				kind: NodeKind.StructDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				extends: extends.value if ?extends
				implements: [implement.value for var implement in implements] if #implements
				fields
			}, first, last)
		} # }}}

		func StructField(attributes, modifiers, name, type?, defaultValue?, first, last) { # {{{
			var node = location({
				kind: NodeKind.StructField
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
			}, first, last)

			if ?type {
				node.type = type.value
			}

			if ?defaultValue {
				node.defaultValue = defaultValue.value
			}

			return node
		} # }}}

		func TaggedTemplateExpression(tag, template, first, last) { # {{{
			return location({
				kind: NodeKind.TaggedTemplateExpression
				tag: tag.value
				template: template.value
			}, first, last)
		} # }}}

		func TemplateExpression(modifiers?, elements, first, last?) { # {{{
			var node = location({
				kind: NodeKind.TemplateExpression
				modifiers: []
				elements: [element.value for var element in elements]
			}, first, last)

			if modifiers != null {
				node.modifiers = [modifier.value for var modifier in modifiers]
			}

			return node
		} # }}}

		func ThisExpression(name, first, last) { # {{{
			return location({
				kind: NodeKind.ThisExpression
				modifiers: []
				name: name.value
			}, first, last)
		} # }}}

		func ThrowStatement(first) { # {{{
			return location({
				kind: NodeKind.ThrowStatement
				attributes: []
			}, first)
		} # }}}

		func ThrowStatement(value, first, last) { # {{{
			return location({
				kind: NodeKind.ThrowStatement
				attributes: []
				value: value.value
			}, first, last)
		} # }}}

		func TopicReference(modifiers = [], first) { # {{{
			return location({
				kind: NodeKind.TopicReference
				modifiers
			}, first)
		} # }}}

		func TryExpression(modifiers, operand, defaultValue?, first, last) { # {{{
			var node = location({
				kind: NodeKind.TryExpression
				modifiers
				argument: operand.value
			}, first, last)

			if defaultValue != null {
				node.defaultValue = defaultValue.value
			}

			return node
		} # }}}

		func TryStatement(body, catchClauses, catchClause?, finalizer?, first, last) { # {{{
			var node = location({
				kind: NodeKind.TryStatement
				attributes: []
				body: body.value
				catchClauses: [clause.value for var clause in catchClauses]
			}, first, last)

			if catchClause != null {
				node.catchClause = catchClause.value
			}
			if finalizer != null {
				node.finalizer = finalizer.value
			}

			return node
		} # }}}

		func TupleDeclaration(attributes, modifiers, name, extends?, implements, fields, first, last) { # {{{
			return location({
				kind: NodeKind.TupleDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				extends: extends.value if ?extends
				implements: [implement.value for var implement in implements] if #implements
				fields
			}, first, last)
		} # }}}

		func TupleField(attributes, modifiers, name?, type?, defaultValue?, first, last) { # {{{
			return location({
				kind: NodeKind.TupleField
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value if ?name
				type: type.value if ?type
				defaultValue: defaultValue.value if ?defaultValue
			}, first, last)
		} # }}}

		func TypeParameter(name) { # {{{
			return location({
				kind: NodeKind.TypeParameter
				modifiers: []
				name: name.value
			}, name)
		} # }}}

		func TypeReference(name) { # {{{
			return location({
				kind: NodeKind.TypeReference
				modifiers: []
				typeName: name.value
			}, name)
		} # }}}

		func TypeReference(modifiers, name, parameters?, typeSubtypes?, first, last) { # {{{
			return location({
				kind: NodeKind.TypeReference
				modifiers: [modifier.value for var modifier in modifiers]
				typeName: name.value
				typeParameters: [parameter.value for var parameter in parameters.value] if ?parameters
				typeSubtypes: [typeSubtype.value for var typeSubtype in typeSubtypes.value] if ?typeSubtypes
			}, first, last)
		} # }}}

		func TypeAliasDeclaration(name, parameters?, type, first, last) { # {{{
			return location({
				kind: NodeKind.TypeAliasDeclaration
				attributes: []
				name: name.value
				typeParameters: [parameter.value for var parameter in parameters.value] if ?parameters
				type: type.value
			}, first, last)
		} # }}}

		func TypeList(attributes, types, first, last) { # {{{
			return location({
				kind: NodeKind.TypeList
				attributes: [attribute.value for var attribute in attributes]
				types: [type.value for var type in types]
			}, first, last)
		} # }}}

		func TypedSpecifier(type, first) { # {{{
			return location({
				kind: NodeKind.TypedSpecifier
				type: type.value
			}, first)
		} # }}}

		func UnaryExpression(modifiers, operator, operand, first, last) { # {{{
			return location({
				kind: NodeKind.UnaryExpression
				modifiers: [modifier.value for var modifier in modifiers]
				operator: operator.value
				argument: operand.value
			}, first, last)
		} # }}}

		func UnaryOperator(operator: UnaryOperatorKind, first) { # {{{
			return location({
				kind: operator
			}, first)
		} # }}}

		func UnaryTypeExpression(modifiers, operator, operand, first, last) { # {{{
			return location({
				kind: NodeKind.UnaryTypeExpression
				modifiers: [modifier.value for var modifier in modifiers]
				operator: operator.value
				argument: operand.value
			}, first, last)
		} # }}}

		func UnaryTypeOperator(operator: UnaryTypeOperatorKind, first) { # {{{
			return location({
				kind: operator
			}, first)
		} # }}}

		func UnionType(types, first, last) { # {{{
			return location({
				kind: NodeKind.UnionType
				types: [type.value for var type in types]
			}, first, last)
		} # }}}

		func UnlessStatement(condition, whenFalse, first, last) { # {{{
			return location({
				kind: NodeKind.UnlessStatement
				attributes: []
				condition: condition.value
				whenFalse: whenFalse.value
			}, first, last)
		} # }}}

		func UntilStatement(condition, body, first, last) { # {{{
			return location({
				kind: NodeKind.UntilStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} # }}}

		func VariableDeclaration(attributes, modifiers, variables, operator?, value?, first, last) { # {{{
			var node = location({
				kind: NodeKind.VariableDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				variables: [variable.value for var variable in variables]
			}, first, last)

			if operator != null {
				node.operator = operator.value
			}
			if value != null {
				node.value = value.value
			}

			return node
		} # }}}

		func VariableDeclarator(modifiers, name, type?, first, last) { # {{{
			var node = location({
				kind: NodeKind.VariableDeclarator
				attributes: []
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
			}, first, last)

			if type != null {
				node.type = type.value
			}

			return node
		} # }}}

		func VariableStatement(attributes, modifiers, declarations, first, last) { # {{{
			return location({
				kind: NodeKind.VariableStatement
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				declarations: [declaration.value for var declaration in declarations]
			}, first, last)
		} # }}}

		func VariantDeclaration(attributes, modifiers, name, fields, first, last) { # {{{
			return location({
				kind: NodeKind.VariantDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				fields
			}, first, last)
		} # }}}

		func VariantField(names, type?, first, last) { # {{{
			return location({
				kind: NodeKind.VariantField
				attributes: []
				modifiers: []
				names: [name.value for var name in names]
				type: type.value if ?type
			}, first, last)
		} # }}}

		func VariantType(master, properties, first, last) { # {{{
			return location({
				kind: NodeKind.VariantType
				master: master.value
				properties
			}, first, last)
		} # }}}

		func WhileStatement(condition, body, first, last) { # {{{
			return location({
				kind: NodeKind.WhileStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} # }}}

		func WithStatement(variables, body, finalizer?, first, last) { # {{{
			var node = location({
				kind: NodeKind.WithStatement
				attributes: []
				variables: [variable.value for var variable in variables]
				body: body.value
			}, first, last)

			if finalizer != null {
				node.finalizer = finalizer.value
			}

			return node
		} # }}}
	}
}
