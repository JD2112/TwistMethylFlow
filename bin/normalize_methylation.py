#!/usr/bin/env python3
import sys
import pandas as pd
import argparse

def normalize_bedgraph(input_file, output_file, method):
    # Depending on method, parse it and output a standard 6-column bedGraph format
    # chr, start, end, meth_percentage, meth_reads, unmeth_reads
    
    # Check if empty
    try:
        if method.lower() == 'bismark':
            # Bismark coverage file format:
            # <chromosome> <start position> <end position> <methylation percentage> <count methylated> <count unmethylated>
            df = pd.read_csv(input_file, sep='\t', header=None, names=['chr', 'start', 'end', 'meth_perc', 'meth_reads', 'unmeth_reads'])
        elif method.lower() == 'methyldackel':
            # MethylDackel default bedGraph format:
            # <chromosome> <start> <end> <methylation percentage> <count methylated> <count unmethylated>
            df = pd.read_csv(input_file, sep='\t', header=None, names=['chr', 'start', 'end', 'meth_perc', 'meth_reads', 'unmeth_reads'])
        else:
            df = pd.read_csv(input_file, sep='\t', header=None)
            
        # Ensure correct data types
        df['start'] = df['start'].astype(int)
        df['end'] = df['end'].astype(int)
        
        # Sort by chr and start
        df = df.sort_values(by=['chr', 'start'])
        
        df.to_csv(output_file, sep='\t', index=False, header=False)
    except Exception as e:
        print(f"Error normalizing {input_file}: {e}", file=sys.stderr)
        # Touch output file to prevent workflow crash if input is empty
        with open(output_file, 'w') as f:
            pass

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--method', required=True)
    args = parser.parse_args()
    normalize_bedgraph(args.input, args.output, args.method)
