# User-Defined Types (UDT) & User-Defined Functions (UDF) in Bicep

This guide details compile-time type safety, schema definitions, and pure deterministic function authoring using modern Bicep language features.

---

## 1. User-Defined Types (`type`)

Historically, complex parameters in ARM and early Bicep were typed as generic `object` or `array`. This caused subtle bugs, lack of IDE auto-completion, and runtime deployment crashes.

Modern Bicep provides first-class **User-Defined Types (UDT)** using the `type` keyword.

### Basic Type Declarations & Sealed Objects

```bicep
@description('Defines the networking parameters for a subnet.')
@sealed() // Rejects any undeclared properties at compile time
type SubnetSpec = {
  @description('The name of the subnet.')
  @minLength(2)
  @maxLength(80)
  name: string

  @description('CIDR range allocated to the subnet.')
  addressPrefix: string

  @description('Optional delegation profile name.')
  delegation: string?

  @description('Enforce private endpoint network policies.')
  privateEndpointPolicies: ('Enabled' | 'Disabled')?
}
```

### Union Types & Tagged Unions (Discriminated Unions)

Union types allow strict enumeration of permitted values. Tagged unions allow modeling polymorphic configurations:

```bicep
// String literal union
type SkuTier = 'Standard' | 'Premium' | 'Isolated'

// Discriminated union based on a tag property ('kind')
type IngressConfiguration = InternalIngress | ExternalIngress

type InternalIngress = {
  kind: 'internal'
  allowFromVnetOnly: bool
  targetPort: int
}

type ExternalIngress = {
  kind: 'external'
  fqdn: string
  targetPort: int
  corsOrigins: string[]
}
```

### Type Constraints & Decorators

Decorate type properties with validation metadata:

| Decorator | Applicable Types | Purpose |
| :--- | :--- | :--- |
| `@description('...')` | Any | Documents the property for IntelliSense and documentation generators. |
| `@minLength(n)`, `@maxLength(n)` | `string`, `array` | Enforces length boundaries. |
| `@minValue(n)`, `@maxValue(n)` | `int` | Enforces numerical limits. |
| `@sealed()` | `object` | Rejects unexpected additional properties. |
| `@secure()` | `string`, `object` | Masks values in deployment logs and state. |

---

## 2. Exporting and Sharing Types across Modules

Types can be exported and imported across Bicep files using the `@export()` decorator and `import` statement:

```bicep
// types/common.bicep
@export()
@description('Standard enterprise tagging contract.')
type EnterpriseTags = {
  Environment: 'dev' | 'staging' | 'prod'
  CostCenter: string
  Owner: string
  Project: string
}
```

```bicep
// main.bicep
import { EnterpriseTags } from 'types/common.bicep'

param tags EnterpriseTags
```

---

## 3. User-Defined Functions (`func`)

User-Defined Functions encapsulate deterministic string operations, naming standards, and mathematical logic directly within Bicep.

### Syntax & Rules

- Functions are declared using the `func` keyword.
- Functions must be pure and deterministic (cannot call runtime-dependent functions like `guid()`, `newGuid()`, or resource runtime outputs).
- Return types must be explicitly declared.

### Practical Function Patterns

#### 1. Cloud Adoption Framework (CAF) Resource Naming

```bicep
func buildResourceName(prefix string, workload string, env string, resourceType string) string =>
  toLower('${prefix}-${workload}-${env}-${resourceType}')

// Usage
var storageName = buildResourceName('hlc', 'billing', 'prod', 'st')
```

#### 2. CIDR Subnet Calculator / Address Formatting

```bicep
func formatCidr(baseIp string, mask int) string => '${baseIp}/${mask}'

// Usage
var defaultCidr = formatCidr('10.200.0.0', 16)
```

#### 3. Tag Enrichment Function

```bicep
func mergeTags(baseTags object, resourceSpecificTag object) object => union(baseTags, resourceSpecificTag)
```
