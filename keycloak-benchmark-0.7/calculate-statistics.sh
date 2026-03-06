#!/bin/bash
# Extract statistics from 10 trial results and calculate mean ± SD and 95% CI
# Run this AFTER completing run-10-trials-400rps.sh

cd /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability/keycloak-benchmark-0.7/results

echo "=========================================="
echo "Statistical Analysis of 10 Trials"
echo "=========================================="
echo ""

# Find all clientsecret result directories sorted by date (most recent 10)
RESULTS=$(ls -dt clientsecret-* | head -10)

echo "Analyzing these test results:"
echo "$RESULTS"
echo ""

# Extract key metrics from each simulation.log
echo "Extracting metrics from each trial..."
echo ""

MEAN_VALUES=()
MEDIAN_VALUES=()
P95_VALUES=()
P99_VALUES=()
THROUGHPUT_VALUES=()

TRIAL=1
for dir in $RESULTS; do
  if [ -f "$dir/simulation.log" ]; then
    # Parse Gatling simulation.log for statistics
    # Format: RUN timestamp scenario users status START/END
    # We need to parse the final statistics from the log
    
    # For now, extract from index.html stats table (easier to parse)
    if [ -f "$dir/index.html" ]; then
      echo "Trial $TRIAL: $dir"
      
      # Extract mean response time (basic grep - adjust based on actual HTML structure)
      MEAN=$(grep -oP 'Mean.*?(\d+)' "$dir/index.html" | head -1 | grep -oP '\d+' || echo "N/A")
      P95=$(grep -oP '95th percentile.*?(\d+)' "$dir/index.html" | head -1 | grep -oP '\d+' || echo "N/A")
      
      echo "  Mean: ${MEAN}ms, P95: ${P95}ms"
      
      MEAN_VALUES+=($MEAN)
      P95_VALUES+=($P95)
      
      TRIAL=$((TRIAL+1))
    fi
  fi
done

echo ""
echo "=========================================="
echo "MANUAL EXTRACTION REQUIRED"
echo "=========================================="
echo ""
echo "This script provides a template. You need to:"
echo ""
echo "1. Open each trial's index.html in browser"
echo "2. Copy these values into a spreadsheet:"
echo "   - Mean Response Time (ms)"
echo "   - Median (50th percentile)"
echo "   - P95 (95th percentile)"
echo "   - P99 (99th percentile)"  
echo "   - Actual throughput (req/s)"
echo ""
echo "3. In Excel/Google Sheets, calculate:"
echo "   - Mean: =AVERAGE(A1:A10)"
echo "   - Std Dev: =STDEV.S(A1:A10)"
echo "   - 95% CI: =1.96 * StdDev / SQRT(10)"
echo ""
echo "4. Format for paper:"
echo "   Mean ± SD (95% CI: lower-upper)"
echo "   Example: 75±6 ms (95% CI: 69-81)"
echo ""
echo "=========================================="
echo ""
echo "Trial results locations:"
for dir in $RESULTS; do
  echo "  - results/$dir/index.html"
done
echo ""
