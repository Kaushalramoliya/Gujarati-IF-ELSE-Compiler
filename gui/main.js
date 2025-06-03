const { app, BrowserWindow, ipcMain } = require("electron");
const path = require("path");
const fs = require("fs");
const { execSync } = require("child_process");

function createWindow() {
  const win = new BrowserWindow({
    width: 1200,
    height: 800,
    icon: path.join(__dirname, 'logo1.png'),
    webPreferences: {
      preload: path.join(__dirname, "renderer.js"),
      contextIsolation: false,
      nodeIntegration: true
    }
  });

  win.loadFile(path.join(__dirname, "index.html"));
}

ipcMain.handle("run-compiler", async (_, inputCode) => {
  const baseDir = path.join(__dirname, "..");
  fs.writeFileSync(path.join(baseDir, "input.txt"), inputCode, "utf-8");

  try {
    execSync("bison -d yacc.y", { cwd: baseDir });
    execSync("flex lex.l", { cwd: baseDir });
    execSync("gcc lex.yy.c yacc.tab.c -o compiler", { cwd: baseDir });
    execSync("compiler.exe", { cwd: baseDir, shell: true });
    execSync("gcc codegen.c -o codegen", { cwd: baseDir });
    execSync("codegen.exe", { cwd: baseDir, shell: true });
    execSync("python interpreter.py", { cwd: baseDir });
  } catch (err) {
    return { console: err.message, files: {} };
  }

  let finalOutput = "";
  try {
    finalOutput = fs.readFileSync(path.join(baseDir, "final_output.txt"), "utf-8");
  } catch {
    finalOutput = "[Error] Could not read final_output.txt";
  }

  const files = {};
  for (const name of ["output.txt", "optimize.txt", "assembly.txt"]) {
    try {
      files[name] = fs.readFileSync(path.join(baseDir, name), "utf-8");
    } catch {
      files[name] = "Error reading file.";
    }
  }

  return {
    console: finalOutput,
    files
  };
});

app.whenReady().then(createWindow);
