import os
import numpy as np
import nibabel as nib
import matplotlib.pyplot as plt

root_dir = os.path.join(os.getcwd(), 'data')
os.makedirs(root_dir, exist_ok=True)

print('Generating a synthetic 3D MRI scan (a digital phantom)...')

# Create a blank 3D volume 64x64x64
img_data = np.zeros((64, 64, 64), dtype=np.float32)
label_data = np.zeros((64, 64, 64), dtype=np.uint8)

# Draw a sphere in the middle to represent an organ (e.g. a tumor or hippocampus)
center = (32, 32, 32)
radius = 15

for x in range(64):
    for y in range(64):
        for z in range(64):
            dist = np.sqrt((x - center[0])**2 + (y - center[1])**2 + (z - center[2])**2)
            if dist <= radius:
                img_data[x, y, z] = np.random.normal(150, 20)  # Tissue intensity
                label_data[x, y, z] = 1  # Segmented organ
            elif dist <= radius + 5:
                img_data[x, y, z] = np.random.normal(50, 10)  # Outer tissue
            else:
                img_data[x, y, z] = np.random.normal(10, 5)  # Background noise

# Apply a little gaussian blur to make it look like a scan
from scipy.ndimage import gaussian_filter
img_data = gaussian_filter(img_data, sigma=1)

# Save as NIfTI (.nii.gz) files
img_nifti = nib.Nifti1Image(img_data, np.eye(4))
label_nifti = nib.Nifti1Image(label_data, np.eye(4))

img_path = os.path.join(root_dir, 'synthetic_scan.nii.gz')
label_path = os.path.join(root_dir, 'synthetic_label.nii.gz')

nib.save(img_nifti, img_path)
nib.save(label_nifti, label_path)

print(f'Saved synthetic scan to: {img_path}')
print(f'Saved synthetic label to: {label_path}')

# Visualizing the middle slice
mid_slice = 32
plt.figure(figsize=(10, 5))

plt.subplot(1, 2, 1)
plt.title('Synthetic MRI Scan (Slice 32)')
plt.imshow(img_data[:, :, mid_slice], cmap='gray')
plt.axis('off')

plt.subplot(1, 2, 2)
plt.title('Segmentation Label (Organ)')
plt.imshow(label_data[:, :, mid_slice], cmap='nipy_spectral')
plt.axis('off')

output_img = 'sample_mri_slice.png'
plt.savefig(output_img)
print(f'Saved visualization to {output_img}')
