/**
 * parser.jison
 * Version 0.3.0
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

%x hcomment import mlcomment regexp resource inline_comment template
%%

<regexp>{RegularExpressionLiteral}				this.popState();return 'REGEXP_LITERAL'
<import>[\@\.\/\w]+								this.popState();return 'IMPORT_LITERAL'

\s+\?\s+										return 'SPACED_?'
\s+\:\s+										return 'SPACED_:'

[^\r\n\S]+										/* skip whitespace */
\s*\/\/[^\r\n]*									/* skip comment */
\s*'/*'											this.begin('mlcomment')
<mlcomment>'/*'									this.begin('mlcomment')
<mlcomment>'*/'									this.popState()
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
'if'											return 'IF'
'impl'											return 'IMPL'
'import'										return 'IMPORT'
'include once'									return 'INCLUDE_ONCE'
'include'										return 'INCLUDE'
'in'											return 'IN'
'is not'										return 'IS_NOT'
'is'											return 'IS'
'let'											return 'LET'
'new'											return 'NEW'
'of'											return 'OF'
'on'											return 'ON'
'private'										return 'PRIVATE'
'protected'										return 'PROTECTED'
'public'										return 'PUBLIC'
'require|extern'								return 'REQUIRE|EXTERN'
'require'										return 'REQUIRE'
'return'										return 'RETURN'
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
\r?\n											return 'NEWLINE'
[_$A-Za-z]\w*									return 'IDENTIFIER'
0b[0-1]+										return 'BINARY_NUMBER'
0o[0-8]+										return 'OCTAL_NUMBER'
0x[0-9a-fA-F]+									return 'HEX_NUMBER'
[0-9]+(?:\.[0-9]+)?								return 'DECIMAL_NUMBER'
\'([^\\']|\\.)*\'								yytext = strip(yytext.slice(1, -1), /\\'/g, '\'');return 'STRING'
\"([^\\"]|\\.)*\"								yytext = strip(yytext.slice(1, -1), /\\"/g, '"');return 'STRING'
\`((.|\n)*?[^\\]|)\`							yytext = yytext.slice(1, -1);return 'TEMPLATE'
\S+												return 'MODULE_NAME'
<<EOF>> 										return 'EOF'
. 												return 'INVALID'

/lex

%start Module

%%

Array // {{{
	: '[' NL_0M ArrayRange ']'
		{
			$$ = location($3, @1, @4);
		}
	| '[' NL_0M Expression ForHeader ']'
		{
			$$ = location({
				kind: Kind.ArrayComprehension,
				body: $3,
				loop: $4
			}, @1, @5);
		}
	| '[' NL_0M ArrayListPN Expression ']'
		{
			$3.push($4);
			
			$$ = location({
				kind: Kind.ArrayExpression,
				values: $3
			}, @1, @5);
		}
	| '[' NL_0M ArrayListPN ']'
		{
			$$ = location({
				kind: Kind.ArrayExpression,
				values: $3
			}, @1, @4);
		}
	| '[' NL_0M Expression ']'
		{
			$$ = location({
				kind: Kind.ArrayExpression,
				values: [$3]
			}, @1, @4);
		}
	| '[' NL_0M ']'
		{
			$$ = location({
				kind: Kind.ArrayExpression,
				values: []
			}, @1, @3);
		}
	;
// }}}

ArrayRange // {{{
	: Operand '<' '..' '<' Operand '..' Operand
		{
			$$ = location({
				kind: Kind.ArrayRange,
				then: $1,
				til: $5,
				by: $7
			}, @1, @7);
		}
	| Operand '<' '..' Operand '..' Operand
		{
			$$ = location({
				kind: Kind.ArrayRange,
				then: $1,
				to: $4,
				by: $6
			}, @1, @6);
		}
	| Operand '..' '<' Operand '..' Operand
		{
			$$ = location({
				kind: Kind.ArrayRange,
				from: $1,
				til: $4,
				by: $6
			}, @1, @6);
		}
	| Operand '..' Operand '..' Operand
		{
			$$ = location({
				kind: Kind.ArrayRange,
				from: $1,
				to: $3,
				by: $5
			}, @1, @5);
		}
	| Operand '<' '..' '<' Operand
		{
			$$ = location({
				kind: Kind.ArrayRange,
				then: $1,
				til: $5
			}, @1, @5);
		}
	| Operand '<' '..' Operand
		{
			$$ = location({
				kind: Kind.ArrayRange,
				then: $1,
				to: $4
			}, @1, @4);
		}
	| Operand '..' '<' Operand
		{
			$$ = location({
				kind: Kind.ArrayRange,
				from: $1,
				til: $4
			}, @1, @4);
		}
	| Operand '..' Operand
		{
			$$ = location({
				kind: Kind.ArrayRange,
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
				kind: Kind.IfExpression,
				condition: $3,
				then: $1.right,
				else: $5
			}, @2, @5);
			
			$$ = location($1, @1, @5)
		}
	| AssignmentDeclarator 'IF' Expression
		{
			$$ = location({
				kind: Kind.IfExpression,
				condition: $3,
				then: $1
			}, @1, @3);
		}
	| AssignmentDeclarator 'UNLESS' Expression
		{
			$$ = location({
				kind: Kind.UnlessExpression,
				condition: $3,
				then: $1
			}, @1, @3);
		}
	| AssignmentDeclarator
	;
// }}}

AssignmentDeclarator // {{{
	: VariableIdentifierList ':=' 'AWAIT' Operand
		{
			$$ = location({
				kind: Kind.AwaitExpression,
				variables: $1,
				operation: $4,
				autotype: true
			}, @1, @4);
		}
	| VariableIdentifier ':=' Expression
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Equality,
					autotype: true
				}, @1),
				left: $1,
				right: $3
			}, @1, @3);
		}
	| VariableIdentifierList '=' 'AWAIT' Operand
		{
			$$ = location({
				kind: Kind.AwaitExpression,
				variables: $1,
				operation: $4
			}, @1, @4);
		}
	| VariableIdentifier '=' Expression
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Equality
				}, @1),
				left: $1,
				right: $3
			}, @1, @3);
		}
	| Operand AssignmentOperator Expression
		{
			if($1.kind === Kind.BinaryOperator && $1.operator.kind !== BinaryOperator.Equality) {
				throw new Error('Unexpected character at line ' + $1.operator.start.line + ' and column ' + $1.operator.start.column)
			}
			
			$2.left = $1;
			$2.right = $3;
			
			$$ = location($2, @1, @3);
		}
	;
// }}}

AssignmentOperator // {{{
	: '+='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Addition
				}, @1)
			}, @1);
		}
	| '&='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.BitwiseAnd
				}, @1)
			}, @1);
		}
	| '<<='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.BitwiseLeftShift
				}, @1)
			}, @1);
		}
	| '|='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.BitwiseOr
				}, @1)
			}, @1);
		}
	| '>>='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.BitwiseRightShift
				}, @1)
			}, @1);
		}
	| '^='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.BitwiseXor
				}, @1)
			}, @1);
		}
	| '/='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Division
				}, @1)
			}, @1);
		}
	| '='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Equality
				}, @1)
			}, @1);
		}
	| '?='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Existential
				}, @1)
			}, @1);
		}
	| '%='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Modulo
				}, @1)
			}, @1);
		}
	| '*='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Multiplication
				}, @1)
			}, @1);
		}
	| '-='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Subtraction
				}, @1)
			}, @1);
		}
	| '??='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.NullCoalescing
				}, @1)
			}, @1);
		}
	;
// }}}

Attribute // {{{
	: '#[' AttributeMember ']'
		{
			$$ = location({
				kind: Kind.AttributeDeclaration,
				declaration: $2
			}, @2);
		}
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
				kind: Kind.AttributeExpression,
				name: $1,
				arguments: $3
			}, @1, @4);
		}
	| Identifier '=' String
		{
			$$ = location({
				kind: Kind.AttributeOperator,
				name: $1,
				value: $3
			}, @1, @3);
		}
	| Identifier
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

AttributeWithin // {{{
	: '#![' AttributeMember ']'
		{
			$$ = location({
				kind: Kind.AttributeDeclaration,
				declaration: $2
			}, @1, @3)
		}
	;
// }}}

BinaryOperator // {{{
	: '+'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Addition
				}, @1)
			}, @1);
		}
	| '-'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Subtraction
				}, @1)
			}, @1);
		}
	| '/'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Division
				}, @1)
			}, @1);
		}
	| '%'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Modulo
				}, @1)
			}, @1);
		}
	| '*'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Multiplication
				}, @1)
			}, @1);
		}
	| '>='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.GreaterThanOrEqual
				}, @1)
			}, @1);
		}
	| '>>'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.BitwiseRightShift
				}, @1)
			}, @1);
		}
	| '>'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.GreaterThan
				}, @1)
			}, @1);
		}
	| '<='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.LessThanOrEqual
				}, @1)
			}, @1);
		}
	| '<<'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.BitwiseLeftShift
				}, @1)
			}, @1);
		}
	| '<'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.LessThan
				}, @1)
			}, @1);
		}
	| '=='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Equality
				}, @1)
			}, @1);
		}
	| '!='
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Inequality
				}, @1)
			}, @1);
		}
	| '??'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.NullCoalescing
				}, @1)
			}, @1);
		}
	| '&&'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.And
				}, @1)
			}, @1);
		}
	| '||'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Or
				}, @1)
			}, @1);
		}
	| '&'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.BitwiseAnd
				}, @1)
			}, @1);
		}
	| '|'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.BitwiseOr
				}, @1)
			}, @1);
		}
	| '^'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.BitwiseXor
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
				kind: Kind.Block,
				attributes: [],
				statements: []
			};
		}
	;
// }}}

BlockAttribute // {{{
	: AttributeWithin NL_EOF_1
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
	: 'CATCH' Identifier Block
		{
			$$ = location({
				kind: Kind.CatchClause,
				binding: $2,
				body: $3
			}, @1, @3);
		}
	| 'CATCH' Block
		{
			$$ = location({
				kind: Kind.CatchClause,
				body: $2
			}, @1, @2);
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
	: 'ON' Identifier 'CATCH' Identifier Block
		{
			$$ = location({
				kind: Kind.CatchClause,
				type: $2,
				binding: $4,
				body: $5
			}, @1, @5);
		}
	| 'ON' Identifier Block
		{
			$$ = location({
				kind: Kind.CatchClause,
				type: $2,
				body: $3
			}, @1, @3);
		}
	;
// }}}

ClassDeclaration // {{{
	: 'SEALED' ClassDeclaration
		{
			$2.sealed = true;
			
			$$ = location($2, @1, @2);
		}
	| 'CLASS' Identifier TypeGeneric 'EXTENDS' Identifier '{' ClassMember '}'
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $2,
				extends: $5,
				members: $7
			}, @1, @8);
		}
	| 'CLASS' Identifier 'EXTENDS' Identifier '{' ClassMember '}'
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $2,
				extends: $4,
				members: $6
			}, @1, @7);
		}
	| 'CLASS' Identifier TypeGeneric '{' ClassMember '}'
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $2,
				members: $5
			}, @1, @6);
		}
	| 'CLASS' Identifier '{' ClassMember '}'
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $2,
				members: $4
			}, @1, @5);
		}
	;
// }}}

ClassField // {{{
	: NameIST ColonSeparator TypeVar '=' Expression
		{
			$$ = location({
				kind: Kind.FieldDeclaration,
				modifiers: [],
				name: $1,
				type: $3,
				defaultValue: $5
			}, @1, @5);
		}
	| NameIST ColonSeparator TypeVar
		{
			$$ = location({
				kind: Kind.FieldDeclaration,
				modifiers: [],
				name: $1,
				type: $3
			}, @1, @3);
		}
	| NameIST '=' Expression
		{
			$$ = location({
				kind: Kind.FieldDeclaration,
				modifiers: [],
				name: $1,
				defaultValue: $3
			}, @1, @3);
		}
	| NameIST
		{
			$$ = location({
				kind: Kind.FieldDeclaration,
				modifiers: [],
				name: $1
			}, @1);
		}
	;
// }}}

ClassMember // {{{
	: ClassMember ClassMemberModifier '{' ClassMemberList '}'
		{
			for(var i = 0; i < $4.length; i++) {
				$4[i].modifiers.push($2);
				
				$1.push($4[i]);
			}
			
			$$ = $1;
		}
	| ClassMember ClassMemberModifier ClassMemberSX
		{
			$3.modifiers.push($2);
			
			$1.push(location($3, @2, @3));
			
			$$ = $1;
		}
	| ClassMember ClassMemberSX
		{
			$1.push($2);
			$$ = $1;
		}
	| ClassMember NL_EOF_1M
	|
		{
			$$ = []
		}
	;
// }}}

ClassMemberList // {{{
	: ClassMemberList ClassMemberSX NL_EOF_1
		{
			$1.push($2);
			$$ = $1;
		}
	| ClassMemberList NL_EOF_1
	|
		{
			$$ = [];
		}
	;
// }}}

ClassMemberModifier // {{{
	: 'PRIVATE'
		{
			$$ = location({
				kind: MemberModifier.Private
			}, @1);
		}
	| 'PROTECTED'
		{
			$$ = location({
				kind: MemberModifier.Protected
			}, @1);
		}
	| 'PUBLIC'
		{
			$$ = location({
				kind: MemberModifier.Public
			}, @1);
		}
	| 'STATIC'
		{
			$$ = location({
				kind: MemberModifier.Static
			}, @1);
		}
	;
// }}}

ClassMemberSX // {{{
	: ClassField
	| Method
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
				kind: Kind.CreateExpression,
				class: $2,
				arguments: $4
			}, @1, @5);
		}
	| 'NEW' CreateClassName
		{
			$$ = location({
				kind: Kind.CreateExpression,
				class: $2,
				arguments: []
			}, @1, @2);
		}
	;
// }}}

DestroyExpression // {{{
	: 'DELETE' VariableName
		{
			$$ = location({
				kind: Kind.DestroyExpression,
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
				kind: Kind.BindingElement,
				name: $2,
				spread: true,
				defaultValue: $4
			}, @1, @4);
		}
	| VariableIdentifier '=' Expression
		{
			$$ = location({
				kind: Kind.BindingElement,
				name: $1,
				defaultValue: $3
			}, @1, @3);
		}
	| '...' Identifier
		{
			$$ = location({
				kind: Kind.BindingElement,
				name: $2,
				spread: true
			}, @1);
		}
	| VariableIdentifier
		{
			$$ = location({
				kind: Kind.BindingElement,
				name: $1
			}, @1);
		}
	| '...'
		{
			$$ = {
				kind: Kind.OmittedExpression,
				spread: true
			};
		}
	|
		{
			$$ = {
				kind: Kind.OmittedExpression
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
				kind: Kind.BindingElement,
				alias: $1,
				name: $3,
				defaultValue: $5
			}, @1, @5);
		}
	| DestructuringObjectItemAlias ColonSeparator VariableIdentifier
		{
			$$ = location({
				kind: Kind.BindingElement,
				alias: $1,
				name: $3
			}, @1, @3);
		}
	| DestructuringObjectItemAlias '=' Expression
		{
			$$ = location({
				kind: Kind.BindingElement,
				name: $1,
				defaultValue: $3
			}, @1, @3);
		}
	| DestructuringObjectItemAlias
		{
			$$ = location({
				kind: Kind.BindingElement,
				name: $1
			}, @1);
		}
	| VariableIdentifier
		{
			$$ = location({
				kind: Kind.BindingElement,
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

ElseStatement // {{{
	: 'ELSE' Block
		{
			$$ = location({
				kind: Kind.ElseStatement,
				body: $2
			}, @1, @2);
		}
	;
// }}}

ElseIfStatements // {{{
	: ElseIfStatements NL_EOF_1M 'ELSE' 'IF' Expression_NoAnonymousFunction Block
		{
			$1.push(location({
				kind: Kind.ElseIfStatement,
				condition: $5,
				body: $6
			}, @3, @6));
			
			$$ = $1;
		}
	| 'ELSE' 'IF' Expression_NoAnonymousFunction Block
		{
			$$ = [location({
				kind: Kind.ElseIfStatement,
				condition: $3,
				body: $4
			}, @1, @4)];
		}
	;
// }}}

EnumDeclaration // {{{
	: 'ENUM' Identifier '<' TypeEntity '>' EnumMemberList
		{
			$$ = location({
				kind: Kind.EnumDeclaration,
				name: $2,
				type: $4,
				members: $6
			}, @1, @6);
		}
	| 'ENUM' Identifier EnumMemberList
	{
			$$ = location({
				kind: Kind.EnumDeclaration,
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
				kind: Kind.EnumMember,
				name: $1,
				value: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: Kind.EnumMember,
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
				kind: Kind.ExportDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'EXPORT' ExportDeclaratorLB
		{
			$$ = location({
				kind: Kind.ExportDeclaration,
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
	: VariableDeclaration
	| FunctionDeclaration
	| ClassDeclaration
	| EnumDeclaration
	| TypeDeclaration
	| Identifier 'AS' Identifier
		{
			$$ = location({
				kind: Kind.ExportAlias,
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
				kind: Kind.ExternDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'EXTERN' ExternDeclaratorLB
		{
			$$ = location({
				kind: Kind.ExternDeclaration,
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
	| ExternVariable
	;
// }}}

ExternClass // {{{
	: 'SEALED' 'CLASS' Identifier TypeGeneric '{' ExternClassMember '}'
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $3,
				members: $6,
				sealed: true
			}, @1, @7);
		}
	| 'SEALED' 'CLASS' Identifier '{' ExternClassMember '}'
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $3,
				members: $5,
				sealed: true
			}, @1, @6);
		}
	| 'CLASS' Identifier TypeGeneric '{' ExternClassMember '}'
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $2,
				members: $5
			}, @1, @6);
		}
	| 'CLASS' Identifier '{' ExternClassMember '}'
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $2,
				members: $4
			}, @1, @5);
		}
	| 'SEALED' 'CLASS' Identifier TypeGeneric
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $3,
				members: [],
				sealed: true
			}, @1, @4);
		}
	| 'SEALED' 'CLASS' Identifier
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $3,
				members: [],
				sealed: true
			}, @1, @3);
		}
	| 'CLASS' Identifier TypeGeneric
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $2,
				members: []
			}, @1, @3);
		}
	| 'CLASS' Identifier
		{
			$$ = location({
				kind: Kind.ClassDeclaration,
				name: $2,
				members: []
			}, @1, @2);
		}
	;
// }}}

ExternClassMember // {{{
	: ExternClassMember ExternClassMemberModifier '{' ExternClassMemberList '}'
		{
			for(var i = 0; i < $4.length; i++) {
				$4[i].modifiers.push($2);
				
				$1.push($4[i]);
			}
			
			$$ = $1;
		}
	| ExternClassMember ExternClassMemberModifier ExternClassMemberSX NL_EOF_1
		{
			$3.modifiers.push($2);
			
			$1.push(location($3, @2, @3));
			
			$$ = $1;
		}
	| ExternClassMember ExternClassMemberSX NL_EOF_1
		{
			$1.push($2);
			$$ = $1;
		}
	| ExternClassMember NL_EOF_1
	|
		{
			$$ = []
		}
	;
// }}}

ExternClassMemberList // {{{
	: ExternClassMemberList ExternClassMemberSX NL_EOF_1
		{
			$1.push($2);
			$$ = $1;
		}
	| ExternClassMemberList NL_EOF_1
	|
		{
			$$ = [];
		}
	;
// }}}

ExternClassMemberModifier // {{{
	: 'PROTECTED'
		{
			$$ = location({
				kind: MemberModifier.Protected
			}, @1);
		}
	| 'PUBLIC'
		{
			$$ = location({
				kind: MemberModifier.Public
			}, @1);
		}
	| 'STATIC'
		{
			$$ = location({
				kind: MemberModifier.Static
			}, @1);
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
				kind: Kind.FieldDeclaration,
				modifiers: [],
				name: $1,
				type: $3
			}, @1, @3);
		}
	| NameIST
		{
			$$ = location({
				kind: Kind.FieldDeclaration,
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
				kind: Kind.FunctionDeclaration,
				modifiers: $5,
				name: $1,
				parameters: $3,
				type: $6
			}, @1, @6);
		}
	| Identifier '(' FunctionParameterList ')' FunctionModifiers
		{
			$$ = location({
				kind: Kind.FunctionDeclaration,
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
			$1.kind = Kind.MethodDeclaration;
			$1.modifiers = $2;
			$1.type = $3;
			$$ = location($1, @3);
		}
	| ExternMethodHeader FunctionModifiers
		{
			$1.kind = Kind.MethodDeclaration;
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

ExternOrRequireDeclaration // {{{
	: 'EXTERN|REQUIRE' ExternDeclaratorLL
		{
			$$ = location({
				kind: Kind.ExternOrRequireDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'EXTERN|REQUIRE' ExternDeclaratorLB
		{
			$$ = location({
				kind: Kind.ExternOrRequireDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

ExternVariable // {{{
	: 'SEALED' Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $2,
				type: $4,
				sealed: true
			}, @1, @4)
		}
	| 'SEALED' Identifier
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $2,
				sealed: true
			}, @1, @2)
		}
	| Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				type: $3
			}, @1, @3)
		}
	| Identifier
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
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
				kind: Kind.TernaryConditionalExpression,
				condition: reorderExpression($1),
				then: $3,
				else: $5
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
	: ExpressionFlowSX BinaryOperator OperandOrType
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| ExpressionFlowSX AssignmentOperator OperandOrType
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
				kind: Kind.TernaryConditionalExpression,
				condition: reorderExpression($1),
				then: $3,
				else: $5
			}, @1, @5);
		}
	| ExpressionFlowSX_NoAnonymousFunction
		{
			$$ = reorderExpression($1);
		}
	;
// }}}

ExpressionFlowSX_NoAnonymousFunction // {{{
	: ExpressionFlowSX_NoAnonymousFunction BinaryOperator OperandOrType_NoAnonymousFunction
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| ExpressionFlowSX_NoAnonymousFunction AssignmentOperator OperandOrType_NoAnonymousFunction
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
				kind: Kind.TernaryConditionalExpression,
				condition: reorderExpression($1),
				then: $3,
				else: $5
			}, @1, @5);
		}
	| ExpressionFlowSX_NoObject
		{
			$$ = reorderExpression($1);
		}
	;
// }}}

ExpressionFlowSX_NoObject // {{{
	: ExpressionFlowSX_NoObject BinaryOperator OperandOrType_NoObject
		{
			$1.push($2);
			$1.push($3);
			$$ = $1;
		}
	| ExpressionFlowSX_NoObject AssignmentOperator OperandOrType_NoObject
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

ForHeader // {{{
	: ForHeaderBegin NL_0M ForHeaderMiddle NL_0M ForHeaderEnd
		{
			$$ = location($3, @1, @5);
			
			$$.declaration = $1.declaration;
			$$.variable = $1.variable;
			
			if($1.index) {
				$$.index = $1.index;
			}
			
			if($5) {
				if($5.until) {
					$$.until = $5.until;
				}
				else if($5.while) {
					$$.while = $5.while;
				}
				
				if($5.when) {
					$$.when = $5.when;
				}
			}
		}
	;
// }}}

ForHeaderBegin // {{{
	: 'FOR' 'LET' Identifier ',' Identifier
		{
			$$ = {
				variable: $3,
				index: $5,
				declaration: true
			};
		}
	| 'FOR' 'LET' Identifier
		{
			$$ = {
				variable: $3,
				declaration: true
			};
		}
	| 'FOR' Identifier ',' Identifier
		{
			$$ = {
				variable: $2,
				index: $4,
				declaration: false
			};
		}
	| 'FOR' Identifier
		{
			$$ = {
				variable: $2,
				declaration: false
			};
		}
	;
// }}}

ForHeaderMiddle // {{{
	: 'FROM' Expression 'TIL' Expression 'BY' Expression
		{
			$$ = {
				kind: Kind.ForFromStatement,
				from: $2,
				til: $4,
				by: $6
			};
		}
	| 'FROM' Expression 'TIL' Expression
		{
			$$ = {
				kind: Kind.ForFromStatement,
				from: $2,
				til: $4
			};
		}
	| 'FROM' Expression 'TO' Expression 'BY' Expression
		{
			$$ = {
				kind: Kind.ForFromStatement,
				from: $2,
				to: $4,
				by: $6
			};
		}
	| 'FROM' Expression 'TO' Expression
		{
			$$ = {
				kind: Kind.ForFromStatement,
				from: $2,
				to: $4
			};
		}
	| 'IN' Number '...' Number '..' Number
		{
			$$ = {
				kind: Kind.ForRangeStatement,
				from: $2,
				til: $4,
				by: $6
			};
		}
	| 'IN' Number '..' Number '..' Number
		{
			$$ = {
				kind: Kind.ForRangeStatement,
				from: $2,
				to: $4,
				by: $6
			};
		}
	| 'IN' Number '...' Number
		{
			$$ = {
				kind: Kind.ForRangeStatement,
				from: $2,
				til: $4
			};
		}
	| 'IN' Number '..' Number
		{
			$$ = {
				kind: Kind.ForRangeStatement,
				from: $2,
				to: $4
			};
		}
	| 'IN' Expression 'DESC'
		{
			$$ = {
				kind: Kind.ForInStatement,
				value: $2,
				desc: true
			};
		}
	| 'IN' Expression
		{
			$$ = {
				kind: Kind.ForInStatement,
				value: $2,
				desc: false
			};
		}
	| 'OF' Expression
		{
			$$ = {
				kind: Kind.ForOfStatement,
				value: $2
			};
		}
	;
// }}}

ForHeaderEnd // {{{
	: 'UNTIL' Expression 'WHEN' Expression
		{
			$$ = {
				until: $2,
				when: $4
			};
		}
	| 'UNTIL' Expression
		{
			$$ = {
				until: $2
			};
		}
	| 'WHILE' Expression 'WHEN' Expression
		{
			$$ = {
				while: $2,
				when: $4
			};
		}
	| 'WHILE' Expression
		{
			$$ = {
				while: $2
			};
		}
	| 'WHEN' Expression
		{
			$$ = {
				when: $2
			};
		}
	|
	;
// }}}

ForStatement // {{{
	: ForHeader NL_0M Block
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
	: 'FUNC' Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionReturns FunctionBody
		{
			$$ = location({
				kind: Kind.FunctionDeclaration,
				modifiers: $6,
				name: $2,
				parameters: $4,
				type: $7,
				body: $8
			}, @1, @8);
		}
	| 'FUNC' Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionBody
		{
			$$ = location({
				kind: Kind.FunctionDeclaration,
				modifiers: $6,
				name: $2,
				parameters: $4,
				body: $7
			}, @1, @7);
		}
	;
// }}}

FunctionExpression // {{{
	: 'FUNC' '(' FunctionParameterList ')' FunctionModifiers FunctionReturns FunctionBody
		{
			$$ = location({
				kind: Kind.FunctionExpression,
				modifiers: $5,
				parameters: $3,
				type: $6,
				body: $7
			}, @1, @7);
		}
	| 'FUNC' '(' FunctionParameterList ')' FunctionModifiers FunctionBody
		{
			$$ = location({
				kind: Kind.FunctionExpression,
				modifiers: $5,
				parameters: $3,
				body: $6
			}, @1, @6);
		}
	| '(' FunctionParameterList ')' FunctionModifiers FunctionReturns FunctionBody
		{
			$$ = location({
				kind: Kind.FunctionExpression,
				modifiers: $4,
				parameters: $2,
				type: $5,
				body: $6
			}, @1, @6);
		}
	| '(' FunctionParameterList ')' FunctionModifiers FunctionBody
		{
			$$ = location({
				kind: Kind.FunctionExpression,
				modifiers: $4,
				parameters: $2,
				body: $5
			}, @1, @5);
		}
	| Identifier '->' TypeVar '=>' Expression
		{
			$$ = location({
				kind: Kind.FunctionExpression,
				modifiers: [],
				parameters: [{
					kind: Kind.Parameter,
					modifiers: [],
					name: $1
				}],
				type: $3,
				body: $5
			}, @1, @5);
		}
	| Identifier '=>' Expression
		{
			$$ = location({
				kind: Kind.FunctionExpression,
				modifiers: [],
				parameters: [{
					kind: Kind.Parameter,
					modifiers: [],
					name: $1
				}],
				body: $3
			}, @1, @3);
		}
	;
// }}}

FunctionModifiers // {{{
	: FunctionModifiers 'ASYNC'
		{
			$1.push(location({
				kind: FunctionModifier.Async
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
	: FunctionParameterModifier FunctionParameterFooter
		{
			$2.modifiers = [$1];
			
			$$ = location($2, @1, @2);
		}
	| FunctionParameterFooter
	;
// }}}

FunctionParameterFooter // {{{
	: Identifier ColonSeparator TypeVar '=' Expression
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				type: $3,
				defaultValue: $5
			}, @1, @5);
		}
	| Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				type: $3
			}, @1, @3);
		}
	| Identifier '=' Expression
		{
			if($3.kind === Kind.Identifier && $3.name === 'null') {
				$$ = location({
					kind: Kind.Parameter,
					modifiers: [],
					name: $1,
					type: {
						kind: Kind.TypeReference,
						typeName: {
							kind: Kind.Identifier,
							name: 'any'
						},
						nullable: true
					}
				}, @1, @3);
			}
			else {
				$$ = location({
					kind: Kind.Parameter,
					modifiers: [],
					name: $1,
					defaultValue: $3
				}, @1, @3);
			}
		}
	| Identifier '?' '=' Expression
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				type: {
					kind: Kind.TypeReference,
					typeName: {
						kind: Kind.Identifier,
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
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				type: {
					kind: Kind.TypeReference,
					typeName: {
						kind: Kind.Identifier,
						name: 'any'
					},
					nullable: true
				}
			}, @1, @2);
		}
	| Identifier
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1
			}, @1);
		}
	| ColonSeparator TypeVar
		{
			$$ = location({
				kind: Kind.Parameter,
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
				kind: Kind.Parameter,
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
				kind: Kind.Parameter,
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
				kind: ParameterModifier.Rest,
				arity: {
					min: $3.value,
					max: $5.value
				}
			}, @1, @6);
		}
	| '...' '{' ',' Number '}'
		{
			$$ = location({
				kind: ParameterModifier.Rest,
				arity: {
					min: 0,
					max: $4.value
				}
			}, @1, @5);
		}
	| '...' '{' Number ',' '}'
		{
			$$ = location({
				kind: ParameterModifier.Rest,
				arity: {
					min: $3.value,
					max: Infinity
				}
			}, @1, @5);
		}
	| '...'
		{
			$$ = location({
				kind: ParameterModifier.Rest,
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

Identifier // {{{
	: 'IDENTIFIER'
		{
			$$ = location({
				kind: Kind.Identifier,
				name: $1
			}, @1);
		}
	| Keyword
		{
			$$ = location({
				kind: Kind.Identifier,
				name: $1
			}, @1);
		}
	;
// }}}

Identifier_NoWhereNoWith // {{{
	: 'IDENTIFIER'
		{
			$$ = location({
				kind: Kind.Identifier,
				name: $1
			}, @1);
		}
	| Keyword_NoWhereNoWith
		{
			$$ = location({
				kind: Kind.Identifier,
				name: $1
			}, @1);
		}
	;
// }}}

IfStatement // {{{
	: 'IF' Expression_NoAnonymousFunction Block
		{
			$$ = location({
				kind: Kind.IfStatement,
				condition: $2,
				then: $3,
				elseifs: []
			}, @1, @3);
		}
	;
// }}}

ImplementDeclaration // {{{
	: 'IMPL' Identifier TypeGeneric '{' ClassMember '}'
		{
			$$ = location({
				kind: Kind.ImplementDeclaration,
				variable: $2,
				properties: $5
			}, @1, @6);
		}
	| 'IMPL' Identifier '{' ClassMember '}'
		{
			$$ = location({
				kind: Kind.ImplementDeclaration,
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
				kind: Kind.ImportDeclaration,
				declarations: [$2]
			}, @1, @2);
		}
	| 'IMPORT' ImportDeclaratorLB
		{
			$$ = location({
				kind: Kind.ImportDeclaration,
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
				kind: Kind.ImportDeclarator,
				module: $3,
				specifiers: $1,
				references: $5
			}, @1, @5)
		}
	| ImportSpecifierList 'FROM' ImportName
		{
			$$ = location({
				kind: Kind.ImportDeclarator,
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
	| Keyword
	| 'IDENTIFIER'
	| 'MODULE_NAME'
	;
// }}}

ImportNameBegin // {{{
	: Keyword
		{
			yy.lexer.begin('import');
		}
	| 'IDENTIFIER'
		{
			yy.lexer.begin('import');
		}
	| 'MODULE_NAME'
		{
			yy.lexer.begin('import');
		}
	| '..'
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
				kind: Kind.ImportSpecifier,
				alias: $1,
				local: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: Kind.ImportSpecifier,
				alias: $1
			}, @1);
		}
	| '*' 'AS' Identifier
		{
			$$ = location({
				kind: Kind.ImportWildcardSpecifier,
				local: $3
			}, @1, @3);
		}
	| '*'
		{
			$$ = location({
				kind: Kind.ImportWildcardSpecifier
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
				kind: Kind.ImportReference,
				alias: $1,
				foreign: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: Kind.ImportReference,
				alias: $1
			}, @1);
		}
	;
// }}}

IncludeDeclaration // {{{
	: 'INCLUDE' ImportName
		{
			$$ = location({
				kind: Kind.IncludeDeclaration,
				files: [$2]
			}, @1, @2)
		}
	| 'INCLUDE' IncludeLB
		{
			$$ = location({
				kind: Kind.IncludeDeclaration,
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
				kind: Kind.IncludeOnceDeclaration,
				files: [$2]
			}, @1, @2)
		}
	| 'INCLUDE_ONCE' IncludeLB
		{
			$$ = location({
				kind: Kind.IncludeOnceDeclaration,
				files: $2
			}, @1, @2);
		}
	;
// }}}

Keyword // {{{
	: 'AS'
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
	| 'IF'
	| 'IMPL'
	| 'IMPORT'
	| 'INCLUDE'
	| 'IN'
	| 'IS'
	| 'LET'
	| 'NEW'
	| 'OF'
	| 'ON'
	| 'PRIVATE'
	| 'PROTECTED'
	| 'PUBLIC'
	| 'REQUIRE'
	| 'RETURN'
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
	: 'AS'
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
	| 'IF'
	| 'IMPL'
	| 'IMPORT'
	| 'INCLUDE'
	| 'IN'
	| 'IS'
	| 'LET'
	| 'NEW'
	| 'OF'
	| 'ON'
	| 'PRIVATE'
	| 'PROTECTED'
	| 'PUBLIC'
	| 'REQUIRE'
	| 'RETURN'
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

Method // {{{
	: MethodHeader FunctionModifiers FunctionReturns MethodBody
		{
			$1.kind = Kind.MethodDeclaration;
			$1.modifiers = $2;
			$1.type = $3;
			$1.body = $4;
			$$ = location($1, @4);
		}
	| MethodHeader FunctionModifiers MethodBody
		{
			$1.kind = Kind.MethodDeclaration;
			$1.modifiers = $2;
			$1.body = $3;
			$$ = location($1, @3);
		}
	| MethodHeader 'AS' NameIS 'WITH' Expression1CList
		{
			$1.kind = Kind.MethodAliasDeclaration;
			$1.modifiers = [];
			$1.alias = $3;
			$1.arguments = $5;
			$$ = location($1, @5);
		}
	| MethodHeader 'AS' NameIS
		{
			$1.kind = Kind.MethodAliasDeclaration;
			$1.modifiers = [];
			$1.alias = $3;
			$$ = location($1, @3);
		}
	| MethodHeader 'FOR' NameIS 'WITH' Expression1CList
		{
			$1.kind = Kind.MethodLinkDeclaration;
			$1.modifiers = [];
			$1.alias = $3;
			$1.arguments = $5;
			$$ = location($1, @5);
		}
	| MethodHeader 'FOR' NameIS
		{
			$1.kind = Kind.MethodLinkDeclaration;
			$1.modifiers = [];
			$1.alias = $3;
			$$ = location($1, @3);
		}
	| MethodHeader
		{
			$1.kind = Kind.MethodDeclaration;
			$1.modifiers = [];
			$$ = location($1, @1);
		}
	;
// }}}

MethodBody // {{{
	: Block
	| '=>' '@' Identifier
		{
			$$ = location({
				kind: Kind.MemberReference,
				name: $3
			}, @2, @3);
		}
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
				parameters: $3
			}, @1, @4)
		}
	;
// }}}

MethodParameter // {{{
	: MethodParameterModifier MethodParameterFooter
		{
			$2.modifiers = [$1];
			
			$$ = location($2, @1, @2);
		}
	| MethodParameterFooter
	;
// }}}

MethodParameterFooter // {{{
	: Identifier ColonSeparator TypeVar '=' Expression
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				type: $3,
				defaultValue: $5
			}, @1, @5);
		}
	| Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				type: $3
			}, @1, @3);
		}
	| Identifier '=' Expression
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				defaultValue: $3
			}, @1, @3);
		}
	| Identifier '?' '=' Expression
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				type: {
					kind: Kind.TypeReference,
					typeName: {
						kind: Kind.Identifier,
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
				kind: Kind.Parameter,
				modifiers: [],
				name: $1,
				type: {
					kind: Kind.TypeReference,
					typeName: {
						kind: Kind.Identifier,
						name: 'any'
					},
					nullable: true
				}
			}, @1, @2);
		}
	| Identifier
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				name: $1
			}, @1);
		}
	| ColonSeparator TypeVar
		{
			$$ = location({
				kind: Kind.Parameter,
				modifiers: [],
				type: $2
			}, @1, @2);
		}
	;
// }}}

MethodParameterList // {{{
	: ',' MethodParameterListSX
		{
			$2.unshift({
				kind: Kind.Parameter,
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
				kind: Kind.Parameter,
				modifiers: []
			});
		}
	| MethodParameter
		{
			$$ = [$1];
		}
	;
// }}}

MethodParameterModifier // {{{
	: '...' '{' Number ',' Number '}'
		{
			$$ = location({
				kind: ParameterModifier.Rest,
				arity: {
					min: $3.value,
					max: $5.value
				}
			}, @1, @6);
		}
	| '...' '{' ',' Number '}'
		{
			$$ = location({
				kind: ParameterModifier.Rest,
				arity: {
					min: 0,
					max: $4.value
				}
			}, @1, @5);
		}
	| '...' '{' Number ',' '}'
		{
			$$ = location({
				kind: ParameterModifier.Rest,
				arity: {
					min: $3.value,
					max: Infinity
				}
			}, @1, @5);
		}
	| '...'
		{
			$$ = location({
				kind: ParameterModifier.Rest,
				arity: {
					min: 0,
					max: Infinity
				}
			}, @1);
		}
	| '@'
		{
			$$ = location({
				kind: ParameterModifier.Member
			}, @1);
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
	| ModuleSX AttributeWithin NL_EOF_1
		{
			$$ = location($1, @2);
			$$.attributes.push($2);
		}
	| ModuleSX NL_EOF_1
	|
		{
			$$ = {
				kind: Kind.Module,
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
				kind: Kind.NumericExpression,
				value: parseInt($1, 2)
			}, @1);
		}
	| 'OCTAL_NUMBER'
		{
			$$ = location({
				kind: Kind.NumericExpression,
				value: parseInt($1, 8)
			}, @1);
		}
	| 'HEX_NUMBER'
		{
			$$ = location({
				kind: Kind.NumericExpression,
				value: parseInt($1, 16)
			}, @1);
		}
	| 'DECIMAL_NUMBER'
		{
			$$ = location({
				kind: Kind.NumericExpression,
				value: parseFloat($1, 10)
			}, @1);
		}
	;
// }}}

Object // {{{
	: '{' NL_0M ObjectListPN ObjectItem '}'
		{
			$3.push($4);
			
			$$ = location({
				kind: Kind.ObjectExpression,
				properties: $3
			}, @1, @5);
		}
	| '{' NL_0M ObjectListPN '}'
		{
			$$ = location({
				kind: Kind.ObjectExpression,
				properties: $3
			}, @1, @4);
		}
	| '{' NL_0M ObjectItem '}'
		{
			$$ = location({
				kind: Kind.ObjectExpression,
				properties: [$3]
			}, @1, @4);
		}
	| '{' NL_0M '}'
		{
			$$ = location({
				kind: Kind.ObjectExpression,
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
	: ObjectItem ',' NL_0M
	| ObjectItem NL_1M
	;
// }}}

ObjectItem // {{{
	: NameIST ColonSeparator Expression
		{
			$$ = location({
				kind: Kind.ObjectMember,
				name: $1,
				value: $3
			}, @1, @3);
		}
	| NameIST '(' FunctionParameterList ')' FunctionModifiers FunctionReturns FunctionBody
		{
			$$ = location({
				kind: Kind.ObjectMember,
				name: $1,
				value: location({
					kind: Kind.FunctionExpression,
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
				kind: Kind.ObjectMember,
				name: $1,
				value: location({
					kind: Kind.FunctionExpression,
					parameters: $3,
					modifiers: $5,
					body: $6
				}, @2, @6)
			}, @1, @6);
		}
	;
// }}}

Operand // {{{
	: PrefixUnaryOperator Operand
		{
			if($1.kind === UnaryOperator.Negative && $2.kind === Kind.NumericExpression) {
				$2.value = -$2.value;
				$$ = location($2, @1, @2);
			}
			else {
				$$ = location({
					kind: Kind.UnaryExpression,
					operator: $1,
					argument: $2
				}, @1, @2);
			}
		}
	| Operand PostfixUnaryOperator
		{
			$$ = location({
				kind: Kind.UnaryExpression,
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
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: true
			}, @1, @3);
		}
	| OperandSX '?[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: true
			}, @1, @4);
		}
	| OperandSX '.' Identifier
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| OperandSX '[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| OperandSX '?' '(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $4,
				nullable: true
			}, @1, @5);
		}
	| OperandSX '?'
		{
			$$ = location({
				kind: Kind.UnaryExpression,
				operator: location({
					kind: UnaryOperator.Existential
				}, @2),
				argument: $1
			}, @1, @2);
		}
	| OperandSX '^^(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX '^$(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX '^@(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX '**(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.Null
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX '*$(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.Argument,
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
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX '::' Identifier
		{
			$$ = location({
				kind: Kind.EnumExpression,
				enum: $1,
				member: $3
			}, @1, @3);
		}
	| OperandSX ':' Identifier
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				left: $1,
				right: location({
					kind: Kind.TypeReference,
					typeName: $3
				}, @3),
				operator: location({
					kind: BinaryOperator.TypeCasting
				}, @2)
			}, @1, @3);
		}
	| OperandElement
	;
// }}}

OperandElement // {{{
	: Array
	| CreateExpression
	| DestroyExpression
	| Identifier
	| Number
	| Object
	| Parenthesis
	| RegularExpression
	| String
	| TemplateExpression
	;
// }}}

OperandOrType // {{{
	: Operand TypeOperator TypeEntity
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				left: $1,
				right: $3,
				operator: $2
			}, @1, @3);
		}
	| Operand
	;
// }}}

Operand_NoAnonymousFunction // {{{
	: PrefixUnaryOperator Operand_NoAnonymousFunction
		{
			if($1.kind === UnaryOperator.Negative && $2.kind === Kind.NumericExpression) {
				$2.value = -$2.value;
				$$ = location($2, @1, @2);
			}
			else {
				$$ = location({
					kind: Kind.UnaryExpression,
					operator: $1,
					argument: $2
				}, @1, @2);
			}
		}
	| Operand_NoAnonymousFunction PostfixUnaryOperator
		{
			$$ = location({
				kind: Kind.UnaryExpression,
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
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: true
			}, @1, @3);
		}
	| OperandSX_NoAnonymousFunction '?[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: true
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '.' Identifier
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| OperandSX_NoAnonymousFunction '[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '?' '(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $4,
				nullable: true
			}, @1, @5);
		}
	| OperandSX_NoAnonymousFunction '?'
		{
			$$ = location({
				kind: Kind.UnaryExpression,
				operator: location({
					kind: UnaryOperator.Existential
				}, @2),
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoAnonymousFunction '^^(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '^$(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '^@(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '**(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '*$(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoAnonymousFunction '::' Identifier
		{
			$$ = location({
				kind: Kind.EnumExpression,
				enum: $1,
				member: $3
			}, @1, @3);
		}
	| OperandSX_NoAnonymousFunction ':' Identifier
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				left: $1,
				right: location({
					kind: Kind.TypeReference,
					typeName: $3
				}, @3),
				operator: location({
					kind: BinaryOperator.TypeCasting
				}, @2)
			}, @1, @3);
		}
	| OperandElement_NoAnonymousFunction
	;
// }}}

OperandElement_NoAnonymousFunction // {{{
	: Array
	| CreateExpression
	| DestroyExpression
	| Identifier
	| Number
	| Object
	| Parenthesis_NoAnonymousFunction
	| RegularExpression
	| String
	| TemplateExpression
	;
// }}}

OperandOrType_NoAnonymousFunction // {{{
	: Operand_NoAnonymousFunction TypeOperator TypeEntity
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				left: $1,
				right: $3,
				operator: $2
			}, @1, @3);
		}
	| Operand_NoAnonymousFunction
	;
// }}}

Operand_NoObject // {{{
	: PrefixUnaryOperator Operand_NoObject
		{
			if($1.kind === UnaryOperator.Negative && $2.kind === Kind.NumericExpression) {
				$2.value = -$2.value;
				$$ = location($2, @1, @2);
			}
			else {
				$$ = location({
					kind: Kind.UnaryExpression,
					operator: $1,
					argument: $2
				}, @1, @2);
			}
		}
	| Operand_NoObject PostfixUnaryOperator
		{
			$$ = location({
				kind: Kind.UnaryExpression,
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
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: true
			}, @1, @3);
		}
	| OperandSX_NoObject '?[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: true
			}, @1, @4);
		}
	| OperandSX_NoObject '.' Identifier
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| OperandSX_NoObject '?' '(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $4,
				nullable: true
			}, @1, @5);
		}
	| OperandSX_NoObject '?'
		{
			$$ = location({
				kind: Kind.UnaryExpression,
				operator: location({
					kind: UnaryOperator.Existential
				}, @2),
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoObject '[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoObject '^^(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '^$(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '^@(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '**(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '*$(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoObject '::' Identifier
		{
			$$ = location({
				kind: Kind.EnumExpression,
				enum: $1,
				member: $3
			}, @1, @3);
		}
	| OperandSX_NoObject ':' Identifier
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				left: $1,
				right: location({
					kind: Kind.TypeReference,
					typeName: $3
				}, @3),
				operator: location({
					kind: BinaryOperator.TypeCasting
				}, @2)
			}, @1, @3);
		}
	| OperandElement_NoObject
	;
// }}}

OperandElement_NoObject // {{{
	: Array
	| CreateExpression
	| DestroyExpression
	| Identifier
	| Number
	| Parenthesis
	| RegularExpression
	| String
	| TemplateExpression
	;
// }}}

OperandOrType_NoObject // {{{
	: Operand_NoObject TypeOperator TypeEntity
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				left: $1,
				right: $3,
				operator: $2
			}, @1, @3);
		}
	| Operand_NoObject
	;
// }}}

Operand_NoWhereNoWith // {{{
	: PrefixUnaryOperator Operand_NoWhereNoWith
		{
			if($1.kind === UnaryOperator.Negative && $2.kind === Kind.NumericExpression) {
				$2.value = -$2.value;
				$$ = location($2, @1, @2);
			}
			else {
				$$ = location({
					kind: Kind.UnaryExpression,
					operator: $1,
					argument: $2
				}, @1, @2);
			}
		}
	| Operand_NoWhereNoWith PostfixUnaryOperator
		{
			$$ = location({
				kind: Kind.UnaryExpression,
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
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: true
			}, @1, @3);
		}
	| OperandSX_NoWhereNoWith '?[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: true
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '.' Identifier
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| OperandSX_NoWhereNoWith '[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '?' '(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $4,
				nullable: true
			}, @1, @5);
		}
	| OperandSX_NoWhereNoWith '?'
		{
			$$ = location({
				kind: Kind.UnaryExpression,
				operator: location({
					kind: UnaryOperator.Existential
				}, @2),
				argument: $1
			}, @1, @2);
		}
	| OperandSX_NoWhereNoWith '^^(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.Null
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '^$(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.Argument,
					value: $3.shift()
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '^@(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CurryExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $3
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '**(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.Null
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '*$(' Expression0CNList ')'
		{
			$$ = location({
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.Argument,
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
				kind: Kind.CallExpression,
				scope: {
					kind: ScopeModifier.This
				},
				callee: $1,
				arguments: $3,
				nullable: false
			}, @1, @4);
		}
	| OperandSX_NoWhereNoWith '::' Identifier
		{
			$$ = location({
				kind: Kind.EnumExpression,
				enum: $1,
				member: $3
			}, @1, @3);
		}
	| OperandSX_NoWhereNoWith ':' Identifier
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				left: $1,
				right: location({
					kind: Kind.TypeReference,
					typeName: $3
				}, @3),
				operator: location({
					kind: BinaryOperator.TypeCasting
				}, @2)
			}, @1, @3);
		}
	| OperandElement_NoWhereNoWith
	;
// }}}

OperandElement_NoWhereNoWith // {{{
	: Array
	| CreateExpression
	| DestroyExpression
	| Identifier_NoWhereNoWith
	| Number
	| Object
	| Parenthesis
	| RegularExpression
	| String
	| TemplateExpression
	;
// }}}

Parenthesis // {{{
	: '(' Expression ')'
		{
			$$ = $2;
		}
	| '(' Identifier '=' Expression ')' FunctionBody
		{
			$$ = location({
				kind: Kind.FunctionExpression,
				modifiers: [],
				parameters: [location({
					kind: Kind.Parameter,
					modifiers: [],
					name: $2,
					defaultValue: $4
				}, @2, @4)],
				body: $6
			}, @1, @6);
		}
	| '(' Identifier '=' Expression ')'
		{
			$$ = location({
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Equality
				}, @3),
				left: $2,
				right: $4
			}, @2, @4);
		}
	| '(' Identifier ')' FunctionBody
		{
			$$ = location({
				kind: Kind.FunctionExpression,
				modifiers: [],
				parameters: [location({
					kind: Kind.Parameter,
					modifiers: [],
					name: $2
				}, @2)],
				body: $4
			}, @1, @4);
		}
	| '(' Identifier ')'
		{
			$$ = $2;
		}
	| '(' Identifier 'SPACED_?' Expression 'SPACED_:' Expression ')'
		{
			$$ = location({
				kind: Kind.TernaryConditionalExpression,
				condition: $2,
				then: $4,
				else: $6
			}, @2, @6);
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
				kind: Kind.BinaryOperator,
				operator: location({
					kind: BinaryOperator.Assignment,
					assignment: AssignmentOperator.Equality
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
				kind: Kind.TernaryConditionalExpression,
				condition: $2,
				then: $4,
				else: $6
			}, @2, @6);
		}
	;
// }}}

PostfixUnaryOperator // {{{
	: '--'
		{
			$$ = location({
				kind: UnaryOperator.DecrementPostfix
			}, @1);
		}
	| '++'
		{
			$$ = location({
				kind: UnaryOperator.IncrementPostfix
			}, @1);
		}
	;
// }}}

PrefixUnaryOperator // {{{
	: '--'
		{
			$$ = location({
				kind: UnaryOperator.DecrementPrefix
			}, @1);
		}
	| '++'
		{
			$$ = location({
				kind: UnaryOperator.IncrementPrefix
			}, @1);
		}
	| '!'
		{
			$$ = location({
				kind: UnaryOperator.Negation
			}, @1);
		}
	| '?'
		{
			$$ = location({
				kind: UnaryOperator.Existential
			}, @1);
		}
	| '-'
		{
			$$ = location({
				kind: UnaryOperator.Negative
			}, @1);
		}
	| '...'
		{
			$$ = location({
				kind: UnaryOperator.Spread
			}, @1);
		}
	;
// }}}

RequireDeclaration // {{{
	: 'REQUIRE' ExternDeclaratorLL
		{
			$$ = location({
				kind: Kind.RequireDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'REQUIRE' ExternDeclaratorLB
		{
			$$ = location({
				kind: Kind.RequireDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

RequireOrExternDeclaration // {{{
	: 'REQUIRE|EXTERN' ExternDeclaratorLL
		{
			$$ = location({
				kind: Kind.RequireOrExternDeclaration,
				declarations: $2
			}, @1, @2);
		}
	| 'REQUIRE|EXTERN' ExternDeclaratorLB
		{
			$$ = location({
				kind: Kind.RequireOrExternDeclaration,
				declarations: $2
			}, @1, @2);
		}
	;
// }}}

RegularExpression // {{{
	: RegularExpressionBegin 'REGEXP_LITERAL'
		{
			$$ = location({
				kind: Kind.RegularExpression,
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
				kind: Kind.ReturnStatement,
				value: {
					kind: Kind.IfExpression,
					condition: $4,
					then: $2,
					else: $6
				}
			}, @1, @6);
		}
	| 'RETURN' Expression 'IF' Expression
		{
			$$ = {
				kind: Kind.IfStatement,
				condition: $4,
				then: location({
					kind: Kind.ReturnStatement,
					value: $2
				}, @1, @2),
				elseifs: []
			};
		}
	| 'RETURN' Expression 'UNLESS' Expression
		{
			$$ = {
				kind: Kind.UnlessStatement,
				condition: $4,
				then: location({
					kind: Kind.ReturnStatement,
					value: $2
				}, @1, @2),
				elseifs: []
			};
		}
	| 'RETURN' Expression
		{
			$$ = location({
				kind: Kind.ReturnStatement,
				value: $2
			}, @1, @2);
		}
	| 'RETURN' 'IF' Expression
		{
			$$ = {
				kind: Kind.IfStatement,
				condition: $3,
				then: location({
					kind: Kind.ReturnStatement
				}, @1),
				elseifs: []
			};
		}
	| 'RETURN' 'UNLESS' Expression
		{
			$$ = {
				kind: Kind.UnlessStatement,
				condition: $3,
				then: location({
					kind: Kind.ReturnStatement
				}, @1),
				elseifs: []
			};
		}
	| 'RETURN'
		{
			$$ = location({
				kind: Kind.ReturnStatement
			}, @1);
		}
	;
// }}}

Statement // {{{
	: VariableDeclaration NL_EOF_1M
	| AssignmentDeclaration NL_EOF_1M
	| FunctionDeclaration NL_EOF_1M
	| EnumDeclaration NL_EOF_1M
	| ReturnStatement NL_EOF_1M
	| IfStatement NL_EOF_1M ElseIfStatements NL_EOF_1M ElseStatement NL_EOF_1M
		{
			$1.elseifs = $3;
			$1.else = $5;
			$$ = location($1, @1, @5);
		}
	| IfStatement NL_EOF_1M ElseIfStatements NL_EOF_1M
		{
			$1.elseifs = $3;
			$$ = location($1, @1, @3);
		}
	| IfStatement NL_EOF_1M ElseStatement NL_EOF_1M
		{
			$1.else = $3;
			$$ = location($1, @1, @3);
		}
	| IfStatement NL_EOF_1M
	| UnlessStatement NL_EOF_1M
	| ForStatement NL_EOF_1M
	| 'DO' Block NL_1M 'UNTIL' Expression NL_EOF_1M
		{
			$$ = location({
				kind: Kind.DoUntilStatement,
				condition: $5,
				body: $2
			}, @1, @5);
		}
	| 'DO' Block NL_1M 'WHILE' Expression NL_EOF_1M
		{
			$$ = location({
				kind: Kind.DoWhileStatement,
				condition: $5,
				body: $2
			}, @1, @5);
		}
	| WhileStatement NL_EOF_1M
	| UntilStatement NL_EOF_1M
	| ThrowStatement NL_EOF_1M
	| TryStatement NL_EOF_1M CatchOnClauseList NL_EOF_1M CatchClause NL_EOF_1M FinallyClause NL_EOF_1M
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
				kind: Kind.BreakStatement
			}, @1);
		}
	| 'CONTINUE' NL_EOF_1M
		{
			$$ = location({
				kind: Kind.ContinueStatement
			}, @1);
		}
	| SwitchStatement NL_EOF_1M
	| TypeDeclaration NL_EOF_1M
	| StatementExpression NL_EOF_1M
	;
// }}}

StatementExpression // {{{
	: Expression ForHeader
		{
			$2.body = $1;
			$$ = location($2, @1, @2);
		}
	| Expression 'IF' Expression
		{
			$$ = location({
				kind: Kind.IfStatement,
				condition: $3,
				then: $1,
				elseifs: []
			}, @1, @3);
		}
	| Expression 'UNLESS' Expression
		{
			$$ = location({
				kind: Kind.UnlessStatement,
				condition: $3,
				then: $1,
				elseifs: []
			}, @1, @3);
		}
	| Expression
	;
// }}}

String // {{{
	: 'STRING'
		{
			$$ = location({
				kind: Kind.Literal,
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
				kind: Kind.SwitchTypeCasting,
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
				kind: Kind.ArrayBinding,
				elements: $2.concat($3)
			}, @1, @4)
		}
	| '[' SwitchBindingArrayList ']'
		{
			$$ = location({
				kind: Kind.ArrayBinding,
				elements: $2
			}, @1, @3)
		}
	;
// }}}

SwitchBindingArrayOmitted // {{{
	: SwitchBindingArrayOmitted ','
		{
			$1.push({
				kind: Kind.OmittedExpression
			});
		}
	| ','
		{
			$$ = [{
				kind: Kind.OmittedExpression
			}];
		}
	;
// }}}

SwitchBindingArrayList // {{{
	: SwitchBindingArrayList ',' '...' Identifier
		{
			$1.push(location({
				kind: Kind.BindingElement,
				name: $4,
				spread: true
			}, @3, @4));
		}
	| SwitchBindingArrayList ',' '...'
		{
			$1.push(location({
				kind: Kind.OmittedExpression,
				spread: true
			}, @3));
		}
	| SwitchBindingArrayList ',' Identifier
		{
			$1.push(location({
				kind: Kind.BindingElement,
				name: $3
			}, @3));
		}
	| SwitchBindingArrayList ','
		{
			$1.push({
				kind: Kind.OmittedExpression
			});
		}
	| '...' Identifier
		{
			$$ = [location({
				kind: Kind.BindingElement,
				name: $2,
				spread: true
			}, @1, @2)];
		}
	| '...'
		{
			$$ = [location({
				kind: Kind.OmittedExpression,
				spread: true
			}, @1)];
		}
	| Identifier
		{
			$$ = [location({
				kind: Kind.BindingElement,
				name: $1
			}, @1)];
		}
	;
// }}}

SwitchBindingObject // {{{
	: '{' SwitchBindingObjectList '}'
		{
			$$ = location({
				kind: Kind.ObjectBinding,
				elements: $2
			}, @1, @3)
		}
	;
// }}}

SwitchBindingObjectList // {{{
	: SwitchBindingObjectList ',' Identifier ColonSeparator Identifier
		{
			$1.push(location({
				kind: Kind.BindingElement,
				alias: $3,
				name: $5
			}, @3, @5));
		}
	| Identifier ColonSeparator Identifier
		{
			$$ = [location({
				kind: Kind.BindingElement,
				alias: $1,
				name: $3
			}, @1, @3)];
		}
	;
// }}}

SwitchCaseList // {{{
	: '{' NL_0M SwitchCaseListPN '}'
		{
			$$ = $3;
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
				kind: Kind.SwitchClause,
				conditions: $1,
				bindings: $4,
				filter: $7,
				body: $11
			}, @1, @11);
		}
	| SwitchCondition NL_0M 'WHERE' Expression NL_0M '=>' NL_0M SwitchCaseExpression NL_1M
		{
			$$ = location({
				kind: Kind.SwitchClause,
				conditions: $1,
				bindings: [],
				filter: $4,
				body: $8
			}, @1, @8);
		}
	| SwitchCondition NL_0M 'WITH' SwitchBinding NL_0M '=>' NL_0M SwitchCaseExpression NL_1M
		{
			$$ = location({
				kind: Kind.SwitchClause,
				conditions: $1,
				bindings: $4,
				body: $8
			}, @1, @8);
		}
	| SwitchCondition NL_0M '=>' NL_0M SwitchCaseExpression NL_1M
		{
			$$ = location({
				kind: Kind.SwitchClause,
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
				kind: Kind.SwitchConditionArray,
				values: [{
					kind: Kind.OmittedExpression
				}].concat($3)
			}, @1, @4);
		}
	| '[' SwitchConditionArrayItemList ']'
		{
			$$ = location({
				kind: Kind.SwitchConditionArray,
				values: $2
			}, @1, @3);
		}
	| '[' ',' ']'
		{
			$$ = location({
				kind: Kind.SwitchConditionArray,
				values: [{
					kind: Kind.OmittedExpression
				}, {
					kind: Kind.OmittedExpression
				}]
			}, @1, @3);
		}
	| '[' ']'
		{
			$$ = location({
				kind: Kind.SwitchConditionArray,
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
				kind: Kind.OmittedExpression,
				spread: true
			}, @3));
		}
	| SwitchConditionArrayItemList ','
		{
			$1.push({
				kind: Kind.OmittedExpression
			});
		}
	| SwitchConditionValue
		{
			$$ = [$1];
		}
	| '...'
		{
			$$ = [location({
				kind: Kind.OmittedExpression,
				spread: true
			}, @1)];
		}
	;
// }}}

SwitchConditionObject // {{{
	: '{' SwitchConditionObjectItemList '}'
		{
			$$ = location({
				kind: Kind.SwitchConditionObject,
				members: $2
			}, @1, @3);
		}
	| '{' '}'
		{
			$$ = location({
				kind: Kind.SwitchConditionObject,
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
				kind: Kind.ObjectMember,
				name: $1,
				value: $3
			}, @1, @3);
		}
	| Identifier
		{
			$$ = location({
				kind: Kind.ObjectMember,
				name: $1
			}, @1);
		}
	;
// }}}

SwitchConditionValue // {{{
	: Operand '<' '..' '<' Operand
		{
			$$ = location({
				kind: Kind.SwitchConditionRange,
				then: $1,
				til: $5
			}, @1, @5);
		}
	| Operand '<' '..' Operand
		{
			$$ = location({
				kind: Kind.SwitchConditionRange,
				then: $1,
				to: $4
			}, @1, @4);
		}
	| Operand '..' '<' Operand
		{
			$$ = location({
				kind: Kind.SwitchConditionRange,
				from: $1,
				til: $4
			}, @1, @4);
		}
	| Operand '..' Operand
		{
			$$ = location({
				kind: Kind.SwitchConditionRange,
				from: $1,
				to: $3
			}, @1, @3);
		}
	| ColonSeparator Identifier
		{
			$$ = location({
				kind: Kind.SwitchConditionEnum,
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
				kind: Kind.SwitchConditionRange,
				then: $1,
				til: $5
			}, @1, @5);
		}
	| Operand_NoWhereNoWith '<' '..' Operand_NoWhereNoWith
		{
			$$ = location({
				kind: Kind.SwitchConditionRange,
				then: $1,
				to: $4
			}, @1, @4);
		}
	| Operand_NoWhereNoWith '..' '<' Operand_NoWhereNoWith
		{
			$$ = location({
				kind: Kind.SwitchConditionRange,
				from: $1,
				til: $4
			}, @1, @4);
		}
	| Operand_NoWhereNoWith '..' Operand_NoWhereNoWith
		{
			$$ = location({
				kind: Kind.SwitchConditionRange,
				from: $1,
				to: $3
			}, @1, @3);
		}
	| ColonSeparator Identifier
		{
			$$ = location({
				kind: Kind.SwitchConditionEnum,
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
				kind: Kind.SwitchConditionType,
				type: $2
			}, @1, @2);
		}
	;
// }}}

SwitchExpression // {{{
	: 'SWITCH' ExpressionFlow SwitchCaseList
		{
			$$ = location({
				kind: Kind.SwitchExpression,
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
				kind: Kind.SwitchStatement,
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
				kind: Kind.TemplateExpression,
				elements: $2
			}, @1, @3);
		}
	;
// }}}

TemplateValues // {{{
	: TemplateValues 'TEMPLATE_VALUE'
		{
			$1.push(location({
				kind: Kind.Literal,
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
				kind: Kind.Literal,
				value: $1
			}, @1)];
		}
	| '\(' Expression ')'
		{
			$$ = [$2];
		}
	;
// }}}

ThrowStatement // {{{
	: 'THROW' Expression 'IF' Expression
		{
			$$ = {
				kind: Kind.IfStatement,
				condition: $4,
				then: location({
					kind: Kind.ThrowStatement,
					value: $2
				}, @1, @2),
				elseifs: []
			};
		}
	| 'THROW' Expression 'UNLESS' Expression
		{
			$$ = {
				kind: Kind.UnlessStatement,
				condition: $4,
				then: location({
					kind: Kind.ThrowStatement,
					value: $2
				}, @1, @2),
				elseifs: []
			};
		}
	| 'THROW' Expression
		{
			$$ = location({
				kind: Kind.ThrowStatement,
				value: $2
			}, @1, @2);
		}
	| 'THROW' 'IF' Expression
		{
			$$ = {
				kind: Kind.IfStatement,
				condition: $3,
				then: location({
					kind: Kind.ThrowStatement
				}, @1),
				elseifs: []
			};
		}
	| 'THROW' 'UNLESS' Expression
		{
			$$ = {
				kind: Kind.UnlessStatement,
				condition: $3,
				then: location({
					kind: Kind.ThrowStatement
				}, @1),
				elseifs: []
			};
		}
	| 'THROW'
		{
			$$ = location({
				kind: Kind.ThrowStatement
			}, @1);
		}
	;
// }}}

TryStatement // {{{
	: 'TRY' Block
		{
			$$ = location({
				kind: Kind.TryStatement,
				body: $2
			}, @1, @2);
		}
	;
// }}}

TypeArray // {{{
	: '[' TypeVarList ']'
		{
			$$ = location({
				kind: Kind.TypeReference,
				typeName: {
					kind: Kind.Identifier,
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
			if($1.type === Kind.UnionType) {
				$1.types.push($3);
				$$ = location($1, @3);
			}
			else {
				$$ = location({
					kind: Kind.UnionType,
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
				kind: Kind.TypeReference,
				typeName: $1,
				typeParameters: $2
			}, @1, @2);
		}
	| TypeName
		{
			$$ = location({
				kind: Kind.TypeReference,
				typeName: $1
			}, @1);
		}
	;
// }}}

TypeName // {{{
	: TypeName '.' Identifier
		{
			$$ = location({
				kind: Kind.MemberExpression,
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
				kind: Kind.TypeReference,
				typeName: {
					kind: Kind.Identifier,
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
				kind: BinaryOperator.TypeCasting
			}, @1);
		}
	| 'IS'
		{
			$$ = location({
				kind: BinaryOperator.TypeEquality
			}, @1);
		}
	| 'IS_NOT'
		{
			$$ = location({
				kind: BinaryOperator.TypeInequality
			}, @1);
		}
	;
// }}}

TypeProperty // {{{
	: Identifier ColonSeparator TypeVar
		{
			$$ = location({
				kind: Kind.ObjectMember,
				name: $1,
				type: $3
			}, @1, @3);
		}
	| Identifier '(' FunctionParameterList ')' FunctionModifiers FunctionReturns
		{
			$$ = location({
				kind: Kind.ObjectMember,
				name: $1,
				type: {
					kind: Kind.FunctionExpression,
					parameters: $3,
					modifiers: $5,
					type: $6
				}
			}, @1, @6);
		}
	| Identifier '(' FunctionParameterList ')' FunctionModifiers
		{
			$$ = location({
				kind: Kind.ObjectMember,
				name: $1,
				type: {
					kind: Kind.FunctionExpression,
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
				kind: Kind.TypeAliasDeclaration,
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

UnlessStatement // {{{
	: 'UNLESS' Expression Block
		{
			$$ = location({
				kind: Kind.UnlessStatement,
				condition: $2,
				then: $3
			}, @1, @3);
		}
	;
// }}}

UntilStatement // {{{
	: 'UNTIL' Expression Block
		{
			$$ = location({
				kind: Kind.UntilStatement,
				condition: $2,
				body: $3
			}, @1, @3);
		}
	| 'UNTIL' Expression '=>' Expression
		{
			$$ = location({
				kind: Kind.UntilStatement,
				condition: $2,
				body: $4
			}, @1, @4);
		}
	;
// }}}

VariableConstDeclarator // {{{
	: Identifier ColonSeparator TypeVar '=' 'AWAIT' Operand
		{
			$$ = location({
				kind: Kind.AwaitExpression,
				variables: [location({
					kind: Kind.VariableDeclarator,
					name: $1,
					type: $3
				}, @1, @3)],
				operation: $6
			}, @1, @6);
		}
	| Identifier ColonSeparator TypeVar '=' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				type: $3,
				init: $5
			}, @1, @5);
		}
	| VariableIdentifier ':=' 'AWAIT' Operand
		{
			$$ = location({
				kind: Kind.AwaitExpression,
				variables: [$1],
				operation: $4,
				autotype: true
			}, @1, @4);
		}
	| VariableIdentifier ':=' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				init: $3,
				autotype: true
			}, @1, @3);
		}
	| VariableIdentifier '=' 'AWAIT' Operand
		{
			$$ = location({
				kind: Kind.AwaitExpression,
				variables: [$1],
				operation: $4
			}, @1, @4);
		}
	| VariableIdentifier '=' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				init: $3
			}, @1, @3);
		}
	;
// }}}

VariableDeclaration // {{{
	: 'LET' VariableList
		{
			$$ = location({
				kind: Kind.VariableDeclaration,
				modifiers: location({
					kind: VariableModifier.Let
				}, @1),
				declarations: $2
			}, @1, @2);
		}
	| 'CONST' VariableConstDeclarator
		{
			$$ = location({
				kind: Kind.VariableDeclaration,
				modifiers: location({
					kind: VariableModifier.Const
				}, @1),
				declarations: [$2]
			}, @1, @2);
		}
	| 'LET' VariableLetDeclarator
		{
			$$ = location({
				kind: Kind.VariableDeclaration,
				modifiers: location({
					kind: VariableModifier.Let
				}, @1),
				declarations: [$2]
			}, @1, @2);
		}
	;
// }}}

VariableIdentifier // {{{
	: Identifier
	| DestructuringArray
		{
			$$ = location({
				kind: Kind.ArrayBinding,
				elements: $1
			}, @1);
		}
	| DestructuringObject
		{
			$$ = location({
				kind: Kind.ObjectBinding,
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

VariableLetDeclarator // {{{
	: Identifier ColonSeparator TypeVar '=' Expression 'IF' Expression 'ELSE' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				type: $3,
				init: {
					kind: Kind.IfExpression,
					condition: $7,
					then: $5,
					else: $9
				}
			}, @1, @9);
		}
	| Identifier ColonSeparator TypeVar '=' Expression 'IF' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				type: $3,
				init: {
					kind: Kind.IfExpression,
					condition: $7,
					then: $5
				}
			}, @1, @7);
		}
	| Identifier ColonSeparator TypeVar '=' Expression 'UNLESS' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				type: $3,
				init: {
					kind: Kind.UnlessExpression,
					condition: $7,
					then: $5
				}
			}, @1, @7);
		}
	| Identifier ColonSeparator TypeVar '=' 'AWAIT' Operand
		{
			$$ = location({
				kind: Kind.AwaitExpression,
				variables: [location({
					kind: Kind.VariableDeclarator,
					name: $1,
					type: $3
				}, @1, @3)],
				operation: $6
			}, @1, @6);
		}
	| Identifier ColonSeparator TypeVar '=' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				type: $3,
				init: $5
			}, @1, @5);
		}
	| VariableIdentifier '=' Expression 'IF' Expression 'ELSE' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				init: {
					kind: Kind.IfExpression,
					condition: $5,
					then: $3,
					else: $7
				}
			}, @1, @7);
		}
	| VariableIdentifier '=' Expression 'IF' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				init: {
					kind: Kind.IfExpression,
					condition: $5,
					then: $3
				}
			}, @1, @5);
		}
	| VariableIdentifier '=' Expression 'UNLESS' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				init: {
					kind: Kind.UnlessExpression,
					condition: $5,
					then: $3
				}
			}, @1, @5);
		}
	| VariableIdentifier ':=' 'AWAIT' Operand
		{
			$$ = location({
				kind: Kind.AwaitExpression,
				variables: [$1],
				operation: $4,
				autotype: true
			}, @1, @4);
		}
	| VariableIdentifier ':=' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				init: $3,
				autotype: true
			}, @1, @3);
		}
	| VariableIdentifier '=' 'AWAIT' Operand
		{
			$$ = location({
				kind: Kind.AwaitExpression,
				variables: [$1],
				operation: $4
			}, @1, @4);
		}
	| VariableIdentifier '=' Expression
		{
			$$ = location({
				kind: Kind.VariableDeclarator,
				name: $1,
				init: $3
			}, @1, @3);
		}
	;
// }}}

VariableList // {{{
	: VariableList ',' Identifier ColonSeparator TypeVar '=' 'AWAIT' Operand
		{
			$1.push(location({
				kind: Kind.VariableDeclarator,
				name: $2,
				type: $4
			}, @2, @4));
			
			$$ = [location({
				kind: Kind.AwaitExpression,
				variables: $1,
				operation: $7
			}, @1, @7)];
		}
	| VariableList ',' VariableIdentifier '=' 'AWAIT' Operand
		{
			$1.push(location({
				kind: Kind.VariableDeclarator,
				name: $3
			}, @3));
			
			$$ = [location({
				kind: Kind.AwaitExpression,
				variables: $1,
				operation: $6
			}, @1, @6)];
		}
	| VariableList ',' Identifier ColonSeparator TypeVar
		{
			$1.push(location({
				kind: Kind.VariableDeclarator,
				name: $2,
				type: $4
			}, @2, @4));
		}
	| VariableList ',' VariableIdentifier
		{
			$1.push(location({
				kind: Kind.VariableDeclarator,
				name: $3
			}, @3));
		}
	| Identifier ColonSeparator TypeVar
		{
			$$ = [location({
				kind: Kind.VariableDeclarator,
				name: $1,
				type: $3
			}, @1, @3)];
		}
	| VariableIdentifier
		{
			$$ = [location({
				kind: Kind.VariableDeclarator,
				name: $1
			}, @1)];
		}
	;
// }}}

VariableName // {{{
	: VariableName '.' Identifier
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: false,
				nullable: false
			}, @1, @3);
		}
	| VariableName '[' Expression ']'
		{
			$$ = location({
				kind: Kind.MemberExpression,
				object: $1,
				property: $3,
				computed: true,
				nullable: false
			}, @1, @4);
		}
	| Identifier
	;
// }}}

WhileStatement // {{{
	: 'WHILE' Expression Block
		{
			$$ = location({
				kind: Kind.WhileStatement,
				condition: $2,
				body: $3
			}, @1, @3);
		}
	| 'WHILE' Expression '=>' Expression
		{
			$$ = location({
				kind: Kind.WhileStatement,
				condition: $2,
				body: $4
			}, @1, @4);
		}
	;
// }}}

%%

var enums = require('@kaoscript/ast')();
var AssignmentOperator = enums.AssignmentOperator;
var BinaryOperator = enums.BinaryOperator;
var FunctionModifier = enums.FunctionModifier;
var Kind = enums.Kind;
var MemberModifier = enums.MemberModifier;
var ParameterModifier = enums.ParameterModifier;
var ScopeModifier = enums.ScopeModifier;
var UnaryOperator = enums.UnaryOperator;
var VariableModifier = enums.VariableModifier;

var $polyadic = {};
$polyadic[BinaryOperator.Addition] = true;
$polyadic[BinaryOperator.And] = true;
$polyadic[BinaryOperator.Assignment] = false;
$polyadic[BinaryOperator.BitwiseAnd] = false;
$polyadic[BinaryOperator.BitwiseLeftShift] = false;
$polyadic[BinaryOperator.BitwiseOr] = false;
$polyadic[BinaryOperator.BitwiseRightShift] = false;
$polyadic[BinaryOperator.BitwiseXor] = false;
$polyadic[BinaryOperator.Division] = true;
$polyadic[BinaryOperator.Equality] = true;
$polyadic[BinaryOperator.GreaterThan] = true;
$polyadic[BinaryOperator.GreaterThanOrEqual] = true;
$polyadic[BinaryOperator.Inequality] = false;
$polyadic[BinaryOperator.LessThan] = true;
$polyadic[BinaryOperator.LessThanOrEqual] = true;
$polyadic[BinaryOperator.Modulo] = true;
$polyadic[BinaryOperator.Multiplication] = true;
$polyadic[BinaryOperator.NullCoalescing] = true;
$polyadic[BinaryOperator.Or] = true;
$polyadic[BinaryOperator.Subtraction] = true;
$polyadic[BinaryOperator.TypeCasting] = false;
$polyadic[BinaryOperator.TypeEquality] = false;
$polyadic[BinaryOperator.TypeInequality] = false;

var $precedence = {};
$precedence[BinaryOperator.Addition] = 13;
$precedence[BinaryOperator.And] = 6;
$precedence[BinaryOperator.Assignment] = 3;
$precedence[BinaryOperator.BitwiseAnd] = 9;
$precedence[BinaryOperator.BitwiseLeftShift] = 12;
$precedence[BinaryOperator.BitwiseOr] = 7;
$precedence[BinaryOperator.BitwiseRightShift] = 12;
$precedence[BinaryOperator.BitwiseXor] = 8;
$precedence[BinaryOperator.Division] = 14;
$precedence[BinaryOperator.Equality] = 10;
$precedence[BinaryOperator.GreaterThan] = 11;
$precedence[BinaryOperator.GreaterThanOrEqual] = 11;
$precedence[BinaryOperator.Inequality] = 10;
$precedence[BinaryOperator.LessThan] = 11;
$precedence[BinaryOperator.LessThanOrEqual] = 11;
$precedence[BinaryOperator.Modulo] = 14;
$precedence[BinaryOperator.Multiplication] = 14;
$precedence[BinaryOperator.NullCoalescing] = 15;
$precedence[BinaryOperator.Or] = 5;
$precedence[BinaryOperator.Subtraction] = 15;
$precedence[BinaryOperator.TypeCasting] = 11;
$precedence[BinaryOperator.TypeEquality] = 11;
$precedence[BinaryOperator.TypeInequality] = 11;

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
					
					if(operator.kind === Kind.BinaryOperator) {
						left = operations[k - 1];
						
						if(left.kind === Kind.BinaryOperator && operator.operator.kind === left.operator.kind && $polyadic[operator.operator.kind]) {
							operator.kind = Kind.PolyadicOperator;
							operator.start = left.start;
							
							operator.operands = [left.left, left.right, operations[k + 1]];
						}
						else if(left.kind === Kind.PolyadicOperator && operator.operator.kind === left.operator.kind) {
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

function strip(value, regex, replacement) { // {{{
	return value.replace(regex, function() {
		return replacement;
	});
}; // }}}

parser.parseError = function(error, hash) { // {{{
	throw new Error('Unexpected \'' + hash.text.replace(/\n/g, '\\n') + '\' at line ' + hash.loc.last_line + ' and column ' + (hash.loc.last_column + 1));
}; // }}}