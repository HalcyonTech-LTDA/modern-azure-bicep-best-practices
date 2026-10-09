# Bicep Linting & Analyzer Rules (`bicepconfig.json`)

This reference guide details configuring the Bicep linter, managing analyzer rules, enforcing formatting standards, and establishing quality gates in CI/CD.

---

## 1. The Bicep Linter Overview

The Bicep compiler includes a built-in linter that checks Bicep files for syntax issues, deprecations, security antipatterns, and style violations during compilation (`az bicep build` or `az bicep lint`).

The linter is configured via a root `bicepconfig.json` file placed in the repository root or infrastructure folder.

---

## 2. Essential Analyzer Rules & Severities

Each rule in `bicepconfig.json` can be configured with:
- `"error"`: Fails compilation with a non-zero exit code.
- `"warning"`: Issues a compiler warning (can be elevated to error in CI).
- `"off"`: Disables the rule (use sparingly and with documented rationale).

### Key Rules Catalog

| Rule Name | Recommended Level | Description / Prevention |
| :--- | :--- | :--- |
| `no-hardcoded-env-urls` | `error` | Disallows hardcoding Azure cloud environment URLs (e.g., `management.azure.com`, `core.windows.net`, `vault.azure.net`). Mandates `environment().suffixes`. |
| `secure-parameter-default` | `error` | Prevents defining hardcoded default values for `@secure()` parameters. |
| `no-unused-params` | `error` | Flags declared parameters that are never referenced in the template. |
| `no-unused-vars` | `error` | Flags declared variables that are never used. |
| `use-recent-api-versions` | `warning` | Warns if an ARM API version is older than 2 years. |
| `use-resource-id-functions`| `error` | Prohibits manual string concatenation of resource IDs (e.g. `'/subscriptions/...'`). Mandates `subscriptionResourceId()`, `resourceId()`, or `.id`. |
| `simplify-interpolation` | `warning` | Flags redundant string interpolations like `'${myVar}'`. |
| `protect-secrets-in-params`| `error` | Flags sensitive parameter names (password, secret, key) that lack the `@secure()` decorator. |

---

## 3. Formatting Standards

Enforce deterministic formatting across all Bicep files using the CLI format command:

```bash
# Check formatting without writing changes (fails in CI if unformatted)
az bicep format --file main.bicep --outdir .

# Format all Bicep files in repository
find . -name "*.bicep" -exec az bicep format --file {} \;
```
