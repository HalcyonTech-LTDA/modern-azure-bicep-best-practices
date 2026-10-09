# IaC Living `README.md` Runbook Mandate for Azure Bicep

This reference guide establishes the engineering mandate for maintaining living runbook documentation in any repository or directory housing Azure Bicep infrastructure code.

---

## 1. The Living Runbook Mandate

Infrastructure-as-Code is never "self-documenting" to non-author engineers, on-call operators, or incident responders during production outages. 

### Invariant Rules:
1. Every directory or repository containing Bicep templates MUST maintain a dedicated, up-to-date `README.md` living runbook.
2. Any pull request or commit that modifies Bicep templates, adds modules, alters parameter contracts, or updates deployment procedures MUST synchronize this `README.md` in the exact same atomic commit.

---

## 2. Mandatory Runbook Structure

The living `README.md` must contain the following sections:

1. **System Under Management (Scope & Architecture)**:
   - High-level topology diagram or text representation.
   - Resource inventory (e.g., VNet, Key Vault, Container Apps, Databases).
2. **Directory Architecture Tree**:
   - Layout of root templates, modules, and `.bicepparam` files.
3. **Environment Selection & Parameter Contracts Matrix**:
   - Supported environments (`dev`, `staging`, `prod`).
   - Required vs optional parameters and secrets management strategy.
4. **Execution Runbook**:
   - Copy-pasteable Azure CLI and PowerShell commands for:
     - Local syntax validation & formatting (`az bicep build`, `az bicep format`).
     - Pre-flight What-If verification (`az stack group create ... --what-if`).
     - Stack deployment (`az stack group create ... --yes`).
     - Stack teardown / rollback procedures.
5. **Quality Gates & Static Analysis**:
   - Linter rules and PSRule compliance commands.
6. **Disaster Recovery & Emergency Break-Glass**:
   - Rollback procedures, managing stack locks, and break-glass administrator access.

---

## 3. Pull Request Synchronization Checklist

Include this checklist in pull request templates:

```markdown
### IaC PR Synchronization Checklist
- [ ] Bicep templates validated with `az bicep build` (zero errors/warnings).
- [ ] Bicep code formatted with `az bicep format`.
- [ ] What-If change analysis executed and reviewed for unintended deletions.
- [ ] No plain-text secrets in code or `.bicepparam`.
- [ ] Dedicated `README.md` runbook updated with new parameters/architecture changes.
```
