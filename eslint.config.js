const js = require("@eslint/js");
const typescript = require("@typescript-eslint/eslint-plugin");
const typescriptParser = require("@typescript-eslint/parser");

module.exports = [
    // Top-level ignores to prevent ESLint from linting its own config and other unwanted files
    {
        ignores: [
            "eslint.config.js",
            ".eslintrc.js",
            "node_modules",
            "build",
            "dist",
            "coverage",
            "typechain-types",
            "circuits",
        ],
    },
    js.configs.recommended,
    {
        files: ["**/*.ts", "**/*.tsx", "**/*.js", "**/*.jsx"],
        languageOptions: {
            parser: typescriptParser,
            parserOptions: {
                project: "./tsconfig.json",
                tsconfigRootDir: ".",
                sourceType: "module",
            },
        },
        plugins: {
            "@typescript-eslint": typescript,
        },
        rules: {
            ...typescript.configs.recommended.rules,
            "@typescript-eslint/interface-name-prefix": "off",
            "@typescript-eslint/explicit-function-return-type": "off",
            "@typescript-eslint/explicit-module-boundary-types": "off",
            "@typescript-eslint/no-explicit-any": "warn",
            "@typescript-eslint/no-unused-expressions": "warn",
        },
    },
    // Add Node and Jest globals for test files
    {
        files: ["**/*.ts", "**/*.js"],
        languageOptions: {
            globals: {
                node: true,
                jest: true,
                describe: "readonly",
                it: "readonly",
                before: "readonly",
                after: "readonly",
                beforeEach: "readonly",
                afterEach: "readonly",
                expect: "readonly",
                test: "readonly",
                console: "readonly",
                Buffer: "readonly",
                performance: "readonly",
                require: "readonly",
                process: "readonly",
                __dirname: "readonly",
                module: "readonly",
            },
        },
    },
];
