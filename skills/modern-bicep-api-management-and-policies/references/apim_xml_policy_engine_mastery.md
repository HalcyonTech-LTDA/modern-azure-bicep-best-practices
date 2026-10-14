# APIM XML Policy Engine Mastery

This guide covers advanced techniques for orchestrating APIM XML policies in Bicep, including dynamic expressions, rate limiting, and JWT validation.

---

## 1. Dynamic XML Policy Composition in Bicep

APIM policies are written in an XML dialect with embedded C# expressions. In Bicep, manage policies cleanly by assembling XML fragments via string variables:

```bicep
var openIdConfigUrl = '${environment().authentication.loginEndpoint}${entraTenantId}/v2.0/.well-known/openid-configuration'
var issuerV2 = '${environment().authentication.loginEndpoint}${entraTenantId}/v2.0'
var issuerV1 = 'https://sts.windows.net/${entraTenantId}/'

var jwtPolicyXml = enableJwtValidation ? '''
        <!-- Microsoft Entra ID OAuth 2.0 Client Credentials JWT Validation -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Invalid, expired, or missing OAuth Bearer token.">
          <openid-config url="${openIdConfigUrl}" />
          <audiences>
            <audience>${jwtAudience}</audience>
          </audiences>
          <issuers>
            <issuer>${issuerV2}</issuer>
            <issuer>${issuerV1}</issuer>
          </issuers>
        </validate-jwt>''' : ''
```

---

## 2. Dynamic Rate Limiting by Key (`<rate-limit-by-key>`)

Tiered rate limiting protects downstream microservices and third-party APIs from traffic spikes and abuse.

### Constructing Caller Identity in C#

Avoid naive IP-only rate limiting in production where multiple clients share corporate gateways. Instead, extract the JWT Subject or an `X-Client-Id` header, falling back to IP:

```bicep
var clientIdentityExpr = '(context.Request.Headers.GetValueOrDefault("Authorization", "").AsJwt()?.Subject ?? context.Request.Headers.GetValueOrDefault("X-Client-Id", context.Request.IpAddress))'
var counterKeyDefault = '@(${clientIdentityExpr})'
var counterKeySync = '@("sync:" + ${clientIdentityExpr})'
var counterKeyBatch = '@("batch:" + ${clientIdentityExpr})'
```

### Route-Based Tiered Policy

```xml
<choose>
  <!-- 1. Expensive Synchronous Route: max 10 req/s, 300 req/60s -->
  <when condition="@(context.Request.Method.Equals(&quot;POST&quot;, System.StringComparison.OrdinalIgnoreCase) &amp;&amp; context.Request.Url.Path.TrimEnd(&apos;/&apos;).Equals(&quot;/bureau-data&quot;, System.StringComparison.OrdinalIgnoreCase))">
    <rate-limit-by-key calls="10" renewal-period="1" counter-key="${counterKeySync}" />
    <rate-limit-by-key calls="300" renewal-period="60" counter-key="${counterKeySync}" />
  </when>
  <!-- 2. Asynchronous Batch Route: max 5 req/s, 60 req/60s -->
  <when condition="@(context.Request.Method.Equals(&quot;POST&quot;, System.StringComparison.OrdinalIgnoreCase) &amp;&amp; context.Request.Url.Path.TrimEnd(&apos;/&apos;).Equals(&quot;/bureau-data/batch&quot;, System.StringComparison.OrdinalIgnoreCase))">
    <rate-limit-by-key calls="5" renewal-period="1" counter-key="${counterKeyBatch}" />
    <rate-limit-by-key calls="60" renewal-period="60" counter-key="${counterKeyBatch}" />
  </when>
  <!-- 3. Default Tier: Query and Management APIs (Spike arrest 50/s, sustained 1500/60s) -->
  <otherwise>
    <rate-limit-by-key calls="50" renewal-period="1" counter-key="${counterKeyDefault}" />
    <rate-limit-by-key calls="1500" renewal-period="60" counter-key="${counterKeyDefault}" />
  </otherwise>
</choose>
```

---

## 3. Health Probe Bypass Pattern

When backend applications provide `/actuator/health` or `/healthz` endpoints used by Azure Load Balancer or monitoring agents, wrapping policies in a conditional prevents authentication failures or rate limit exhaustion from failing health checks:

```xml
<choose>
  <when condition="@(!context.Request.Url.Path.TrimStart(&apos;/&apos;).StartsWith(&quot;actuator/health&quot;))">
    <!-- Apply JWT Validation, Idempotency, and Rate Limiting -->
  </when>
</choose>
```

---

## 4. Backend Timeouts & URL Rewriting

```xml
<inbound>
  <base />
  <set-backend-service backend-id="${backendId}" />
  <!-- Prefix routing for Spring Boot versioned controllers -->
  <choose>
    <when condition="@(context.Request.Url.Path.TrimStart(&apos;/&apos;).StartsWith(&quot;actuator/health&quot;))">
      <rewrite-uri template="@(context.Request.Url.Path.StartsWith(&quot;/&quot;) ? context.Request.Url.Path : &quot;/&quot; + context.Request.Url.Path)" copy-unmatched-params="true" />
    </when>
    <otherwise>
      <rewrite-uri template="@(context.Request.Url.Path.StartsWith(&quot;/&quot;) ? &quot;/v1&quot; + context.Request.Url.Path : &quot;/v1/&quot; + context.Request.Url.Path)" copy-unmatched-params="true" />
    </otherwise>
  </choose>
</inbound>
<backend>
  <!-- Allow up to 360 seconds (6 minutes) for deep backend processing or container spin-up -->
  <forward-request timeout="360" />
</backend>
```
