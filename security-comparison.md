# Security Comparison: Custom SCC vs. restricted-v2

## Approach Comparison

| Security Aspect | Custom SCC (Initial) | restricted-v2 (Current) |
|----------------|---------------------|------------------------|
| **SCC Used** | `edb-operator-scc` (custom) | `restricted-v2` (default) |
| **SCC Priority** | 15 (elevated) | None (default) |
| **UID Strategy** | RunAsAny | MustRunAsRange |
| **Actual UID** | 10001 (arbitrary) | 1000190000 (namespace range) |
| **Privilege Escalation** | Allowed | Disabled |
| **Custom Policies** | Yes (requires maintenance) | No (platform-managed) |
| **Audit Complexity** | Higher (custom policy) | Lower (standard policy) |
| **Security Posture** | ⚠️ Permissive | ✅ Restrictive |

## Security Benefits of restricted-v2

### 1. **UID Isolation**
- **Before**: Pod could run as any UID (10001)
- **After**: Pod must use assigned UID (1000190000)
- **Benefit**: Better namespace isolation, prevents UID conflicts

### 2. **No Custom SCCs**
- **Before**: Required creating and maintaining custom security policy
- **After**: Uses platform-provided default policy
- **Benefit**: Easier auditing, automatic security updates

### 3. **Privilege Escalation**
- **Before**: Could potentially escalate privileges
- **After**: Privilege escalation explicitly disabled
- **Benefit**: Cannot gain root or elevated permissions

### 4. **Compliance**
- **Before**: Custom policy may require additional security reviews
- **After**: Standard OpenShift security model
- **Benefit**: Easier compliance with security standards (CIS, STIGs)

### 5. **Platform Integration**
- **Before**: Bypassing default security controls
- **After**: Working within platform security boundaries
- **Benefit**: Better platform security guarantees

## Technical Details

### UID Assignment

**Custom SCC** (edb-operator-scc):
```yaml
runAsUser:
  type: RunAsAny  # Can use any UID
```

**restricted-v2**:
```yaml
runAsUser:
  type: MustRunAsRange  # Must use namespace-assigned range
  # Namespace range: 1000190000-1000199999
```

### Capabilities

**Custom SCC**:
```yaml
allowPrivilegeEscalation: true  # More permissive
```

**restricted-v2**:
```yaml
allowPrivilegeEscalation: false  # More secure
requiredDropCapabilities:
- ALL  # Drops all Linux capabilities
```

### Seccomp Profiles

**Both Approaches**:
```yaml
seccompProfiles:
- runtime/default  # Syscall filtering enabled
```
*(restricted-v2 supports this, so no compromise needed)*

## Real-World Implications

### What Changed in Practice

1. **Container Startup**:
   - Before: Started as UID 10001
   - After: Started as UID 1000190000
   - Impact: Process runs with different UID but same functionality

2. **File Permissions**:
   - Before: Files owned by 10001:10001
   - After: Files owned by 1000190000:root
   - Impact: No functional difference, OpenShift handles this

3. **Security Boundaries**:
   - Before: Could potentially interact with other namespace resources
   - After: Strictly isolated within namespace UID range
   - Impact: Better multi-tenant security

### PostgreSQL Cluster Pods

When creating PostgreSQL clusters, the database pods will also:
- Use namespace-assigned UIDs
- Run under restricted-v2 SCC
- Have proper volume ownership configured by operator
- Maintain full functionality with enhanced security

## Migration Path (What We Did)

```bash
# 1. Remove custom SCC
kubectl delete scc edb-operator-scc

# 2. Remove anyuid binding
kubectl delete clusterrolebinding system:openshift:scc:anyuid

# 3. Remove hardcoded UIDs from deployment
kubectl patch deployment postgresql-operator-controller-manager \
  -n postgresql-operator-system --type='json' -p='[
  {"op": "remove", "path": "/spec/template/spec/containers/0/securityContext/runAsUser"},
  {"op": "remove", "path": "/spec/template/spec/containers/0/securityContext/runAsGroup"}
]'

# 4. Add seccomp profile back (allowed by restricted-v2)
kubectl patch deployment postgresql-operator-controller-manager \
  -n postgresql-operator-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/securityContext/seccompProfile", 
   "value": {"type": "RuntimeDefault"}}
]'

# 5. Explicitly bind to restricted-v2
oc adm policy add-scc-to-user restricted-v2 \
  -z postgresql-operator-manager \
  -n postgresql-operator-system
```

## Verification

### Check Current SCC
```bash
kubectl get pod -n postgresql-operator-system \
  -o jsonpath='{.items[0].metadata.annotations.openshift\.io/scc}'
# Output: restricted-v2
```

### Check Assigned UID
```bash
kubectl get pod -n postgresql-operator-system -o yaml | grep runAsUser
# Output: runAsUser: 1000190000
```

### Check Security Context
```bash
kubectl get pod -n postgresql-operator-system -o yaml | \
  grep -A 10 "securityContext:"
```

## Recommendations

### ✅ Do
- Use default platform SCCs (restricted-v2)
- Let OpenShift assign UIDs automatically
- Enable seccomp profiles (RuntimeDefault)
- Drop all unnecessary capabilities
- Keep documentation on security decisions

### ❌ Don't
- Create custom SCCs unless absolutely necessary
- Hardcode UIDs in pod specs
- Use anyuid or privileged SCCs
- Disable security features for convenience
- Assume operator needs more privileges than it does

## Conclusion

By removing hardcoded UIDs and using `restricted-v2` SCC, we achieved:

✅ **Maximum Security**: Most restrictive platform SCC  
✅ **Zero Custom Policies**: No custom SCCs to maintain  
✅ **Platform Compliance**: Standard OpenShift security model  
✅ **Full Functionality**: Operator works perfectly  
✅ **Better Isolation**: Namespace-bound UIDs  
✅ **Easier Auditing**: Standard security boundaries  
✅ **Production Ready**: Enterprise-grade security posture  

This approach should be the standard for all operator deployments on MicroShift/OpenShift.
