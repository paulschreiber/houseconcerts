import js from "@eslint/js";
import { importX } from "eslint-plugin-import-x";
import globals from "globals";
import eslintConfigPrettier from "eslint-config-prettier";

export default [
  js.configs.recommended,
  importX.flatConfigs.recommended,
  eslintConfigPrettier,
  {
    files: ["app/javascript/**/*.js"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
      },
    },
    rules: {
      // Importmap pins (e.g. "@hotwired/stimulus", "controllers") resolve via
      // config/importmap.rb / the browser importmap, not node_modules - this
      // rule can't see those, so it can't be used here.
      "import-x/no-unresolved": "off",
      semi: ["error", "always"],
      quotes: ["error", "double"],
      "no-unused-vars": [
        "error",
        {
          vars: "all",
          args: "none",
        },
      ],
      "import-x/order": [
        "error",
        {
          alphabetize: {
            order: "asc",
            caseInsensitive: true,
          },
          groups: [["builtin", "external", "internal"]],
        },
      ],
    },
  },
];
