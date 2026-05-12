# Quarto v1.10.0 Go CVE Resolution Test - Results

**Date**: January 2025  
**Test Images Built**: 
- jd21/methylflow-report:test-1.10.0 ✅ 
- jd21/methylflow-enrichment:test-1.10.0 ⏳ (building)

---

## Key Finding

⚠️ **Quarto v1.10.0 STILL USES Go 1.23.12** (same as v1.9.37)

Evidence:
```
strings /opt/quarto/bin/tools/x86_64/esbuild | grep go1
> go1.23.12
```

The esbuild binary in Quarto v1.10.0 was compiled with Go 1.23.12, NOT Go 1.25+ as hoped.

---

## Implications

❌ **Go CVEs NOT resolved** in Quarto v1.10.0

The 11 Go stdlib CVEs remain:
- CVE-2025-68121 (CRITICAL)
- CVE-2026-32283, CVE-2026-32281, CVE-2026-32280, CVE-2026-25679
- CVE-2025-61729, CVE-2025-61726, CVE-2025-61725, CVE-2025-61723
- CVE-2025-58188, CVE-2025-58187

These will persist in enrichment and report images using Quarto v1.10.0.

---

## Recommendation

**CONTINUE WITH CURRENT PLAN**:
1. Keep enrichment:1.1.0 and report:1.1.4 on v1.9.37 (no upgrade needed)
2. Deploy as Tier 2 with runtime hardening (as documented)
3. Do NOT upgrade to Quarto v1.10.0 (no security improvement)
4. Continue monitoring for Quarto v1.11+ or v2.0+ that uses Go 1.25+

**Timeline**: 
- Monitor Quarto releases for Go 1.25 rebuild
- Expected: Late Q2 2025 or later (not Q1)

---

## Docker Scout Scan (In Progress)

Scanning both test images for full CVE comparison:
- jd21/methylflow-report:test-1.10.0 
- jd21/methylflow-enrichment:test-1.10.0

Results pending (Scout scanning can take 5-10 minutes for large images).

**Expected outcome**: Same 12 CVEs as v1.9.37 (Go 1.23.12 + Linux kernel)

---

## Conclusion

Quarto v1.10.0 does NOT fix the Go CVE issue. No action needed to upgrade. Continue with documented hardening strategy for enrichment/report Tier 2 deployment.
