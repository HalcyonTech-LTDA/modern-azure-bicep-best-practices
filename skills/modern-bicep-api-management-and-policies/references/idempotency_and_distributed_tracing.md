# Idempotency & Distributed Tracing in APIM

This guide covers implementing RFC 6648 idempotency validation, response caching, and W3C distributed tracing in Azure API Management.

---

## 1. RFC 6648 Idempotency Pattern

For mutation endpoints (e.g. `POST /bureau-data` or `POST /orders`), callers pass an `Idempotency-Key` header:
1. **Validation**: If `Idempotency-Key` is missing or whitespace, APIM immediately aborts the pipeline and returns `400 Bad Request`.
2. **Lookup**: APIM looks up the key in its distributed cache via `<cache-lookup-value>`. If found, APIM returns the cached response with `Idempotent-Replayed: true` (RFC 6648), skipping backend invocation and avoiding duplicate charges.
3. **Storage**: On successful backend response (`200 OK` or `202 Accepted`), APIM stores the response in the cache via `<cache-store-value>` for a configured TTL (e.g. 24 hours = 86400s).

### Inbound Idempotency XML

```xml
<choose>
  <when condition="@(context.Request.Method.Equals(&quot;POST&quot;, System.StringComparison.OrdinalIgnoreCase) &amp;&amp; context.Request.Url.Path.TrimEnd(&apos;/&apos;).Equals(&quot;/bureau-data&quot;, System.StringComparison.OrdinalIgnoreCase))">
    <!-- 1. Enforce Header -->
    <choose>
      <when condition="@(string.IsNullOrWhiteSpace(context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;, &quot;&quot;)))">
        <return-response>
          <set-status code="400" reason="Bad Request" />
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
          <set-body>@{
            return new Newtonsoft.Json.Linq.JObject(
              new Newtonsoft.Json.Linq.JProperty("error", "Bad Request"),
              new Newtonsoft.Json.Linq.JProperty("message", "Header 'Idempotency-Key' is required for this operation."),
              new Newtonsoft.Json.Linq.JProperty("status", 400)
            ).ToString();
          }</set-body>
        </return-response>
      </when>
    </choose>
    <!-- 2. Cache Lookup -->
    <cache-lookup-value key="@(&quot;idempotency:sync:&quot; + context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;))" variable-name="idempotentResponse" />
    <choose>
      <when condition="@(context.Variables.ContainsKey(&quot;idempotentResponse&quot;))">
        <return-response>
          <set-status code="200" reason="OK" />
          <set-header name="Content-Type" exists-action="override">
            <value>application/json</value>
          </set-header>
          <set-header name="Idempotent-Replayed" exists-action="override">
            <value>true</value>
          </set-header>
          <set-body>@((string)context.Variables[&quot;idempotentResponse&quot;])</set-body>
        </return-response>
      </when>
    </choose>
  </when>
</choose>
```

### Outbound Storage XML

```xml
<outbound>
  <base />
  <choose>
    <when condition="@((context.Response.StatusCode == 200 || context.Response.StatusCode == 201) &amp;&amp; context.Request.Method.Equals(&quot;POST&quot;, System.StringComparison.OrdinalIgnoreCase) &amp;&amp; !string.IsNullOrWhiteSpace(context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;, &quot;&quot;)))">
      <cache-store-value key="@(&quot;idempotency:sync:&quot; + context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;))" value="@(context.Response.Body.As&lt;string&gt;(preserveContent: true))" duration="86400" />
    </when>
  </choose>
</outbound>
```

---

## 2. Distributed Tracing with W3C & Application Insights

To correlate traces across the APIM gateway and backend microservices:
1. Deploy an APIM Logger resource (`Microsoft.ApiManagement/service/loggers`) linked to Application Insights.
2. Deploy an API Diagnostics resource (`Microsoft.ApiManagement/service/apis/diagnostics`):
   - Set `httpCorrelationProtocol: 'W3C'`.
   - Propagate `traceparent` and `tracestate` headers in both frontend and backend configurations.
   - Record custom correlation headers (`Idempotency-Key`, `Idempotent-Replayed`).
   - Set `logClientIp: false` to adhere to data privacy (LGPD / GDPR).

```bicep
resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-05-01' = {
  parent: api
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    loggerId: apimLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: [
          'Idempotency-Key'
          'traceparent'
          'tracestate'
        ]
      }
      response: {
        headers: [
          'Idempotent-Replayed'
          'traceparent'
          'tracestate'
        ]
      }
    }
    backend: {
      request: {
        headers: [
          'Idempotency-Key'
          'traceparent'
          'tracestate'
        ]
      }
      response: {
        headers: [
          'Idempotent-Replayed'
          'traceparent'
          'tracestate'
        ]
      }
    }
    logClientIp: false
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
  }
}
```
