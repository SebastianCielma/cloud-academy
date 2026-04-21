# Cloud Cost Anomaly Detector

## 1. How to run the script
Ensure you have Python 3 installed. The script uses only standard libraries, so no external dependencies are required.

To run the script against the provided dataset, execute the following command in your terminal:
`python main.py -input daily_costs_sample_1.csv`

The script will output a formatted report to standard output (stdout) and automatically generate a structured `anomalies_report.json` file in the same directory.

## 2. Anomaly Detection Logic
The core detection logic relies on a **rolling mean (moving average)** approach. 
1. The script groups the data by unique `(service, environment)` pairs.
2. For each day, it calculates the baseline cost by averaging the costs from a sliding window of the previous 14 days.
3. It compares the current day's cost against this baseline to calculate the percentage increase.
4. If the percentage increase exceeds predefined thresholds, it is flagged as an anomaly.

## 3. Assumptions Made
* **Data Chronology**: The baseline for day *N* is calculated using only days *N-1, N-2, ...* ensuring no future data leaks into the baseline calculation.
* **Minimum History Requirements**: The algorithm requires at least 3 days of historical data to establish a valid baseline.
* **Noise Reduction**: An absolute minimum cost threshold is enforced. Daily costs below $5.00 are ignored to prevent micro-fluctuations (e.g., an increase from $0.10 to $0.50, which is technically a 400% increase but irrelevant in absolute value) from triggering false alarms.

## 4. Thresholds Used
Detected anomalies are classified based on the following percentage increases over the baseline:
* **INFO**: >= 20%
* **WARNING**: >= 50%
* **CRITICAL**: >= 100%

---
