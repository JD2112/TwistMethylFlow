# Vulnerability Analysis: jd21/methylflow-report:1.1.1

## Summary
Image contains 2 vulnerable packages with 12 total CVEs (4 CRITICAL, 27 HIGH).

## Root Causes

### 1. Go stdlib 1.23.12 (in Quarto's bundled esbuild) — **11 CVEs**
- **Source**: Quarto 1.9.37 ships with esbuild compiled against Go 1.20.12/1.23.12
- **Impact**: 1 CRITICAL (CVE-2025-68121) + 10 HIGH
- **Fix**: Requires Quarto to release a new binary built with Go 1.24.13+ or 1.25.8+
- **Workaround**: Strip esbuild from image if not needed, or replace with precompiled Go 1.25 binary (requires source rebuild)
- **Status**: UPSTREAM ISSUE — waiting for Quarto patch

### 2. Linux kernel 6.8.0-111 (in Ubuntu 24.04) — **1 CVE**
- **CVE-2026-31431**: HIGH severity, no fix in ubuntu:24.04
- **Impact**: Kernel-level vulnerability, unfixable in 24.04 stream
- **Mitigation**: Upgrade to Ubuntu 25.10+ (not compatible with rocker/r-ver:4.6.0)
- **Status**: BLOCKED — base OS limitation

## Recommendations

1. **Short-term**: Accept vulnerability and file upstream issue with Quarto team
2. **Medium-term**: Wait for Quarto 1.7+ release with Go 1.25
3. **Long-term**: Migrate to custom R build on ubuntu:25.10 (see `Dockerfile_report_ubuntu`)

## Files
- `Dockerfile_report`: Current production (1.1.1) — 12 CVEs
- `Dockerfile_report_ubuntu`: Experimental Ubuntu 25.10 base (WIP)

