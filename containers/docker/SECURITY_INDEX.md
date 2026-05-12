# Security Documentation Index

**Image**: jd21/methylflow-report:1.1.1  
**Last Updated**: January 2025  
**CVEs**: 12 known (1 CRITICAL, 11 HIGH) — All unfixable (upstream limitation)

---

## Quick Navigation

| Document | Purpose | Audience | Read Time |
|----------|---------|----------|-----------|
| **[SECURITY.md](./SECURITY.md)** | Complete vulnerability analysis, risk assessment, compliance | Security teams, DevOps, architects | 15 min |
| **[RESOLUTION_SUMMARY.md](./RESOLUTION_SUMMARY.md)** | Investigation results, why unfixable, operational recommendations | Managers, tech leads, security staff | 10 min |
| **[HARDENING_EXAMPLES.md](./HARDENING_EXAMPLES.md)** | Ready-to-use Docker/K8s configs with security hardening | DevOps, platform engineers | 15 min |
| **[Dockerfile_report](./Dockerfile_report)** | Image source with inline security annotations | Developers, build engineers | 5 min |
| **[This file]** | Navigation and summary | Everyone | 2 min |

---

## Key Facts (TL;DR)

✅ **Status**: RESOLVED via documentation & hardening (not image patching)

❌ **Why Not Patchable**:
- Go 1.23.12 is statically-linked inside Quarto binary (unfixable without upstream rebuild)
- Linux kernel CVE has no patch in Ubuntu 24.04 (unfixable without major OS upgrade)

🔒 **Mitigation**: Apply runtime hardening controls (read-only FS, capability drop, resource limits)

⏳ **Timeline**: Quarto v1.7 (with Go 1.25) expected Q2 2025 → rebuild then

---

## Vulnerability Summary

### CVE #1: Go stdlib 1.23.12 (11 vulnerabilities: 1 CRITICAL + 10 HIGH)
- **In**: Quarto 1.9.37 esbuild binary
- **Fixable**: NO — requires Quarto upstream rebuild with Go 1.24.13+
- **Risk**: MEDIUM (exploitation requires processing untrusted Quarto documents)
- **ETA**: Quarto v1.7+ (Q2 2025)

### CVE #2: Linux kernel 6.8.0-111 (1 vulnerability: HIGH)
- **In**: Ubuntu 24.04 base image
- **Fixable**: NO — no patch in 24.04 stream
- **Risk**: LOW (requires container escape)
- **Workaround**: Upgrade to Ubuntu 25.10 (blocks rocker/r-ver compatibility)

---

## Safe Usage

✅ **RECOMMENDED** (LOW RISK):
- Batch processing with trusted R code
- Internal reporting only (non-public)
- Read-only filesystem deployments
- Short-lived containers

⚠️ **USE WITH CAUTION** (MEDIUM RISK):
- User-submitted Quarto documents
- Multi-tenant deployments
- Long-running services

❌ **NOT RECOMMENDED** (HIGH RISK):
- Public web APIs
- HIPAA/PCI-DSS without formal risk acceptance
- Security-critical applications

---

## Getting Started (Security Checklist)

- [ ] **Read**: SECURITY.md (full details)
- [ ] **Assess**: Does your use case match "SAFE" above?
- [ ] **Implement**: Choose hardening config from HARDENING_EXAMPLES.md
- [ ] **Deploy**: Use selected Docker/K8s config
- [ ] **Monitor**: Set calendar reminder for Quarto v1.7 release
- [ ] **Document**: Add security annotations to your deployment documentation

---

## For Different Roles

### 👨‍💼 Project Manager / Security Officer
→ Start with **RESOLUTION_SUMMARY.md**
- Understand what's wrong and why it can't be fixed
- Review compliance implications (PCI-DSS, HIPAA, SOC 2)
- Approve risk acceptance & mitigation strategy

### 👨‍💻 DevOps / Platform Engineer
→ Start with **HARDENING_EXAMPLES.md**
- Copy hardened docker-compose or K8s manifests
- Integrate into deployment pipeline
- Set up vulnerability scanning

### 🔐 Security Team
→ Start with **SECURITY.md**
- Complete vulnerability analysis
- Attack surface assessment
- Incident response procedures
- Monitoring setup

### 👨‍🚀 Developer
→ Check **Dockerfile_report** + inline comments
- Understand security labels in image metadata
- Use hardened examples in development
- Report new findings to security team

---

## Quick Commands

```bash
# View image security annotations
docker inspect jd21/methylflow-report:1.1.1 | jq '.Config.Labels | select(.[].security*)'

# Scan for CVEs (slow, ~2 min)
docker scout cves jd21/methylflow-report:1.1.1 --only-severity critical,high

# Run with hardening (read-only, isolated)
docker run --rm --read-only --tmpfs /tmp:noexec,nosuid --security-opt=no-new-privileges=true jd21/methylflow-report:1.1.1

# Check upstream status (Quarto releases)
curl -s https://api.github.com/repos/quarto-dev/quarto-cli/releases | jq '.[] | select(.tag_name | contains("1.7"))'
```

---

## Timeline & Next Steps

| When | Action | Owner |
|------|--------|-------|
| NOW | Review SECURITY.md, approve risk, implement hardening | Security + DevOps |
| Weekly | Run `docker scout cves` | DevOps |
| Monthly | Review logs for exploit attempts | Security |
| Q2 2025 | Check Quarto releases for v1.7+ | DevOps |
| After Quarto 1.7 | Rebuild image, re-scan, redeploy | DevOps |

---

## Frequently Asked Questions

**Q: Can we fix these CVEs?**  
A: No. Both are in upstream projects (Quarto, Ubuntu) that don't provide patches. See RESOLUTION_SUMMARY.md for details.

**Q: Is this image safe to use?**  
A: Yes, for trusted workloads. Apply runtime hardening (read-only FS, capability drop). See HARDENING_EXAMPLES.md.

**Q: What if our compliance requires zero CVEs?**  
A: You have three options: (1) Get formal risk acceptance approved, (2) Wait for Quarto v1.7 (Q2 2025), (3) Migrate to external Quarto rendering service.

**Q: Will this break when I upgrade to Quarto 1.7?**  
A: No. When Quarto v1.7+ is released with Go 1.25, you'll rebuild this image using that new Quarto version, reducing 11 CVEs.

**Q: Do I need to rebuild the image now?**  
A: No. The current image (1.1.1) is stable and functional. Rebuild only when Quarto v1.7+ is released.

---

## Support Resources

- **Quarto Releases**: https://github.com/quarto-dev/quarto-cli/releases
- **CVE Details**: Search https://nvd.nist.gov for CVE IDs
- **Docker Scout**: https://scout.docker.com
- **Ubuntu Security**: https://ubuntu.com/security/usn

---

## Document Revisions

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 2025 | Initial security audit & documentation |

---

**Need help?** Check the relevant doc above, then escalate to your security team.
