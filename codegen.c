#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static int reg_count = 1;

char* get_register() {
    char buf[16];
    sprintf(buf, "R%d", reg_count++);
    return strdup(buf);
}

char* lookup_reg(const char *sym, char map[][2][20], int count) {
    for (int i = 0; i < count; i++) {
        if (strcmp(map[i][0], sym) == 0) {
            return map[i][1];
        }
    }
    return NULL;
}

int main(void) {
    FILE *fin  = fopen("optimize.txt", "r");
    FILE *fout = fopen("assembly.txt", "w");
    if (!fin || !fout) {
        perror("File open error");
        return 1;
    }

    char line[256];
    char varmap[100][2][20]; 
    int varcount = 0;

    while (fgets(line, sizeof(line), fin)) {
        char lhs[32], a[32], op[4], b[32], lbl[32];
        int num;

        if (sscanf(line, "print %31s , %31s", lhs, a) == 2) {
            char *Rv = lookup_reg(a, varmap, varcount);
            if (!Rv) {
                Rv = get_register();
                fprintf(fout, "MOV %s, %s\n", Rv, a);
                strcpy(varmap[varcount][0], a);
                strcpy(varmap[varcount][1], Rv);
                varcount++;
            }
            fprintf(fout, "PRINT %s, %s\n", lhs, Rv);
            continue;
        }

        if (sscanf(line, "%31s = %31s %3s %31s", lhs, a, op, b) == 4) {
            char *Ra = lookup_reg(a, varmap, varcount);
            if (!Ra) {
                Ra = get_register();
                fprintf(fout, "MOV %s, %s\n", Ra, a);
            }
            char *Rb = lookup_reg(b, varmap, varcount);
            if (!Rb) {
                if (isdigit((unsigned char)b[0])) {
                    Rb = get_register();
                    fprintf(fout, "MOV %s, %s\n", Rb, b);
                } else {
                    Rb = get_register();
                    fprintf(fout, "MOV %s, %s\n", Rb, b);
                }
            }
            char *Rt = get_register();
            if (strcmp(op, "+") == 0)      fprintf(fout, "ADD %s, %s, %s\n", Rt, Ra, Rb);
            else if (strcmp(op, "-") == 0) fprintf(fout, "SUB %s, %s, %s\n", Rt, Ra, Rb);
            else if (strcmp(op, "*") == 0) fprintf(fout, "MUL %s, %s, %s\n", Rt, Ra, Rb);
            else if (strcmp(op, "/") == 0) fprintf(fout, "DIV %s, %s, %s\n", Rt, Ra, Rb);

            strcpy(varmap[varcount][0], lhs);
            strcpy(varmap[varcount][1], Rt);
            varcount++;
        }
        else if (sscanf(line, "%31s = %d", lhs, &num) == 2) {
            char *Rt = get_register();
            fprintf(fout, "MOV %s, %d\n", Rt, num);
            strcpy(varmap[varcount][0], lhs);
            strcpy(varmap[varcount][1], Rt);
            varcount++;
        }
        else if (sscanf(line, "%31s = %31s", lhs, a) == 2) {
            char *Rs = lookup_reg(a, varmap, varcount);
            if (!Rs) {
                Rs = get_register();
                fprintf(fout, "MOV %s, %s\n", Rs, a);
            }
            char *Rd = get_register();
            fprintf(fout, "MOV %s, %s\n", Rd, Rs);
            strcpy(varmap[varcount][0], lhs);
            strcpy(varmap[varcount][1], Rd);
            varcount++;
        }
        else if (sscanf(line, "if %31s %3s %31s goto %31s", a, op, b, lbl) == 4) {
            char *Ra = lookup_reg(a, varmap, varcount);
            if (!Ra) {
                Ra = get_register();
                fprintf(fout, "MOV %s, %s\n", Ra, a);
            }
            if (sscanf(b, "%d", &num) == 1) {
                fprintf(fout, "CMP %s, %d\n", Ra, num);
            } else {
                char *Rb = lookup_reg(b, varmap, varcount);
                if (!Rb) {
                    Rb = get_register();
                    fprintf(fout, "MOV %s, %s\n", Rb, b);
                }
                fprintf(fout, "CMP %s, %s\n", Ra, Rb);
            }
            if (strcmp(op, "<") == 0)      fprintf(fout, "JL %s\n", lbl);
            else if (strcmp(op, ">") == 0) fprintf(fout, "JG %s\n", lbl);
            else if (strcmp(op, "==") == 0)fprintf(fout, "JE %s\n", lbl);
            else if (strcmp(op, "!=") == 0)fprintf(fout, "JNE %s\n", lbl);
            else if (strcmp(op, "<=") == 0)fprintf(fout, "JLE %s\n", lbl);
            else if (strcmp(op, ">=") == 0)fprintf(fout, "JGE %s\n", lbl);
        }
        else if (sscanf(line, "goto %31s", lbl) == 1) {
            fprintf(fout, "JMP %s\n", lbl);
        }
        else if (strchr(line, ':')) {
            fprintf(fout, "%s", line);
        }
    }

    fclose(fin);
    fclose(fout);
    printf("Assembly generated in assembly.txt\n");
    return 0;
}