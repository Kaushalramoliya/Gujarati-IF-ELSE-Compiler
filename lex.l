%{
#include "yacc.tab.h"
#include <string.h>
%}

%%

"પૂર્ણાંક"         return INT;       
"વિશિષ્ટ પૂર્ણાંક"  return FLOAT;    

"જો"               return IF;
"તો"               return THEN;
"નહિંતર"          return ELSE;
"છાપો"            return PRINT;      

"<="               return LE;
">="               return GE;
"=="               return EQ;
"!="               return NE;
"<"                return '<';
">"                return '>';

"="                return '=';
";"                return ';';
","                return ',';        
"("                return '(';
")"                return ')';
"{"                return '{';        
"}"                return '}';        

"\""([^"\n])*"\""  { 
                      yylval.str = strdup(yytext);
                      return STRING;
                   }

"+"                return '+';
"-"                return '-';
"*"                return '*';
"/"                return '/';

[0-9]+             { yylval.str = strdup(yytext); return NUMBER; }
[a-zA-Z_][a-zA-Z0-9_]*  { yylval.str = strdup(yytext); return ID; }

[ \t\n]+           {   }
.                  { fprintf(stderr, "Unknown character: %s\n", yytext); }

%%

int yywrap(void) { return 1; }
