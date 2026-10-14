# Container Apps & Jobs Sizing & Quotas Cheatsheet

## Supported vCPU and Memory Combinations

Azure Container Apps enforces fixed valid combinations of CPU and memory:

| vCPU (`cpu: json(...)`) | Memory (`memory: '...'`) | Typical Workload Profile |
| :--- | :--- | :--- |
| `0.25` | `0.5Gi` | Lightweight sidecars, short DB migration jobs |
| `0.5` | `1.0Gi` | Standard Spring Boot REST APIs, background shedlock schedulers |
| `0.75` | `1.5Gi` | Medium-load APIs with in-memory caching |
| `1.0` | `2.0Gi` | High-throughput batch workers, WireMock partner simulators |
| `1.25` | `2.5Gi` | Intensive processing workers |
| `1.5` | `3.0Gi` | Memory-heavy reporting workers |
| `2.0` | `4.0Gi` | Heavy data transformation pipelines |

*Note*: In Bicep, CPU must be passed as a JSON number via `cpu: json('0.5')`, while memory is specified as a formatted string `memory: '1.0Gi'`.

---

## Replica Scaling Best Practices

| Environment | API Replicas (`minReplicas` - `maxReplicas`) | Scheduler Replicas | Batch Job Parallelism | Mock Replicas |
| :--- | :--- | :--- | :--- | :--- |
| **dev** | 1 - 5 | 1 - 1 | 1 | 2 (active) |
| **uat** | 1 - 5 | 1 - 1 | 1 | 0 (scale-to-zero) |
| **prod** | 2 - 10 (High Availability) | 1 - 1 (ShedLock safe) | 2 (Parallel processing) | 0 (dormant / disabled) |
