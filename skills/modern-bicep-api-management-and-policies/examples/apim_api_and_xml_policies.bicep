@description('Name of the existing API Management service instance.')
param apimName string

@description('Backend identifier name to route incoming requests.')
param backendId string = 'aca-api-backend'

@description('Unique identifier name for the API resource in APIM.')
param apiName string = 'my-api'

@description('URL path suffix for this API on the gateway.')
param apiPath string = 'v1'

@description('Whether to enforce OAuth 2.0 JWT validation.')
param enableJwtValidation bool = false

@description('Azure AD / Microsoft Entra Tenant ID.')
param entraTenantId string = tenant().tenantId

@description('Expected Audience (aud claim) in JWT token.')
param jwtAudience string = 'api://my-service'

@description('Backend response timeout in seconds.')
param backendTimeout int = 360

@description('Resource ID of the Application Insights component for distributed tracing.')
param appInsightsId string = ''

@description('Connection string of the Application Insights component.')
@secure()
param appInsightsConnectionString string = ''

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

// ================================================================================================
// Product
// ================================================================================================
resource product 'Microsoft.ApiManagement/service/products@2024-05-01' = {
  parent: apim
  name: 'default-product'
  properties: {
    displayName: 'Default Product'
    description: 'API Product without subscription key requirement'
    subscriptionRequired: false
    state: 'published'
  }
}

// ================================================================================================
// API Definition
// ================================================================================================
resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: apiName
  properties: {
    displayName: 'Microservice API'
    description: 'REST API routed to internal Azure Container Apps backend'
    subscriptionRequired: false
    path: apiPath
    protocols: [
      'https'
    ]
    isCurrent: true
  }
}

resource productApi 'Microsoft.ApiManagement/service/products/apis@2024-05-01' = {
  parent: product
  name: apiName
  dependsOn: [
    api
  ]
}

// ================================================================================================
// Distributed Tracing: Logger & Diagnostics
// ================================================================================================
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = if (!empty(appInsightsId)) {
  parent: apim
  name: 'appinsights-logger'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger for APIM distributed tracing'
    credentials: {
      connectionString: appInsightsConnectionString
    }
    isBuffered: true
    resourceId: appInsightsId
  }
}

resource apiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2024-05-01' = if (!empty(appInsightsId)) {
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

// ================================================================================================
// Typed API Operations
// ================================================================================================
resource getHealth 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'get-health'
  properties: {
    displayName: 'Health Check'
    method: 'GET'
    urlTemplate: '/actuator/health'
    description: 'Health check probe bypassed from auth and rate limiting'
  }
}

resource createResource 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'create-resource'
  properties: {
    displayName: 'Create Resource'
    method: 'POST'
    urlTemplate: '/items'
    description: 'Creates a resource with mandatory Idempotency-Key header'
    request: {
      headers: [
        {
          name: 'Idempotency-Key'
          type: 'string'
          required: true
          description: 'Unique idempotency key'
        }
      ]
    }
  }
}

// ================================================================================================
// API Policy XML
// ================================================================================================
var openIdConfigUrl = '${environment().authentication.loginEndpoint}${entraTenantId}/v2.0/.well-known/openid-configuration'
var issuerV2 = '${environment().authentication.loginEndpoint}${entraTenantId}/v2.0'
var issuerV1 = 'https://sts.windows.net/${entraTenantId}/'

var jwtPolicyXml = enableJwtValidation ? '\n        <!-- Microsoft Entra ID OAuth 2.0 Client Credentials JWT Validation -->\n        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Invalid, expired, or missing OAuth Bearer token.">\n          <openid-config url="${openIdConfigUrl}" />\n          <audiences>\n            <audience>${jwtAudience}</audience>\n          </audiences>\n          <issuers>\n            <issuer>${issuerV2}</issuer>\n            <issuer>${issuerV1}</issuer>\n          </issuers>\n        </validate-jwt>' : ''

var clientIdentityExpr = '(context.Request.Headers.GetValueOrDefault(&quot;Authorization&quot;, &quot;&quot;).AsJwt()?.Subject ?? context.Request.Headers.GetValueOrDefault(&quot;X-Client-Id&quot;, context.Request.IpAddress))'
var counterKeyDefault = '@(${clientIdentityExpr})'

var rateLimitPolicyXml = '\n        <!-- Tiered Rate Limiting -->\n        <rate-limit-by-key calls="50" renewal-period="1" counter-key="${counterKeyDefault}" />\n        <rate-limit-by-key calls="1500" renewal-period="60" counter-key="${counterKeyDefault}" />'

var idempotencyInboundXml = '\n        <!-- Idempotency Validation & Caching for POST /items -->\n        <choose>\n          <when condition="@(context.Request.Method.Equals(&quot;POST&quot;, System.StringComparison.OrdinalIgnoreCase) &amp;&amp; context.Request.Url.Path.TrimEnd(&apos;/&apos;).Equals(&quot;/items&quot;, System.StringComparison.OrdinalIgnoreCase))">\n            <choose>\n              <when condition="@(string.IsNullOrWhiteSpace(context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;, &quot;&quot;)))">\n                <return-response>\n                  <set-status code="400" reason="Bad Request" />\n                  <set-header name="Content-Type" exists-action="override">\n                    <value>application/json</value>\n                  </set-header>\n                  <set-body>@{\n                    return new Newtonsoft.Json.Linq.JObject(\n                      new Newtonsoft.Json.Linq.JProperty(&quot;error&quot;, &quot;Bad Request&quot;),\n                      new Newtonsoft.Json.Linq.JProperty(&quot;message&quot;, &quot;Header &apos;Idempotency-Key&apos; is required.&quot;),\n                      new Newtonsoft.Json.Linq.JProperty(&quot;status&quot;, 400)\n                    ).ToString();\n                  }</set-body>\n                </return-response>\n              </when>\n            </choose>\n            <cache-lookup-value key="@(&quot;idempotency:items:&quot; + context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;))" variable-name="idempotentResponse" />\n            <choose>\n              <when condition="@(context.Variables.ContainsKey(&quot;idempotentResponse&quot;))">\n                <return-response>\n                  <set-status code="200" reason="OK" />\n                  <set-header name="Content-Type" exists-action="override">\n                    <value>application/json</value>\n                  </set-header>\n                  <set-header name="Idempotent-Replayed" exists-action="override">\n                    <value>true</value>\n                  </set-header>\n                  <set-body>@((string)context.Variables[&quot;idempotentResponse&quot;])</set-body>\n                </return-response>\n              </when>\n            </choose>\n          </when>\n        </choose>'

var idempotencyOutboundXml = '\n    <!-- Store response by Idempotency-Key for 24h -->\n    <choose>\n      <when condition="@((context.Response.StatusCode == 200 || context.Response.StatusCode == 201) &amp;&amp; context.Request.Method.Equals(&quot;POST&quot;, System.StringComparison.OrdinalIgnoreCase) &amp;&amp; !string.IsNullOrWhiteSpace(context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;, &quot;&quot;)))">\n        <cache-store-value key="@(&quot;idempotency:items:&quot; + context.Request.Headers.GetValueOrDefault(&quot;Idempotency-Key&quot;))" value="@(context.Response.Body.As&lt;string&gt;(preserveContent: true))" duration="86400" />\n      </when>\n    </choose>'

var policyXml = '<policies>\n  <inbound>\n    <base />\n    <!-- Security & Rate Limiting (bypassing /actuator/health) -->\n    <choose>\n      <when condition="@(!context.Request.Url.Path.TrimStart(&apos;/&apos;).StartsWith(&quot;actuator/health&quot;))">${jwtPolicyXml}${idempotencyInboundXml}${rateLimitPolicyXml}\n      </when>\n    </choose>\n    <set-backend-service backend-id="${backendId}" />\n    <choose>\n      <when condition="@(context.Request.Url.Path.TrimStart(&apos;/&apos;).StartsWith(&quot;actuator/health&quot;))">\n        <rewrite-uri template="@(context.Request.Url.Path.StartsWith(&quot;/&quot;) ? context.Request.Url.Path : &quot;/&quot; + context.Request.Url.Path)" copy-unmatched-params="true" />\n      </when>\n      <otherwise>\n        <rewrite-uri template="@(context.Request.Url.Path.StartsWith(&quot;/&quot;) ? &quot;/v1&quot; + context.Request.Url.Path : &quot;/v1/&quot; + context.Request.Url.Path)" copy-unmatched-params="true" />\n      </otherwise>\n    </choose>\n  </inbound>\n  <backend>\n    <forward-request timeout="${backendTimeout}" />\n  </backend>\n  <outbound>\n    <base />${idempotencyOutboundXml}\n  </outbound>\n  <on-error>\n    <base />\n  </on-error>\n</policies>'

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: api
  name: 'policy'
  properties: {
    value: policyXml
    format: 'rawxml'
  }
}

// ================================================================================================
// Outputs
// ================================================================================================
@description('Resource ID of the API.')
output apiId string = api.id

@description('API Gateway URL Path.')
output fullApiPath string = '/${apiPath}'
