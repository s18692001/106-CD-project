%{

#include <iostream>
#include "symbols.hpp"
#include "lex.yy.cpp"

#define Trace(t) if (Opt_P) cout << "TRACE => " << t << endl;

int Opt_P = 1;
void yyerror(string s);

SymbolTableList symbols;

%}

/* yylval */
%union {
  int ival;
  double dval;
  bool bval;
  string *sval;
  idInfo* info;
  int type;
}

/* tokens */
%token INC DEC LE GE EQ NEQ AND OR ADD SUB MUL DIV 
%token BOOL BREAK CHAR CONTINUE DO ELSE ENUM EXTERN FLOAT FOR FN IF IN INT LET LOOP MATCH MUT PRINT PRINTLN PUB RETURN SELF STATIC STR STRUCT USE WHERE WHILE
%token <ival> INT_CONST
%token <dval> REAL_CONST
%token <bval> BOOL_CONST
%token <sval> STR_CONST
%token <sval> ID

/* type for non-terminal */
%type <info> const_value expression func_invocation
%type <type> var_type

/* precedence */
%left OR
%left AND
%left '!'
%left '<' LE EQ GE '>' NEQ
%left '+' '-'
%left '*' '/'
%nonassoc UMINUS

%%

/* program */
program                 : opt_var_dec opt_func_dec
                        {
                          Trace("program");
                        }
                        ;

/* zero or more variable and constant declarations */
opt_var_dec             : var_dec opt_var_dec
                        | const_dec opt_var_dec
                        | /* zero */
                        ;

/* constant declaration */
const_dec               : LET ID ':' var_type '=' expression ';'
                        {
                          Trace("constant declaration with type");

                          if (!isConst(*$6)) yyerror("Error: expression not constant value"); /* constant check */
                          if ($4 != $6->type) yyerror("Error: type not match"); /* type check */

                          $6->flag = constVariableFlag;
                          if (symbols.insert(*$2, *$6) == -1) yyerror("Error: constant redefinition"); /* symbol check */
                        }
                        | LET ID '=' expression ';'
                        {
                          Trace("constant declaration");

                          if (!isConst(*$4)) yyerror("Error: expression not constant value"); /* constant check */

                          $4->flag = constVariableFlag;
                          if (symbols.insert(*$2, *$4) == -1) yyerror("Error: constant redefinition"); /* symbol check */
                        }
                        ;

/* variable declaration */
var_dec                 : LET MUT ID ':' var_type '=' expression ';'
                        {
                          Trace("variable declaration with type and expression");
                        }
                        | LET MUT ID ':' var_type ';'
                        {
                          Trace("variable declaration with type");
                        }
                        | LET MUT ID '=' expression ';'
                        {
                          Trace("variable declaration with expression");
                        }
                        | LET MUT ID ';'
                        {
                          Trace("variable declaration");
                        }
                        | LET MUT ID '[' var_type ',' expression ']' ';'
                        {
                          Trace("array declaration");
                        }
                        ;

/* variable type */
var_type                : STR
                        | INT
                        | BOOL
                        | FLOAT
                        ;

/* one or more function declaration */
opt_func_dec            : func_dec opt_func_dec
                        | func_dec /* one */
                        ;

/* function declaration */
func_dec                : FN ID '(' opt_args ')' '-' '>' var_type '{' opt_var_dec opt_statement '}'
                        {
                          Trace("function declaration with return type");
                        }
                        | FN ID '(' opt_args ')' '{' opt_var_dec opt_statement '}'
                        {
                          Trace("function declaration");
                        }
                        ;

/* zero or more arguments */
opt_args                : args
                        | /* zero */
                        ;

/* arguments */
args                    : arg ',' args
                        | arg
                        ; 

/* argument */
arg                     : ID ':' var_type
                        ;

/* one or more statements */
opt_statement           : statement opt_statement
                        | statement /* one */
                        ;

/* statement */
statement               : simple
                        | block
                        | conditional
                        | loop
                        | func_invocation
                        ;

/* simple */
simple                  : ID '=' expression ';'
                        {
                          Trace("statement: variable assignment");
                        }
                        | ID '[' expression ']' '=' expression ';'
                        {
                          Trace("statement: array assignment");
                        }
                        | PRINT expression ';'
                        {
                          Trace("statement: print expression");
                        }
                        | PRINTLN expression ';'
                        {
                          Trace("statement: println expression");
                        }
                        | RETURN expression ';'
                        {
                          Trace("statement: return expression");
                        }
                        | RETURN ';'
                        {
                          Trace("statement: return");
                        }
                        | expression ';'
                        {
                          Trace("statement: expression");
                        }
                        ;

/* block */
block                   : '{' opt_var_dec opt_statement '}'
                        ;

/* conditional */
conditional             : IF '(' expression ')' block ELSE block
                        {
                          Trace("statement: if else");
                        }
                        | IF '(' expression ')' block
                        {
                          Trace("statement: if");
                        }
                        ;

/* loop */
loop                    : WHILE '(' expression ')' block
                        {
                          Trace("statement: while loop");
                        }
                        ;

/* function invocation */
func_invocation         : ID '(' opt_comma_separated ')'
                        {
                          Trace("statement: function invocation");
                        }
                        ;

/* optional comma-separated expressions */
opt_comma_separated     : comma_separated
                        | /* zero */
                        ;

/* comma-separated expressions */
comma_separated         : expression ',' comma_separated
                        | expression /* func_expression */
                        ;

/* constant value */
const_value             : INT_CONST
                        {
                          $$ = intConst($1);
                        }
                        | REAL_CONST
                        {
                          $$ = realConst($1);
                        }
                        | BOOL_CONST
                        {
                          $$ = boolConst($1);
                        }
                        | STR_CONST
                        {
                          $$ = strConst($1);
                        }
                        ;

/* expression */
expression              : ID
                        {
                          idInfo *info = symbols.lookup(*$1);
                          if (info == NULL) yyerror("undeclared indentifier"); /* declaration check */
                          $$ = info;
                        }
                        | const_value
                        | ID '[' expression ']'
                        | func_invocation
                        | '-' expression %prec UMINUS
                        {
                          Trace("-expression");

                          if ($2->type != intType && $2->type != realType) yyerror("operator error"); /* operator check */

                          idInfo *info = new idInfo();
                          info->flag = variableFlag;
                          info->type = $2->type;
                          $$ = info;
                        }
                        | expression '*' expression
                        {
                          Trace("expression * expression");
                        }
                        | expression '/' expression
                        {
                          Trace("expression / expression");
                        }
                        | expression '+' expression
                        {
                          Trace("expression + expression");
                        }
                        | expression '-' expression
                        {
                          Trace("expression - expression");
                        }
                        | expression '<' expression
                        {
                          Trace("expression < expression");
                        }
                        | expression LE expression
                        {
                          Trace("expression <= expression");
                        }
                        | expression EQ expression
                        {
                          Trace("expression == expression");
                        }
                        | expression GE expression
                        {
                          Trace("expression >= expression");
                        }
                        | expression '>' expression
                        {
                          Trace("expression > expression");
                        }
                        | expression NEQ expression
                        {
                          Trace("expression != expression");
                        }
                        | '!' expression
                        {
                          Trace("!expression");
                        }
                        | expression AND expression
                        {
                          Trace("expression && expression");
                        }
                        | expression OR expression
                        {
                          Trace("expression || expression");
                        }
                        | '(' expression ')'
                        {
                          Trace("(expression)");
                        }
                        ;

%%

void yyerror(string s) {
  cerr << "line " << linenum << ": " << s << endl;
  exit(1);
}

int main(void) {
  yyparse();
  return 0;
}
