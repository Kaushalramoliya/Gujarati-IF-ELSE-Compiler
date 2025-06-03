const { ipcRenderer } = require("electron");

document.getElementById("run-btn").addEventListener("click", async () => {
  const inputCode = document.getElementById("input").value;
  const result = await ipcRenderer.invoke("run-compiler", inputCode);

  document.getElementById("output").value = result.console;

  document.getElementById("output-tab").textContent = result.files["output.txt"] || "No output.txt";
  document.getElementById("optimize-tab")?.remove();
  document.getElementById("assembly-tab")?.remove();

  const optimizeTab = document.createElement("pre");
  optimizeTab.id = "optimize-tab";
  optimizeTab.style.display = "none";
  optimizeTab.textContent = result.files["optimize.txt"] || "No optimize.txt";
  document.getElementById("tab-content").appendChild(optimizeTab);

  const assemblyTab = document.createElement("pre");
  assemblyTab.id = "assembly-tab";
  assemblyTab.style.display = "none";
  assemblyTab.textContent = result.files["assembly.txt"] || "No assembly.txt";
  document.getElementById("tab-content").appendChild(assemblyTab);
});

function showTab(name) {
  document.querySelectorAll("#tab-content pre").forEach(tab => tab.style.display = "none");
  document.getElementById(`${name}-tab`).style.display = "block";
}
