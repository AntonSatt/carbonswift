# CarbonShift Deployment Guide

This guide walks you through deploying the CarbonShift AI-powered carbon dashboard for the Grafana/AWS Hackathon.

## Prerequisites

Before starting, ensure you have:

1. **AWS Account** with permissions to:
   - Create EC2 instances
   - Create IAM roles and policies
   - Access Amazon Bedrock (Claude 3 model)
   - Create Security Groups

2. **Grafana Cloud Account** (free tier works):
   - Sign up at https://grafana.com
   - Create a new stack or use existing

3. **Local Tools Installed**:
   - Terraform >= 1.0
   - AWS CLI v2
   - curl, jq (for verification)

4. **AWS Credentials Configured**:
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, and default region
   ```

## Step 1: Configure Grafana Cloud

1. Log in to your Grafana Cloud account
2. Navigate to **Connections** → **Add new connection** → **Hosted Prometheus metrics**
3. Note the following values:
   - **Remote Write Endpoint**: `https://prometheus-prod-XX-XX.grafana.net/api/prom/push`
   - **Username/Instance ID**: Your numeric instance ID
   - **Password**: Generate an API token with **MetricsPublisher** role

## Step 2: Configure Terraform Variables

1. Copy the example variables file:
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```

2. Edit `terraform/terraform.tfvars` with your values:
   ```hcl
   aws_region = "eu-north-1"  # Stockholm, Sweden
   instance_type = "t3.micro"
   
   # From Grafana Cloud setup
   grafana_cloud_prometheus_url = "https://prometheus-prod-XX-XX.grafana.net/api/prom/push"
   grafana_cloud_prometheus_user = "123456"
   grafana_cloud_api_key = "your-api-token-here"
   ```

3. **IMPORTANT**: Never commit `terraform.tfvars` to version control!

## Step 3: Configure IAM Permissions

Your AWS user needs specific permissions to deploy this infrastructure.

### Option A: AWS Managed Policies (Easiest) ⭐

Attach these pre-built AWS managed policies to your IAM user:

```bash
# Via AWS Console: IAM → Users → Your User → Add permissions → Attach policies directly
# Or via CLI:
aws iam attach-user-policy --user-name your-user --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
aws iam attach-user-policy --user-name your-user --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-user-policy --user-name your-user --policy-arn arn:aws:iam::aws:policy/AmazonBedrockFullAccess
```

**Permissions included:**
- ✅ `IAMFullAccess` - Create and manage IAM roles for EC2
- ✅ `AmazonEC2FullAccess` - Create and manage EC2 instances
- ✅ `AmazonBedrockFullAccess` - Access AI models for insights

**Note**: These are broad permissions suitable for testing/hackathons. For production, use more restrictive custom policies.

### Option B: Custom Policy (More Restrictive)

If you encounter the 2048-character limit for inline policies, see `iam-policy-compact.json` for a minimal custom policy.

## Step 4: Enable Amazon Bedrock Access

Amazon Bedrock requires model access to be enabled in your AWS account:

1. Go to AWS Console → **Amazon Bedrock** → **Model access**
2. Click **Manage model access**
3. Enable access to:
   - **Anthropic Claude 3 Haiku** (recommended - fast and cost-effective)
   - **Anthropic Claude 3 Sonnet** (optional - higher quality)
4. Wait for approval (usually instant)

**Region Note**: Bedrock is accessed from `us-east-1` in the code, but your EC2 instances run in `eu-north-1`.

## Step 4: Deploy Infrastructure

Run the deployment script:

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

The script will:
1. Initialize Terraform
2. Validate configuration
3. Plan infrastructure changes
4. Deploy 3 EC2 instances with all services
5. Display endpoints and IPs

**Deployment time**: ~5-10 minutes for full setup

## Step 5: Verify Deployment

After deployment completes, wait 5-10 minutes for all services to initialize, then verify:

```bash
./scripts/verify.sh
```

This will test:
- ✓ Node Exporter on all instances
- ✓ Carbon Service health endpoints
- ✓ Carbon metrics availability
- ✓ AI Insight endpoints (Amazon Bedrock)

### Manual Verification

You can also manually test endpoints (replace `<IP>` with actual IPs from deployment output):

```bash
# Health check
curl http://<IP>:8080/health

# Carbon metrics
curl http://<IP>:8080/metrics

# AI-powered insight
curl http://<IP>:8080/ai-insight | jq '.'

# Node Exporter metrics
curl http://<IP>:9100/metrics
```

## Step 6: Import Grafana Dashboard

1. Log in to your Grafana Cloud stack
2. Navigate to **Dashboards** → **Import**
3. Click **Upload JSON file**
4. Select `grafana/dashboard.json` from this project
5. Click **Import**

The dashboard includes:
- Real-time CO2 emissions (actual in Sweden)
- "What If" regional comparison (SE, DE, GB, FR)
- Live grid carbon intensity from all regions
- CPU usage and system metrics
- AI optimization insight panels (see next step)

## Step 7: Configure AI Insight Panels

The AI insight panels need to be configured with your instance IPs:

### Option A: Using JSON API Data Source (Recommended)

For each AI panel (Web Server, API Server, Compute Worker):

1. Edit the panel
2. Change visualization type to **Table** or **Stat**
3. Add a new **JSON API** data source:
   - URL: `http://<INSTANCE_IP>:8080/ai-insight`
   - Method: GET
4. Configure field mappings to display:
   - `insight` (the AI recommendation)
   - `current_co2_g_hour`
   - `status`
   - `timestamp`

### Option B: Using Text Panel with Manual Updates

Keep the text panels and manually query the endpoints:

```bash
curl http://<IP>:8080/ai-insight
```

Then copy the insights into the panel content.

## Step 8: Test Load Simulation

To see AI insights for high-load scenarios:

```bash
# SSH to compute worker (replace IP)
ssh ubuntu@<COMPUTE_IP>

# Run stress test for 5 minutes
stress-ng --cpu 2 --timeout 300s
```

The AI will detect elevated emissions and provide optimization recommendations!

## Monitoring and Logs

### Check service logs on instances:

```bash
# User data setup log
ssh ubuntu@<IP> 'sudo tail -f /var/log/user-data.log'

# Carbon service log
ssh ubuntu@<IP> 'sudo journalctl -u carbon-service -f'

# Grafana Alloy log
ssh ubuntu@<IP> 'sudo journalctl -u alloy -f'

# Node Exporter log
ssh ubuntu@<IP> 'sudo journalctl -u node_exporter -f'
```

## Cost Estimation

**AWS Costs** (monthly, approximate):
- 3x t3.micro instances: ~$9/month (in eu-north-1)
- Data transfer: ~$1-2/month
- Amazon Bedrock (Claude 3 Haiku): ~$0.50-1/month for testing
- **Total**: ~$10-12/month

**Grafana Cloud**: Free tier (14-day retention)

## Cleanup

To destroy all infrastructure:

```bash
./scripts/destroy.sh
```

This will:
- Delete all EC2 instances
- Remove Security Groups
- Remove IAM roles and policies

**Note**: Grafana Cloud data is NOT affected.

## Testing & Workflow

### Using the Utility Scripts

**`verify.sh`** - Test all endpoints
```bash
./scripts/verify.sh
# Tests Node Exporter, Carbon Service, and AI endpoints
# Shows sample metrics
```

**`destroy.sh`** - Tear down infrastructure
```bash
./scripts/destroy.sh
# Removes all AWS resources
# Saves costs when not in use
# Your code and Grafana Cloud data are SAFE
```

**`deploy.sh`** - Deploy/redeploy infrastructure
```bash
./scripts/deploy.sh
# Creates all infrastructure from scratch
# Takes ~10 minutes
```

### The Destroy → Deploy Cycle

**It's completely safe to destroy and redeploy!**

```bash
./scripts/destroy.sh   # Remove everything (~5 min)
./scripts/deploy.sh    # Recreate everything (~10 min)
```

**What's preserved:**
- ✅ All your code files
- ✅ Grafana Cloud metrics history
- ✅ Dashboard configurations
- ✅ `terraform.tfvars` credentials

**What's recreated:**
- ↻ Fresh EC2 instances
- ↻ Security groups
- ↻ IAM roles

**Use cases:**
- Save costs overnight
- Reset to clean state
- Test deployment process

### SSH Access Without Keys

If you didn't configure SSH keys, use **EC2 Instance Connect** (browser-based terminal):

1. Go to AWS Console → EC2 → Instances
2. Select your instance
3. Click **"Connect"** → **"EC2 Instance Connect"**
4. Browser terminal opens instantly
5. Run commands like `stress-ng --cpu 2 --timeout 300s`

**No SSH keys required!** ✅

### When to Use `terraform taint`

Only needed when **code changes** but instances are still running:

```bash
# Modified code in user_data.sh?
cd terraform
terraform taint aws_instance.compute_worker
terraform apply
```

**NOT needed** after `destroy.sh` - instances don't exist, so `deploy.sh` creates fresh ones automatically.

## Troubleshooting

### Services not starting

Check the user-data log for errors:
```bash
ssh ubuntu@<IP> 'sudo tail -100 /var/log/user-data.log'
```

### Metrics not appearing in Grafana

1. Verify Grafana Cloud credentials in `terraform.tfvars`
2. Check Alloy is running: `ssh ubuntu@<IP> 'sudo systemctl status alloy'`
3. Check Alloy logs: `ssh ubuntu@<IP> 'sudo journalctl -u alloy -n 50'`

### Bedrock "AccessDeniedException"

1. Ensure model access is enabled in Amazon Bedrock console
2. Verify the IAM role has `bedrock:InvokeModel` permissions
3. Check IAM role is attached to instances:
   ```bash
   aws ec2 describe-instances --filters "Name=tag:Project,Values=CarbonShift" \
     --query 'Reservations[*].Instances[*].[InstanceId,IamInstanceProfile.Arn]' --output table
   ```

### Carbon metrics showing 0 or fallback values

The Nowtricity API might be rate-limited or unavailable. The service will use fallback values:
- Sweden: 25 gCO2/kWh
- Germany: 420 gCO2/kWh
- UK: 250 gCO2/kWh
- France: 60 gCO2/kWh

These are typical values and will still demonstrate the "What If" concept.

## Architecture Details

### Data Flow

1. **Node Exporter** → collects system metrics → port 9100
2. **Carbon Service** → fetches Nowtricity API → calculates CO2 → port 8080
3. **Grafana Alloy** → scrapes both services → sends to Grafana Cloud
4. **Grafana Dashboard** → queries Prometheus → displays visualizations
5. **AI Insight Endpoint** → queries metrics → calls Bedrock → returns optimization tips

### Security Notes

- Security Group allows public access to ports 8080, 9100, 12345
- For production: restrict to Grafana Cloud IPs and your IP
- SSH access on port 22 (add SSH key via `ssh_key_name` variable)
- IAM role follows least-privilege for Bedrock access

## FAQ

### Why don't CO2 emissions spike during stress tests?

The current carbon service calculates CO2 using a **constant power consumption** value (7W TDP for t3.micro), regardless of CPU usage.

**What happens:**
- ✅ CPU usage increases during stress test
- ❌ Power consumption stays at 7W (constant)
- ❌ CO2 emissions stay flat

This is a **known limitation** for the hackathon proof-of-concept. The architecture **supports** dynamic calculation based on CPU, but implementing it requires:
- Reading CPU metrics from Node Exporter or `/proc/stat`
- Scaling power between idle (2W) and max (7W) based on CPU %
- Complex rate calculations over time

**For the demo:** Focus on the "What If" regional analysis and AI insights - these work perfectly!

### How do dashboard metrics update?

**Automatic (every 15-30 seconds):**
- ✅ CO2 emissions
- ✅ Grid carbon intensity
- ✅ CPU usage
- ✅ System metrics
- ✅ "What If" comparisons

**Manual only:**
- ❌ AI insights (run `curl http://<IP>:8080/ai-insight` when needed)

**Reason:** AI calls cost money and take time. Manual querying is better for demos.

### Can I redeploy after running destroy.sh?

**Yes! Absolutely safe.** 

```bash
./scripts/destroy.sh   # Delete everything
./scripts/deploy.sh    # Recreate everything
```

Your code, credentials, and Grafana Cloud data are preserved locally. The deploy script rebuilds AWS infrastructure from scratch.

### Do I need to run terraform taint every time?

**No!** Only in specific situations:

**Need taint:**
- ✅ You modified `user_data.sh` code
- ✅ Instances are still running
- ✅ Want to apply code changes

**Don't need taint:**
- ✅ After `destroy.sh` (instances don't exist)
- ✅ Fresh deployment
- ✅ Never modified code

### How do I access instances without SSH keys?

Use **EC2 Instance Connect** (browser-based):
1. AWS Console → EC2 → Instances
2. Select instance → Click "Connect"
3. Choose "EC2 Instance Connect"
4. Browser terminal opens - no keys needed!

### Why use managed policies instead of custom policies?

**AWS Managed Policies** (IAMFullAccess, EC2FullAccess, BedrockFullAccess):
- ✅ No 2048-character limit
- ✅ Pre-built and tested by AWS
- ✅ Perfect for hackathons/testing
- ✅ Simple to attach

**Custom policies:**
- ⚠️ Hit 2048-character inline policy limit
- ⚠️ Tedious to debug permissions
- ✅ More secure for production

For a hackathon, managed policies are the pragmatic choice!

## Support and Contributions

For hackathon submission, include:
- Screenshots of the dashboard showing all 4 key panels
- Example AI insight from Bedrock
- Comparison showing CO2 difference between regions
- Brief demo video (optional but recommended)

## License

MIT License - See LICENSE file for details
