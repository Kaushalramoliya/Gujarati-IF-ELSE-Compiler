import sys
sys.stdout.reconfigure(encoding='utf-8')

def is_number(s):
    try:
        int(s)
        return True
    except:
        return False

variables = {}
labels = {}
instructions = []

out = open("final_output.txt", "w", encoding="utf-8")

with open("optimize.txt", "r", encoding="utf-8") as f:
    lines = [line.strip() for line in f if line.strip()]

for idx, line in enumerate(lines):
    if line.endswith(":"):
        label = line[:-1]
        labels[label] = idx
    instructions.append(line)

i = 0
while i < len(instructions):
    line = instructions[i]

    if line.endswith(":"):
        i += 1
        continue

    if line.startswith("print"):
        rest = line[len("print"):].strip()

        if "," in rest:
            text_part, var = rest.split(",", 1)
            text_part = text_part.strip()
            var = var.strip()
            if text_part.startswith('"') and text_part.endswith('"'):
                text_part = text_part[1:-1]
            value = variables.get(var)
            if value is None:
                out.write(f"{text_part} undefined\n")
            else:
                out.write(f"{text_part} {value}\n")

        else:
            arg = rest
            if arg.startswith('"') and arg.endswith('"'):
                out.write(arg[1:-1] + "\n")
            else:
                value = variables.get(arg)
                if value is None:
                    out.write(f"{arg} undefined\n")
                else:
                    out.write(str(value) + "\n")

        i += 1
        continue

    if line.startswith("if"):
        parts = line.replace("if", "").replace("goto", "").strip().split()
        v1, op, v2, lbl = parts[0], parts[1], parts[2], parts[3]
        val1 = variables.get(v1, int(v1) if is_number(v1) else 0)
        val2 = variables.get(v2, int(v2) if is_number(v2) else 0)
        jump = {
            '>' : val1 > val2,
            '<' : val1 < val2,
            '==' : val1 == val2,
            '!=' : val1 != val2,
            '>=' : val1 >= val2,
            '<=' : val1 <= val2,
        }[op]
        i = labels[lbl] if jump else i+1
        continue

    if line.startswith("goto"):
        lbl = line.split()[1]
        i = labels[lbl]
        continue

    if "=" in line:
        var, expr = line.split("=", 1)
        var = var.strip(); expr = expr.strip()
        for k in sorted(variables, key=lambda x: -len(x)):
            expr = expr.replace(k, str(variables[k]))
        try:
            variables[var] = eval(expr)
        except:
            variables[var] = expr
        i += 1
        continue

out.close()
