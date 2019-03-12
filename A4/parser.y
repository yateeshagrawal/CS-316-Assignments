%{
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	extern "C" void yyerror(const char *s);
	extern int yylex(void);
	extern int yylineno;
	Symbol_Table* global_sym_table = new Symbol_Table();
	Symbol_Table* local_sym_table = new Symbol_Table();
%}

%union {
	int integer_value;
	double double_value;
	std::string * string_value;
	list<Ast *> * ast_list;
	Ast * ast;
	Symbol_Table * symbol_table;
	Symbol_Table_Entry * symbol_entry;
	Basic_Block * basic_block;
	Procedure * procedure;
	list<Symbol_Table_Entry *> * symbol_entry_list;
}

%token <integer_value> INTEGER_NUMBER
%token <double_value> DOUBLE_NUMBER
%token <string_value> NAME
%token BBNUM  RETURN  INTEGER  FLOAT  ASSIGN  VOID  UMINUS
%token WHILE IF DO ELSE
%token EQUAL LESS_THAN GREATER_THAN LESS_THAN_EQUAL GREATER_THAN_EQUAL NOT_EQUAL
%token AND OR NOT

%type <symbol_entry_list> variable_list	declaration	variable_declaration variable_declaration_list optional_variable_declaration_list
%type <procedure> procedure_definition
%type <ast>	assignment_statement arith_expression 
%type <ast> log_expression rel_expression iteration_statement control_statement 
%type <ast> selection_statement matched_statement matched_statement2 unmatched_statement

%type <ast_list> statement_list



%right ASSIGN
%right '?'
%left OR
%left AND
%left EQUAL NOT_EQUAL
%left LESS_THAN GREATER_THAN LESS_THAN_EQUAL GREATEAR_THAN_EQUAL
%left '+' '-'
%left '*' '/'
%right UMINUS
%right NOT




%start program

%%

program					:	global_variable_declaration_list procedure_definition
							{
								(*global_sym_table).set_table_scope(global);
								program_object.set_global_table(*global_sym_table);
								program_object.set_procedure($2, yylineno);
							}
							; 

procedure_definition	:	VOID NAME '(' ')'
                  	   		'{'
									local_variable_declaration_list statement_list
        	           		'}' 
							{	
								$$ = new Procedure(void_data_type,*$2, yylineno);
								(*local_sym_table).set_table_scope(local);
								(*$$).set_local_list((*local_sym_table));
								(*$$).set_ast_list(*($7));
							}
        	           		;


global_variable_declaration_list	: 	optional_variable_declaration_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$1).begin(); it != (*$1).end(); it++) {
												(*it)->set_symbol_scope(global);
												Symbol_Table x;
												x.push_symbol(*it);
												x.set_table_scope(global);
												(*global_sym_table).append_list(x, (*it)->get_lineno());
											}
										}
										;

local_variable_declaration_list		: 	optional_variable_declaration_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$1).begin(); it != (*$1).end(); it++) {
												(*it)->set_symbol_scope(local);
												Symbol_Table x;
												x.push_symbol(*it);
												x.set_table_scope(local);
												(*local_sym_table).append_list(x, (*it)->get_lineno());
											}
										}
										;
								
optional_variable_declaration_list	:	/* empty */ 
										{
											$$ = new list<Symbol_Table_Entry *>();
										}
										|	variable_declaration_list
										{
											$$ = $1;
										}
										;

variable_declaration_list			:	variable_declaration
										{
											$$ = $1;
										}
										|	variable_declaration_list variable_declaration
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*($1)).push_back(*it);
											}
											$$ = $1;
										}
										;

variable_declaration				:	declaration ';'
										{
											$$ = $1;
										}
										;

declaration							:	INTEGER variable_list
										{
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*it)->set_data_type(int_data_type);
											}
											$$ = $2;
										}
										| FLOAT variable_list 
										{	
											for(list<Symbol_Table_Entry*>::iterator it = (*$2).begin(); it != (*$2).end(); it++) {
												(*it)->set_data_type(double_data_type);
											}
											$$ = $2;
										}
                                        ;

variable_list                       :	NAME	
										{
											$$ = new list<Symbol_Table_Entry *>();
											Symbol_Table_Entry* a = new Symbol_Table_Entry(*$1,int_data_type,yylineno);
											(*$$).push_back(a);
										}
										| variable_list ',' NAME
										{
											Symbol_Table_Entry* b = new Symbol_Table_Entry(*$3,int_data_type,yylineno);
											(*$1).push_back(b); /* TODO: Clarify from the TA */
											$$ = $1;
										}
										;


statement_list	        :	/* empty */ 
							{
								$$ = new list<Ast *>();
							}
							|	statement_list assignment_statement
							{
								(*$1).push_back($2);
								$$ = $1;
							}
							|	statement_list control_statement /*added control statement */
							{
								(*$1).push_back($2);
								$$ = $1;
							}
							;

control_statement		:	iteration_statement /*while, do-while*/
							{
								$$ = $1;
							}
							|	selection_statement /*if then else*/
							{
								$$ = $1;
							}
							;



/*
while() {
	stmts;
}
or 
while()
stmt;
or
do() {
	stmts;
}
*/
iteration_statement		:	WHILE '(' log_expression ')' 
							'{'
							statement_list
							'}'
							{

								if((*$6).empty()) /*body empty */
								{
									yyerror("cs316: Error: Block of statements cannot be empty");
									exit(1);
								}
								Sequence_Ast *x = new Sequence_Ast(yylineno);
								for(list<Ast*>::iterator it = (*$6).begin(); it != (*$6).end(); it++) {
									x->ast_push_back(*it);
								}
								$$ = new Iteration_Statement_Ast($3, x, yylineno, 0); /*last arg is bool do_form */

								/* $$->print(cout); */
							}
							|	WHILE '(' log_expression ')' assignment_statement
							{
								Sequence_Ast *x = new Sequence_Ast(yylineno);
								x->ast_push_back($5);
							}
							|	WHILE '(' log_expression ')' control_statement
							{
								Sequence_Ast *x = new Sequence_Ast(yylineno);
								x->ast_push_back($5);
							}
							|	DO '{' statement_list '}' WHILE '(' log_expression ')' ';'
							{
								if($3->empty()) /*body empty */
								{
									yyerror("cs316: Error: Block of statements cannot be empty");
									exit(1);
								}
								Sequence_Ast *x = new Sequence_Ast(yylineno);
								for(list<Ast*>::iterator it = (*$3).begin(); it != (*$3).end(); it++) {
									x->ast_push_back(*it);
								}
								$$ = new Iteration_Statement_Ast($7, x, yylineno, 1); /*last arg is bool do_form */	
							}
							;


/*
if-then-else
with or without braces
*/

selection_statement		:	IF '(' log_expression ')'
							'{' statement_list '}'
							{
								if($6->empty()) /*body empty */
								{
									yyerror("cs316: Error: Block of statements cannot be empty");
									exit(1);
								}
								Sequence_Ast *x = new Sequence_Ast(yylineno);
								for(list<Ast*>::iterator it = (*$6).begin(); it != (*$6).end(); it++) {
									x->ast_push_back(*it);
								}
								$$ = new Selection_Statement_Ast($3, x, NULL, yylineno);
							}
							|	IF '(' log_expression ')'
							'{' statement_list '}'
							ELSE '{' statement_list '}'
							{
								if($6->empty() || $10->empty()) /*body empty */
								{
									yyerror("cs316: Error: Block of statements cannot be empty");
									exit(1);
								}
								Sequence_Ast *x = new Sequence_Ast(yylineno);
								for(list<Ast*>::iterator it = (*$6).begin(); it != (*$6).end(); it++) {
									x->ast_push_back(*it);
								}

								Sequence_Ast *y = new Sequence_Ast(yylineno);
								for(list<Ast*>::iterator it = (*$10).begin(); it != (*$10).end(); it++) {
									y->ast_push_back(*it);
								}

								$$ = new Selection_Statement_Ast($3, x, y, yylineno);
							}

					/*
							|	matched_statement
							{
								$$ = $1;
							}
							|	unmatched_statement 
							{
								$$ = $1;
							}
							

matched_statement		:	IF '(' log_expression ')' matched_statement2 ELSE matched_statement2
							{
								$$ = new Selection_Statement_Ast($2, $3, $5, yylineno);
							}

							*/
/*
selection_statement		:	matched_statement
							{
								$$ = $1;
							}
							| unmatched_statement
							{
								$$ = $1;
							}


matched_statement		:	IF log_expression matched_statement2 ELSE matched_statement2
							{
								$$ = new Selection_Statement_Ast($2, $3, $5, yylineno);
							}

matched_statement2		:	matched_statement
							{
								$$ = $1;
							}
							|	statement_list
							{
								x = new Sequence_Ast(yylineno);
								for(list<Ast*>::iterator it = (*$1).begin(); it != (*$1).end(); it++) {
									x->ast_push_back(*it);
								}
								$$ = x;
							}

unmatched_statement		:	IF log_expression selection_statement 
							{
								$$ = new Selection_Statement_Ast($2, $3, NULL, yylineno);
							}
							|	IF log_expression matched_statement else unmatched_statement
							{
								$$ = new Selection_Statement_Ast($2, $3, $5, yylineno);	
							}

*/

log_expression			:	log_expression AND log_expression
							{
								$$ = new Logical_Expr_Ast($1, _logical_and, $3, yylineno);
								(*$$).check_ast();
							}
							|	log_expression OR log_expression
							{
								$$ = new Logical_Expr_Ast($1, _logical_or, $3, yylineno);
								(*$$).check_ast();
							}
							|	NOT log_expression
							{
								$$ = new Logical_Expr_Ast(NULL, _logical_not, $2, yylineno);
								(*$$).check_ast();
							}
							|	rel_expression
							{
								$$ = $1;
								(*$$).check_ast();
							}
							|	'(' log_expression ')'
							{
								$$ = $2;
							}
							;

rel_expression			:	arith_expression EQUAL arith_expression
							{
								$$ = new Relational_Expr_Ast($1, equalto, $3, yylineno);
								(*$$).check_ast();
							}
							|	arith_expression NOT_EQUAL arith_expression
							{
								$$ = new Relational_Expr_Ast($1, not_equalto, $3, yylineno);
								(*$$).check_ast();
							}
							|	arith_expression LESS_THAN arith_expression
							{
								$$ = new Relational_Expr_Ast($1, less_than, $3, yylineno);
								(*$$).check_ast();
							}
							|	arith_expression LESS_THAN_EQUAL arith_expression
							{
								$$ = new Relational_Expr_Ast($1, less_equalto, $3, yylineno);
								(*$$).check_ast();
							}	
							|	arith_expression GREATER_THAN arith_expression
							{
								$$ = new Relational_Expr_Ast($1, greater_than, $3, yylineno);
								(*$$).check_ast();
							}
							|	arith_expression GREATER_THAN_EQUAL arith_expression
							{
								$$ = new Relational_Expr_Ast($1, greater_equalto, $3, yylineno);
								(*$$).check_ast();
							}
							|	'(' rel_expression ')'
							{
								$$ = $2;
							}

							;



assignment_statement	:	NAME ASSIGN arith_expression ';'
				
							{
								if(!(*local_sym_table).is_empty() && (*local_sym_table).variable_in_symbol_list_check(*$1)){ 
									Ast* lhs1 = new Name_Ast(*$1, (*local_sym_table).get_symbol_table_entry(*$1), yylineno);
									$$ = new Assignment_Ast(lhs1,$3,yylineno);
									(*$$).check_ast();
								}
								else if(!(*global_sym_table).is_empty() && (*global_sym_table).variable_in_symbol_list_check(*$1)){
									Ast* lhs2 = new Name_Ast(*$1, (*global_sym_table).get_symbol_table_entry(*$1), yylineno);
									$$ = new Assignment_Ast(lhs2,$3,yylineno);
									(*$$).check_ast();
								}
								else{
									yyerror("cs316: Error: Variable has not been declared");
									exit(1);
								}
							}
							;

arith_expression		: 	INTEGER_NUMBER	
							{
								$$ = new Number_Ast<int>($1, int_data_type, yylineno);
							}
							| DOUBLE_NUMBER 
							{
								$$ = new Number_Ast<double>($1, double_data_type, yylineno);
							}
							| NAME
							{
								if(!(*local_sym_table).is_empty() && (*local_sym_table).variable_in_symbol_list_check(*($1))){
									$$ = new Name_Ast(*$1, (*local_sym_table).get_symbol_table_entry(*$1), yylineno);
								}
								else if(!(*global_sym_table).is_empty() && (*global_sym_table).variable_in_symbol_list_check(*$1)){
									$$ = new Name_Ast(*$1, (*global_sym_table).get_symbol_table_entry(*$1), yylineno);
								}
								else{
									yyerror("cs316: Error : Variable has not been declared");
									exit(1);
								}
							}
							| arith_expression '+' arith_expression
							{
								$$ = new Plus_Ast($1, $3, yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$1).get_data_type());
							}
							| arith_expression '-' arith_expression
							{
								$$ = new Minus_Ast($1, $3, yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$1).get_data_type());
							}
							| arith_expression '*' arith_expression
							{
								$$ = new Mult_Ast($1, $3, yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$1).get_data_type());
							}
							| arith_expression '/' arith_expression
							{
								$$ = new Divide_Ast($1, $3, yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$1).get_data_type());
							}
							| '-' arith_expression %prec UMINUS
							{
								$$ = new UMinus_Ast($2,NULL,yylineno);
								(*$$).check_ast();
								(*$$).set_data_type((*$2).get_data_type());
							}
							/*ternary operator*/
							|	log_expression '?' arith_expression ':' arith_expression
							{
								$$ = new Conditional_Expression_Ast($1, $3, $5, yylineno);
							}
							| '('arith_expression')'
							{
								$$ = $2;
							}
							;
%%