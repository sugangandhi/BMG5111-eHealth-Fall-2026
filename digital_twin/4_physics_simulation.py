import os
import numpy as np
import pyvista as pv

root_dir = os.path.join(os.getcwd(), 'data')
mesh_path = os.path.join(root_dir, 'organ_model.stl')

print(f'Loading 3D model from {mesh_path}...')
mesh = pv.read(mesh_path)

# 1. Create a copy of the mesh to deform
deformed_mesh = mesh.copy()

# 2. Simulate Physics: Apply a downward force (e.g., a surgical tool pressing on top)
print('Simulating soft tissue deformation (compression)...')
vertices = np.array(deformed_mesh.points)

# Find the highest point (Z-axis) to apply the pressure
max_z_idx = np.argmax(vertices[:, 2])
pressure_point = vertices[max_z_idx]

# Calculate distance of all points from the pressure point
distances = np.linalg.norm(vertices - pressure_point, axis=1)

# Apply a Gaussian displacement field (closer points move down more)
force_magnitude = 7.0  # amount of compression
influence_radius = 12.0

displacement = np.zeros_like(vertices)
displacement[:, 2] = -force_magnitude * np.exp(-(distances**2) / (2 * influence_radius**2))

# Update vertices with displacement
deformed_mesh.points = vertices + displacement

# 3. Calculate 'Stress' (Displacement magnitude) for visualization
stress_values = np.linalg.norm(displacement, axis=1)
deformed_mesh['Stress (Deformation)'] = stress_values

# 4. Save the deformed twin
deformed_path = os.path.join(root_dir, 'organ_deformed.stl')
deformed_mesh.save(deformed_path)
print(f'Saved deformed digital twin to {deformed_path}')

# 5. Visualize the Simulation (Interactive)
print('Generating the physics simulation visualization (off-screen)...')
plotter = pv.Plotter(shape=(1, 2), off_screen=True)

# Subplot 1: Original
plotter.subplot(0, 0)
plotter.add_text('Original Organ (Digital Twin)', font_size=12)
plotter.add_mesh(mesh, color='lightblue', show_edges=True)

# Subplot 2: Deformed with Stress Heatmap
plotter.subplot(0, 1)
plotter.add_text('Physics Simulation: Surgical Compression', font_size=12)
plotter.add_mesh(deformed_mesh, scalars='Stress (Deformation)', cmap='jet', show_edges=True)

plotter.link_views()  # Link camera movements so both rotate together

print('Saving screenshot of the simulation to simulation_result.png')
plotter.screenshot('simulation_result.png')
print('Done! Please open simulation_result.png to see the result.')
