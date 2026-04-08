Generate production-ready Kubernetes manifests from application configuration.

Load the following expertise before starting:

- [kubernetes-operations](../../../skills/kubernetes-operations/SKILL.md)
- [DevOps Agent](../../../agents/devops.md)

## Steps

1. Analyze the application requirements (ports, health checks, dependencies).
2. Generate base manifests:
   - Deployment (with resources, probes, strategy).
   - Service (ClusterIP/LoadBalancer).
   - ConfigMap / Secret Templates.
3. Add advanced resources:
   - Ingress (with TLS).
   - HPA (scaling rules).
   - SecurityContext (non-root).
4. Validate manifests: `kubectl apply --dry-run=client`.

## Rules

- Follow [kubernetes-operations](../../../skills/kubernetes-operations/SKILL.md) for production manifest standards.
- Always set CPU/Memory requests and limits.
- Never hardcode secrets; use templates or references.
- Include readiness and liveness probes.
