# Minimal Appliance - SSH Gateway

A secure SSH gateway running Ubuntu 22.04 with key-based authentication only, accessible on port 8222.

## Quick Start

### 1. Provision SSH Key

Run the setup script to generate a local SSH key pair for the gateway:

```bash
chmod +x setup-ssh-key.sh
./setup-ssh-key.sh
```

This script will:
- Create a `default-key/` directory (git-ignored)
- Generate a new ED25519 key pair specifically for this gateway
- Create the `authorized_keys` file for the container

### 2. Build and Start the Gateway

**Using docker-compose (recommended):**
```bash
docker-compose up -d --build
```

**Using docker directly:**
```bash
docker build -t minimal-appliance .
docker run -d -p 8222:22 --name minimal-appliance minimal-appliance
```

### 3. Connect via SSH

```bash
ssh -i default-key/id_rsa -p 8222 ubuntu@localhost
```

## Manual Setup

If you prefer to use your own SSH key:

1. Create the `default-key` directory:
   ```bash
   mkdir -p default-key
   ```

2. Copy your public key to `authorized_keys`:
   ```bash
   cp ~/.ssh/id_rsa.pub default-key/authorized_keys
   ```

3. Build and run:
   
   **With docker-compose:**
   ```bash
   docker-compose up -d --build
   ```
   
   **With docker:**
   ```bash
   docker build -t minimal-appliance .
   docker run -d -p 8222:22 --name minimal-appliance minimal-appliance
   ```

4. Connect with your key:
   ```bash
   ssh -p 8222 ubuntu@localhost
   ```

## Configuration

### Authentication

- **Username:** `ubuntu`
- **Authentication:** Key-based only (passwords disabled)
- **Root login:** Disabled
- **SSH key location:** `./default-key/` (git-ignored)

### Ports

- Host port: `8222`
- Container port: `22` (SSH)

### Volumes

The docker-compose configuration includes a mounted volume:
- `./data` → `/home/ubuntu/data` (persistent storage)

## Security Features

This SSH gateway is configured with security best practices:

✅ **Password authentication disabled** - Key-based authentication only  
✅ **Root login disabled** - Only `ubuntu` user can connect  
✅ **Strong key generation** - Uses ED25519 by default  
✅ **Local key storage** - Keys stored in git-ignored `default-key/` directory  
✅ **No default passwords** - No password authentication configured

### Additional Security Recommendations

1. **Restrict SSH key permissions:**
   ```bash
   chmod 600 default-key/id_rsa
   chmod 644 default-key/id_rsa.pub
   ```

2. **Use firewall rules** to restrict access to port 8222

3. **Rotate keys regularly** by running `./setup-ssh-key.sh` again

4. **Monitor access logs:**
   ```bash
   docker-compose logs -f
   ```

## Useful Commands

### View logs
**With docker-compose:**
```bash
docker-compose logs -f
```

**With docker:**
```bash
docker logs -f minimal-appliance
```

### Stop the container
**With docker-compose:**
```bash
docker-compose down
```

**With docker:**
```bash
docker stop minimal-appliance
docker rm minimal-appliance
```

### Rebuild after changes
**With docker-compose:**
```bash
docker-compose up -d --build
```

**With docker:**
```bash
docker stop minimal-appliance
docker rm minimal-appliance
docker build -t minimal-appliance .
docker run -d -p 8222:22 --name minimal-appliance minimal-appliance
```

### Access container shell directly
```bash
docker exec -it minimal-appliance /bin/bash
```

### Check SSH service status inside container
```bash
docker exec minimal-appliance service ssh status
```

## Troubleshooting

### Connection Refused

1. Check if container is running:
   ```bash
   docker ps | grep minimal-appliance
   ```

2. Check SSH service inside container:
   ```bash
   docker exec minimal-appliance service ssh status
   ```

3. Check port mapping:
   ```bash
   docker port minimal-appliance
   ```

### Permission Denied (publickey)

1. Ensure `authorized_keys` was created:
   ```bash
   ls -la default-key/
   docker exec minimal-appliance cat /home/ubuntu/.ssh/authorized_keys
   ```

2. Check file permissions:
   ```bash
   docker exec minimal-appliance ls -la /home/ubuntu/.ssh/
   ```

3. Verify you're using the correct key:
   ```bash
   ssh -i default-key/id_rsa -p 8222 ubuntu@localhost -v
   ```

4. Ensure private key has correct permissions:
   ```bash
   chmod 600 default-key/id_rsa
   ```

### Can't Connect on Port 8222

Check if the port is already in use:
```bash
lsof -i :8222
```

If occupied, change the port in `docker-compose.yml`:
```yaml
ports:
  - "8223:22"  # Use a different port
```
