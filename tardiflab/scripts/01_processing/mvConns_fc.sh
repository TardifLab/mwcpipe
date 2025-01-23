#!/bin/bash
#
#
# move FC connectomes around
#
# Inputs:
#	$1 : source directory
#	$2 : target directory
#
# note: files should conform to expected naming structure: e.g., sub-01_ses-1_func_space-conte69-32k_atlas-schaefer-400_desc-FC.txt
#
# 2021 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#------------------------------------------------------------------------------------------------------------------------------------

sourcedir=$1
targetdir=$2

# FUNK-tion
cd "$sourcedir"
shopt -s globstar
for i in **/*conte69*FC.txt; do
        fn=$(basename $i)
        parc=$(echo $fn | cut -d "_" -f5 | sed 's/^atlas-//') 				# relies on the parcellation being in the 5th field

        # assign new fullfile
        dirnew="$targetdir/${parc}/FC"
        fnnew="$dirnew/${fn}"

        if [ ! -d ${dirnew} ]; then mkdir -p ${dirnew} ;  fi
        cp --verbose $i $fnnew 								# sometimes you wanna copy
#        mv -v $i $fnnew 								# sometimes you wanna move
done

# --------- Version below used to rename files while moving


#sourcedir=$1
#targetdir=$2

# root_dir=/data_/tardiflab/mwc/bids/derivatives/micapipe

# Read subject tags from csv into arrays for renaming (used one time to rename subjects)
#sublist=${root_dir}/other/MICs_rename-equivalence_07-2021.csv
#original=($(tail -n +2 $sublist | cut -d ',' -f1))
#mics=($(tail -n +2 $sublist | cut -d ' ' -f2))

# go to dir & iterate through files
#if [ ! -d ${targetdir} ]; then mkdir -p ${targetdir} ;  fi
#cd "$sourcedir"
#shopt -s globstar
#for i in **/*conte69*FC.txt; do
#	fnold=$(basename $i)
#        idold=$(echo $fnold | cut -d "_" -f1 | cut -d "-" -f2)
#	parc=$(echo $fnold | cut -d "_" -f5 | sed -e "s/"atlas-"/""/") 				# chops off "atlas-"
#
#	# Get new ID tag from csv
#	iiold=$(echo ${original[@]/$idold//} | cut -d/ -f1 | wc -w | tr -d ' ')
#	idnew=$(echo "${mics[$iiold]}")
#	idnew="$(echo -e "${idnew}" | tr -d '[:space:]')" 					# trim white space from variable name
#
#	# assign new fullfile
#	fnnew="$targetdir/${idnew}_${parc}_rsfmri-FC_conte69-32k.txt"
#
##        cp --verbose $i $fnnew
#	mv -v $i $fnnew
#done


# TESTING
#        echo "*-----------------------------------------------------------------------------*"
#        echo "$i"
#        echo "Original filename         : $fnold"
#        echo "Original ID               : $idold"
#        echo "Original parc             : $parc"
#        echo "Original index            : $iiold"
#        echo " "
#        echo "new filename              : $fnnew"
#        echo "new ID                    : $idnew"
#        echo "*-----------------------------------------------------------------------------*"


