import os
import matplotlib.pyplot as plt
import nibabel as nib
from monai.apps import DecathlonDataset

root_dir = os.path.join(os.getcwd(), 'data')
os.makedirs(root_dir, exist_ok=True)

print('Downloading Medical Segmentation Decathlon - Task04_Hippocampus (MRI)...')
print('This may take a minute. It''s a ~27MB dataset.')

# Download the dataset
dataset = DecathlonDataset(
    root_dir=root_dir,
    task='Task04_Hippocampus',
    section='training',
    download=True,
)

print(f'Download complete! Data saved to: {root_dir}')
print(f'Number of training scans available: {len(dataset)}')

# Get the first scan
sample = dataset[0]
image_path = sample['image']
label_path = sample['label']

print(f'Loading first image: {image_path}')

# Load the NIfTI file (.nii.gz)
img = nib.load(image_path)
img_data = img.get_fdata()

label = nib.load(label_path)
label_data = label.get_fdata()

print(f'Image shape: {img_data.shape}')

# Visualizing the middle slice
mid_slice = img_data.shape[2] // 2

plt.figure(figsize=(10, 5))

plt.subplot(1, 2, 1)
plt.title(f'MRI Scan (Slice {mid_slice})')
plt.imshow(img_data[:, :, mid_slice], cmap='gray')
plt.axis('off')

plt.subplot(1, 2, 2)
plt.title('Segmentation Label (Hippocampus)')
plt.imshow(label_data[:, :, mid_slice], cmap='nipy_spectral')
plt.axis('off')

# Save the plot
output_img = 'sample_mri_slice.png'
plt.savefig(output_img)
print(f'Saved visualization to {output_img}')
