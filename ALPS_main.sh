export FREESURFER_HOME="/path/to/freesurfer"
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR="/path/to/data/folder"
export FSLDIR="/path/to/fsl"
export FS_LICENSE="/freesurfer/license"
source $FSLDIR/etc/fslconf/fsl.sh


# Use the correct subject name and file paths
subject=$1
study_time=$2
if_eddy=$3
if_bidirect=$4
radius=2.5
subj_dir="$SUBJECTS_DIR/$subject/$study_time/DTI"
code_dir="/path/to/code"

# Find the dMRI files
dti_file=$(find "$subj_dir" -name "*_DTI.nii.gz" | head -1)
bvec_file=$(find "$subj_dir" -name "*_DTI.bvec" | head -1)
bval_file=$(find "$subj_dir" -name "*_DTI.bval" | head -1)
json_file=$(find "$subj_dir" -name "*_DTI.json" | head -1)
# Check if files exist
if [ ! -f "$dti_file" ]; then
    echo "Error: DTI file not found in $subj_dir"
    exit 1
fi

if [ ! -f "$bvec_file" ]; then
    echo "Error: bvec file not found in $subj_dir"
    exit 1
fi

if [ ! -f "$bval_file" ]; then
    echo "Error: bval file not found in $subj_dir"
    exit 1
fi
echo "Processing DTI file: $dti_file"
echo "Using bvec file: $bvec_file"
echo "Using bval file: $bval_file"

# Test PA if birection (AP or PA)
PA_file=""
AP_file=""
if [ "$if_bidirect" == 1 ]; then
  PA_file=$(find "$subj_dir" -name "*PA*.nii.gz" | head -1)
  AP_file=$(find "$subj_dir" -name "*AP*.nii.gz" | head -1)
  if [ ! -f "$PA_file" ] || [ ! -f "$AP_file" ]; then
    echo "Error: PA/AP file not found in $subj_dir"
    exit 1
  fi
fi
# Get the base name without extension for output files
base_name=$(basename "$dti_file" .nii.gz)

bval_length=$(awk '{print NF}' "$bval_file")
echo "Number of b evaluation: $bval_length"

# ##########预处理##########
echo "----------Preprocess Start-------------"
mkdir -p "${subj_dir}/preprocess"
# index.txt
indx=""
n=`${FSLDIR}/bin/fslval $dti_file dim4`
echo "Number of volumes: $n"
for ((i=1;i<=${n};i++));do
    indx="$indx 1"
done
echo $indx > ${subj_dir}/preprocess/eddy_index.txt
#acqparams.txt
if [ "$if_AP_PA" == 1 ]; then
    # Creation of acqparam file for AP and PA
    numlines=`${FSLDIR}/bin/fslval $AP_file dim2`
    dtiDwell=`$BB_BIN_DIR/bb_pipeline_tools/bb_get_dwell_time $AP_file`
    topupValue="0"`echo "scale=4;("$dtiDwell" * ("$numlines" -1.0)) / 1000.0 "| bc`

    cat /dev/null > ${subj_dir}/preprocess/acqparams.txt 

    for i in `seq 1 $numAP`;
    do
        printf "0 -1 0 $topupValue\n" >>${subj_dir}/preprocess/acqparams.txt
    done   

    for i in `seq 1 $numPA`;
    do
        printf "0 1 0 $topupValue\n" >>${subj_dir}/preprocess/acqparams.txt
    done   
else
    #获取json文件中的参数 - acqparam
    if [ -f "${json_file}" ]; then
        # ACQUISITION PARAMETERS OF FIRST INPUT (REQUIRED FOR EDDY)
        #scanner1=$(jq -r '.Manufacturer' "$json1") # -r gives you the raw output
        #scanner1=$(cat "${json1}" | grep -w Manufacturer | cut -d ' ' -f2 | tr -d ',')
        scanner1=$(cat "${json_file}" | awk -F'"' '/"Manufacturer"/ {print $4}')
        if [[ "$scanner1" == *"Philips"* ]]
        then
            #PEdir1=$(jq -r '.PhaseEncodingAxis' "$json1")
            #PEdir1=$(cat "${json1}" | grep -w PhaseEncodingAxis | cut -d ' ' -f2 | tr -d ',' | tr -d '"')
            PEdir1=$(cat "${json_file}" | awk -F'"' '/"PhaseEncodingAxis"/ {print $4}')
            TotalReadoutTime1=0.1 #this assumes that the readout time is identical for all acquisitions on the Philips scanner. A "realistic" read-out time is ~50-100ms (and eddy accepts 10-200ms). So use 0.1 (i.e., 100 ms), not 1.
        else
            #PEdir1=$(jq -r '.PhaseEncodingDirection' "$json1")
            #TotalReadoutTime1=$(jq -r '.TotalReadoutTime' "$json1")
            #PEdir1=$(cat "${json1}" | grep -w PhaseEncodingDirection | cut -d ' ' -f2 | tr -d ',' | tr -d '"')
            #TotalReadoutTime1=$(cat "${json1}" | grep -w TotalReadoutTime | cut -d ' ' -f2 | tr -d ',' | tr -d '"')
            PEdir1=$(cat "${json_file}" | awk -F'"' '/"PhaseEncodingDirection"/ {print $4}')
            TotalReadoutTime1=$(cat "${json_file}" | grep -w TotalReadoutTime | cut -d ':' -f2 | cut -d ',' -f1 | xargs)
            
        fi
        if [ "$PEdir1" = i ]; then printf "1 0 0 $TotalReadoutTime1" > "${subj_dir}/preprocess/acqparams.txt";
        elif [ "$PEdir1" = i- ]; then printf "-1 0 0 $TotalReadoutTime1" > "${subj_dir}/preprocess/acqparams.txt";
        elif [ "$PEdir1" = j ]; then printf "0 1 0 $TotalReadoutTime1" > "${subj_dir}/preprocess/acqparams.txt";
        elif [ "$PEdir1" = j- ]; then printf "0 -1 0 $TotalReadoutTime1" > "${subj_dir}/preprocess/acqparams.txt";
        elif [ "$PEdir1" = k ]; then printf "0 0 1 $TotalReadoutTime1" > "${subj_dir}/preprocess/acqparams.txt";
        elif [ "$PEdir1" = k- ]; then printf "0 0 -1 $TotalReadoutTime1" > "${subj_dir}/preprocess/acqparams.txt"; 
        fi
    fi
fi
#提取b0
# echo "提取b0"
if [ "$if_bidirect" == 1 ]; then
  fslroi "$dti_file" "${subj_dir}/preprocess/temp_b0_1" 0 -1 0 -1 0 -1 0 1
  fslroi "$PA_file" "${subj_dir}/preprocess/temp_b0_2" 0 -1 0 -1 0 -1 0 1
  fslmerge -t ${subj_dir}/preprocess/b0 ${subj_dir}/preprocess/temp_b0_1.nii.gz ${subj_dir}/preprocess/temp_b0_2.nii.gz
else
  # single direction
  fslroi "$dti_file" "${subj_dir}/preprocess/temp_b0_1" 0 -1 0 -1 0 -1 0 1
  fslroi "$dti_file" "${subj_dir}/preprocess/temp_b0_2" 0 -1 0 -1 0 -1 $((n / 2)) 1
  fslmaths "${subj_dir}/preprocess/temp_b0_1" -add "${subj_dir}/preprocess/temp_b0_2" -div 2 "${subj_dir}/preprocess/b0"
fi
b02b0_1=`find /${FSLDIR} -name "b02b0_1.cnf" | head -n 1`
topup --imain="${subj_dir}/preprocess/b0" --datain="${subj_dir}/preprocess/acqparams.txt" --config="${b02b0_1}" --out="${subj_dir}/preprocess/topup_results" --iout="${subj_dir}/preprocess/hifi_b0"
if [ "$if_AP_PA" == 1 ]; then
  applytopup --imain="${subj_dir}/preprocess/temp_b0_1,${subj_dir}/preprocess/temp_b0_2" --topup="${subj_dir}/preprocess/b0" --datain="${subj_dir}/preprocess/acqparams.txt" --inindex=1,2 --out="${subj_dir}/preprocess/b0"
else
  applytopup --imain="${subj_dir}/preprocess/temp_b0_1" --topup="${subj_dir}/preprocess/b0" --datain="${subj_dir}/preprocess/acqparams.txt" --inindex=1 --out="${subj_dir}/preprocess/b0"
fi
# bet, get brain mask
bet2 "${subj_dir}/preprocess/b0" "${subj_dir}/preprocess/nodif_brain" -m 
# 涡流矫正
echo "涡流矫正"
if [ ! -f "${subj_dir}/preprocess/data.nii.gz" ] && [ "$if_eddy" == 1 ]; then
  # 已有矫正结果则跳过，否则运行eddy矫正代码。速度非常慢。
  echo "开始涡流矫正,速度非常慢"
  eddy diffusion --imain="$dti_file" --mask="${subj_dir}/preprocess/nodif_brain_mask.nii.gz" --acqp=${subj_dir}/preprocess/acqparams.txt --index=${subj_dir}/preprocess/eddy_index.txt --bvecs=$bvec_file --bvals=$bval_file --out="${subj_dir}/preprocess/data" --flm=quadratic --resamp=jac --slm=linear --fwhm=2 --ff=5  --sep_offs_move --nvoxhp=1000 --very_verbose  --repol --rms
  # eddy quality control
  eddy_quad "${subj_dir}/preprocess/data" -idx ${subj_dir}/preprocess/eddy_index.txt -par ${subj_dir}/preprocess/acqparams.txt -m "${subj_dir}/preprocess/nodif_brain_mask.nii.gz" -b $bval_file -o "${subj_dir}/preprocess/eddy_qc_dir"
fi

# GDC 无线圈矫正参数 跳过
# "${code_dir}"/bb_pipeline_tools/bb_GDC --workingdir=${subj_dir}/preprocess/data_GDC --in=data.nii.gz --out=data_ud.nii.gz --owarp=data_ud_warp.nii.gz --codedir=$code_dir
# echo "GDC结束"
#应用GDC
# applywarp --ref="${subj_dir}/preprocess/nodif_brain_mask.nii.gz" --in="${subj_dir}/preprocess/nodif_brain_mask.nii.gz" --warp="${subj_dir}/preprocess/data_ud_warp.nii.gz" --out="${subj_dir}/preprocess/nodif_brain_mask_ud.nii.gz" --interp=nn

#计算张量
echo "计算张量"
dtifit --data="${subj_dir}/preprocess/data.nii.gz" --out="${subj_dir}/preprocess/dti" --mask="${subj_dir}/preprocess/nodif_brain_mask.nii.gz" --bvecs="${subj_dir}/preprocess/data.eddy_rotated_bvecs" --bvals="$bval_file" --save_tensor
echo "----------Preprocess Clear-------------"

##########TBSS##########
echo "----------TBSS Start-------------"
if [ -d "${subj_dir}/TBSS/FA" ]; then
  rm -rf "${subj_dir}/TBSS"
fi
mkdir -p "${subj_dir}/TBSS"
cp "${subj_dir}/preprocess/dti_FA.nii.gz" "${subj_dir}/TBSS/dti_FA.nii.gz"
# Change to TBSS directory for processing
echo "Change to TBSS directory: ${subj_dir}/TBSS"
cd "${subj_dir}/TBSS"
# Run TBSS preprocessing
echo "Run tbss_1_preproc"
"${code_dir}"/bb_tbss/bb_tbss_1_preproc dti_FA.nii.gz
echo "Run tbss_2_reg"
"${code_dir}"/bb_tbss/bb_tbss_2_reg -T "${code_dir}"
echo "Run tbss_3_postreg"
# -T for project to FMRIB58_MNI space and -S for project to MNI152_1mm space
"${code_dir}"/bb_tbss/bb_tbss_3_postreg -T
echo "Run tbss_4_prestats"
"${code_dir}"/bb_tbss/bb_tbss_4_prestats 0.2
echo "Run tbss_non_FA"
"${code_dir}"/bb_tbss/bb_tbss_non_FA
echo "----------TBSS Clear-------------"

##########ALPS##########
echo "----------ALPS Start-------------"
mkdir -p "${subj_dir}/mALPS"
# Split tensor into individual components
fslsplit "${subj_dir}/preprocess/dti_tensor.nii.gz" "${subj_dir}/mALPS/tensor_"
# JHU-ICBM-labels-1mm模板转换至FA空间下模板：JHU_in_FA.nii.gz 
# Note: This requires the TBSS registration to be completed first
  #JHU-ICBM-labels-1mm模板转换至FA空间下模板：JHU_in_FA.nii.gz
applywarp --ref="${subj_dir}/TBSS/FA/dti_FA.nii.gz" --in="${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm" --out="${subj_dir}/mALPS/JHU_in_FA.nii.gz" --warp="${subj_dir}/TBSS/FA/MNI_to_dti_FA_warp.nii.gz"

#建立联合纤维mask（41-42）
mri_binarize --i "${subj_dir}/mALPS/JHU_in_FA.nii.gz" --match 42 41 --o "${subj_dir}/mALPS/JHU_association_mask.nii.gz"

#建立投射纤维mask（23-28）
mri_binarize --i "${subj_dir}/mALPS/JHU_in_FA.nii.gz" --match 24 25 26 27 28 23 --o "${subj_dir}/mALPS/JHU_projection_mask.nii.gz"

#MNI space：37 -12 24  26 -12 24  -26 -12 24  -37 -12 24 
#FSL space：53 114 96  64 114 96  116 114 96  127 114 96

#取点
# 1 = R_SLF
fslmaths "${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz" -mul 0 -add 1 -roi 53 1 114 1 96  1 0 1  "${subj_dir}/mALPS/point_1.nii.gz" -odt float
# 2 = R_SCR
fslmaths "${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz" -mul 0 -add 1 -roi 64 1 114 1 96  1 0 1  "${subj_dir}/mALPS/point_2.nii.gz" -odt float
# 3 = L_SCR
fslmaths "${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz" -mul 0 -add 1 -roi 116 1 114 1 96  1 0 1  "${subj_dir}/mALPS/point_3.nii.gz" -odt float
# 4 = L_SLF
fslmaths "${FSLDIR}/data/atlases/JHU/JHU-ICBM-labels-1mm.nii.gz" -mul 0 -add 1 -roi 127 1 114 1 96  1 0 1  "${subj_dir}/mALPS/point_4.nii.gz" -odt float

#扩张成球，半径3mm
fslmaths "${subj_dir}/mALPS/point_1.nii.gz" -kernel sphere $radius -fmean -bin  "${subj_dir}/mALPS/sphere_1.nii.gz" -odt float

fslmaths "${subj_dir}/mALPS/point_2.nii.gz" -kernel sphere $radius -fmean -bin  "${subj_dir}/mALPS/sphere_2.nii.gz" -odt float

fslmaths "${subj_dir}/mALPS/point_3.nii.gz" -kernel sphere $radius -fmean -bin  "${subj_dir}/mALPS/sphere_3.nii.gz" -odt float

fslmaths "${subj_dir}/mALPS/point_4.nii.gz" -kernel sphere $radius -fmean -bin  "${subj_dir}/mALPS/sphere_4.nii.gz" -odt float

#点转换至FA空间下模板：${subj}_sphere_1_in_FA.nii.gz
applywarp --ref="${subj_dir}/TBSS/FA/dti_FA.nii.gz" --in="${subj_dir}/mALPS/sphere_1.nii.gz" --out="${subj_dir}/mALPS/sphere_1_in_FA.nii.gz" --warp="${subj_dir}/TBSS/FA/MNI_to_dti_FA_warp.nii.gz"

applywarp --ref="${subj_dir}/TBSS/FA/dti_FA.nii.gz" --in="${subj_dir}/mALPS/sphere_2.nii.gz" --out="${subj_dir}/mALPS/sphere_2_in_FA.nii.gz" --warp="${subj_dir}/TBSS/FA/MNI_to_dti_FA_warp.nii.gz"

applywarp --ref="${subj_dir}/TBSS/FA/dti_FA.nii.gz" --in="${subj_dir}/mALPS/sphere_3.nii.gz" --out="${subj_dir}/mALPS/sphere_3_in_FA.nii.gz" --warp="${subj_dir}/TBSS/FA/MNI_to_dti_FA_warp.nii.gz"

applywarp --ref="${subj_dir}/TBSS/FA/dti_FA.nii.gz" --in="${subj_dir}/mALPS/sphere_4.nii.gz" --out="${subj_dir}/mALPS/sphere_4_in_FA.nii.gz" --warp="${subj_dir}/TBSS/FA/MNI_to_dti_FA_warp.nii.gz"



#合并所有roi
#proj合并
fslmaths "${subj_dir}/mALPS/sphere_2_in_FA.nii.gz" -add "${subj_dir}/mALPS/sphere_3_in_FA.nii.gz" "${subj_dir}/mALPS/proj.nii.gz"
#asso合并
fslmaths "${subj_dir}/mALPS/sphere_1_in_FA.nii.gz" -add "${subj_dir}/mALPS/sphere_4_in_FA.nii.gz" "${subj_dir}/mALPS/asso.nii.gz"
#全合并
fslmaths "${subj_dir}/mALPS/proj.nii.gz" -add "${subj_dir}/mALPS/asso.nii.gz" "${subj_dir}/mALPS/proj_asso.nii.gz"
#左合并
fslmaths "${subj_dir}/mALPS/sphere_3_in_FA.nii.gz" -add "${subj_dir}/mALPS/sphere_4_in_FA.nii.gz" "${subj_dir}/mALPS/proj_asso_l.nii.gz"
#右合并
fslmaths "${subj_dir}/mALPS/sphere_1_in_FA.nii.gz" -add "${subj_dir}/mALPS/sphere_2_in_FA.nii.gz" "${subj_dir}/mALPS/proj_asso_r.nii.gz"

# xmin=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $1}')
# xsize=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $2}')
# #取层,z1-z2 y1,y2
# zmin=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $5}') #29
# zsize=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $6}') #2
# echo "z1: $z1"
# echo "z2: $z2"
# ymin=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $3}') #126
# ysize=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $4}') #6
# echo "y1: $y1"
# echo "y2: $y2"
# #左取层,z1l-z2l y1l,y2l
# zminl=$(fslstats "${subj_dir}/mALPS/proj_asso_l.nii.gz" -w | awk '{print $5}') #29
# zsizel=$(fslstats "${subj_dir}/mALPS/proj_asso_l.nii.gz" -w | awk '{print $6}') #2
# echo "z1l: $z1l"
# echo "z2l: $z2l"
# yminl=$(fslstats "${subj_dir}/mALPS/proj_asso_l.nii.gz" -w | awk '{print $3}') 
# ysizel=$(fslstats "${subj_dir}/mALPS/proj_asso_l.nii.gz" -w | awk '{print $4}')
# echo "y1l: $y1l"
# echo "y2l: $y2l"
# #右取层,z1r-z2r y1r,y2r
# z1r=$(fslstats "${subj_dir}/mALPS/proj_asso_r.nii.gz" -w | awk '{print $5}')
# z2r=$(fslstats "${subj_dir}/mALPS/proj_asso_r.nii.gz" -w | awk '{print $6}')
# echo "z1r: $z1r"
# echo "z2r: $z2r"
# y1r=$(fslstats "${subj_dir}/mALPS/proj_asso_r.nii.gz" -w | awk '{print $3}')
# y2r=$(fslstats "${subj_dir}/mALPS/proj_asso_r.nii.gz" -w | awk '{print $4}')
# echo "y1r: $y1r"
# echo "y2r: $y2r"

# roi_center=$((x1 + x2 / 2))

# #roi高度的长方形mask,mask_left和mask_right,0-64,64-127
# fslmaths "${subj_dir}/mALPS/JHU_projection_mask.nii.gz" -mul 0 -add 1 -roi  0 -1 $y1 $y2 $z1 $z2 0 1 -bin "${subj_dir}/mALPS/slice_mask_in_FA.nii.gz"
# fslmaths "${subj_dir}/mALPS/JHU_projection_mask.nii.gz" -mul 0 -add 1 -roi  0 ($x1+$x2)/2 $y1r $y2r $z1r $z2r 0 1 -bin "${subj_dir}/mALPS/slice_mask_in_FA_right.nii.gz"
# fslmaths "${subj_dir}/mALPS/JHU_projection_mask.nii.gz" -mul 0 -add 1 -roi  ($x1+$x2)/2 -1 $y1l $y2l $z1l $z2l 0 1 -bin "${subj_dir}/mALPS/slice_mask_in_FA_left.nii.gz"

echo "使用图像中线分割（更稳定）"
# 获取图像尺寸
x_dim=$(fslhd "${subj_dir}/TBSS/dti_FA.nii.gz" | grep "^dim1" | awk '{print $2}')
x_mid=$((x_dim / 2))

echo "Image X dimension: $x_dim, midline: $x_mid"

# 获取总ROI的Y、Z边界（用于两侧）
y1=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $3}')  # 126
y2=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $4}')  # 6
z1=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $5}')  # 29
z2=$(fslstats "${subj_dir}/mALPS/proj_asso.nii.gz" -w | awk '{print $6}')  # 2

echo "Using Y bounds: $y1+$y2 (126+6), Z bounds: $z1+$z2 (29+2)"

fslmaths "${subj_dir}/mALPS/JHU_projection_mask.nii.gz" -mul 0 -add 1 -roi  0 -1 $y1 $y2 $z1 $z2 0 1 -bin "${subj_dir}/mALPS/slice_mask_in_FA.nii.gz"

# 右侧mask（X: 0 到 中线）
fslmaths "${subj_dir}/mALPS/JHU_projection_mask.nii.gz" -mul 0 -add 1 \
  -roi 0 $x_mid $y1 $y2 $z1 $z2 0 1 -bin \
  "${subj_dir}/mALPS/slice_mask_in_FA_right.nii.gz"

# 左侧mask（X: 中线 到 末尾）
left_size=$((x_dim - x_mid))
fslmaths "${subj_dir}/mALPS/JHU_projection_mask.nii.gz" -mul 0 -add 1 \
  -roi $x_mid $left_size $y1 $y2 $z1 $z2 0 1 -bin \
  "${subj_dir}/mALPS/slice_mask_in_FA_left.nii.gz"

echo "Created masks - Right: X(0-$((x_mid-1))), Left: X($x_mid-$((x_mid+left_size-1)))"

#左右roi mask与纤维mask做交集,取值
fslmaths "${subj_dir}/mALPS/JHU_association_mask.nii.gz" -mul "${subj_dir}/mALPS/slice_mask_in_FA_left.nii.gz" "${subj_dir}/mALPS/asso_left.nii.gz"
fslmaths "${subj_dir}/mALPS/JHU_projection_mask.nii.gz" -mul "${subj_dir}/mALPS/slice_mask_in_FA_left.nii.gz" "${subj_dir}/mALPS/proj_left.nii.gz"
xxpl=$(fslstats "${subj_dir}/mALPS/tensor_0000.nii.gz" -k "${subj_dir}/mALPS/proj_left.nii.gz" -M)
xxal=$(fslstats "${subj_dir}/mALPS/tensor_0000.nii.gz" -k "${subj_dir}/mALPS/asso_left.nii.gz" -M)
yypl=$(fslstats "${subj_dir}/mALPS/tensor_0003.nii.gz" -k "${subj_dir}/mALPS/proj_left.nii.gz" -M)
zzal=$(fslstats "${subj_dir}/mALPS/tensor_0005.nii.gz" -k "${subj_dir}/mALPS/asso_left.nii.gz" -M)
result1=$(bc <<< "$xxpl + $xxal")
result2=$(bc <<< "$yypl + $zzal")
mALPS_l=$(bc <<< "scale=6; $result1 / $result2")

fslmaths "${subj_dir}/mALPS/JHU_association_mask.nii.gz" -mul "${subj_dir}/mALPS/slice_mask_in_FA_right.nii.gz" "${subj_dir}/mALPS/asso_right.nii.gz"
fslmaths "${subj_dir}/mALPS/JHU_projection_mask.nii.gz" -mul "${subj_dir}/mALPS/slice_mask_in_FA_right.nii.gz" "${subj_dir}/mALPS/proj_right.nii.gz"
xxpr=$(fslstats "${subj_dir}/mALPS/tensor_0000.nii.gz" -k "${subj_dir}/mALPS/proj_right.nii.gz" -M)
xxar=$(fslstats "${subj_dir}/mALPS/tensor_0000.nii.gz" -k "${subj_dir}/mALPS/asso_right.nii.gz" -M)
yypr=$(fslstats "${subj_dir}/mALPS/tensor_0003.nii.gz" -k "${subj_dir}/mALPS/proj_right.nii.gz" -M)
zzar=$(fslstats "${subj_dir}/mALPS/tensor_0005.nii.gz" -k "${subj_dir}/mALPS/asso_right.nii.gz" -M)
result3=$(bc <<< "$xxpr + $xxar")
result4=$(bc <<< "$yypr + $zzar")
mALPS_r=$(bc <<< "scale=6; $result3 / $result4")


#计算参数+输出
  #设置输出表格
echo "subjID,Dxx_projection_l,Dxx_association_l,Dyy_projection_l,Dzz_association_l,mALPS_l,Dxx_projection_r,Dxx_association_r,Dyy_projection_r,Dzz_association_r,mALPS_r" > "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," ${subj} >>  "${subj_dir}/mALPS/mALPS_all.csv"

  #右输出
printf "%s," $xxpr >> "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," $xxar >> "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," $yypr >> "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," $zzar >> "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," $mALPS_r >> "${subj_dir}/mALPS/mALPS_all.csv"

  #左输出
printf "%s," $xxpl >> "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," $xxal >> "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," $yypl >> "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," $zzal >> "${subj_dir}/mALPS/mALPS_all.csv"
printf "%s," $mALPS_l >> "${subj_dir}/mALPS/mALPS_all.csv"

echo "" >>  "${subj_dir}/mALPS/mALPS_all.csv"

echo "----------ALPS End-------------"
echo "ALPS analysis successful! Browse ${subj_dir}/mALPS/mALPS_all.csv for results."

