#!/bin/bash
# created by Shen Ke and Jian Fanchong

export PATH=/share/home/shenk/local/anaconda3/envs/bismark/bin:$PATH

set -e

HM=$1
sp=$2
ncpu=$3
sample=$4
sample_splitPart=$5

genomes=/data/hg38.genome
chromsizes=/data/hg38.chrom.sizes
scripts=/share/home/shenk/analysis/pipeline-example/scripts

# Step-1 data quality control and barcode removal
function clean {
    IN=$HM/00-rawdata
    OUT=$HM/01-outputs
    
    R1=$IN/$sample_splitPart/$(ls $IN/${sample_splitPart} | grep _R1 | grep q.gz$)
    R2=$IN/$sample_splitPart/$(ls $IN/${sample_splitPart} | grep _R2 | grep q.gz$)
    outQC=$OUT/fastqc/$sample_splitPart
    outTrim=$OUT/trim/$sample_splitPart
    mkdir -p $outQC
    mkdir -p $outTrim
    fastqc $IN/$sample_splitPart/*.gz -t $ncpu -o $outQC
    trim_galore -q 20 --stringency 2 -e 0.1 --paired $R1 $R2 --gzip -o $outTrim -j $ncpu

    # remove the code below for in vivo FOODIE

}

# Step-2 alignment of processed sequencing reads to the genome using bismark
function align {
    OUT=$HM/01-outputs
    
    genome=${genomes[$sp]}
    outTrim=$OUT/trim/$sample_splitPart
    outAlign=$OUT/align/$sample_splitPart
    mkdir -p $outAlign
    
    R1=$outTrim/$(ls $outTrim | grep val_1.fq.gz)
    R2=$outTrim/$(ls $outTrim | grep val_2.fq.gz)
   
    bismark --genome $genome --non_directional -p $ncpu -1 $R1 -2 $R2 -o $outAlign --temp_dir=$outAlign -X 500
    aln=$outAlign/${sample_splitPart}.bam
    mv $outAlign/*bismark_bt2_pe.bam $aln
    aln_sort=$outAlign/${sample_splitPart}.sorted.bam

    samtools sort -@ $ncpu $aln > $aln_sort
    samtools index $aln_sort
}

# Step-3 cytosine conversion analysis from bismark output
function call_conversion {
    IN=$HM/01-outputs
    OUT=$HM/02-merge-outputs
    pwd=$PWD

    mkdir -p $OUT/split_align/$sample
    set +e
    ln -s $pwd/../01-outputs/align/$sample_splitPart/${sample_splitPart}.sorted.bam* $OUT/split_align/$sample/
    set -e

    outSplitAlign=$OUT/split_align/$sample
    outSplitBed=$OUT/split_bedfiles/$sample
    mkdir -p $outSplitBed
    
    #dedupaln=$outSplitAlign/${sample}.deduplicated.bam
    undedupaln=$outSplitAlign/${sample_splitPart}.sorted.bam
    res=$outSplitBed/${sample_splitPart}.reads.undedup.bed
    mkdir -p $OUT/info/$sample
    info=$OUT/info/$sample/${sample_splitPart}.call.o.txt
    python $scripts/methyl_extract_XCX-test.py -c 1 -fo $res -a $undedupaln -t 15 -q 5 --ATAC 'Y' > $info
}

# Step-4 generation of files for downstream analysis and visualization
function call_track {
    OUT=$HM/02-merge-outputs
    
    outSplitBed=$OUT/split_bedfiles/$sample
    res=$outSplitBed/${sample_splitPart}.reads.undedup.bed
    track=$outSplitBed/${sample_splitPart}.reads.undedup.summary.bed
    trackScore=$outSplitBed/${sample_splitPart}.reads.undedup.summary_score.bed
    TMPDIR=$outSplitBed
    
    python $scripts/summary_bed.py $res abcdefghijklmnop  | sort -k1,1 -k2,2n > $track
    python $scripts/summary_bed_score_trim-test_wo_st_ed.py $res abcdefghijklmnop ABCDEFGHIJKLMNOP | awk '{if($3-$2>2)print$0}' | sort -k1,1 -k2,2n > $trackScore
}


#clean

#align

#call_conversion

call_track
