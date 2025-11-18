# 🎬 CarbonShift Demo Presentation Script
**Duration**: ~3 minutes | **For**: Grafana/AWS Hackathon Video Demo

---

## 🎯 Quick Overview
**CarbonShift** is an AI-powered observability dashboard that tracks real-time CO2 emissions from AWS infrastructure and provides intelligent optimization recommendations using Amazon Bedrock.

---

## ⏱️ Demo Timeline & Script

### **[0:00-0:30] Opening & Problem Statement**

**Script:**
> "Hi! I'm presenting CarbonShift - an AI-powered carbon monitoring dashboard for AWS infrastructure. As cloud computing grows, so does its environmental impact. But most teams lack visibility into their carbon footprint. CarbonShift solves this by providing real-time CO2 emissions tracking with AI-powered optimization insights."

**Action:**
- Show the full Grafana dashboard on screen
- Highlight the title: "CarbonShift - AI-Powered Carbon Dashboard"

---

### **[0:30-1:00] Start CPU Load Test**

**Script:**
> "Let me start by demonstrating real-time monitoring. I'm connecting to one of our EC2 compute workers in AWS and running a CPU stress test. This will simulate high workload and we'll watch the carbon emissions change in real-time throughout the demo."

**Actions:**
1. **Switch to AWS Console or Terminal**
2. **Connect to EC2 compute-worker** via AWS EC2 Instance Connect or SSH
3. **Run the stress command:**
   ```bash
   stress-ng --cpu 2 --timeout 300s
   ```
4. **Explain briefly:** "This runs a 5-minute CPU stress test at 100% utilization on 2 cores"
5. **Switch back to Grafana dashboard**

**Note:** This needs to run for ~5 minutes to show impact, so start it early!

---

## 📊 Dashboard Walkthrough [1:00-2:45]

### **[1:00-1:20] Panel 1 & 2: Pricing vs Carbon Intensity**

**Navigate to:** Top row of "Pricing & Carbon Emissions Data" section

#### **TC2 Instance Pricing / hourly** (Left Panel)
**Script:**
> "First, let's look at EC2 pricing across regions. Sweden is the most expensive at $0.078/hour, while Germany and France are around $0.012/hour. But price isn't the whole story..."

**Key Points:**
- Sweden (SE): $0.0784/hour ⚠️ Most expensive
- Germany (DE): $0.012/hour ✅ Cheapest
- France (FR): $0.0118/hour
- Britain (GB): $0.0118/hour

#### **Carbon Intensity per Dollar** (Right Panel)
**Script:**
> "Here's where it gets interesting - this shows grams of CO2 emitted per dollar spent. Sweden, despite being more expensive, only produces 42 grams of CO2 per dollar. Germany produces 257 grams - that's 6x dirtier! This is the key insight: cheaper doesn't mean cleaner."

**Key Points:**
- 🟢 Sweden: 42.2 g CO2/USD (cleanest - hydro/nuclear power)
- 🟡 France: 126.3 g CO2/USD (nuclear power)
- 🟠 Britain: 222.0 g CO2/USD
- 🔴 Germany: 256.7 g CO2/USD (dirtiest - coal dependency)

**Talking Point:**
"Lower is better here - it means you're getting cleaner computing per dollar spent."

---

### **[1:20-1:50] Panel 3: Regional Comparison**

**Navigate to:** Right panel in "What If Analysis" section

#### **Regional Comparison (Current)** - Bar Gauge
**Script:**
> "This is our 'What If' analysis. We're actually running in Sweden, but this shows what our CO2 emissions would be if we ran the exact same workload in other regions. Right now we're at about 3.3 grams per hour in Sweden. If we moved to Germany, we'd emit over 9 grams - nearly 3x more CO2 from the same workload!"

**Key Metrics to Highlight:**
- 🟢 **SE (Sweden) - ACTUAL**: ~3.3 g/h (cleanest, where we are)
- 🔵 **FR (France) - What If**: ~4.9 g/h (2nd best option)
- 🟠 **GB (Britain) - What If**: ~8.9 g/h
- 🔴 **DE (Germany) - What If**: ~9.5 g/h (worst option)

**Visual Cue:** The bars are color-coded - green for clean, red for dirty

---

### **[1:50-2:10] Panel 4: Grid Carbon Intensity Timeline**

**Navigate to:** "Grid Carbon Intensity by Region (24h Average)" - Large graph at bottom

#### **Brief Overview**
**Script:**
> "This shows live carbon intensity from electrical grids across Europe over the last 24 hours. The data comes from real-time grid APIs. You can see Sweden consistently stays below 50 grams of CO2 per kilowatt-hour, while Germany spikes above 400 during peak hours. This volatility is due to Germany's reliance on fossil fuels, while Sweden uses mostly hydroelectric and nuclear."

**Key Observations:**
- 🇸🇪 Sweden: Flat, stable, ~25-50 gCO2/kWh (renewable heavy)
- 🇩🇪 Germany: Volatile, 350-450 gCO2/kWh (fossil fuel dependent)
- 🇫🇷 France: Low, stable, ~60-100 gCO2/kWh (nuclear)
- 🇬🇧 Britain: Medium volatility, ~200-280 gCO2/kWh (mixed)

**Quick Note:** "The legend shows last value, mean, min, and max for each region"

---

### **[2:10-2:30] Panel 5: Carbon AI Assistant**

**Navigate to:** "🤖 Carbon AI Assistant" panel (text/markdown panel)

#### **AI-Powered Optimization with Amazon Bedrock**
**Script:**
> "Here's where our AI integration comes in. We use Amazon Bedrock with Claude 3 to analyze our infrastructure and provide intelligent recommendations. The AI looks at our current emissions, compares regional options, and suggests optimizations."

**Highlight the AI conversation:**
1. **Analysis**: "You're in one of the cleanest regions" ✅
2. **Current metrics**: 3.3 g CO2/hour, 42 gCO2/kWh
3. **Recommendations**:
   - Stay in Sweden (already optimal)
   - Optimize CPU usage via auto-scaling
   - Migration to Germany would increase emissions by 226%
4. **Next steps**: CPU pattern monitoring, renewable energy credits

**Integration Point:**
> "This integrates seamlessly with Grafana Assistant - we can ask questions about our carbon footprint and get AI-powered answers in real-time. The AI has access to all our metrics via a Flask API that queries Prometheus and calls Bedrock."

**Technical Detail:**
"Behind the scenes, we have a Python Flask service that exposes an `/ai-insight` endpoint. It pulls current metrics, sends them to Amazon Bedrock's Claude 3 model, and returns optimization recommendations based on real data."

---

### **[2:30-2:45] Panel 6: CPU Usage Impact**

**Navigate to:** "CPU Usage by Instance" - Bottom left timeseries graph

#### **Live Monitoring of Stress Test**
**Script:**
> "Remember that stress test we started? Let's see the impact. This graph shows CPU usage per instance - and you can see our compute-worker spiking to nearly 100% from our stress test. This directly impacts carbon emissions."

**Key Points:**
- **web-server**: Low, stable CPU (~5-10%)
- **api-server**: Low, stable CPU (~5-10%)
- **compute-worker**: 📈 Spiking to ~100% (from stress-ng)

**Connection to Carbon:**
> "Higher CPU usage means more power consumption, which means more CO2 emissions. The AI can detect these patterns and suggest right-sizing instances or using auto-scaling to reduce waste during idle periods."

**Visual Note:** "The graph should show a clear spike corresponding to when we started the stress test"

---

### **[2:45-3:00] Closing & Impact**

**Script:**
> "So in summary: CarbonShift gives you real-time visibility into your cloud carbon footprint with AI-powered insights. We're using real grid data from the Nowtricity API, monitoring with Prometheus and Grafana Cloud, and leveraging Amazon Bedrock for intelligent recommendations. This isn't just about emissions - it's about making smarter infrastructure decisions."

**Key Takeaways:**
- ✅ **Real-time monitoring** of actual infrastructure CO2 emissions
- ✅ **'What If' analysis** across multiple regions
- ✅ **AI-powered recommendations** via Amazon Bedrock
- ✅ **Actionable insights** to reduce both cost and carbon

**Final Line:**
> "Because the cheapest region isn't always the cleanest - and with the right visibility, we can make better decisions for both our budget and the planet. Thank you!"

---

## 🛠️ Technology Stack

### **Infrastructure & Deployment**
- **Cloud Provider**: AWS (eu-north-1 - Stockholm, Sweden)
- **Compute**: 3× t3.micro EC2 instances (web-server, api-server, compute-worker)
- **Infrastructure as Code**: Terraform
- **Operating System**: Ubuntu 22.04 LTS
- **IAM**: Custom role with Bedrock access permissions

### **Monitoring Stack**
- **Metrics Collection**: Prometheus + Node Exporter (system metrics)
- **Metrics Agent**: Grafana Alloy (collects and forwards metrics)
- **Observability Platform**: Grafana Cloud (visualization & storage)
- **Time Series Database**: Grafana Cloud Prometheus

### **Backend Services**
- **Language**: Python 3.9+
- **Framework**: Flask (lightweight web framework)
- **Carbon Service**: Custom Python service with two main endpoints:
  - `/metrics` - Prometheus format metrics
  - `/ai-insight` - AI-powered optimization recommendations
  - `/health` - Health check endpoint

### **AI & Machine Learning**
- **AI Platform**: Amazon Bedrock
- **Model**: Anthropic Claude 3 Haiku (fast, cost-effective)
- **Use Case**: Natural language insights and optimization recommendations
- **Integration**: REST API from Python Flask → Bedrock → Grafana

### **Data Sources & APIs**
- **Carbon Intensity API**: Nowtricity API (real-time grid data)
- **Regions Monitored**: Sweden (SE), Germany (DE), France (FR), United Kingdom (GB)
- **Metrics Exposed**: Prometheus format (compatible with Grafana)

### **Visualization**
- **Platform**: Grafana Cloud
- **Dashboard**: Custom JSON dashboard
- **Data Source**: Grafana Cloud Prometheus
- **Panel Types**: Bar charts, time series, gauges, stat panels, text/markdown

### **Development & DevOps**
- **Version Control**: Git
- **Scripts**: Bash deployment/verification scripts
- **Configuration**: Terraform variables, systemd services
- **Monitoring**: CloudWatch, systemd journald logs

---

## 🌐 API Integrations Explained

### **1. Nowtricity API** (Real-time Grid Carbon Intensity)

#### **Purpose**
Provides live carbon intensity data from electricity grids across Europe.

#### **What it does**
- Fetches current grams of CO2 per kilowatt-hour (gCO2/kWh) for each region
- Updates every 5-30 minutes depending on grid provider
- Covers: Sweden (SE), Germany (DE), France (FR), United Kingdom (GB)

#### **How we use it**
```python
# Python Flask service polls Nowtricity API
GET https://api.nowtricity.com/data
→ Returns: {country: "SE", intensity: 42}

# We then calculate instance emissions:
CO2_emissions = Power_consumption × Carbon_intensity × Time
```

#### **Example Data**
```
Sweden (SE):    25-50 gCO2/kWh  (hydro + nuclear)
France (FR):    60-100 gCO2/kWh (nuclear)
UK (GB):        200-280 gCO2/kWh (mixed)
Germany (DE):   350-450 gCO2/kWh (coal + gas)
```

#### **Fallback Values**
If the API is unavailable, we use typical values to ensure the demo continues working.

---

### **2. Amazon Bedrock API** (AI-Powered Insights)

#### **Purpose**
Provides AI-powered analysis and optimization recommendations for carbon footprint.

#### **Model Used**
- **Anthropic Claude 3 Haiku**: Fast, intelligent, cost-effective
- **Context window**: Handles comprehensive metrics and comparisons
- **Response style**: Conversational, actionable recommendations

#### **What it does**
1. Receives current infrastructure metrics (CPU, emissions, region)
2. Analyzes patterns and compares against other regions
3. Generates natural language insights and recommendations
4. Suggests specific optimization strategies

#### **Integration Flow**
```
Prometheus Metrics → Python Flask Service → Amazon Bedrock API
                                            ↓
                                      Claude 3 Analysis
                                            ↓
                                    JSON Response with Insights
                                            ↓
                                    Grafana Dashboard Display
```

#### **API Call Example**
```python
import boto3

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

response = bedrock.invoke_model(
    modelId='anthropic.claude-3-haiku-20240307-v1:0',
    body=json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "messages": [{
            "role": "user",
            "content": f"Analyze carbon footprint: {metrics}"
        }],
        "max_tokens": 1000
    })
)
```

#### **Sample AI Response**
```
✅ Good News: You're in Sweden (42 gCO2/kWh) - one of the cleanest regions!

Current emissions: 3.3 g CO2/hour

💡 Recommendations:
1. Stay in Sweden - already optimal
2. Consider auto-scaling during low-traffic periods
3. Migration to Germany would INCREASE emissions by 226%

🎯 Next Steps:
- Monitor CPU patterns for right-sizing
- Schedule batch jobs during off-peak grid hours
```

#### **IAM Permissions Required**
```json
{
  "Effect": "Allow",
  "Action": "bedrock:InvokeModel",
  "Resource": "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku-*"
}
```

---

### **3. Prometheus Metrics API** (Internal)

#### **Purpose**
Exposes calculated carbon metrics in Prometheus format for Grafana to scrape.

#### **Endpoints**
- **Port**: 8080
- **Path**: `/metrics`
- **Format**: Prometheus text-based format

#### **Metrics Exposed**
```prometheus
# Current grid carbon intensity per region
grid_carbon_intensity_g_kwh{country="SE"} 42.0

# Calculated instance CO2 emissions
instance_co2_emissions_g_hour{country="SE",role="web-server"} 1.1
instance_co2_emissions_g_hour{country="SE",role="api-server"} 1.1
instance_co2_emissions_g_hour{country="SE",role="compute-worker"} 1.1

# What-if scenarios for other regions
instance_co2_emissions_g_hour{country="DE",role="web-server"} 3.5
instance_co2_emissions_g_hour{country="FR",role="web-server"} 1.5
# ... etc for all instances and regions
```

#### **How Grafana Uses It**
1. Grafana Alloy scrapes `/metrics` every 15 seconds
2. Forwards to Grafana Cloud Prometheus
3. Dashboard queries Prometheus for visualization
4. Updates displayed in real-time

---

## 🔧 Commands & Technical Setup

### **Stress Test Command**

#### **Command to Run**
```bash
stress-ng --cpu 2 --timeout 300s
```

#### **Breakdown**
- `stress-ng`: CPU stress testing tool (pre-installed on instances)
- `--cpu 2`: Stress 2 CPU cores
- `--timeout 300s`: Run for 300 seconds (5 minutes)

#### **When to Execute**
- **Timing**: Start at 0:30 mark (early in demo)
- **Why**: Needs ~2-3 minutes to show visible impact on graphs
- **Where**: SSH/Connect to **compute-worker** EC2 instance

#### **Expected Impact**
- CPU usage spikes from ~5% → ~100%
- CO2 emissions increase proportionally
- Visible in "CPU Usage by Instance" graph
- AI may detect and suggest optimization

#### **AWS Connection Options**

**Option 1: EC2 Instance Connect (Browser-based)**
```bash
# From AWS Console:
EC2 → Instances → carbon-shift-compute-worker → Connect → EC2 Instance Connect
```

**Option 2: SSH (Terminal)**
```bash
ssh -i your-key.pem ubuntu@<COMPUTE-WORKER-IP>
```

**Option 3: AWS CLI Session Manager**
```bash
aws ssm start-session --target <INSTANCE-ID>
```

---

### **Verification Commands**

#### **Check Carbon Service**
```bash
curl http://<INSTANCE-IP>:8080/health
# Expected: {"status": "healthy"}

curl http://<INSTANCE-IP>:8080/metrics
# Expected: Prometheus metrics output

curl http://<INSTANCE-IP>:8080/ai-insight
# Expected: JSON with AI recommendations
```

#### **Check Node Exporter**
```bash
curl http://<INSTANCE-IP>:9100/metrics | grep node_cpu
# Expected: CPU metrics
```

---

## 📝 Dashboard Panel Quick Reference

| **Panel Name** | **Type** | **Key Metric** | **What It Shows** |
|---|---|---|---|
| EC2 Instance Pricing / hourly | Bar Chart | USD/hour | Pricing comparison across regions |
| Carbon Intensity per Dollar | Bar Gauge | g CO2/USD | Emissions efficiency per dollar spent |
| Regional Comparison (Current) | Bar Gauge | g CO2/h | "What if" emissions in different regions |
| Grid Carbon Intensity (24h) | Time Series | gCO2/kWh | Live grid data over time |
| Carbon AI Assistant | Text/Markdown | N/A | AI recommendations from Bedrock |
| CPU Usage by Instance | Time Series | % | CPU utilization per instance role |

---

## 🎬 Demo Tips & Best Practices

### **Before Recording**
- [ ] Verify all 3 EC2 instances are running
- [ ] Check Grafana dashboard loads with live data
- [ ] Test stress-ng command on compute-worker
- [ ] Ensure metrics are updating (refresh dashboard)
- [ ] Set dashboard time range to "Last 15 minutes" for responsiveness
- [ ] Close unnecessary browser tabs for clean screen record

### **During Recording**
- [ ] Speak clearly and at a moderate pace
- [ ] Point out color coding (green = good, red = bad)
- [ ] Highlight the numbers that matter (concrete values)
- [ ] Show enthusiasm about the AI insights!
- [ ] Keep eye on time - practice helps hit 3-minute mark

### **After Stress Test Starts**
- [ ] Let it run while explaining other panels
- [ ] Return to CPU graph around 2:30 mark to show spike
- [ ] Mention the visible impact on emissions

### **Backup Plan**
If live API fails:
- Mention "using fallback typical values"
- Emphasize the "What If" concept still works
- Focus on the AI recommendations and regional comparison

---

## 🌍 Environmental Impact Context

### **Why This Matters**
- Data centers consume ~1% of global electricity
- Cloud computing growing 20-30% annually
- Not all electricity is created equal (coal vs. hydro)
- Regional differences can mean 10x carbon footprint difference
- Most teams have ZERO visibility into carbon impact

### **Real-World Implications**
- **Sweden choice**: ~70% cleaner than Germany
- **Annual savings**: Moving 100 instances could save ~500kg CO2/year
- **Business value**: ESG reporting, cost optimization, brand reputation

---

## 🚀 Future Enhancements (Optional Mention)

- **Auto-migration**: Automatically move workloads to cleaner regions
- **Scheduling**: Run batch jobs during cleanest grid hours
- **Alerts**: Notify when carbon intensity spikes
- **Cost vs. Carbon**: Optimal balance recommendations
- **Multi-cloud**: Support for Azure, GCP
- **Carbon budget tracking**: Set limits and track progress

---

## ✅ Pre-Demo Checklist

- [ ] All EC2 instances healthy and running
- [ ] Grafana dashboard accessible and loading data
- [ ] Time range set to "Last 15 minutes" or "Last 1 hour"
- [ ] AWS Console ready with compute-worker instance
- [ ] stress-ng command copied and ready to paste
- [ ] Screen recording software tested
- [ ] Microphone tested
- [ ] Browser in full-screen mode
- [ ] Script reviewed and practiced
- [ ] Timing rehearsed (aim for 2:45-3:00)

---

## 📊 Key Numbers to Remember

| **Metric** | **Value** | **Context** |
|---|---|---|
| Instances | 3 | web-server, api-server, compute-worker |
| Instance Type | t3.micro | AWS general purpose |
| Region | eu-north-1 | Stockholm, Sweden |
| Sweden CO2 | ~42 gCO2/kWh | Cleanest in demo |
| Germany CO2 | ~420 gCO2/kWh | 10x dirtier than Sweden |
| Carbon Diff | 226% | Increase if moved to Germany |
| Current Emissions | ~3.3 g/h | Total from all instances in Sweden |
| Demo Duration | 3 minutes | Keep it tight! |

---

## 🎯 Success Criteria

Your demo is successful if viewers understand:
1. ✅ **The Problem**: Cloud carbon footprint is invisible to most teams
2. ✅ **The Solution**: Real-time monitoring with AI insights
3. ✅ **The Impact**: Regional choice can mean 2-10x emissions difference
4. ✅ **The Technology**: Grafana + AWS + Bedrock integration
5. ✅ **The Value**: Better decisions for cost, carbon, and compliance

---

**Good luck with your demo! 🌱🚀**
