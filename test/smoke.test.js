// Teste mínimo do CI. Quando o modelo (issue #3) existir, ele também valida
// que todos os arquivos .cds compilam. Testes de serviço com cds.test entram depois.
const cds = require("@sap/cds");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const hasCds = (dir) =>
  fs.existsSync(path.join(root, dir)) &&
  fs.readdirSync(path.join(root, dir), { recursive: true }).some((f) => String(f).endsWith(".cds"));

describe("smoke", () => {
  test("@sap/cds carrega", () => {
    expect(cds.version).toBeDefined();
  });

  const modelDirs = ["db", "srv"].filter(hasCds);
  (modelDirs.length ? test : test.skip)("modelo CDS compila", async () => {
    const csn = await cds.load(modelDirs.map((d) => path.join(root, d)));
    expect(csn.definitions).toBeDefined();
  });
});
