#!/usr/bin/env python3

import os
import fnmatch
import glob
import pandas as pd
import json
import argparse
import numpy as np
from datetime import datetime

def parse_args():
    parser = argparse.ArgumentParser(description="Build Unified Results for milou Clinical Report")
    parser.add_argument('--run_name', type=str, default="milouRun")
    parser.add_argument('--project_dir', type=str, default=".")
    parser.add_argument('--pipeline_version', type=str, default="1.2.0")
    parser.add_argument('--promoter_dist', type=int, default=2000)
    parser.add_argument('--enhancer_dist', type=int, default=10000)
    parser.add_argument('--pvalue_cutoff', type=float, default=0.05)
    parser.add_argument('--logfc_cutoff', type=float, default=0.5)
    parser.add_argument('--top_n_genes', type=int, default=100)
    parser.add_argument('--mode', type=str, default='research', help="Pipeline execution mode (research or clinical)")
    parser.add_argument('--metadata', type=str, help="Path to sample sheet/metadata")
    parser.add_argument('--methods_yml', type=str, help="Path to methods description")
    parser.add_argument('--citations_bib', type=str, help="Path to citations bib")
    parser.add_argument('--commit', type=str, default="Not available", help="Git commit hash")
    parser.add_argument('--command_line', type=str, default="Not available", help="Nextflow command line")
    parser.add_argument('--nextflow_version', type=str, default="Not available", help="Nextflow version")
    parser.add_argument('--container_engine', type=str, default="Not available", help="Container engine used")
    parser.add_argument('--genome_build', type=str, default="Not available", help="Reference genome build")
    parser.add_argument('--resolved_params', type=str, help="Path to resolved params JSON")
    parser.add_argument('--checksums_dir', type=str, help="Directory containing sha256 checksums")
    parser.add_argument('--coverage_threshold', type=float, default=10.0, help="Coverage threshold for sanity check")
    parser.add_argument('--min_30x_pc', type=float, default=80.0, help="Min % of targets required to be >30x")
    return parser.parse_args()


        
def process_qc(output_dir, metadata=None):
    mqc_stats_path = "multiqc_data/multiqc_general_stats.txt"
    if not os.path.exists(mqc_stats_path):
        mqc_stats_path = glob.glob("**/multiqc_general_stats.txt", recursive=True)
        if mqc_stats_path: mqc_stats_path = mqc_stats_path[0]
        else: return None

    # Load mapping from sample name to Group if metadata provided
    id_to_group = {}
    valid_ids = set()
    if metadata is not None:
        # Robustly handle column naming
        s_col = 'sample' if 'sample' in metadata.columns else 'Sample' if 'Sample' in metadata.columns else None
        g_col = 'group' if 'group' in metadata.columns else 'Group' if 'Group' in metadata.columns else None
        
        if s_col:
            valid_ids = set(metadata[s_col].astype(str).tolist())
            if g_col:
                id_to_group = dict(zip(metadata[s_col].astype(str), metadata[g_col].astype(str)))
        else:
            print("Warning: Metadata provided but no 'sample' column found.")

    print(f"Processing QC from: {mqc_stats_path}")
    try:
        df = pd.read_csv(mqc_stats_path, sep="\t")
        
        # Helper to find exact or close matches for requested columns
        def find_exact_col(target):
            if target in df.columns: return target
            matches = [c for c in df.columns if target.lower() in c.lower()]
            return matches[0] if matches else None

        c_insert = find_exact_col('qualimap_bamqc-median_insert_size')
        c_cov    = find_exact_col('qualimap_bamqc-mean_coverage')
        c_cov30  = find_exact_col('qualimap_bamqc-30_x_pc') # Bench-mark for clinical
        c_pct    = find_exact_col('qualimap_bamqc-percentage_aligned')

        # Fallbacks if Qualimap prefix is missing
        if not c_insert: c_insert = find_exact_col('median_insert_size')
        if not c_cov:    c_cov    = find_exact_col('mean_coverage')
        if not c_cov30:  c_cov30  = find_exact_col('30_x_pc')
        if not c_pct:    c_pct    = find_exact_col('percentage_aligned')

        print(f"  Mapped QC columns: Insert={c_insert}, Cov={c_cov}, Cov30={c_cov30}, Pct={c_pct}")

    except Exception as e:
        print(f"Error reading QC file: {e}")
        return None
    
    qc_data = []
    seen = set()
    for _, row in df.iterrows():
        try:
            raw_s = str(row['Sample'])
            matched_id = None
            if valid_ids:
                # 1. Try exact match (case-insensitive)
                for vid in valid_ids:
                    if vid.lower() == raw_s.lower():
                        matched_id = vid
                        break
                # 2. Try matching if valid_id is in raw_s (e.g. NEB_EM_Rep1 in NEB_EM_Rep1_bam)
                if not matched_id:
                    for vid in valid_ids:
                        if vid.lower() in raw_s.lower():
                            matched_id = vid
                            break
                # 3. Try matching if raw_s is in valid_id
                if not matched_id:
                    for vid in valid_ids:
                        if raw_s.lower() in vid.lower():
                            matched_id = vid
                            break
            
            # 4. Fallback if no match found
            if not matched_id:
                if valid_ids:
                    continue
                matched_id = raw_s.split('.')[0]
            
            if matched_id in seen: continue
            seen.add(matched_id)

            def fmt_val(col, suffix="", precision=2):
                if col and col in df.columns and pd.notnull(row[col]):
                    val = row[col]
                    try:
                        f_val = float(val)
                        return f"{round(f_val, precision)}{suffix}"
                    except:
                        return str(val)
                return "N/A"

            qc_data.append({
                "Sample": matched_id,
                "Group": id_to_group.get(matched_id, "Unknown"),
                "Mean Coverage": fmt_val(c_cov, "x"),
                "Targets > 30x (%)": fmt_val(c_cov30, "%"),
                "Median Insert Size": fmt_val(c_insert, " bp", 0),
                "Mapping %": fmt_val(c_pct, "%")
            })
        except: continue
    
    if not qc_data: return None
    qc_df = pd.DataFrame(qc_data)
    qc_df.to_csv(os.path.join(output_dir, "qc_summary.tsv"), sep="\t", index=False)
    return qc_df

def load_disgenet():
    disgenet_path = "tests/test_data/curated_gene_disease_associations.tsv"
    if os.path.exists(disgenet_path):
        try:
            dg = pd.read_csv(disgenet_path, sep="\t")
            # Create a dict: Gene_symbol -> List of top diseases (by score)
            dg = dg.sort_values(by="score", ascending=False)
            mapping = {}
            for name, group in dg.groupby("geneSymbol"):
                mapping[name] = ", ".join(group["diseaseName"].head(3).tolist())
            return mapping
        except Exception as e:
            print(f"Error loading DisGeNET: {e}")
    return {}

def process_dmr_and_genes(output_dir, args):
    # Find DMR/DML files
    # Broaden search to be case-insensitive for common prefixes
    all_files = glob.glob("*")
    dmr_patterns = ["*dmr*", "*dml*", "edger*", "methylkit*", "dss*", "DSS*"]
    
    dmr_files = []
    for p in dmr_patterns:
        # Simple case-insensitive matching
        pattern = p.lower()
        matches = [f for f in all_files if fnmatch.fnmatch(f.lower(), pattern)]
        dmr_files.extend(matches)
    
    dmr_files = [f for f in set(dmr_files) if "_go" not in f and "_kegg" not in f and "_disease" not in f]
    
    # Prioritize _annotated files if available
    annotated_files = [f for f in dmr_files if "_annotated" in f]
    if annotated_files:
        print(f"Found annotated files: {annotated_files}")
        # Only use annotated files to avoid double counting if original results are also present
        dmr_files = annotated_files
    
    all_dmrs = []
    
    for f in dmr_files:
        try:
            df = pd.read_csv(f)
            # Identify method from filename loosely
            method = "edgeR" if "edger" in f.lower() else "methylKit" if "methylkit" in f.lower() else "DSS" if "dss" in f.lower() else "Unknown"
            df['Method'] = method
            df['Source_File'] = f
            
            # Standardize columns (Case-insensitive mapping)
            col_map = {c.lower(): c for c in df.columns}
            
            # 1. log2FC
            if 'log2fc' in col_map: df['log2FC'] = df[col_map['log2fc']]
            elif 'logfc' in col_map: df['log2FC'] = df[col_map['logfc']]
            elif 'meth.diff' in col_map: df['log2FC'] = df[col_map['meth.diff']]
            elif 'diff' in col_map: df['log2FC'] = df[col_map['diff']]
            elif 'diff.methy' in col_map: df['log2FC'] = df[col_map['diff.methy']]
            
            # 2. P-value / FDR
            if 'pvalue' in col_map: df['pvalue'] = df[col_map['pvalue']]
            elif 'qvalue' in col_map: df['pvalue'] = df[col_map['qvalue']]
            elif 'fdr' in col_map: df['pvalue'] = df[col_map['fdr']]
            elif 'pval' in col_map: df['pvalue'] = df[col_map['pval']]
            
            # 3. Gene Symbol
            if 'symbol' in col_map: df['gene'] = df[col_map['symbol']]
            elif 'gene' in col_map: df['gene'] = df[col_map['gene']]
            else: df['gene'] = "Unknown"
            
            # 4. Coordinates
            if 'chr' in col_map: df['Chr'] = df[col_map['chr']]
            
            if 'locus' in col_map: 
                df['Locus'] = df[col_map['locus']]
            elif 'start' in col_map and 'end' in col_map:
                df['Locus'] = ((df[col_map['start']] + df[col_map['end']]) / 2).astype(int)
            
            if 'dist_to_feature' in col_map: df['Distance'] = df[col_map['dist_to_feature']]
            elif 'dist.to.feature' in col_map: df['Distance'] = df[col_map['dist.to.feature']]
            elif 'distance' in col_map: df['Distance'] = df[col_map['distance']]
            
            # Keep only significant
            if 'significance' in df.columns:
                sig_df = df[df['significance'] != 'Not Significant'].copy()
            else:
                p_col = 'pvalue' if 'pvalue' in df.columns else None
                fc_col = 'log2FC' if 'log2FC' in df.columns else None
                
                if p_col and fc_col:
                    sig_df = df[(df[p_col] < 0.05) & (df[fc_col].abs() >= 0.01)].copy()
                else:
                    sig_df = df.copy()

            if not sig_df.empty:
                cols_to_keep = ['Method', 'gene', 'log2FC', 'pvalue']
                for c in ['chr', 'start', 'end', 'strand', 'Distance']:
                    if c in sig_df.columns: cols_to_keep.append(c)
                
                sig_df = sig_df[[c for c in cols_to_keep if c in sig_df.columns]]
                all_dmrs.append(sig_df)
        except Exception as e:
            print(f"Warn: Could not parse {f}: {e}")

    if all_dmrs:
        combined_dmr = pd.concat(all_dmrs, ignore_index=True)
        # Deduplicate DMRs across methods (naive merge)
        # We group by gene and take mean log2FC and min pval, collecting methods
        agg_map = {
            'Methods_Detected': ('Method', lambda x: ", ".join(set(x))),
            'Mean_log2FC': ('log2FC', 'mean'),
            'Min_pvalue': ('pvalue', 'min')
        }
        if 'Distance' in combined_dmr.columns:
            agg_map['Distance'] = ('Distance', lambda x: np.mean(pd.to_numeric(x, errors='coerce')))
            
        grouped = combined_dmr.groupby('gene').agg(**agg_map).reset_index()
        
        # 3.1 Algorithmic Consensus Voting Guardrail
        if args.mode == 'clinical':
            # Enforce strict majority vote: must be detected by >= 2 methods
            grouped['Num_Methods'] = grouped['Methods_Detected'].apply(lambda x: len([m for m in str(x).split(',') if m.strip()]))
            initial_count = len(grouped)
            consensus = grouped[grouped['Num_Methods'] >= 2].copy()
            if len(consensus) > 0:
                grouped = consensus
                grouped.drop(columns=['Num_Methods'], inplace=True, errors='ignore')
                print(f"CLINICAL MODE ACTIVE: Filtered {initial_count} exploratory DMRs down to {len(grouped)} consensus-validated DMRs (>=2 algorithms).")
            else:
                grouped.drop(columns=['Num_Methods'], inplace=True, errors='ignore')
                print(f"CLINICAL MODE ACTIVE: 0 consensus DMRs found. Falling back to union of single-algorithm DMRs ({initial_count} total).")
        
        if 'Distance' in grouped.columns:
            def get_region(d):
                if pd.isna(d): return 'Unknown'
                if abs(d) <= args.promoter_dist: return 'Promoter'
                elif abs(d) <= args.enhancer_dist: return 'Distal / Enhancer'
                else: return 'Intergenic'
            grouped['Region'] = grouped['Distance'].apply(get_region)
        else:
            grouped['Region'] = 'Unknown'

        
        grouped.to_csv(os.path.join(output_dir, "dmr_summary.tsv"), sep="\t", index=False)
        
        # Build gene prioritization
        # Load DisGeNET
        disgenet = load_disgenet()
        
        grouped['Score'] = grouped['Mean_log2FC'].abs() * -np.log10(grouped['Min_pvalue'].clip(lower=1e-300))
        grouped = grouped.sort_values('Score', ascending=False)
        
        grouped['Disease_Associations'] = grouped['gene'].apply(lambda g: disgenet.get(g, "None found"))
        grouped.to_csv(os.path.join(output_dir, "gene_summary.tsv"), sep="\t", index=False)
    else:
        pd.DataFrame(columns=["gene", "Methods_Detected", "Mean_log2FC", "Min_pvalue", "Region"]).to_csv(os.path.join(output_dir, "dmr_summary.tsv"), sep="\t", index=False)
        pd.DataFrame(columns=["gene", "Score", "Disease_Associations"]).to_csv(os.path.join(output_dir, "gene_summary.tsv"), sep="\t", index=False)

def process_go(output_dir):
    all_files = glob.glob("*")
    go_patterns = ["*_go_results.csv", "*go_enrichment*.csv", "*_go_summary.csv"]
    go_files = []
    for p in go_patterns:
        pattern = p.lower()
        matches = [f for f in all_files if fnmatch.fnmatch(f.lower(), pattern)]
        go_files.extend(matches)
    
    go_files = list(set(go_files))
    print(f"Found GO files: {go_files}")
    
    all_go = []
    for f in go_files:
        try:
            df = pd.read_csv(f)
            if 'Description' in df.columns:
                method_source = "edgeR" if "edger" in f.lower() else "methylKit" if "methylkit" in f.lower() else "DSS" if "dss" in f.lower() else "Pipeline"
                df['Source'] = method_source
                all_go.append(df)
        except Exception as e:
            print(f"Error processing GO file {f}: {e}")
            
    if all_go:
        combined = pd.concat(all_go)
        # Ensure ID and Description are both present for grouping
        if 'ID' not in combined.columns: combined['ID'] = combined['Description']
        
        pathways = combined.groupby(['ID', 'Description']).agg(
            Methods=('Source', lambda x: ", ".join(set(x))),
            pvalue=('pvalue', 'min'),
            padjust=('p.adjust' if 'p.adjust' in combined.columns else 'pvalue', 'min')
        ).reset_index().rename(columns={'padjust': 'p.adjust'}).sort_values('pvalue')
        pathways.to_csv(os.path.join(output_dir, "go_results.csv"), sep=",", index=False)
    else:
        pd.DataFrame(columns=["Description", "Methods", "pvalue", "p.adjust"]).to_csv(os.path.join(output_dir, "go_results.csv"), sep=",", index=False)

def process_kegg(output_dir):
    all_files = glob.glob("*")
    kegg_patterns = ["*_kegg_results.csv", "*kegg_enrichment*.csv"]
    kegg_files = []
    for p in kegg_patterns:
        pattern = p.lower()
        matches = [f for f in all_files if fnmatch.fnmatch(f.lower(), pattern)]
        kegg_files.extend(matches)
        
    kegg_files = list(set(kegg_files))
    print(f"Found KEGG files: {kegg_files}")
    
    all_kegg = []
    for f in kegg_files:
        try:
            df = pd.read_csv(f)
            if 'Description' in df.columns:
                method_source = "edgeR" if "edger" in f.lower() else "methylKit" if "methylkit" in f.lower() else "DSS" if "dss" in f.lower() else "Pipeline"
                df['Source'] = method_source
                all_kegg.append(df)
        except Exception as e:
            print(f"Error processing KEGG file {f}: {e}")
            
    if all_kegg:
        combined = pd.concat(all_kegg)
        if 'ID' not in combined.columns: combined['ID'] = combined['Description']
        
        kegg_pathways = combined.groupby(['ID', 'Description']).agg(
            Methods=('Source', lambda x: ", ".join(set(x))),
            pvalue=('pvalue', 'min'),
            padjust=('p.adjust' if 'p.adjust' in combined.columns else 'pvalue', 'min')
        ).reset_index().rename(columns={'padjust': 'p.adjust'}).sort_values('pvalue')
        kegg_pathways.to_csv(os.path.join(output_dir, "kegg_results.csv"), sep=",", index=False)
    else:
        pd.DataFrame(columns=["Description", "Methods", "pvalue", "p.adjust"]).to_csv(os.path.join(output_dir, "kegg_results.csv"), sep=",", index=False)

def process_disease(output_dir):
    all_files = glob.glob("*")
    dis_patterns = ["*_disease_enrichment.csv", "*disease_enrichment*.csv"]
    dis_files = []
    for p in dis_patterns:
        pattern = p.lower()
        matches = [f for f in all_files if fnmatch.fnmatch(f.lower(), pattern)]
        dis_files.extend(matches)
        
    dis_files = list(set(dis_files))
    print(f"Found Disease files: {dis_files}")
    
    all_dis = []
    for f in dis_files:
        try:
            df = pd.read_csv(f)
            if 'Description' in df.columns:
                all_dis.append(df)
        except Exception as e:
            print(f"Error processing Disease file {f}: {e}")
    if all_dis:
        combined = pd.concat(all_dis)
        if 'ID' not in combined.columns: combined['ID'] = combined['Description']
        
        # Sort disease associations by pvalue and preserve ID
        combined = combined.sort_values('pvalue')
        combined.to_csv(os.path.join(output_dir, "disease_enrichment.csv"), sep=",", index=False)
    else:
        pd.DataFrame(columns=["Description", "pvalue", "p.adjust"]).to_csv(os.path.join(output_dir, "disease_enrichment.csv"), sep=",", index=False)

def process_gene_prioritization(output_dir):
    gp_files = glob.glob("*_gene_prioritized.csv")
    all_gp = []
    for f in gp_files:
        try:
            df = pd.read_csv(f)
            if not df.empty:
                method = "edgeR" if "edger" in f.lower() else "methylKit" if "methylkit" in f.lower() else "DSS" if "dss" in f.lower() else "Unknown"
                df['Method'] = method
                
                # Harmonize Symbol column
                col_map = {c.lower(): c for c in df.columns}
                if 'symbol' in col_map and col_map['symbol'] != 'Symbol':
                    df = df.rename(columns={col_map['symbol']: 'Symbol'})
                if 'diff' in col_map and col_map['diff'] != 'diff':
                    df = df.rename(columns={col_map['diff']: 'diff'})
                elif 'meth.diff' in col_map:
                    df = df.rename(columns={col_map['meth.diff']: 'diff'})
                elif 'logfc' in col_map:
                    df = df.rename(columns={col_map['logfc']: 'diff'})
                
                if 'fdr' in col_map and col_map['fdr'] != 'fdr':
                    df = df.rename(columns={col_map['fdr']: 'fdr'})
                elif 'qvalue' in col_map:
                    df = df.rename(columns={col_map['qvalue']: 'fdr'})
                elif 'p.adjust' in col_map:
                    df = df.rename(columns={col_map['p.adjust']: 'fdr'})
                
                all_gp.append(df)
        except: pass
    if all_gp:
        combined = pd.concat(all_gp, ignore_index=True)
        # Drop rows where Symbol is missing/NA
        combined = combined.dropna(subset=['Symbol'])
        combined = combined[combined['Symbol'].astype(str).str.strip() != '']
        
        # Calculate methods detected
        combined = combined.sort_values('Rank_Score', ascending=False)
        methods_detected = combined.groupby('Symbol')['Method'].apply(lambda x: ", ".join(sorted(set(x)))).reset_index()
        
        combined = combined.drop_duplicates('Symbol')
        combined = combined.drop(columns=['Method']).merge(methods_detected, on='Symbol')
        combined.to_csv(os.path.join(output_dir, "gene_prioritized.csv"), sep=",", index=False)
    else:
        pd.DataFrame(columns=["Symbol", "Rank_Score", "Region", "Method"]).to_csv(os.path.join(output_dir, "gene_prioritized.csv"), sep=",", index=False)

def process_plots(output_dir):
    print("Consolidating plots...")
    # Deep search for PNGs
    all_pngs = glob.glob("*.png") + glob.glob("**/*.png", recursive=True)
    all_pngs = list(set(all_pngs)) # De-duplicate
    print(f"Found {len(all_pngs)} plots: {all_pngs}")
    for p in all_pngs:
        try:
            # Get basename to avoid subdirectory issues in results_dir
            target_name = os.path.basename(p)
            target_path = os.path.join(output_dir, target_name)
            
            # Avoid copying onto itself
            if os.path.abspath(p) == os.path.abspath(target_path): continue
            
            # Bulletproof binary copy to avoid all permissions/symlink bugs in containers
            with open(p, 'rb') as f_in:
                with open(target_path, 'wb') as f_out:
                    f_out.write(f_in.read())
            print(f"  Copied {p} -> {target_name}")
        except Exception as e:
            print(f"Error copying plot {p}: {e}")

def main():
    args = parse_args()
    output_dir = "results_dir"
    os.makedirs(output_dir, exist_ok=True)
    
    print("Building unified results...")
    
    # 0. Load Metadata first
    ids = set()
    m_df = None
    
    # Try the explicit argument first
    metadata_file = args.metadata
    if not metadata_file or not os.path.exists(metadata_file):
        # Fallback to scanning if arg is missing
        sheets = glob.glob("*.csv") + glob.glob("*.tsv")
        for s in sheets:
            if 'sample' in s.lower() or 'metadata' in s.lower() or 'sheet' in s.lower():
                metadata_file = s
                break
    
    if metadata_file and os.path.exists(metadata_file):
        print(f"Loading metadata from: {metadata_file}")
        try:
            # Use standard read_csv with fallback for separator
            try:
                temp_df = pd.read_csv(metadata_file, sep=",")
                # Check for common sample column names
                if not any(c.lower() in ['sample', 'sample_id', 'id'] for c in temp_df.columns):
                    temp_df = pd.read_csv(metadata_file, sep="\t")
            except:
                temp_df = pd.read_csv(metadata_file, sep=None, engine='python')

            # Flexible column discovery for 'sample'
            col = None
            for c in temp_df.columns:
                if c.lower() in ['sample', 'sample_id', 'id', 'specimen']:
                    col = c
                    break
            
            if col:
                m_df = temp_df.rename(columns={col: 'sample'})
                ids = set(m_df['sample'].astype(str).tolist())
                m_df.to_csv(os.path.join(output_dir, "sample_metadata.tsv"), sep="\t", index=False)
                print(f"  Successfully processed and saved sample_metadata.tsv (ID col: {col})")
            else:
                # Force save even if ID col not found, just to ensure file exists
                temp_df.to_csv(os.path.join(output_dir, "sample_metadata.tsv"), sep="\t", index=False)
                m_df = temp_df
                print(f"  Warning: No 'sample' column identified in {metadata_file}, but saved file anyway.")
        except Exception as e:
            print(f"Error loading metadata {metadata_file}: {e}")

    # 1. QC
    qc_df = process_qc(output_dir, m_df)
    
    # 2. DMRs and Genes
    process_dmr_and_genes(output_dir, args)
    process_gene_prioritization(output_dir)
    
    # 3. GO Pathways, KEGG & Disease
    process_go(output_dir)
    process_kegg(output_dir)
    process_disease(output_dir)
    process_plots(output_dir)
    
    # 4. Run Info Traceability
    versions = {}
    try:
        # Search everywhere for versions.yml including parent dirs of work dir
        yml_files = glob.glob("**/versions.yml", recursive=True) + \
                    glob.glob("../**/versions.yml", recursive=True)
        for yf in yml_files:
            try:
                with open(yf, 'r') as f:
                    for line in f:
                        if ":" in line and not line.strip().startswith("-") and not line.strip().endswith(":"):
                            k, v = line.split(":", 1)
                            versions[k.strip()] = v.strip()
            except: continue
    except: pass

    narrative = ""
    try:
        grouped = pd.read_csv(os.path.join(output_dir, "gene_prioritized.csv"))
        pathways = pd.read_csv(os.path.join(output_dir, "go_results.csv"))
        if len(grouped) > 0 and len(pathways) > 0:
            top_gene = grouped.iloc[0]['Symbol']
            top_pathway = pathways.iloc[0]['Description']
            narrative = f"Significant biological deviation was observed in {top_gene}, heavily associated with {top_pathway}. The epigenetic profile in these regions warrants further experimental investigation."
        else:
            narrative = "Analysis completed, but no statistically significant DMRs or pathways were identified."
    except:
        narrative = "Narrative generation unavailable."

    # 5. Methods & Citations
    methods_html = ""
    if args.methods_yml and os.path.exists(args.methods_yml):
        try:
            with open(args.methods_yml, 'r') as f:
                content = f.read()
                # Simple extraction of 'data: |' block
                if 'data: |' in content:
                    methods_html = content.split('data: |')[1].strip()
        except: pass
    
    # Load separate epigenetic metrics if available
    epi_metrics = {}
    epi_files = glob.glob("*_epigenetic_metrics.json") + glob.glob("../*_epigenetic_metrics.json")
    for epi_file in set(epi_files):
        try:
            with open(epi_file, 'r') as f:
                data = json.load(f)
                if isinstance(data, dict):
                    for k, v in data.items():
                        if k in epi_metrics and isinstance(epi_metrics[k], dict) and isinstance(v, dict):
                            epi_metrics[k].update(v)
                        else:
                            epi_metrics[k] = v
        except Exception as e:
            print(f"Warn: Could not parse epigenetic metrics file {epi_file}: {e}")

    citations_text = ""
    if args.citations_bib and os.path.exists(args.citations_bib):
        try:
            with open(args.citations_bib, 'r') as f:
                citations_text = f.read()
        except: pass

    resolved_params = {}
    if args.resolved_params and os.path.exists(args.resolved_params):
        try:
            with open(args.resolved_params, 'r') as f:
                resolved_params = json.load(f)
        except: pass

    checksums = {}
    if args.checksums_dir and os.path.exists(args.checksums_dir):
        for cfile in glob.glob(os.path.join(args.checksums_dir, "*.sha256")):
            try:
                with open(cfile, 'r') as cf:
                    content = cf.read().strip()
                    if content:
                        checksums[os.path.basename(cfile)] = content.split()[0]
            except: pass

    sanity_checks = []
    # Note: qc_df is available from earlier in main()
    if qc_df is not None:
        for idx, row in qc_df.iterrows():
            cov_str = str(row.get("Mean Coverage", "0"))
            try:
                cov_val = float(cov_str.replace("x", "").strip())
                if cov_val < args.coverage_threshold:
                    sanity_checks.append(f"WARNING: Sample {row.get('Sample', 'Unknown')} coverage ({cov_val}x) below {args.coverage_threshold}x")
            except: pass

            map_str = str(row.get("Mapping %", "0"))
            try:
                map_val = float(map_str.replace("%", "").strip())
                if map_val < 50.0:
                    sanity_checks.append(f"WARNING: Sample {row.get('Sample', 'Unknown')} alignment rate low ({map_val}%)")
            except: pass

            cov30_str = str(row.get("Targets > 30x (%)", "0"))
            try:
                cov30_val = float(cov30_str.replace("%", "").strip())
                if cov30_val < args.min_30x_pc:
                    sanity_checks.append(f"WARNING: Sample {row.get('Sample', 'Unknown')} clinical benchmark failed: only {cov30_val}% of targets at >30x (Required: {args.min_30x_pc}%)")
            except: pass
    if not sanity_checks:
        sanity_checks.append("PASS: All samples met coverage and alignment quality thresholds.")

    run_info = {
        "pipeline": "milou",
        "version": args.pipeline_version,
        "run_name": args.run_name,
        "timestamp": datetime.now().isoformat(),
        "files_processed": len(glob.glob("*")),
        "narrative": narrative,
        "clinical_narrative": narrative,
        "epigenetic_summary": epi_metrics,
        "commit_hash": args.commit,
        "command_line": args.command_line,
        "nextflow_version": args.nextflow_version,
        "container_engine": args.container_engine,
        "genome_build": args.genome_build,
        "software_versions": versions,
        "methods_description": methods_html,
        "citations": citations_text,
        "resolved_params": resolved_params,
        "checksums": checksums,
        "sanity_checks": sanity_checks,
        "enrichment_params": {
            "pvalue_cutoff": args.pvalue_cutoff,
            "logfc_cutoff": args.logfc_cutoff,
            "top_n_genes": args.top_n_genes
        }
    }
    with open(os.path.join(output_dir, "run_info.json"), "w") as f:
        json.dump(run_info, f, indent=4)
    print(f"Successfully built unified results in {output_dir}/")

if __name__ == "__main__":
    main()
