#!/usr/bin/env python3
import os
import time
import math
import logging
import requests
import json
from datetime import datetime, timedelta
from threading import Thread
from flask import Flask, Response, jsonify, request
from prometheus_client import Gauge, generate_latest, REGISTRY
import boto3
from botocore.exceptions import ClientError
import psutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Environment/config
ROLE = os.environ.get('INSTANCE_ROLE', 'unknown')
AI_REFRESH_SECS = int(os.environ.get('AI_AUTO_REFRESH_SECONDS', '300'))
BALANCE_WEIGHT = float(os.environ.get('BALANCE_WEIGHT', '0.5'))

# Prometheus metrics
grid_carbon_intensity = Gauge(
    'grid_carbon_intensity_g_kwh',
    'Carbon intensity of electricity grid in gCO2/kWh',
    ['country']
)

co2_emissions = Gauge(
    'instance_co2_emissions_g_hour',
    'Estimated CO2 emissions in grams per hour',
    ['role', 'country']
)

best_region_metric = Gauge(
    'carbon_best_region',
    'Best region by lowest CO2/h (1=best, 0=not best)',
    ['region']
)

balanced_region_metric = Gauge(
    'carbon_balanced_region',
    'Balanced region by cost+carbon (1=best, 0=not best)',
    ['region']
)

region_score_metric = Gauge(
    'region_score',
    'Region score by metric type',
    ['region', 'metric']
)

# Constants - Realistic t3.micro power model
IDLE_POWER_WATTS = 3.5   # Idle + infrastructure overhead
MAX_POWER_WATTS = 18.0   # CPU + RAM + network at max load

COUNTRIES = {
    'SE': 'Sweden',
    'DE': 'Germany',
    'GB': 'United Kingdom',
    'FR': 'France'
}

PRICES_USD_H = {
    'DE': 0.0120,
    'FR': 0.0118,
    'GB': 0.0118,
    'SE': 0.0784
}

NOWTRICITY_API = "https://api.nowtricity.com/v1"

logger.info(f"Carbon Service starting for role: {ROLE}")
logger.info(f"AI auto-refresh: {AI_REFRESH_SECS}s, Balance weight: {BALANCE_WEIGHT}")

carbon_cache = {}
cache_timestamp = 0
CACHE_TTL = 300


def fetch_carbon_intensity():
    global carbon_cache, cache_timestamp
    
    current_time = time.time()
    if current_time - cache_timestamp < CACHE_TTL and carbon_cache:
        logger.debug("Using cached carbon intensity data")
        return carbon_cache
    
    logger.info("Fetching fresh carbon intensity data from Nowtricity API")
    results = {}
    
    for country_code in COUNTRIES.keys():
        try:
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=24)
            
            url = f"{NOWTRICITY_API}/carbon-intensity/{country_code}"
            params = {
                'start': start_time.isoformat() + 'Z',
                'end': end_time.isoformat() + 'Z'
            }
            
            response = requests.get(url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if data and len(data) > 0:
                    values = [item.get('intensity', 0) for item in data if 'intensity' in item]
                    avg_intensity = sum(values) / len(values) if values else 0
                    results[country_code] = avg_intensity
                    logger.info(f"{country_code}: {avg_intensity:.2f} gCO2/kWh")
                else:
                    fallback = {'SE': 25, 'DE': 420, 'GB': 250, 'FR': 60}
                    results[country_code] = fallback.get(country_code, 100)
                    logger.warning(f"No data for {country_code}, using fallback: {results[country_code]}")
            else:
                fallback = {'SE': 25, 'DE': 420, 'GB': 250, 'FR': 60}
                results[country_code] = fallback.get(country_code, 100)
                logger.warning(f"API error for {country_code}, using fallback: {results[country_code]}")
                
        except Exception as e:
            logger.error(f"Error fetching data for {country_code}: {e}")
            fallback = {'SE': 25, 'DE': 420, 'GB': 250, 'FR': 60}
            results[country_code] = fallback.get(country_code, 100)
    
    carbon_cache = results
    cache_timestamp = current_time
    return results


def get_cpu_usage():
    try:
        return float(psutil.cpu_percent(interval=0.5))
    except Exception as e:
        logger.error(f"psutil cpu_percent error: {e}")
        return 5.0


def calculate_co2_emissions(carbon_intensity_g_kwh):
    cpu_usage_percent = get_cpu_usage()
    power_watts = IDLE_POWER_WATTS + (MAX_POWER_WATTS - IDLE_POWER_WATTS) * (cpu_usage_percent / 100.0)
    power_kw = power_watts / 1000.0
    co2_g_hour = power_kw * carbon_intensity_g_kwh
    logger.debug(f"CPU: {cpu_usage_percent:.1f}%, Power: {power_watts:.2f}W, CO2: {co2_g_hour:.2f}g/h")
    return co2_g_hour


def best_region_by_carbon(intensities):
    emissions = {cc: calculate_co2_emissions(intensities[cc]) for cc in intensities}
    best_cc = min(emissions, key=emissions.get)
    return best_cc, emissions


def balanced_region(intensities, prices, w_carbon):
    emissions = {cc: calculate_co2_emissions(intensities[cc]) for cc in intensities}
    c_vals = list(emissions.values())
    p_vals = list(prices.values())
    c_min, c_max = min(c_vals), max(c_vals)
    p_min, p_max = min(p_vals), max(p_vals)
    
    def norm(v, vmin, vmax):
        return 0 if vmax == vmin else (v - vmin) / (vmax - vmin)
    
    scores = {}
    for cc in intensities.keys():
        c_norm = norm(emissions[cc], c_min, c_max)
        p_norm = norm(prices[cc], p_min, p_max)
        scores[cc] = w_carbon * c_norm + (1.0 - w_carbon) * p_norm
    
    best_bal = min(scores, key=scores.get)
    return best_bal, emissions, scores


def update_region_metrics(intensities):
    for cc in intensities.keys():
        best_region_metric.labels(region=cc).set(0)
        balanced_region_metric.labels(region=cc).set(0)
    
    best_cc, emissions = best_region_by_carbon(intensities)
    best_region_metric.labels(region=best_cc).set(1)
    
    bal_cc, emissions2, scores = balanced_region(intensities, PRICES_USD_H, BALANCE_WEIGHT)
    balanced_region_metric.labels(region=bal_cc).set(1)
    
    for cc in intensities.keys():
        region_score_metric.labels(region=cc, metric='carbon').set(emissions[cc])
        region_score_metric.labels(region=cc, metric='price').set(PRICES_USD_H[cc])
        region_score_metric.labels(region=cc, metric='balanced').set(scores[cc])
    
    return best_cc, bal_cc, emissions, scores


def build_ai_prompt(role, intensities, best_cc, bal_cc, emissions, scores):
    lines = []
    lines.append(f"Role: {role}")
    lines.append("Per-region emissions and pricing:")
    for cc in intensities.keys():
        lines.append(f"- {cc}: {emissions[cc]:.2f} g/h, ${PRICES_USD_H[cc]:.4f}/h, score={scores[cc]:.3f}")
    
    return f"""Act as a cloud sustainability SRE.

Goal:
- Recommend the best region to MINIMIZE CO2.
- Recommend a BALANCED region between carbon and price (weight carbon={BALANCE_WEIGHT:.2f}).

Context:
{chr(10).join(lines)}
Best (CO2-only): {best_cc}
Balanced (cost+carbon): {bal_cc}

Explain briefly (<=120 words) and give 2 concrete actions."""


last_ai = {
    "timestamp": None,
    "role": ROLE,
    "best_region": None,
    "balanced_region": None,
    "insight": None,
}


def ai_refresh_loop():
    while True:
        try:
            intensities = fetch_carbon_intensity()
            best_cc, bal_cc, emissions, scores = update_region_metrics(intensities)
            prompt = build_ai_prompt(ROLE, intensities, best_cc, bal_cc, emissions, scores)
            
            bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
            model_id = "anthropic.claude-3-haiku-20240307-v1:0"
            
            body = json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 300,
                "temperature": 0.4,
                "messages": [{"role": "user", "content": prompt}]
            })
            
            logger.info("Refreshing AI recommendation...")
            resp = bedrock.invoke_model(modelId=model_id, body=body)
            text = json.loads(resp['body'].read())['content'][0]['text']
            
            last_ai.update({
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "best_region": best_cc,
                "balanced_region": bal_cc,
                "insight": text
            })
            logger.info(f"AI refresh complete: best={best_cc}, balanced={bal_cc}")
            
        except Exception as e:
            logger.error(f"AI refresh error: {e}")
        
        time.sleep(max(60, AI_REFRESH_SECS))


@app.route('/metrics')
def metrics():
    try:
        intensities = fetch_carbon_intensity()
        
        for country_code, intensity in intensities.items():
            grid_carbon_intensity.labels(country=country_code).set(intensity)
        
        for country_code, intensity in intensities.items():
            emissions = calculate_co2_emissions(intensity)
            co2_emissions.labels(role=ROLE, country=country_code).set(emissions)
        
        update_region_metrics(intensities)
        
        return Response(generate_latest(REGISTRY), mimetype='text/plain')
    except Exception as e:
        logger.error(f"Error generating metrics: {e}")
        return Response(f"Error: {str(e)}", status=500)


@app.route('/recommendation')
def recommendation():
    try:
        w = request.args.get('w', None)
        w_carbon = float(w) if w is not None else BALANCE_WEIGHT
        
        intensities = fetch_carbon_intensity()
        best_cc, emissions = best_region_by_carbon(intensities)
        bal_cc, emissions2, scores = balanced_region(intensities, PRICES_USD_H, w_carbon)
        
        return jsonify({
            "role": ROLE,
            "best_region": best_cc,
            "balanced_region": bal_cc,
            "weight_carbon": w_carbon,
            "emissions_g_h": {k: round(v, 2) for k, v in emissions.items()},
            "prices_usd_h": PRICES_USD_H,
            "scores": {k: round(v, 3) for k, v in scores.items()},
            "timestamp": datetime.utcnow().isoformat() + "Z"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/ai-insight')
def ai_insight():
    try:
        refresh = request.args.get('refresh', 'false').lower() == 'true'
        
        if refresh or not last_ai.get("insight"):
            intensities = fetch_carbon_intensity()
            best_cc, bal_cc, emissions, scores = update_region_metrics(intensities)
            prompt = build_ai_prompt(ROLE, intensities, best_cc, bal_cc, emissions, scores)
            
            bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
            resp = bedrock.invoke_model(
                modelId="anthropic.claude-3-haiku-20240307-v1:0",
                body=json.dumps({
                    "anthropic_version": "bedrock-2023-05-31",
                    "max_tokens": 300,
                    "temperature": 0.4,
                    "messages": [{"role": "user", "content": prompt}]
                })
            )
            text = json.loads(resp['body'].read())['content'][0]['text']
            
            last_ai.update({
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "best_region": best_cc,
                "balanced_region": bal_cc,
                "insight": text
            })
        
        intensities = fetch_carbon_intensity()
        current_co2 = calculate_co2_emissions(intensities.get('SE', 25))
        
        return jsonify(last_ai | {"current_co2_g_hour": round(current_co2, 2)})
        
    except ClientError as e:
        code = e.response['Error']['Code']
        msg = e.response['Error']['Message']
        return jsonify({"error": f"Bedrock: {code}", "message": msg}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'role': ROLE})


if __name__ == '__main__':
    Thread(target=ai_refresh_loop, daemon=True).start()
    app.run(host='0.0.0.0', port=8080)
