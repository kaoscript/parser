namespace AST {
	var CONDITIONAL_PRECEDENCE = 4

	export func pushAttributes(
		// TODO
		// data: Range & { attributes: NodeData(AttributeDeclaration)[] }
		data
		attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
	): Void { # {{{
		if ?#attributes {
			data.start = attributes[0].value.start

			while ?#attributes {
				data.attributes.unshift(attributes.pop().value)
			}
		}
	} # }}}

	export func pushModifier<T is NodeData>(
		data: T
		modifier: Event(Y)
		prefix: Boolean
	): T { # {{{
		data.modifiers.push(modifier.value)

		if prefix {
			data.start = modifier.start
		}
		else {
			data.end = modifier.end
		}

		return data
	} # }}}

	// TODO
	// export func reorderExpression(operations: BinaryOperationData[]): NodeData(Expression) { # {{{
	export func reorderExpression<T is NodeData>(operations: T[]): T { # {{{
		var precedences = {}
		var mut precedenceList = []

		for var mut i from 1 to~ operations.length step 2 {
			var precedence = operations[i].operator.kind.precedence

			if ?precedences[precedence] {
				precedences[precedence] += 1
			}
			else {
				precedences[precedence] = 1
			}

			precedenceList.push(precedence)
		}

		precedenceList.sort(func(a, b) {
			return b - a
		})

		for var precedence in precedenceList {
			var mut count = precedences[precedence]

			for var mut k from 1 to~ operations.length step 2 while count > 0 {
				if operations[k].operator.kind.precedence == precedence {
					if operations[k] is .BinaryExpression && operations[k].operator.kind.attribute ~~ OperatorAttribute.RTL {
						var mut end = operations.length - 1

						for var i from k + 2 to~ operations.length step 2 {
							if operations[i].operator.kind.attribute !~ OperatorAttribute.RTL {
								end = i - 1
							}
						}

						var mut c = 0

						for var i from end - 1 down to k step 2 {
							var operator = operations[i]

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

						var mut operator = operations[k]
						// var mut operand: NodeData(BinaryExpression, PolyadicExpression)? = null
						// var mut operand = null

						if operator is .BinaryExpression {
							var left = operations[k - 1]

							if left is .BinaryExpression && operator.operator.kind == left.operator.kind && operator.operator.kind.attribute ~~ OperatorAttribute.Polyadic {
								operator.kind = NodeKind.PolyadicExpression
								operator.start = left.start
								operator.end = operations[k + 1].end

								operator.operands = [left.left, left.right, operations[k + 1]]
								// operand = {
								// 	kind: NodeKind.PolyadicExpression
								// 	operator
								// 	operands: [left.left, left.right, operations[k + 1]]
								// 	start: left.start
								// 	end: operations[k + 1].end
								// }
							}
							else if left is .PolyadicExpression && operator.operator.kind == left.operator.kind {
								left.operands.push(operations[k + 1])
								left.end = operations[k + 1].end

								operator = left
							}
							else if operator.operator.kind.attribute ~~ OperatorAttribute.Comparable {
								if left is .ComparisonExpression {
									left.values.push(operator.operator, operations[k + 1])
									left.end = operations[k + 1].end

									operator = left
								}
								else {
									operator = ComparisonExpression([left, operator.operator, operations[k + 1]])
								}
							}
							else if left is .BinaryExpression && operator.operator.kind == BinaryOperatorKind.Assignment && left.operator.kind == BinaryOperatorKind.Assignment && operator.operator.assignment == left.operator.assignment {
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
		func AccessorDeclaration(
			{ start, end }: Range
		): NodeData(AccessorDeclaration) { # {{{
			return {
				kind: .AccessorDeclaration
				start
				end
			}
		} # }}}

		func AccessorDeclaration(
			{ value % body }: Event<NodeData(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(AccessorDeclaration) { # {{{
			return {
				kind: .AccessorDeclaration
				body
				start
				end
			}
		} # }}}

		func ArrayBinding(
			elements: Event<NodeData(BindingElement)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ArrayBinding) { # {{{
			return {
				kind: .ArrayBinding
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func ArrayBindingElement(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			internal: Event<NodeData(Identifier, ArrayBinding, ObjectBinding, ThisExpression)>
			type: Event<NodeData(Type)>
			operator: Event<BinaryOperatorData(Assignment)>
			defaultValue: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(BindingElement) { # {{{
			return {
				kind: .BindingElement
				attributes: [attribute.value for var attribute in attributes] if ?#attributes
				modifiers
				internal: internal.value if ?]internal
				type: type.value if ?]type
				operator: operator.value if ?]operator
				defaultValue: defaultValue.value if ?]defaultValue
				start
				end
			}
		} # }}}

		func ArrayComprehension(
			value: Event<NodeData(Expression)>(Y)
			iteration: Event<IterationData>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(ArrayComprehension) { # {{{
			return {
				kind: .ArrayComprehension
				modifiers: []
				value: value.value
				iteration: iteration.value
				start
				end
			}
		} # }}}

		func ArrayExpression(
			values: Event<NodeData(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ArrayExpression) { # {{{
			return {
				kind: .ArrayExpression
				modifiers: []
				values: [value.value for var value in values]
				start
				end
			}
		} # }}}

		func ArrayRangeFI(
			from: Event<NodeData(Expression)>(Y)
			til: Event<NodeData(Expression)>(Y)
			by: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(ArrayRange) { # {{{
			return {
				kind: .ArrayRange
				from: from.value
				til: til.value
				by: by.value if ?]by
				start
				end
			}
		} # }}}

		func ArrayRangeFO(
			from: Event<NodeData(Expression)>(Y)
			to: Event<NodeData(Expression)>(Y)
			by: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(ArrayRange) { # {{{
			return {
				kind: .ArrayRange
				from: from.value
				to: to.value
				by: by.value if ?]by
				start
				end
			}
		} # }}}

		func ArrayRangeTI(
			then: Event<NodeData(Expression)>(Y)
			til: Event<NodeData(Expression)>(Y)
			by: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(ArrayRange) { # {{{
			return {
				kind: .ArrayRange
				then: then.value
				til: til.value
				by: by.value if ?]by
				start
				end
			}
		} # }}}

		func ArrayRangeTO(
			then: Event<NodeData(Expression)>(Y)
			to: Event<NodeData(Expression)>(Y)
			by: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(ArrayRange) { # {{{
			return {
				kind: .ArrayRange
				then: then.value
				to: to.value
				by: by.value if ?]by
				start
				end
			}
		} # }}}

		func ArrayType(
			modifiers: Event<ModifierData>(Y)[]
			properties: Event<NodeData(PropertyType)>(Y)[]
			rest: Event<NodeData(PropertyType)>
			{ start }: Range
			{ end }: Range
		): NodeData(ArrayType) { # {{{
			return {
				kind: .ArrayType
				modifiers: [modifier.value for var modifier in modifiers]
				properties: [property.value for var property in properties]
				rest: rest.value if ?]rest
				start
				end
			}
		} # }}}

		func AssignmentOperator(
			operator: AssignmentOperatorKind
			{ start, end }: Range
		): BinaryOperatorData(Assignment) { # {{{
			return {
				kind: .Assignment
				assignment: operator
				start
				end
			}
		} # }}}

		func AttributeDeclaration(
			declaration: Event<NodeData(Identifier, AttributeExpression, AttributeOperation)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(AttributeDeclaration) { # {{{
			return {
				kind: .AttributeDeclaration
				declaration: declaration.value
				start
				end
			}
		} # }}}

		func AttributeExpression(
			name: Event<NodeData(Identifier)>(Y)
			arguments: Event<NodeData(Identifier, AttributeOperation, AttributeExpression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(AttributeExpression) { # {{{
			return {
				kind: .AttributeExpression
				name: name.value
				arguments: [argument.value for var argument in arguments]
				start
				end
			}
		} # }}}

		func AttributeOperation(
			name: Event<NodeData(Identifier)>(Y)
			value: Event<NodeData(Literal)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(AttributeOperation) { # {{{
			return {
				kind: .AttributeOperation
				name: name.value
				value: value.value
				start
				end
			}
		} # }}}

		func AwaitExpression(
			modifiers: ModifierData[]
			variables: Event<NodeData(VariableDeclarator)>(Y)[]
			operation: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(AwaitExpression) { # {{{
			return {
				kind: .AwaitExpression
				modifiers
				variables: [variable.value for var variable in variables] if ?#variables
				operation: operation.value if ?]operation
				start
				end
			}
		} # }}}

		func BinaryExpression(
			{ value, start, end }: Event<BinaryOperatorData>(Y)
		): NodeData(BinaryExpression) { # {{{
			return {
				kind: .BinaryExpression
				modifiers: []
				operator: value
				start
				end
			}
		} # }}}

		func BinaryExpression(
			left: Event<NodeData(Expression)>(Y)
			operator: Event<BinaryOperatorData>(Y)
			right: Event<NodeData(Expression, Type)>(Y)
			{ start }: Range = left
			{ end }: Range = right
		): NodeData(BinaryExpression) { # {{{
			return {
				kind: .BinaryExpression
				modifiers: []
				operator: operator.value
				left: left.value
				right: right.value
				start
				end
			}
		} # }}}

		func BinaryOperator(
			operator: BinaryOperatorKind(!Assignment)
			{ start, end }: Range
		): BinaryOperatorData(!Assignment) { # {{{
			return {
				kind: operator
				modifiers: []
				start
				end
			}
		} # }}}

		func BinaryOperator(
			modifiers: ModifierData[]
			operator: BinaryOperatorKind(!Assignment)
			{ start, end }: Range
		): BinaryOperatorData(!Assignment) { # {{{
			return {
				kind: operator
				modifiers
				start
				end
			}
		} # }}}

		func BitmaskDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			type: Event<NodeData(Identifier)>
			members: NodeData(BitmaskValue, MethodDeclaration)[]
			{ start }: Range
			{ end }: Range
		): NodeData(BitmaskDeclaration) { # {{{
			return {
				kind: .BitmaskDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				type: type.value if ?]type
				members: members
				start
				end
			}
		} # }}}

		func BitmaskValue(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			value: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(BitmaskValue) { # {{{
			return {
				kind: .BitmaskValue
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				value: value.value if ?]value
				start
				end
			}
		} # }}}

		func Block(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			statements: Event<NodeData(Statement)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(Block) { # {{{
			return {
				kind: .Block
				attributes: [attribute.value for var attribute in attributes]
				statements: [statement.value for var statement in statements]
				start
				end
			}
		} # }}}

		func BlockStatement(
			label: Event<NodeData(Identifier)>(Y)
			body: Event<NodeData(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(BlockStatement) { # {{{
			return {
				kind: .BlockStatement
				attributes: []
				label: label.value
				body: body.value
				start
				end
			}
		} # }}}

		func BreakStatement(
			label: Event<NodeData(Identifier)>
			{ start }: Range
			{ end }: Range
		): NodeData(BreakStatement) { # {{{
			return {
				kind: .BreakStatement
				attributes: []
				label: label.value if ?]label
				start
				end
			}
		} # }}}

		func CallExpression(
			modifiers: ModifierData[]
			scope: ScopeData = { kind: ScopeKind.This }
			callee: Event<NodeData(Expression)>(Y)
			arguments: Event<Event<NodeData(Argument, Expression)>(Y)[]>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(CallExpression) { # {{{
			return {
				kind: .CallExpression
				modifiers
				scope
				callee: callee.value
				arguments: [argument.value for var argument in arguments.value]
				start
				end
			}
		} # }}}

		func CatchClause(
			binding: Event<NodeData(Identifier)>
			type: Event<NodeData(Identifier)>
			body: Event<NodeData(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(CatchClause) { # {{{
			return {
				kind: .CatchClause
				body: body.value
				binding: binding.value if ?]binding
				type: type.value if ?]type
				start
				end
			}
		} # }}}

		func ClassDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			typeParameters: Event<Event<NodeData(TypeParameter)>[]>
			version: Event<VersionData>
			extends: Event<NodeData(Identifier, MemberExpression)>
			implements: Event<NodeData(Identifier, MemberExpression)>(Y)[]
			members: Event<NodeData(ClassMember)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ClassDeclaration) { # {{{
			return {
				kind: .ClassDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				typeParameters: [parameter.value for var parameter in typeParameters.value] if ?]typeParameters
				version: version.value if ?]version
				extends: extends.value if ?]extends
				implements: [implement.value for var implement in implements] if ?#implements
				members: [member.value for var member in members]
				start
				end
			}
		} # }}}

		func ComparisonExpression(
			values: Array<NodeData(Expression) | BinaryOperatorData>
		): NodeData(ComparisonExpression) { # {{{
			return {
				kind: .ComparisonExpression
				modifiers: []
				values
				start: values[0].start
				end: values[values.length - 1].end
			}
		} # }}}

		func ComputedPropertyName(
			expression: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(ComputedPropertyName) { # {{{
			return {
				kind: .ComputedPropertyName
				expression: expression.value
				start
				end
			}
		} # }}}

		func ContinueStatement(
			label: Event<NodeData(Identifier)>
			{ start }: Range
			{ end }: Range
		): NodeData(ContinueStatement) { # {{{
			return {
				kind: .ContinueStatement
				attributes: []
				label: label.value if ?]label
				start
				end
			}
		} # }}}

		func CurryExpression(
			scope: ScopeData
			callee: Event<NodeData(Expression)>(Y)
			arguments: Event<Event<NodeData(Argument, Expression)>(Y)[]>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(CurryExpression) { # {{{
			return {
				kind: .CurryExpression
				modifiers: []
				scope: scope
				callee: callee.value
				arguments: [argument.value for var argument in arguments.value]
				start
				end
			}
		} # }}}

		func DeclarationSpecifier(
			{ value % declaration, start, end }: Event<NodeData(SpecialDeclaration)>(Y)
		): NodeData(DeclarationSpecifier) { # {{{
			return {
				kind: .DeclarationSpecifier
				declaration
				start
				end
			}
		} # }}}

		func DiscloseDeclaration(
			name: Event<NodeData(Identifier)>(Y)
			typeParameters: Event<Event<NodeData(TypeParameter)>[]>
			members: Event<NodeData(ClassMember)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(DiscloseDeclaration) { # {{{
			return {
				kind: .DiscloseDeclaration
				attributes: []
				name: name.value
				typeParameters: [parameter.value for var parameter in typeParameters.value] if ?]typeParameters && ?#typeParameters.value
				members: [member.value for var member in members]
				start
				end
			}
		} # }}}

		func DisruptiveExpression(
			operator: Event<RestrictiveOperatorData>(Y)
			condition: Event<NodeData(Expression)>(Y)
			mainExpression: Event<NodeData(Expression)>(Y)
			disruptedExpression: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(DisruptiveExpression) { # {{{
			return {
				kind: .DisruptiveExpression
				operator: operator.value
				condition: condition.value
				mainExpression: mainExpression.value
				disruptedExpression: disruptedExpression.value
				start
				end
			}
		} # }}}

		func DoUntilStatement(
			condition: Event<NodeData(Expression)>(Y)
			body: Event<NodeData(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(DoUntilStatement) { # {{{
			return {
				kind: .DoUntilStatement
				attributes: []
				condition: condition.value
				body: body.value
				start
				end
			}
		} # }}}

		func DoWhileStatement(
			condition: Event<NodeData(Expression)>(Y)
			body: Event<NodeData(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(DoWhileStatement) { # {{{
			return {
				kind: .DoWhileStatement
				attributes: []
				condition: condition.value
				body: body.value
				start
				end
			}
		} # }}}

		func EnumDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			type: Event<NodeData(TypeReference)>
			initial: Event<NodeData(Expression)>
			step: Event<NodeData(Expression)>
			members: NodeData(EnumValue, FieldDeclaration, MethodDeclaration)[]
			{ start }: Range
			{ end }: Range
		): NodeData(EnumDeclaration) { # {{{
			return {
				kind: .EnumDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				type: type.value if ?]type
				initial: initial.value if ?]initial
				step: step.value if ?]step
				members
				start
				end
			}
		} # }}}

		func EnumValue(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			value: Event<NodeData(Expression)>
			arguments: Event<NodeData(Argument, Expression)>(Y)[]?
			{ start }: Range
			{ end }: Range
		): NodeData(EnumValue) { # {{{
			return {
				kind: .EnumValue
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				value: value.value if ?]value
				arguments: [argument.value for var argument in arguments] if ?#arguments
				start
				end
			}
		} # }}}

		func ExclusionType(
			types: Event<NodeData(Type)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ExclusionType) { # {{{
			return {
				kind: .ExclusionType
				types: [type.value for var type in types]
				start
				end
			}
		} # }}}

		func ExportDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(DeclarationSpecifier, GroupSpecifier, NamedSpecifier, PropertiesSpecifier)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ExportDeclaration) { # {{{
			return {
				kind: .ExportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func ExpressionStatement(
			{ value % expression, start, end }: Event<NodeData(Expression)>(Y)
		): NodeData(ExpressionStatement) { # {{{
			return {
				kind: .ExpressionStatement
				attributes: []
				expression
				start
				end
			}
		} # }}}

		func ExternDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ExternDeclaration) { # {{{
			return {
				kind: .ExternDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func ExternOrImportDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(ImportDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ExternOrImportDeclaration) { # {{{
			return {
				kind: .ExternOrImportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func ExternOrRequireDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ExternOrRequireDeclaration) { # {{{
			return {
				kind: .ExternOrRequireDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func FallthroughStatement(
			{ start, end }: Range
		): NodeData(FallthroughStatement) { # {{{
			return {
				kind: .FallthroughStatement
				attributes: []
				start
				end
			}
		} # }}}

		func FieldDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			type: Event<NodeData(Type)>
			value: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(FieldDeclaration) { # {{{
			return {
				kind: .FieldDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				type: type.value if ?]type
				value: value.value if ?]value
				start
				end
			}
		} # }}}

		func ForStatement(
			iterations: Event<IterationData>(Y)[]
			body: Event<NodeData(Block, ExpressionStatement)>(Y)
			else: Event<NodeData(Block)>
			{ start }: Range
			{ end }: Range
		): NodeData(ForStatement) { # {{{
			return {
				kind: .ForStatement
				attributes: []
				iterations: [iteration.value for var iteration in iterations]
				body: body.value
				else: else.value if ?]else
				start
				end
			}
		} # }}}

		// TODO!
		// func FunctionDeclaration(
		// 	modifiers: Event<ModifierData>(Y)[]
		// 	name: Event<NodeData(Identifier)>(Y)
		// 	typeParameters: Event<Event<NodeData(TypeParameter)>(Y)[]>
		// 	parameters: Event<Event<NodeData(Parameter)>(Y)[]>
		// 	type: Event<NodeData(Type)>
		// 	throws: Event<Event<NodeData(Identifier)>(Y)[]>
		// 	body: Event<NodeData(Block, Expression, IfStatement, UnlessStatement)>
		// 	{ start }: Range
		// 	{ end }: Range
		// ): NodeData(FunctionDeclaration) { # {{{
		// 	return {
		// 		kind: .FunctionDeclaration
		// 		attributes: []
		// 		modifiers: [modifier.value for var modifier in modifiers]
		// 		name: name.value
		// 		// TODO!
		// 		typeParameters: [parameter.value for var parameter in typeParameters.value] if ?#typeParameters?].value
		// 		parameters: [parameter.value for var parameter in parameters.value] if ?]parameters
		// 		type: type.value if ?]type
		// 		throws: [throw.value for var throw in throws?].value]
		// 		body: body.value if ?]body
		// 		start
		// 		end
		// 	}
		// } # }}}
		func FunctionDeclaration(
			name: Event<NodeData(Identifier)>(Y)
			typeParameters: Event<Event<NodeData(TypeParameter)>[]>
			parameters: Event<Event<NodeData(Parameter)>(Y)[]>(Y)?
			modifiers: Event<ModifierData>(Y)[]?
			type: Event<NodeData(Type)>?
			throws: Event<Event<NodeData(Identifier)>[]>?
			body: Event<NodeData(Block, Expression, IfStatement, UnlessStatement)>(Y)?
			{ start }: Range
			{ end }: Range
		): NodeData(FunctionDeclaration) { # {{{
			return {
				kind: .FunctionDeclaration
				attributes: []
				modifiers: if ?modifiers set [modifier.value for var modifier in modifiers] else []
				name: name.value
				typeParameters: [parameter.value for var parameter in typeParameters.value] if ?]typeParameters && ?#typeParameters.value
				parameters: [parameter.value for var parameter in parameters.value] if ?parameters
				type: type.value if ?type?.value
				throws: if ?throws set [throw.value for var throw in throws.value] else []
				body: body.value if ?body
				start
				end
			}
		} # }}}

		func FunctionExpression(
			parameters: Event<Event<NodeData(Parameter)>[]>(Y)
			modifiers: Event<ModifierData>(Y)[]?
			type: Event<NodeData(Type)>?
			throws: Event<Event<NodeData(Identifier)>[]>?
			body: Event<NodeData(Block, Expression, IfStatement, UnlessStatement)>(Y)?
			{ start }: Range
			{ end }: Range
		): NodeData(FunctionExpression) { # {{{
			return {
				kind: .FunctionExpression
				modifiers: if ?modifiers set [modifier.value for var modifier in modifiers] else []
				parameters: [parameter.value for var parameter in parameters.value]
				type: type.value if ?type?.value
				throws: if ?throws set [throw.value for var throw in throws.value] else []
				body: body.value if ?body
				start
				end
			}
		} # }}}

		func FusionType(
			types: Event<NodeData(Type)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(FusionType) { # {{{
			return {
				kind: .FusionType
				types: [type.value for var type in types]
				start
				end
			}
		} # }}}

		func GroupSpecifier(
			modifiers: Event<ModifierData>(Y)[]
			elements: Event<NodeData(NamedSpecifier, TypedSpecifier)>(Y)[]
			type: Event<NodeData(DescriptiveType)>
			{ start }: Range
			{ end }: Range
		): NodeData(GroupSpecifier) { # {{{
			return {
				kind: .GroupSpecifier
				modifiers: [modifier.value for var modifier in modifiers]
				elements: [element.value for var element in elements]
				type: type.value if ?]type
				start
				end
			}
		} # }}}

		func Identifier(
			name: String
			{ start, end }: Range
		): NodeData(Identifier) { # {{{
			return {
				kind: .Identifier
				modifiers: []
				name
				start
				end
			}
		} # }}}

		func IfExpression(
			condition: Event<NodeData(Expression)>
			declaration: Event<NodeData(VariableDeclaration)>
			whenTrue: Event<NodeData(Block, SetStatement)>(Y)
			whenFalse: Event<NodeData(Block, IfExpression, SetStatement)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(IfExpression) { # {{{
			return {
				kind: .IfExpression
				attributes: []
				condition: condition.value if ?]condition
				declaration: declaration.value if ?]declaration
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value
				start
				end
			}
		} # }}}

		func IfStatement(
			condition: Event<NodeData(Expression)>(Y)
			whenTrue: Event<NodeData(Block, BreakStatement, ContinueStatement, ExpressionStatement, ReturnStatement, SetStatement, ThrowStatement)>(Y)
			whenFalse: Event<NodeData(Block, IfStatement)>
			{ start }: Range
			{ end }: Range
		): NodeData(IfStatement) { # {{{
			return {
				kind: .IfStatement
				attributes: []
				condition: condition.value
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value if ?]whenFalse
				start
				end
			}
		} # }}}

		func IfStatement(
			declarations: NodeData(VariableDeclaration, Expression)[][]
			whenTrue: Event<NodeData(Block, BreakStatement, ContinueStatement, ExpressionStatement, ReturnStatement, SetStatement, ThrowStatement)>(Y)
			whenFalse: Event<NodeData(Block, IfStatement)>
			{ start }: Range
			{ end }: Range
		): NodeData(IfStatement) { # {{{
			return {
				kind: .IfStatement
				attributes: []
				declarations
				whenTrue: whenTrue.value
				whenFalse: whenFalse.value if ?]whenFalse
				start
				end
			}
		} # }}}

		func ImplementDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			variable: Event<NodeData(Identifier, MemberExpression)>(Y)
			interface: Event<NodeData(Identifier, MemberExpression)>
			properties: Event<NodeData(ClassMember)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ImplementDeclaration) { # {{{
			return {
				kind: .ImplementDeclaration
				attributes: [attribute.value for var attribute in attributes]
				variable: variable.value
				interface: interface.value if ?]interface
				properties: [property.value for var property in properties]
				start
				end
			}
		} # }}}

		func ImportDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(ImportDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ImportDeclaration) { # {{{
			return {
				kind: .ImportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func ImportDeclarator(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			source: Event<NodeData(Literal)>(Y)
			arguments: NodeData(NamedArgument, PositionalArgument)[]?
			type: Event<NodeData(DescriptiveType, TypeList)>
			specifiers: Event<NodeData(GroupSpecifier)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ImportDeclarator) { # {{{
			return {
				kind: .ImportDeclarator
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				source: source.value
				arguments: arguments if ?arguments
				type: type.value if ?]type
				specifiers: [specifier.value for var specifier in specifiers]
				start
				end
			}
		} # }}}

		func IncludeAgainDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(IncludeDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(IncludeAgainDeclaration) { # {{{
			return {
				kind: .IncludeAgainDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func IncludeDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(IncludeDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(IncludeDeclaration) { # {{{
			return {
				kind: .IncludeDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func IncludeDeclarator(
			{ value % file, start, end }: Event<String>(Y)
		): NodeData(IncludeDeclarator) { # {{{
			return {
				kind: .IncludeDeclarator
				attributes: []
				file
				start
				end
			}
		} # }}}

		func IterationArray(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>
			type:  Event<NodeData(Type)>
			index: Event<NodeData(Identifier)>
			expression: Event<NodeData(Expression)>(Y)
			from: Event<NodeData(Expression)>
			to: Event<NodeData(Expression)>
			step: Event<NodeData(Expression)>
			split: Event<NodeData(Expression)>
			until: Event<NodeData(Expression)>
			while: Event<NodeData(Expression)>
			when: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): IterationData(Array) { # {{{
			return {
				kind: .Array
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				expression: expression.value
				value: value.value if ?]value
				type: type.value if ?]type
				index: index.value if ?]index
				from: from.value if ?]from
				to: to.value if ?]to
				step: step.value if ?]step
				split: split.value if ?]split
				until: until.value if ?]until
				while: while.value if ?]while
				when: when.value if ?]when
				start
				end
			}
		} # }}}

		func IterationFrom(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			variable: Event<NodeData(Identifier)>(Y)
			from: Event<NodeData(Expression)>(Y)
			to: Event<NodeData(Expression)>(Y)
			step: Event<NodeData(Expression)>
			until: Event<NodeData(Expression)>
			while: Event<NodeData(Expression)>
			when: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): IterationData(From) { # {{{
			return {
				kind: .From
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				variable: variable.value
				from: from.value
				to: to.value
				step: step.value if ?]step
				until: until.value if ?]until
				while: while.value if ?]while
				when: when.value if ?]when
				start
				end
			}
		} # }}}

		func IterationObject(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>
			type:  Event<NodeData(Type)>
			key: Event<NodeData(Identifier)>
			expression: Event<NodeData(Expression)>(Y)
			until: Event<NodeData(Expression)>
			while: Event<NodeData(Expression)>
			when: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): IterationData(Object) { # {{{
			return {
				kind: .Object
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				expression: expression.value
				value: value.value if ?]value
				type: type.value if ?]type
				key: key.value if ?]key
				until: until.value if ?]until
				while: while.value if ?]while
				when: when.value if ?]when
				start
				end
			}
		} # }}}

		func IterationRange(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<NodeData(Identifier)>
			index: Event<NodeData(Identifier)>
			from: Event<NodeData(Expression)>(Y)
			to: Event<NodeData(Expression)>
			step: Event<NodeData(Expression)>
			until: Event<NodeData(Expression)>
			while: Event<NodeData(Expression)>
			when: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): IterationData(Range) { # {{{
			return {
				kind: .Range
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				value: value.value
				index: index.value if ?]index
				from: from.value
				to: to.value
				step: step.value if ?]step
				until: until.value if ?]until
				while: while.value if ?]while
				when: when.value if ?]when
				start
				end
			}
		} # }}}

		func IterationRepeat(
			modifiers: ModifierData[]
			expression: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): IterationData(Repeat) { # {{{
			return {
				kind: .Repeat
				attributes: []
				modifiers
				expression: expression.value
				start
				end
			}
		} # }}}

		func JunctionExpression(
			operator: Event<BinaryOperatorData>(Y)
			operands: NodeData(Expression, Type)[]
		): NodeData(JunctionExpression) { # {{{
			return {
				kind: .JunctionExpression
				modifiers: []
				operator: operator.value
				operands
				start: operands[0].start
				end: operands[operands.length - 1].end
			}
		} # }}}

		func LambdaExpression(
			parameters: Event<Event<NodeData(Parameter)>[]>(Y)
			modifiers: Event<ModifierData>(Y)[]?
			type: Event<NodeData(Type)>?
			throws: Event<Event<NodeData(Identifier)>[]>?
			body: Event<NodeData(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(LambdaExpression) { # {{{
			return {
				kind: .LambdaExpression
				modifiers: if ?modifiers set [modifier.value for var modifier in modifiers] else []
				parameters: [parameter.value for var parameter in parameters.value]
				type: type.value if ?type?.value
				throws: if ?throws set [throw.value for var throw in throws.value] else []
				body: body.value
				start
				end
			}
		} # }}}

		func Literal(
			modifiers: Event<ModifierData>(Y)[]?
			value: String
			start: Position
			end: Position
		): NodeData(Literal) { # {{{
			return {
				kind: .Literal
				modifiers: if ?modifiers set [modifier.value for var modifier in modifiers] else []
				value
				start
				end
			}
		} # }}}

		func Literal(
			modifiers: Event<ModifierData>(Y)[]?
			value: String
			{ start } & first: Range
			{ end }: Range = first
		): NodeData(Literal) { # {{{
			return {
				kind: .Literal
				modifiers: if ?modifiers set [modifier.value for var modifier in modifiers] else []
				value
				start: first.start
				end
			}
		} # }}}

		func MacroDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			parameters: Event<Event<NodeData(Parameter)>(Y)[]>(Y)
			body: Event<NodeData(Block, ExpressionStatement)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(MacroDeclaration) { # {{{
			return {
				kind: .MacroDeclaration
				attributes: [attribute.value for var attribute in attributes]
				name: name.value
				parameters: [parameter.value for var parameter in parameters.value]
				body: body.value
				start
				end
			}
		} # }}}

		func MacroExpression(
			elements: Event<MacroElementData(Expression, Literal)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(MacroExpression) { # {{{
			return {
				kind: .MacroExpression
				attributes: []
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func MacroElementExpression(
			expression: Event<NodeData(Expression)>(Y)
			reification: ReificationData?
			{ start }: Range
			{ end }: Range
		): MacroElementData(Expression) { # {{{
			return {
				kind: .Expression
				expression: expression.value
				reification: reification if ?reification
				start
				end
			}
		} # }}}

		func MacroElementLiteral(
			value: String
			{ start }: Range
			{ end }: Range
		): MacroElementData(Literal) { # {{{
			return {
				kind: .Literal
				value: value
				start
				end
			}
		} # }}}

		func MacroElementNewLine(
			{ start, end }: Range
		): MacroElementData(NewLine) { # {{{
			return {
				kind: .NewLine
				start
				end
			}
		} # }}}

		func MatchClause(
			conditions: Event<NodeData(Expression, MatchConditionArray, MatchConditionObject, MatchConditionRange, MatchConditionType)>(Y)[]
			binding: Event<NodeData(VariableDeclarator, ArrayBinding, ObjectBinding)>
			filter: Event<NodeData(Expression)>
			body: Event<NodeData(Block, Statement)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(MatchClause) { # {{{
			return {
				kind: .MatchClause
				conditions: [condition.value for var condition in conditions]
				binding: binding.value if ?]binding
				filter: filter.value if ?]filter
				body: body.value
				start
				end
			}
		} # }}}

		func MatchConditionArray(
			values: Event<NodeData(Expression, MatchConditionRange, OmittedExpression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(MatchConditionArray) { # {{{
			return {
				kind: .MatchConditionArray
				values: [value.value for var value in values]
				start
				end
			}
		} # }}}

		func MatchConditionObject(
			properties: Event<NodeData(ObjectMember)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(MatchConditionObject) { # {{{
			return {
				kind: .MatchConditionObject
				properties: [property.value for var property in properties]
				start
				end
			}
		} # }}}

		func MatchConditionRangeFI(
			from: Event<NodeData(Expression)>(Y)
			til: Event<NodeData(Expression)>(Y)
		): NodeData(MatchConditionRange) { # {{{
			return {
				kind: .MatchConditionRange
				from: from.value
				til: til.value
				start: from.start
				end: til.end
			}
		} # }}}

		func MatchConditionRangeFO(
			from: Event<NodeData(Expression)>(Y)
			to: Event<NodeData(Expression)>(Y)
		): NodeData(MatchConditionRange) { # {{{
			return {
				kind: .MatchConditionRange
				from: from.value
				to: to.value
				start: from.start
				end: to.end
			}
		} # }}}

		func MatchConditionRangeTI(
			then: Event<NodeData(Expression)>(Y)
			til: Event<NodeData(Expression)>(Y)
		): NodeData(MatchConditionRange) { # {{{
			return {
				kind: .MatchConditionRange
				then: then.value
				til: til.value
				start: then.start
				end: til.end
			}
		} # }}}

		func MatchConditionRangeTO(
			then: Event<NodeData(Expression)>(Y)
			to: Event<NodeData(Expression)>(Y)
		): NodeData(MatchConditionRange) { # {{{
			return {
				kind: .MatchConditionRange
				then: then.value
				to: to.value
				start: then.start
				end: to.end
			}
		} # }}}

		func MatchConditionType(
			type: Event<NodeData(Type)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(MatchConditionType) { # {{{
			return {
				kind: .MatchConditionType
				type: type.value
				start
				end
			}
		} # }}}

		func MatchExpression(
			expression: Event<NodeData(Expression)>(Y)
			clauses: Event<NodeData(MatchClause)[]>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(MatchExpression) { # {{{
			return {
				kind: .MatchExpression
				attributes: []
				expression: expression.value
				clauses: [clause for var clause in clauses.value]
				start
				end
			}
		} # }}}

		func MatchStatement(
			expression: Event<NodeData(Expression)>
			declaration: Event<NodeData(VariableDeclaration)>
			clauses: Event<NodeData(MatchClause)[]>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(MatchStatement) { # {{{
			return {
				kind: .MatchStatement
				attributes: []
				expression: expression.value if ?]expression
				declaration: declaration.value if ?]declaration
				clauses: [clause for var clause in clauses.value]
				start
				end
			}
		} # }}}

		func MemberExpression(
			modifiers: ModifierData[]
			object: Event<NodeData(Expression)>
			property: Event<NodeData(Expression)>(Y)
			{ start }: Range = object ?]] property
			{ end }: Range = property
		): NodeData(MemberExpression) { # {{{
			return {
				kind: .MemberExpression
				modifiers
				object: object.value if ?]object
				property: property.value
				start
				end
			}
		} # }}}

		func MethodDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			typeParameters: Event<Event<NodeData(TypeParameter)>[]>
			parameters: Event<Event<NodeData(Parameter)>(Y)[]>(Y)
			type: Event<NodeData(Type)>?
			throws: Event<Event<NodeData(Identifier)>[]>?
			body: Event<NodeData(Block, Expression, IfStatement, UnlessStatement)>?
			{ start }: Range
			{ end }: Range
		): NodeData(MethodDeclaration) { # {{{
			return {
				kind: .MethodDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				typeParameters: [parameter.value for var parameter in typeParameters.value] if ?]typeParameters && ?#typeParameters.value
				parameters: [parameter.value for var parameter in parameters.value]
				type: type.value if ?type?.value
				throws: if ?throws set [throw.value for var throw in throws.value] else []
				body: body.value if ?body?.value
				start
				end
			}
		} # }}}

		func Modifier(
			kind: ModifierKind
			{ start, end }: Range
			last: Range? = null
		): ModifierData { # {{{
			return {
				kind: kind
				start
				end: last?.end ?? end
			}!!!
		} # }}}

		func Module(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			body: NodeData(Statement)[]
			parser: Parser
		): NodeData(Module) { # {{{
			return {
				kind: .Module
				attributes: [attribute.value for var attribute in attributes]
				body,
				start: {
					line: 1
					column: 1
				}
				end: parser.position().end
			}
		} # }}}

		func MutatorDeclaration(
			{ start, end }: Range
		): NodeData(MutatorDeclaration) { # {{{
			return {
				kind: .MutatorDeclaration
				start
				end
			}
		} # }}}

		func MutatorDeclaration(
			body: Event<NodeData(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(MutatorDeclaration) { # {{{
			return {
				kind: .MutatorDeclaration
				body: body.value
				start
				end
			}
		} # }}}

		func NamedArgument(
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			value: Event<NodeData(Expression, PlaceholderArgument)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(NamedArgument) { # {{{
			return {
				kind: .NamedArgument
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				value: value.value
				start
				end
			}
		} # }}}

		func NamedSpecifier(
			{ value % internal, start, end }: Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>(Y)
		): NodeData(NamedSpecifier) { # {{{
			return {
				kind: .NamedSpecifier
				modifiers: []
				internal
				start
				end
			}
		} # }}}

		func NamedSpecifier(
			modifiers: Event<ModifierData>(Y)[]
			internal: Event<NodeData(Identifier, MemberExpression, ArrayBinding, ObjectBinding)>(Y)
			external: Event<NodeData(Identifier)>
			{ start }: Range
			{ end }: Range
		): NodeData(NamedSpecifier) { # {{{
			return {
				kind: .NamedSpecifier
				modifiers: [modifier.value for var modifier in modifiers]
				internal: internal.value
				external: external.value if ?]external
				start
				end
			}
		} # }}}

		func NamespaceDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			statements: Event<NodeData(Statement)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(NamespaceDeclaration) { # {{{
			return {
				kind: .NamespaceDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				statements: [statement.value for var statement in statements]
				start
				end
			}
		} # }}}

		func NumericExpression(
			value: Number
			radix: Number
			{ start, end }: Range
		): NodeData(NumericExpression) { # {{{
			return {
				kind: .NumericExpression
				modifiers: []
				value
				radix
				start
				end
			}
		} # }}}

		func ObjectBinding(
			elements: Event<NodeData(BindingElement)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ObjectBinding) { # {{{
			return {
				kind: .ObjectBinding
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func ObjectBindingElement(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			external: Event<NodeData(Identifier)>
			internal: Event<NodeData(Identifier, ArrayBinding, ObjectBinding, ThisExpression)>
			type: Event<NodeData(Type)>
			operator: Event<BinaryOperatorData(Assignment)>
			defaultValue: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(BindingElement) { # {{{
			return {
				kind: .BindingElement
				attributes: [attribute.value for var attribute in attributes] if ?#attributes
				modifiers
				external: external.value if ?]external
				internal: internal.value if ?]internal
				type: type.value if ?]type
				operator: operator.value if ?]operator
				defaultValue: defaultValue.value if ?]defaultValue
				start
				end
			}
		} # }}}

		func ObjectComprehension(
			name: Event<NodeData(ComputedPropertyName, TemplateExpression)>(Y)
			value: Event<NodeData(Expression)>(Y)
			iteration: Event<IterationData>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(ObjectComprehension) { # {{{
			return {
				kind: .ObjectComprehension
				modifiers: []
				name: name.value
				value: value.value
				iteration: iteration.value
				start
				end
			}
		} # }}}

		func ObjectExpression(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			properties: Event<NodeData(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ObjectExpression) { # {{{
			return {
				kind: .ObjectExpression
				modifiers: []
				attributes: [attribute.value for var attribute in attributes]
				properties: [property.value for var property in properties]
				start
				end
			}
		} # }}}

		func ObjectMember(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier, ComputedPropertyName, Literal, TemplateExpression)>
			type: Event<NodeData(Type)>
			value: Event<NodeData(Expression, MatchConditionRange)>
			{ start }: Range
			{ end }: Range
		): NodeData(ObjectMember) { # {{{
			return {
				kind: .ObjectMember
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value if ?]name
				type: type.value if ?]type
				value: value.value if ?]value
				start
				end
			}
		} # }}}

		func ObjectType(
			modifiers: Event<ModifierData>(Y)[]
			properties: Event<NodeData(PropertyType)>(Y)[]
			rest: Event<NodeData(PropertyType)>(Y)?
			{ start }: Range
			{ end }: Range
		): NodeData(ObjectType) { # {{{
			return {
				kind: .ObjectType
				modifiers: [modifier.value for var modifier in modifiers]
				properties: [property.value for var property in properties]
				rest: rest.value if ?rest
				start
				end
			}
		} # }}}

		func OmittedExpression(
			modifiers: ModifierData[]
			{ start, end }: Range
		): NodeData(OmittedExpression) { # {{{
			return {
				kind: .OmittedExpression
				modifiers
				start
				end
			}
		} # }}}

		func OmittedReference(
			{ start, end }: Range
		): NodeData(TypeReference) { # {{{
			return {
				kind: .TypeReference
				modifiers: []
				start
				end
			}
		} # }}}

		func PassStatement(
			{ start, end }: Range
		): NodeData(PassStatement) { # {{{
			return {
				kind: .PassStatement
				attributes: []
				start
				end
			}
		} # }}}

		func Parameter(
			{ value, start, end }
		): NodeData(Parameter) { # {{{
			return {
				kind: .Parameter
				attributes: []
				modifiers: []
				internal: value
				external: value
				start
				end
			}
		} # }}}

		func Parameter(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			external: Event<NodeData(Identifier)>(Y)?
			internal: Event<NodeData(Identifier, ArrayBinding, ObjectBinding, ThisExpression)>(Y)?
			type: Event<NodeData(Type)>(Y)?
			operator: Event<BinaryOperatorData(Assignment)>(Y)?
			defaultValue: Event<NodeData(Expression)>(Y)?
			{ start }: Range
			{ end }: Range
		): NodeData(Parameter) { # {{{
			return {
				kind: .Parameter
				attributes: [attribute.value for var attribute in attributes]
				modifiers
				external: external.value if ?external
				internal: internal.value if ?internal
				type: type.value if ?type
				operator: operator.value if ?operator
				defaultValue: defaultValue.value if ?defaultValue
				start
				end
			}
		} # }}}

		func PlaceholderArgument(
			modifiers: Event<ModifierData>(Y)[]
			index: Event<NodeData(NumericExpression)>
			{ start }: Range
			{ end }: Range
		): NodeData(PlaceholderArgument) { # {{{
			return {
				kind: .PlaceholderArgument
				modifiers: [modifier.value for var modifier in modifiers]
				index: index.value if ?]index
				start
				end
			}
		} # }}}

		func PositionalArgument(
			modifiers: Event<ModifierData>(Y)[]
			value: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(PositionalArgument) { # {{{
			return {
				kind: .PositionalArgument
				modifiers: [modifier.value for var modifier in modifiers]
				value: value.value
				start
				end
			}
		} # }}}

		func PropertiesSpecifier(
			modifiers: Event<ModifierData>(Y)[]
			object: Event<NodeData(Identifier, MemberExpression)>(Y)
			properties: Event<NodeData(NamedSpecifier)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(PropertiesSpecifier) { # {{{
			return {
				kind: .PropertiesSpecifier
				modifiers: [modifier.value for var modifier in modifiers]
				object: object.value
				properties: [property.value for var property in properties]
				start
				end
			}
		} # }}}

		func PropertyDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			type: Event<NodeData(Type)>
			defaultValue: Event<NodeData(Expression)>
			accessor: Event<NodeData(AccessorDeclaration)>
			mutator: Event<NodeData(MutatorDeclaration)>
			{ start }: Range
			{ end }: Range
		): NodeData(PropertyDeclaration) { # {{{
			return {
				kind: .PropertyDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				type: type.value if ?]type
				defaultValue: defaultValue.value if ?]defaultValue
				accessor: accessor.value if ?]accessor
				mutator: mutator.value if ?]mutator
				start
				end
			}
		} # }}}

		func PropertyType(
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>
			type: Event<NodeData(Type)>
			{ start }: Range
			{ end }: Range
		): NodeData(PropertyType) { # {{{
			return {
				kind: .PropertyType
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value if ?]name
				type: type.value if ?]type
				start
				end
			}
		} # }}}

		func ProxyDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			internal: Event<NodeData(Identifier)>(Y)
			external: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(ProxyDeclaration) { # {{{
			return {
				kind: .ProxyDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				internal: internal.value
				external: external.value
				start
				end
			}
		} # }}}

		func ProxyGroupDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			recipient: Event<NodeData(Expression)>(Y)
			elements: Event<NodeData(ProxyDeclaration)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(ProxyGroupDeclaration) { # {{{
			return {
				kind: .ProxyGroupDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				recipient: recipient.value
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func Reference(
			name: String
			{ start, end }: Range
		): NodeData(Reference) { # {{{
			return {
				kind: .Reference
				name
				start
				end
			}
		} # }}}

		func RegularExpression(
			value: String
			{ start, end }: Range
		): NodeData(RegularExpression) { # {{{
			return {
				kind: .RegularExpression
				modifiers: []
				value
				start
				end
			}
		} # }}}

		func Reification(
			kind: ReificationKind
			{ start, end }: Range
		): ReificationData { # {{{
			return {
				kind: kind
				start
				end
			}!!!
		} # }}}

		func RepeatStatement(
			expression: Event<NodeData(Expression)>
			body: Event<NodeData(Block, ExpressionStatement)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(RepeatStatement) { # {{{
			return {
				kind: .RepeatStatement
				attributes: []
				expression: expression.value if ?]expression
				body: body.value
				start
				end
			}
		} # }}}

		func RequireDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(RequireDeclaration) { # {{{
			return {
				kind: .RequireDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func RequireOrExternDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(RequireOrExternDeclaration) { # {{{
			return {
				kind: .RequireOrExternDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func RequireOrImportDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			declarations: Event<NodeData(ImportDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(RequireOrImportDeclaration) { # {{{
			return {
				kind: .RequireOrImportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func RestModifier(
			min: Number
			max: Number
			{ start }: Range
			{ end }: Range
		): ModifierData(Rest) { # {{{
			return {
				kind: .Rest
				arity: {
					min: min
					max: max
				}
				start
				end
			}
		} # }}}

		func RestrictiveExpression(
			operator: Event<RestrictiveOperatorData>(Y)
			condition: Event<NodeData(Expression)>(Y)
			expression: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(RestrictiveExpression) { # {{{
			return {
				kind: .RestrictiveExpression
				operator: operator.value
				condition: condition.value
				expression: expression.value
				start
				end
			}
		} # }}}

		func RestrictiveOperator(
			operator: RestrictiveOperatorKind
			{ start, end }: Range
		): RestrictiveOperatorData { # {{{
			return {
				kind: operator
				modifiers: []
				start
				end
			}!!!
		} # }}}

		func ReturnStatement(
			{ start, end }: Range
		): NodeData(ReturnStatement) { # {{{
			return {
				kind: .ReturnStatement
				attributes: []
				start
				end
			}
		} # }}}

		func ReturnStatement(
			value: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(ReturnStatement) { # {{{
			return {
				kind: .ReturnStatement
				attributes: []
				value: value.value
				start
				end
			}
		} # }}}

		func RollingExpression(
			modifiers: ModifierData[]
			object: Event<NodeData(Expression)>(Y)
			expressions: Event<NodeData(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(RollingExpression) { # {{{
			return {
				kind: .RollingExpression
				modifiers
				object: object.value
				expressions: [expression.value for var expression in expressions]
				start
				end
			}
		} # }}}

		func Scope(
			scope: ScopeKind
		): ScopeData { # {{{
			return {
				kind: scope
			}
		} # }}}

		func Scope(
			scope: ScopeKind
			value: Event<NodeData(Argument, Identifier, ObjectExpression)>(Y)
		): ScopeData { # {{{
			return {
				kind: scope
				value: value.value
			}
		} # }}}

		func SequenceExpression(
			expressions: Event<NodeData(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(SequenceExpression) { # {{{
			return {
				kind: .SequenceExpression
				modifiers: []
				expressions: [expression.value for var expression in expressions]
				start
				end
			}
		} # }}}

		func SetStatement(
			{ start, end }: Range
		): NodeData(SetStatement) { # {{{
			return {
				kind: .SetStatement
				attributes: []
				start
				end
			}
		} # }}}

		func SetStatement(
			value: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(SetStatement) { # {{{
			return {
				kind: .SetStatement
				attributes: []
				value: value.value
				start
				end
			}
		} # }}}

		func ShebangDeclaration(
			command: String
			{ start }: Range
			{ end }: Range
		): NodeData(ShebangDeclaration) { # {{{
			return {
				kind: .ShebangDeclaration
				command
				start
				end
			}
		} # }}}

		func ShorthandProperty(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			name: Event<NodeData(Identifier, ComputedPropertyName, Literal, TemplateExpression, ThisExpression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(ShorthandProperty) { # {{{
			return {
				kind: .ShorthandProperty
				attributes: [attribute.value for var attribute in attributes]
				name: name.value
				start
				end
			}
		} # }}}

		func SpreadExpression(
			modifiers: Event<ModifierData>(Y)[]
			operand: Event<NodeData(Expression)>(Y)
			members: Event<NodeData(NamedSpecifier)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(SpreadExpression) { # {{{
			return {
				kind: .SpreadExpression
				attributes: []
				modifiers: [modifier.value for var modifier in modifiers]
				operand: operand.value
				members: [member.value for var member in members]
				start
				end
			}
		} # }}}

		func StructDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			extends: Event<NodeData(TypeReference)>
			implements: Event<NodeData(Identifier, MemberExpression)>(Y)[]
			fields: NodeData(FieldDeclaration)[]
			{ start }: Range
			{ end }: Range
		): NodeData(StructDeclaration) { # {{{
			return {
				kind: .StructDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				extends: extends.value if ?]extends
				implements: [implement.value for var implement in implements] if ?#implements
				fields
				start
				end
			}
		} # }}}

		func TaggedTemplateExpression(
			tag: Event<NodeData(Expression)>
			template: Event<NodeData(TemplateExpression)>
			{ start }: Range
			{ end }: Range
		): NodeData(TaggedTemplateExpression) { # {{{
			return {
				kind: .TaggedTemplateExpression
				tag: tag.value
				template: template.value
				start
				end
			}
		} # }}}

		func TemplateExpression(
			modifiers: Event<ModifierData>(Y)[]
			elements: Event<NodeData(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(TemplateExpression) { # {{{
			return {
				kind: .TemplateExpression
				modifiers: [modifier.value for var modifier in modifiers]
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func ThisExpression(
			name: Event<NodeData(Identifier)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(ThisExpression) { # {{{
			return {
				kind: .ThisExpression
				modifiers: []
				name: name.value
				start
				end
			}
		} # }}}

		func ThrowStatement(
			{ start, end }: Range
		): NodeData(ThrowStatement) { # {{{
			return {
				kind: .ThrowStatement
				attributes: []
				start
				end
			}
		} # }}}

		func ThrowStatement(
			value: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(ThrowStatement) { # {{{
			return {
				kind: .ThrowStatement
				attributes: []
				value: value.value
				start
				end
			}
		} # }}}

		func TopicReference(
			modifiers: ModifierData[] = []
			{ start, end }: Range
		): NodeData(TopicReference) { # {{{
			return {
				kind: .TopicReference
				modifiers
				start
				end
			}
		} # }}}

		func TryExpression(
			modifiers: ModifierData[]
			argument: Event<NodeData(Expression)>(Y)
			defaultValue: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(TryExpression) { # {{{
			return {
				kind: .TryExpression
				modifiers
				argument: argument.value
				defaultValue: defaultValue.value if ?]defaultValue
				start
				end
			}
		} # }}}

		func TryStatement(
			body: Event<NodeData(Block)>(Y)
			catchClauses: Event<NodeData(CatchClause)>(Y)[]
			catchClause: Event<NodeData(CatchClause)>
			finalizer: Event<NodeData(Block)>
			{ start }: Range
			{ end }: Range
		): NodeData(TryStatement) { # {{{
			return {
				kind: .TryStatement
				attributes: []
				body: body.value
				catchClauses: [clause.value for var clause in catchClauses]
				catchClause: catchClause.value if ?]catchClause
				finalizer: finalizer.value if ?]finalizer
				start
				end
			}
		} # }}}

		func TupleDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			extends: Event<NodeData(Identifier)>
			implements: Event<NodeData(Identifier, MemberExpression)>(Y)[]
			fields: NodeData(TupleField)[]
			{ start }: Range
			{ end }: Range
		): NodeData(TupleDeclaration) { # {{{
			return {
				kind: .TupleDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				extends: extends.value if ?]extends
				implements: [implement.value for var implement in implements] if ?#implements
				fields
				start
				end
			}
		} # }}}

		func TupleField(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>
			type: Event<NodeData(Type)>
			defaultValue: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(TupleField) { # {{{
			return {
				kind: .TupleField
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value if ?]name
				type: type.value if ?]type
				defaultValue: defaultValue.value if ?]defaultValue
				start
				end
			}
		} # }}}

		func TypedExpression(
			modifiers: Event<ModifierData>(Y)[]
			expression: Event<NodeData(Expression)>(Y)
			parameters: Event<NodeData(Type)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(TypedExpression) { # {{{
			return {
				kind: .TypedExpression
				modifiers: [modifier.value for var modifier in modifiers]
				expression: expression.value
				typeParameters: [parameter.value for var parameter in parameters]
				start
				end
			}
		} # }}}

		func TypedSpecifier(
			type: Event<NodeData(DescriptiveType)>(Y)
			{ start, end }: Range
		): NodeData(TypedSpecifier) { # {{{
			return {
				kind: .TypedSpecifier
				type: type.value
				start
				end
			}
		} # }}}

		func TypeAliasDeclaration(
			name: Event<NodeData(Identifier)>(Y)
			parameters: Event<Event<NodeData(TypeParameter)>[]>
			type: Event<NodeData(Type)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(TypeAliasDeclaration) { # {{{
			return {
				kind: .TypeAliasDeclaration
				attributes: []
				name: name.value
				typeParameters: [parameter.value for var parameter in parameters.value] if ?]parameters && ?#parameters.value
				type: type.value
				start
				end
			}
		} # }}}

		func TypeList(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			types: Event<NodeData(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(TypeList) { # {{{
			return {
				kind: .TypeList
				attributes: [attribute.value for var attribute in attributes]
				types: [type.value for var type in types]
				start
				end
			}
		} # }}}

		func TypeParameter(
			name: Event<NodeData(Identifier)>(Y)
			constraint: Event<NodeData(Type)>
			{ start }: Range
			{ end }: Range
		): NodeData(TypeParameter) { # {{{
			return {
				kind: .TypeParameter
				modifiers: []
				name: name.value
				constraint: constraint.value if ?]constraint
				start
				end
			}
		} # }}}

		func TypeReference(
			{ value % typeName, start, end }: Event<NodeData(Identifier, MemberExpression, UnaryExpression)>(Y)
		): NodeData(TypeReference) { # {{{
			return {
				kind: .TypeReference
				modifiers: []
				typeName
				start
				end
			}
		} # }}}

		func TypeReference(
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier, MemberExpression, UnaryExpression)>(Y)
			parameters: Event<Event<NodeData(Type)>(Y)[]>
			subtypes: Event<Event<NodeData(Identifier)>(Y)[] | NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(TypeReference) { # {{{
			return {
				kind: .TypeReference
				modifiers: [modifier.value for var modifier in modifiers]
				typeName: name.value
				typeParameters: [parameter.value for var parameter in parameters.value] if ?]parameters
				typeSubtypes: (
					if subtypes.value is Array {
						set [subtype.value for var subtype in subtypes.value]
					}
					else {
						set subtypes.value
					}
				) if ?]subtypes
				start
				end
			}
		} # }}}

		func UnaryExpression(
			modifiers: Event<ModifierData>(Y)[]
			operator: Event<UnaryOperatorData>(Y)
			argument: Event<NodeData(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(UnaryExpression) { # {{{
			return {
				kind: .UnaryExpression
				modifiers: [modifier.value for var modifier in modifiers]
				operator: operator.value
				argument: argument.value
				start
				end
			}
		} # }}}

		func UnaryOperator(
			operator: UnaryOperatorKind
			{ start, end }: Range
		): UnaryOperatorData { # {{{
			return {
				kind: operator
				start
				end
			}!!!
		} # }}}

		func UnaryTypeExpression(
			modifiers: Event<ModifierData>(Y)[]
			operator: Event<UnaryTypeOperatorData>(Y)
			argument: Event<NodeData(Type, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(UnaryTypeExpression) { # {{{
			return {
				kind: .UnaryTypeExpression
				modifiers: [modifier.value for var modifier in modifiers]
				operator: operator.value
				argument: argument.value
				start
				end
			}
		} # }}}

		func UnaryTypeOperator(
			operator: UnaryTypeOperatorKind
			{ start, end }: Range
		): UnaryTypeOperatorData { # {{{
			return {
				kind: operator
				start
				end
			}!!!
		} # }}}

		func UnionType(
			types: Event<NodeData(Type)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(UnionType) { # {{{
			return {
				kind: .UnionType
				types: [type.value for var type in types]
				start
				end
			}
		} # }}}

		func UnlessStatement(
			condition: Event<NodeData(Expression)>(Y)
			whenFalse: Event<NodeData(Block, BreakStatement, ContinueStatement, ExpressionStatement, ReturnStatement, SetStatement, ThrowStatement)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(UnlessStatement) { # {{{
			return {
				kind: .UnlessStatement
				attributes: []
				condition: condition.value
				whenFalse: whenFalse.value
				start
				end
			}
		} # }}}

		func UntilStatement(
			condition: Event<NodeData(Expression)>(Y)
			body: Event<NodeData(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(UntilStatement) { # {{{
			return {
				kind: .UntilStatement
				attributes: []
				condition: condition.value
				body: body.value
				start
				end
			}
		} # }}}

		func VariableDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			variables: Event<NodeData(VariableDeclarator)>(Y)[]
			operator: Event<BinaryOperatorData(Assignment)>
			value: Event<NodeData(Expression)>
			{ start }: Range
			{ end }: Range
		): NodeData(VariableDeclaration) { # {{{
			return {
				kind: .VariableDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				variables: [variable.value for var variable in variables]
				operator: operator.value if ?]operator
				value: value.value if ?]value
				start
				end
			}
		} # }}}

		func VariableDeclarator(
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier, ArrayBinding, ObjectBinding)>(Y)
			type: Event<NodeData(Type)>
			{ start }: Range
			{ end }: Range
		): NodeData(VariableDeclarator) { # {{{
			return {
				kind: .VariableDeclarator
				attributes: []
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				type: type.value if ?]type
				start
				end
			}
		} # }}}

		func VariableStatement(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			declarations: Event<NodeData(VariableDeclaration)>(Y)[]
			{ start }: Range
			{ end }: Range
		): NodeData(VariableStatement) { # {{{
			return {
				kind: .VariableStatement
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func VariantDeclaration(
			attributes: Event<NodeData(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<NodeData(Identifier)>(Y)
			fields: NodeData(VariantField)[]
			{ start }: Range
			{ end }: Range
		): NodeData(VariantDeclaration) { # {{{
			return {
				kind: .VariantDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				fields
				start
				end
			}
		} # }}}

		func VariantField(
			names: Event<NodeData(Identifier)>(Y)[]
			type: Event<NodeData(Type)>
			{ start }: Range
			{ end }: Range
		): NodeData(VariantField) { # {{{
			return {
				kind: .VariantField
				attributes: []
				modifiers: []
				names: [name.value for var name in names]
				type: type.value if ?]type
				start
				end
			}
		} # }}}

		func VariantType(
			master: Event<NodeData(TypeReference)>(Y)
			properties: NodeData(VariantField)[]
			{ start }: Range
			{ end }: Range
		): NodeData(VariantType) { # {{{
			return {
				kind: .VariantType
				master: master.value
				properties
				start
				end
			}
		} # }}}

		func Version(
			major: String
			minor: String = '0'
			patch: String = '0'
			{ start, end }: Range
		): VersionData { # {{{
			return {
				major
				minor
				patch
				start
				end
			}
		} # }}}

		func WhileStatement(
			condition: Event<NodeData(Expression, VariableDeclaration)>(Y)
			body: Event<NodeData(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): NodeData(WhileStatement) { # {{{
			return {
				kind: .WhileStatement
				attributes: []
				condition: condition.value
				body: body.value
				start
				end
			}
		} # }}}

		func WithStatement(
			variables: Event<NodeData(BinaryExpression, VariableDeclaration)>(Y)[]
			body: Event<NodeData(Block)>(Y)
			finalizer: Event<NodeData(Block)>
			{ start }: Range
			{ end }: Range
		): NodeData(WithStatement) { # {{{
			return {
				kind: .WithStatement
				attributes: []
				variables: [variable.value for var variable in variables]
				body: body.value
				finalizer: finalizer.value if ?]finalizer
				start
				end
			}
		} # }}}
	}
}
