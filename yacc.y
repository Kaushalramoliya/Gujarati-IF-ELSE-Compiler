%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern FILE *yyin, *yyout;
int yylex(void);
void yyerror(char *s);

int tempCount = 1, labelCount = 1;

typedef struct {
    char *name;
    char *type;       
    int   initialized;
} Symbol;

#define MAXSYM 128
Symbol symtab[MAXSYM];
int    symcount = 0;

void addSymbol(char *name, char *type) {
    for(int i=0;i<symcount;i++)
        if(strcmp(symtab[i].name,name)==0) return;
    symtab[symcount].name        = strdup(name);
    symtab[symcount].type        = strdup(type);
    symtab[symcount].initialized = 0;
    symcount++;
}

int isDeclared(char *name) {
    for(int i=0;i<symcount;i++)
        if(strcmp(symtab[i].name,name)==0) return 1;
    return 0;
}

char* getType(char *name) {
    for(int i=0;i<symcount;i++)
        if(strcmp(symtab[i].name,name)==0) 
            return symtab[i].type;
    return NULL;
}

void markInitialized(char *name) {
    for(int i=0;i<symcount;i++)
        if(strcmp(symtab[i].name,name)==0)
            symtab[i].initialized = 1;
}

int isInitialized(char *name) {
    for(int i=0;i<symcount;i++)
        if(strcmp(symtab[i].name,name)==0)
            return symtab[i].initialized;
    return 0;
}

char* newTemp() {
    char buf[16];
    sprintf(buf,"t%d",tempCount++);
    return strdup(buf);
}

char* newLabel() {
    char buf[16];
    sprintf(buf,"L%d",labelCount++);
    return strdup(buf);
}

typedef struct {
    char  name[32];
    int   value;
    int   known;
} ConstEntry;
#define MAXC 256
ConstEntry cmap[MAXC];
int cmapCount = 0;

void cmap_set(const char *n, int v) {
    for(int i=0;i<cmapCount;i++){
        if(strcmp(cmap[i].name,n)==0){
            cmap[i].value = v; cmap[i].known = 1;
            return;
        }
    }
    strcpy(cmap[cmapCount].name,n);
    cmap[cmapCount].value = v;
    cmap[cmapCount].known = 1;
    cmapCount++;
}

int cmap_get(const char *n, int *out) {
    for(int i=0;i<cmapCount;i++){
        if(strcmp(cmap[i].name,n)==0 && cmap[i].known){
            *out = cmap[i].value;
            return 1;
        }
    }
    return 0;
}

void optimize() {
    FILE *fin  = fopen("output.txt","r");
    FILE *fout = fopen("optimize.txt","w");
    char line[256];
    while(fgets(line,sizeof(line),fin)){
        char lhs[32], op1[32], op2[32], oper[4], lbl[32];
        int  num;

        /* Case 1:  t = <const> */
        if(sscanf(line,"%31s = %d", lhs, &num)==2) {
            cmap_set(lhs, num);
            fprintf(fout,"%s = %d\n", lhs, num);

        /* Case 2:  t = x + y  (or -,*,/) */
        } else if(sscanf(line,"%31s = %31s %3s %31s", lhs, op1, oper, op2)==4) {
            int v1, v2, k1, k2;
            k1 = cmap_get(op1,&v1);
            k2 = cmap_get(op2,&v2);

            if(k1 && k2) {
                /* fold */
                int r = 0;
                if     (strcmp(oper,"+")==0) r = v1+v2;
                else if(strcmp(oper,"-")==0) r = v1-v2;
                else if(strcmp(oper,"*")==0) r = v1*v2;
                else if(strcmp(oper,"/")==0) r = v1/v2;
                cmap_set(lhs,r);
                fprintf(fout,"%s = %d\n", lhs, r);
            } else {
                /* substitute known */
                if(k1) sprintf(op1,"%d",v1);
                if(k2) sprintf(op2,"%d",v2);
                fprintf(fout,"%s = %s %s %s\n", lhs, op1, oper, op2);
            }

        /* Case 3: if‐goto with a constant */
        } else if(sscanf(line,"if %31s %3s %31s goto %31s", op1, oper, op2, lbl)==4){
            int v2, k2 = cmap_get(op2,&v2);
            if(k2) fprintf(fout,"if %s %s %d goto %s\n", op1, oper, v2, lbl);
            else  fprintf(fout,"%s",line);

        /* default: copy label, goto, etc. */
        } else {
            fprintf(fout,"%s",line);
        }
    }
    fclose(fin);
    fclose(fout);
}
%}

%union {
    char* str;
}

%token <str> ID NUMBER STRING
%token IF THEN ELSE PRINT
%token LE GE EQ NE
%token INT FLOAT

%type <str> type E stmt condop statement stmts stmt_block

%%

program:
    stmts
  ;

stmts:
      stmts statement
    | /* empty */
  ;

stmt_block:
      stmt
    | '{' stmts '}'    { /* nothing */ }
  ;

statement:
    IF '(' E condop E ')' THEN stmt_block ELSE stmt_block
    {
        char thenID[64], thenT[64], elseID[64], elseT[64];
        sscanf($8, "%[^,],%s", thenID, thenT);
        sscanf($10, "%[^,],%s", elseID, elseT);

        char *L1=newLabel(), *L2=newLabel(), *L3=newLabel();

        fprintf(yyout,"if %s %s %s goto %s\n", $3,$4,$5,L1);
        fprintf(yyout,"goto %s\n", L2);

        fprintf(yyout,"%s:\n", L1);
        fprintf(yyout,"%s = %s\n", thenID, thenT);
        fprintf(yyout,"goto %s\n", L3);

        fprintf(yyout,"%s:\n", L2);
        fprintf(yyout,"%s = %s\n", elseID, elseT);

        fprintf(yyout,"%s:\n", L3);

        $$ = NULL;
    }
  | stmt
    { $$ = $1; }
  ;

stmt:
      type ID '=' E ';'
    {
        if($4[0]=='"') {
            fprintf(stderr,
              "Semantic Error: cannot assign string literal to %s variable '%s'\n",
              $1, $2);
            exit(1);
        }
        if (!isDeclared($2)) addSymbol($2, $1);
        markInitialized($2);
        fprintf(yyout, "%s = %s\n", $2, $4);
        size_t n = strlen($2) + strlen($4) + 2;
        char *buf = malloc(n);
        sprintf(buf, "%s,%s", $2, $4);
        $$ = buf;
    }
  | ID '=' E ';'
    {
        if (!isDeclared($1)) {
            fprintf(stderr,"Semantic Error: '%s' undeclared\n",$1);
            exit(1);
        }
        if($3[0]=='"') {
            char *vt = getType($1);
            fprintf(stderr,
              "Semantic Error: cannot assign string literal to %s variable '%s'\n",
              vt, $1);
            exit(1);
        }
        markInitialized($1);
        fprintf(yyout,"%s = %s\n", $1, $3);
        size_t n = strlen($1) + strlen($3) + 2;
        char *buf = malloc(n);
        sprintf(buf,"%s,%s",$1,$3);
        $$ = buf;
    }
  | PRINT STRING ',' ID ';'
    {
        fprintf(yyout,"print %s, %s\n", $2, $4);
        $$ = NULL;
    }
  | PRINT STRING ';'
    {
        fprintf(yyout,"print %s\n", $2);
        $$ = NULL;
    }
  ;

condop:
      '<'       { $$ = "<"; }
    | '>'       { $$ = ">"; }
    | LE        { $$ = "<="; }
    | GE        { $$ = ">="; }
    | EQ        { $$ = "=="; }
    | NE        { $$ = "!="; }
  ;

E:
      E '+' E
    {
        char *t=newTemp();
        fprintf(yyout,"%s = %s + %s\n",t,$1,$3);
        $$ = t;
    }
  | E '-' E
    {
        char *t=newTemp();
        fprintf(yyout,"%s = %s - %s\n",t,$1,$3);
        $$ = t;
    }
  | E '*' E
    {
        char *t=newTemp();
        fprintf(yyout,"%s = %s * %s\n",t,$1,$3);
        $$ = t;
    }
  | E '/' E
    {
        char *t=newTemp();
        fprintf(yyout,"%s = %s / %s\n",t,$1,$3);
        $$ = t;
    }
  | '(' E ')'
        { $$ = $2; }
  | ID
    {
        if (!isDeclared($1)) {
            fprintf(stderr,"Semantic Error: '%s' undeclared\n",$1);
            exit(1);
        }
        if (!isInitialized($1)) {
            fprintf(stderr,"Semantic Error: '%s' uninitialized\n",$1);
            exit(1);
        }
        $$ = $1;
    }
  | NUMBER
    {
        char *t=newTemp();
        fprintf(yyout,"%s = %s\n",t,$1);
        $$ = t;
    }
  | STRING
    {
        $$ = $1;
    }
  ;

type:
      INT   { $$ = "int";   }
    | FLOAT { $$ = "float"; }
  ;

%%

int main(void) {
    yyin  = fopen("input.txt","r");
    yyout = fopen("output.txt","w");
    if (!yyin || !yyout) { perror("fopen"); return 1; }

    yyparse();

    fclose(yyin);
    fclose(yyout);

    printf("DONE\n");

    optimize();

    return 0;
}

void yyerror(char *s) {
    fprintf(stderr,"Parse error: %s\n",s);
    exit(1);
}
