import js from "@eslint/js";
import globals from "globals";

export default [
  { ignores: ["node_modules/**", "gen/**", "**/dist/**", "coverage/**"] },
  js.configs.recommended,
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "commonjs",
      globals: { ...globals.node, ...globals.jest }
    },
    rules: { "no-unused-vars": ["warn", { argsIgnorePattern: "^_" }] }
  },
  {
    // Apps UI5 freestyle (navegador + sap.ui.define)
    files: ["app/**/*.js"],
    languageOptions: {
      sourceType: "script",
      globals: { ...globals.browser, sap: "readonly", jQuery: "readonly" }
    }
  }
];
