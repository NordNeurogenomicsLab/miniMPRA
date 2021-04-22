#!/bin/sh

#SBATCH --job-name=bwa_pipeline
#SBATCH --time=00:15:00
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --mem=16G
#SBATCH --partition=production
#SBATCH --output=bwa_pipeline_%j.out   
#SBATCH --error=bwa_pipeline_%j.out   
#SBATCH --mail-type=ALL
#SBATCH --mail-user=kcichewicz@ucdavis.edu


# This is a basic bwa alignment pipeline

# Dependencies
## Processed sample defined as an input to the script
current_sample=$1

## Creates output directories

out_dir="/share/nordlab/users/kcichewicz/miniMPRA/pipeline_test/"
sam_dir="${out_dir}/sam_files"
bam_dir="${out_dir}/sorted_bam"
dedup_bam_dir="${out_dir}/dedup_bam_dir"
bedGraphs="${out_dir}/bedGraphs"


mkdir -p ${out_dir}
mkdir -p ${sam_dir}
mkdir -p ${bam_dir}
mkdir -p ${dedup_bam_dir}
mkdir -p ${bedGraphs}

## Input files
reads=/share/nordlab/users/kcichewicz/miniMPRA/trimmed_fastq/
genome=/share/nordlab/genomes/Mus_musculus/Ensembl/GRCm38/Sequence/WholeGenomeFasta/Mus_musculus.GRCm38.dna.primary_assembly.fa


# bwa mem call
/share/nordlab/users/kcichewicz/bin/bwa-0.7.17/bwa mem \
-t 8 \
-M \
$genome \
$reads/"$current_sample"_1.fastq \
$reads/"$current_sample"_2.fastq \
> $sam_dir/$current_sample.sam


# Converting to bam
java -Xmx8g -jar /share/nordlab/users/kcichewicz/bin/picard.jar SortSam \
INPUT= $sam_dir/$current_sample.sam \
OUTPUT= $bam_dir/$current_sample.bam \
SORT_ORDER=coordinate

# Indexing
java -Xmx8g -jar /share/nordlab/users/kcichewicz/bin/picard.jar BuildBamIndex \
INPUT= $bam_dir/$current_sample.bam


# Deduplication
java -d64 -Xmx8g -jar /share/nordlab/users/kcichewicz/bin/picard.jar MarkDuplicates REMOVE_DUPLICATES=true \
INPUT= $bam_dir/$current_sample.bam \
OUTPUT= $dedup_bam_dir/$current_sample.bam \
METRICS_FILE=$dedup_bam_dir/$current_sample.txt

# Indexing 2
java -Xmx8g -jar /share/nordlab/users/kcichewicz/bin/picard.jar BuildBamIndex \
INPUT= $dedup_bam_dir/$current_sample.bam



# BedGraph generation

module load deeptools/3.3.1                                                                                          

bamCoverage -b $dedup_bam_dir/$current_sample.bam -o $bedGraphs/$current_sample.bedgraph \
--numberOfProcessors 8 \
--ignoreDuplicates \
--outFileFormat bedgraph \
--normalizeUsing CPM