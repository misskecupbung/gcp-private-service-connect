# GCP Private Service Connect

Access Google APIs through private endpoints instead of routing through the public internet.

By default, when your VMs call Google APIs (Cloud Storage, BigQuery, Pub/Sub), traffic goes out to public IP addresses. Private Service Connect (PSC) creates a private endpoint inside your VPC, so API calls stay within Google's network.

> **Duration**: 30 minutes  
> **Level**: Intermediate

**What you'll build:**
- Private endpoint for Google APIs inside your VPC
- DNS override that resolves googleapis.com to your private IP
- Works for all Google APIs (Storage, BigQuery, Pub/Sub, etc.)

## Architecture

## Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed and authenticated
- Terraform >= 1.0

## Deploy

### Step 0: Clone the Repo

```bash
git clone https://github.com/misskecupbung/gcp-private-service-connect.git
cd gcp-private-service-connect
```

### Step 1: Enable APIs

```bash
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

gcloud services enable compute.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable iap.googleapis.com
```

### Step 2: Deploy with Terraform

```bash
cd terraform

cp terraform.tfvars.example terraform.tfvars
sed -i "s/your-project-id/$PROJECT_ID/" terraform.tfvars

# Deploy
terraform init
terraform plan
terraform apply
```

Terraform creates:
- 1 VPC with subnet (`10.1.0.0/24`)
- 1 test VM (no public IP)
- Cloud Router + Cloud NAT (for startup script package installation)
- Private Service Connect endpoint for Google APIs (`10.1.0.100`)
- Private DNS zone (routes `*.googleapis.com` + specific records to PSC endpoint)
- Firewall rules for IAP SSH

### Step 3: Check Outputs

```bash
terraform output
```

You'll see:
- `test_vm_internal_ip` - IP of test-vm
- `psc_endpoint_ip` - Private endpoint (10.1.0.100)

## Verify

### 1. Check DNS Resolution

```bash
# SSH into test-vm
gcloud compute ssh test-vm --zone=us-central1-a --tunnel-through-iap

# Check DNS - should return 10.1.0.100, NOT a public IP
nslookup storage.googleapis.com

# Try other Google APIs - all should resolve to 10.1.0.100
nslookup bigquery.googleapis.com
nslookup pubsub.googleapis.com
```

Expected: All googleapis.com addresses resolve to `10.1.0.100`

### 2. Test Cloud Storage Access

```bash
# Still inside test-vm

# List a public bucket through private endpoint
gsutil ls gs://gcp-public-data-landsat 2>/dev/null | head -5

# If you have your own bucket
gsutil ls gs://your-bucket-name

# Exit VM
exit
```

The traffic goes through your PSC endpoint, not the public internet.

### 3. Compare With and Without PSC

To see the difference, you can temporarily check what public DNS would return:

```bash
# Inside test-vm

# Your private DNS returns PSC IP
nslookup storage.googleapis.com

# Public DNS would return Google's public IPs
nslookup storage.googleapis.com 8.8.8.8
```

## How It Works

1. **PSC Endpoint** - A forwarding rule that creates a private IP (10.1.0.100) pointing to Google APIs

2. **Private DNS Zone** - Overrides public DNS for `*.googleapis.com`, returning your PSC IP instead

3. **Traffic Flow** - When test-vm calls any Google API, DNS returns 10.1.0.100, and traffic routes privately

## Cleanup

```bash
cd terraform
terraform destroy
```

## Resources

- [Private Service Connect](https://cloud.google.com/vpc/docs/private-service-connect)
- [Configure PSC for Google APIs](https://cloud.google.com/vpc/docs/configure-private-service-connect-apis)

## License

MIT
