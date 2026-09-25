import os
import pyvista as pv

root_dir = os.path.join(os.getcwd(), 'data')
mesh_path = os.path.join(root_dir, 'organ_model.stl')

print(f'Loading 3D model from {mesh_path}...')
mesh = pv.read(mesh_path)

print('Opening 3D viewer. You can rotate and zoom using your mouse.')
plotter = pv.Plotter()
plotter.add_mesh(mesh, color='lightpink', specular=0.5, show_edges=True)
plotter.add_title('Digital Twin - Organ Geometry')
plotter.show()

