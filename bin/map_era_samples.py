import pandas as pd
import os

# Paths
csv_path = 'examples/Sample_sheet_twist.csv'
tsv_path = 'examples/filereport_read_run_ERP146869.tsv'
output_path = 'examples/Sample_sheet_replicate_article.csv'
fastq_dir = 'tests/test_data'

# Load files
print(f"Reading {csv_path}...")
df_samples = pd.read_csv(csv_path)

print(f"Reading {tsv_path}...")
df_meta = pd.read_csv(tsv_path, sep='\t')

# Create a mapping from clean ID (e.g. '12A') to run_accession (e.g. 'ERR11435640')
# In the TSV, 'sample_alias' has values like '12A_S9'
def get_clean_id(alias):
    if pd.isna(alias): return None
    return alias.split('_')[0]

df_meta['clean_id'] = df_meta['sample_alias'].apply(get_clean_id)
mapping = df_meta.set_index('clean_id')['run_accession'].to_dict()

# Reconstruct the sample sheet
results = []
for _, row in df_samples.iterrows():
    sid = str(row['sample_id'])
    group = row['group']
    
    if sid in mapping:
        err_id = mapping[sid]
        read1 = f"{fastq_dir}/{err_id}_1.fastq.gz"
        read2 = f"{fastq_dir}/{err_id}_2.fastq.gz"
        
        results.append({
            'sample_id': sid,
            'group': group,
            'read1': read1,
            'read2': read2
        })
    else:
        print(f"Warning: No mapping found for sample {sid}")

# Save result
if results:
    df_result = pd.DataFrame(results)
    df_result.to_csv(output_path, index=False)
    print(f"Successfully created {output_path} with {len(df_result)} samples.")
    print(df_result.head())
else:
    print("Error: No samples matched.")
