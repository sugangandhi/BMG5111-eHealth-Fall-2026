import os
import nibabel as nib
from skimage import measure
import trimesh

root_dir = os.path.join(os.getcwd(), 'data')
label_path = os.path.join(root_dir, 'synthetic_label.nii.gz')

print(f'Loading segmented organ from {label_path}...')
label = nib.load(label_path)
label_data = label.get_fdata()

print('Running Marching Cubes algorithm to generate 3D surface mesh...')
# Marching cubes finds the surface of the organ (where value is 1)
verts, faces, normals, values = measure.marching_cubes(label_data, level=0.5)

print(f'Generated {len(verts)} vertices and {len(faces)} faces.')

# Create a Trimesh object
mesh = trimesh.Trimesh(vertices=verts, faces=faces, vertex_normals=normals)

# Smooth the mesh (medical scans are often blocky/voxelized)
print('Smoothing the mesh...')
trimesh.smoothing.filter_laplacian(mesh, iterations=10)

# Save the 3D mesh as an STL file
mesh_path = os.path.join(root_dir, 'organ_model.stl')
mesh.export(mesh_path)
print(f'Saved 3D model (Digital Twin) to {mesh_path}')

