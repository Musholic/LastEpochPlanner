
#!/bin/bash

INPUT_FILE="src/Data/ModCache.lua"
OUTPUT_FILE="unsupported.lua"

# Check if the input file actually exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

total_lines=$(wc -l < "$INPUT_FILE")

supported_lines=$(grep -cE ',nil}$' "$INPUT_FILE")

grep -vE ',nil}$' "$INPUT_FILE" > "$OUTPUT_FILE"

if [ "$total_lines" -gt 0 ]; then
    percentage=$(awk -v s="$supported_lines" -v t="$total_lines" 'BEGIN {printf "%.2f", (s/t)*100}')
else
    percentage="0.00"
fi

# Print the report
echo "---------------------------------------"
echo "Report:"
echo "---------------------------------------"
echo "Total mods:           $total_lines"
echo "Total supported mods: $supported_lines"
echo "Percentage supported: ${percentage}%"
echo "---------------------------------------"
echo "Unsupported mods saved to: $OUTPUT_FILE"
