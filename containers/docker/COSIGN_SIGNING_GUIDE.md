# Cosign Image Signing & Docker Hub Push Guide

## Prerequisites

✅ **Cosign installed**: v2.4.2  
✅ **Cosign keys generated**: `~/.cosign/cosign.key` and `~/.cosign/cosign.pub`  
✅ **Docker running locally**

## Images to Sign & Push

| Image | Version | Size | Status |
|-------|---------|------|--------|
| jd21/methylflow-main | 1.1.1 | 4.05 GB | ✅ Ready |
| jd21/methylflow-enrichment | 1.1.0 | 1.54 GB | ✅ Ready |
| jd21/methylflow-report | 1.1.4 | 1.21 GB | ✅ Ready |
| jd21/methylflow-unified | 1.1.3 | 1.04 GB | ✅ Ready |

**Total size**: ~7.8 GB

---

## Step-by-Step Instructions

### Step 1: Log In to Docker Hub

```bash
docker login
# Enter your Docker Hub username
# Enter your Docker Hub access token (or password)
```

**Note**: If you don't have an access token, generate one:
- Go to https://hub.docker.com/settings/security
- Click "New Access Token"
- Copy the token and use it as your password

### Step 2: Verify Local Images Exist

```bash
docker images | grep methylflow
```

Expected output:
```
jd21/methylflow-main:1.1.1       fb1053ea02fa   15.6GB   4.05GB
jd21/methylflow-enrichment:1.1.0 5b4f6a391d1e   6.22GB   1.54GB
jd21/methylflow-report:1.1.4     5e6c36454166   4.01GB   1.21GB
jd21/methylflow-unified:1.1.3    22fa929391b6   3.88GB   1.04GB
```

### Step 3: Push Images to Docker Hub

```bash
# Push each image
docker push jd21/methylflow-main:1.1.1
docker push jd21/methylflow-enrichment:1.1.0
docker push jd21/methylflow-report:1.1.4
docker push jd21/methylflow-unified:1.1.3
```

**Note**: First push will take 10-30 minutes per image depending on your internet speed. Subsequent pushes are faster due to layer caching.

Monitor progress:
```bash
docker push jd21/methylflow-main:1.1.1 -v  # Verbose output
```

### Step 4: Sign Images with Cosign

First, retrieve your cosign key password (it was generated and set during key creation):

```bash
# If you have the password stored, use it:
export COSIGN_PASSWORD="your-cosign-password"

# Then sign each image:
cosign sign --key ~/.cosign/cosign.key jd21/methylflow-main:1.1.1
cosign sign --key ~/.cosign/cosign.key jd21/methylflow-enrichment:1.1.0
cosign sign --key ~/.cosign/cosign.key jd21/methylflow-report:1.1.4
cosign sign --key ~/.cosign/cosign.key jd21/methylflow-unified:1.1.3
```

Each sign command will:
- Sign the image with your private key
- Upload the signature to Docker Hub (stored in `sha256-<digest>.sig`)
- Display the signature details

### Step 5: Verify Signatures

```bash
# Verify each signed image
cosign verify --key ~/.cosign/cosign.pub jd21/methylflow-main:1.1.1
cosign verify --key ~/.cosign/cosign.pub jd21/methylflow-enrichment:1.1.0
cosign verify --key ~/.cosign/cosign.pub jd21/methylflow-report:1.1.4
cosign verify --key ~/.cosign/cosign.pub jd21/methylflow-unified:1.1.3
```

Expected output (shows verified signature):
```json
[{
  "critical": {
    "identity": {
      "docker-reference": "jd21/methylflow-main:1.1.1"
    },
    "image": {
      "docker-manifest-digest": "sha256:..."
    },
    "type": "cosign container image signature"
  },
  "optional": {
    ...
  }
}]
```

### Step 6: (Optional) Share Public Key

To allow others to verify signatures, upload your public key:

```bash
# View your public key
cat ~/.cosign/cosign.pub

# Upload it to a public location (e.g., GitHub repo, personal website)
# Then others can verify with:
# cosign verify --key <path-to-your-pub-key> jd21/methylflow-main:1.1.1
```

---

## Automated Script (Optional)

Use the provided `sign-and-push.sh` script:

```bash
# Make it executable
chmod +x /Users/jyoda68/Documents/TwistNext/containers/docker/sign-and-push.sh

# Edit the script to add your cosign password:
# Find line: export COSIGN_PASSWORD="your-password-here"
# Replace with your actual password

# Run it
./sign-and-push.sh
```

---

## Troubleshooting

### Error: "operation not supported by device"
This occurs when cosign tries to access a hardware key that doesn't exist. Solution:
```bash
export COSIGN_PASSWORD="your-password"
cosign sign --key ~/.cosign/cosign.key <image>
```

### Error: "unauthorized: access denied"
Docker Hub login failed. Fix:
```bash
docker logout
docker login  # Try again
```

### Error: "signature upload failed"
Image not found on Docker Hub. Fix:
```bash
# Ensure image is pushed first
docker push jd21/methylflow-main:1.1.1 --all-tags
```

### Slow uploads?
Use `docker push` with progress monitoring:
```bash
docker push jd21/methylflow-main:1.1.1 --quiet  # Hide progress for faster output
```

---

## Verification Checklist

After completing all steps:

- [ ] All 4 images pushed to Docker Hub
- [ ] All 4 images signed with cosign
- [ ] Signatures verified with public key
- [ ] Public key uploaded (optional)
- [ ] SBOM generated (optional, see below)

---

## Optional: Generate SBOM for Each Image

After pushing, you can generate SBOMs:

```bash
docker sbom jd21/methylflow-main:1.1.1 --format spdx-json > sbom-main.json
docker sbom jd21/methylflow-enrichment:1.1.0 --format spdx-json > sbom-enrichment.json
docker sbom jd21/methylflow-report:1.1.4 --format spdx-json > sbom-report.json
docker sbom jd21/methylflow-unified:1.1.3 --format spdx-json > sbom-unified.json

# Sign SBOMs with cosign
cosign attach sbom --sbom sbom-main.json jd21/methylflow-main:1.1.1
cosign attach sbom --sbom sbom-enrichment.json jd21/methylflow-enrichment:1.1.0
cosign attach sbom --sbom sbom-report.json jd21/methylflow-report:1.1.4
cosign attach sbom --sbom sbom-unified.json jd21/methylflow-unified:1.1.3
```

---

## What Happens After Signing?

1. **Signatures stored in Docker Hub** — Under `sha256-<image-digest>.sig`
2. **Verifiable by others** — Anyone with your public key can verify authenticity
3. **Portable** — Signatures stored alongside images, transferred with image
4. **Immutable** — Can't be changed once signed (unless re-signed with new key)

---

## Security Notes

⚠️ **Keep cosign private key safe**:
- Don't commit to version control
- Use strong password for `~/.cosign/cosign.key`
- Back up in secure location
- Rotate periodically

✅ **Public key is safe to share**:
- Use for verification only
- Include in source control
- Upload to public sites

---

## Reference

- Cosign docs: https://docs.sigstore.dev/cosign/overview/
- Docker push docs: https://docs.docker.com/reference/cli/docker/image/push/
- SBOM generation: https://docs.docker.com/scout/sbom/
