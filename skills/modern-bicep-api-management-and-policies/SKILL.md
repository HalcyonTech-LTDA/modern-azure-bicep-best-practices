---
name: modern-bicep-api-management-and-policies
description: >-
  Use this skill when designing, authoring, or refactoring Azure API Management (APIM) and XML Policy Engine in Bicep:
  external VNet injection, internal Container Apps backends, Products, APIs, typed Operations, W3C distributed tracing (App Insights loggers & diagnostics),
  and XML policies: route-based rate limiting (<rate-limit-by-key>), Entra ID OAuth JWT validation (<validate-jwt>),
  RFC 6648 idempotency validation & response caching (<cache-lookup-value>/<cache-store-value>), backend timeouts (<forward-request>),
  URI rewrites, and health probe bypassing.
---

# Modern Azure API Management & XML Policy Engine

This skill provides comprehensive architectural guidelines, security controls, and declarative Bicep patterns for deploying Azure API Management (APIM) in External VNet mode and mastering the APIM XML policy engine.

---

## Core Principles

1. **External VNet Injection & NSG Hardening**:
   - Deploy APIM with `virtualNetworkType: 'External'` injected into a dedicated subnet (`snet-apim`).
   - The subnet NSG MUST permit:
     - Inbound port `3443` from service tag `ApiManagement` (mandatory control plane management).
     - Inbound ports `80` and `443` from `Internet` (client traffic).
     - Inbound from `AzureLoadBalancer` health probes.
     - Outbound to `Storage` (port 443), `Sql` (port 1433), `AzureKeyVault` (port 443), and `AzureMonitor`.
   - Disable insecure legacy protocols: TLS 1.0 and TLS 1.1 on both client gateway and backend connections.

2. **Backend Target Decoupling**:
   - Model downstream microservices as APIM Backends (`Microsoft.ApiManagement/service/backends@2024-05-01`).
   - Point the backend URL to the internal FQDN of the Azure Container Apps REST API (`https://${apiAppFqdn}`).
   - Set `protocol: 'http'` (APIM terminology for HTTP/HTTPS) and configure TLS validation settings as appropriate for internal certs.

3. **Typed Operations & API Taxonomy**:
   - Structure APIs cleanly: `Product` -> `API` -> `Operations`.
   - For public or token-authenticated APIs that do not require APIM subscription keys, set `subscriptionRequired: false`.
   - Declare explicit, strongly typed `operations` (`Microsoft.ApiManagement/service/apis/operations@2024-05-01`) for each HTTP method and route template (`/actuator/health`, `/bureau-data/{cpf}`, `/bureau-data/batch`, etc.).
   - Define expected request headers (such as `Idempotency-Key`) and template parameters directly in the operation schema.

4. **W3C Distributed Tracing & Telemetry Diagnostics**:
   - Provision an APIM Logger (`Microsoft.ApiManagement/service/loggers`) linked to Application Insights.
   - Configure API Diagnostics (`Microsoft.ApiManagement/service/apis/diagnostics`) with `httpCorrelationProtocol: 'W3C'`, propagating `traceparent` and `tracestate` headers across frontend and backend calls.
   - Preserve custom tracing headers (`Idempotency-Key`, `Idempotent-Replayed`) in diagnostic logs while enforcing privacy via `logClientIp: false`.

5. **XML Policy Engine Orchestration**:
   - Embed dynamic XML policies directly in Bicep using multi-line string interpolation:
     - **Health Probe Bypass**: Bypasses authentication and rate limiting for `/actuator/health` to prevent probe starvation and false cluster restarts.
     - **Entra ID OAuth 2.0 JWT Validation**: `<validate-jwt>` with `<openid-config url="..." />`, checking multiple valid audiences and issuers (v1 and v2).
     - **Tiered Rate Limiting by Key**: `<rate-limit-by-key>` with dynamic C# context expressions identifying callers (JWT Subject `?.Subject` ?? `X-Client-Id` ?? `context.Request.IpAddress`). Differentiate burst/spike arrest from sustained hourly quotas, and route-specific limits (e.g. expensive external bureau calls vs light queries).
     - **Idempotency Enforcement & Caching**: Check for required `Idempotency-Key` header; if missing, return `400 Bad Request` via `<return-response>`. Look up cached responses via `<cache-lookup-value>`; if found, return `Idempotent-Replayed: true` (RFC 6648). Cache successful responses via `<cache-store-value>` in `<outbound>`.
     - **Backend Timeout & URI Rewriting**: `<forward-request timeout="..." />` to accommodate cold starts or deep batch aggregations, paired with `<rewrite-uri>` for route versioning.

---

## Detailed Topic Guides

1. **APIM VNet & Backend Architecture**:
   - External VNet mode, NSG control plane requirements, internal ACA routing, and TLS hardening.
   - [Read Guide](./references/apim_vnet_and_backend_architecture.md)

2. **APIM XML Policy Engine Mastery**:
   - Inbound, backend, outbound, and on-error policy pipelines.
   - Rate limiting by key with C# expressions, JWT validation, URL rewriting, and timeouts.
   - [Read Guide](./references/apim_xml_policy_engine_mastery.md)

3. **Idempotency & Distributed Tracing**:
   - RFC 6648 header validation, 24h caching lifecycle, W3C correlation with Application Insights.
   - [Read Guide](./references/idempotency_and_distributed_tracing.md)

---

## Blueprint Examples

1. **APIM Service in External VNet Mode**:
   See [`examples/apim_service_external_vnet.bicep`](./examples/apim_service_external_vnet.bicep).
2. **API Definition, Operations & Full XML Policy Suite**:
   See [`examples/apim_api_and_xml_policies.bicep`](./examples/apim_api_and_xml_policies.bicep).
