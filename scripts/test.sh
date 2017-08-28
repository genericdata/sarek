#!/bin/bash
INSTALL=false
PROFILE="singularityTest"
TEST="ALL"
TRAVIS=false

while [[ $# -gt 0 ]]
do
  key="$1"
  case $key in
    -c|--travisci)
    TRAVIS=true
    shift
    ;;
    -i|--install)
    INSTALL=true
    shift
    ;;
    -p|--profile)
    PROFILE="$2"
    shift
    ;;
    -t|--test)
    TEST="$2"
    shift
    ;;
    *) # unknown option
    ;;
  esac
  shift
done

# Install Singularity
if [[ "$PROFILE" == singularityTest ]] && [[ "$INSTALL" == true ]]
then
  ./scripts/install.sh -t singularity
fi


function nf_test() {
  echo "$(tput setaf 1)nextflow run $@ -profile $PROFILE -resume --verbose$(tput sgr0)"
  nextflow run "$@" -profile "$PROFILE" -resume --verbose
}

nf_test buildReferences.nf --download

#remove images
if [[ "$PROFILE" == travis ]] && [[ "$TRAVIS" == true ]]
then
  docker rmi -f maxulysse/igvtools:1.1
else if [[ "$PROFILE" == singularityTest ]] && [[ "$TRAVIS" == true ]]
then
  rm -rf work/singularity/igvtools-1.1.img
fi

if [[ "$TEST" = MAPPING ]] || [[ "$TEST" = ALL ]]
then
  nf_test . --test --step preprocessing
fi

if [[ "$TEST" = REALIGN ]] || [[ "$TEST" = ALL ]]
then
  nf_test . --test --step preprocessing
  nf_test . --step realign --noReports
  nf_test . --step realign --tools HaplotypeCaller
  nf_test . --step realign --tools HaplotypeCaller --noReports --noGVCF
fi

if [[ "$TEST" = RECALIBRATE ]] || [[ "$TEST" = ALL ]]
then
  nf_test . --test --step preprocessing
  nf_test . --step recalibrate --noReports
  nf_test . --step recalibrate --tools FreeBayes,HaplotypeCaller,MuTect1,MuTect2,Strelka
  # Test whether restarting from an already recalibrated BAM works
  nf_test . --step skipPreprocessing --tools Strelka --noReports
fi

if [[ "$TEST" = ANNOTATE ]] || [[ "$TEST" = ALL ]]
then
  nf_test . --step preprocessing --sample data/tsv/tiny-manta.tsv --tools Manta
  nf_test . --test --step preprocessing --tools MuTect2,Strelka

  #remove images
  if [[ "$PROFILE" == travis ]] && [[ "$TRAVIS" == true ]]
  then
    docker rmi -f maxulysse/concatvcf:1.1 maxulysse/fastqc:1.1 maxulysse/gatk:1.0 maxulysse/gatk:1.1 maxulysse/mapreads:1.1 maxulysse/picard:1.1 maxulysse/runmanta:1.1 maxulysse/samtools:1.1 maxulysse/strelka:1.1
  else if [[ "$PROFILE" == singularityTest ]] && [[ "$TRAVIS" == true ]]
  then
    rm -rf work/singularity/concatvcf-1.1.img work/singularity/fastqc-1.1.img work/singularity/gatk-1.0.img work/singularity/gatk-1.1.img work/singularity/mapreads-1.1.img work/singularity/picard-1.1.img work/singularity/runmanta-1.1.img work/singularity/samtools-1.1.img work/singularity/strelka-1.1.img
  fi

  nf_test . --step annotate --tools snpEff,VEP --annotateTools Strelka
  nf_test . --step annotate --tools snpEff --annotateVCF VariantCalling/Manta/Manta_9876T_vs_1234N.diploidSV.vcf,VariantCalling/Manta/Manta_9876T_vs_1234N.somaticSV.vcf --noReports
fi
