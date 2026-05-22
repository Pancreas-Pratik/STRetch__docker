#!/bin/bash

## This script will install the tools required for the STRetch pipeline.
## It will fetched each tool from the web and placed into the tools/ subdirectory.
## Paths to all installed tools can be found in the file tools.groovy at the
## end of execution of this script. These paths can be changed if a different
## version of software is required.
##

installdir=$PWD
refdir=$PWD/reference-data
SKIP_REF=${SKIP_REF:-0}
toolspec=$PWD/pipelines/pipeline_config.groovy
bpipeconfig=$PWD/pipelines/bpipe.config
bpipeconfig_template=$PWD/pipelines/config-examples/bpipe.config_template

mkdir -p tools/bin
cd tools

if [ ! -f $toolspec ] ; then
    echo "The configuration file pipelines/pipeline_config.groovy was not found, creating it."
    else
    echo -n "WARNING: pipelines/pipeline_config.groovy already exists so will be overwritten by this installation. "
    echo "Creating backup pipelines/pipeline_config.groovy.backup in case you wish to retreive the previous version of this file."
    cp $toolspec ${toolspec}.backup
fi

#a list of which programs need to be installed
commands="bpipe python goleft bedtools bwa samtools mosdepth"
jarfiles="bazam picard"

# Tools installed by the Miniconda STR environment.
conda_commands="python goleft bedtools mosdepth"

function is_conda_command {
    case " $conda_commands " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

function resolve_tool {
    local c=$1

    # 1) Prefer STRetch tools/bin symlinks.
    if [ -x "$PWD/bin/$c" ] ; then
        echo "$PWD/bin/$c"
        return 0
    fi

    # 2) Then check the Miniconda STR environment directly.
    if [ -x "$PWD/miniconda/envs/STR/bin/$c" ] ; then
        echo "$PWD/miniconda/envs/STR/bin/$c"
        return 0
    fi

    # 3) Finally check system/container PATH.
    command -v "$c" 2>/dev/null
}

#installation method
function bpipe_install {
    wget -O bpipe-0.9.9.5.tar.gz https://github.com/ssadedin/bpipe/releases/download/0.9.9.5/bpipe-0.9.9.5.tar.gz
    tar -zxvf bpipe-0.9.9.5.tar.gz ; rm bpipe-0.9.9.5.tar.gz
    ln -s $PWD/bpipe-0.9.9.5/bin/* $PWD/bin/
}

# Installs miniconda, Python 3 + required packages, BedTools and goleft
# (and any other dependancies listed in environment.yml)
function python_install {
    echo "Installing Miniconda + STR conda environment"

    if [ ! -x "$PWD/miniconda/bin/conda" ] ; then
        wget -O miniconda.sh https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
        bash miniconda.sh -b -p "$PWD/miniconda"
        rm miniconda.sh
    fi

    "$PWD/miniconda/bin/conda" config --add channels defaults
    "$PWD/miniconda/bin/conda" config --add channels bioconda
    "$PWD/miniconda/bin/conda" config --add channels conda-forge
    "$PWD/miniconda/bin/conda" config --set channel_priority flexible

    if [ ! -x "$PWD/miniconda/envs/STR/bin/python" ] ; then
        "$PWD/miniconda/bin/conda" env create -f ../environment.yml
    fi

    for tool in python goleft bedtools mosdepth ; do
        if [ ! -x "$PWD/miniconda/envs/STR/bin/$tool" ] ; then
            echo "ERROR: $tool was not created in $PWD/miniconda/envs/STR/bin"
            echo "The conda environment failed or environment.yml did not install $tool."
            exit 1
        fi
        ln -sf "$PWD/miniconda/envs/STR/bin/$tool" "$PWD/bin/$tool"
    done
}

function bwa_install {
    wget -O bwakit-0.7.15_x64-linux.tar.bz2 --no-check-certificate https://github.com/lh3/bwa/releases/download/v0.7.15/bwakit-0.7.15_x64-linux.tar.bz2
    tar -jxvf bwakit-0.7.15_x64-linux.tar.bz2
    rm bwakit-0.7.15_x64-linux.tar.bz2
    ln -s $PWD/bwa.kit/* $PWD/bin/
}

function samtools_install {
    wget --no-check-certificate https://github.com/samtools/samtools/releases/download/1.8/samtools-1.8.tar.bz2
    tar -jxvf samtools-1.8.tar.bz2
    rm samtools-1.8.tar.bz2
    make prefix=$PWD install -C samtools-1.8/
}

function bazam_install {
    wget --no-check-certificate https://github.com/ssadedin/bazam/releases/download/1.0.1/bazam.jar
    ln -s $PWD/bazam.jar $PWD/bin/bazam.jar
}

function picard_install {
    wget https://github.com/broadinstitute/picard/releases/download/2.18.9/picard.jar
    ln -s $PWD/picard.jar $PWD/bin/picard.jar
}

function download_hg19 {
    wget --no-check-certificate -O $refdir/reference-data.tar.gz https://home.chpc.utah.edu/~u6026198/hg19.STRling.bundle.tar.gz
    tar -xf $refdir/reference-data.tar.gz -C $refdir
    rm $refdir/reference-data.tar.gz
}

#populate toolspec
echo "// Bpipe pipeline config file" > $toolspec
echo "// Paths are relative to the directory the pipeline is running in, so absolute" >> $toolspec
echo "// paths are recommended." >> $toolspec
echo >> $toolspec
echo "// Adjust parameters" >> $toolspec
echo "PLATFORM='illumina'" >> $toolspec
echo >> $toolspec
echo "// Number of threads to use for BWA" >> $toolspec
echo "threads=8" >> $toolspec
echo >> $toolspec
echo "// For exome pipeline only ***Edit before running the exome pipeline***" >> $toolspec
echo "EXOME_TARGET=\"path/to/exome_target_regions.bed\"" >> $toolspec
echo "// Uncomment the line below to run the STRetch installation test, or specify your own" >> $toolspec
echo "//EXOME_TARGET=\"SCA8_region.bed\"" >> $toolspec
echo >> $toolspec
echo "// For bam pipeline only ***Edit before running if using CRAM input format***" >> $toolspec
echo "CRAM_REF=\"path/to/reference_genome_used_to_create_cram.fasta\"" >> $toolspec
echo >> $toolspec

#set STRetch base directory
echo "// STRetch installation location" >> $toolspec
echo "STRETCH=\"$installdir\"" >> $toolspec
echo >> $toolspec

echo "// Paths to tools used by the pipeline" >> $toolspec

for c in $commands ; do
    c_path=$(resolve_tool "$c")

    if [ -z "$c_path" ] ; then
        echo "$c not found, fetching it"

        if is_conda_command "$c" ; then
            # python_install creates the STR conda env containing:
            # python, goleft, bedtools, mosdepth, etc.
            if [ ! -x "$PWD/miniconda/envs/STR/bin/python" ] ; then
                python_install
            fi
        else
            ${c}_install
        fi

        c_path=$(resolve_tool "$c")
    fi

    echo "$c=\"$c_path\"" >> $toolspec
done

for j in $jarfiles ; do
    if [ ! -f $PWD/bin/$j.jar ] ; then
	echo "$j not found, fetching it"
	${j}_install
    fi
    echo "$j=\"$PWD/bin/${j}.jar\"" >> $toolspec
done

if [ "$SKIP_REF" = "1" ] ; then
    echo "SKIP_REF=1, skipping hg19 reference download"
else
    if [ ! -f $refdir/hg19.PCRfreeWGS_143_STRetch_controls.tsv ] ; then
        mkdir -p $refdir
        echo "Downloading reference data"
        download_hg19
    fi
fi

echo >> $toolspec
echo "// Path to reference data" >> $toolspec
echo "refdir=\"$refdir\"" >> $toolspec

echo >> $toolspec
echo "// Decoy reference assumed to have matching .genome file in the same directory" >> $toolspec
echo "REF=\"$refdir/hg19.STRdecoys.sorted.fasta\"" >> $toolspec
echo "STR_BED=\"$refdir/hg19.simpleRepeat_period1-6_dedup.sorted.bed\"" >> $toolspec
echo "DECOY_BED=\"$refdir/STRdecoys.sorted.bed\"" >> $toolspec
echo "// By default, uses other samples in the same batch as a control" >> $toolspec
echo "CONTROL=\"\"" >> $toolspec
echo "// Uncomment the line below to use a set of WGS samples as controls, or specify your own" >> $toolspec
echo "//CONTROL=\"$refdir/hg19.PCRfreeWGS_143_STRetch_controls.tsv\"" >> $toolspec
echo >> $toolspec

if [ ! -f $bpipeconfig ] ; then
    echo "pipelines/bpipe.config not found, creating it"
    #copy bpipe.config template to pipeline directory
    cp $bpipeconfig_template $bpipeconfig
fi

#loop through commands to check they are all installed
echo "**********************************************************"
echo "Checking that all required tools were installed:"
Final_message="All commands installed successfully!"
for c in $commands ; do
    c_path=$(resolve_tool "$c")

    if [ -z "$c_path" ] ; then
        echo -n "WARNING: $c could not be found!!!! "
        echo "You will need to download and install $c manually, then add its path to $toolspec"
        Final_message="WARNING: One or more command did not install successfully. See warning messages above. You will need to correct this before running STRetch."
    else
        echo "$c looks like it has been installed at $c_path"
    fi
done

for j in $jarfiles ; do
    if [ ! -f $PWD/bin/$j.jar ] ; then
        echo -n "WARNING: $j could not be found!!!! "
	echo "You will need to download and install $j manually, then add its path to $toolspec"
	Final_message="WARNING: One or more command did not install successfully. See warning messages above. You will need to correct this before running STRetch."
    else
        echo "$j looks like it has been installed"
    fi
done


echo "**********************************************************"

#check for reference data
if [ "$SKIP_REF" = "1" ] ; then
    echo "SKIP_REF=1, reference data intentionally skipped"
elif [ ! -f $refdir/hg19.PCRfreeWGS_143_STRetch_controls.tsv ] ; then
    echo -n "WARNING: reference files could not be found!!!! "
    echo "You will need to download them manually, then add the path to $toolspec"
else
    echo "It looks like the reference data has been downloaded"
fi

echo "**********************************************************"

#check for config files
if [ ! -f $toolspec ] ; then
    echo -n "WARNING: pipelines/pipeline_config.groovy could not be found!!!! "
    echo "You will need to create this file manually."
else
    echo "It looks like pipelines/pipeline_config.groovy exists"
fi

if [ ! -f $bpipeconfig ] ; then
    echo -n "WARNING: pipelines/bpipe.config could not be found. "
    echo -n "This file is only required when using a job submission system. "
    echo "If required, you will need to create this file manually."
else
    echo "It looks like pipelines/bpipe.config exists"
fi

echo "**********************************************************"
echo $Final_message
