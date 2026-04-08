Debug a failing or unhealthy Kubernetes pod by analyzing events, logs, and configuration.

Load the following expertise before starting:

- [kubernetes-operations](../../../skills/kubernetes-operations/SKILL.md)
- [DevOps Agent](../../../agents/devops.md)

## Steps

1. Get pod status and events: `kubectl describe pod <name>`.
2. Analyze the pod state (Pending, CrashLoopBackOff, ImagePullBackOff, OOMKilled).
3. Fetch container logs (`--previous` if crashed).
4. Verify configuration (Secrets, ConfigMaps, ENVs).
5. Check resource usage: `kubectl top pod`.
6. Propose a root cause and fix.

## Rules

- Follow diagnostics patterns from [kubernetes-operations](../../../skills/kubernetes-operations/SKILL.md).
- Prioritize events as they often reveal transient issues.
- Check RBAC permissions if API errors are detected.
