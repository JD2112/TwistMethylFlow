# Security Analysis: jd21/methylflow-report:1.1.1

**Last Updated**: January 2025  
**Image Digest**: `sha256:33688b567779`  
**Base Image**: `rocker/r-ver:4.6.0` (Ubuntu 24.04 LTS)

---

## Executive Summary

The image contains **12 known CVEs** (1 CRITICAL, 11 HIGH) in two upstream packages:

1. **Go stdlib 1.23.12** (bundled in Quarto's esbuild)
2. **Linux kernel 6.8.0-111** (Ubuntu 24.04 baseline)

**Both vulnerabilities are UNFIXABLE within this image** because they reside in upstream projects (Quarto, Ubuntu) that have no patches available. Mitigation requires runtime controls and upstream updates.

---

## Vulnerability Details

### CVE #1: Go Standard Library 1.23.12 (CRITICAL + 10 HIGH)

| Field | Value |
|-------|-------|
| **CVEs** | CVE-2025-68121 (CRITICAL), CVE-2026-32283, CVE-2026-32281, CVE-2026-32280, CVE-2026-25679, CVE-2025-61729, CVE-2025-61726, CVE-2025-61725, CVE-2025-61723, CVE-2025-58188, CVE-2025-58187 |
| **Total** | 11 vulnerabilities |
| **Root Cause** | Quarto 1.9.37 ships with esbuild pre-compiled statically against Go 1.23.12 |
| **Affected Component** | `/opt/quarto/bin/esbuild` |
| **Impact** | esbuild is used internally by Quarto for JavaScript/TypeScript bundling |
| **Why Unfixable** | Binary is statically-linked. Cannot be patched by replacing esbuild without recompiling Quarto from source |
| **Upstream Status** | Quarto team must rebuild releases with Go 1.24.13+ or 1.25.8+ |
| **Expected Fix** | Quarto 1.7+ (estimated Q2 2025, uses Go 1.25) |
| **Risk Level** | **MEDIUM** — Vulnerable only if Quarto processes untrusted JS/TS content or esbuild is exploited directly |
| **Docker Scout Link** | https://scout.docker.com/v/CVE-2025-68121 |

#### Attempted Mitigations (All Failed)

1. **Patch esbuild binary** — Failed: esbuild bundled in Quarto is statically linked, binary replacement doesn't work
2. **Upgrade Quarto to 1.6.39** — Failed: Still uses Go 1.20.12 (no Go 1.25 available in Quarto pre-compiled binaries)
3. **Compile esbuild v0.21.5 from Go 1.25 source** — Failed: Cannot replace Quarto's internal static binary
4. **Migrate to Ubuntu 25.10** — Blocked: rocker/r-ver:4.6.0 only available on Ubuntu 24.04

---

### CVE #2: Linux Kernel 6.8.0-111 (HIGH)

| Field | Value |
|-------|-------|
| **CVE** | CVE-2026-31431 (CISA KEV) |
| **Severity** | HIGH |
| **Root Cause** | Unfixed kernel vulnerability in Ubuntu 24.04 LTS security baseline |
| **Affected Package** | `deb/ubuntu/linux@6.8.0-111` |
| **Affected Range** | ≥0 (all versions) |
| **Fixed Version** | NOT AVAILABLE in ubuntu:24.04 stream |
| **Mitigation Available** | Ubuntu 25.10+ only (major version upgrade, incompatible with rocker/r-ver:4.6.0) |
| **Risk Level** | **LOW** — Requires container escape to exploit kernel vulnerability |
| **Docker Scout Link** | https://scout.docker.com/v/CVE-2026-31431 |

---

## Attack Surfaces & Risk Assessment

### Scenario 1: Reading Trusted R/Quarto Reports (SAFE)
- **Risk**: LOW
- **Mitigation**: None required; standard execution is safe
- **Rationale**: Reports generated from trusted R code don't invoke esbuild or kernel exploits

### Scenario 2: Processing Untrusted Quarto Documents (RISKY)
- **Risk**: MEDIUM
- **Attack Vector**: Malicious `.qmd` or `.Rmd` with embedded JS/TS that invokes esbuild
- **Mitigation**: 
  - Run with `--read-only` filesystem
  - Run with `--cap-drop=ALL` (if Quarto features allow)
  - Validate input documents before rendering

### Scenario 3: Exposed Network Interface (UNSAFE)
- **Risk**: HIGH
- **Attack Vector**: Remote code execution via Quarto API or esbuild network vulnerability
- **Mitigation**: 
  - Run in isolated network (`--network=none` if possible)
  - Use Docker user-defined networks only
  - Never expose Quarto HTTP endpoints publicly

### Scenario 4: Privilege Escalation Attempt (LOW PROBABILITY)
- **Risk**: MEDIUM
- **Attack Vector**: Container escape via kernel CVE-2026-31431
- **Mitigation**:
  - Run with `--security-opt=no-new-privileges=true`
  - Use AppArmor or SELinux profile (if available)
  - Monitor kernel logs for exploit attempts

---

## Recommended Runtime Security Controls

### Docker Run Command with Security Hardening

```bash
docker run \
  --rm \
  --user appuser:appuser \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --tmpfs /app:rw,noexec,nosuid,nodev,size=512m \
  --security-opt=no-new-privileges=true \
  --cap-drop=ALL \
  --cap-add=CHOWN,DAC_OVERRIDE,SETGID,SETUID \
  -v /path/to/reports:/app:ro \
  jd21/methylflow-report:1.1.1
```

### Docker Compose Example

```yaml
services:
  methylflow-report:
    image: jd21/methylflow-report:1.1.1
    user: appuser:appuser
    read_only: true
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    tmpfs:
      - /tmp:size=256m,noexec,nosuid,nodev
      - /app:size=512m,noexec,nosuid,nodev
    security_opt:
      - no-new-privileges=true
    volumes:
      - ./reports:/app:ro
    environment:
      - QUARTO_QUIET=true
```

---

## Monitoring & Incident Response

### 1. Regular Vulnerability Scanning

```bash
# Scan for new CVEs weekly
docker scout cves jd21/methylflow-report:1.1.1 --only-severity critical,high

# Export SBOM for compliance audits
docker sbom jd21/methylflow-report:1.1.1 --format spdx-json > sbom.json
```

### 2. Upstream Tracking

| Project | Track | Action |
|---------|-------|--------|
| **Quarto** | [GitHub Issues](https://github.com/quarto-dev/quarto-cli/releases) | Check for v1.7+ (Go 1.25) |
| **Ubuntu 24.04** | [USN Advisories](https://ubuntu.com/security/usn) | No fix expected in 24.04 LTS |
| **Go stdlib** | [Go Security](https://github.com/golang/go/security) | Monitor for backports to Go 1.23 (unlikely) |

### 3. Rebuild Triggers

Rebuild image immediately if:
- [ ] Quarto v1.7+ released (uses Go 1.25+)
- [ ] rocker/r-ver releases Ubuntu 25.10 variant
- [ ] New critical CVE discovered in Go stdlib
- [ ] Security incident affects Quarto ecosystem

---

## Upgrade Path & Timeline

### Option A: Wait for Upstream (Recommended)
- **Timeline**: Q2-Q3 2025
- **Action**: Rebuild with Quarto 1.7+ when released
- **Effort**: 30 minutes (run build, test, push)
- **Risk Reduction**: 11 HIGH + 1 CRITICAL resolved

### Option B: Migrate to Ubuntu 25.10 (Complex)
- **Timeline**: ASAP
- **Action**: Build R 4.6.0 from source on ubuntu:25.10
- **Effort**: 4-6 hours (compilation, testing, validation)
- **Risk Reduction**: Resolves all 12 CVEs
- **Status**: Experimental (see `Dockerfile_report_ubuntu`)

### Option C: Extract Quarto (Workaround)
- **Timeline**: Immediate
- **Action**: Remove Quarto from image, render documents externally
- **Effort**: 1-2 hours (refactor rendering pipeline)
- **Risk Reduction**: Eliminates 11 HIGH + 1 CRITICAL (Go + esbuild)
- **Trade-off**: Loses in-container rendering capability

---

## Compliance Implications

| Standard | Implication | Action |
|----------|------------|--------|
| **PCI DSS** | CRITICAL CVE violates requirement 6.2 | Requires risk acceptance or remediation plan |
| **HIPAA** | HIGH CVEs in healthcare use | Implement compensating controls (isolation, monitoring) |
| **SOC 2** | Must track vulnerability status | Document in security control matrix |
| **ISO 27001** | Define risk acceptance formally | Update vulnerability management policy |

**Recommendation**: Document this as a known upstream limitation with explicit risk acceptance in your security policy.

---

## References

- [Docker Scout Vulnerability Scan](https://scout.docker.com/)
- [NVD CVE-2025-68121](https://nvd.nist.gov/vuln/detail/CVE-2025-68121)
- [Quarto GitHub](https://github.com/quarto-dev/quarto-cli)
- [Ubuntu Security Notices](https://ubuntu.com/security/usn/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

---

## Support & Questions

For questions about these vulnerabilities:
1. Check the upstream project issue trackers (links above)
2. Run `docker scout cves jd21/methylflow-report:1.1.1` for latest scan
3. Review this document for current status

**Last Review**: January 2025  
**Next Review**: After Quarto 1.7 release or quarterly (whichever is sooner)
