namespace AST {
	var CONDITIONAL_PRECEDENCE = 4

	export func pushAttributes(
		// TODO
		// data: Range & { attributes: Ast(AttributeDeclaration)[] }
		data
		attributes: Event<Ast(AttributeDeclaration)>(Y)[]
	): Void { # {{{
		if ?#attributes {
			data.start = attributes[0].value.start

			while ?#attributes {
				data.attributes.unshift(attributes.pop().value)
			}
		}
	} # }}}

	export func pushModifier<T is Ast>(
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
	// export func reorderExpression(operations: BinaryOperationData[]): Ast(Expression) { # {{{
	export func reorderExpression<T is Ast>(operations: T[]): T { # {{{
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
						// var mut operand: Ast(BinaryExpression, PolyadicExpression)? = null
						// var mut operand = null

						if operator is .BinaryExpression {
							var left = operations[k - 1]

							if left is .BinaryExpression && operator.operator.kind == left.operator.kind && operator.operator.kind.attribute ~~ OperatorAttribute.Polyadic {
								operator.kind = AstKind.PolyadicExpression
								operator.start = left.start
								operator.end = operations[k + 1].end

								operator.operands = [left.left, left.right, operations[k + 1]]
								// operand = {
								// 	kind: AstKind.PolyadicExpression
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
		): Ast(AccessorDeclaration) { # {{{
			return {
				kind: .AccessorDeclaration
				start
				end
			}
		} # }}}

		func AccessorDeclaration(
			{ value % body }: Event<Ast(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(AccessorDeclaration) { # {{{
			return {
				kind: .AccessorDeclaration
				body
				start
				end
			}
		} # }}}

		func ArrayBinding(
			elements: Event<Ast(BindingElement)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ArrayBinding) { # {{{
			return {
				kind: .ArrayBinding
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func ArrayBindingElement(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			internal: Event<Ast(Identifier, ArrayBinding, ObjectBinding, ThisExpression)>
			type: Event<Ast(Type)>
			operator: Event<BinaryOperatorData(Assignment)>
			defaultValue: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(BindingElement) { # {{{
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
			value: Event<Ast(Expression)>(Y)
			iteration: Event<IterationData>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(ArrayComprehension) { # {{{
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
			values: Event<Ast(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ArrayExpression) { # {{{
			return {
				kind: .ArrayExpression
				modifiers: []
				values: [value.value for var value in values]
				start
				end
			}
		} # }}}

		func ArrayRangeFI(
			from: Event<Ast(Expression)>(Y)
			til: Event<Ast(Expression)>(Y)
			by: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(ArrayRange) { # {{{
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
			from: Event<Ast(Expression)>(Y)
			to: Event<Ast(Expression)>(Y)
			by: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(ArrayRange) { # {{{
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
			then: Event<Ast(Expression)>(Y)
			til: Event<Ast(Expression)>(Y)
			by: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(ArrayRange) { # {{{
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
			then: Event<Ast(Expression)>(Y)
			to: Event<Ast(Expression)>(Y)
			by: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(ArrayRange) { # {{{
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
			properties: Event<Ast(PropertyType)>(Y)[]
			rest: Event<Ast(PropertyType)>
			{ start }: Range
			{ end }: Range
		): Ast(ArrayType) { # {{{
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
			declaration: Event<Ast(Identifier, AttributeExpression, AttributeOperation)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(AttributeDeclaration) { # {{{
			return {
				kind: .AttributeDeclaration
				declaration: declaration.value
				start
				end
			}
		} # }}}

		func AttributeExpression(
			name: Event<Ast(Identifier)>(Y)
			arguments: Event<Ast(Identifier, AttributeOperation, AttributeExpression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(AttributeExpression) { # {{{
			return {
				kind: .AttributeExpression
				name: name.value
				arguments: [argument.value for var argument in arguments]
				start
				end
			}
		} # }}}

		func AttributeOperation(
			name: Event<Ast(Identifier)>(Y)
			value: Event<Ast(Literal)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(AttributeOperation) { # {{{
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
			variables: Event<Ast(VariableDeclarator)>(Y)[]
			operation: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(AwaitExpression) { # {{{
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
		): Ast(BinaryExpression) { # {{{
			return {
				kind: .BinaryExpression
				modifiers: []
				operator: value
				start
				end
			}
		} # }}}

		func BinaryExpression(
			left: Event<Ast(Expression)>(Y)
			operator: Event<BinaryOperatorData>(Y)
			right: Event<Ast(Expression, Type)>(Y)
			{ start }: Range = left
			{ end }: Range = right
		): Ast(BinaryExpression) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			type: Event<Ast(Identifier)>
			members: Ast(BitmaskValue, MethodDeclaration)[]
			{ start }: Range
			{ end }: Range
		): Ast(BitmaskDeclaration) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			value: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(BitmaskValue) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			statements: Event<Ast(Statement)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(Block) { # {{{
			return {
				kind: .Block
				attributes: [attribute.value for var attribute in attributes]
				statements: [statement.value for var statement in statements]
				start
				end
			}
		} # }}}

		func BlockStatement(
			label: Event<Ast(Identifier)>(Y)
			body: Event<Ast(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(BlockStatement) { # {{{
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
			label: Event<Ast(Identifier)>
			{ start }: Range
			{ end }: Range
		): Ast(BreakStatement) { # {{{
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
			callee: Event<Ast(Expression)>(Y)
			arguments: Event<Event<Ast(Argument, Expression)>(Y)[]>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(CallExpression) { # {{{
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
			binding: Event<Ast(Identifier)>
			type: Event<Ast(Identifier)>
			body: Event<Ast(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(CatchClause) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			typeParameters: Event<Event<Ast(TypeParameter)>[]>
			version: Event<VersionData>
			extends: Event<Ast(Identifier, MemberExpression)>
			implements: Event<Ast(Identifier, MemberExpression)>(Y)[]
			members: Event<Ast(ClassMember)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ClassDeclaration) { # {{{
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
			values: Array<Ast(Expression) | BinaryOperatorData>
		): Ast(ComparisonExpression) { # {{{
			return {
				kind: .ComparisonExpression
				modifiers: []
				values
				start: values[0].start
				end: values[values.length - 1].end
			}
		} # }}}

		func ComputedPropertyName(
			expression: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(ComputedPropertyName) { # {{{
			return {
				kind: .ComputedPropertyName
				expression: expression.value
				start
				end
			}
		} # }}}

		func ContinueStatement(
			label: Event<Ast(Identifier)>
			{ start }: Range
			{ end }: Range
		): Ast(ContinueStatement) { # {{{
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
			callee: Event<Ast(Expression)>(Y)
			arguments: Event<Event<Ast(Argument, Expression)>(Y)[]>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(CurryExpression) { # {{{
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
			{ value % declaration, start, end }: Event<Ast(SpecialDeclaration)>(Y)
		): Ast(DeclarationSpecifier) { # {{{
			return {
				kind: .DeclarationSpecifier
				declaration
				start
				end
			}
		} # }}}

		func DiscloseDeclaration(
			name: Event<Ast(Identifier)>(Y)
			typeParameters: Event<Event<Ast(TypeParameter)>[]>
			members: Event<Ast(ClassMember)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(DiscloseDeclaration) { # {{{
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
			condition: Event<Ast(Expression)>(Y)
			mainExpression: Event<Ast(Expression)>(Y)
			disruptedExpression: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(DisruptiveExpression) { # {{{
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
			condition: Event<Ast(Expression)>(Y)
			body: Event<Ast(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(DoUntilStatement) { # {{{
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
			condition: Event<Ast(Expression)>(Y)
			body: Event<Ast(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(DoWhileStatement) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			type: Event<Ast(TypeReference)>
			initial: Event<Ast(Expression)>
			step: Event<Ast(Expression)>
			members: Ast(EnumValue, FieldDeclaration, MethodDeclaration)[]
			{ start }: Range
			{ end }: Range
		): Ast(EnumDeclaration) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			value: Event<Ast(Expression)>
			arguments: Event<Ast(Argument, Expression)>(Y)[]?
			{ start }: Range
			{ end }: Range
		): Ast(EnumValue) { # {{{
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
			types: Event<Ast(Type)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ExclusionType) { # {{{
			return {
				kind: .ExclusionType
				types: [type.value for var type in types]
				start
				end
			}
		} # }}}

		func ExportDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(DeclarationSpecifier, GroupSpecifier, NamedSpecifier, PropertiesSpecifier)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ExportDeclaration) { # {{{
			return {
				kind: .ExportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func ExpressionStatement(
			{ value % expression, start, end }: Event<Ast(Expression)>(Y)
		): Ast(ExpressionStatement) { # {{{
			return {
				kind: .ExpressionStatement
				attributes: []
				expression
				start
				end
			}
		} # }}}

		func ExternDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ExternDeclaration) { # {{{
			return {
				kind: .ExternDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func ExternOrImportDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(ImportDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ExternOrImportDeclaration) { # {{{
			return {
				kind: .ExternOrImportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func ExternOrRequireDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ExternOrRequireDeclaration) { # {{{
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
		): Ast(FallthroughStatement) { # {{{
			return {
				kind: .FallthroughStatement
				attributes: []
				start
				end
			}
		} # }}}

		func FieldDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			type: Event<Ast(Type)>
			value: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(FieldDeclaration) { # {{{
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
			body: Event<Ast(Block, ExpressionStatement)>(Y)
			else: Event<Ast(Block)>
			{ start }: Range
			{ end }: Range
		): Ast(ForStatement) { # {{{
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
		// 	name: Event<Ast(Identifier)>(Y)
		// 	typeParameters: Event<Event<Ast(TypeParameter)>(Y)[]>
		// 	parameters: Event<Event<Ast(Parameter)>(Y)[]>
		// 	type: Event<Ast(Type)>
		// 	throws: Event<Event<Ast(Identifier)>(Y)[]>
		// 	body: Event<Ast(Block, Expression, IfStatement, UnlessStatement)>
		// 	{ start }: Range
		// 	{ end }: Range
		// ): Ast(FunctionDeclaration) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]?
			name: Event<Ast(Identifier)>(Y)
			typeParameters: Event<Event<Ast(TypeParameter)>[]>
			parameters: Event<Event<Ast(Parameter)>(Y)[]>(Y)?
			type: Event<Ast(Type)>?
			throws: Event<Event<Ast(Identifier)>[]>?
			body: Event<Ast(Block, Expression, IfStatement, UnlessStatement)>(Y)?
			{ start }: Range
			{ end }: Range
		): Ast(FunctionDeclaration) { # {{{
			return {
				kind: .FunctionDeclaration
				attributes: [attribute.value for var attribute in attributes]
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
			parameters: Event<Event<Ast(Parameter)>[]>(Y)
			modifiers: Event<ModifierData>(Y)[]?
			type: Event<Ast(Type)>?
			throws: Event<Event<Ast(Identifier)>[]>?
			body: Event<Ast(Block, Expression, IfStatement, UnlessStatement)>(Y)?
			{ start }: Range
			{ end }: Range
		): Ast(FunctionExpression) { # {{{
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
			types: Event<Ast(Type)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(FusionType) { # {{{
			return {
				kind: .FusionType
				types: [type.value for var type in types]
				start
				end
			}
		} # }}}

		func GroupSpecifier(
			modifiers: Event<ModifierData>(Y)[]
			elements: Event<Ast(NamedSpecifier, TypedSpecifier)>(Y)[]
			type: Event<Ast(DescriptiveType)>
			{ start }: Range
			{ end }: Range
		): Ast(GroupSpecifier) { # {{{
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
		): Ast(Identifier) { # {{{
			return {
				kind: .Identifier
				modifiers: []
				name
				start
				end
			}
		} # }}}

		func IfExpression(
			condition: Event<Ast(Expression)>
			declaration: Event<Ast(VariableDeclaration)>
			whenTrue: Event<Ast(Block, SetStatement)>(Y)
			whenFalse: Event<Ast(Block, IfExpression, SetStatement)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(IfExpression) { # {{{
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
			condition: Event<Ast(Expression)>(Y)
			whenTrue: Event<Ast(Block, BreakStatement, ContinueStatement, ExpressionStatement, ReturnStatement, SetStatement, ThrowStatement)>(Y)
			whenFalse: Event<Ast(Block, IfStatement)>
			{ start }: Range
			{ end }: Range
		): Ast(IfStatement) { # {{{
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
			declarations: Ast(VariableDeclaration, Expression)[][]
			whenTrue: Event<Ast(Block, BreakStatement, ContinueStatement, ExpressionStatement, ReturnStatement, SetStatement, ThrowStatement)>(Y)
			whenFalse: Event<Ast(Block, IfStatement)>
			{ start }: Range
			{ end }: Range
		): Ast(IfStatement) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			variable: Event<Ast(Identifier, MemberExpression)>(Y)
			interface: Event<Ast(Identifier, MemberExpression)>
			properties: Event<Ast(ClassMember)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ImplementDeclaration) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(ImportDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ImportDeclaration) { # {{{
			return {
				kind: .ImportDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func ImportDeclarator(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			source: Event<Ast(Literal)>(Y)
			arguments: Ast(NamedArgument, PositionalArgument)[]?
			type: Event<Ast(DescriptiveType, TypeList)>
			specifiers: Event<Ast(GroupSpecifier)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ImportDeclarator) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(IncludeDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(IncludeAgainDeclaration) { # {{{
			return {
				kind: .IncludeAgainDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func IncludeDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(IncludeDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(IncludeDeclaration) { # {{{
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
		): Ast(IncludeDeclarator) { # {{{
			return {
				kind: .IncludeDeclarator
				attributes: []
				file
				start
				end
			}
		} # }}}

		func IterationArray(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<Ast(Identifier, ArrayBinding, ObjectBinding)>
			type:  Event<Ast(Type)>
			index: Event<Ast(Identifier)>
			expression: Event<Ast(Expression)>(Y)
			from: Event<Ast(Expression)>
			to: Event<Ast(Expression)>
			step: Event<Ast(Expression)>
			split: Event<Ast(Expression)>
			until: Event<Ast(Expression)>
			while: Event<Ast(Expression)>
			when: Event<Ast(Expression)>
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			variable: Event<Ast(Identifier)>(Y)
			from: Event<Ast(Expression)>(Y)
			to: Event<Ast(Expression)>(Y)
			step: Event<Ast(Expression)>
			until: Event<Ast(Expression)>
			while: Event<Ast(Expression)>
			when: Event<Ast(Expression)>
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<Ast(Identifier, ArrayBinding, ObjectBinding)>
			type:  Event<Ast(Type)>
			key: Event<Ast(Identifier)>
			expression: Event<Ast(Expression)>(Y)
			until: Event<Ast(Expression)>
			while: Event<Ast(Expression)>
			when: Event<Ast(Expression)>
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			value: Event<Ast(Identifier)>
			index: Event<Ast(Identifier)>
			from: Event<Ast(Expression)>(Y)
			to: Event<Ast(Expression)>
			step: Event<Ast(Expression)>
			until: Event<Ast(Expression)>
			while: Event<Ast(Expression)>
			when: Event<Ast(Expression)>
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
			expression: Event<Ast(Expression)>(Y)
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
			operands: Ast(Expression, Type)[]
		): Ast(JunctionExpression) { # {{{
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
			parameters: Event<Event<Ast(Parameter)>[]>(Y)
			modifiers: Event<ModifierData>(Y)[]?
			type: Event<Ast(Type)>?
			throws: Event<Event<Ast(Identifier)>[]>?
			body: Event<Ast(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(LambdaExpression) { # {{{
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
		): Ast(Literal) { # {{{
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
		): Ast(Literal) { # {{{
			return {
				kind: .Literal
				modifiers: if ?modifiers set [modifier.value for var modifier in modifiers] else []
				value
				start: first.start
				end
			}
		} # }}}

		func MacroDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			parameters: Event<Event<Ast(Parameter)>(Y)[]>(Y)
			body: Event<Ast(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(MacroDeclaration) { # {{{
			return {
				kind: .MacroDeclaration
				attributes: [attribute.value for var attribute in attributes]
				modifiers: [modifier.value for var modifier in modifiers]
				name: name.value
				parameters: [parameter.value for var parameter in parameters.value]
				body: body.value
				start
				end
			}
		} # }}}

		func MatchClause(
			conditions: Event<Ast(Expression, MatchConditionArray, MatchConditionObject, MatchConditionRange, MatchConditionType)>(Y)[]
			binding: Event<Ast(VariableDeclarator, ArrayBinding, ObjectBinding)>
			filter: Event<Ast(Expression)>
			body: Event<Ast(Block, Statement)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(MatchClause) { # {{{
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
			values: Event<Ast(Expression, MatchConditionRange, OmittedExpression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(MatchConditionArray) { # {{{
			return {
				kind: .MatchConditionArray
				values: [value.value for var value in values]
				start
				end
			}
		} # }}}

		func MatchConditionObject(
			properties: Event<Ast(ObjectMember)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(MatchConditionObject) { # {{{
			return {
				kind: .MatchConditionObject
				properties: [property.value for var property in properties]
				start
				end
			}
		} # }}}

		func MatchConditionRangeFI(
			from: Event<Ast(Expression)>(Y)
			til: Event<Ast(Expression)>(Y)
		): Ast(MatchConditionRange) { # {{{
			return {
				kind: .MatchConditionRange
				from: from.value
				til: til.value
				start: from.start
				end: til.end
			}
		} # }}}

		func MatchConditionRangeFO(
			from: Event<Ast(Expression)>(Y)
			to: Event<Ast(Expression)>(Y)
		): Ast(MatchConditionRange) { # {{{
			return {
				kind: .MatchConditionRange
				from: from.value
				to: to.value
				start: from.start
				end: to.end
			}
		} # }}}

		func MatchConditionRangeTI(
			then: Event<Ast(Expression)>(Y)
			til: Event<Ast(Expression)>(Y)
		): Ast(MatchConditionRange) { # {{{
			return {
				kind: .MatchConditionRange
				then: then.value
				til: til.value
				start: then.start
				end: til.end
			}
		} # }}}

		func MatchConditionRangeTO(
			then: Event<Ast(Expression)>(Y)
			to: Event<Ast(Expression)>(Y)
		): Ast(MatchConditionRange) { # {{{
			return {
				kind: .MatchConditionRange
				then: then.value
				to: to.value
				start: then.start
				end: to.end
			}
		} # }}}

		func MatchConditionType(
			type: Event<Ast(Type)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(MatchConditionType) { # {{{
			return {
				kind: .MatchConditionType
				type: type.value
				start
				end
			}
		} # }}}

		func MatchExpression(
			expression: Event<Ast(Expression)>(Y)
			clauses: Event<Ast(MatchClause, SyntimeStatement)[]>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(MatchExpression) { # {{{
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
			expression: Event<Ast(Expression)>
			declaration: Event<Ast(VariableDeclaration)>
			clauses: Event<Ast(MatchClause, SyntimeStatement)[]>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(MatchStatement) { # {{{
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
			object: Event<Ast(Expression)>
			property: Event<Ast(Expression)>(Y)
			{ start }: Range = object ?]] property
			{ end }: Range = property
		): Ast(MemberExpression) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			typeParameters: Event<Event<Ast(TypeParameter)>[]>
			parameters: Event<Event<Ast(Parameter)>(Y)[]>(Y)
			type: Event<Ast(Type)>?
			throws: Event<Event<Ast(Identifier)>[]>?
			body: Event<Ast(Block, Expression, IfStatement, UnlessStatement)>?
			{ start }: Range
			{ end }: Range
		): Ast(MethodDeclaration) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			body: Ast(Statement)[]
			parser: Parser
		): Ast(Module) { # {{{
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
		): Ast(MutatorDeclaration) { # {{{
			return {
				kind: .MutatorDeclaration
				start
				end
			}
		} # }}}

		func MutatorDeclaration(
			body: Event<Ast(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(MutatorDeclaration) { # {{{
			return {
				kind: .MutatorDeclaration
				body: body.value
				start
				end
			}
		} # }}}

		func NamedArgument(
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			value: Event<Ast(Expression, PlaceholderArgument)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(NamedArgument) { # {{{
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
			{ value % internal, start, end }: Event<Ast(Identifier, ArrayBinding, ObjectBinding)>(Y)
		): Ast(NamedSpecifier) { # {{{
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
			internal: Event<Ast(Identifier, MemberExpression, ArrayBinding, ObjectBinding)>(Y)
			external: Event<Ast(Identifier)>
			{ start }: Range
			{ end }: Range
		): Ast(NamedSpecifier) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			statements: Event<Ast(Statement)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(NamespaceDeclaration) { # {{{
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
		): Ast(NumericExpression) { # {{{
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
			elements: Event<Ast(BindingElement)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ObjectBinding) { # {{{
			return {
				kind: .ObjectBinding
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func ObjectBindingElement(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			external: Event<Ast(Identifier)>
			internal: Event<Ast(Identifier, ArrayBinding, ObjectBinding, ThisExpression)>
			type: Event<Ast(Type)>
			operator: Event<BinaryOperatorData(Assignment)>
			defaultValue: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(BindingElement) { # {{{
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
			name: Event<Ast(ComputedPropertyName, TemplateExpression)>(Y)
			value: Event<Ast(Expression)>(Y)
			iteration: Event<IterationData>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(ObjectComprehension) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			properties: Event<Ast(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ObjectExpression) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier, ComputedPropertyName, Literal, TemplateExpression)>
			type: Event<Ast(Type)>
			value: Event<Ast(Expression, MatchConditionRange)>
			{ start }: Range
			{ end }: Range
		): Ast(ObjectMember) { # {{{
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
			properties: Event<Ast(PropertyType)>(Y)[]
			rest: Event<Ast(PropertyType)>(Y)?
			{ start }: Range
			{ end }: Range
		): Ast(ObjectType) { # {{{
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
		): Ast(OmittedExpression) { # {{{
			return {
				kind: .OmittedExpression
				modifiers
				start
				end
			}
		} # }}}

		func OmittedReference(
			{ start, end }: Range
		): Ast(TypeReference) { # {{{
			return {
				kind: .TypeReference
				modifiers: []
				start
				end
			}
		} # }}}

		func Operator(
			operator: Event<BinaryOperatorData>(Y)
		): Ast(Operator) { # {{{
			return {
				kind: .Operator
				operator: operator.value
				...operator { start, end }
			}
		} # }}}

		func PassStatement(
			{ start, end }: Range
		): Ast(PassStatement) { # {{{
			return {
				kind: .PassStatement
				attributes: []
				start
				end
			}
		} # }}}

		func Parameter(
			{ value, start, end }
		): Ast(Parameter) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: ModifierData[]
			external: Event<Ast(Identifier)>(Y)?
			internal: Event<Ast(Identifier, ArrayBinding, ObjectBinding, ThisExpression)>(Y)?
			type: Event<Ast(Type)>(Y)?
			operator: Event<BinaryOperatorData(Assignment)>(Y)?
			defaultValue: Event<Ast(Expression)>(Y)?
			{ start }: Range
			{ end }: Range
		): Ast(Parameter) { # {{{
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
			index: Event<Ast(NumericExpression)>
			{ start }: Range
			{ end }: Range
		): Ast(PlaceholderArgument) { # {{{
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
			value: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(PositionalArgument) { # {{{
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
			object: Event<Ast(Identifier, MemberExpression)>(Y)
			properties: Event<Ast(NamedSpecifier)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(PropertiesSpecifier) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			type: Event<Ast(Type)>
			defaultValue: Event<Ast(Expression)>
			accessor: Event<Ast(AccessorDeclaration)>
			mutator: Event<Ast(MutatorDeclaration)>
			{ start }: Range
			{ end }: Range
		): Ast(PropertyDeclaration) { # {{{
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
			name: Event<Ast(Identifier)>
			type: Event<Ast(Type)>
			{ start }: Range
			{ end }: Range
		): Ast(PropertyType) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			internal: Event<Ast(Identifier)>(Y)
			external: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(ProxyDeclaration) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			recipient: Event<Ast(Expression)>(Y)
			elements: Event<Ast(ProxyDeclaration)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(ProxyGroupDeclaration) { # {{{
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

		func QuoteExpression(
			elements: Event<QuoteElementData>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(QuoteExpression) { # {{{
			return {
				kind: .QuoteExpression
				attributes: []
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func QuoteElementEscape(
			value: String
			{ start }: Range
			{ end }: Range
		): QuoteElementData(Escape) { # {{{
			return {
				kind: .Escape
				value: value
				start
				end
			}
		} # }}}

		func QuoteElementExpression(
			expression: Event<Ast(Expression)>(Y)
			reifications: ReificationData[]
			{ start }: Range
			{ end }: Range
		): QuoteElementData(Expression) { # {{{
			return {
				kind: .Expression
				expression: expression.value
				reifications
				start
				end
			}
		} # }}}

		func QuoteElementLiteral(
			value: String
			{ start }: Range
			{ end }: Range
		): QuoteElementData(Literal) { # {{{
			return {
				kind: .Literal
				value: value
				start
				end
			}
		} # }}}

		func QuoteElementNewLine(
			{ start, end }: Range
		): QuoteElementData(NewLine) { # {{{
			return {
				kind: .NewLine
				start
				end
			}
		} # }}}

		func QuoteElementStatement(
			statement: Event<Ast(FlowStatement)>(Y)
			{ start }: Range
			{ end }: Range
		): QuoteElementData(Statement) { # {{{
			return {
				kind: .Statement
				statement: statement.value
				start
				end
			}
		} # }}}

		func Reference(
			name: String
			{ start, end }: Range
		): Ast(Reference) { # {{{
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
		): Ast(RegularExpression) { # {{{
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
			expression: Event<Ast(Expression)>
			body: Event<Ast(Block, ExpressionStatement)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(RepeatStatement) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(RequireDeclaration) { # {{{
			return {
				kind: .RequireDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func RequireOrExternDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(RequireOrExternDeclaration) { # {{{
			return {
				kind: .RequireOrExternDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declarator.value for var declarator in declarations]
				start
				end
			}
		} # }}}

		func RequireOrImportDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(ImportDeclarator)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(RequireOrImportDeclaration) { # {{{
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
			condition: Event<Ast(Expression)>(Y)
			expression: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(RestrictiveExpression) { # {{{
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
		): Ast(ReturnStatement) { # {{{
			return {
				kind: .ReturnStatement
				attributes: []
				start
				end
			}
		} # }}}

		func ReturnStatement(
			value: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(ReturnStatement) { # {{{
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
			object: Event<Ast(Expression)>(Y)
			expressions: Event<Ast(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(RollingExpression) { # {{{
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
			value: Event<Ast(Argument, Identifier, ObjectExpression)>(Y)
		): ScopeData { # {{{
			return {
				kind: scope
				value: value.value
			}
		} # }}}

		func SemtimeStatement(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			body: Event<Ast(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(SemtimeStatement) { # {{{
			return {
				kind: .SemtimeStatement
				attributes: [attribute.value for var attribute in attributes]
				body: body.value
				start
				end
			}
		} # }}}

		func SequenceExpression(
			expressions: Event<Ast(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(SequenceExpression) { # {{{
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
		): Ast(SetStatement) { # {{{
			return {
				kind: .SetStatement
				attributes: []
				start
				end
			}
		} # }}}

		func SetStatement(
			value: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(SetStatement) { # {{{
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
		): Ast(ShebangDeclaration) { # {{{
			return {
				kind: .ShebangDeclaration
				command
				start
				end
			}
		} # }}}

		func ShorthandProperty(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			name: Event<Ast(Identifier, ComputedPropertyName, Literal, TemplateExpression, ThisExpression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(ShorthandProperty) { # {{{
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
			operand: Event<Ast(Expression)>(Y)
			members: Event<Ast(NamedSpecifier)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(SpreadExpression) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			extends: Event<Ast(TypeReference)>
			implements: Event<Ast(Identifier, MemberExpression)>(Y)[]
			fields: Ast(FieldDeclaration)[]
			{ start }: Range
			{ end }: Range
		): Ast(StructDeclaration) { # {{{
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

		func SyntimeCallExpression(
			modifiers: ModifierData[]
			callee: Event<Ast(Expression)>(Y)
			arguments: Event<Ast(Argument, Expression, Statement)[]>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(SyntimeCallExpression) { # {{{
			return {
				kind: .SyntimeCallExpression
				modifiers
				callee: callee.value
				arguments: arguments.value
				start
				end
			}
		} # }}}

		func SyntimeDeclaration(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			declarations: Event<Ast(ImplementDeclaration, MacroDeclaration, NamespaceDeclaration)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(SyntimeDeclaration) { # {{{
			return {
				kind: .SyntimeDeclaration
				attributes: [attribute.value for var attribute in attributes]
				declarations: [declaration.value for var declaration in declarations]
				start
				end
			}
		} # }}}

		func SyntimeStatement(
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			body: Event<Ast(Block)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(SyntimeStatement) { # {{{
			return {
				kind: .SyntimeStatement
				attributes: [attribute.value for var attribute in attributes]
				body: body.value
				start
				end
			}
		} # }}}

		func TaggedTemplateExpression(
			tag: Event<Ast(Expression)>
			template: Event<Ast(TemplateExpression)>
			{ start }: Range
			{ end }: Range
		): Ast(TaggedTemplateExpression) { # {{{
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
			elements: Event<Ast(Expression)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(TemplateExpression) { # {{{
			return {
				kind: .TemplateExpression
				modifiers: [modifier.value for var modifier in modifiers]
				elements: [element.value for var element in elements]
				start
				end
			}
		} # }}}

		func ThisExpression(
			name: Event<Ast(Identifier)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(ThisExpression) { # {{{
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
		): Ast(ThrowStatement) { # {{{
			return {
				kind: .ThrowStatement
				attributes: []
				start
				end
			}
		} # }}}

		func ThrowStatement(
			value: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(ThrowStatement) { # {{{
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
		): Ast(TopicReference) { # {{{
			return {
				kind: .TopicReference
				modifiers
				start
				end
			}
		} # }}}

		func TryExpression(
			modifiers: ModifierData[]
			argument: Event<Ast(Expression)>(Y)
			defaultValue: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(TryExpression) { # {{{
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
			body: Event<Ast(Block)>(Y)
			catchClauses: Event<Ast(CatchClause)>(Y)[]
			catchClause: Event<Ast(CatchClause)>
			finalizer: Event<Ast(Block)>
			{ start }: Range
			{ end }: Range
		): Ast(TryStatement) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			extends: Event<Ast(Identifier)>
			implements: Event<Ast(Identifier, MemberExpression)>(Y)[]
			fields: Ast(TupleField)[]
			{ start }: Range
			{ end }: Range
		): Ast(TupleDeclaration) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>
			type: Event<Ast(Type)>
			defaultValue: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(TupleField) { # {{{
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
			expression: Event<Ast(Expression)>(Y)
			parameters: Event<Ast(Type)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(TypedExpression) { # {{{
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
			type: Event<Ast(DescriptiveType)>(Y)
			{ start, end }: Range
		): Ast(TypedSpecifier) { # {{{
			return {
				kind: .TypedSpecifier
				type: type.value
				start
				end
			}
		} # }}}

		func TypeAliasDeclaration(
			name: Event<Ast(Identifier)>(Y)
			parameters: Event<Event<Ast(TypeParameter)>[]>
			type: Event<Ast(Type)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(TypeAliasDeclaration) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			types: Event<Ast(DescriptiveType)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(TypeList) { # {{{
			return {
				kind: .TypeList
				attributes: [attribute.value for var attribute in attributes]
				types: [type.value for var type in types]
				start
				end
			}
		} # }}}

		func TypeParameter(
			name: Event<Ast(Identifier)>(Y)
			constraint: Event<Ast(Type)>
			{ start }: Range
			{ end }: Range
		): Ast(TypeParameter) { # {{{
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
			{ value % typeName, start, end }: Event<Ast(Identifier, MemberExpression, UnaryExpression)>(Y)
		): Ast(TypeReference) { # {{{
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
			name: Event<Ast(Identifier, MemberExpression, UnaryExpression)>(Y)
			parameters: Event<Event<Ast(Type)>(Y)[]>
			subtypes: Event<Event<Ast(Identifier)>(Y)[] | Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(TypeReference) { # {{{
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
			argument: Event<Ast(Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(UnaryExpression) { # {{{
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
			argument: Event<Ast(Type, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(UnaryTypeExpression) { # {{{
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
			types: Event<Ast(Type)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(UnionType) { # {{{
			return {
				kind: .UnionType
				types: [type.value for var type in types]
				start
				end
			}
		} # }}}

		func UnlessStatement(
			condition: Event<Ast(Expression)>(Y)
			whenFalse: Event<Ast(Block, BreakStatement, ContinueStatement, ExpressionStatement, ReturnStatement, SetStatement, ThrowStatement)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(UnlessStatement) { # {{{
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
			condition: Event<Ast(Expression)>(Y)
			body: Event<Ast(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(UntilStatement) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			variables: Event<Ast(VariableDeclarator)>(Y)[]
			operator: Event<BinaryOperatorData(Assignment)>
			value: Event<Ast(Expression)>
			{ start }: Range
			{ end }: Range
		): Ast(VariableDeclaration) { # {{{
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
			name: Event<Ast(Identifier, ArrayBinding, ObjectBinding)>(Y)
			type: Event<Ast(Type)>
			{ start }: Range
			{ end }: Range
		): Ast(VariableDeclarator) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			declarations: Event<Ast(VariableDeclaration)>(Y)[]
			{ start }: Range
			{ end }: Range
		): Ast(VariableStatement) { # {{{
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
			attributes: Event<Ast(AttributeDeclaration)>(Y)[]
			modifiers: Event<ModifierData>(Y)[]
			name: Event<Ast(Identifier)>(Y)
			fields: Ast(VariantField)[]
			{ start }: Range
			{ end }: Range
		): Ast(VariantDeclaration) { # {{{
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
			names: Event<Ast(Identifier)>(Y)[]
			type: Event<Ast(Type)>
			{ start }: Range
			{ end }: Range
		): Ast(VariantField) { # {{{
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
			master: Event<Ast(TypeReference)>(Y)
			properties: Ast(VariantField)[]
			{ start }: Range
			{ end }: Range
		): Ast(VariantType) { # {{{
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
			condition: Event<Ast(Expression, VariableDeclaration)>(Y)
			body: Event<Ast(Block, Expression)>(Y)
			{ start }: Range
			{ end }: Range
		): Ast(WhileStatement) { # {{{
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
			variables: Event<Ast(BinaryExpression, VariableDeclaration)>(Y)[]
			body: Event<Ast(Block)>(Y)
			finalizer: Event<Ast(Block)>
			{ start }: Range
			{ end }: Range
		): Ast(WithStatement) { # {{{
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
