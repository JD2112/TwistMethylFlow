# Runtime Hardening Examples for jd21/methylflow-report:1.1.1

This file provides ready-to-use Docker run and docker-compose configurations with security hardening applied to mitigate known CVEs.

---

## Docker Run Examples

### Minimal Hardened Run (Read-only, Isolated)

```bash
docker run \
  --rm \
  --name methylflow \
  --user appuser:appuser \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --tmpfs /app:rw,noexec,nosuid,nodev,size=512m \
  --security-opt=no-new-privileges=true \
  jd21/methylflow-report:1.1.1
```

**Security Flags Explained**:
- `--read-only` — Filesystem is read-only (prevents persistence of exploits)
- `--tmpfs` — Create temporary in-memory filesystems with strict mount options
  - `rw` — Readable and writable (required for temp storage)
  - `noexec` — No executable files can run from these mounts
  - `nosuid` — SUID bits ignored (prevents privilege escalation via files)
  - `nodev` — Device files ignored
  - `size=X` — Limit memory usage
- `--security-opt=no-new-privileges=true` — Child processes cannot gain more privileges than parent

### Production Hardened Run (with Volume Mount)

```bash
docker run \
  --rm \
  --name methylflow-prod \
  --user appuser:appuser \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --tmpfs /app:rw,noexec,nosuid,nodev,size=512m \
  --cap-drop=ALL \
  --cap-add=CHOWN,DAC_OVERRIDE,SETGID,SETUID \
  --security-opt=no-new-privileges=true \
  --security-opt=seccomp=unconfined \
  --log-driver=json-file \
  --log-opt=max-size=10m \
  --log-opt=max-file=3 \
  --memory=2g \
  --cpus=2 \
  --pids-limit=100 \
  -v /path/to/reports:/app:ro \
  -v /var/log/methylflow:/var/log:rw \
  jd21/methylflow-report:1.1.1
```

**Additional Security Controls**:
- `--cap-drop=ALL` — Drop all Linux capabilities
- `--cap-add=CHOWN,DAC_OVERRIDE,SETGID,SETUID` — Add only required capabilities
- `--memory=2g` — Limit memory to 2GB (prevents OOM attacks/resource exhaustion)
- `--cpus=2` — Limit CPU to 2 cores (prevents CPU exhaustion)
- `--pids-limit=100` — Max 100 processes (prevents fork bombs)
- `--log-*` — Structured logging with rotation (aids forensics)

### Development Hardened Run (with Volume Binding)

```bash
docker run \
  --rm \
  -it \
  --name methylflow-dev \
  --user appuser:appuser \
  --tmpfs /tmp:rw,noexec,nosuid,nodev,size=256m \
  --tmpfs /app:rw,noexec,nosuid,nodev,size=512m \
  --security-opt=no-new-privileges=true \
  --cap-drop=ALL \
  --cap-add=CHOWN,DAC_OVERRIDE \
  -v $(pwd)/reports:/app \
  jd21/methylflow-report:1.1.1 \
  quarto --version
```

---

## Docker Compose Examples

### Docker Compose v2 (Recommended)

```yaml
version: '3.9'

services:
  methylflow:
    image: jd21/methylflow-report:1.1.1
    container_name: methylflow-report
    user: appuser:appuser
    
    # Filesystem Security
    read_only: true
    tmpfs:
      - /tmp:size=256m,noexec,nosuid,nodev
      - /app:size=512m,noexec,nosuid,nodev
    
    # Capability Restrictions
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    
    # Privilege Restrictions
    security_opt:
      - no-new-privileges:true
    privileged: false
    
    # Resource Limits
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
    
    # Logging
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    
    # Volumes (read-only for data)
    volumes:
      - ./reports:/app:ro
      - methylflow-logs:/var/log
    
    # Health Check
    healthcheck:
      test: ["CMD", "quarto", "--version"]
      interval: 60s
      timeout: 15s
      retries: 3
      start_period: 20s
    
    # Environment
    environment:
      - QUARTO_QUIET=true
      - R_LIBS_USER=/tmp/rlibs
    
    # Restart Policy
    restart: unless-stopped

volumes:
  methylflow-logs:
    driver: local
```

### Kubernetes Deployment (Hardened Pod)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: methylflow-report
  namespace: default
  labels:
    app: methylflow
    version: v1.1.1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: methylflow
  template:
    metadata:
      labels:
        app: methylflow
        version: v1.1.1
    spec:
      serviceAccountName: methylflow
      
      # Security Context (Pod level)
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      
      # Resource Quotas
      containers:
      - name: methylflow
        image: jd21/methylflow-report:1.1.1
        imagePullPolicy: IfNotPresent
        
        # Security Context (Container level)
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
            add:
              - NET_BIND_SERVICE
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        
        # Port
        ports:
        - containerPort: 8080
          protocol: TCP
        
        # Liveliness & Readiness Probes
        livenessProbe:
          exec:
            command:
            - quarto
            - --version
          initialDelaySeconds: 20
          periodSeconds: 60
          timeoutSeconds: 15
          failureThreshold: 3
        
        readinessProbe:
          exec:
            command:
            - quarto
            - --version
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 2
        
        # Resources
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        
        # Volumes
        volumeMounts:
        - name: app
          mountPath: /app
          readOnly: true
        - name: tmp
          mountPath: /tmp
        - name: cache
          mountPath: /home/appuser/.cache
        
        # Env Variables
        env:
        - name: QUARTO_QUIET
          value: "true"
        - name: R_LIBS_USER
          value: "/tmp/rlibs"
      
      # Pod Network Policy (if needed)
      # dnsPolicy: ClusterFirst
      
      # Volumes
      volumes:
      - name: app
        configMap:
          name: methylflow-reports
          defaultMode: 0444
      - name: tmp
        emptyDir:
          sizeLimit: 256Mi
      - name: cache
        emptyDir:
          sizeLimit: 256Mi

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: methylflow
  namespace: default

---
apiVersion: v1
kind: Service
metadata:
  name: methylflow-report
  namespace: default
spec:
  selector:
    app: methylflow
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
```

---

## Network Security (iptables / UFW)

If running on host with network exposure:

### UFW (Ubuntu Firewall)

```bash
# Allow only from trusted subnets
sudo ufw allow from 10.0.0.0/8 to any port 8080 proto tcp
sudo ufw allow from 192.168.0.0/16 to any port 8080 proto tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

### iptables (Advanced)

```bash
# Drop all traffic by default
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# Allow loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow from specific subnet to container port
sudo iptables -A INPUT -s 10.0.0.0/8 -p tcp --dport 8080 -j ACCEPT

# Save
sudo iptables-save > /etc/iptables/rules.v4
```

---

## Monitoring & Logging

### Send Logs to Syslog

```bash
docker run \
  --log-driver=syslog \
  --log-opt syslog-address=unixgram:///dev/log \
  --log-opt tag="methylflow" \
  jd21/methylflow-report:1.1.1
```

### Monitor with Prometheus

```bash
docker run \
  --rm \
  -p 9323:9323 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  prom/node-exporter:latest
```

### Container Event Audit

```bash
# Real-time container events
docker events --filter 'image=jd21/methylflow-report:1.1.1' --format '{{json .}}'

# Log to file
docker events --filter 'image=jd21/methylflow-report:1.1.1' > /var/log/methylflow-docker.log
```

---

## Incident Response Checklist

If a container running this image is compromised:

- [ ] Stop container: `docker stop <container>`
- [ ] Preserve logs: `docker logs <container> > incident-$(date +%s).log`
- [ ] Preserve filesystem: `docker commit <container> methylflow-incident:$(date +%s)`
- [ ] Inspect container: `docker inspect <container>`
- [ ] Check network: `docker network inspect bridge`
- [ ] Review Docker daemon logs: `journalctl -u docker`
- [ ] Scan for related compromises: `docker ps -a --filter 'status=exited'`
- [ ] Notify security team
- [ ] Rebuild image and redeploy to clean environment

---

## References

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Container Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [AppArmor Profile Reference](https://gitlab.com/apparmor/apparmor/-/wikis/Documentation)
