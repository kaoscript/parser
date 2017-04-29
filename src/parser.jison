/**
 * parser.jison
 * Version 0.5.0
 * September 14th, 2016
 *
 * Copyright (c) 2016 Baptiste Augrain
 * Licensed under the MIT license.
 * http://www.opensource.org/licenses/mit-license.php
 **/
%lex

RegularExpressionNonTerminator		[^\n\r]
RegularExpressionBackslashSequence	\\{RegularExpressionNonTerminator}
RegularExpressionClassChar			[^\n\r\]\\]|{RegularExpressionBackslashSequence}
RegularExpressionClass				\[{RegularExpressionClassChar}*\]
RegularExpressionFlags				[gmi]*
RegularExpressionFirstChar			([^\n\r\*\\\/\[])|{RegularExpressionBackslashSequence}|{RegularExpressionClass}
RegularExpressionChar				([^\n\r\\\/\[])|{RegularExpressionBackslashSequence}|{RegularExpressionClass}
RegularExpressionBody				{RegularExpressionFirstChar}{RegularExpressionChar}*
RegularExpressionLiteral			{RegularExpressionBody}\/{RegularExpressionFlags}

%x class_version hcomment import mlcomment regexp resource inline_comment template
%%

<regexp>{RegularExpressionLiteral}				this.popState();return 'REGEXP_LITERAL'
<import>[\@\.\/A-Za-z0-9_\-]+					this.popState();return 'IMPORT_LITERAL'

\s+\?\s+										return 'SPACED_?'
\s+\:\s+										return 'SPACED_:'

<class_version>\d+(\.\d+(\.\d+)?)?				this.popState();yytext = yytext.split('.');return 'CLASS_VERSION'

[^\r\n\S]+										/* skip whitespace */
\s*\/\/[^\r\n]*									/* skip comment */
\s*'/*'											this.begin('mlcomment')
<mlcomment>'/*'									this.begin('mlcomment')
<mlcomment>'*/'									this.popState()
<mlcomment>[^\*\/\\]+							/* skip comment */
<mlcomment>(.|\n)								/* skip comment */
'---'\r?\n										this.begin('hcomment')
<hcomment>'---'\r?\n							this.popState()
<hcomment>(.|\r?\n)								/* skip comment */

<inline_comment>\s*'/*'							this.begin('inline_comment')
<inline_comment>'*/'\s*							this.popState()
<inline_comment>(.|\n)							/* skip comment */

<resource>\s*\r?\n\s*							return 'NEWLINE'
<resource>'}'									this.popState()
<resource>\s*\/\/[^\r\n]*\r?\n\s*				/* skip comment */
<resource>\s*'/*'								this.begin('inline_comment')
<resource>\S+									return 'RESOURCE_NAME'

<template>'`'									this.popState();return 'TEMPLATE_END'
<template>'\('									this.begin('');return '\('
<template>([^`\\]|\\(?!\())+					return 'TEMPLATE_VALUE'

'`'												this.begin('template');return 'TEMPLATE_BEGIN'
'abstract'										return 'ABSTRACT'
'async'											return 'ASYNC'
'as'											return 'AS'
'await'											return 'AWAIT'
'break'											return 'BREAK'
'by'											return 'BY'
'catch'											return 'CATCH'
'class'											return 'CLASS'
'const'											return 'CONST'
'continue'										return 'CONTINUE'
'delete'										return 'DELETE'
'desc'											return 'DESC'
'do'											return 'DO'
'else'											return 'ELSE'
'enum'											return 'ENUM'
'export'										return 'EXPORT'
'extends'										return 'EXTENDS'
'extern|require'								return 'EXTERN|REQUIRE'
'extern'										return 'EXTERN'
'finally'										return 'FINALLY'
'for'											return 'FOR'
'from'											return 'FROM'
'func'											return 'FUNC'
'get'											return 'GET'
'if'											return 'IF'
'impl'											return 'IMPL'
'import'										return 'IMPORT'
'include once'									return 'INCLUDE_ONCE'
'include'										return 'INCLUDE'
'in'											return 'IN'
'is not'										return 'IS_NOT'
'is'											return 'IS'
'let'											return 'LET'
'namespace'										return 'NAMESPACE'
'new'											return 'NEW'
'of'											return 'OF'
'on'											return 'ON'
'private'										return 'PRIVATE'
'protected'										return 'PROTECTED'
'public'										return 'PUBLIC'
'require|extern'								return 'REQUIRE|EXTERN'
'require|import'								return 'REQUIRE|IMPORT'
'require'										return 'REQUIRE'
'return'										return 'RETURN'
'set'											return 'SET'
'sealed'										return 'SEALED'
'static'										return 'STATIC'
'switch'										return 'SWITCH'
'til'											return 'TIL'
'to'											return 'TO'
'throw'											return 'THROW'
'try'											return 'TRY'
'type'											return 'TYPE'
'unless'										return 'UNLESS'
'until'											return 'UNTIL'
'where'											return 'WHERE'
\s*'when'										return 'WHEN'
'while'											return 'WHILE'
'with'											return 'WITH'
'#!['											return '#!['
'#['											return '#['
'?.'											return '?.'
'?['											return '?['
'^^('											this.begin('');return '^^('
'^$('											this.begin('');return '^$('
'^@('											this.begin('');return '^@('
'**('											this.begin('');return '**('
'*$('											this.begin('');return '*$('
'->'											return '->'
'=>'											return '=>'
'>='											return '>='
'<='											return '<='
'!='											return '!='
'??='											return '??='
'!?='											return '!?='
'?='											return '?='
'=='											return '=='
'+='											return '+='
'&='											return '&='
'<<='											return '<<='
'|='											return '|='
'>>='											return '>>='
'^='											return '^='
'/='											return '/='
'%='											return '%='
'*='											return '*='
'-='											return '-='
':='											return ':='
'='												return '='
'('												this.begin('');return '('
')'												this.popState();return ')'
'['												return '['
']'												return ']'
'{'												return '{'
'}'												return '}'
'<<'											return '<<'
'<'												return '<'
'>>'											return '>>'
'>'												return '>'
'::'											return '::'
':'												return ':'
','												return ','
'??'											return '??'
'?'												return '?'
'...'											return '...'
'..'											return '..'
\s*'.'\s*										return '.'
'@'												return '@'
'++'											return '++'
'+'												return '+'
'--'											return '--'
'-'												return '-'
'/'												return '/'
'%'												return '%'
'*'												return '*'
\s*'&&'\s*										return '&&'
'&'												return '&'
\s*'||'\s*										return '||'
'|'												return '|'
'^'												return '^'
'!'												return '!'
'_'												return '_'
'~'												return '~'
\r?\n											return 'NEWLINE'
[_$A-Za-z]\w*									return 'IDENTIFIER'
0b[_0-1]+[a-zA-Z]*								return 'BINARY_NUMBER'
0o[_0-8]+[a-zA-Z]*								return 'OCTAL_NUMBER'
0x[_0-9a-fA-F]+[a-zA-Z]*						return 'HEX_NUMBER'
(?:[0-9]|[1-2][0-9]|3[0-6])r[_0-9a-zA-Z]+		return 'RADIX_NUMBER'
[0-9][_0-9]*(?:\.[_0-9]+)?[a-zA-Z]*				return 'DECIMAL_NUMBER'
\'([^\\']|\\.)*\'								yytext = yytext.slice(1, -1).replace(/(^|[^\\])\\('|")/g, '$1$2');return 'STRING'
\"([^\\"]|\\.)*\"								yytext = yytext.slice(1, -1).replace(/(^|[^\\])\\('|")/g, '$1$2');return 'STRING'
\`((.|\n)*?[^\\]|)\`							yytext = yytext.slice(1, -1);return 'TEMPLATE'
\S+												return 'MODULE_NAME'
<<EOF>> 										return 'EOF'
. 												return 'INVALID'

/lex

%start Module

%%

AbstractMethod // {{{
	: MethodHeader FunctionModifiers FunctionReturns FunctionThrows
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$1.type = $3;
			$1.throws = $4;
			$$ = location($1, @4);
		}
	| MethodHeader FunctionModifiers FunctionReturns
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$1.type = $3;
			$$ = location($1, @3);
		}
	| MethodHeader FunctionModifiers FunctionThrows
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$1.throws = $3;
			$$ = location($1, @3);
		}
	| MethodHeader FunctionModifiers
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$$ = location($1, @2);
		}
	;
// }}}

AbstractMethodList // {{{
	: AbstractMethodList AbstractMethod NL_EOF_1
		{
			$1.push($2);
			$$ = $1;
		}
	| AbstractMethodList NL_EOF_1
	|
		{
			$$ = [];
		}
	;
// }}}

Array // {{{
	: '[' NL_0M ArrayRange NL_0M ']'
		{
			$$ = location($3, @1, @5);
		}
	| '[' NL_0M Expression ForExpression NL_0M ']'
		{
			$$ = location({
				kind: NodeKind.ArrayComprehension,
				body: $3,
				loop: $4
			}, @1, @6);
		}
	| '[' NL_0M Expression NL_1M ForExpression NL_0M ']'
		{
			$$ = location({
				kind: NodeKind.ArrayComprehension,
				body: $3,
				loop: $5
			}, @1, @7);
		}
	| '[' NL_0M ArrayListPN Expression NL_0M ']'
		{
			$3.push($4);
			
			$$ = location({
				kind: NodeKind.ArrayExpression,
				values: $3
			}, @1, @6);
		}
	| '[' NL_0M ArrayListPN NL_0M ']'
		{
			$$ = location({
				kind: NodeKind.ArrayExpression,
				values: $3
			}, @1, @5);
		}
	| '[' NL_0M Expression NL_0M ']'
		{
			$$ = location({
				kind: NodeKind.ArrayExpression,
				values: [$3]
			}, @1, @5);
		}
	| '[' NL_0M ']'
		{
			$$ = location({
				kind: NodeKind.ArrayExpression,
				values: []
			}, @1, @3);
		}
	;
// }}}

ArrayRange // {{{
	: Operand '<' '..' '<' Operand '..' Operand
		{
			$$ = location({
				kind: NodeKind.ArrayRange,
				then: $1,
				til: $5,
				by: $7
			}, @1, @7);
		}
	| Operand '<' '..' Operand '..' Operand
		{
			$$ = location({
				kind: NodeKind.ArrayRange,
				then: $1,
				to: $4,
				by: $6
			}, @1, @6);
		}
	| Operand '..' '<' Operand '..' Operand
		{
			$$ = location({
				kind: NodeKind.ArrayRange,
				from: $1,
				til: $4,
				by: $6
			}, @1, @6);
		}
	| Operand '..' Operand '..' Operand
		{
			$$ = location({
				kind: NodeKind.ArrayRange,
				from: $1,
				to: $3,
				by: $5
			}, @1, @5);
		}
	| Operand '<' '..' '<' Operand
		{
			$$ = location({
				kind: NodeKind.ArrayRange,
				then: $1,
				til: $5
			}, @1, @5);
		}
	| Operand '<' '..' Operand
		{
			$$ = location({
				kind: NodeKind.ArrayRange,
				then: $1,
				to: $4
			}, @1, @4);
		}
	| Operand '..' '<' Operand
		{
			$$ = location({
				kind: NodeKind.ArrayRange,
				from: $1,
				til: $4
			}, @1, @4);
		}
	| Operand '..' Operand
		{
			$$ = location({
				kind: NodeKind.ArrayRange,
				from: $1,
				to: $3
			}, @1, @3);
		}
	;
// }}}

ArrayListPN // {{{
	: ArrayListPN ArrayListPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| ArrayListPNI
		{
			$$ = [$1]
		}
	;
// }}}

ArrayListPNI // {{{
	: Expression ',' NL_0M
	| Expression NL_1M
	;
// }}}

AssignmentDeclaration // {{{
	: AssignmentDeclarator 'IF' Expression 'ELSE' Expression
		{
			$1.right = location({
				kind: NodeKind.IfExpression,
				condition: $3,
				whenTrue: $1.right,
				whenFalse: $5
			}, @2, @5);
			
			$$ = location($1, @1, @5)
		}
	| AssignmentDeclarator 'IF' Expression
		{
			$$ = location({
				kind: NodeKind.IfExpression,
				condition: $3,
				whenTrue: $1
			}, @1, @3);
		}
	| AssignmentDeclarator 'UNLESS' Expression
		{
			$$ = location({
				kind: NodeKind.UnlessExpression,
				condition: $3,
				whenFalse: $1
			}, @1, @3);
		}
	| AssignmentDeclarator
	;
// }}}

AssignmentDeclarator // {{{
	: VariableIdentifierList ':=' 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.AwaitExpression,
				variables: $1,
				operation: $4,
				autotype: true
			}, @1, @4);
		}
	| VariableIdentifier ':=' Expression
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality,
					autotype: true
				}, @1),
				left: $1,
				right: $3
			}, @1, @3);
		}
	| VariableIdentifierList '=' 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.AwaitExpression,
				variables: $1,
				operation: $4
			}, @1, @4);
		}
	| VariableIdentifier '=' Expression
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality
				}, @1),
				left: $1,
				right: $3
			}, @1, @3);
		}
	| Operand AssignmentOperatorKind Expression
		{
			if($1.kind === NodeKind.BinaryExpression && $1.operator.kind !== BinaryOperatorKind.Equality) {
				throw new Error('Unexpected character at line ' + $1.operator.start.line + ' and column ' + $1.operator.start.column)
			}
			
			$2.left = $1;
			$2.right = $3;
			
			$$ = location($2, @1, @3);
		}
	;
// }}}

AssignmentOperatorKind // {{{
	: '+='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Addition
				}, @1)
			}, @1);
		}
	| '&='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.BitwiseAnd
				}, @1)
			}, @1);
		}
	| '<<='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.BitwiseLeftShift
				}, @1)
			}, @1);
		}
	| '|='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.BitwiseOr
				}, @1)
			}, @1);
		}
	| '>>='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.BitwiseRightShift
				}, @1)
			}, @1);
		}
	| '^='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.BitwiseXor
				}, @1)
			}, @1);
		}
	| '/='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Division
				}, @1)
			}, @1);
		}
	| '='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality
				}, @1)
			}, @1);
		}
	| '!?='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.NonExistential
				}, @1)
			}, @1);
		}
	| '?='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Existential
				}, @1)
			}, @1);
		}
	| '%='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Modulo
				}, @1)
			}, @1);
		}
	| '*='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Multiplication
				}, @1)
			}, @1);
		}
	| '-='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Subtraction
				}, @1)
			}, @1);
		}
	| '??='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.NullCoalescing
				}, @1)
			}, @1);
		}
	;
// }}}

Attribute // {{{
	: '#[' AttributeMember ']'
		{
			$$ = location({
				kind: NodeKind.AttributeDeclaration,
				declaration: $2
			}, @2);
		}
	;
// }}}

AttributeBlock // {{{
	: '#![' AttributeMember ']'
		{
			$$ = location({
				kind: NodeKind.AttributeDeclaration,
				declaration: $2
			}, @1, @3)
		}
	;
// }}}

AttributeIdentifier // {{{
	: AttributeIdentifier '-' 'IDENTIFIER'
		{
			$1.name += $2 + $3;
			
			$$ = location($1, @1, @3);
		}
	| AttributeIdentifier '-' Keyword
		{
			$1.name += $2 + $3;
			
			$$ = location($1, @1, @3);
		}
	| Identifier
	;
// }}}

AttributeList // {{{
	: AttributeList Attribute NL_EOF_1
		{
			$1.push($2);
			$$ = $1;
		}
	| Attribute NL_EOF_1
		{
			$$ = [$1];
		}
	;
// }}}

AttributeMember // {{{
	: Identifier '(' AttributeMemberList ')'
		{
			$$ = location({
				kind: NodeKind.AttributeExpression,
				name: $1,
				arguments: $3
			}, @1, @4);
		}
	| Identifier '=' String
		{
			$$ = location({
				kind: NodeKind.AttributeOperation,
				name: $1,
				value: $3
			}, @1, @3);
		}
	| AttributeIdentifier
	;
// }}}

AttributeMemberList // {{{
	: AttributeMemberList ',' AttributeMember
		{
			$$ = $1;
			$$.push($3);
		}
	| AttributeMember
		{
			$$ = [$1];
		}
	;
// }}}

BinaryOperatorKind // {{{
	: '+'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Addition
				}, @1)
			}, @1);
		}
	| '-'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Subtraction
				}, @1)
			}, @1);
		}
	| '/'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Division
				}, @1)
			}, @1);
		}
	| '%'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Modulo
				}, @1)
			}, @1);
		}
	| '*'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Multiplication
				}, @1)
			}, @1);
		}
	| '>='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.GreaterThanOrEqual
				}, @1)
			}, @1);
		}
	| '>>'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.BitwiseRightShift
				}, @1)
			}, @1);
		}
	| '>'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.GreaterThan
				}, @1)
			}, @1);
		}
	| '<='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.LessThanOrEqual
				}, @1)
			}, @1);
		}
	| '<<'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.BitwiseLeftShift
				}, @1)
			}, @1);
		}
	| '<'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.LessThan
				}, @1)
			}, @1);
		}
	| '=='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Equality
				}, @1)
			}, @1);
		}
	| '!='
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Inequality
				}, @1)
			}, @1);
		}
	| '??'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.NullCoalescing
				}, @1)
			}, @1);
		}
	| '&&'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.And
				}, @1)
			}, @1);
		}
	| '||'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Or
				}, @1)
			}, @1);
		}
	| '&'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.BitwiseAnd
				}, @1)
			}, @1);
		}
	| '|'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.BitwiseOr
				}, @1)
			}, @1);
		}
	| '^'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.BitwiseXor
				}, @1)
			}, @1);
		}
	;
// }}}

Block // {{{
	: '{' BlockSX '}'
		{
			$$ = location($2, @1, @3);
		}
	;
// }}}

BlockSX // {{{
	: BlockSX BlockStatement
		{
			$$ = location($1, @2);
			$$.statements.push($2);
		}
	| BlockSX BlockAttribute
		{
			$$ = location($1, @2);
			$$.attributes.push($2);
		}
	| BlockSX NL_EOF_1
	|
		{
			$$ = {
				kind: NodeKind.Block,
				attributes: [],
				statements: []
			};
		}
	;
// }}}

BlockAttribute // {{{
	: AttributeBlock NL_EOF_1
		{
			$$ = $1;
		}
	;
// }}}

BlockStatement // {{{
	: AttributeList Statement
		{
			$$ = location($2, @1, @2);
			$$.attributes = $1;
		}
	| Statement
		{
			$$ = $1;
			$$.attributes = [];
		}
	;
// }}}

CatchClause // {{{
	: 'CATCH' Identifier NL_0M Block
		{
			$$ = location({
				kind: NodeKind.CatchClause,
				binding: $2,
				body: $4
			}, @1, @4);
		}
	| 'CATCH' NL_0M Block
		{
			$$ = location({
				kind: NodeKind.CatchClause,
				body: $3
			}, @1, @3);
		}
	;
// }}}

CatchOnClauseList // {{{
	: CatchOnClauseList NL_EOF_1M CatchOnClause
		{
			$1.push($2);
			$$ = $1;
		}
	| CatchOnClause
		{
			$$ = [$1];
		}
	;
// }}}

CatchOnClause // {{{
	: 'ON' Identifier 'CATCH' Identifier NL_0M Block
		{
			$$ = location({
				kind: NodeKind.CatchClause,
				type: $2,
				binding: $4,
				body: $6
			}, @1, @6);
		}
	| 'ON' Identifier NL_0M Block
		{
			$$ = location({
				kind: NodeKind.CatchClause,
				type: $2,
				body: $4
			}, @1, @4);
		}
	;
// }}}

ClassDeclaration // {{{
	: ClassModifier 'CLASS' ClassIndentifier 'EXTENDS' Identifier '{' ClassMember '}'
		{
			$3.modifiers = $1;
			$3.extends = $5;
			$3.members = $7;
			
			$$ = location($3, @1, @8);
		}
	| ClassModifier 'CLASS' ClassIndentifier '{' ClassMember '}'
		{
			$3.modifiers = $1;
			$3.members = $5;
			
			$$ = location($3, @1, @6);
		}
	| 'CLASS' ClassIndentifier 'EXTENDS' Identifier '{' ClassMember '}'
		{
			$2.modifiers = [];
			$2.extends = $4;
			$2.members = $6;
			
			$$ = location($2, @1, @7);
		}
	| 'CLASS' ClassIndentifier '{' ClassMember '}'
		{
			$2.modifiers = [];
			$2.members = $4;
			
			$$ = location($2, @1, @5);
		}
	;
// }}}

ClassField // {{{
	: NameIST ColonSeparator TypeVar '=' Expression
		{
			$$ = location({
				kind: NodeKind.FieldDeclaration,
				modifiers: [],
				name: $1,
				type: $3,
				defaultValue: $5
			}, @1, @5);
		}
	| NameIST ColonSeparator TypeVar
		{
			$$ = location({
				kind: NodeKind.FieldDeclaration,
				modifiers: [],
				name: $1,
				type: $3
			}, @1, @3);
		}
	| NameIST '=' Expression
		{
			$$ = location({
				kind: NodeKind.FieldDeclaration,
				modifiers: [],
				name: $1,
				defaultValue: $3
			}, @1, @3);
		}
	| NameIST
		{
			$$ = location({
				kind: NodeKind.FieldDeclaration,
				modifiers: [],
				name: $1
			}, @1);
		}
	;
// }}}

ClassIndentifier // {{{
	: Identifier TypeGeneric ClassVersionAt 'CLASS_VERSION'
		{
			$$ = {
				kind: NodeKind.ClassDeclaration,
				name: $1,
				version: location({
					major: $4[0],
					minor: $4.length > 1 ? $4[1] : 0,
					patch: $4.length > 2 ? $4[2] : 0
				}, @4)
			};
		}
	| Identifier ClassVersionAt 'CLASS_VERSION'
		{
			$$ = {
				kind: NodeKind.ClassDeclaration,
				name: $1,
				version: location({
					major: $3[0],
					minor: $3.length > 1 ? $3[1] : 0,
					patch: $3.length > 2 ? $3[2] : 0
				}, @3)
			};
		}
	| Identifier TypeGeneric
		{
			$$ = {
				kind: NodeKind.ClassDeclaration,
				name: $1
			};
		}
	| Identifier
		{
			$$ = {
				kind: NodeKind.ClassDeclaration,
				name: $1
			};
		}
	;
// }}}

ClassMember // {{{
	: ClassMember ClassMemberModifiers '{' ClassMemberList '}' NL_1M
		{
			for(var i = 0; i < $4.length; i++) {
				$4[i].modifiers = $2;
				
				$1.push($4[i]);
			}
		}
	| ClassMember ClassMemberModifiers ClassMemberSX NL_1M
		{
			$3.modifiers = $2;
			
			$1.push(location($3, @2, @3));
		}
	| ClassMember ClassMemberSX NL_1M
		{
			$1.push($2);
			$$ = $1;
		}
	| ClassMember ClassMemberAbstractModifiers AbstractMethod NL_1M
		{
			$3.modifiers = $2;
			
			$1.push(location($3, @2, @3));
		}
	| ClassMember ClassMemberAbstractModifiers '{' AbstractMethodList '}' NL_1M
		{
			for(var i = 0; i < $4.length; i++) {
				$4[i].modifiers = $2;
				
				$1.push($4[i]);
			}
		}
	| ClassMember NL_1M
	|
		{
			$$ = []
		}
	;
// }}}

ClassMemberAbstractModifiers // {{{
	: VisibilityModifier 'ABSTRACT'
		{
			$$ = [$1, location({
				kind: ModifierKind.Abstract
			}, @2)];
		}
	| 'ABSTRACT'
		{
			$$ = [location({
				kind: ModifierKind.Abstract
			}, @1)];
		}
	;
// }}}

ClassMemberList // {{{
	: ClassMemberList ClassMemberSX NL_1M
		{
			$1.push($2);
			$$ = $1;
		}
	| ClassMemberList NL_1M
	|
		{
			$$ = [];
		}
	;
// }}}

ClassMemberModifiers // {{{
	: VisibilityModifier 'STATIC'
		{
			$$ = [$1, location({
				kind: ModifierKind.Static
			}, @2)]
		}
	| VisibilityModifier
		{
			$$ = [$1]
		}
	| 'STATIC'
		{
			$$ = [location({
				kind: ModifierKind.Static
			}, @1)];
		}
	;
// }}}

ClassMemberSX // {{{
	: AttributeList ClassField
		{
			$$ = location($2, @1, @2);
			$$.attributes = $1;
		}
	| AttributeList Method
		{
			$$ = location($2, @1, @2);
			$$.attributes = $1;
		}
	| ClassField
	| Property
	| Method
	;
// }}}

ClassModifier // {{{
	: 'ABSTRACT'
		{
			$$ = [location({
				kind: ModifierKind.Abstract
			}, @1)];
		}
	| 'SEALED' 'ABSTRACT'
		{
			$$ = [
				location({
					kind: ModifierKind.Sealed
				}, @1),
				location({
					kind: ModifierKind.Abstract
				}, @2)
			];
		}
	| 'SEALED'
		{
			$$ = [location({
				kind: ModifierKind.Sealed
			}, @1)];
		}
	;
// }}}

ClassVersionAt // {{{
	: '@'
		{
			yy.lexer.begin('class_version');
		}
	;
// }}}

ColonSeparator // {{{
	: ':'
	| 'SPACED_:'
	;
// }}}

CommaOrNewLine // {{{
	: ','
	| 'NEWLINE'
	;
// }}}

ConstDeclaration // {{{
	: 'CONST' TypedVariableList VariableEquals 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: false,
				variables: $2,
				autotype: $3,
				init: location({
					kind: NodeKind.AwaitExpression,
					operation: $5
				}, @4, @5)
			}, @1, @5);
		}
	| 'CONST' TypedVariable VariableEquals 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: false,
				variables: [$2],
				autotype: $3,
				init: location({
					kind: NodeKind.AwaitExpression,
					operation: $5
				}, @4, @5)
			}, @1, @5);
		}
	| 'CONST' TypedVariable VariableEquals Expression
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: false,
				variables: [$2],
				autotype: $3,
				init: $4
			}, @1, @4);
		}
	;
// }}}

CreateClassName // {{{
	: TypeEntity
	| VariableName
	| '(' Expression ')'
		{
			$$ = $2
		}
	;
// }}}

CreateExpression // {{{
	: 'NEW' CreateClassName '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CreateExpression,
				class: $2,
				arguments: $4
			}, @1, @5);
		}
	| 'NEW' CreateClassName
		{
			$$ = location({
				kind: NodeKind.CreateExpression,
				class: $2,
				arguments: []
			}, @1, @2);
		}
	;
// }}}

DestroyStatement // {{{
	: 'DELETE' VariableName
		{
			$$ = location({
				kind: NodeKind.DestroyStatement,
				variable: $2
			}, @1, @2);
		}
	;
// }}}

DestructuringArray // {{{
	: '[' NL_0M DestructuringArrayPN DestructuringArrayItem ']'
		{
			$3.push($4);
			$$ = $3;
		}
	| '[' NL_0M DestructuringArrayPN ']'
		{
			$$ = $3;
		}
	| '[' NL_0M DestructuringArrayItem ']'
		{
			$$ = [$3];
		}
	| '[' NL_0M ']'
		{
			$$ = [];
		}
	;
// }}}

DestructuringArrayPN // {{{
	: DestructuringArrayPN DestructuringArrayPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| DestructuringArrayPNI
		{
			$$ = [$1];
		}
	;
// }}}

DestructuringArrayPNI // {{{
	: DestructuringArrayItem ',' NL_0M
	| DestructuringArrayItem NL_1M
	;
// }}}

DestructuringArrayItem // {{{
	: '...' Identifier '=' Expression
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				name: $2,
				spread: true,
				defaultValue: $4
			}, @1, @4);
		}
	| VariableIdentifier '=' Expression
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				name: $1,
				defaultValue: $3
			}, @1, @3);
		}
	| '...' Identifier
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				name: $2,
				spread: true
			}, @1);
		}
	| VariableIdentifier
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				name: $1
			}, @1);
		}
	| '...'
		{
			$$ = {
				kind: NodeKind.OmittedExpression,
				spread: true
			};
		}
	|
		{
			$$ = {
				kind: NodeKind.OmittedExpression
			};
		}
	;
// }}}

DestructuringObject // {{{
	: '{' NL_0M DestructuringObjectPN DestructuringObjectItem '}'
		{
			$3.push($4);
			$$ = $3;
		}
	| '{' NL_0M DestructuringObjectPN '}'
		{
			$$ = $3;
		}
	| '{' NL_0M DestructuringObjectItem '}'
		{
			$$ = [$3];
		}
	| '{' NL_0M '}'
		{
			$$ = [];
		}
	;
// }}}

DestructuringObjectPN // {{{
	: DestructuringObjectPN DestructuringObjectPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| DestructuringObjectPNI
		{
			$$ = [$1];
		}
	;
// }}}

DestructuringObjectPNI // {{{
	: DestructuringObjectItem ',' NL_0M
	| DestructuringObjectItem NL_1M
	;
// }}}

DestructuringObjectItem // {{{
	: DestructuringObjectItemAlias ColonSeparator VariableIdentifier '=' Expression
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				alias: $1,
				name: $3,
				defaultValue: $5
			}, @1, @5);
		}
	| DestructuringObjectItemAlias ColonSeparator VariableIdentifier
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				alias: $1,
				name: $3
			}, @1, @3);
		}
	| DestructuringObjectItemAlias '=' Expression
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				name: $1,
				defaultValue: $3
			}, @1, @3);
		}
	| DestructuringObjectItemAlias
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				name: $1
			}, @1);
		}
	| VariableIdentifier
		{
			$$ = location({
				kind: NodeKind.BindingElement,
				name: $1
			}, @1);
		}
	;
// }}}

DestructuringObjectItemAlias // {{{
	: '[' Identifier ']'
		{
			$2.computed = true;
			$$ = location($2, @1, @3);
		}
	| Identifier
	;
// }}}

EnumDeclaration // {{{
	: 'ENUM' Identifier '<' TypeEntity '>' EnumMemberList
		{
			$$ = location({
				kind: NodeKind.EnumDeclaration,
				name: $2,
				type: $4,
				members: $6
			}, @1, @6);
		}
	| 'ENUM' Identifier EnumMemberList
	{
			$$ = location({
				kind: NodeKind.EnumDeclaration,
				name: $2,
				members: $3
			}, @1, @3);
		}
	;
// }}}

EnumMember // {{{
	: Identifier '=' Expression
		{
			$$ = location({
				kind: NodeKind.EnumMember,
				name: $1,
				value: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: NodeKind.EnumMember,
				name: $1
			}, @1);
		}
	;
// }}}

EnumMemberList // {{{
	: '{' NL_0M EnumMemberListPN EnumMember '}'
		{
			$3.push($4);
			$$ = $3;
		}
	| '{' NL_0M EnumMemberListPN '}'
		{
			$$ = $3;
		}
	| '{' NL_0M EnumMember '}'
		{
			$$ = [$3];
		}
	| '{' NL_0M '}'
		{
			$$ = [];
		}
	;
// }}}

EnumMemberListPN // {{{
	: EnumMemberListPN EnumMemberListPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| EnumMemberListPNI
		{
			$$ = [$1];
		}
	;
// }}}
	
EnumMemberListPNI // {{{
	: EnumMember ',' NL_0M
	| EnumMember NL_1M
	;
// }}}

ExportDeclaration // {{{
	: 'EXPORT' ExportDeclaratorLL
		{
			$$ = location({
				kind: NodeKind.ExportDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'EXPORT' ExportDeclaratorLB
		{
			$$ = location({
				kind: NodeKind.ExportDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

ExportDeclaratorLL // {{{
	: ExportDeclaratorLL ',' ExportDeclarator
		{
			$1.push($3);
			$$ = $1;
		}
	| ExportDeclarator
		{
			$$ = [$1];
		}
	;
// }}}

ExportDeclaratorLB // {{{
	: '{' NL_0M ExportDeclaratorLBPN '}'
		{
			$$ = $3;
		}
	| '{' NL_0M ExportDeclarator '}'
		{
			$$ = [$3];
		}
	| '{' NL_0M '}'
		{
			$$ = [];
		}
	;
// }}}

ExportDeclaratorLBPN // {{{
	: ExportDeclaratorLBPN ExportDeclaratorLBPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| ExportDeclaratorLBPNI
		{
			$$ = [$1];
		}
	;
// }}}

ExportDeclaratorLBPNI // {{{
	: ExportDeclarator NL_1M
	;
// }}}

ExportDeclarator // {{{
	: ClassDeclaration
	| ConstDeclaration
	| EnumDeclaration
	| FunctionDeclaration
	| LetDeclaration
	| NamespaceDeclaration
	| TypeDeclaration
	| Identifier 'AS' Identifier
		{
			$$ = location({
				kind: NodeKind.ExportAlias,
				name: $1,
				alias: $3
			}, @1, @3);
		}
	| Identifier
	;
// }}}

ExternDeclaration // {{{
	: 'EXTERN' ExternDeclaratorLL
		{
			$$ = location({
				kind: NodeKind.ExternDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'EXTERN' ExternDeclaratorLB
		{
			$$ = location({
				kind: NodeKind.ExternDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

ExternDeclaratorLL // {{{
	: ExternDeclaratorLL ',' ExternDeclarator
		{
			$1.push($3);
			$$ = $1;
		}
	| ExternDeclarator
		{
			$$ = [$1];
		}
	;
// }}}

ExternDeclaratorLB // {{{
	: '{' NL_0M ExternDeclaratorLBPN '}'
		{
			$$ = $3;
		}
	| '{' NL_0M ExternDeclarator '}'
		{
			$$ = [$3];
		}
	| '{' NL_0M '}'
		{
			$$ = [];
		}
	;
// }}}

ExternDeclaratorLBPN // {{{
	: ExternDeclaratorLBPN ExternDeclaratorLBPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| ExternDeclaratorLBPNI
		{
			$$ = [$1];
		}
	;
// }}}

ExternDeclaratorLBPNI // {{{
	: ExternDeclarator NL_1M
	;
// }}}

ExternDeclarator // {{{
	: ExternClass
	| ExternFunction
	| ExternNamespace
	| ExternVariable
	;
// }}}

ExternClass // {{{
	: 'SEALED' 'ABSTRACT' 'CLASS' ExternClassBody
		{
			$4.modifiers = [
				location({
					kind: ModifierKind.Sealed
				}, @1),
				location({
					kind: ModifierKind.Abstract
				}, @2)
			];
			
			$$ = location($4, @1, @4);
		}
	| 'ABSTRACT' 'CLASS' ExternClassBody
		{
			$3.modifiers = [
				location({
					kind: ModifierKind.Abstract
				}, @1)
			];
			
			$$ = location($3, @1, @3);
		}
	| 'SEALED' 'CLASS' ExternClassBody
		{
			$3.modifiers = [
				location({
					kind: ModifierKind.Sealed
				}, @1)
			];
			
			$$ = location($3, @1, @3);
		}
	| 'CLASS' ExternClassBody
		{
			$2.modifiers = [];
			
			$$ = location($2, @1, @2);
		}
	;
// }}}

ExternClassBody // {{{
	: Identifier TypeGeneric 'EXTENDS' Identifier '{' ExternClassMember '}'
		{
			$$ = location({
				kind: NodeKind.ClassDeclaration,
				name: $1,
				extends: $4,
				members: $6
			}, @1, @7);
		}
	| Identifier 'EXTENDS' Identifier '{' ExternClassMember '}'
		{
			$$ = location({
				kind: NodeKind.ClassDeclaration,
				modifiers: [],
				name: $1,
				extends: $3,
				members: $5
			}, @1, @6);
		}
	| Identifier TypeGeneric '{' ExternClassMember '}'
		{
			$$ = location({
				kind: NodeKind.ClassDeclaration,
				modifiers: [],
				name: $1,
				members: $4
			}, @1, @5);
		}
	| Identifier '{' ExternClassMember '}'
		{
			$$ = location({
				kind: NodeKind.ClassDeclaration,
				modifiers: [],
				name: $1,
				members: $3
			}, @1, @4);
		}
	| Identifier TypeGeneric 'EXTENDS' Identifier
		{
			$$ = location({
				kind: NodeKind.ClassDeclaration,
				name: $1,
				extends: $4,
				members: []
			}, @1, @7);
		}
	| Identifier 'EXTENDS' Identifier
		{
			$$ = location({
				kind: NodeKind.ClassDeclaration,
				name: $1,
				extends: $3,
				members: []
			}, @1, @3);
		}
	| Identifier TypeGeneric
		{
			$$ = location({
				kind: NodeKind.ClassDeclaration,
				name: $1,
				members: []
			}, @1, @2);
		}
	| Identifier
		{
			$$ = location({
				kind: NodeKind.ClassDeclaration,
				name: $1,
				members: []
			}, @1);
		}
	;
// }}}

ExternClassMember // {{{
	: ExternClassMember ClassMemberModifiers '{' ExternClassMemberList '}' NL_1M
		{
			for(var i = 0; i < $4.length; i++) {
				$4[i].modifiers = $2;
				
				$1.push($4[i]);
			}
			
			$$ = $1;
		}
	| ExternClassMember ClassMemberModifiers ExternClassMemberSX NL_1M
		{
			$3.modifiers = $2;
			
			$1.push(location($3, @2, @3));
			
			$$ = $1;
		}
	| ExternClassMember ExternClassMemberSX NL_1M
		{
			$1.push($2);
			$$ = $1;
		}
	| ExternClassMember NL_1M
	|
		{
			$$ = []
		}
	;
// }}}

ExternClassMemberList // {{{
	: ExternClassMemberList ExternClassMemberSX NL_1M
		{
			$1.push($2);
			$$ = $1;
		}
	| ExternClassMemberList NL_1M
	|
		{
			$$ = [];
		}
	;
// }}}

ExternClassMemberSX // {{{
	: ExternClassField
	| ExternMethod
	;
// }}}

ExternClassField // {{{
	: NameIST ColonSeparator TypeVar
		{
			$$ = location({
				kind: NodeKind.FieldDeclaration,
				modifiers: [],
				name: $1,
				type: $3
			}, @1, @3);
		}
	| NameIST
		{
			$$ = location({
				kind: NodeKind.FieldDeclaration,
				modifiers: [],
				name: $1
			}, @1);
		}
	;
// }}}

ExternFunction // {{{
	: Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionReturns
		{
			$$ = location({
				kind: NodeKind.FunctionDeclaration,
				modifiers: $5,
				name: $1,
				parameters: $3,
				type: $6
			}, @1, @6);
		}
	| Identifier '(' FunctionParameterList ')' FunctionModifiers
		{
			$$ = location({
				kind: NodeKind.FunctionDeclaration,
				modifiers: $4,
				name: $1,
				parameters: $3
			}, @1, @5);
		}
	;
// }}}

ExternMethod // {{{
	: ExternMethodHeader FunctionModifiers FunctionReturns
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$1.type = $3;
			$$ = location($1, @3);
		}
	| ExternMethodHeader FunctionModifiers
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$$ = location($1, @2);
		}
	;
// }}}

ExternMethodHeader // {{{
	: Identifier '(' FunctionParameterList ')'
		{
			$$ = location({
				name: $1,
				parameters: $3
			}, @1, @4)
		}
	;
// }}}

ExternNamespace // {{{
	: 'SEALED' 'NAMESPACE' Identifier NL_0M '{' NL_0M ExternNamespaceStatementList '}'
		{
			$$ = location({
				kind: NodeKind.NamespaceDeclaration,
				modifiers: [
					location({
						kind: ModifierKind.Sealed
					}, @1)
				],
				name: $3,
				statements: $7
			}, @1, @8)
		}
	| 'NAMESPACE' Identifier NL_0M '{' NL_0M ExternNamespaceStatementList '}'
		{
			$$ = location({
				kind: NodeKind.NamespaceDeclaration,
				modifiers: [],
				name: $2,
				statements: $6
			}, @1, @7)
		}
	| 'SEALED' 'NAMESPACE' Identifier
		{
			$$ = location({
				kind: NodeKind.NamespaceDeclaration,
				modifiers: [
					location({
						kind: ModifierKind.Sealed
					}, @1)
				],
				name: $3,
				statements: []
			}, @1, @3)
		}
	| 'NAMESPACE' Identifier
		{
			$$ = location({
				kind: NodeKind.NamespaceDeclaration,
				modifiers: [],
				name: $2,
				statements: []
			}, @1, @2)
		}
	;
// }}}

ExternNamespaceStatementList // {{{
	: ExternNamespaceStatementList ExternDeclarator NL_1M
		{
			$1.push($2)
			$$ = $1
		}
	|
		{
			$$ = [];
		}
	;
// }}}

ExternOrRequireDeclaration // {{{
	: 'EXTERN|REQUIRE' ExternDeclaratorLL
		{
			$$ = location({
				kind: NodeKind.ExternOrRequireDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'EXTERN|REQUIRE' ExternDeclaratorLB
		{
			$$ = location({
				kind: NodeKind.ExternOrRequireDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

ExternVariable // {{{
	: 'SEALED' Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: NodeKind.VariableDeclarator,
				name: $2,
				type: $4,
				sealed: true
			}, @1, @4)
		}
	| 'SEALED' Identifier
		{
			$$ = location({
				kind: NodeKind.VariableDeclarator,
				name: $2,
				sealed: true
			}, @1, @2)
		}
	| Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: NodeKind.VariableDeclarator,
				name: $1,
				type: $3
			}, @1, @3)
		}
	| Identifier
		{
			$$ = location({
				kind: NodeKind.VariableDeclarator,
				name: $1
			}, @1)
		}
	;
// }}}

Expression // {{{
	: FunctionExpression
	| SwitchExpression
	| ExpressionFlowSX 'SPACED_?' Expression 'SPACED_:' Expression
		{
			$$ = location({
				kind: NodeKind.ConditionalExpression,
				condition: reorderExpression($1),
				whenTrue: $3,
				whenFalse: $5
			}, @1, @5);
		}
	| ExpressionFlowSX
		{
			$$ = reorderExpression($1);
		}
	;
// }}}

ExpressionFlow // {{{
	: ExpressionFlowSX
		{
			$$ = reorderExpression($1);
		}
	;
// }}}

ExpressionFlowSX // {{{
	: ExpressionFlowSX BinaryOperatorKind OperandOrType
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| ExpressionFlowSX AssignmentOperatorKind OperandOrType
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| OperandOrType
		{
			$$ = [$1]
		}
	;
// }}}

Expression_NoAnonymousFunction // {{{
	: FunctionExpression
	| SwitchExpression
	| ExpressionFlowSX_NoAnonymousFunction 'SPACED_?' Expression 'SPACED_:' Expression
		{
			$$ = location({
				kind: NodeKind.ConditionalExpression,
				condition: reorderExpression($1),
				whenTrue: $3,
				whenFalse: $5
			}, @1, @5);
		}
	| ExpressionFlowSX_NoAnonymousFunction
		{
			$$ = reorderExpression($1);
		}
	;
// }}}

ExpressionFlowSX_NoAnonymousFunction // {{{
	: ExpressionFlowSX_NoAnonymousFunction BinaryOperatorKind OperandOrType_NoAnonymousFunction
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| ExpressionFlowSX_NoAnonymousFunction AssignmentOperatorKind OperandOrType_NoAnonymousFunction
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| OperandOrType_NoAnonymousFunction
		{
			$$ = [$1]
		}
	;
// }}}

Expression_NoObject // {{{
	: FunctionExpression
	| SwitchExpression
	| ExpressionFlowSX_NoObject 'SPACED_?' Expression 'SPACED_:' Expression
		{
			$$ = location({
				kind: NodeKind.ConditionalExpression,
				condition: reorderExpression($1),
				whenTrue: $3,
				whenFalse: $5
			}, @1, @5);
		}
	| ExpressionFlowSX_NoObject
		{
			$$ = reorderExpression($1);
		}
	;
// }}}

ExpressionFlowSX_NoObject // {{{
	: ExpressionFlowSX_NoObject BinaryOperatorKind OperandOrType_NoObject
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| ExpressionFlowSX_NoObject AssignmentOperatorKind OperandOrType_NoObject
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| OperandOrType_NoObject
		{
			$$ = [$1]
		}
	;
// }}}

Expression0CNList // {{{
	: NL_0M Expression0CNListPN Expression
		{
			$2.push($3);
			$$ = $2;
		}
	| NL_0M Expression0CNListPN
		{
			$$ = $2;
		}
	| NL_0M Expression
		{
			$$ = [$2];
		}
	| NL_0M
		{
			$$ = [];
		}
	;
// }}}

Expression0CNListPN // {{{
	: Expression0CNListPN Expression0CNListPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| Expression0CNListPNI
		{
			$$ = [$1];
		}
	;
// }}}
	
Expression0CNListPNI // {{{
	: Expression ',' NL_0M
	| Expression NL_1M
	;
// }}}

Expression1CList // {{{
	: Expression1CList ',' Expression
		{
			$1.push($3);
			$$ = $1;
		}
	| Expression
		{
			$$ = [$1];
		}
	;
// }}}

FinallyClause // {{{
	: 'FINALLY' Block
		{
			$$ = $2
		}
	;
// }}}

ForExpression // {{{
	: 'FOR' ForFromBegin NL_0M ForFromMiddle NL_0M ForExpressionLoop NL_0M ForExpressionWhen
		{
			$$ = location($4, @1, @8);
			
			$$.declaration = $2.declaration;
			$$.variable = $2.variable;
			
			if($6) {
				if($6.until) {
					$$.until = $6.until;
				}
				else {
					$$.while = $6.while;
				}
			}
			
			if($8) {
				$$.when = $8;
			}
		}
	| 'FOR' ForInBegin NL_0M ForInMiddle NL_0M ForExpressionLoop NL_0M ForExpressionWhen
		{
			$$ = location($4, @1, @8);
			
			$$.declaration = $2.declaration;
			$$.value = $2.value;
			
			if($2.index) {
				$$.index = $2.index;
			}
			
			if($6) {
				if($6.until) {
					$$.until = $6.until;
				}
				else {
					$$.while = $6.while;
				}
			}
			
			if($8) {
				$$.when = $8;
			}
		}
	| 'FOR' ForOfBegin NL_0M ForOfMiddle NL_0M ForExpressionLoop NL_0M ForExpressionWhen
		{
			$$ = location($4, @1, @8);
			
			$$.declaration = $2.declaration;
			
			if($2.key) {
				$$.key = $2.key;
			}
			if($2.value) {
				$$.value = $2.value;
			}
			
			if($6) {
				if($6.until) {
					$$.until = $6.until;
				}
				else {
					$$.while = $6.while;
				}
			}
			
			if($8) {
				$$.when = $8;
			}
		}
	;
// }}}

ForExpressionLoop // {{{
	: 'UNTIL' Expression
		{
			$$ = {
				until: $2
			};
		}
	| 'WHILE' Expression
		{
			$$ = {
				while: $2
			};
		}
	|
	;
// }}}

ForExpressionWhen // {{{
	: 'WHEN' Expression
		{
			$$ = $2;
		}
	|
	;
// }}}

ForFromBegin // {{{
	: 'LET' Identifier
		{
			$$ = {
				variable: $2,
				declaration: true
			};
		}
	| Identifier
		{
			$$ = {
				variable: $1,
				declaration: false
			};
		}
	;
// }}}

ForFromMiddle // {{{
	: 'FROM' Expression 'TIL' Expression 'BY' Expression
		{
			$$ = {
				kind: NodeKind.ForFromStatement,
				from: $2,
				til: $4,
				by: $6
			};
		}
	| 'FROM' Expression 'TIL' Expression
		{
			$$ = {
				kind: NodeKind.ForFromStatement,
				from: $2,
				til: $4
			};
		}
	| 'FROM' Expression 'TO' Expression 'BY' Expression
		{
			$$ = {
				kind: NodeKind.ForFromStatement,
				from: $2,
				to: $4,
				by: $6
			};
		}
	| 'FROM' Expression 'TO' Expression
		{
			$$ = {
				kind: NodeKind.ForFromStatement,
				from: $2,
				to: $4
			};
		}
	;
// }}}

ForInBegin // {{{
	: 'LET' Identifier ',' Identifier
		{
			$$ = {
				value: $2,
				index: $4,
				declaration: true
			};
		}
	| 'LET' ':' Identifier
		{
			$$ = {
				index: $3,
				declaration: true
			};
		}
	| 'LET' Identifier
		{
			$$ = {
				value: $2,
				declaration: true
			};
		}
	| Identifier ',' Identifier
		{
			$$ = {
				value: $1,
				index: $3,
				declaration: false
			};
		}
	| ':' Identifier
		{
			$$ = {
				index: $2,
				declaration: false
			};
		}
	| Identifier
		{
			$$ = {
				value: $1,
				declaration: false
			};
		}
	;
// }}}

ForInMiddle // {{{
	: 'IN' Number '...' Number '..' Number
		{
			$$ = {
				kind: NodeKind.ForRangeStatement,
				from: $2,
				til: $4,
				by: $6
			};
		}
	| 'IN' Number '..' Number '..' Number
		{
			$$ = {
				kind: NodeKind.ForRangeStatement,
				from: $2,
				to: $4,
				by: $6
			};
		}
	| 'IN' Number '...' Number
		{
			$$ = {
				kind: NodeKind.ForRangeStatement,
				from: $2,
				til: $4
			};
		}
	| 'IN' Number '..' Number
		{
			$$ = {
				kind: NodeKind.ForRangeStatement,
				from: $2,
				to: $4
			};
		}
	| 'IN' Expression 'DESC'
		{
			$$ = {
				kind: NodeKind.ForInStatement,
				expression: $2,
				desc: true
			};
		}
	| 'IN' Expression
		{
			$$ = {
				kind: NodeKind.ForInStatement,
				expression: $2,
				desc: false
			};
		}
	;
// }}}

ForOfBegin // {{{
	: 'LET' Identifier ',' Identifier
		{
			$$ = {
				key: $2,
				value: $4,
				declaration: true
			};
		}
	| 'LET' ':' Identifier
		{
			$$ = {
				value: $3,
				declaration: true
			};
		}
	| 'LET' Identifier
		{
			$$ = {
				key: $2,
				declaration: true
			};
		}
	| Identifier ',' Identifier
		{
			$$ = {
				key: $1,
				value: $3,
				declaration: false
			};
		}
	| ':' Identifier
		{
			$$ = {
				value: $2,
				declaration: false
			};
		}
	| Identifier
		{
			$$ = {
				key: $1,
				declaration: false
			};
		}
	;
// }}}

ForOfMiddle // {{{
	: 'OF' Expression
		{
			$$ = {
				kind: NodeKind.ForOfStatement,
				expression: $2
			};
		}
	;
// }}}

ForStatement // {{{
	: ForExpression NL_0M Block
		{
			$1.body = $3;
			$$ = location($1, @3);
		}
	;
// }}}

FunctionBody // {{{
	: Block
	| '=>' Expression
		{
			$$ = $2
		}
	;
// }}}

FunctionDeclaration // {{{
	: 'FUNC' Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionReturns FunctionThrows FunctionBody
		{
			$$ = location({
				kind: NodeKind.FunctionDeclaration,
				modifiers: $6,
				name: $2,
				parameters: $4,
				type: $7,
				throws: $8,
				body: $9
			}, @1, @9);
		}
	| 'FUNC' Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionReturns FunctionBody
		{
			$$ = location({
				kind: NodeKind.FunctionDeclaration,
				modifiers: $6,
				name: $2,
				parameters: $4,
				type: $7,
				throws: [],
				body: $8
			}, @1, @8);
		}
	| 'FUNC' Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionThrows FunctionBody
		{
			$$ = location({
				kind: NodeKind.FunctionDeclaration,
				modifiers: $6,
				name: $2,
				parameters: $4,
				throws: $7,
				body: $8
			}, @1, @8);
		}
	| 'FUNC' Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionBody
		{
			$$ = location({
				kind: NodeKind.FunctionDeclaration,
				modifiers: $6,
				name: $2,
				parameters: $4,
				throws: [],
				body: $7
			}, @1, @7);
		}
	;
// }}}

FunctionExpression // {{{
	: 'FUNC' '(' FunctionParameterList ')' FunctionModifiers FunctionReturns FunctionBody
		{
			$$ = location({
				kind: NodeKind.FunctionExpression,
				modifiers: $5,
				parameters: $3,
				type: $6,
				body: $7
			}, @1, @7);
		}
	| 'FUNC' '(' FunctionParameterList ')' FunctionModifiers FunctionBody
		{
			$$ = location({
				kind: NodeKind.FunctionExpression,
				modifiers: $5,
				parameters: $3,
				body: $6
			}, @1, @6);
		}
	| '(' FunctionParameterList ')' FunctionModifiers FunctionReturns LambdaBody
		{
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: $4,
				parameters: $2,
				type: $5,
				body: $6
			}, @1, @6);
		}
	| '(' FunctionParameterList ')' FunctionModifiers LambdaBody
		{
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: $4,
				parameters: $2,
				body: $5
			}, @1, @5);
		}
	| Identifier LambdaBody
		{
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: [],
				parameters: [{
					kind: NodeKind.Parameter,
					modifiers: [],
					name: $1
				}],
				body: $2
			}, @1, @2);
		}
	;
// }}}

FunctionModifiers // {{{
	: FunctionModifiers 'ASYNC'
		{
			$1.push(location({
				kind: ModifierKind.Async
			}, @2));
			$$ = $1;
		}
	|
		{
			$$ = [];
		}
	;
// }}}

FunctionParameter // {{{
	: FunctionParameterModifier FunctionParameterSX
		{
			$2.modifiers = [$1];
			
			$$ = location($2, @1, @2);
		}
	| FunctionParameterModifier
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [$1]
			}, @1)
		}
	| FunctionParameterSX
	;
// }}}

FunctionParameterSX // {{{
	: Identifier ColonSeparator TypeVar '=' Expression
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [],
				name: $1,
				type: $3,
				defaultValue: $5
			}, @1, @5);
		}
	| Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [],
				name: $1,
				type: $3
			}, @1, @3);
		}
	| Identifier '=' Expression
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [],
				name: $1,
				defaultValue: $3
			}, @1, @3);
		}
	| Identifier '?' '=' Expression
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [],
				name: $1,
				type: {
					kind: NodeKind.TypeReference,
					typeName: {
						kind: NodeKind.Identifier,
						name: 'any'
					},
					nullable: true
				},
				defaultValue: $4
			}, @1, @4);
		}
	| Identifier '?'
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [],
				name: $1,
				type: {
					kind: NodeKind.TypeReference,
					typeName: {
						kind: NodeKind.Identifier,
						name: 'any'
					},
					nullable: true
				}
			}, @1, @2);
		}
	| Identifier
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [],
				name: $1
			}, @1);
		}
	| ColonSeparator TypeVar
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [],
				type: $2
			}, @1, @2);
		}
	;
// }}}

FunctionParameterList // {{{
	: ',' FunctionParameterListSX
		{
			$2.unshift({
				kind: NodeKind.Parameter,
				modifiers: []
			});
			
			$$ = $2;
		}
	| FunctionParameterListSX
	|
		{
			$$ = [];
		}
	;

FunctionParameterListSX
	: FunctionParameterListSX ',' FunctionParameter
		{
			$1.push($3);
			$$ = $1;
		}
	| FunctionParameterListSX ','
		{
			$1.push({
				kind: NodeKind.Parameter,
				modifiers: []
			});
		}
	| FunctionParameter
		{
			$$ = [$1];
		}
	;
// }}}

FunctionParameterModifier // {{{
	: '...' '{' Number ',' Number '}'
		{
			$$ = location({
				kind: ModifierKind.Rest,
				arity: {
					min: $3.value,
					max: $5.value
				}
			}, @1, @6);
		}
	| '...' '{' ',' Number '}'
		{
			$$ = location({
				kind: ModifierKind.Rest,
				arity: {
					min: 0,
					max: $4.value
				}
			}, @1, @5);
		}
	| '...' '{' Number ',' '}'
		{
			$$ = location({
				kind: ModifierKind.Rest,
				arity: {
					min: $3.value,
					max: Infinity
				}
			}, @1, @5);
		}
	| '...'
		{
			$$ = location({
				kind: ModifierKind.Rest,
				arity: {
					min: 0,
					max: Infinity
				}
			}, @1);
		}
	;
// }}}

FunctionReturns // {{{
	: ColonSeparator TypeVar
		{
			$$ = $2;
		}
	;
// }}}

FunctionThrows // {{{
	: FunctionThrows ',' Identifier
		{
			$1.push($3);
		}
	| '~' Identifier
		{
			$$ = [$2];
		}
	;
// }}}

Identifier // {{{
	: 'IDENTIFIER'
		{
			$$ = location({
				kind: NodeKind.Identifier,
				name: $1
			}, @1);
		}
	| Keyword
		{
			$$ = location({
				kind: NodeKind.Identifier,
				name: $1
			}, @1);
		}
	;
// }}}

Identifier_NoWhereNoWith // {{{
	: 'IDENTIFIER'
		{
			$$ = location({
				kind: NodeKind.Identifier,
				name: $1
			}, @1);
		}
	| Keyword_NoWhereNoWith
		{
			$$ = location({
				kind: NodeKind.Identifier,
				name: $1
			}, @1);
		}
	;
// }}}

IfStatement // {{{
	: 'IF' Expression_NoAnonymousFunction NL_0M Block
		{
			$$ = location({
				kind: NodeKind.IfStatement,
				condition: $2,
				whenTrue: $4
			}, @1, @4);
		}
	;
// }}}

IfStatementList // {{{
	: IfStatementList NL_EOF_1M 'ELSE' IfStatement
		{
			$1.push($4);
		}
	| 'ELSE' IfStatement
		{
			$$ = [$2];
		}
	;
// }}}

ImplementDeclaration // {{{
	: 'IMPL' Identifier TypeGeneric '{' ClassMember '}'
		{
			$$ = location({
				kind: NodeKind.ImplementDeclaration,
				variable: $2,
				properties: $5
			}, @1, @6);
		}
	| 'IMPL' Identifier '{' ClassMember '}'
		{
			$$ = location({
				kind: NodeKind.ImplementDeclaration,
				variable: $2,
				properties: $4
			}, @1, @5);
		}
	;
// }}}

ImportDeclaration // {{{
	: 'IMPORT' ImportDeclarator
		{
			$$ = location({
				kind: NodeKind.ImportDeclaration,
				declarations: [$2]
			}, @1, @2);
		}
	| 'IMPORT' ImportDeclaratorLB
		{
			$$ = location({
				kind: NodeKind.ImportDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

ImportDeclaratorLB // {{{
	: '{' NL_0M ImportDeclaratorLBPN '}'
		{
			$$ = $3;
		}
	| '{' NL_0M ImportDeclarator '}'
		{
			$$ = [$3];
		}
	| '{' NL_0M '}'
		{
			$$ = [];
		}
	;
// }}}

ImportDeclaratorLBPN // {{{
	: ImportDeclaratorLBPN ImportDeclaratorLBPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| ImportDeclaratorLBPNI
		{
			$$ = [$1];
		}
	;
// }}}

ImportDeclaratorLBPNI // {{{
	: ImportDeclarator NL_1M
	;
// }}}

ImportDeclarator // {{{
	: ImportSpecifierList 'FROM' ImportName 'WITH' ImportReferenceList
		{
			$$ = location({
				kind: NodeKind.ImportDeclarator,
				module: $3,
				specifiers: $1,
				references: $5
			}, @1, @5)
		}
	| ImportSpecifierList 'FROM' ImportName
		{
			$$ = location({
				kind: NodeKind.ImportDeclarator,
				module: $3,
				specifiers: $1
			}, @1, @3)
		}
	;
// }}}

ImportName // {{{
	: 'STRING'
	| ImportNameBegin 'IMPORT_LITERAL'
		{
			$$ = $1 + $2;
		}
	| 'IDENTIFIER' ImportNameBegin 'IMPORT_LITERAL'
		{
			$$ = $1 + $2 + $3;
		}
	| 'MODULE_NAME' ImportNameBegin 'IMPORT_LITERAL'
		{
			$$ = $1 + $2 + $3;
		}
	| Keyword ImportNameBegin 'IMPORT_LITERAL'
		{
			$$ = $1 + $2 + $3;
		}
	| 'IDENTIFIER'
	| 'MODULE_NAME'
	| Keyword
	;
// }}}

ImportNameBegin // {{{
	: '..'
		{
			yy.lexer.begin('import');
		}
	| '.'
		{
			yy.lexer.begin('import');
		}
	| '/'
		{
			yy.lexer.begin('import');
		}
	| '@'
		{
			yy.lexer.begin('import');
		}
	| '-'
		{
			yy.lexer.begin('import');
		}
	;
// }}}

ImportSpecifierList // {{{
	: ImportSpecifierList ',' ImportSpecifier
		{
			$1.push($3);
			$$ = $1;
		}
	| ImportSpecifier
		{
			$$ = [$1];
		}
	;
// }}}

ImportSpecifier // {{{
	: Identifier 'AS' Identifier
		{
			$$ = location({
				kind: NodeKind.ImportSpecifier,
				alias: $1,
				local: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: NodeKind.ImportSpecifier,
				alias: $1
			}, @1);
		}
	| '*' 'AS' Identifier
		{
			$$ = location({
				kind: NodeKind.ImportWildcardSpecifier,
				local: $3
			}, @1, @3);
		}
	| '*'
		{
			$$ = location({
				kind: NodeKind.ImportWildcardSpecifier
			}, @1);
		}
	;
// }}}

ImportReferenceList // {{{
	: ImportReferenceList ',' ImportReference
		{
			$1.push($3);
			$$ = $1;
		}
	| ImportReference
		{
			$$ = [$1];
		}
	;
// }}}

ImportReference // {{{
	: Identifier 'AS' Identifier
		{
			$$ = location({
				kind: NodeKind.ImportReference,
				alias: $1,
				foreign: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: NodeKind.ImportReference,
				alias: $1
			}, @1);
		}
	;
// }}}

IncludeDeclaration // {{{
	: 'INCLUDE' ImportName
		{
			$$ = location({
				kind: NodeKind.IncludeDeclaration,
				files: [$2]
			}, @1, @2)
		}
	| 'INCLUDE' IncludeLB
		{
			$$ = location({
				kind: NodeKind.IncludeDeclaration,
				files: $2
			}, @1, @2);
		}
	;
// }}}

IncludeLB // {{{
	: IncludeLBBegin IncludeLBPN 'NEWLINE'
		{
			$$ = $2;
		}
	| IncludeLBBegin 'NEWLINE'
		{
			$$ = [];
		}
	;
// }}}

IncludeLBBegin // {{{
	: '{'
		{
			yy.lexer.begin('resource');
		}
	;
// }}}

IncludeLBPN // {{{
	: IncludeLBPN IncludeLBPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| IncludeLBPNI
		{
			$$ = [$1];
		}
	;
// }}}

IncludeLBPNI // {{{
	: 'NEWLINE' 'RESOURCE_NAME'
		{
			$$ = $2
		}
	;
// }}}

IncludeOnceDeclaration // {{{
	: 'INCLUDE_ONCE' ImportName
		{
			$$ = location({
				kind: NodeKind.IncludeOnceDeclaration,
				files: [$2]
			}, @1, @2)
		}
	| 'INCLUDE_ONCE' IncludeLB
		{
			$$ = location({
				kind: NodeKind.IncludeOnceDeclaration,
				files: $2
			}, @1, @2);
		}
	;
// }}}

Keyword // {{{
	: 'ABSTRACT'
	| 'AS'
	| 'ASYNC'
	| 'AWAIT'
	| 'BREAK'
	| 'BY'
	| 'CATCH'
	| 'CLASS'
	| 'CONST'
	| 'CONTINUE'
	| 'DELETE'
	| 'DESC'
	| 'DO'
	| 'ELSE'
	| 'ENUM'
	| 'EXPORT'
	| 'EXTENDS'
	| 'EXTERN'
	| 'SEALED'
	| 'FINALLY'
	| 'FOR'
	| 'FROM'
	| 'FUNC'
	| 'GET'
	| 'IF'
	| 'IMPL'
	| 'IMPORT'
	| 'INCLUDE'
	| 'IN'
	| 'IS'
	| 'LET'
	| 'NEW'
	| 'NAMESPACE'
	| 'OF'
	| 'ON'
	| 'PRIVATE'
	| 'PROTECTED'
	| 'PUBLIC'
	| 'REQUIRE'
	| 'RETURN'
	| 'SEALED'
	| 'SET'
	| 'STATIC'
	| 'SWITCH'
	| 'TIL'
	| 'TO'
	| 'THROW'
	| 'TRY'
	| 'TYPE'
	| 'UNLESS'
	| 'UNTIL'
	| 'WHEN'
	| 'WHERE'
	| 'WHILE'
	| 'WITH'
	;
// }}}

Keyword_NoWhereNoWith // {{{
	: 'ABSTRACT'
	| 'AS'
	| 'ASYNC'
	| 'AWAIT'
	| 'BREAK'
	| 'BY'
	| 'CATCH'
	| 'CLASS'
	| 'CONST'
	| 'CONTINUE'
	| 'DELETE'
	| 'DESC'
	| 'DO'
	| 'ELSE'
	| 'ENUM'
	| 'EXPORT'
	| 'EXTENDS'
	| 'EXTERN'
	| 'SEALED'
	| 'FINALLY'
	| 'FOR'
	| 'FROM'
	| 'FUNC'
	| 'GET'
	| 'IF'
	| 'IMPL'
	| 'IMPORT'
	| 'INCLUDE'
	| 'IN'
	| 'IS'
	| 'LET'
	| 'NEW'
	| 'NAMESPACE'
	| 'OF'
	| 'ON'
	| 'PRIVATE'
	| 'PROTECTED'
	| 'PUBLIC'
	| 'REQUIRE'
	| 'RETURN'
	| 'SEALED'
	| 'SET'
	| 'STATIC'
	| 'SWITCH'
	| 'TIL'
	| 'TO'
	| 'THROW'
	| 'TRY'
	| 'TYPE'
	| 'UNLESS'
	| 'UNTIL'
	| 'WHEN'
	| 'WHILE'
	;
// }}}

LambdaBody // {{{
	: '=>' Block
		{
			$$ = $2
		}
	| '=>' Expression_NoObject
		{
			$$ = $2
		}
	;
// }}}

LetDeclaration // {{{
	: 'LET' DestructuringArray ',' TypedVariableListX VariableEquals 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [location({
					kind: NodeKind.VariableDeclarator,
					name: $2
				}, @2)].concat($4),
				autotype: $5,
				init: location({
					kind: NodeKind.AwaitExpression,
					operation: $7
				}, @6, @7)
			}, @1, @7);
		}
	| 'LET' DestructuringObject ',' TypedVariableListX VariableEquals 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [location({
					kind: NodeKind.VariableDeclarator,
					name: $2
				}, @2)].concat($4),
				autotype: $5,
				init: location({
					kind: NodeKind.AwaitExpression,
					operation: $7
				}, @6, @7)
			}, @1, @7);
		}
	| 'LET' TypedIdentifier ',' TypedVariableListX VariableEquals 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [$2].concat($4),
				autotype: $5,
				init: location({
					kind: NodeKind.AwaitExpression,
					operation: $7
				}, @6, @7)
			}, @1, @7);
		}
	| 'LET' DestructuringArray VariableEquals 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [location({
					kind: NodeKind.VariableDeclarator,
					name: $2,
				}, @2)],
				autotype: $3,
				init: location({
					kind: NodeKind.AwaitExpression,
					operation: $5
				}, @4, @5)
			}, @1, @5);
		}
	| 'LET' DestructuringObject VariableEquals 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [location({
					kind: NodeKind.VariableDeclarator,
					name: $2,
				}, @2)],
				autotype: $3,
				init: location({
					kind: NodeKind.AwaitExpression,
					operation: @5
				}, @4, @5)
			}, @1, @5);
		}
	| 'LET' TypedIdentifier VariableEquals 'AWAIT' Operand
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [$2],
				autotype: $3,
				init: location({
					kind: NodeKind.AwaitExpression,
					operation: $5
				}, @4, @5)
			}, @1, @5);
		}
	| 'LET' DestructuringArray VariableEquals Expression VariableCondition
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [location({
					kind: NodeKind.VariableDeclarator,
					name: $2,
				}, @2)],
				autotype: $3,
				init: setCondition($4, @4, $5, @5)
			}, @1, @5);
		}
	| 'LET' DestructuringObject VariableEquals Expression VariableCondition
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [location({
					kind: NodeKind.VariableDeclarator,
					name: $2,
				}, @2)],
				autotype: $3,
				init: setCondition($4, @4, $5, @5)
			}, @1, @5);
		}
	| 'LET' TypedIdentifier VariableEquals Expression VariableCondition
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [$2],
				autotype: $3,
				init: setCondition($4, @4, $5, @5)
			}, @1, @5);
		}
	| 'LET' TypedIdentifier
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [$2]
			}, @1, @2);
		}
	| 'LET' TypedIdentifier ',' TypedIdentifierListX
		{
			$$ = location({
				kind: NodeKind.VariableDeclaration,
				rebindable: true,
				variables: [$2].concat($4)
			}, @1, @4);
		}
	;
// }}}

Method // {{{
	: MethodHeader FunctionModifiers FunctionReturns FunctionThrows MethodBody
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$1.type = $3;
			$1.throws = $4;
			$1.body = $5;
			$$ = location($1, @5);
		}
	| MethodHeader FunctionModifiers FunctionReturns MethodBody
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$1.type = $3;
			$1.body = $4;
			$$ = location($1, @4);
		}
	| MethodHeader FunctionModifiers FunctionThrows MethodBody
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$1.throws = $3;
			$1.body = $4;
			$$ = location($1, @4);
		}
	| MethodHeader FunctionModifiers MethodBody
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = $2;
			$1.body = $3;
			$$ = location($1, @3);
		}
	| MethodHeader
		{
			$1.kind = NodeKind.MethodDeclaration;
			$1.modifiers = [];
			$$ = location($1, @1);
		}
	;
// }}}

MethodBody // {{{
	: Block
	| '=>' Expression
		{
			$$ = $2;
		}
	;
// }}}

MethodHeader // {{{
	: NameIST '(' MethodParameterList ')'
		{
			$$ = location({
				name: $1,
				parameters: $3,
				throws: []
			}, @1, @4)
		}
	;
// }}}

MethodParameter // {{{
	: FunctionParameter
	| '@' Identifier '(' ')' '=' Expression
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [
					location({
						kind: ModifierKind.ThisAlias
					}, @1),
					location({
						kind: ModifierKind.SetterAlias
					}, @3, @4)
				],
				name: $2,
				defaultValue: $6
			}, @1, @6);
		}
	| '@' Identifier '(' ')'
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [
					location({
						kind: ModifierKind.ThisAlias
					}, @1),
					location({
						kind: ModifierKind.SetterAlias
					}, @3, @4)
				],
				name: $2,
			}, @1, @4);
		}
	| '@' Identifier '=' Expression
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [
					location({
						kind: ModifierKind.ThisAlias
					}, @1)
				],
				name: $2,
				defaultValue: $4
			}, @1, @4);
		}
	| '@' Identifier
		{
			$$ = location({
				kind: NodeKind.Parameter,
				modifiers: [
					location({
						kind: ModifierKind.ThisAlias
					}, @1)
				],
				name: $2
			}, @1, @2);
		}
	;
// }}}

MethodParameterList // {{{
	: ',' MethodParameterListSX
		{
			$2.unshift({
				kind: NodeKind.Parameter,
				modifiers: []
			});
			
			$$ = $2;
		}
	| MethodParameterListSX
	|
		{
			$$ = [];
		}
	;

MethodParameterListSX
	: MethodParameterListSX ',' MethodParameter
		{
			$1.push($3);
			$$ = $1;
		}
	| MethodParameterListSX ','
		{
			$1.push({
				kind: NodeKind.Parameter,
				modifiers: []
			});
		}
	| MethodParameter
		{
			$$ = [$1];
		}
	;
// }}}

Module // {{{
	: ModuleSX
		{
			return $1;
		}
	;
// }}}

ModuleSX // {{{
	: ModuleSX ModuleBody
		{
			$$ = location($1, @2);
			$$.body.push($2);
		}
	| ModuleSX AttributeBlock NL_EOF_1
		{
			$$ = location($1, @2);
			$$.attributes.push($2);
		}
	| ModuleSX NL_EOF_1
	|
		{
			$$ = {
				kind: NodeKind.Module,
				attributes: [],
				body: []
			};
		}
	;
// }}}

ModuleBody // {{{
	: AttributeList ModuleBodySX
		{
			$$ = location($2, @1, @2);
			$$.attributes = $1;
		}
	| ModuleBodySX
		{
			$$ = $1;
			$$.attributes = [];
		}
	;
// }}}

ModuleBodySX // {{{
	: ExportDeclaration NL_EOF_1
	| ExternDeclaration NL_EOF_1
	| ImportDeclaration NL_EOF_1
	| IncludeDeclaration NL_EOF_1
	| IncludeOnceDeclaration NL_EOF_1
	| RequireDeclaration NL_EOF_1
	| ExternOrRequireDeclaration NL_EOF_1
	| RequireOrExternDeclaration NL_EOF_1
	| RequireOrImportDeclaration NL_EOF_1
	| Statement
	;
// }}}

NameIS // {{{
	: Identifier
	| String
	;
// }}}

NameIST // {{{
	: Identifier
	| String
	| TemplateExpression
	;
// }}}

NamespaceDeclaration // {{{
	: 'NAMESPACE' Identifier NL_0M '{' NL_0M NamespaceStatementList '}'
		{
			$$ = location({
				kind: NodeKind.NamespaceDeclaration,
				modifiers: [],
				name: $2,
				statements: $6
			}, @1, @7)
		}
	;
// }}}

NamespaceStatement // {{{
	: ClassDeclaration
	| ConstDeclaration
	| EnumDeclaration
	| FunctionDeclaration
	| LetDeclaration
	| NamespaceDeclaration
	| TypeDeclaration
	;
// }}}

NamespaceStatementList // {{{
	: NamespaceStatementList NamespaceStatement NL_1M
		{
			$1.push($2)
			$$ = $1
		}
	|
		{
			$$ = [];
		}
	;
// }}}

NL_EOF_1 // {{{
	: 'EOF'
	| 'NEWLINE'
	;
// }}}

NL_EOF_1M // {{{
	: NL_EOF_1M 'EOF'
	| NL_EOF_1M 'NEWLINE'
	| 'EOF'
	| 'NEWLINE'
	;
// }}}

NL_1M // {{{
	: NL_1M 'NEWLINE'
	| 'NEWLINE'
	;
// }}}

NL_0M // {{{
	: NL_1M
	|
	;
// }}}

NL_01 // {{{
	: 'NEWLINE'
	|
	;
// }}}

Number // {{{
	: 'BINARY_NUMBER'
		{
			$$ = location({
				kind: NodeKind.NumericExpression,
				value: parseInt($1.slice(2).replace(/\_/g, ''), 2)
			}, @1);
		}
	| 'OCTAL_NUMBER'
		{
			$$ = location({
				kind: NodeKind.NumericExpression,
				value: parseInt($1.slice(2).replace(/\_/g, ''), 8)
			}, @1);
		}
	| 'HEX_NUMBER'
		{
			$$ = location({
				kind: NodeKind.NumericExpression,
				value: parseInt($1.slice(2).replace(/\_/g, ''), 16)
			}, @1);
		}
	| 'RADIX_NUMBER'
		{
			var data = /^(\d+)r(.*)$/.exec($1);
			
			$$ = location({
				kind: NodeKind.NumericExpression,
				value: parseInt(data[2].replace(/\_/g, ''), parseInt(data[1]))
			}, @1);
		}
	| 'DECIMAL_NUMBER'
		{
			$$ = location({
				kind: NodeKind.NumericExpression,
				value: parseFloat($1.replace(/\_/g, ''), 10)
			}, @1);
		}
	;
// }}}

Object // {{{
	: '{' NL_0M ObjectListPN ObjectItem '}'
		{
			$3.push($4);
			
			$$ = location({
				kind: NodeKind.ObjectExpression,
				properties: $3
			}, @1, @5);
		}
	| '{' NL_0M ObjectListPN '}'
		{
			$$ = location({
				kind: NodeKind.ObjectExpression,
				properties: $3
			}, @1, @4);
		}
	| '{' NL_0M ObjectItem '}'
		{
			$$ = location({
				kind: NodeKind.ObjectExpression,
				properties: [$3]
			}, @1, @4);
		}
	| '{' NL_0M '}'
		{
			$$ = location({
				kind: NodeKind.ObjectExpression,
				properties: []
			}, @1, @3);
		}
	;
// }}}

ObjectListPN // {{{
	: ObjectListPN ObjectListPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| ObjectListPNI
		{
			$$ = [$1];
		}
	;
// }}}
	
ObjectListPNI // {{{
	: AttributeList ObjectItem ',' NL_0M
		{
			$$ = location($2, @1, @2);
			$$.attributes = $1;
		}
	| AttributeList ObjectItem NL_1M
		{
			$$ = location($2, @1, @2);
			$$.attributes = $1;
		}
	| ObjectItem ',' NL_0M
	| ObjectItem NL_1M
	;
// }}}

ObjectItem // {{{
	: NameIST ColonSeparator Expression
		{
			$$ = location({
				kind: NodeKind.ObjectMember,
				name: $1,
				value: $3
			}, @1, @3);
		}
	| NameIST '(' FunctionParameterList ')' FunctionModifiers FunctionReturns FunctionBody
		{
			$$ = location({
				kind: NodeKind.ObjectMember,
				name: $1,
				value: location({
					kind: NodeKind.FunctionExpression,
					parameters: $3,
					modifiers: $5,
					type: $6,
					body: $7
				}, @2, @7)
			}, @1, @7);
		}
	| NameIST '(' FunctionParameterList ')' FunctionModifiers FunctionBody
		{
			$$ = location({
				kind: NodeKind.ObjectMember,
				name: $1,
				value: location({
					kind: NodeKind.FunctionExpression,
					parameters: $3,
					modifiers: $5,
					body: $6
				}, @2, @6)
			}, @1, @6);
		}
	;
// }}}

Operand // {{{
	: PrefixUnaryOperatorKind Operand
		{
			if($1.kind === UnaryOperatorKind.Negative && $2.kind === NodeKind.NumericExpression) {
				$2.value = -$2.value;
				$$ = location($2, @1, @2);
			}
			else {
				$$ = location({
					kind: NodeKind.UnaryExpression,
					operator: $1,
					argument: $2
				}, @1, @2);
			}
		}
	| Operand PostfixUnaryOperatorKind
		{
			$$ = location({
				kind: NodeKind.UnaryExpression,
				operator: $2,
				argument: $1
			}, @1, @2);
		}
	| OperandSX
	;
// }}}

OperandSX // {{{
	: OperandSX '?.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: true
			}, @1, @3);
		}
	| OperandSX '?[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: true
			}, @1, @4);
		}
	| OperandSX '.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| OperandSX '[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| OperandSX '?' '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $4,
				nullable: true
			}, @1, @5);
		}
	| OperandSX '?'
		{
			$$ = location({
				kind: NodeKind.UnaryExpression,
				operator: location({
					kind: UnaryOperatorKind.Existential
				}, @2),
				argument: $1
			}, @1, @2);
		}
	| OperandSX '^^(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX '^$(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX '^@(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX '**(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.Null
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX '*$(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX '::' Identifier
		{
			$$ = location({
				kind: NodeKind.EnumExpression,
				enum: $1,
				member: $3
			}, @1, @3);
		}
	| OperandSX ':' Identifier
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				left: $1,
				right: location({
					kind: NodeKind.TypeReference,
					typeName: $3
				}, @3),
				operator: location({
					kind: BinaryOperatorKind.TypeCasting
				}, @2)
			}, @1, @3);
		}
	| OperandElement
	;
// }}}

OperandElement // {{{
	: Array
	| CreateExpression
	| Identifier
	| Number
	| Object
	| Parenthesis
	| RegularExpression
	| String
	| TemplateExpression
	| ThisExpression
	;
// }}}

OperandOrType // {{{
	: Operand TypeOperator TypeEntity
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				left: $1,
				right: $3,
				operator: $2
			}, @1, @3);
		}
	| Operand
	;
// }}}

Operand_NoAnonymousFunction // {{{
	: PrefixUnaryOperatorKind Operand_NoAnonymousFunction
		{
			if($1.kind === UnaryOperatorKind.Negative && $2.kind === NodeKind.NumericExpression) {
				$2.value = -$2.value;
				$$ = location($2, @1, @2);
			}
			else {
				$$ = location({
					kind: NodeKind.UnaryExpression,
					operator: $1,
					argument: $2
				}, @1, @2);
			}
		}
	| Operand_NoAnonymousFunction PostfixUnaryOperatorKind
		{
			$$ = location({
				kind: NodeKind.UnaryExpression,
				operator: $2,
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoAnonymousFunction
	;
// }}}

OperandSX_NoAnonymousFunction // {{{
	: OperandSX_NoAnonymousFunction '?.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: true
			}, @1, @3);
		}
	| OperandSX_NoAnonymousFunction '?[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: true
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| OperandSX_NoAnonymousFunction '[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '?' '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $4,
				nullable: true
			}, @1, @5);
		}
	| OperandSX_NoAnonymousFunction '?'
		{
			$$ = location({
				kind: NodeKind.UnaryExpression,
				operator: location({
					kind: UnaryOperatorKind.Existential
				}, @2),
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoAnonymousFunction '^^(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '^$(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '^@(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '**(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '*$(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '::' Identifier
		{
			$$ = location({
				kind: NodeKind.EnumExpression,
				enum: $1,
				member: $3
			}, @1, @3);
		}
	| OperandSX_NoAnonymousFunction ':' Identifier
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				left: $1,
				right: location({
					kind: NodeKind.TypeReference,
					typeName: $3
				}, @3),
				operator: location({
					kind: BinaryOperatorKind.TypeCasting
				}, @2)
			}, @1, @3);
		}
	| OperandElement_NoAnonymousFunction
	;
// }}}

OperandElement_NoAnonymousFunction // {{{
	: Array
	| CreateExpression
	| Identifier
	| Number
	| Object
	| Parenthesis_NoAnonymousFunction
	| RegularExpression
	| String
	| TemplateExpression
	| ThisExpression
	;
// }}}

OperandOrType_NoAnonymousFunction // {{{
	: Operand_NoAnonymousFunction TypeOperator TypeEntity
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				left: $1,
				right: $3,
				operator: $2
			}, @1, @3);
		}
	| Operand_NoAnonymousFunction
	;
// }}}

Operand_NoObject // {{{
	: PrefixUnaryOperatorKind Operand_NoObject
		{
			if($1.kind === UnaryOperatorKind.Negative && $2.kind === NodeKind.NumericExpression) {
				$2.value = -$2.value;
				$$ = location($2, @1, @2);
			}
			else {
				$$ = location({
					kind: NodeKind.UnaryExpression,
					operator: $1,
					argument: $2
				}, @1, @2);
			}
		}
	| Operand_NoObject PostfixUnaryOperatorKind
		{
			$$ = location({
				kind: NodeKind.UnaryExpression,
				operator: $2,
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoObject
	;
// }}}

OperandSX_NoObject // {{{
	: OperandSX_NoObject '?.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: true
			}, @1, @3);
		}
	| OperandSX_NoObject '?[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: true
			}, @1, @4);
		}
	| OperandSX_NoObject '.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| OperandSX_NoObject '?' '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $4,
				nullable: true
			}, @1, @5);
		}
	| OperandSX_NoObject '?'
		{
			$$ = location({
				kind: NodeKind.UnaryExpression,
				operator: location({
					kind: UnaryOperatorKind.Existential
				}, @2),
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoObject '[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoObject '^^(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '^$(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '^@(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '**(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '*$(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '::' Identifier
		{
			$$ = location({
				kind: NodeKind.EnumExpression,
				enum: $1,
				member: $3
			}, @1, @3);
		}
	| OperandSX_NoObject ':' Identifier
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				left: $1,
				right: location({
					kind: NodeKind.TypeReference,
					typeName: $3
				}, @3),
				operator: location({
					kind: BinaryOperatorKind.TypeCasting
				}, @2)
			}, @1, @3);
		}
	| OperandElement_NoObject
	;
// }}}

OperandElement_NoObject // {{{
	: Array
	| CreateExpression
	| Identifier
	| Number
	| Parenthesis
	| RegularExpression
	| String
	| TemplateExpression
	| ThisExpression
	;
// }}}

OperandOrType_NoObject // {{{
	: Operand_NoObject TypeOperator TypeEntity
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				left: $1,
				right: $3,
				operator: $2
			}, @1, @3);
		}
	| Operand_NoObject
	;
// }}}

Operand_NoWhereNoWith // {{{
	: PrefixUnaryOperatorKind Operand_NoWhereNoWith
		{
			if($1.kind === UnaryOperatorKind.Negative && $2.kind === NodeKind.NumericExpression) {
				$2.value = -$2.value;
				$$ = location($2, @1, @2);
			}
			else {
				$$ = location({
					kind: NodeKind.UnaryExpression,
					operator: $1,
					argument: $2
				}, @1, @2);
			}
		}
	| Operand_NoWhereNoWith PostfixUnaryOperatorKind
		{
			$$ = location({
				kind: NodeKind.UnaryExpression,
				operator: $2,
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoWhereNoWith
	;
// }}}

OperandSX_NoWhereNoWith // {{{
	: OperandSX_NoWhereNoWith '?.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: true
			}, @1, @3);
		}
	| OperandSX_NoWhereNoWith '?[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: true
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| OperandSX_NoWhereNoWith '[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '?' '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $4,
				nullable: true
			}, @1, @5);
		}
	| OperandSX_NoWhereNoWith '?'
		{
			$$ = location({
				kind: NodeKind.UnaryExpression,
				operator: location({
					kind: UnaryOperatorKind.Existential
				}, @2),
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoWhereNoWith '^^(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '^$(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '^@(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CurryExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '**(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.Null
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '*$(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '(' Expression0CNList ')'
		{
			$$ = location({
				kind: NodeKind.CallExpression,
				scope: {
					kind: ScopeKind.This
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '::' Identifier
		{
			$$ = location({
				kind: NodeKind.EnumExpression,
				enum: $1,
				member: $3
			}, @1, @3);
		}
	| OperandSX_NoWhereNoWith ':' Identifier
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				left: $1,
				right: location({
					kind: NodeKind.TypeReference,
					typeName: $3
				}, @3),
				operator: location({
					kind: BinaryOperatorKind.TypeCasting
				}, @2)
			}, @1, @3);
		}
	| OperandElement_NoWhereNoWith
	;
// }}}

OperandElement_NoWhereNoWith // {{{
	: Array
	| CreateExpression
	| Identifier_NoWhereNoWith
	| Number
	| Object
	| Parenthesis
	| RegularExpression
	| String
	| TemplateExpression
	| ThisExpression
	;
// }}}

Parenthesis // {{{
	: '(' Expression ')'
		{
			$$ = $2;
		}
	| '(' Expression ',' Expression1CList ')'
		{
			$4.unshift($2);
			
			$$ = location({
				kind: NodeKind.SequenceExpression,
				expressions: $4
			}, @2, @4);
		}
	| '(' Identifier ')'
		{
			$$ = $2;
		}
	| '(' Identifier '=' Expression ')'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality
				}, @3),
				left: $2,
				right: $4
			}, @2, @4);
		}
	| '(' Identifier '=' Expression ',' Expression1CList ')'
		{
			$6.unshift(location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality
				}, @3),
				left: $2,
				right: $4
			}, @2, @4));
			
			$$ = location({
				kind: NodeKind.SequenceExpression,
				expressions: $6
			}, @2, @6);
		}
	| '(' Identifier 'SPACED_?' Expression 'SPACED_:' Expression ')'
		{
			$$ = location({
				kind: NodeKind.ConditionalExpression,
				condition: $2,
				whenTrue: $4,
				whenFalse: $6
			}, @2, @6);
		}
	| '(' Identifier ')' LambdaBody
		{
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: [],
				parameters: [location({
					kind: NodeKind.Parameter,
					modifiers: [],
					name: $2
				}, @2)],
				body: $4
			}, @1, @4);
		}
	| '(' Identifier '=' Expression ')' LambdaBody
		{
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: [],
				parameters: [location({
					kind: NodeKind.Parameter,
					modifiers: [],
					name: $2,
					defaultValue: $4
				}, @2, @4)],
				body: $6
			}, @1, @6);
		}
	| '(' Identifier '=' Expression ',' FunctionParameterList ')' LambdaBody
		{
			$6.unshift(location({
				kind: NodeKind.Parameter,
				modifiers: [],
				name: $2,
				defaultValue: $4
			}, @2, @4));
			
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: [],
				parameters: $6,
				body: $8
			}, @1, @8);
		}
	| '(' NL_0M Expression NL_0M ')'
		{
			$$ = $3;
		}
	| '(' NL_0M Expression ',' Expression1CList NL_0M ')'
		{
			$5.unshift($3);
			
			$$ = location({
				kind: NodeKind.SequenceExpression,
				expressions: $5
			}, @3, @5);
		}
	| '(' NL_0M Identifier NL_0M ')'
		{
			$$ = $3;
		}
	| '(' NL_0M Identifier '=' Expression NL_0M ')'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality
				}, @4),
				left: $3,
				right: $5
			}, @3, @5);
		}
	| '(' NL_0M Identifier '=' Expression ',' Expression1CList NL_0M ')'
		{
			$7.unshift(location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality
				}, @4),
				left: $3,
				right: $5
			}, @3, @5));
			
			$$ = location({
				kind: NodeKind.SequenceExpression,
				expressions: $7
			}, @3, @7);
		}
	| '(' NL_0M Identifier 'SPACED_?' Expression 'SPACED_:' Expression NL_0M ')'
		{
			$$ = location({
				kind: NodeKind.ConditionalExpression,
				condition: $3,
				whenTrue: $5,
				whenFalse: $7
			}, @3, @7);
		}
	| '(' NL_0M Identifier NL_0M ')' LambdaBody
		{
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: [],
				parameters: [location({
					kind: NodeKind.Parameter,
					modifiers: [],
					name: $3
				}, @3)],
				body: $6
			}, @1, @6);
		}
	| '(' NL_0M Identifier '=' Expression NL_0M ')' LambdaBody
		{
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: [],
				parameters: [location({
					kind: NodeKind.Parameter,
					modifiers: [],
					name: $3,
					defaultValue: $5
				}, @3, @5)],
				body: $8
			}, @1, @8);
		}
	| '(' NL_0M Identifier '=' Expression ',' FunctionParameterList NL_0M ')' LambdaBody
		{
			$7.unshift(location({
				kind: NodeKind.Parameter,
				modifiers: [],
				name: $3,
				defaultValue: $5
			}, @3, @5));
			
			$$ = location({
				kind: NodeKind.LambdaExpression,
				modifiers: [],
				parameters: $7,
				body: $10
			}, @1, @10);
		}
	;
// }}}

Parenthesis_NoAnonymousFunction // {{{
	: '(' Expression ')'
		{
			$$ = $2;
		}
	| '(' Identifier '=' Expression ')'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality
				}, @3),
				left: $2,
				right: $4
			}, @2, @4);
		}
	| '(' Identifier ')'
		{
			$$ = $2;
		}
	| '(' Identifier 'SPACED_?' Expression 'SPACED_:' Expression ')'
		{
			$$ = location({
				kind: NodeKind.ConditionalExpression,
				condition: $2,
				whenTrue: $4,
				whenFalse: $6
			}, @2, @6);
		}
	| '(' NL_0M Expression NL_0M ')'
		{
			$$ = $3;
		}
	| '(' NL_0M Identifier '=' Expression NL_0M ')'
		{
			$$ = location({
				kind: NodeKind.BinaryExpression,
				operator: location({
					kind: BinaryOperatorKind.Assignment,
					assignment: AssignmentOperatorKind.Equality
				}, @4),
				left: $3,
				right: $5
			}, @3, @5);
		}
	| '(' NL_0M Identifier NL_0M ')'
		{
			$$ = $3;
		}
	| '(' NL_0M Identifier 'SPACED_?' Expression 'SPACED_:' Expression NL_0M ')'
		{
			$$ = location({
				kind: NodeKind.ConditionalExpression,
				condition: $3,
				whenTrue: $5,
				whenFalse: $7
			}, @3, @7);
		}
	;
// }}}

PostfixUnaryOperatorKind // {{{
	: '--'
		{
			$$ = location({
				kind: UnaryOperatorKind.DecrementPostfix
			}, @1);
		}
	| '++'
		{
			$$ = location({
				kind: UnaryOperatorKind.IncrementPostfix
			}, @1);
		}
	;
// }}}

PrefixUnaryOperatorKind // {{{
	: '--'
		{
			$$ = location({
				kind: UnaryOperatorKind.DecrementPrefix
			}, @1);
		}
	| '++'
		{
			$$ = location({
				kind: UnaryOperatorKind.IncrementPrefix
			}, @1);
		}
	| '!'
		{
			$$ = location({
				kind: UnaryOperatorKind.Negation
			}, @1);
		}
	| '?'
		{
			$$ = location({
				kind: UnaryOperatorKind.Existential
			}, @1);
		}
	| '-'
		{
			$$ = location({
				kind: UnaryOperatorKind.Negative
			}, @1);
		}
	| '...'
		{
			$$ = location({
				kind: UnaryOperatorKind.Spread
			}, @1);
		}
	| '~'
		{
			$$ = location({
				kind: UnaryOperatorKind.BitwiseNot
			}, @1);
		}
	;
// }}}

Property // {{{
	: NameIST ColonSeparator TypeVar PropertyGetSet '=' Expression
		{
			$$ = location({
				kind: NodeKind.PropertyDeclaration,
				modifiers: [],
				name: $1,
				type: $3,
				defaultValue: $6
			}, @1, @6);
			
			if(!!$4.accessor) {
				$$.accessor = $4.accessor;
			}
			if(!!$4.mutator) {
				$$.mutator = $4.mutator;
			}
		}
	| NameIST ColonSeparator TypeVar PropertyGetSet
		{
			$$ = location({
				kind: NodeKind.PropertyDeclaration,
				modifiers: [],
				name: $1,
				type: $3
			}, @1, @4);
			
			if(!!$4.accessor) {
				$$.accessor = $4.accessor;
			}
			if(!!$4.mutator) {
				$$.mutator = $4.mutator;
			}
		}
	| NameIST PropertyGetSet '=' Expression
		{
			$$ = location({
				kind: NodeKind.PropertyDeclaration,
				modifiers: [],
				name: $1,
				defaultValue: $4
			}, @1, @4);
			
			if(!!$2.accessor) {
				$$.accessor = $2.accessor;
			}
			if(!!$2.mutator) {
				$$.mutator = $2.mutator;
			}
		}
	| NameIST PropertyGetSet
		{
			$$ = location({
				kind: NodeKind.PropertyDeclaration,
				modifiers: [],
				name: $1
			}, @1, @2);
			
			if(!!$2.accessor) {
				$$.accessor = $2.accessor;
			}
			if(!!$2.mutator) {
				$$.mutator = $2.mutator;
			}
		}
	;
// }}}

PropertyGetSet // {{{
	: '{' 'GET' ',' 'SET' '}'
		{
			$$ = {
				accessor: location({
					kind: NodeKind.AccessorDeclaration
				}, @2),
				mutator: location({
					kind: NodeKind.MutatorDeclaration
				}, @3)
			};
		}
	| '{' 'GET' '}'
		{
			$$ = {
				accessor: location({
					kind: NodeKind.AccessorDeclaration
				}, @2)
			};
		}
	| '{' 'SET' '}'
		{
			$$ = {
				mutator: location({
					kind: NodeKind.MutatorDeclaration
				}, @3)
			};
		}
	| '{' NL_1M PropertyGetter NL_1M PropertySetter NL_1M '}'
		{
			$$ = {
				accessor: $3,
				mutator: $5
			};
		}
	| '{' NL_1M PropertyGetter NL_1M '}'
		{
			$$ = {
				accessor: $3
			};
		}
	| '{' NL_1M PropertySetter NL_1M '}'
		{
			$$ = {
				mutator: $3
			};
		}
	;
// }}}

PropertyGetter // {{{
	: 'GET'
		{
			$$ = location({
				kind: NodeKind.AccessorDeclaration
			}, @1);
		}
	| 'GET' '=>' Expression
		{
			$$ = location({
				kind: NodeKind.AccessorDeclaration,
				body: $3
			}, @1, @3);
		}
	| 'GET' Block
		{
			$$ = location({
				kind: NodeKind.AccessorDeclaration,
				body: $2
			}, @1, @2);
		}
	;
// }}}

PropertySetter // {{{
	: 'SET'
		{
			$$ = location({
				kind: NodeKind.MutatorDeclaration
			}, @1);
		}
	| 'SET' '=>' Expression
		{
			$$ = location({
				kind: NodeKind.MutatorDeclaration,
				body: $3
			}, @1, @3);
		}
	| 'SET' Block
		{
			$$ = location({
				kind: NodeKind.MutatorDeclaration,
				body: $2
			}, @1, @2);
		}
	;
// }}}

RequireDeclaration // {{{
	: 'REQUIRE' ExternDeclaratorLL
		{
			$$ = location({
				kind: NodeKind.RequireDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'REQUIRE' ExternDeclaratorLB
		{
			$$ = location({
				kind: NodeKind.RequireDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

RequireOrExternDeclaration // {{{
	: 'REQUIRE|EXTERN' ExternDeclaratorLL
		{
			$$ = location({
				kind: NodeKind.RequireOrExternDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'REQUIRE|EXTERN' ExternDeclaratorLB
		{
			$$ = location({
				kind: NodeKind.RequireOrExternDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

RequireOrImportDeclaration // {{{
	: 'REQUIRE|IMPORT' ImportDeclarator
		{
			$$ = location({
				kind: NodeKind.RequireOrImportDeclaration,
				declarations: [$2]
			}, @1, @2);
		}
	| 'REQUIRE|IMPORT' ImportDeclaratorLB
		{
			$$ = location({
				kind: NodeKind.RequireOrImportDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

RegularExpression // {{{
	: RegularExpressionBegin 'REGEXP_LITERAL'
		{
			$$ = location({
				kind: NodeKind.RegularExpression,
				value: $1 + $2
			}, @1, @2);
		}
	;
// }}}

RegularExpressionBegin // {{{
	: '/'
		{
			yy.lexer.begin('regexp');
		}
	| '/='
		{
			yy.lexer.begin('regexp');
		}
	;
// }}}

ReturnStatement // {{{
	: 'RETURN' Expression 'IF' Expression 'ELSE' Expression
		{
			$$ = location({
				kind: NodeKind.ReturnStatement,
				value: location({
					kind: NodeKind.IfExpression,
					condition: $4,
					whenTrue: $2,
					whenFalse: $6
				}, @2, @6)
			}, @1, @6);
		}
	| 'RETURN' Expression 'IF' Expression
		{
			$$ = location({
				kind: NodeKind.IfStatement,
				condition: $4,
				whenTrue: location({
					kind: NodeKind.ReturnStatement,
					value: $2
				}, @1, @2)
			}, @1, @4);
		}
	| 'RETURN' Expression 'UNLESS' Expression
		{
			$$ = location({
				kind: NodeKind.UnlessStatement,
				condition: $4,
				whenFalse: location({
					kind: NodeKind.ReturnStatement,
					value: $2
				}, @1, @2)
			}, @1, @4);
		}
	| 'RETURN' Expression
		{
			$$ = location({
				kind: NodeKind.ReturnStatement,
				value: $2
			}, @1, @2);
		}
	| 'RETURN' 'IF' Expression
		{
			$$ = location({
				kind: NodeKind.IfStatement,
				condition: $3,
				whenTrue: location({
					kind: NodeKind.ReturnStatement
				}, @1)
			}, @1, @3);
		}
	| 'RETURN' 'UNLESS' Expression
		{
			$$ = location({
				kind: NodeKind.UnlessStatement,
				condition: $3,
				whenFalse: location({
					kind: NodeKind.ReturnStatement
				}, @1)
			}, @1, @3);
		}
	| 'RETURN'
		{
			$$ = location({
				kind: NodeKind.ReturnStatement
			}, @1);
		}
	;
// }}}

Statement // {{{
	: AssignmentDeclaration NL_EOF_1M
	| ConstDeclaration NL_EOF_1M
	| FunctionDeclaration NL_EOF_1M
	| EnumDeclaration NL_EOF_1M
	| LetDeclaration NL_EOF_1M
	| ReturnStatement NL_EOF_1M
	| IfStatement NL_EOF_1M IfStatementList NL_EOF_1M 'ELSE' Block NL_EOF_1M
		{
			$1.whenFalse = $3[0];
			
			for(var i = 0, l = $3.length - 1; i < l; i++) {
				$3[i].whenFalse = $3[i + 1];
			}
			
			$3[l].whenFalse = $6;
			
			$$ = location($1, @1, @6);
		}
	| IfStatement NL_EOF_1M IfStatementList NL_EOF_1M 'ELSE' NL_0M Block NL_EOF_1M
		{
			$1.whenFalse = $3[0];
			
			for(var i = 0, l = $3.length - 1; i < l; i++) {
				$3[i].whenFalse = $3[i + 1];
			}
			
			$3[l].whenFalse = $7;
			
			$$ = location($1, @1, @7);
		}
	| IfStatement NL_EOF_1M IfStatementList NL_EOF_1M
		{
			$1.whenFalse = $3[0];
			
			for(var i = 0, l = $3.length - 1; i < l; i++) {
				$3[i].whenFalse = $3[i + 1];
			}
			
			$$ = location($1, @1, @3);
		}
	| IfStatement NL_EOF_1M 'ELSE' Block NL_EOF_1M
		{
			$1.whenFalse = $4;
			$$ = location($1, @1, @4);
		}
	| IfStatement NL_EOF_1M
	| UnlessStatement NL_EOF_1M
	| ForStatement NL_EOF_1M
	| 'DO' Block NL_1M 'UNTIL' Expression NL_EOF_1M
		{
			$$ = location({
				kind: NodeKind.DoUntilStatement,
				condition: $5,
				body: $2
			}, @1, @5);
		}
	| 'DO' Block NL_1M 'WHILE' Expression NL_EOF_1M
		{
			$$ = location({
				kind: NodeKind.DoWhileStatement,
				condition: $5,
				body: $2
			}, @1, @5);
		}
	| 'DO' NL_1M Block NL_1M 'UNTIL' Expression NL_EOF_1M
		{
			$$ = location({
				kind: NodeKind.DoUntilStatement,
				condition: $6,
				body: $3
			}, @1, @6);
		}
	| 'DO' NL_1M Block NL_1M 'WHILE' Expression NL_EOF_1M
		{
			$$ = location({
				kind: NodeKind.DoWhileStatement,
				condition: $6,
				body: $3
			}, @1, @6);
		}
	| WhileStatement NL_EOF_1M
	| UntilStatement NL_EOF_1M
	| ThrowStatement NL_EOF_1M
	| TryStatement NL_EOF_1M CatchOnClauseList NL_EOF_1M CatchClause NL_1M FinallyClause NL_EOF_1M
		{
			$1.catchClauses = $3;
			$1.catchClause = $5;
			$1.finalizer = $7;
			$$ = location($1, @1, @7);
		}
	| TryStatement NL_EOF_1M CatchOnClauseList NL_EOF_1M CatchClause NL_EOF_1M
		{
			$1.catchClauses = $3;
			$1.catchClause = $5;
			$$ = location($1, @1, @5);
		}
	| TryStatement NL_EOF_1M CatchClause NL_EOF_1M FinallyClause NL_EOF_1M
		{
			$1.catchClauses = [];
			$1.catchClause = $3;
			$1.finalizer = $5;
			$$ = location($1, @1, @5);
		}
	| TryStatement NL_EOF_1M CatchClause NL_EOF_1M
		{
			$1.catchClauses = [];
			$1.catchClause = $3;
			$$ = location($1, @1, @3);
		}
	| TryStatement NL_EOF_1M CatchOnClauseList NL_EOF_1M FinallyClause NL_EOF_1M
		{
			$1.catchClauses = $3;
			$1.finalizer = $5;
			$$ = location($1, @1, @5);
		}
	| TryStatement NL_EOF_1M CatchOnClauseList NL_EOF_1M
		{
			$1.catchClauses = $3;
			$$ = location($1, @1, @3);
		}
	| TryStatement NL_EOF_1M FinallyClause NL_EOF_1M
		{
			$1.catchClauses = [];
			$1.finalizer = $3;
			$$ = location($1, @1, @3);
		}
	| TryStatement NL_EOF_1M
		{
			$1.catchClauses = [];
		}
	| ClassDeclaration NL_EOF_1M
	| ImplementDeclaration NL_EOF_1M
	| AwaitStatement NL_EOF_1M
	| 'BREAK' NL_EOF_1M
		{
			$$ = location({
				kind: NodeKind.BreakStatement
			}, @1);
		}
	| 'CONTINUE' NL_EOF_1M
		{
			$$ = location({
				kind: NodeKind.ContinueStatement
			}, @1);
		}
	| SwitchStatement NL_EOF_1M
	| TypeDeclaration NL_EOF_1M
	| DestroyStatement NL_EOF_1M
	| StatementExpression NL_EOF_1M
	| NamespaceDeclaration NL_EOF_1M
	;
// }}}

StatementExpression // {{{
	: Expression ForExpression
		{
			$2.body = $1;
			$$ = location($2, @1, @2);
		}
	| Expression 'IF' Expression
		{
			$$ = location({
				kind: NodeKind.IfStatement,
				condition: $3,
				whenTrue: $1
			}, @1, @3);
		}
	| Expression 'UNLESS' Expression
		{
			$$ = location({
				kind: NodeKind.UnlessStatement,
				condition: $3,
				whenFalse: $1
			}, @1, @3);
		}
	| Expression
	;
// }}}

String // {{{
	: 'STRING'
		{
			$$ = location({
				kind: NodeKind.Literal,
				value: $1
			}, @1);
		}
	;
// }}}

SwitchBinding // {{{
	: SwitchBinding ',' SwitchBindingValue
		{
			$1.push($3);
		}
	| SwitchBindingValue
		{
			$$ = [$1];
		}
	;
// }}}

SwitchBindingValue // {{{
	: SwitchBindingArray
	| SwitchBindingObject
	| Identifier 'AS' TypeVar
		{
			$$ = location({
				kind: NodeKind.SwitchTypeCasting,
				name: $1,
				type: $3
			}, @1, @3);
		}
	| Identifier
	;
// }}}

SwitchBindingArray // {{{
	: '[' SwitchBindingArrayOmitted SwitchBindingArrayList ']'
		{
			$$ = location({
				kind: NodeKind.ArrayBinding,
				elements: $2.concat($3)
			}, @1, @4)
		}
	| '[' SwitchBindingArrayList ']'
		{
			$$ = location({
				kind: NodeKind.ArrayBinding,
				elements: $2
			}, @1, @3)
		}
	;
// }}}

SwitchBindingArrayOmitted // {{{
	: SwitchBindingArrayOmitted ','
		{
			$1.push({
				kind: NodeKind.OmittedExpression
			});
		}
	| ','
		{
			$$ = [{
				kind: NodeKind.OmittedExpression
			}];
		}
	;
// }}}

SwitchBindingArrayList // {{{
	: SwitchBindingArrayList ',' '...' Identifier
		{
			$1.push(location({
				kind: NodeKind.BindingElement,
				name: $4,
				spread: true
			}, @3, @4));
		}
	| SwitchBindingArrayList ',' '...'
		{
			$1.push(location({
				kind: NodeKind.OmittedExpression,
				spread: true
			}, @3));
		}
	| SwitchBindingArrayList ',' Identifier
		{
			$1.push(location({
				kind: NodeKind.BindingElement,
				name: $3
			}, @3));
		}
	| SwitchBindingArrayList ','
		{
			$1.push({
				kind: NodeKind.OmittedExpression
			});
		}
	| '...' Identifier
		{
			$$ = [location({
				kind: NodeKind.BindingElement,
				name: $2,
				spread: true
			}, @1, @2)];
		}
	| '...'
		{
			$$ = [location({
				kind: NodeKind.OmittedExpression,
				spread: true
			}, @1)];
		}
	| Identifier
		{
			$$ = [location({
				kind: NodeKind.BindingElement,
				name: $1
			}, @1)];
		}
	;
// }}}

SwitchBindingObject // {{{
	: '{' SwitchBindingObjectList '}'
		{
			$$ = location({
				kind: NodeKind.ObjectBinding,
				elements: $2
			}, @1, @3)
		}
	;
// }}}

SwitchBindingObjectList // {{{
	: SwitchBindingObjectList ',' Identifier ColonSeparator Identifier
		{
			$1.push(location({
				kind: NodeKind.BindingElement,
				alias: $3,
				name: $5
			}, @3, @5));
		}
	| Identifier ColonSeparator Identifier
		{
			$$ = [location({
				kind: NodeKind.BindingElement,
				alias: $1,
				name: $3
			}, @1, @3)];
		}
	;
// }}}

SwitchCaseList // {{{
	: NL_0M '{' NL_0M SwitchCaseListPN '}'
		{
			$$ = $4;
		}
	;
// }}}

SwitchCaseListPN // {{{
	: SwitchCaseListPN SwitchCase
		{
			$1.push($2);
		}
	| SwitchCase
		{
			$$ = [$1];
		}
	;
// }}}

SwitchCase // {{{
	: SwitchCondition NL_0M 'WITH' SwitchBinding NL_0M 'WHERE' Expression NL_0M '=>' NL_0M SwitchCaseExpression NL_1M
		{
			$$ = location({
				kind: NodeKind.SwitchClause,
				conditions: $1,
				bindings: $4,
				filter: $7,
				body: $11
			}, @1, @11);
		}
	| SwitchCondition NL_0M 'WHERE' Expression NL_0M '=>' NL_0M SwitchCaseExpression NL_1M
		{
			$$ = location({
				kind: NodeKind.SwitchClause,
				conditions: $1,
				bindings: [],
				filter: $4,
				body: $8
			}, @1, @8);
		}
	| SwitchCondition NL_0M 'WITH' SwitchBinding NL_0M '=>' NL_0M SwitchCaseExpression NL_1M
		{
			$$ = location({
				kind: NodeKind.SwitchClause,
				conditions: $1,
				bindings: $4,
				body: $8
			}, @1, @8);
		}
	| SwitchCondition NL_0M '=>' NL_0M SwitchCaseExpression NL_1M
		{
			$$ = location({
				kind: NodeKind.SwitchClause,
				conditions: $1,
				bindings: [],
				body: $5
			}, @1, @5);
		}
	;
// }}}

SwitchCaseExpression // {{{
	: Block
	| ReturnStatement
	| ThrowStatement
	| Expression_NoObject
	;
// }}}

SwitchCondition // {{{
	: SwitchConditionList
	|
		{
			$$ = [];
		}
	;
// }}}

SwitchConditionList // {{{
	: SwitchConditionList ',' SwitchConditionArray
		{
			$1.push($3);
		}
	| SwitchConditionList ',' SwitchConditionObject
		{
			$1.push($3);
		}
	| SwitchConditionList ',' SwitchConditionSubtyping
		{
			$1.push($3);
		}
	| SwitchConditionList ',' SwitchConditionValue_NoWhereNoWith
		{
			$1.push($3);
		}
	| SwitchConditionArray
		{
			$$ = [$1];
		}
	| SwitchConditionObject
		{
			$$ = [$1];
		}
	| SwitchConditionSubtyping
		{
			$$ = [$1];
		}
	| SwitchConditionValue_NoWhereNoWith
		{
			$$ = [$1];
		}
	;
// }}}

SwitchConditionArray // {{{
	: '[' ',' SwitchConditionArrayItemList ']'
		{
			$$ = location({
				kind: NodeKind.SwitchConditionArray,
				values: [{
					kind: NodeKind.OmittedExpression
				}].concat($3)
			}, @1, @4);
		}
	| '[' SwitchConditionArrayItemList ']'
		{
			$$ = location({
				kind: NodeKind.SwitchConditionArray,
				values: $2
			}, @1, @3);
		}
	| '[' ',' ']'
		{
			$$ = location({
				kind: NodeKind.SwitchConditionArray,
				values: [{
					kind: NodeKind.OmittedExpression
				}, {
					kind: NodeKind.OmittedExpression
				}]
			}, @1, @3);
		}
	| '[' ']'
		{
			$$ = location({
				kind: NodeKind.SwitchConditionArray,
				values: []
			}, @1, @2);
		}
	;
// }}}

SwitchConditionArrayItemList // {{{
	: SwitchConditionArrayItemList ',' SwitchConditionValue
		{
			$1.push($3);
		}
	| SwitchConditionArrayItemList ',' '...'
		{
			$1.push(location({
				kind: NodeKind.OmittedExpression,
				spread: true
			}, @3));
		}
	| SwitchConditionArrayItemList ','
		{
			$1.push({
				kind: NodeKind.OmittedExpression
			});
		}
	| SwitchConditionValue
		{
			$$ = [$1];
		}
	| '...'
		{
			$$ = [location({
				kind: NodeKind.OmittedExpression,
				spread: true
			}, @1)];
		}
	;
// }}}

SwitchConditionObject // {{{
	: '{' SwitchConditionObjectItemList '}'
		{
			$$ = location({
				kind: NodeKind.SwitchConditionObject,
				members: $2
			}, @1, @3);
		}
	| '{' '}'
		{
			$$ = location({
				kind: NodeKind.SwitchConditionObject,
				members: []
			}, @1, @2);
		}
	;
// }}}

SwitchConditionObjectItemList // {{{
	: SwitchConditionObjectItemList ',' SwitchConditionObjectItem
		{
			$1.push($3);
		}
	| SwitchConditionObjectItem
		{
			$$ = [$1];
		}
	;
// }}}

SwitchConditionObjectItem // {{{
	: Identifier ColonSeparator SwitchConditionValue
		{
			$$ = location({
				kind: NodeKind.ObjectMember,
				name: $1,
				value: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: NodeKind.ObjectMember,
				name: $1
			}, @1);
		}
	;
// }}}

SwitchConditionValue // {{{
	: Operand '<' '..' '<' Operand
		{
			$$ = location({
				kind: NodeKind.SwitchConditionRange,
				then: $1,
				til: $5
			}, @1, @5);
		}
	| Operand '<' '..' Operand
		{
			$$ = location({
				kind: NodeKind.SwitchConditionRange,
				then: $1,
				to: $4
			}, @1, @4);
		}
	| Operand '..' '<' Operand
		{
			$$ = location({
				kind: NodeKind.SwitchConditionRange,
				from: $1,
				til: $4
			}, @1, @4);
		}
	| Operand '..' Operand
		{
			$$ = location({
				kind: NodeKind.SwitchConditionRange,
				from: $1,
				to: $3
			}, @1, @3);
		}
	| ColonSeparator Identifier
		{
			$$ = location({
				kind: NodeKind.SwitchConditionEnum,
				name: $2
			}, @1, @2);
		}
	| Operand
	;
// }}}

SwitchConditionValue_NoWhereNoWith // {{{
	: Operand_NoWhereNoWith '<' '..' '<' Operand_NoWhereNoWith
		{
			$$ = location({
				kind: NodeKind.SwitchConditionRange,
				then: $1,
				til: $5
			}, @1, @5);
		}
	| Operand_NoWhereNoWith '<' '..' Operand_NoWhereNoWith
		{
			$$ = location({
				kind: NodeKind.SwitchConditionRange,
				then: $1,
				to: $4
			}, @1, @4);
		}
	| Operand_NoWhereNoWith '..' '<' Operand_NoWhereNoWith
		{
			$$ = location({
				kind: NodeKind.SwitchConditionRange,
				from: $1,
				til: $4
			}, @1, @4);
		}
	| Operand_NoWhereNoWith '..' Operand_NoWhereNoWith
		{
			$$ = location({
				kind: NodeKind.SwitchConditionRange,
				from: $1,
				to: $3
			}, @1, @3);
		}
	| ColonSeparator Identifier
		{
			$$ = location({
				kind: NodeKind.SwitchConditionEnum,
				name: $2
			}, @1, @2);
		}
	| Operand_NoWhereNoWith
	;
// }}}

SwitchConditionSubtyping // {{{
	: 'IS' TypeVar
		{
			$$ = location({
				kind: NodeKind.SwitchConditionType,
				type: $2
			}, @1, @2);
		}
	;
// }}}

SwitchExpression // {{{
	: 'SWITCH' ExpressionFlow SwitchCaseList
		{
			$$ = location({
				kind: NodeKind.SwitchExpression,
				expression: $2,
				clauses: $3
			}, @1, @3);
		}
	;
// }}}

SwitchStatement // {{{
	: 'SWITCH' ExpressionFlow SwitchCaseList
		{
			$$ = location({
				kind: NodeKind.SwitchStatement,
				expression: $2,
				clauses: $3
			}, @1, @3);
		}
	;
// }}}

TemplateExpression // {{{
	: 'TEMPLATE_BEGIN' TemplateValues 'TEMPLATE_END'
		{
			$$ = location({
				kind: NodeKind.TemplateExpression,
				elements: $2
			}, @1, @3);
		}
	;
// }}}

TemplateValues // {{{
	: TemplateValues 'TEMPLATE_VALUE'
		{
			$1.push(location({
				kind: NodeKind.Literal,
				value: $2
			}, @2));
			$$ = $1;
		}
	| TemplateValues '\(' Expression ')'
		{
			$1.push($3);
			$$ = $1;
		}
	| 'TEMPLATE_VALUE'
		{
			$$ = [location({
				kind: NodeKind.Literal,
				value: $1
			}, @1)];
		}
	| '\(' Expression ')'
		{
			$$ = [$2];
		}
	;
// }}}

ThisExpression // {{{
	: '@' Identifier
		{
			$$ = location({
				kind: NodeKind.ThisExpression,
				name: $2
			}, @1, @2);
		}
	;
// }}}

ThrowStatement // {{{
	: 'THROW' Expression 'IF' Expression
		{
			$$ = location({
				kind: NodeKind.IfStatement,
				condition: $4,
				whenTrue: location({
					kind: NodeKind.ThrowStatement,
					value: $2
				}, @1, @2)
			}, @1, @4);
		}
	| 'THROW' Expression 'UNLESS' Expression
		{
			$$ = location({
				kind: NodeKind.UnlessStatement,
				condition: $4,
				whenFalse: location({
					kind: NodeKind.ThrowStatement,
					value: $2
				}, @1, @2)
			}, @1, @4);
		}
	| 'THROW' Expression
		{
			$$ = location({
				kind: NodeKind.ThrowStatement,
				value: $2
			}, @1, @2);
		}
	| 'THROW' 'IF' Expression
		{
			$$ = location({
				kind: NodeKind.IfStatement,
				condition: $3,
				whenTrue: location({
					kind: NodeKind.ThrowStatement
				}, @1)
			}, @1, @3);
		}
	| 'THROW' 'UNLESS' Expression
		{
			$$ = location({
				kind: NodeKind.UnlessStatement,
				condition: $3,
				whenFalse: location({
					kind: NodeKind.ThrowStatement
				}, @1)
			}, @1, @3);
		}
	| 'THROW'
		{
			$$ = location({
				kind: NodeKind.ThrowStatement
			}, @1);
		}
	;
// }}}

TryStatement // {{{
	: 'TRY' Block
		{
			$$ = location({
				kind: NodeKind.TryStatement,
				body: $2
			}, @1, @2);
		}
	| 'TRY' NL_1M Block
		{
			$$ = location({
				kind: NodeKind.TryStatement,
				body: $3
			}, @1, @3);
		}
	;
// }}}

TypeArray // {{{
	: '[' TypeVarList ']'
		{
			$$ = location({
				kind: NodeKind.TypeReference,
				typeName: {
					kind: NodeKind.Identifier,
					name: 'array'
				},
				typeParameters: $2
			}, @1, @3);
		}
	;
// }}}

TypeEntity // {{{
	: TypeEntitySX '?'
		{
			$$ = location($1, @2);
			$$.nullable = true;
		}
	| TypeEntitySX
	;
// }}}

TypeEntityList // {{{
	: TypeEntityList '|' TypeEntity
		{
			if($1.type === NodeKind.UnionType) {
				$1.types.push($3);
				$$ = location($1, @3);
			}
			else {
				$$ = location({
					kind: NodeKind.UnionType,
					types: [$1, $3]
				}, @1, @3)
			}
		}
	| TypeEntity
		{
			$$ = $1
		}
	;
// }}}

TypeEntitySX // {{{
	: TypeName TypeGeneric
		{
			$$ = location({
				kind: NodeKind.TypeReference,
				typeName: $1,
				typeParameters: $2
			}, @1, @2);
		}
	| TypeName
		{
			$$ = location({
				kind: NodeKind.TypeReference,
				typeName: $1
			}, @1);
		}
	;
// }}}

TypeName // {{{
	: TypeName '.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| Identifier
	;
// }}}

TypeGeneric // {{{
	: '<' TypeGenericList '>'
		{
			$$ = $2;
		}
	;
// }}}

TypeGenericList // {{{
	: TypeGenericList ',' TypeEntity
		{
			$1.push($3);
			$$ = $1;
		}
	| TypeEntity
		{
			$$ = [$1];
		}
	;
// }}}

TypeObject // {{{
	: TypePropertyList
		{
			$$ = location({
				kind: NodeKind.TypeReference,
				typeName: {
					kind: NodeKind.Identifier,
					name: 'object'
				},
				properties: $1
			}, @1);
		}
	;
// }}}

TypeOperator // {{{
	: 'AS'
		{
			$$ = location({
				kind: BinaryOperatorKind.TypeCasting
			}, @1);
		}
	| 'IS'
		{
			$$ = location({
				kind: BinaryOperatorKind.TypeEquality
			}, @1);
		}
	| 'IS_NOT'
		{
			$$ = location({
				kind: BinaryOperatorKind.TypeInequality
			}, @1);
		}
	;
// }}}

TypeProperty // {{{
	: Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: NodeKind.ObjectMember,
				name: $1,
				type: $3
			}, @1, @3);
		}
	| Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionReturns
		{
			$$ = location({
				kind: NodeKind.ObjectMember,
				name: $1,
				type: {
					kind: NodeKind.FunctionExpression,
					parameters: $3,
					modifiers: $5,
					type: $6
				}
			}, @1, @6);
		}
	| Identifier '(' FunctionParameterList ')' FunctionModifiers
		{
			$$ = location({
				kind: NodeKind.ObjectMember,
				name: $1,
				type: {
					kind: NodeKind.FunctionExpression,
					parameters: $3,
					modifiers: $5
				}
			}, @1, @5);
		}
	;
// }}}

TypePropertyList // {{{
	: '{' NL_0M TypePropertyListPN TypeProperty '}'
		{
			$3.push($4);
			$$ = $3;
		}
	| '{' NL_0M TypePropertyListPN '}'
		{
			$$ = $3;
		}
	| '{' NL_0M TypeProperty '}'
		{
			$$ = [$3];
		}
	| '{' NL_0M '}'
		{
			$$ = [];
		}
	;
// }}}

TypePropertyListPN // {{{
	: TypePropertyListPN TypePropertyListPNI
		{
			$1.push($2);
			$$ = $1;
		}
	| TypePropertyListPNI
		{
			$$ = [$1];
		}
	;
// }}}

TypePropertyListPNI // {{{
	: TypeProperty ',' NL_0M
	| TypeProperty NL_1M
	;
// }}}

TypeDeclaration // {{{
	: 'TYPE' Identifier '=' TypeVar
		{
			$$ = location({
				kind: NodeKind.TypeAliasDeclaration,
				name: $2,
				type: $4
			}, @1, @4)
		}
	;
// }}}

TypeVar // {{{
	: TypeArray
	| TypeObject
	| TypeEntityList
	;
// }}}

TypeVarList // {{{
	: TypeVarList ',' TypeVar
		{
			$1.push($3);
			$$ = $1;
		}
	| TypeVar
		{
			$$ = [$1];
		}
	;
// }}}

TypedIdentifier // {{{
	: Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: NodeKind.VariableDeclarator,
				name: $1,
				type: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: NodeKind.VariableDeclarator,
				name: $1
			}, @1, @1);
		}
	;
// }}}

TypedIdentifierListX // {{{
	: TypedIdentifierListX ',' Identifier ColonSeparator TypeVar
		{
			$1.push(location({
				kind: NodeKind.VariableDeclarator,
				name: $3,
				type: $5
			}, @3, @5));
			
			$$ = $1;
		}
	| TypedIdentifierListX ',' Identifier
		{
			$1.push(location({
				kind: NodeKind.VariableDeclarator,
				name: $3
			}, @3, @3));
			
			$$ = $1;
		}
	| Identifier ColonSeparator TypeVar
		{
			$$ = [location({
				kind: NodeKind.VariableDeclarator,
				name: $1,
				type: $3
			}, @1, @3)];
		}
	| Identifier
		{
			$$ = [location({
				kind: NodeKind.VariableDeclarator,
				name: $1
			}, @1, @1)];
		}
	;
// }}}

TypedVariable // {{{
	: DestructuringArray
		{
			$$ = location({
				kind: NodeKind.VariableDeclarator,
				name: $1
			}, @1, @1);
		}
	| DestructuringObject
		{
			$$ = location({
				kind: NodeKind.VariableDeclarator,
				name: $1
			}, @1, @1);
		}
	| TypedIdentifier
	;
// }}}

TypedVariableList // {{{
	: TypedVariableList ',' TypedVariable
		{
			$1.push($3);
			
			$$ = $1;
		}
	| TypedVariable
		{
			$$ = [$1];
		}
	;
// }}}

TypedVariableListX // {{{
	: TypedVariableListX ',' DestructuringArray
		{
			$1.push(location({
				kind: NodeKind.VariableDeclarator,
				name: $3
			}, @3, @3));
			
			$$ = $1;
		}
	| TypedVariableListX ',' DestructuringObject
		{
			$1.push(location({
				kind: NodeKind.VariableDeclarator,
				name: $3
			}, @3, @3));
			
			$$ = $1;
		}
	| TypedVariableListX ',' TypedIdentifier
		{
			$1.push($3);
			
			$$ = $1;
		}
	| DestructuringArray
		{
			$$ = [location({
				kind: NodeKind.VariableDeclarator,
				name: $1
			}, @1, @1)];
		}
	| DestructuringObject
		{
			$$ = [location({
				kind: NodeKind.VariableDeclarator,
				name: $1
			}, @1, @1)];
		}
	| TypedIdentifier
		{
			$$ = [$1];
		}
	;
// }}}

UnlessStatement // {{{
	: 'UNLESS' Expression Block
		{
			$$ = location({
				kind: NodeKind.UnlessStatement,
				condition: $2,
				whenFalse: $3
			}, @1, @3);
		}
	;
// }}}

UntilStatement // {{{
	: 'UNTIL' Expression Block
		{
			$$ = location({
				kind: NodeKind.UntilStatement,
				condition: $2,
				body: $3
			}, @1, @3);
		}
	| 'UNTIL' Expression '=>' Expression
		{
			$$ = location({
				kind: NodeKind.UntilStatement,
				condition: $2,
				body: $4
			}, @1, @4);
		}
	;
// }}}

VariableCondition // {{{
	: 'IF' Expression 'ELSE' Expression
		{
			$$ = location({
				kind: NodeKind.IfExpression,
				condition: $2,
				whenFalse: $4
			}, @1, @4)
		}
	| 'IF' Expression
		{
			$$ = location({
				kind: NodeKind.IfExpression,
				condition: $2
			}, @1, @2)
		}
	| 'UNLESS' Expression
		{
			$$ = location({
				kind: NodeKind.UnlessExpression,
				condition: $2
			}, @1, @2)
		}
	|
	;
// }}}

VariableEquals // {{{
	: ':='
		{
			$$ = true
		}
	| '='
		{
			$$ = false
		}
	;
// }}}

VariableIdentifier // {{{
	: Identifier
	| DestructuringArray
		{
			$$ = location({
				kind: NodeKind.ArrayBinding,
				elements: $1
			}, @1);
		}
	| DestructuringObject
		{
			$$ = location({
				kind: NodeKind.ObjectBinding,
				elements: $1
			}, @1);
		}
	;
// }}}

VariableIdentifierList // {{{
	: VariableIdentifierList ',' VariableIdentifier
		{
			$1.push($3);
		}
	| VariableIdentifier
		{
			$$ = [$1];
		}
	;
// }}}

VariableName // {{{
	: VariableName '.' Identifier
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| VariableName '[' Expression ']'
		{
			$$ = location({
				kind: NodeKind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| Identifier
	;
// }}}

VisibilityModifier // {{{
	: 'PRIVATE'
		{
			$$ = location({
				kind: ModifierKind.Private
			}, @1);
		}
	| 'PROTECTED'
		{
			$$ = location({
				kind: ModifierKind.Protected
			}, @1);
		}
	| 'PUBLIC'
		{
			$$ = location({
				kind: ModifierKind.Public
			}, @1);
		}
	;
// }}}

WhileStatement // {{{
	: 'WHILE' Expression Block
		{
			$$ = location({
				kind: NodeKind.WhileStatement,
				condition: $2,
				body: $3
			}, @1, @3);
		}
	| 'WHILE' Expression '=>' Expression
		{
			$$ = location({
				kind: NodeKind.WhileStatement,
				condition: $2,
				body: $4
			}, @1, @4);
		}
	;
// }}}

%%

var enums = require('@kaoscript/ast')();
var AssignmentOperatorKind = enums.AssignmentOperatorKind;
var BinaryOperatorKind = enums.BinaryOperatorKind;
var ModifierKind = enums.ModifierKind;
var NodeKind = enums.NodeKind;
var ScopeKind = enums.ScopeKind;
var UnaryOperatorKind = enums.UnaryOperatorKind;

var $polyadic = {};
$polyadic[BinaryOperatorKind.Addition] = true;
$polyadic[BinaryOperatorKind.And] = true;
$polyadic[BinaryOperatorKind.Assignment] = false;
$polyadic[BinaryOperatorKind.BitwiseAnd] = true;
$polyadic[BinaryOperatorKind.BitwiseLeftShift] = true;
$polyadic[BinaryOperatorKind.BitwiseOr] = true;
$polyadic[BinaryOperatorKind.BitwiseRightShift] = true;
$polyadic[BinaryOperatorKind.BitwiseXor] = true;
$polyadic[BinaryOperatorKind.Division] = true;
$polyadic[BinaryOperatorKind.Equality] = true;
$polyadic[BinaryOperatorKind.GreaterThan] = true;
$polyadic[BinaryOperatorKind.GreaterThanOrEqual] = true;
$polyadic[BinaryOperatorKind.Inequality] = false;
$polyadic[BinaryOperatorKind.LessThan] = true;
$polyadic[BinaryOperatorKind.LessThanOrEqual] = true;
$polyadic[BinaryOperatorKind.Modulo] = true;
$polyadic[BinaryOperatorKind.Multiplication] = true;
$polyadic[BinaryOperatorKind.NullCoalescing] = true;
$polyadic[BinaryOperatorKind.Or] = true;
$polyadic[BinaryOperatorKind.Subtraction] = true;
$polyadic[BinaryOperatorKind.TypeCasting] = false;
$polyadic[BinaryOperatorKind.TypeEquality] = false;
$polyadic[BinaryOperatorKind.TypeInequality] = false;

var $precedence = {};
$precedence[BinaryOperatorKind.Addition] = 13;
$precedence[BinaryOperatorKind.And] = 6;
$precedence[BinaryOperatorKind.Assignment] = 3;
$precedence[BinaryOperatorKind.BitwiseAnd] = 11;
$precedence[BinaryOperatorKind.BitwiseLeftShift] = 12;
$precedence[BinaryOperatorKind.BitwiseOr] = 9;
$precedence[BinaryOperatorKind.BitwiseRightShift] = 12;
$precedence[BinaryOperatorKind.BitwiseXor] = 10;
$precedence[BinaryOperatorKind.Division] = 14;
$precedence[BinaryOperatorKind.Equality] = 7;
$precedence[BinaryOperatorKind.GreaterThan] = 8;
$precedence[BinaryOperatorKind.GreaterThanOrEqual] = 8;
$precedence[BinaryOperatorKind.Inequality] = 7;
$precedence[BinaryOperatorKind.LessThan] = 8;
$precedence[BinaryOperatorKind.LessThanOrEqual] = 8;
$precedence[BinaryOperatorKind.Modulo] = 14;
$precedence[BinaryOperatorKind.Multiplication] = 14;
$precedence[BinaryOperatorKind.NullCoalescing] = 15;
$precedence[BinaryOperatorKind.Or] = 5;
$precedence[BinaryOperatorKind.Subtraction] = 15;
$precedence[BinaryOperatorKind.TypeCasting] = 8;
$precedence[BinaryOperatorKind.TypeEquality] = 8;
$precedence[BinaryOperatorKind.TypeInequality] = 8;

function location(descriptor, firstToken, lastToken) { // {{{
	if(lastToken) {
		descriptor.start = {
			line: firstToken.first_line,
			column: firstToken.first_column + 1
		};
		
		descriptor.end = {
			line: lastToken.last_line,
			column: lastToken.last_column + 1
		};
	}
	else {
		if(!descriptor.start) {
			descriptor.start = {
				line: firstToken.first_line,
				column: firstToken.first_column + 1
			};
		}
		
		descriptor.end = {
			line: firstToken.last_line,
			column: firstToken.last_column + 1
		};
	}
	
	return descriptor;
} // }}}

function reorderExpression(operations) { // {{{
	if(operations.length === 1) {
		return operations[0];
	}
	else {
		var precedences = {};
		var precedenceList = [];
		
		var precedence;
		for(var i = 1 ; i < operations.length; i += 2) {
			precedence = $precedence[operations[i].operator.kind];
			
			if(precedences[precedence]) {
				++precedences[precedence];
			}
			else {
				precedences[precedence] = 1;
			}
			
			precedenceList.push(precedence);
		}
		
		precedenceList = precedenceList.sort(function(a, b) {
			return b - a;
		});
		
		var count, k, operator, left;
		for(var i = 0; i < precedenceList.length; i++) {
			precedence = precedenceList[i];
			count = precedences[precedence];
			
			for(k = 1; count && k < operations.length; k += 2) {
				if($precedence[operations[k].operator.kind] === precedence) {
					--count;
					
					operator = operations[k];
					
					if(operator.kind === NodeKind.BinaryExpression) {
						left = operations[k - 1];
						
						if(left.kind === NodeKind.BinaryExpression && operator.operator.kind === left.operator.kind && $polyadic[operator.operator.kind]) {
							operator.kind = NodeKind.PolyadicExpression;
							operator.start = left.start;
							
							operator.operands = [left.left, left.right, operations[k + 1]];
						}
						else if(left.kind === NodeKind.PolyadicExpression && operator.operator.kind === left.operator.kind) {
							left.end = operator.end;
							
							left.operands.push(operations[k + 1]);
							
							operator = left;
						}
						else {
							operator.left = left;
							operator.right = operations[k + 1];
						}
					}
					else {
						operator.left = operations[k - 1];
						operator.right = operations[k + 1];
					}
					
					operations.splice(k - 1, 3, operator);
					
					k -= 2;
				}
			}
		}
		
		return operations[0];
	}
} // }}}

function setCondition(value, valPosition, condition, condPosition) { // {{{
	if(condition) {
		if(condition.kind === NodeKind.IfExpression) {
			condition.whenTrue = value;
			
			return location(condition, valPosition, condPosition);
		}
		else if(condition.kind === NodeKind.UnlessExpression) {
			condition.whenFalse = value;
			
			return location(condition, valPosition, condPosition);
		}
		else {
			throw new Error('Not supported ' + condition.kind);
		}
	}
	else {
		return value;
	}
} // }}}

parser.parseError = function(error, hash) { // {{{
	throw new Error('Unexpected \'' + hash.text.replace(/\n/g, '\\n') + '\' at line ' + hash.loc.last_line + ' and column ' + (hash.loc.last_column + 1));
}; // }}}