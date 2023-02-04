namespace AST {
	# {{{
	var $comparison = {
		[BinaryOperatorKind::Addition]: false
		[BinaryOperatorKind::And]: false
		[BinaryOperatorKind::Assignment]: false
		[BinaryOperatorKind::Division]: false
		[BinaryOperatorKind::Equality]: true
		[BinaryOperatorKind::EmptyCoalescing]: false
		[BinaryOperatorKind::GreaterThan]: true
		[BinaryOperatorKind::GreaterThanOrEqual]: true
		[BinaryOperatorKind::Imply]: false
		[BinaryOperatorKind::Inequality]: true
		[BinaryOperatorKind::LeftShift]: false
		[BinaryOperatorKind::LessThan]: true
		[BinaryOperatorKind::LessThanOrEqual]: true
		[BinaryOperatorKind::Match]: false
		[BinaryOperatorKind::Mismatch]: false
		[BinaryOperatorKind::Modulo]: false
		[BinaryOperatorKind::Multiplication]: false
		[BinaryOperatorKind::NullCoalescing]: false
		[BinaryOperatorKind::Or]: false
		[BinaryOperatorKind::Quotient]: false
		[BinaryOperatorKind::RightShift]: false
		[BinaryOperatorKind::Subtraction]: false
		[BinaryOperatorKind::TypeCasting]: false
		[BinaryOperatorKind::TypeEquality]: false
		[BinaryOperatorKind::TypeInequality]: false
		[BinaryOperatorKind::Xor]: false
	}

	var $polyadic = {
		[BinaryOperatorKind::Addition]: true
		[BinaryOperatorKind::And]: true
		[BinaryOperatorKind::Assignment]: false
		[BinaryOperatorKind::Division]: true
		[BinaryOperatorKind::EmptyCoalescing]: true
		[BinaryOperatorKind::Imply]: true
		[BinaryOperatorKind::LeftShift]: true
		[BinaryOperatorKind::Modulo]: true
		[BinaryOperatorKind::Multiplication]: true
		[BinaryOperatorKind::NullCoalescing]: true
		[BinaryOperatorKind::Or]: true
		[BinaryOperatorKind::Quotient]: true
		[BinaryOperatorKind::RightShift]: true
		[BinaryOperatorKind::Subtraction]: true
		[BinaryOperatorKind::TypeCasting]: false
		[BinaryOperatorKind::TypeEquality]: false
		[BinaryOperatorKind::TypeInequality]: false
		[BinaryOperatorKind::Xor]: true
	}

	var $precedence = {
		[BinaryOperatorKind::Addition]: 13
		[BinaryOperatorKind::And]: 6
		[BinaryOperatorKind::Assignment]: 3
		[BinaryOperatorKind::Division]: 14
		[BinaryOperatorKind::Equality]: 8
		[BinaryOperatorKind::EmptyCoalescing]: 15
		[BinaryOperatorKind::GreaterThan]: 8
		[BinaryOperatorKind::GreaterThanOrEqual]: 8
		[BinaryOperatorKind::Imply]: 5
		[BinaryOperatorKind::Inequality]: 8
		[BinaryOperatorKind::LeftShift]: 12
		[BinaryOperatorKind::LessThan]: 8
		[BinaryOperatorKind::LessThanOrEqual]: 8
		[BinaryOperatorKind::Match]: 8
		[BinaryOperatorKind::Mismatch]: 8
		[BinaryOperatorKind::Modulo]: 14
		[BinaryOperatorKind::Multiplication]: 14
		[BinaryOperatorKind::NullCoalescing]: 15
		[BinaryOperatorKind::Or]: 5
		[BinaryOperatorKind::Quotient]: 14
		[BinaryOperatorKind::RightShift]: 12
		[BinaryOperatorKind::Subtraction]: 13
		[BinaryOperatorKind::TypeCasting]: 8
		[BinaryOperatorKind::TypeEquality]: 8
		[BinaryOperatorKind::TypeInequality]: 8
		[BinaryOperatorKind::Xor]: 5
	}
	# }}}

	var CONDITIONAL_PRECEDENCE = 4

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

		for i from 1 to~ operations.length step 2 {
			if operations[i].kind == NodeKind::ConditionalExpression {
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

		precedenceList = precedenceList.sort(func(a, b) {
			return b - a
		})

		var dyn count, k, operator, left
		for var precedence in precedenceList {
			count = precedences[precedence]

			for k from 1 to~ operations.length step 2 while count > 0 {
				if operations[k].kind == NodeKind::ConditionalExpression {
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
					count -= 1

					operator = operations[k]

					if operator.kind == NodeKind::BinaryExpression {
						left = operations[k - 1]

						if left.kind == NodeKind::BinaryExpression && operator.operator.kind == left.operator.kind && $polyadic[operator.operator.kind] {
							operator.kind = NodeKind::PolyadicExpression
							operator.start = left.start
							operator.end = operations[k + 1].end

							operator.operands = [left.left, left.right, operations[k + 1]]
						}
						else if left.kind == NodeKind::PolyadicExpression && operator.operator.kind == left.operator.kind {
							left.operands.push(operations[k + 1])
							left.end = operations[k + 1].end

							operator = left
						}
						else if $comparison[operator.operator.kind] {
							if left.kind == NodeKind::ComparisonExpression {
								left.values.push(operator.operator, operations[k + 1])
								left.end = operations[k + 1].end

								operator = left
							}
							else {
								operator = ComparisonExpression([left, operator.operator, operations[k + 1]])
							}
						}
						else if left.kind == NodeKind::BinaryExpression && operator.operator.kind == BinaryOperatorKind::Assignment && left.operator.kind == BinaryOperatorKind::Assignment && operator.operator.assignment == left.operator.assignment {
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

		return operations[0]
	} # }}}

	export {
		func AccessorDeclaration(first) { # {{{
			return location({
				kind: NodeKind::AccessorDeclaration
			}, first)
		} # }}}

		func AccessorDeclaration(body, first, last) { # {{{
			return location({
				kind: NodeKind::AccessorDeclaration
				body: body.value
			}, first, last)
		} # }}}

		func Argument(modifiers, name?, value, first, last) { # {{{
			if name == null {
				return location({
					kind: NodeKind::Argument
					modifiers
					value: value.value
				}, first, last)
			}
			else {
				return location({
					kind: NodeKind::Argument
					modifiers
					name: name.value
					value: value.value
				}, first, last)
			}
		} # }}}

		func ArrayBinding(elements, first, last) { # {{{
			return location({
				kind: NodeKind::ArrayBinding
				elements: [element.value for element in elements]
			}, first, last)
		} # }}}

		func ArrayBindingElement(modifiers, name?, type?, defaultValue?, first, last) { # {{{
			var node = location({
				kind: NodeKind::BindingElement
				modifiers
			}, first, last)

			if ?name {
				node.name = name.value
			}

			if ?type {
				node.type = type.value
			}

			if ?defaultValue {
				node.defaultValue = defaultValue.value
			}

			return node
		} # }}}

		func ArrayComprehension(expression, loop, first, last) { # {{{
			return location({
				kind: NodeKind::ArrayComprehension
				modifiers: []
				body: expression.value
				loop: loop.value
			}, first, last)
		} # }}}

		func ArrayExpression(values, first, last) { # {{{
			return location({
				kind: NodeKind::ArrayExpression
				modifiers: []
				values: [value.value for value in values]
			}, first, last)
		} # }}}

		func ArrayRangeFI(from, til, by?, first, last) { # {{{
			var node = location({
				kind: NodeKind::ArrayRange
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
				kind: NodeKind::ArrayRange
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
				kind: NodeKind::ArrayRange
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
				kind: NodeKind::ArrayRange
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
				kind: NodeKind::ArrayType
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
				kind: BinaryOperatorKind::Assignment
				assignment: operator
			}, first)
		} # }}}

		func AttributeDeclaration(declaration, first, last) { # {{{
			return location({
				kind: NodeKind::AttributeDeclaration
				declaration: declaration.value
			}, first, last)
		} # }}}

		func AttributeExpression(name, arguments, first, last) { # {{{
			return location({
				kind: NodeKind::AttributeExpression
				name: name.value
				arguments: [argument.value for argument in arguments]
			}, first, last)
		} # }}}

		func AttributeOperation(name, value, first, last) { # {{{
			return location({
				kind: NodeKind::AttributeOperation
				name: name.value
				value: value.value
			}, first, last)
		} # }}}

		func AwaitExpression(modifiers, variables?, operand, first, last) { # {{{
			var node = location({
				kind: NodeKind::AwaitExpression
				modifiers
				operation: operand.value
			}, first, last)

			if variables != null {
				node.variables = [variable.value for variable in variables]
			}

			return node
		} # }}}

		func BinaryExpression(operator) { # {{{
			return location({
				kind: NodeKind::BinaryExpression
				modifiers: []
				operator: operator.value
			}, operator)
		} # }}}

		func BinaryExpression(left, operator, right, first = left, last = right) { # {{{
			return location({
				kind: NodeKind::BinaryExpression
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
				kind: NodeKind::BitmaskDeclaration
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
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
				kind: NodeKind::Block
				attributes: [attribute.value for attribute in attributes]
				statements: [statement.value for statement in statements]
			}, first, last)
		} # }}}

		func BlockStatement(label, body, first, last) { # {{{
			return location({
				kind: NodeKind::BlockStatement
				attributes: []
				label: label.value
				body: body.value
			}, first, last)
		} # }}}

		func BreakStatement(label?, first, last) { # {{{
			// TODO!
			// return location({
			// 	kind: NodeKind::BreakStatement
			// 	attributes: []
			// 	label: label.value if ?label
			// }, first, last)
			var node = location({
				kind: NodeKind::BreakStatement
				attributes: []
			}, first, last)

			if ?label {
				node.label = label.value
			}

			return node
		} # }}}

		func CallExpression(modifiers, scope = { kind: ScopeKind::This }, callee, arguments, first, last) { # {{{
			return location({
				kind: NodeKind::CallExpression
				modifiers
				scope
				callee: callee.value
				arguments: [argument.value for argument in arguments.value]
			}, first, last)
		} # }}}

		func CatchClause(binding?, type?, body, first, last) { # {{{
			var node = location({
				kind: NodeKind::CatchClause
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

		func ClassDeclaration(attributes, modifiers, name, version?, extends?, members, first, last) { # {{{
			var node = location({
				kind: NodeKind::ClassDeclaration
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
				name: name.value
				members: [member.value for member in members]
			}, first, last)

			if version != null {
				node.version = version.value
			}
			if extends != null {
				node.extends = extends.value
			}

			return node
		} # }}}

		func ComparisonExpression(values) { # {{{
			return location({
				kind: NodeKind::ComparisonExpression
				modifiers: []
				values
			}, values[0], values[values.length - 1])
		} # }}}

		func ComputedPropertyName(expression, first, last) { # {{{
			return location({
				kind: NodeKind::ComputedPropertyName
				expression: expression.value
			}, first, last)
		} # }}}

		func ConditionalExpression(first) { # {{{
			return location({
				kind: NodeKind::ConditionalExpression
			}, first)
		} # }}}

		func ConditionalExpression(condition, whenTrue, whenFalse) { # {{{
			return location({
				kind: NodeKind::ConditionalExpression
				modifiers: []
				condition: condition.value
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value
			}, condition, whenFalse)
		} # }}}

		func ContinueStatement(label?, first, last) { # {{{
			// TODO!
			// return location({
			// 	kind: NodeKind::ContinueStatement
			// 	attributes: []
			// 	label: label.value if ?label
			// }, first, last)
			var node = location({
				kind: NodeKind::ContinueStatement
				attributes: []
			}, first, last)

			if ?label {
				node.label = label.value
			}

			return node
		} # }}}

		func CreateExpression(class, arguments, first, last) { # {{{
			return location({
				kind: NodeKind::CreateExpression
				modifiers: []
				class: class.value
				arguments: [argument.value for argument in arguments.value]
			}, first, last)
		} # }}}

		func CurryExpression(scope, callee, arguments, first, last) { # {{{
			return location({
				kind: NodeKind::CurryExpression
				modifiers: []
				scope: scope
				callee: callee.value
				arguments: [argument.value for argument in arguments.value]
			}, first, last)
		} # }}}

		func DeclarationSpecifier(declaration) { # {{{
			return location({
				kind: NodeKind::DeclarationSpecifier
				declaration: declaration.value
			}, declaration)
		} # }}}

		func DestroyStatement(variable, first, last) { # {{{
			return location({
				kind: NodeKind::DestroyStatement
				attributes: []
				variable: variable.value
			}, first, last)
		} # }}}

		func DiscloseDeclaration(name, members, first, last) { # {{{
			return location({
				kind: NodeKind::DiscloseDeclaration
				attributes: []
				name: name.value
				members: [member.value for member in members]
			}, first, last)
		} # }}}

		func DisruptiveExpression(operator: Event, condition: Event, mainExpression: Event, disruptedExpression: Event, first, last) { # {{{
			return location({
				kind: NodeKind::DisruptiveExpression
				operator: operator.value
				condition: condition.value
				mainExpression: mainExpression.value
				disruptedExpression: disruptedExpression.value
			}, first, last)
		} # }}}

		func DoUntilStatement(condition, body, first, last) { # {{{
			return location({
				kind: NodeKind::DoUntilStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} # }}}

		func DoWhileStatement(condition, body, first, last) { # {{{
			return location({
				kind: NodeKind::DoWhileStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} # }}}

		func EnumExpression(enum, member) { # {{{
			return location({
				kind: NodeKind::EnumExpression
				modifiers: []
				enum: enum.value
				member: member.value
			}, enum, member)
		} # }}}

		func EnumDeclaration(attributes, modifiers, name, type?, members, first, last) { # {{{
			var node = location({
				kind: NodeKind::EnumDeclaration
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
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
				kind: NodeKind::ExclusionType
				types: [type.value for type in types]
			}, first, last)
		} # }}}

		func ExportDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::ExportDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} # }}}

		func ExpressionStatement(expression) { # {{{
			expression.value.attributes = []

			return expression.value
		} # }}}

		func ExternDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::ExternDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} # }}}

		func ExternOrImportDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::ExternOrImportDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declaration.value for declaration in declarations]
			}, first, last)
		} # }}}

		func ExternOrRequireDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::ExternOrRequireDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} # }}}

		func FallthroughStatement(first) { # {{{
			return location({
				kind: NodeKind::FallthroughStatement
				attributes: []
			}, first)
		} # }}}

		func FieldDeclaration(attributes, modifiers, name, type?, value?, first, last) { # {{{
			var node = location({
				kind: NodeKind::FieldDeclaration
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
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

		func ForFromStatement(modifiers, variable, from, to?, step?, until?, while?, when?, first, last) { # {{{
			var node = location({
				kind: NodeKind::ForFromStatement
				modifiers
				attributes: []
				variable: variable.value
				from: from.value
				to: to.value
			}, first, last)

			if step != null {
				node.step = step.value
			}

			if until != null {
				node.until = until.value
			}
			else if while != null {
				node.while = while.value
			}

			if when != null {
				node.when = when.value
			}

			return node
		} # }}}

		func ForInStatement(modifiers, value, type, index, expression, from?, to?, step?, split?, until?, while?, when?, first, last) { # {{{
			var node = location({
				kind: NodeKind::ForInStatement
				attributes: []
				modifiers
				expression: expression.value
			}, first, last)

			if value.ok {
				node.value = value.value
			}
			if type.ok {
				node.type = type.value
			}
			if index.ok {
				node.index = index.value
			}

			if from != null {
				node.from = from.value
			}
			if to != null {
				node.to = to.value
			}
			if step != null {
				node.step = step.value
			}
			if split != null {
				node.split = split.value
			}

			if until != null {
				node.until = until.value
			}
			else if while != null {
				node.while = while.value
			}

			if when != null {
				node.when = when.value
			}

			return node
		} # }}}

		func ForRangeStatement(modifiers, value, index, from, to, step?, until?, while?, when?, first, last) { # {{{
			var node = location({
				kind: NodeKind::ForRangeStatement
				attributes: []
				modifiers
				value: value.value
				from: from.value
				to: to.value
			}, first, last)

			if index.ok {
				node.index = index.value
			}

			if step != null {
				node.step = step.value
			}

			if until != null {
				node.until = until.value
			}
			else if while != null {
				node.while = while.value
			}

			if when != null {
				node.when = when.value
			}

			return node
		} # }}}

		func ForOfStatement(modifiers, value, type, key, expression, until?, while?, when?, first, last) { # {{{
			var node = location({
				kind: NodeKind::ForOfStatement
				attributes: []
				modifiers
				expression: expression.value
			}, first, last)

			if value.ok {
				node.value = value.value
			}
			if type.ok {
				node.type = type.value
			}
			if key.ok {
				node.key = key.value
			}

			if until != null {
				node.until = until.value
			}
			else if while != null {
				node.while = while.value
			}

			if when != null {
				node.when = when.value
			}

			return node
		} # }}}

		func FunctionDeclaration(name, parameters?, modifiers?, type?, throws?, body?, first, last) { # {{{
			var node = location({
				kind: NodeKind::FunctionDeclaration
				attributes: []
				name: name.value
			}, first, last)

			if parameters != null {
				node.parameters = [parameter.value for parameter in parameters.value]
			}

			if modifiers == null {
				node.modifiers = []
			}
			else {
				node.modifiers = [modifier.value for modifier in modifiers]
			}

			if type != null {
				node.type = type.value
			}

			if throws == null {
				node.throws = []
			}
			else {
				node.throws = [throw.value for throw in throws.value]
			}

			if body != null {
				node.body = body.value
			}

			return node
		} # }}}

		func FunctionExpression(parameters, modifiers?, type?, throws?, body?, first, last) { # {{{
			var node = location({
				kind: NodeKind::FunctionExpression
				parameters: [parameter.value for parameter in parameters.value]
			}, first, last)

			if modifiers == null {
				node.modifiers = []
			}
			else {
				node.modifiers = [modifier.value for modifier in modifiers]
			}

			if type != null {
				node.type = type.value
			}

			if throws == null {
				node.throws = []
			}
			else {
				node.throws = [throw.value for throw in throws.value]
			}

			if body != null {
				node.body = body.value
			}

			return node
		} # }}}

		func FusionType(types, first, last) { # {{{
			return location({
				kind: NodeKind::FusionType
				types: [type.value for type in types]
			}, first, last)
		} # }}}

		func GroupSpecifier(modifiers, elements, type?, first, last) { # {{{
			var node = location({
				kind: NodeKind::GroupSpecifier
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
				kind: NodeKind::IfExpression
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

		func IfStatement(condition?, declaration?, whenTrue, whenFalse?, first, last) { # {{{
			var node = location({
				kind: NodeKind::IfStatement
				attributes: []
				whenTrue: whenTrue.value
			}, first, last)

			if condition != null {
				node.condition = condition.value
			}

			if declaration != null {
				node.declaration = declaration.value
			}

			if whenFalse != null {
				node.whenFalse = whenFalse.value
			}

			return node
		} # }}}

		func ImplementDeclaration(attributes, variable, properties, first, last) { # {{{
			return location({
				kind: NodeKind::ImplementDeclaration
				attributes: [attribute.value for attribute in attributes]
				variable: variable.value
				properties: [property.value for property in properties]
			}, first, last)
		} # }}}

		func ImportDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::ImportDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declaration.value for declaration in declarations]
			}, first, last)
		} # }}}

		func ImportDeclarator(attributes, modifiers, source, arguments?, type?, specifiers, first, last) { # {{{
			var node = location({
				kind: NodeKind::ImportDeclarator
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				source: source.value
				specifiers: [specifier.value for var specifier in specifiers]
			}, first, last)

			if arguments != null {
				node.arguments = arguments
			}
			if type != null {
				node.type = type.value
			}

			return node
		} # }}}

		func Identifier(name, first) { # {{{
			return location({
				kind: NodeKind::Identifier
				modifiers: []
				name: name
			}, first)
		} # }}}

		func IncludeAgainDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::IncludeAgainDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declaration.value for declaration in declarations]
			}, first, last)
		} # }}}

		func IncludeDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::IncludeDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declaration.value for declaration in declarations]
			}, first, last)
		} # }}}

		func IncludeDeclarator(file) { # {{{
			return location({
				kind: NodeKind::IncludeDeclarator
				attributes: []
				file: file.value
			}, file, file)
		} # }}}

		func JunctionExpression(operator, operands) { # {{{
			return location({
				kind: NodeKind::JunctionExpression
				modifiers: []
				operator: operator.value
				operands
			}, operands[0], operands[operands.length - 1])
		} # }}}

		func LambdaExpression(parameters, modifiers?, type?, throws?, body, first, last) { # {{{
			var node = location({
				kind: NodeKind::LambdaExpression
				modifiers: []
				parameters: [parameter.value for parameter in parameters.value]
				body: body.value
			}, first, last)

			if modifiers != null {
				node.modifiers = [modifier.value for modifier in modifiers]
			}

			if type != null {
				node.type = type.value
			}

			if throws == null {
				node.throws = []
			}
			else {
				node.throws = [throw.value for throw in throws.value]
			}

			return node
		} # }}}

		func Literal(modifiers?, value, first, last? = null) { # {{{
			var node = location({
				kind: NodeKind::Literal
				modifiers: []
				value: value
			}, first, last)

			if modifiers != null {
				node.modifiers = [modifier.value for modifier in modifiers]
			}

			return node
		} # }}}

		func MacroDeclaration(attributes, name, parameters, body, first, last) { # {{{
			return location({
				kind: NodeKind::MacroDeclaration
				attributes: [attribute.value for attribute in attributes]
				name: name.value
				parameters: [parameter.value for parameter in parameters.value]
				body: body.value
			}, first, last)
		} # }}}

		func MacroExpression(elements, first, last) { # {{{
			return location({
				kind: NodeKind::MacroExpression
				attributes: []
				elements: [element.value for element in elements]
			}, first, last)
		} # }}}

		func MacroElementExpression(expression, reification?, first, last) { # {{{
			var node = location({
				kind: MacroElementKind::Expression
				expression: expression.value
			}, first, last)

			if reification != null {
				node.reification = reification
			}

			return node
		} # }}}

		func MacroElementLiteral(value, first, last) { # {{{
			return location({
				kind: MacroElementKind::Literal
				value: value
			}, first, last)
		} # }}}

		func MacroElementNewLine(first) { # {{{
			return location({
				kind: MacroElementKind::NewLine
			}, first)
		} # }}}

		func MatchClause(conditions?, bindings?, filter?, body, first, last) { # {{{
			var node = location({
				kind: NodeKind::MatchClause
				body: body.value
			}, first, last)

			if conditions == null {
				node.conditions = []
			}
			else {
				node.conditions = [condition.value for condition in conditions]
			}

			if bindings == null {
				node.bindings = []
			}
			else {
				node.bindings = [binding.value for binding in bindings.value]
			}

			if filter != null {
				node.filter = filter.value
			}

			return node
		} # }}}

		func MatchConditionArray(values, first, last) { # {{{
			return location({
				kind: NodeKind::MatchConditionArray
				values: [value.value for value in values]
			}, first, last)
		} # }}}

		func MatchConditionObject(members, first, last) { # {{{
			return location({
				kind: NodeKind::MatchConditionObject
				members: [member.value for member in members]
			}, first, last)
		} # }}}

		func MatchConditionRangeFI(from, til) { # {{{
			return location({
				kind: NodeKind::MatchConditionRange
				from: from.value
				til: til.value
			}, from, til)
		} # }}}

		func MatchConditionRangeFO(from, to) { # {{{
			return location({
				kind: NodeKind::MatchConditionRange
				from: from.value
				to: to.value
			}, from, to)
		} # }}}

		func MatchConditionRangeTI(then, til) { # {{{
			return location({
				kind: NodeKind::MatchConditionRange
				then: then.value
				til: til.value
			}, then, til)
		} # }}}

		func MatchConditionRangeTO(then, to) { # {{{
			return location({
				kind: NodeKind::MatchConditionRange
				then: then.value
				to: to.value
			}, then, to)
		} # }}}

		func MatchConditionType(type, first, last) { # {{{
			return location({
				kind: NodeKind::MatchConditionType
				type: type.value
			}, first, last)
		} # }}}

		func MatchExpression(expression, clauses, first, last) { # {{{
			return location({
				kind: NodeKind::MatchExpression
				attributes: []
				expression: expression.value
				clauses: [clause for clause in clauses.value]
			}, first, last)
		} # }}}

		func MatchStatement(expression, clauses, first, last) { # {{{
			return location({
				kind: NodeKind::MatchStatement
				attributes: []
				expression: expression.value
				clauses: [clause for clause in clauses.value]
			}, first, last)
		} # }}}

		func MemberExpression(modifiers, object, property, first = object, last = property) { # {{{
			return location({
				kind: NodeKind::MemberExpression
				modifiers
				object: object.value
				property: property.value
			}, first, last)
		} # }}}

		func MethodDeclaration(attributes, modifiers, name, parameters, type?, throws?, body?, first, last) { # {{{
			var node = location({
				kind: NodeKind::MethodDeclaration
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
				name: name.value
				parameters: [parameter.value for parameter in parameters.value]
			}, first, last)

			if type != null {
				node.type = type.value
			}

			if throws == null {
				node.throws = []
			}
			else {
				node.throws = [throw.value for throw in throws.value]
			}

			if body != null {
				node.body = body.value
			}

			return node
		} # }}}

		func Modifier(kind, first, last? = null) { # {{{
			return location({
				kind: kind
			}, first, last)
		} # }}}

		func Module(attributes, body, parser: Parser) { # {{{
			return location({
				kind: NodeKind::Module
				attributes: [attribute.value for attribute in attributes]
				body: body,
				start: {
					line: 1
					column: 1
				}
			}, parser.position())
		} # }}}

		func MutatorDeclaration(first) { # {{{
			return location({
				kind: NodeKind::MutatorDeclaration
			}, first)
		} # }}}

		func MutatorDeclaration(body, first, last) { # {{{
			return location({
				kind: NodeKind::MutatorDeclaration
				body: body.value
			}, first, last)
		} # }}}

		func NamedArgument(name, value) { # {{{
			return location({
				kind: NodeKind::NamedArgument
				modifiers: []
				name: name.value
				value: value.value
			}, name, value)
		} # }}}

		func NamedArgument(name, value, first, last) { # {{{
			return location({
				kind: NodeKind::NamedArgument
				modifiers: []
				name: name.value
				value: value.value
			}, first, last)
		} # }}}

		func NamedSpecifier(internal) { # {{{
			return location({
				kind: NodeKind::NamedSpecifier
				modifiers: []
				internal: internal.value
			}, internal, internal)
		} # }}}

		func NamedSpecifier(modifiers, internal, external?, first, last) { # {{{
			var node = location({
				kind: NodeKind::NamedSpecifier
				modifiers: [modifier.value for var modifier in modifiers]
				internal: internal.value
			}, first, last)

			if ?external {
				node.external = external.value
			}

			return node
		} # }}}

		func NamespaceDeclaration(attributes, modifiers, name, statements, first, last) { # {{{
			return location({
				kind: NodeKind::NamespaceDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				statements: [statement.value for var statement in statements]
			}, first, last)
		} # }}}

		func NumericExpression(value, first) { # {{{
			return location({
				kind: NodeKind::NumericExpression
				modifiers: []
				value: value
			}, first)
		} # }}}

		func ObjectBinding(elements, first, last) { # {{{
			return location({
				kind: NodeKind::ObjectBinding
				elements: [element.value for element in elements]
			}, first, last)
		} # }}}

		func ObjectBindingElement(modifiers, name, alias?, defaultValue?, first, last) { # {{{
			var node = location({
				kind: NodeKind::BindingElement
				name: name.value
				modifiers
			}, first, last)

			if ?alias {
				node.alias = alias.value
			}

			if ?defaultValue {
				node.defaultValue = defaultValue.value
			}

			return node
		} # }}}

		func ObjectExpression(attributes, properties, first, last) { # {{{
			return location({
				kind: NodeKind::ObjectExpression
				modifiers: []
				attributes: [attribute.value for attribute in attributes]
				properties: [property.value for property in properties]
			}, first, last)
		} # }}}

		func ObjectMember(attributes, modifiers, name?, type?, value?, first, last) { # {{{
			var node = location({
				kind: NodeKind::ObjectMember
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
				kind: NodeKind::ObjectType
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
				kind: NodeKind::OmittedExpression
				modifiers
			}, first, first)

			return node
		} # }}}

		func OmittedReference(first) { # {{{
			return location({
				kind: NodeKind::TypeReference
				modifiers: []
			}, first, first)
		} # }}}

		func PassStatement(first) { # {{{
			return location({
				kind: NodeKind::PassStatement
				attributes: []
			}, first, first)
		} # }}}

		func Parameter(name) { # {{{
			return location({
				kind: NodeKind::Parameter
				attributes: []
				modifiers: []
				internal: name.value
				external: name.value
			}, name, name)
		} # }}}

		func Parameter(attributes, modifiers, external?, internal?, type?, operator?, defaultValue?, first, last) { # {{{
			var node = location({
				kind: NodeKind::Parameter
				attributes: [attribute.value for var attribute in attributes]
				modifiers: modifiers
			}, first, last)

			if external != null {
				node.external = external.value
			}
			if internal != null {
				node.internal = internal.value
			}
			if type != null {
				node.type = type.value
			}
			if operator != null {
				node.operator = operator.value
			}
			if defaultValue != null {
				node.defaultValue = defaultValue.value
			}

			return node
		} # }}}

		func PickStatement(first) { # {{{
			return location({
				kind: NodeKind::PickStatement
				attributes: []
			}, first, first)
		} # }}}

		func PickStatement(value, first, last) { # {{{
			return location({
				kind: NodeKind::PickStatement
				attributes: []
				value: value.value
			}, first, last)
		} # }}}

		func PositionalArgument(value) { # {{{
			return location({
				kind: NodeKind::PositionalArgument
				modifiers: []
				value: value.value
			}, value, value)
		} # }}}

		func PropertiesSpecifier(modifiers, object, properties, first, last) { # {{{
			return location({
				kind: NodeKind::PropertiesSpecifier
				modifiers: [modifier.value for var modifier in modifiers]
				object: object.value
				properties: [property.value for var property in properties]
			}, first, last)
		} # }}}

		func PropertyDeclaration(attributes, modifiers, name, type?, defaultValue?, accessor?, mutator?, first, last) { # {{{
			var node = location({
				kind: NodeKind::PropertyDeclaration
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
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
				kind: NodeKind::PropertyType
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
				kind: NodeKind::ProxyDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				internal: internal.value
				external: external.value
			}, first, last)
		} # }}}

		func ProxyGroupDeclaration(attributes, modifiers, recipient, elements, first, last) { # {{{
			return location({
				kind: NodeKind::ProxyGroupDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				recipient: recipient.value
				elements: [element.value for var element in elements]
			}, first, last)
		} # }}}

		func Reference(name: String, first) { # {{{
			return location({
				kind: NodeKind::Reference
				name
			}, first)
		} # }}}

		func RegularExpression(value, first) { # {{{
			return location({
				kind: NodeKind::RegularExpression
				modifiers: []
				value: value
			}, first)
		} # }}}

		func RepeatStatement(expression?, body?, first, last) { # {{{
			var node = location({
				kind: NodeKind::RepeatStatement
				attributes: []
			}, first, last)

			if ?expression {
				node.expression = expression.value
			}
			if ?body {
				node.body = body.value
			}

			return node
		} # }}}

		func RequireDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::RequireDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} # }}}

		func RequireOrExternDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::RequireOrExternDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} # }}}

		func RequireOrImportDeclaration(attributes, declarations, first, last) { # {{{
			return location({
				kind: NodeKind::RequireOrImportDeclaration
				attributes: [attribute.value for attribute in attributes]
				declarations: [declaration.value for declaration in declarations]
			}, first, last)
		} # }}}

		func RestModifier(min, max, first, last) { # {{{
			return location({
				kind: ModifierKind::Rest
				arity: {
					min: min
					max: max
				}
			}, first, last)
		} # }}}

		func RestrictiveExpression(operator: Event, condition: Event, expression: Event, first, last) { # {{{
			return location({
				kind: NodeKind::RestrictiveExpression
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
				kind: NodeKind::ReturnStatement
				attributes: []
			}, first, first)
		} # }}}

		func ReturnStatement(value, first, last) { # {{{
			return location({
				kind: NodeKind::ReturnStatement
				attributes: []
				value: value.value
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
				kind: NodeKind::SequenceExpression
				modifiers: []
				expressions: [expression.value for expression in expressions]
			}, first, last)
		} # }}}

		func ShebangDeclaration(command, first, last) { # {{{
			return location({
				kind: NodeKind::ShebangDeclaration
				command
			}, first, last)
		} # }}}

		func ShorthandProperty(attributes, name, first, last) { # {{{
			return location({
				kind: NodeKind::ShorthandProperty
				attributes: [attribute.value for attribute in attributes]
				name: name.value
			}, first, last)
		} # }}}

		func StructDeclaration(attributes, modifiers, name, extends?, fields, first, last) { # {{{
			var node = location({
				kind: NodeKind::StructDeclaration
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
				name: name.value
				fields
			}, first, last)

			if extends != null {
				node.extends = extends.value
			}

			return node
		} # }}}

		func StructField(attributes, modifiers, name, type?, defaultValue?, first, last) { # {{{
			var node = location({
				kind: NodeKind::StructField
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
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
				kind: NodeKind::TaggedTemplateExpression
				tag: tag.value
				template: template.value
			}, first, last)
		} # }}}

		func TemplateExpression(modifiers?, elements, first, last?) { # {{{
			var node = location({
				kind: NodeKind::TemplateExpression
				modifiers: []
				elements: [element.value for element in elements]
			}, first, last)

			if modifiers != null {
				node.modifiers = [modifier.value for modifier in modifiers]
			}

			return node
		} # }}}

		func ThisExpression(name, first, last) { # {{{
			return location({
				kind: NodeKind::ThisExpression
				modifiers: []
				name: name.value
			}, first, last)
		} # }}}

		func ThrowStatement(first) { # {{{
			return location({
				kind: NodeKind::ThrowStatement
				attributes: []
			}, first)
		} # }}}

		func ThrowStatement(value, first, last) { # {{{
			return location({
				kind: NodeKind::ThrowStatement
				attributes: []
				value: value.value
			}, first, last)
		} # }}}

		func TryExpression(modifiers, operand, defaultValue?, first, last) { # {{{
			var node = location({
				kind: NodeKind::TryExpression
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
				kind: NodeKind::TryStatement
				attributes: []
				body: body.value
				catchClauses: [clause.value for clause in catchClauses]
			}, first, last)

			if catchClause != null {
				node.catchClause = catchClause.value
			}
			if finalizer != null {
				node.finalizer = finalizer.value
			}

			return node
		} # }}}

		func TupleDeclaration(attributes, modifiers, name, extends?, fields, first, last) { # {{{
			var node = location({
				kind: NodeKind::TupleDeclaration
				attributes: [attribute.value for attribute in attributes]
				modifiers: [modifier.value for modifier in modifiers]
				name: name.value
				fields
			}, first, last)

			if extends != null {
				node.extends = extends.value
			}

			return node
		} # }}}

		func TupleField(attributes, modifiers, name?, type?, defaultValue?, first, last) { # {{{
			var node = location({
				kind: NodeKind::TupleField
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
			}, first, last)

			if ?name {
				node.name = name.value
			}

			if ?type {
				node.type = type.value
			}

			if ?defaultValue {
				node.defaultValue = defaultValue.value
			}

			return node
		} # }}}

		func TypeReference(name) { # {{{
			return location({
				kind: NodeKind::TypeReference
				modifiers: []
				typeName: name.value
			}, name)
		} # }}}

		func TypeReference(modifiers, name, parameters?, first, last) { # {{{
			var node = location({
				kind: NodeKind::TypeReference
				modifiers: [modifier.value for var modifier in modifiers]
				typeName: name.value
			}, first, last)

			if parameters != null {
				node.typeParameters = [parameter.value for var parameter in parameters.value]
			}

			return node
		} # }}}

		func TypeAliasDeclaration(name, type, first, last) { # {{{
			return location({
				kind: NodeKind::TypeAliasDeclaration
				attributes: []
				name: name.value
				type: type.value
			}, first, last)
		} # }}}

		func TypeList(attributes, types, first, last) { # {{{
			return location({
				kind: NodeKind::TypeList
				attributes: [attribute.value for var attribute in attributes]
				types: [type.value for var type in types]
			}, first, last)
		} # }}}

		func TypedSpecifier(type, first) { # {{{
			return location({
				kind: NodeKind::TypedSpecifier
				type: type.value
			}, first)
		} # }}}

		func UnaryExpression(operator, operand, first, last) { # {{{
			return location({
				kind: NodeKind::UnaryExpression
				modifiers: []
				operator: operator.value
				argument: operand.value
			}, first, last)
		} # }}}

		func UnaryOperator(operator: UnaryOperatorKind, first) { # {{{
			return location({
				kind: operator
			}, first)
		} # }}}

		func UnionType(types, first, last) { # {{{
			return location({
				kind: NodeKind::UnionType
				types: [type.value for var type in types]
			}, first, last)
		} # }}}

		func UnlessStatement(condition, whenFalse, first, last) { # {{{
			return location({
				kind: NodeKind::UnlessStatement
				attributes: []
				condition: condition.value
				whenFalse: whenFalse.value
			}, first, last)
		} # }}}

		func UntilStatement(condition, body, first, last) { # {{{
			return location({
				kind: NodeKind::UntilStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} # }}}

		func VariableDeclaration(attributes, modifiers, variables, operator?, value?, first, last) { # {{{
			var node = location({
				kind: NodeKind::VariableDeclaration
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
				kind: NodeKind::VariableDeclarator
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
				kind: NodeKind::VariableStatement
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				declarations: [declaration.value for var declaration in declarations]
			}, first, last)
		} # }}}

		func WhileStatement(condition, body, first, last) { # {{{
			return location({
				kind: NodeKind::WhileStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} # }}}

		func WithStatement(variables, body, finalizer?, first, last) { # {{{
			var node = location({
				kind: NodeKind::WithStatement
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
