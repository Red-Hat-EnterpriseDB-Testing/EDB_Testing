# Secure Installation of EDB Postgres Operator on MicroShift

## Overview
This document explains how the EDB Postgres for Kubernetes operator was configured to run securely on MicroShift using the default `restricted-v2` Security Context Constraint (SCC), without requiring any custom or elevated privileges.

## Security Context Constraints (SCC)

MicroShift/OpenShift enforces Security Context Constraints to control what privileges pods can use. The default `restricted-v2` SCC is the most restrictive and secure option.

### Why the Default Installation Failed

The official EDB operator manifest sets:
- `runAsUser: 10001` (hardcoded UID)
- `runAsGroup: 10001` (hardcoded GID)  
- `seccompProfile: RuntimeDefault`

However, MicroShift's `restricted-v2` SCC requires:
- UIDs must be in the namespace-allocated range (e.g., 1000190000-1000199999)
- `Run As User Strategy: MustRunAsRange` (cannot use arbitrary UIDs)

## Secure Solution

Instead of creating a custom SCC with elevated privileges, we modified the operator deployment to work within the default security boundaries:

### 1. Remove Hardcoded UIDs

```bash
kubectl patch deployment postgresql-operator-controller-manager \
  -n postgresql-operator-system --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/containers/0/securityContext/runAsUser"},
  {"op": "remove", "path": "/spec/template/spec/containers/0/securityContext/runAsGroup"}
]'
```

This allows OpenShift to automatically assign a UID from the allowed range.

### 2. Keep Seccomp Profile

The `restricted-v2` SCC allows `runtime/default` seccomp profiles, so we kept it:

```bash
kubectl patch deployment postgresql-operator-controller-manager \
  -n postgresql-operator-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/securityContext/seccompProfile", 
   "value": {"type": "RuntimeDefault"}}
]'
```

### 3. Bind to restricted-v2 SCC

Explicitly bind the service account to use `restricted-v2`:

```bash
oc adm policy add-scc-to-user restricted-v2 \
  -z postgresql-operator-manager \
  -n postgresql-operator-system
```

## Result

The operator now runs with:

- **SCC**: `restricted-v2` (most restrictive, default SCC)
- **UID**: `1000190000` (auto-assigned from namespace range)
- **Seccomp**: `runtime/default` (kernel-level syscall filtering)
- **Capabilities**: All dropped except allowed ones
- **Privilege Escalation**: Disabled
- **Root Filesystem**: Read-only
- **SELinux**: Enforced with assigned context

## Verification

Check the pod's SCC:
```bash
kubectl get pod -n postgresql-operator-system \
  -o jsonpath='{.items[0].metadata.annotations.openshift\.io/scc}'
```

Output: `restricted-v2`

Check the assigned UID:
```bash
kubectl get pod -n postgresql-operator-system -o yaml | grep runAsUser
```

Output: `runAsUser: 1000190000` (or similar from allowed range)

## Security Benefits

Compared to using a custom SCC or `anyuid`:

1. **No Arbitrary UIDs**: Pod cannot run as any UID it wants
2. **Automatic UID Assignment**: OpenShift manages UID allocation
3. **Privilege Restrictions**: Cannot escalate privileges
4. **Syscall Filtering**: Seccomp limits available system calls
5. **SELinux Enforcement**: Additional mandatory access control
6. **Default Security**: Uses platform-provided security boundaries
7. **No Custom SCCs**: Easier to audit and maintain

## Namespace UID Range

Each namespace in MicroShift/OpenShift gets a unique UID range:

```bash
kubectl get namespace postgresql-operator-system \
  -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}'
```

Example output: `1000190000/10000`

This means:
- **Start UID**: 1000190000
- **Range Size**: 10000 UIDs
- **End UID**: 1000199999

All pods in this namespace must use UIDs within this range.

## PostgreSQL Pods

When you create PostgreSQL clusters using the operator, the database pods will also run with restricted security contexts. The operator automatically handles:

- Setting appropriate UIDs for PostgreSQL processes
- Configuring volume permissions
- Managing file ownership within containers

## Best Practices

1. **Always use restricted-v2**: Don't create custom SCCs unless absolutely necessary
2. **Let OpenShift assign UIDs**: Don't hardcode runAsUser values
3. **Enable seccomp**: Use RuntimeDefault for syscall filtering
4. **Drop capabilities**: Only request needed capabilities
5. **Read-only root filesystem**: Use emptyDir for writable paths
6. **Regular updates**: Keep operator updated for security fixes

## Troubleshooting

### Pod stuck in CreateContainerConfigError

Check if UID is in allowed range:
```bash
kubectl describe pod -n postgresql-operator-system | grep -A 5 "SCC:"
```

### Permission denied errors

Verify volume permissions match the assigned UID:
```bash
kubectl exec -n postgresql-operator-system deployment/postgresql-operator-controller-manager \
  -- ls -la /controller
```

### Image pull issues

Ensure pull secret exists in the namespace:
```bash
kubectl get secret edb-pull-secret -n postgresql-operator-system
```

## References

- [OpenShift Security Context Constraints](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [EDB Postgres for Kubernetes Documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/)
- [Seccomp in Kubernetes](https://kubernetes.io/docs/tutorials/security/seccomp/)

## Summary

By removing hardcoded UIDs and using the default `restricted-v2` SCC, we achieved:
- ✅ Maximum security (most restrictive SCC)
- ✅ No custom security policies
- ✅ Automatic UID management
- ✅ Full operator functionality
- ✅ Production-ready configuration

This approach follows security best practices and makes the deployment more maintainable and auditable.
