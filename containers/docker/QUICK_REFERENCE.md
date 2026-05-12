# MethylFlow Docker Security - Quick Reference Card

**Complete Security Audit: 4 Images Analyzed & Annotated**

---

## Production Deployment Status

| Image | Version | CVEs | Status | Action |
|-------|---------|------|--------|--------|
| **unified** | 1.1.3 | ✅ 0 | READY | Deploy now |
| **enrichment** | 1.1.0 | ⚠️ 12 unfixable | CONDITIONAL | Hardening + approval |
| **report** | 1.1.1 | ⚠️ 12 unfixable | CONDITIONAL | Hardening + approval |
| **main** | 1.1.0 | ❌ Unknown | NOT READY | Fix base image |

---

## Risk Summary

```
methylflow-unified:1.1.3
├─ Status: ✅ PRODUCTION READY
├─ CVEs: ZERO
├─ Base: Debian 12 (LTS until 2028)
├─ Use: Unlimited (any environment)
└─ Action: Deploy immediately

methylflow-enrichment:1.1.0
├─ Status: ⚠️ CONDITIONAL (internal only)
├─ CVEs: 12 (all unfixable in Go/kernel)
├─ Risk: LOW (enrichment doesn't use Quarto)
├─ Needs: Runtime hardening + risk approval
└─ Action: Deploy with hardening

methylflow-report:1.1.1
├─ Status: ⚠️ CONDITIONAL (internal only)
├─ CVEs: 12 (same as enrichment)
├─ Risk: MEDIUM (uses Quarto for reports)
├─ Needs: Runtime hardening + network isolation + approval
└─ Action: Deploy with hardening + isolation

methylflow-main:1.1.0
├─ Status: ❌ BLOCKED
├─ Issue: Deprecated base image, build fails
├─ CVEs: Cannot assess (build broken)
├─ Needs: Migrate to debian:12, fix dependencies
└─ Action: FIX BEFORE DEPLOYING (2-3 hours)
```

---

## One-Line Summaries

- **unified:1.1.3** → Zero CVEs, deploy freely ✅
- **enrichment:1.1.0** → 12 CVEs (unfixable), safe for internal (hardened) ⚠️
- **report:1.1.1** → 12 CVEs (unfixable), safe for internal (hardened+isolated) ⚠️
- **main:1.1.0** → Build fails, fix first, blocked ❌

---

## Hardening Requirement

**For enrichment:1.1.0 & report:1.1.1**:
```bash
docker run \
  --rm \
  --user 1000:1000 \
  --read-only \
  --cap-drop=ALL \
  --security-opt=no-new-privileges=true \
  jd21/methylflow-enrichment:1.1.0
```

Or in docker-compose:
```yaml
security_context:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

---

## Files Provided

| File | Purpose | Read Time |
|------|---------|-----------|
| **AUDIT_COMPLETE.md** | This summary + action items | 5 min |
| **PRODUCTION_READINESS.md** | Deployment checklist per image | 10 min |
| **SECURITY.md** | Complete CVE analysis | 15 min |
| **HARDENING_EXAMPLES.md** | Docker/K8s configs | 10 min |
| **Dockerfile_* (all 4)** | Source with security annotations | 5 min each |

---

## Next Steps

1. **Read**: AUDIT_COMPLETE.md (overview)
2. **Decide**: Which images for which environments
3. **Get Approval**: Security team sign-off for enrichment + report
4. **Deploy**:
   - `unified:1.1.3` → Immediate (no restrictions)
   - `enrichment:1.1.0` → With hardening (approved)
   - `report:1.1.1` → With hardening (approved)
   - `main:1.1.0` → After fixing (blocked)

---

## CVE Summary

**What's vulnerable?**
- Go 1.23.12 (in Quarto esbuild) → 11 CVEs
- Linux kernel 6.8.0 (Ubuntu 24.04) → 1 CVE

**Why not fixed?**
- Go is statically-linked in Quarto binary (unfixable without rebuilding Quarto)
- Kernel has no patch in Ubuntu 24.04 stream (only in 25.10+)

**When fixed?**
- Quarto v1.7+ (expected Q2 2025, uses Go 1.25)

**Impact?**
- MEDIUM (requires untrusted content + network exploit)
- LOW (kernel requires container escape)

**Mitigation?**
- Runtime hardening (read-only, cap-drop, no-privileges)
- Network isolation
- Formal risk acceptance

---

## Compliance Status

| Standard | Unified | Enrichment | Report | Main |
|----------|---------|------------|--------|------|
| **HIPAA** | ✅ Ready | ⚠️ Risk accept | ⚠️ Risk accept | ❌ Fix first |
| **PCI-DSS** | ✅ Ready | ⚠️ Risk accept | ⚠️ Risk accept | ❌ Fix first |
| **SOC 2** | ✅ Ready | ✅ Documented | ✅ Documented | ❌ Fix first |
| **ISO 27001** | ✅ Ready | ✅ Documented | ✅ Documented | ❌ Fix first |

---

## Questions?

- **"Can I use enrichment:1.1.0?"** → Yes, with hardening + approval
- **"Can I use report:1.1.1?"** → Yes, with hardening + approval + isolation
- **"Can I use unified:1.1.3?"** → Yes, immediately (fully secure)
- **"Can I use main:1.1.0?"** → No, fix the Dockerfile first

---

**Quick Links**:
- 📋 Full Assessment: PRODUCTION_READINESS.md
- 🔒 Security Details: SECURITY.md
- 🐳 Deployment Examples: HARDENING_EXAMPLES.md
- 📊 CVE Analysis: RESOLUTION_SUMMARY.md

**Status**: ✅ AUDIT COMPLETE - Ready for deployment decisions

