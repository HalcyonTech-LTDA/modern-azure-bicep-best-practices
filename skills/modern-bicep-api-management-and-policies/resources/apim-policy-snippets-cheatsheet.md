# APIM Policy Snippets & Best Practices Cheatsheet

## 1. Rate Limiting Expressions

### Rate Limit by Client Identity (JWT Subject > X-Client-Id > IP)
```xml
<rate-limit-by-key
  calls="100"
  renewal-period="60"
  counter-key="@(context.Request.Headers.GetValueOrDefault(&quot;Authorization&quot;, &quot;&quot;).AsJwt()?.Subject ?? context.Request.Headers.GetValueOrDefault(&quot;X-Client-Id&quot;, context.Request.IpAddress))" />
```

### Route-Based Rate Limiting
```xml
<choose>
  <when condition="@(context.Request.Url.Path.TrimEnd(&apos;/&apos;).EndsWith(&quot;/heavy-task&quot;, System.StringComparison.OrdinalIgnoreCase))">
    <rate-limit-by-key calls="5" renewal-period="60" counter-key="@(&quot;heavy:&quot; + context.Request.IpAddress)" />
  </when>
</choose>
```

---

## 2. Microsoft Entra ID (Azure AD) OAuth 2.0 JWT Validation

```xml
<validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Invalid token.">
  <openid-config url="https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration" />
  <audiences>
    <audience>api://my-service</audience>
  </audiences>
  <issuers>
    <issuer>https://login.microsoftonline.com/{tenant-id}/v2.0</issuer>
    <issuer>https://sts.windows.net/{tenant-id}/</issuer>
  </issuers>
</validate-jwt>
```

---

## 3. RFC 6648 Idempotency Enforcer

```xml
<!-- Inbound: Require Header & Return Cached Response -->
<choose>
  <when condition="@(string.IsNullOrWhiteSpace(context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;, &quot;&quot;)))">
    <return-response>
      <set-status code="400" reason="Bad Request" />
      <set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header>
      <set-body>{"error":"Bad Request","message":"Idempotency-Key header is required"}</set-body>
    </return-response>
  </when>
</choose>
<cache-lookup-value key="@(&quot;idempotency:&quot; + context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;))" variable-name="cachedResp" />
<choose>
  <when condition="@(context.Variables.ContainsKey(&quot;cachedResp&quot;))">
    <return-response>
      <set-status code="200" reason="OK" />
      <set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header>
      <set-header name="Idempotent-Replayed" exists-action="override"><value>true</value></set-header>
      <set-body>@((string)context.Variables[&quot;cachedResp&quot;])</set-body>
    </return-response>
  </when>
</choose>

<!-- Outbound: Store Successful Response in Cache -->
<choose>
  <when condition="@(context.Response.StatusCode == 200 || context.Response.StatusCode == 201)">
    <cache-store-value key="@(&quot;idempotency:&quot; + context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;))" value="@(context.Response.Body.As&lt;string&gt;(preserveContent: true))" duration="86400" />
  </when>
</choose>
```
