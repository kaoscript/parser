namespace AST {
	// {{{
	const $comparison = {
		[BinaryOperatorKind::Addition]: false
		[BinaryOperatorKind::And]: false
		[BinaryOperatorKind::Assignment]: false
		[BinaryOperatorKind::BitwiseAnd]: false
		[BinaryOperatorKind::BitwiseLeftShift]: false
		[BinaryOperatorKind::BitwiseOr]: false
		[BinaryOperatorKind::BitwiseRightShift]: false
		[BinaryOperatorKind::BitwiseXor]: false
		[BinaryOperatorKind::Division]: false
		[BinaryOperatorKind::Equality]: true
		[BinaryOperatorKind::GreaterThan]: true
		[BinaryOperatorKind::GreaterThanOrEqual]: true
		[BinaryOperatorKind::Imply]: false
		[BinaryOperatorKind::Inequality]: true
		[BinaryOperatorKind::LessThan]: true
		[BinaryOperatorKind::LessThanOrEqual]: true
		[BinaryOperatorKind::Modulo]: false
		[BinaryOperatorKind::Multiplication]: false
		[BinaryOperatorKind::NullCoalescing]: false
		[BinaryOperatorKind::Or]: false
		[BinaryOperatorKind::Quotient]: false
		[BinaryOperatorKind::Subtraction]: false
		[BinaryOperatorKind::TypeCasting]: false
		[BinaryOperatorKind::TypeEquality]: false
		[BinaryOperatorKind::TypeInequality]: false
		[BinaryOperatorKind::Xor]: false
	}

	const $polyadic = {
		[BinaryOperatorKind::Addition]: true
		[BinaryOperatorKind::And]: true
		[BinaryOperatorKind::Assignment]: false
		[BinaryOperatorKind::BitwiseAnd]: true
		[BinaryOperatorKind::BitwiseLeftShift]: true
		[BinaryOperatorKind::BitwiseOr]: true
		[BinaryOperatorKind::BitwiseRightShift]: true
		[BinaryOperatorKind::BitwiseXor]: true
		[BinaryOperatorKind::Division]: true
		[BinaryOperatorKind::Imply]: true
		[BinaryOperatorKind::Modulo]: true
		[BinaryOperatorKind::Multiplication]: true
		[BinaryOperatorKind::NullCoalescing]: true
		[BinaryOperatorKind::Or]: true
		[BinaryOperatorKind::Quotient]: true
		[BinaryOperatorKind::Subtraction]: true
		[BinaryOperatorKind::TypeCasting]: false
		[BinaryOperatorKind::TypeEquality]: false
		[BinaryOperatorKind::TypeInequality]: false
		[BinaryOperatorKind::Xor]: true
	}

	const $precedence = {
		[BinaryOperatorKind::Addition]: 13
		[BinaryOperatorKind::And]: 6
		[BinaryOperatorKind::Assignment]: 3
		[BinaryOperatorKind::BitwiseAnd]: 11
		[BinaryOperatorKind::BitwiseLeftShift]: 12
		[BinaryOperatorKind::BitwiseOr]: 9
		[BinaryOperatorKind::BitwiseRightShift]: 12
		[BinaryOperatorKind::BitwiseXor]: 10
		[BinaryOperatorKind::Division]: 14
		[BinaryOperatorKind::Equality]: 8
		[BinaryOperatorKind::GreaterThan]: 8
		[BinaryOperatorKind::GreaterThanOrEqual]: 8
		[BinaryOperatorKind::Imply]: 5
		[BinaryOperatorKind::Inequality]: 8
		[BinaryOperatorKind::LessThan]: 8
		[BinaryOperatorKind::LessThanOrEqual]: 8
		[BinaryOperatorKind::Modulo]: 14
		[BinaryOperatorKind::Multiplication]: 14
		[BinaryOperatorKind::NullCoalescing]: 15
		[BinaryOperatorKind::Or]: 5
		[BinaryOperatorKind::Quotient]: 14
		[BinaryOperatorKind::Subtraction]: 13
		[BinaryOperatorKind::TypeCasting]: 8
		[BinaryOperatorKind::TypeEquality]: 8
		[BinaryOperatorKind::TypeInequality]: 8
		[BinaryOperatorKind::Xor]: 5
	}
	// }}}

	const CONDITIONAL_PRECEDENCE = 4

	func location(descriptor, firstToken, lastToken = null) { // {{{
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
	} // }}}

	export func reorderExpression(operations) { // {{{
		const precedences = {}
		let precedenceList = []

		let precedence
		for i from 1 til operations.length by 2 {
			if operations[i].kind == NodeKind::ConditionalExpression {
				if precedences[CONDITIONAL_PRECEDENCE] {
					++precedences[CONDITIONAL_PRECEDENCE]
				}
				else {
					precedences[CONDITIONAL_PRECEDENCE] = 1
				}

				precedenceList.push(CONDITIONAL_PRECEDENCE)

				i++
			}
			else {
				precedence = $precedence[operations[i].operator.kind]

				if precedences[precedence] {
					++precedences[precedence]
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

		let count, k, operator, left
		for precedence in precedenceList {
			count = precedences[precedence]

			for k from 1 til operations.length by 2 while count {
				if operations[k].kind == NodeKind::ConditionalExpression {
					if precedence == CONDITIONAL_PRECEDENCE {
						--count

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
						k++
					}
				}
				else if $precedence[operations[k].operator.kind] == precedence {
					--count

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
	} // }}}

	export {
		func AccessorDeclaration(first) { // {{{
			return location({
				kind: NodeKind::AccessorDeclaration
			}, first)
		} // }}}

		func AccessorDeclaration(body, first, last) { // {{{
			return location({
				kind: NodeKind::AccessorDeclaration
				body: body.value
			}, first, last)
		} // }}}

		func ArrayBinding(elements, first, last) { // {{{
			return location({
				kind: NodeKind::ArrayBinding
				elements: [element.value for element in elements]
			}, first, last)
		} // }}}

		func ArrayComprehension(expression, loop, first, last) { // {{{
			return location({
				kind: NodeKind::ArrayComprehension
				body: expression.value
				loop: loop.value
			}, first, last)
		} // }}}

		func ArrayExpression(values, first, last) { // {{{
			return location({
				kind: NodeKind::ArrayExpression
				values: [value.value for value in values]
			}, first, last)
		} // }}}

		func ArrayRangeFI(from, til, by?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ArrayRange
				from: from.value
				til: til.value
			}, first, last)

			if by? {
				node.by = by.value
			}

			return node
		} // }}}

		func ArrayRangeFO(from, to, by?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ArrayRange
				from: from.value
				to: to.value
			}, first, last)

			if by? {
				node.by = by.value
			}

			return node
		} // }}}

		func ArrayRangeTI(then, til, by?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ArrayRange
				then: then.value
				til: til.value
			}, first, last)

			if by? {
				node.by = by.value
			}

			return node
		} // }}}

		func ArrayRangeTO(then, to, by?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ArrayRange
				then: then.value
				to: to.value
			}, first, last)

			if by? {
				node.by = by.value
			}

			return node
		} // }}}

		func AssignmentOperator(operator: AssignmentOperatorKind, first) { // {{{
			return location({
				kind: BinaryOperatorKind::Assignment
				assignment: operator
			}, first)
		} // }}}

		func AttributeDeclaration(declaration, first, last) { // {{{
			return location({
				kind: NodeKind::AttributeDeclaration
				declaration: declaration.value
			}, first, last)
		} // }}}

		func AttributeExpression(name, arguments, first, last) { // {{{
			return location({
				kind: NodeKind::AttributeExpression
				name: name.value
				arguments: [argument.value for argument in arguments]
			}, first, last)
		} // }}}

		func AttributeOperation(name, value, first, last) { // {{{
			return location({
				kind: NodeKind::AttributeOperation
				name: name.value
				value: value.value
			}, first, last)
		} // }}}

		func AwaitExpression(variables?, autotype, operand, first, last) { // {{{
			const node = location({
				kind: NodeKind::AwaitExpression
				operation: operand.value
			}, first, last)

			if variables != null {
				node.variables = [variable.value for variable in variables]
			}
			if autotype {
				node.autotype = true
			}

			return node
		} // }}}

		func BinaryExpression(operator) { // {{{
			return location({
				kind: NodeKind::BinaryExpression
				operator: operator.value
			}, operator)
		} // }}}

		func BinaryExpression(left, operator, right, first = left, last = right) { // {{{
			return location({
				kind: NodeKind::BinaryExpression
				operator: operator.value
				left: left.value
				right: right.value
			}, first, last)
		} // }}}

		func BinaryOperator(operator: BinaryOperatorKind, first) { // {{{
			return location({
				kind: operator
			}, first)
		} // }}}

		func BindingElement(name) { // {{{
			return location({
				kind: NodeKind::BindingElement
				name: name.value
			}, name)
		} // }}}

		func BindingElement(name, alias?, spread?, defaultValue?, first, last) { // {{{
			const node = location({
				kind: NodeKind::BindingElement
				name: name.value
			}, first, last)

			if alias? {
				node.alias = alias.value
			}

			if spread? {
				node.spread = true
			}

			if defaultValue? {
				node.defaultValue = defaultValue.value
			}

			return node
		} // }}}

		func Block(attributes, statements, first, last) { // {{{
			return location({
				kind: NodeKind::Block
				attributes: attributes
				statements: [statement.value for statement in statements]
			}, first, last)
		} // }}}

		func BreakStatement(first) { // {{{
			return location({
				kind: NodeKind::BreakStatement
				attributes: []
			}, first)
		} // }}}

		func CallExpression(callee, arguments, first, last) { // {{{
			return location({
				kind: NodeKind::CallExpression
				scope: {
					kind: ScopeKind::This
				}
				callee: callee.value
				arguments: [argument.value for argument in arguments.value]
				nullable: false
			}, first, last)
		} // }}}

		func CallExpression(scope, callee, arguments, nullable: Boolean, first, last) { // {{{
			return location({
				kind: NodeKind::CallExpression
				scope: scope
				callee: callee.value
				arguments: [argument.value for argument in arguments.value]
				nullable: nullable
			}, first, last)
		} // }}}

		func CallMacroExpression(callee, arguments, first, last) { // {{{
			return location({
				kind: NodeKind::CallMacroExpression
				callee: callee.value
				arguments: [argument.value for argument in arguments.value]
			}, first, last)
		} // }}}

		func CatchClause(binding?, type?, body, first, last) { // {{{
			const node = location({
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
		} // }}}

		func ClassDeclaration(attributes, name, version?, extends?, modifiers, members, first, last) { // {{{
			const node = location({
				kind: NodeKind::ClassDeclaration
				attributes
				name: name.value
				modifiers: [modifier.value for modifier in modifiers]
				members: [member.value for member in members]
			}, first, last)

			if version != null {
				node.version = version.value
			}
			if extends != null {
				node.extends = extends.value
			}

			return node
		} // }}}

		func ComparisonExpression(values) { // {{{
			return location({
				kind: NodeKind::ComparisonExpression
				values
			}, values[0], values[values.length - 1])
		} // }}}

		func ComputedPropertyName(expression, first, last) { // {{{
			return location({
				kind: NodeKind::ComputedPropertyName
				expression: expression.value
			}, first, last)
		} // }}}

		func ConditionalExpression(first) { // {{{
			return location({
				kind: NodeKind::ConditionalExpression
			}, first)
		} // }}}

		func ConditionalExpression(condition, whenTrue, whenFalse) { // {{{
			return location({
				kind: NodeKind::ConditionalExpression
				condition: condition.value
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value
			}, condition, whenFalse)
		} // }}}

		func ContinueStatement(first) { // {{{
			return location({
				kind: NodeKind::ContinueStatement
				attributes: []
			}, first)
		} // }}}

		func CreateExpression(class, arguments, first, last) { // {{{
			return location({
				kind: NodeKind::CreateExpression
				class: class.value
				arguments: [argument.value for argument in arguments.value]
			}, first, last)
		} // }}}

		func CurryExpression(scope, callee, arguments, first, last) { // {{{
			return location({
				kind: NodeKind::CurryExpression
				scope: scope
				callee: callee.value
				arguments: [argument.value for argument in arguments.value]
			}, first, last)
		} // }}}

		func DestroyStatement(variable, first, last) { // {{{
			return location({
				kind: NodeKind::DestroyStatement
				attributes: []
				variable: variable.value
			}, first, last)
		} // }}}

		func DiscloseDeclaration(name, members, first, last) { // {{{
			return location({
				kind: NodeKind::DiscloseDeclaration
				attributes: []
				name: name.value
				members: [member.value for member in members]
			}, first, last)
		} // }}}

		func DoUntilStatement(condition, body, first, last) { // {{{
			return location({
				kind: NodeKind::DoUntilStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} // }}}

		func DoWhileStatement(condition, body, first, last) { // {{{
			return location({
				kind: NodeKind::DoWhileStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} // }}}

		func EnumExpression(enum, member) { // {{{
			return location({
				kind: NodeKind::EnumExpression
				enum: enum.value
				member: member.value
			}, enum, member)
		} // }}}

		func EnumDeclaration(name, type?, members, first, last) { // {{{
			const node = location({
				kind: NodeKind::EnumDeclaration
				attributes: []
				name: name.value
				members: members
			}, first, last)

			if type != null {
				node.type = type.value
			}

			return node
		} // }}}

		func EnumMember(name) { // {{{
			return location({
				kind: NodeKind::EnumMember
				name: name.value
			}, name)
		} // }}}

		func EnumMember(name, value) { // {{{
			return location({
				kind: NodeKind::EnumMember
				name: name.value
				value: value.value
			}, name, value)
		} // }}}

		func ExportDeclaration(declarations, first, last) { // {{{
			return location({
				kind: NodeKind::ExportDeclaration
				attributes: []
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} // }}}

		func ExportDeclarationSpecifier(declaration) { // {{{
			return location({
				kind: NodeKind::ExportDeclarationSpecifier
				declaration: declaration.value
			}, declaration)
		} // }}}

		func ExportNamedSpecifier(local, exported) { // {{{
			return location({
				kind: NodeKind::ExportNamedSpecifier
				local: local.value
				exported: exported.value
			}, local, exported)
		} // }}}

		func ExportPropertiesSpecifier(object, properties, last) { // {{{
			return location({
				kind: NodeKind::ExportPropertiesSpecifier
				object: object.value
				properties: properties
			}, object, last)
		} // }}}

		func ExportWildcardSpecifier(local, end) { // {{{
			return location({
				kind: NodeKind::ExportWildcardSpecifier
				local: local.value
			}, local, end)
		} // }}}

		func ExpressionStatement(expression) { // {{{
			expression.value.attributes = []

			return expression.value
		} // }}}

		func ExternDeclaration(declarations, first, last) { // {{{
			return location({
				kind: NodeKind::ExternDeclaration
				attributes: []
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} // }}}

		func ExternOrRequireDeclaration(declarations, first, last) { // {{{
			return location({
				kind: NodeKind::ExternOrRequireDeclaration
				attributes: []
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} // }}}

		func FieldDeclaration(attributes, modifiers, name, type?, defaultValue?, first, last) { // {{{
			const node = location({
				kind: NodeKind::FieldDeclaration
				attributes
				modifiers: [modifier.value for modifier in modifiers]
				name: name.value
			}, first, last)

			if type != null {
				node.type = type.value
			}
			if defaultValue != null {
				node.defaultValue = defaultValue.value
			}

			return node
		} // }}}

		func ForFromStatement(declaration: Boolean, rebindable: Boolean, variable, from, til?, to?, by?, until?, while?, when?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ForFromStatement
				attributes: []
				variable: variable.value
				from: from.value
				declaration: declaration
			}, first, last)

			if declaration {
				node.rebindable = rebindable
			}

			if til != null {
				node.til = til.value
			}
			else if to != null {
				node.to = to.value
			}
			if by != null {
				node.by = by.value
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
		} // }}}

		func ForInStatement(declaration: Boolean, rebindable: Boolean, value?, index?, expression, desc?, from?, til?, to?, by?, until?, while?, when?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ForInStatement
				attributes: []
				expression: expression.value
				desc: desc != null
				declaration: declaration
			}, first, last)

			if declaration {
				node.rebindable = rebindable
			}

			if value.ok {
				node.value = value.value
			}
			if index.ok {
				node.index = index.value
			}

			if from != null {
				node.from = from.value
			}
			if til != null {
				node.til = til.value
			}
			else if to != null {
				node.to = to.value
			}
			if by != null {
				node.by = by.value
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
		} // }}}

		func ForRangeStatement(declaration: Boolean, rebindable: Boolean, value, index?, from?, then?, til?, to?, by?, until?, while?, when?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ForRangeStatement
				attributes: []
				value: value.value
				declaration: declaration
			}, first, last)

			if declaration {
				node.rebindable = rebindable
			}

			if index.ok {
				node.index = index.value
			}

			if from != null {
				node.from = from.value
			}
			else if then != null {
				node.then = then.value
			}
			if til != null {
				node.til = til.value
			}
			else if to != null {
				node.to = to.value
			}
			if by != null {
				node.by = by.value
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
		} // }}}

		func ForOfStatement(declaration: Boolean, rebindable: Boolean, value?, key?, expression, until?, while?, when?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ForOfStatement
				attributes: []
				expression: expression.value
				declaration: declaration
			}, first, last)

			if declaration {
				node.rebindable = rebindable
			}

			if value.ok {
				node.value = value.value
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
		} // }}}

		func FunctionDeclaration(name, parameters?, modifiers?, type?, throws?, body?, first, last) { // {{{
			const node = location({
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
		} // }}}

		func FunctionExpression(parameters, modifiers?, type?, throws?, body?, first, last) { // {{{
			const node = location({
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
		} // }}}

		func IfExpression(condition, whenTrue, whenFalse?, first, last) { // {{{
			const node = location({
				kind: NodeKind::IfExpression
				condition: condition.value
				whenTrue: whenTrue.value
			}, first, last)

			if whenFalse != null {
				node.whenFalse = whenFalse.value
			}

			return node
		} // }}}

		func IfStatement(condition, whenTrue, whenFalse?, first, last) { // {{{
			const node = location({
				kind: NodeKind::IfStatement
				attributes: []
				condition: condition.value
				whenTrue: whenTrue.value
			}, first, last)

			if whenFalse != null {
				node.whenFalse = whenFalse.value
			}

			return node
		} // }}}

		func ImplementDeclaration(attributes, variable, properties, first, last) { // {{{
			return location({
				kind: NodeKind::ImplementDeclaration
				attributes
				variable: variable.value
				properties: [property.value for property in properties]
			}, first, last)
		} // }}}

		func ImportArgument(seep?, name?, value) { // {{{
			const node = location({
				kind: NodeKind::ImportArgument
				name: null
				value: value.value
				seeped: seep != null
			}, seep ?? name ?? value, name ?? value)

			if name != null {
				node.name = name.value
			}

			return node
		} // }}}

		func ImportDeclaration(declarations, first, last) { // {{{
			return location({
				kind: NodeKind::ImportDeclaration
				attributes: []
				declarations: [declaration.value for declaration in declarations]
			}, first, last)
		} // }}}

		func ImportDeclarator(source, specifiers, arguments?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ImportDeclarator
				source: source.value
				specifiers: [specifier.value for specifier in specifiers]
			}, first, last)

			if arguments != null {
				node.arguments = arguments
			}

			return node
		} // }}}

		func ImportNamespaceSpecifier(local, specifiers?, first, last) { // {{{
			const node = location({
				kind: NodeKind::ImportNamespaceSpecifier
				local: local.value
			}, first, last)

			if specifiers != null {
				node.specifiers = [specifier.value for specifier in specifiers]
			}

			return node
		} // }}}

		func ImportSpecifier(imported, local, first, last) { // {{{
			return location({
				kind: NodeKind::ImportSpecifier
				imported: imported.value
				local: local.value
			}, first, last)
		} // }}}

		func Identifier(name, first) { // {{{
			return location({
				kind: NodeKind::Identifier
				name: name
			}, first)
		} // }}}

		func IncludeAgainDeclaration(files, first, last) { // {{{
			return location({
				kind: NodeKind::IncludeAgainDeclaration
				attributes: []
				files: files
			}, first, last)
		} // }}}

		func IncludeDeclaration(files, first, last) { // {{{
			return location({
				kind: NodeKind::IncludeDeclaration
				attributes: []
				files: files
			}, first, last)
		} // }}}

		func LambdaExpression(parameters, modifiers?, type?, body, first, last) { // {{{
			const node = location({
				kind: NodeKind::LambdaExpression
				modifiers: []
				parameters: [parameter.value for parameter in parameters.value]
				body: body.value
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

			return node
		} // }}}

		func Literal(value, first, last = null) { // {{{
			return location({
				kind: NodeKind::Literal
				value: value
			}, first, last)
		} // }}}

		func MacroDeclaration(attributes, name, parameters, body, first, last) { // {{{
			return location({
				kind: NodeKind::MacroDeclaration
				attributes
				name: name.value
				parameters: [parameter.value for parameter in parameters.value]
				body: body.value
			}, first, last)
		} // }}}

		func MacroExpression(elements, multilines, first, last) { // {{{
			return location({
				kind: NodeKind::MacroExpression
				attributes: []
				elements: [element.value for element in elements]
				multilines: multilines
			}, first, last)
		} // }}}

		func MacroElementExpression(expression, reification?, first, last) { // {{{
			const node = location({
				kind: MacroElementKind::Expression
				expression: expression.value
			}, first, last)

			if reification == null {
				node.reification = {
					kind: ReificationKind::Expression
				}
			}
			else {
				node.reification = reification
			}

			return node
		} // }}}

		func MacroElementLiteral(value, first, last) { // {{{
			return location({
				kind: MacroElementKind::Literal
				value: value
			}, first, last)
		} // }}}

		func MacroElementNewLine(first) { // {{{
			return location({
				kind: MacroElementKind::NewLine
			}, first)
		} // }}}

		func MacroReification(value, first) { // {{{
			switch value {
				'a' => {
					return location({
						kind: ReificationKind::Arguments
					}, first)
				}
				'b' => {
					return location({
						kind: ReificationKind::Block
					}, first)
				}
				'e' => {
					return location({
						kind: ReificationKind::Expression
					}, first)
				}
				'i' => {
					return location({
						kind: ReificationKind::Identifier
					}, first)
				}
			}
		} // }}}

		func MemberExpression(object, property, computed, nullable, first = object, last = property) { // {{{
			return location({
				kind: NodeKind::MemberExpression
				object: object.value
				property: property.value
				computed: computed
				nullable: nullable
			}, first, last)
		} // }}}

		func MethodDeclaration(attributes, modifiers, name, parameters, type?, throws?, body?, first, last) { // {{{
			const node = location({
				kind: NodeKind::MethodDeclaration
				attributes
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
		} // }}}

		func Modifier(kind, first, last = null) { // {{{
			return location({
				kind: kind
			}, first, last)
		} // }}}

		func Module(attributes, body, parser: Parser) { // {{{
			return location({
				kind: NodeKind::Module
				attributes
				body: body,
				start: {
					line: 1
					column: 1
				}
			}, parser.position())
		} // }}}

		func MutatorDeclaration(first) { // {{{
			return location({
				kind: NodeKind::MutatorDeclaration
			}, first)
		} // }}}

		func MutatorDeclaration(body, first, last) { // {{{
			return location({
				kind: NodeKind::MutatorDeclaration
				body: body.value
			}, first, last)
		} // }}}

		func Nullable(first) { // {{{
			return location({
				kind: NodeKind::TypeReference
				typeName: {
					kind: NodeKind::Identifier
					name: 'any'
				}
				nullable: true
			}, first)
		} // }}}

		func NamespaceDeclaration(attributes, modifiers, name, statements, first, last) { // {{{
			return location({
				kind: NodeKind::NamespaceDeclaration
				attributes
				modifiers: [modifier.value for modifier in modifiers]
				name: name.value
				statements: [statement.value for statement in statements]
			}, first, last)
		} // }}}

		func NumericExpression(value, first) { // {{{
			return location({
				kind: NodeKind::NumericExpression
				value: value
			}, first)
		} // }}}

		func ObjectBinding(elements, first, last) { // {{{
			return location({
				kind: NodeKind::ObjectBinding
				elements: [element.value for element in elements]
			}, first, last)
		} // }}}

		func ObjectExpression(attributes, properties, first, last) { // {{{
			return location({
				kind: NodeKind::ObjectExpression
				attributes
				properties: [property.value for property in properties]
			}, first, last)
		} // }}}

		func ObjectMember(name) { // {{{
			return location({
				kind: NodeKind::ObjectMember
				name: name.value
			}, name, name)
		} // }}}

		func ObjectMember(name, value) { // {{{
			return location({
				kind: NodeKind::ObjectMember
				name: name.value
				value: value.value
			}, name, value)
		} // }}}

		func ObjectMember(attributes, name, value, first, last) { // {{{
			return location({
				kind: NodeKind::ObjectMember
				attributes
				name: name.value
				value: value.value
			}, first, last)
		} // }}}

		func ObjectReference(properties, first, last) { // {{{
			return location({
				kind: NodeKind::TypeReference
				typeName: {
					kind: NodeKind::Identifier
					name: 'object'
				},
				properties: [property.value for property in properties]
			}, first, last)
		} // }}}

		func ObjectMemberReference(name, type) { // {{{
			return node = location({
				kind: NodeKind::ObjectMember
				name: name.value
				type: type.value
			}, name, type)
		} // }}}

		func OmittedExpression(spread, first) { // {{{
			const node = location({
				kind: NodeKind::OmittedExpression
			}, first)

			if spread {
				node.spread = true
			}
			else {
				node.end = node.start
			}

			return node
		} // }}}

		func PropertyDeclaration(attributes, modifiers, name, type?, defaultValue?, accessor?, mutator?, first, last) { // {{{
			const node = location({
				kind: NodeKind::PropertyDeclaration
				attributes
				modifiers: [modifier.value for modifier in modifiers]
				name: name.value
			}, first, last)

			if type != null {
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
		} // }}}

		func Parameter(name) { // {{{
			return location({
				kind: NodeKind::Parameter
				modifiers: []
				name: name.value
			}, name, name)
		} // }}}

		func Parameter(name?, type?, modifiers, defaultValue?, first, last) { // {{{
			const node = location({
				kind: NodeKind::Parameter
				modifiers: modifiers
			}, first, last)

			if name != null {
				node.name = name.value
			}
			if type != null {
				node.type = type.value
			}

			if defaultValue != null {
				node.defaultValue = defaultValue.value
			}

			return node
		} // }}}

		func RegularExpression(value, first) { // {{{
			return location({
				kind: NodeKind::RegularExpression
				value: value
			}, first)
		} // }}}

		func RequireDeclaration(declarations, first, last) { // {{{
			return location({
				kind: NodeKind::RequireDeclaration
				attributes: []
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} // }}}

		func RequireOrExternDeclaration(declarations, first, last) { // {{{
			return location({
				kind: NodeKind::RequireOrExternDeclaration
				attributes: []
				declarations: [declarator.value for declarator in declarations]
			}, first, last)
		} // }}}

		func RequireOrImportDeclaration(declarations, first, last) { // {{{
			return location({
				kind: NodeKind::RequireOrImportDeclaration
				attributes: []
				declarations: [declaration.value for declaration in declarations]
			}, first, last)
		} // }}}

		func RestModifier(min, max, first, last) { // {{{
			return location({
				kind: ModifierKind::Rest
				arity: {
					min: min
					max: max
				}
			}, first, last)
		} // }}}

		func ReturnStatement(first) { // {{{
			return location({
				kind: NodeKind::ReturnStatement
				attributes: []
			}, first, first)
		} // }}}

		func ReturnStatement(value, first, last) { // {{{
			return location({
				kind: NodeKind::ReturnStatement
				attributes: []
				value: value.value
			}, first, last)
		} // }}}

		func Scope(scope: ScopeKind) { // {{{
			return {
				kind: scope
			}
		} // }}}

		func Scope(scope: ScopeKind, value) { // {{{
			return {
				kind: scope
				value: value.value
			}
		} // }}}

		func SequenceExpression(expressions, first, last) { // {{{
			return location({
				kind: NodeKind::SequenceExpression
				expressions: [expression.value for expression in expressions]
			}, first, last)
		} // }}}

		func ShorthandProperty(attributes, name, first, last) { // {{{
			return location({
				kind: NodeKind::ShorthandProperty
				attributes
				name: name.value
			}, first, last)
		} // }}}

		func SwitchClause(conditions?, bindings?, filter?, body, first, last) { // {{{
			const node = location({
				kind: NodeKind::SwitchClause
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
		} // }}}

		func SwitchConditionArray(values, first, last) { // {{{
			return location({
				kind: NodeKind::SwitchConditionArray
				values: [value.value for value in values]
			}, first, last)
		} // }}}

		func SwitchConditionObject(members, first, last) { // {{{
			return location({
				kind: NodeKind::SwitchConditionObject
				members: [member.value for member in members]
			}, first, last)
		} // }}}

		func SwitchConditionRangeFO(from, to) { // {{{
			return location({
				kind: NodeKind::SwitchConditionRange
				from: from.value
				to: to.value
			}, from, to)
		} // }}}

		func SwitchConditionType(type, first, last) { // {{{
			return location({
				kind: NodeKind::SwitchConditionType
				type: type.value
			}, first, last)
		} // }}}

		func SwitchExpression(expression, clauses, first, last) { // {{{
			return location({
				kind: NodeKind::SwitchExpression
				attributes: []
				expression: expression.value
				clauses: [clause for clause in clauses.value]
			}, first, last)
		} // }}}

		func SwitchStatement(expression, clauses, first, last) { // {{{
			return location({
				kind: NodeKind::SwitchStatement
				attributes: []
				expression: expression.value
				clauses: [clause for clause in clauses.value]
			}, first, last)
		} // }}}

		func SwitchTypeCasting(name, type) { // {{{
			return location({
				kind: NodeKind::SwitchTypeCasting
				name: name.value
				type: type.value
			}, name, type)
		} // }}}

		func TaggedTemplateExpression(tag, template, first, last) { // {{{
			return location({
				kind: NodeKind::TaggedTemplateExpression
				tag: tag.value
				template: template.value
			}, first, last)
		} // }}}

		func TemplateExpression(elements, first, last) { // {{{
			return location({
				kind: NodeKind::TemplateExpression
				elements: [element.value for element in elements]
			}, first, last)
		} // }}}

		func ThisExpression(name, first, last) { // {{{
			return location({
				kind: NodeKind::ThisExpression
				name: name.value
			}, first, last)
		} // }}}

		func ThrowStatement(first) { // {{{
			return location({
				kind: NodeKind::ThrowStatement
				attributes: []
			}, first)
		} // }}}

		func ThrowStatement(value, first, last) { // {{{
			return location({
				kind: NodeKind::ThrowStatement
				attributes: []
				value: value.value
			}, first, last)
		} // }}}

		func TryStatement(body, catchClauses, catchClause?, finalizer?, first, last) { // {{{
			const node = location({
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
		} // }}}

		func TypeReference(name) { // {{{
			return location({
				kind: NodeKind::TypeReference
				typeName: name.value
			}, name)
		} // }}}

		func TypeReference(name, parameters?, nullable?, first, last) { // {{{
			let node
			if parameters == null {
				node = location({
					kind: NodeKind::TypeReference
					typeName: name.value
				}, first, last)
			}
			else {
				node = location({
					kind: NodeKind::TypeReference
					typeName: name.value
					typeParameters: [parameter.value for parameter in parameters.value]
				}, first, last)
			}

			if nullable?.ok {
				node.nullable = true
			}

			return node
		} // }}}

		func TypeAliasDeclaration(name, type, first, last) { // {{{
			return location({
				kind: NodeKind::TypeAliasDeclaration
				attributes: []
				name: name.value
				type: type.value
			}, first, last)
		} // }}}

		func UnaryExpression(operator, operand, first, last) { // {{{
			return location({
				kind: NodeKind::UnaryExpression
				operator: operator.value
				argument: operand.value
			}, first, last)
		} // }}}

		func UnaryOperator(operator: UnaryOperatorKind, first) { // {{{
			return location({
				kind: operator
			}, first)
		} // }}}

		func UnionType(types, first, last) { // {{{
			return location({
				kind: NodeKind::UnionType
				types: [type.value for type in types]
			}, first, last)
		} // }}}

		func UnlessExpression(condition, whenFalse, first, last) { // {{{
			return location({
				kind: NodeKind::UnlessExpression
				condition: condition.value
				whenFalse: whenFalse.value
			}, first, last)
		} // }}}

		func UnlessStatement(condition, whenFalse, first, last) { // {{{
			return location({
				kind: NodeKind::UnlessStatement
				attributes: []
				condition: condition.value
				whenFalse: whenFalse.value
			}, first, last)
		} // }}}

		func UntilStatement(condition, body, first, last) { // {{{
			return location({
				kind: NodeKind::UntilStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} // }}}

		func VariableDeclaration(variables, rebindable, first, last) { // {{{
			return location({
				kind: NodeKind::VariableDeclaration
				attributes: []
				rebindable: rebindable
				variables: [variable.value for variable in variables]
			}, first, last)
		} // }}}

		func VariableDeclaration(variables, rebindable, equals, isAwait, expression, first, last) { // {{{
			return location({
				kind: NodeKind::VariableDeclaration
				attributes: []
				rebindable: rebindable
				variables: [variable.value for variable in variables]
				autotype: equals.value
				await: isAwait
				init: expression.value
			}, first, last)
		} // }}}

		func VariableDeclarator(name) { // {{{
			return location({
				kind: NodeKind::VariableDeclarator
				name: name.value
			}, name)
		} // }}}

		func VariableDeclarator(name, type) { // {{{
			return location({
				kind: NodeKind::VariableDeclarator
				name: name.value
				type: type.value
			}, name, type)
		} // }}}

		func VariableDeclarator(name, type?, sealed, first, last) { // {{{
			const node = location({
				kind: NodeKind::VariableDeclarator
				name: name.value
				sealed: sealed
			}, first, last)

			if type != null {
				node.type = type.value
			}

			return node
		} // }}}

		func WhileStatement(condition, body, first, last) { // {{{
			return location({
				kind: NodeKind::WhileStatement
				attributes: []
				condition: condition.value
				body: body.value
			}, first, last)
		} // }}}
	}
}