type Position = {
	line: Number
	column: Number
}

type Range = {
	start: Position
	end: Position
}

type Event<T> = {
	variant ok: Boolean {
		false, N {
			expecteds: String[]?
			start: Position?
			end: Position?
		}
		true, Y {
			value: T
			start: Position
			end: Position
		}
	}
}

type Marker = {
	eof: Boolean
	index: Number
	line: Number
	column: Number
}

type NodeData = Range & {
	variant kind: NodeKind {
		AccessorDeclaration {
			body: NodeData(Block, Expression)?
		}
		Argument {
			modifiers: ModifierData[]
			name: NodeData(Identifier)?
			value: NodeData(Expression)
		}
		ArrayBinding {
			elements: NodeData(BindingElement)[]
		}
		ArrayExpression {
			values: NodeData(Expression)[]
		}
		ConditionalExpression {
			modifiers: ModifierData[]
			condition: NodeData(Expression)
			whenTrue: NodeData(Expression)
			whenFalse: NodeData(Expression)
		}
		DeclarationSpecifier {
			declaration: NodeData(ClassDeclaration, FunctionDeclaration, BitmaskDeclaration)
		}
		Identifier {
			modifiers: ModifierData[]
			name: String
		}
		NumericExpression {
			modifiers: ModifierData[]
			value: Number
			radix: Number
		}
		RestrictiveExpression {
			operator: RestrictiveOperatorData
			condition: NodeData(Expression)
			expression: NodeData(Expression)
		}
		StatementList {
			attributes: NodeData(AttributeDeclaration)[]
			body: NodeData(Statement)[]
		}
		ThisExpression {
			modifiers: ModifierData[]
			name: NodeData(Identifier)
		}
		VariableDeclarator {
			attributes: NodeData(AttributeDeclaration)[]
			modifiers: ModifierData[]
			name: NodeData(Identifier, ArrayBinding, ObjectBinding)
			type: NodeData(Type)?
		}
	}
}

type ModifierData = Range & {
	variant kind: ModifierKind {
	}
}

type BinaryOperatorData = Range & {
	variant kind: BinaryOperatorKind {
		Assignment {
			assignment: AssignmentOperatorKind
		}
	}
	modifiers: ModifierData[]?
}

type IterationData = Range & {
	variant kind: IterationKind {
	}
}

type MacroElementData = Range & {
	variant kind: MacroElementKind {
		Expression {
			expression: NodeData(Expression)
			reification: ReificationData?
			separator: NodeData(Expression)?
		}
	}
}

type ReificationData = Range & {
	variant kind: ReificationKind {
	}
}

type RestrictiveOperatorData = Range & {
	variant kind: RestrictiveOperatorKind {
	}
}

type ScopeData = {
	kind: ScopeKind
}

type UnaryOperatorData = Range & {
	variant kind: UnaryOperatorKind {
	}
}

type UnaryTypeOperatorData = Range & {
	variant kind: UnaryTypeOperatorKind {
	}
}
