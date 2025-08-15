# brain-ALPS
Automatic brain DTI-ALPS analysis

# Overview
<img width="1347" height="844" alt="image" src="https://github.com/user-attachments/assets/c0420da5-7e5e-439e-9d2c-d253ed353d45" />

# Prerequisites
- Freesurfer
- FSL > 7.4.1

# Data requirments
- 4D dMRI in nii.gz with bvec, bval, json

# Usage
- Setup fsl and freesurfer env
- Run `bash ALPS_main.sh $subject_folder_name`

# Reference
- Alfaro-Almagro, F., Jenkinson, M., Bangerter, N.K., Andersson, J.L.R., Griffanti, L., Douaud, G., Sotiropoulos, S.N., Jbabdi, S., Hernandez-Fernandez, M., Vallee, E., Vidaurre, D., Webster, M., McCarthy, P., Rorden, C., Daducci, A., Alexander, D.C., Zhang, H., Dragonu, I., Matthews, P.M., Miller, K.L., Smith, S.M., 2018. Image processing and Quality Control for the first 10,000 brain imaging datasets from UK Biobank. Neuroimage 166, 400–424. https://doi.org/10.1016/j.neuroimage.2017.10.034
- Liu, X, Barisano, G, et al., Cross-Vendor Test-Retest Validation of Diffusion Tensor Image Analysis along the Perivascular Space (DTI-ALPS) for Evaluating Glymphatic System Function, Aging and Disease (2023)" 
