import React, { useRef, useMemo, useState, useEffect, useCallback } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls } from '@react-three/drei';
import * as THREE from 'three';
import { 
  Play, Pause, RotateCcw, Eye, EyeOff, Layers, Sliders, 
  Activity, Maximize2, Zap, Compass, Info, ChevronRight,
  Heart, Shield, Crosshair, Sparkles, Menu, User, Users, X, Check, ChevronDown
} from 'lucide-react';

// ============================================================================
// CONSTANTS & RADIOLOGY PRESETS
// ============================================================================
const WINDOW_PRESETS = {
  softTissue: { name: 'Soft Tissue', width: 400, level: 40, desc: 'Abdomen & Mediastinum' },
  lung: { name: 'Lung Parenchyma', width: 1500, level: -600, desc: 'Bronchial & Vascular markings' },
  bone: { name: 'Bone / Skeletal', width: 2000, level: 500, desc: 'Cortical & Trabecular bone' },
  angio: { name: 'Angiography', width: 600, level: 160, desc: 'Contrast-enhanced vessels' },
};

const ORGANS = [
  { id: 'lungs', name: 'Lungs', color: '#06b6d4', huRange: [-850, -400], zRange: [0.1, 0.9], icon: '🫁' },
  { id: 'heart', name: 'Heart & Aorta', color: '#f43f5e', huRange: [30, 220], zRange: [0.2, 0.65], icon: '❤️' },
  { id: 'liver', name: 'Liver', color: '#f59e0b', huRange: [45, 75], zRange: [-0.3, 0.25], icon: '🟤' },
  { id: 'kidneys', name: 'Kidneys', color: '#10b981', huRange: [30, 60], zRange: [-0.55, -0.05], icon: '🟢' },
  { id: 'spleen', name: 'Spleen', color: '#a855f7', huRange: [40, 55], zRange: [-0.15, 0.25], icon: '🟣' },
  { id: 'spine', name: 'Spine & Ribs', color: '#e2e8f0', huRange: [400, 1200], zRange: [-0.9, 0.95], icon: '🦴' },
];

// ============================================================================
// THREE.JS 3D ANATOMICAL TORSO & CUTTING PLANE
// ============================================================================
function AnatomicalScene({ 
  plane, 
  slicePos, 
  selectedOrgan, 
  onSelectOrgan, 
  enableClipping, 
  showContours 
}) {
  const controlsRef = useRef();

  // Three.js clipping plane definition
  const clipPlane = useMemo(() => {
    if (!enableClipping) return null;
    if (plane === 'axial') {
      return new THREE.Plane(new THREE.Vector3(0, -1, 0), slicePos * 4.5);
    } else if (plane === 'coronal') {
      return new THREE.Plane(new THREE.Vector3(0, 0, -1), slicePos * 2.2);
    } else {
      return new THREE.Plane(new THREE.Vector3(-1, 0, 0), slicePos * 2.5);
    }
  }, [plane, slicePos, enableClipping]);

  const clippingPlanes = useMemo(() => (clipPlane ? [clipPlane] : []), [clipPlane]);

  return (
    <>
      <ambientLight intensity={0.9} />
      <directionalLight position={[10, 15, 10]} intensity={1.4} />
      <directionalLight position={[-10, -10, -10]} intensity={0.5} />
      <pointLight position={[0, 0, 5]} intensity={0.9} color="#38bdf8" />

      <OrbitControls 
        ref={controlsRef} 
        enableDamping 
        dampingFactor={0.05} 
        minDistance={5} 
        maxDistance={22}
      />

      {/* Anatomical Organ Group */}
      <group position={[0, 0, 0]}>
        
        {/* 1. Spine (Vertebral Column) */}
        <SpineMesh 
          selected={selectedOrgan === 'spine'} 
          onClick={() => onSelectOrgan('spine')}
          clippingPlanes={clippingPlanes}
        />

        {/* 2. Ribcage */}
        <RibcageMesh 
          selected={selectedOrgan === 'spine'} 
          onClick={() => onSelectOrgan('spine')}
          clippingPlanes={clippingPlanes}
        />

        {/* 3. Lungs (Bilateral) */}
        <LungsMesh 
          selected={selectedOrgan === 'lungs'} 
          onClick={() => onSelectOrgan('lungs')}
          clippingPlanes={clippingPlanes}
        />

        {/* 4. Heart & Aorta */}
        <HeartMesh 
          selected={selectedOrgan === 'heart'} 
          onClick={() => onSelectOrgan('heart')}
          clippingPlanes={clippingPlanes}
        />

        {/* 5. Liver */}
        <LiverMesh 
          selected={selectedOrgan === 'liver'} 
          onClick={() => onSelectOrgan('liver')}
          clippingPlanes={clippingPlanes}
        />

        {/* 6. Kidneys (Bilateral) */}
        <KidneysMesh 
          selected={selectedOrgan === 'kidneys'} 
          onClick={() => onSelectOrgan('kidneys')}
          clippingPlanes={clippingPlanes}
        />

        {/* 7. Spleen */}
        <SpleenMesh 
          selected={selectedOrgan === 'spleen'} 
          onClick={() => onSelectOrgan('spleen')}
          clippingPlanes={clippingPlanes}
        />

        {/* Visual 3D Cutting Plane Indicator */}
        <CuttingPlaneIndicator plane={plane} slicePos={slicePos} />
      </group>
    </>
  );
}

// ----------------------------------------------------------------------------
// 3D ORGAN COMPONENTS
// ----------------------------------------------------------------------------
function SpineMesh({ selected, onClick, clippingPlanes }) {
  const vertebrae = useMemo(() => {
    const items = [];
    for (let i = 0; i < 22; i++) {
      const y = 4.2 - i * 0.42;
      const z = -0.8 + Math.sin(i * 0.2) * 0.25;
      items.push({ y, z, key: i });
    }
    return items;
  }, []);

  return (
    <group onClick={(e) => { e.stopPropagation(); onClick(); }}>
      {vertebrae.map((v) => (
        <mesh key={v.key} position={[0, v.y, v.z]}>
          <boxGeometry args={[0.75, 0.28, 0.85]} />
          <meshStandardMaterial 
            color={selected ? "#38bdf8" : "#e2e8f0"} 
            roughness={0.4}
            metalness={0.2}
            emissive={selected ? "#0284c7" : "#000000"}
            emissiveIntensity={selected ? 0.6 : 0}
            clippingPlanes={clippingPlanes}
            clipShadows
          />
        </mesh>
      ))}
    </group>
  );
}

function RibcageMesh({ selected, onClick, clippingPlanes }) {
  const ribs = useMemo(() => {
    const list = [];
    for (let r = 0; r < 9; r++) {
      const y = 3.6 - r * 0.45;
      const rx = 1.9 + Math.sin(r * 0.35) * 0.45;
      const rz = 1.35 + Math.sin(r * 0.3) * 0.25;
      list.push({ y, rx, rz, key: r });
    }
    return list;
  }, []);

  return (
    <group onClick={(e) => { e.stopPropagation(); onClick(); }}>
      {ribs.map((rib) => (
        <group key={rib.key} position={[0, rib.y, 0]}>
          {/* Left Rib */}
          <mesh position={[rib.rx * 0.5, 0, 0]} rotation={[0.1, 0, -0.15]}>
            <torusGeometry args={[rib.rx * 0.65, 0.05, 8, 24, Math.PI * 0.85]} />
            <meshStandardMaterial 
              color={selected ? "#38bdf8" : "#cbd5e1"} 
              roughness={0.5} 
              clippingPlanes={clippingPlanes}
            />
          </mesh>
          {/* Right Rib */}
          <mesh position={[-rib.rx * 0.5, 0, 0]} rotation={[0.1, Math.PI, 0.15]}>
            <torusGeometry args={[rib.rx * 0.65, 0.05, 8, 24, Math.PI * 0.85]} />
            <meshStandardMaterial 
              color={selected ? "#38bdf8" : "#cbd5e1"} 
              roughness={0.5} 
              clippingPlanes={clippingPlanes}
            />
          </mesh>
        </group>
      ))}
    </group>
  );
}

function LungsMesh({ selected, onClick, clippingPlanes }) {
  return (
    <group onClick={(e) => { e.stopPropagation(); onClick(); }}>
      {/* Right Lung (Anatomical Right = Viewer Left) */}
      <mesh position={[-1.15, 2.2, 0.15]} rotation={[0, 0.1, -0.05]}>
        <sphereGeometry args={[1.05, 32, 32]} />
        <meshPhysicalMaterial 
          color="#06b6d4" 
          transparent 
          opacity={selected ? 0.85 : 0.45}
          roughness={0.2}
          transmission={0.4}
          emissive={selected ? "#06b6d4" : "#083344"}
          emissiveIntensity={selected ? 0.8 : 0.1}
          clippingPlanes={clippingPlanes}
        />
      </mesh>
      {/* Left Lung (Has cardiac notch) */}
      <mesh position={[1.15, 2.2, 0.2]} rotation={[0, -0.1, 0.05]}>
        <sphereGeometry args={[0.95, 32, 32]} />
        <meshPhysicalMaterial 
          color="#06b6d4" 
          transparent 
          opacity={selected ? 0.85 : 0.45}
          roughness={0.2}
          transmission={0.4}
          emissive={selected ? "#06b6d4" : "#083344"}
          emissiveIntensity={selected ? 0.8 : 0.1}
          clippingPlanes={clippingPlanes}
        />
      </mesh>
    </group>
  );
}

function HeartMesh({ selected, onClick, clippingPlanes }) {
  const meshRef = useRef();
  useFrame(({ clock }) => {
    if (meshRef.current) {
      const beat = 1 + Math.sin(clock.getElapsedTime() * 4) * 0.03;
      meshRef.current.scale.set(beat, beat, beat);
    }
  });

  return (
    <group ref={meshRef} position={[0.25, 1.85, 0.45]} onClick={(e) => { e.stopPropagation(); onClick(); }}>
      {/* Ventricular mass */}
      <mesh rotation={[0.2, 0.3, -0.3]}>
        <sphereGeometry args={[0.72, 28, 28]} />
        <meshStandardMaterial 
          color="#f43f5e"
          roughness={0.3}
          metalness={0.1}
          emissive={selected ? "#f43f5e" : "#881337"}
          emissiveIntensity={selected ? 0.9 : 0.25}
          clippingPlanes={clippingPlanes}
        />
      </mesh>
      {/* Aortic Arch */}
      <mesh position={[-0.1, 0.65, -0.1]} rotation={[0.4, 0, 0.2]}>
        <torusGeometry args={[0.32, 0.12, 12, 24, Math.PI * 0.9]} />
        <meshStandardMaterial 
          color="#fb7185" 
          roughness={0.3} 
          clippingPlanes={clippingPlanes}
        />
      </mesh>
    </group>
  );
}

function LiverMesh({ selected, onClick, clippingPlanes }) {
  return (
    <mesh 
      position={[-0.9, 0.05, 0.25]} 
      rotation={[0.15, -0.3, 0.1]} 
      scale={[1.5, 0.9, 1.1]}
      onClick={(e) => { e.stopPropagation(); onClick(); }}
    >
      <sphereGeometry args={[0.92, 32, 24]} />
      <meshStandardMaterial 
        color="#f59e0b"
        roughness={0.4}
        emissive={selected ? "#f59e0b" : "#78350f"}
        emissiveIntensity={selected ? 0.8 : 0.15}
        transparent
        opacity={selected ? 0.9 : 0.65}
        clippingPlanes={clippingPlanes}
      />
    </mesh>
  );
}

function KidneysMesh({ selected, onClick, clippingPlanes }) {
  return (
    <group onClick={(e) => { e.stopPropagation(); onClick(); }}>
      {/* Right Kidney (slightly lower due to liver) */}
      <mesh position={[-1.2, -1.0, -0.55]} rotation={[0.2, 0.1, -0.2]} scale={[0.5, 0.85, 0.55]}>
        <sphereGeometry args={[0.65, 24, 24]} />
        <meshStandardMaterial 
          color="#10b981"
          roughness={0.35}
          emissive={selected ? "#10b981" : "#064e3b"}
          emissiveIntensity={selected ? 0.9 : 0.2}
          clippingPlanes={clippingPlanes}
        />
      </mesh>
      {/* Left Kidney */}
      <mesh position={[1.2, -0.75, -0.55]} rotation={[0.2, -0.1, 0.2]} scale={[0.5, 0.85, 0.55]}>
        <sphereGeometry args={[0.65, 24, 24]} />
        <meshStandardMaterial 
          color="#10b981"
          roughness={0.35}
          emissive={selected ? "#10b981" : "#064e3b"}
          emissiveIntensity={selected ? 0.9 : 0.2}
          clippingPlanes={clippingPlanes}
        />
      </mesh>
    </group>
  );
}

function SpleenMesh({ selected, onClick, clippingPlanes }) {
  return (
    <mesh 
      position={[1.35, 0.1, -0.3]} 
      rotation={[-0.2, 0.4, 0.1]} 
      scale={[0.6, 0.9, 0.5]}
      onClick={(e) => { e.stopPropagation(); onClick(); }}
    >
      <sphereGeometry args={[0.65, 24, 24]} />
      <meshStandardMaterial 
        color="#a855f7"
        roughness={0.4}
        emissive={selected ? "#a855f7" : "#581c87"}
        emissiveIntensity={selected ? 0.85 : 0.2}
        clippingPlanes={clippingPlanes}
      />
    </mesh>
  );
}

// ----------------------------------------------------------------------------
// DYNAMIC 3D CUTTING PLANE WIDGET
// ----------------------------------------------------------------------------
function CuttingPlaneIndicator({ plane, slicePos }) {
  const planeRef = useRef();

  // Position & rotation based on plane
  let position = [0, 0, 0];
  let rotation = [0, 0, 0];
  let size = [5.5, 4.5];

  if (plane === 'axial') {
    // Horizontal cut moving Y
    position = [0, slicePos * 4.5, 0];
    rotation = [Math.PI / 2, 0, 0];
    size = [5.4, 4.2];
  } else if (plane === 'coronal') {
    // Front-to-back cut moving Z
    position = [0, 0.6, slicePos * 2.2];
    rotation = [0, 0, 0];
    size = [5.4, 8.5];
  } else if (plane === 'sagittal') {
    // Side-to-side cut moving X
    position = [slicePos * 2.5, 0.6, 0];
    rotation = [0, Math.PI / 2, 0];
    size = [4.4, 8.5];
  }

  return (
    <group position={position} rotation={rotation} ref={planeRef}>
      {/* Semi-transparent laser plane */}
      <mesh>
        <planeGeometry args={size} />
        <meshBasicMaterial 
          color="#06b6d4" 
          transparent 
          opacity={0.22} 
          side={THREE.DoubleSide} 
          depthWrite={false}
        />
      </mesh>
      {/* Glowing Border Outline */}
      <lineSegments>
        <edgesGeometry args={[new THREE.PlaneGeometry(size[0], size[1])]} />
        <lineBasicMaterial color="#38bdf8" linewidth={2} />
      </lineSegments>
      {/* Corner crosshairs */}
      <mesh position={[size[0] / 2 - 0.2, size[1] / 2 - 0.2, 0.01]}>
        <ringGeometry args={[0.08, 0.12, 16]} />
        <meshBasicMaterial color="#38bdf8" />
      </mesh>
      <mesh position={[-size[0] / 2 + 0.2, -size[1] / 2 + 0.2, 0.01]}>
        <ringGeometry args={[0.08, 0.12, 16]} />
        <meshBasicMaterial color="#38bdf8" />
      </mesh>
    </group>
  );
}


// ============================================================================
// REAL-TIME PROCEDURAL CT SCAN GENERATOR & CANVAS ENGINE
// ============================================================================
function CTScanViewport({ 
  plane, 
  slicePos, 
  windowPreset, 
  customWidth, 
  customLevel, 
  showContours, 
  selectedOrgan,
  onProbeUpdate 
}) {
  const canvasRef = useRef(null);
  const [probeInfo, setProbeInfo] = useState(null);

  // Compute WW and WL
  const width = customWidth ?? windowPreset.width;
  const level = customLevel ?? windowPreset.level;

  // Windowing transfer function: maps Hounsfield Unit to 0-255 grayscale
  const huToGrayscale = useCallback((hu) => {
    const low = level - width / 2;
    const high = level + width / 2;
    if (hu <= low) return 0;
    if (hu >= high) return 255;
    return Math.round(((hu - low) / width) * 255);
  }, [width, level]);

  // Render cross-section CT image to Canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const W = canvas.width;
    const H = canvas.height;
    const imgData = ctx.createImageData(W, H);
    const data = imgData.data;

    const z = slicePos; // -1.0 to +1.0

    // Procedural Anatomical Simulation
    for (let py = 0; py < H; py++) {
      const ny = (py / H) * 2 - 1; // -1 (anterior/top) to +1 (posterior/bottom)
      for (let px = 0; px < W; px++) {
        const nx = (px / W) * 2 - 1; // -1 (right) to +1 (left)
        const idx = (py * W + px) * 4;

        let hu = -1000; // Air baseline

        if (plane === 'axial') {
          // --- AXIAL SLICE SIMULATION ---
          // Body perimeter (torso oval)
          const bodyDist = (nx * nx) / (0.75 * 0.75) + (ny * ny) / (0.58 * 0.58);
          if (bodyDist <= 1.0) {
            // Subcutaneous fat
            hu = -90;

            // Muscle wall
            if (bodyDist <= 0.92) {
              hu = 45;
            }

            // Bone: Spine (posterior center)
            const spineDist = Math.hypot(nx, ny - 0.42);
            if (spineDist < 0.16) {
              hu = 850; // Vertebral body cortical/trabecular bone
              if (spineDist < 0.05) hu = 15; // Spinal canal/fluid
            }

            // Bone: Ribs (distributed around perimeter)
            const ribAngle = Math.atan2(ny, nx);
            const ribRingDist = Math.abs(bodyDist - 0.88);
            if (ribRingDist < 0.04 && Math.sin(ribAngle * 8) > 0.4) {
              hu = 950;
            }

            // CHEST CAVITY (z > 0.0)
            if (z > 0.0) {
              const thoracicCavity = (nx * nx) / (0.65 * 0.65) + (ny * ny) / (0.48 * 0.48);
              if (thoracicCavity <= 0.85) {
                // Default mediastinal soft tissue
                hu = 35;

                // Lungs (Left & Right air spaces)
                const rightLungDist = Math.hypot(nx + 0.34, ny + 0.02);
                const leftLungDist = Math.hypot(nx - 0.34, ny + 0.02);
                const lungRadius = 0.28 * Math.min(1.2, Math.max(0.4, (z + 0.5)));

                if (rightLungDist < lungRadius) {
                  hu = -650 + Math.sin(nx * 40 + ny * 35) * 80; // Lung parenchyma with vessel dots
                }
                if (leftLungDist < lungRadius * 0.92) {
                  hu = -650 + Math.cos(nx * 40 - ny * 35) * 80;
                }

                // Heart & Great Vessels (z between 0.15 and 0.65)
                if (z >= 0.15 && z <= 0.65) {
                  const heartDist = Math.hypot(nx - 0.08, ny + 0.12);
                  if (heartDist < 0.24) {
                    hu = 160 + Math.sin(nx * 20) * 20; // Contrast-enhanced cardiac blood pool
                  }
                  // Descending Aorta (anterior-left of spine)
                  if (Math.hypot(nx - 0.07, ny - 0.26) < 0.07) {
                    hu = 220;
                  }
                }
              }
            } 
            // ABDOMINAL CAVITY (z <= 0.0)
            else {
              const abdominalCavity = (nx * nx) / (0.68 * 0.68) + (ny * ny) / (0.50 * 0.50);
              if (abdominalCavity <= 0.85) {
                hu = 35; // Default retroperitoneum/mesentery

                // Liver (Right lobe dominates: nx < 0.2, ny between -0.3 and 0.3)
                if (z > -0.55 && nx < 0.22 && nx > -0.65 && ny > -0.4 && ny < 0.3) {
                  const liverShape = Math.hypot(nx + 0.25, ny);
                  if (liverShape < 0.44) {
                    hu = 62 + Math.sin(nx * 30 + ny * 25) * 8; // Hepatic parenchyma
                  }
                }

                // Spleen (Left posterior: nx > 0.3, ny between 0.0 and 0.35)
                if (z > -0.4 && nx > 0.28 && nx < 0.62 && ny > -0.1 && ny < 0.32) {
                  if (Math.hypot(nx - 0.45, ny - 0.12) < 0.18) {
                    hu = 50;
                  }
                }

                // Kidneys (Bilateral retroperitoneal: z between -0.65 and -0.05)
                if (z >= -0.65 && z <= -0.05) {
                  const rKidneyDist = Math.hypot(nx + 0.32, ny - 0.22);
                  const lKidneyDist = Math.hypot(nx - 0.32, ny - 0.22);
                  if (rKidneyDist < 0.14 || lKidneyDist < 0.14) {
                    hu = 45; // Renal cortex
                    if (rKidneyDist < 0.06 || lKidneyDist < 0.06) hu = 180; // Contrast collecting system
                  }
                }
              }
            }
          }
        } else if (plane === 'coronal') {
          // --- CORONAL SLICE SIMULATION ---
          const bodyOutline = (nx * nx) / (0.75 * 0.75) + (ny * ny) / (0.9 * 0.9);
          if (bodyOutline <= 1.0) {
            hu = 40;
            // Spine down the center
            if (Math.abs(nx) < 0.12) hu = 800;
            // Lungs in upper halves
            if (ny < -0.1 && (Math.hypot(nx + 0.4, ny + 0.45) < 0.35 || Math.hypot(nx - 0.4, ny + 0.45) < 0.35)) {
              hu = -600;
            }
            // Liver below diaphragm on anatomical right
            if (ny >= -0.1 && ny <= 0.35 && nx < 0.15 && nx > -0.65) {
              hu = 65;
            }
            // Kidneys
            if (ny > 0.1 && ny < 0.5 && (Math.hypot(nx + 0.35, ny - 0.3) < 0.14 || Math.hypot(nx - 0.35, ny - 0.3) < 0.14)) {
              hu = 48;
            }
          }
        } else {
          // --- SAGITTAL SLICE SIMULATION ---
          const bodyOutline = (nx * nx) / (0.55 * 0.55) + (ny * ny) / (0.9 * 0.9);
          if (bodyOutline <= 1.0) {
            hu = 40;
            // Vertebral column posterior
            if (nx > 0.22 && nx < 0.4) hu = 850;
            // Sternum anterior
            if (nx < -0.35 && nx > -0.45 && ny < 0.2) hu = 900;
            // Lung cavity
            if (ny < 0.1 && Math.hypot(nx + 0.05, ny + 0.35) < 0.38) hu = -600;
            // Heart anterior
            if (ny < 0.2 && ny > -0.1 && nx < 0.1 && nx > -0.25) hu = 150;
            // Liver
            if (ny >= 0.05 && ny <= 0.45 && nx < 0.2) hu = 62;
          }
        }

        // Apply Window/Level transfer function
        const gray = huToGrayscale(hu);
        data[idx] = gray;
        data[idx + 1] = gray;
        data[idx + 2] = gray;
        data[idx + 3] = 255;
      }
    }

    ctx.putImageData(imgData, 0, 0);

    // --- DRAW ORGAN CONTOURS OVERLAY IF ENABLED ---
    if (showContours) {
      drawContours(ctx, W, H, plane, z, selectedOrgan);
    }

  }, [plane, slicePos, huToGrayscale, showContours, selectedOrgan]);

  // Helper to draw clean anatomical contours
  const drawContours = (ctx, W, H, plane, z, selectedOrgan) => {
    ctx.lineWidth = 2.5;

    // Helper to stroke colored ring
    const strokeShape = (organId, color, drawFn) => {
      const isSelected = selectedOrgan === organId;
      ctx.save();
      ctx.strokeStyle = color;
      ctx.shadowColor = color;
      ctx.shadowBlur = isSelected ? 16 : 4;
      ctx.lineWidth = isSelected ? 3.5 : 1.8;
      ctx.setLineDash(isSelected ? [] : [4, 4]);
      drawFn();
      ctx.stroke();
      ctx.restore();
    };

    if (plane === 'axial') {
      // Lungs Contour
      if (z > 0.05) {
        strokeShape('lungs', '#06b6d4', () => {
          ctx.beginPath();
          ctx.ellipse(W * 0.33, H * 0.48, W * 0.14, H * 0.18, 0, 0, Math.PI * 2);
          ctx.ellipse(W * 0.67, H * 0.48, W * 0.14, H * 0.18, 0, 0, Math.PI * 2);
        });
      }
      // Heart Contour
      if (z >= 0.15 && z <= 0.65) {
        strokeShape('heart', '#f43f5e', () => {
          ctx.beginPath();
          ctx.ellipse(W * 0.54, H * 0.44, W * 0.12, H * 0.14, -0.2, 0, Math.PI * 2);
        });
      }
      // Liver Contour
      if (z > -0.55 && z <= 0.25) {
        strokeShape('liver', '#f59e0b', () => {
          ctx.beginPath();
          ctx.ellipse(W * 0.36, H * 0.48, W * 0.18, H * 0.19, 0.2, 0, Math.PI * 2);
        });
      }
      // Kidneys Contour
      if (z >= -0.65 && z <= -0.05) {
        strokeShape('kidneys', '#10b981', () => {
          ctx.beginPath();
          ctx.ellipse(W * 0.34, H * 0.61, W * 0.07, H * 0.09, 0.15, 0, Math.PI * 2);
          ctx.ellipse(W * 0.66, H * 0.61, W * 0.07, H * 0.09, -0.15, 0, Math.PI * 2);
        });
      }
      // Spine Contour
      strokeShape('spine', '#e2e8f0', () => {
        ctx.beginPath();
        ctx.ellipse(W * 0.50, H * 0.71, W * 0.08, H * 0.08, 0, 0, Math.PI * 2);
      });
    }
  };

  // Live Mouse Pixel Probe Handler
  const handleMouseMove = (e) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = Math.floor((e.clientX - rect.left) * (canvas.width / rect.width));
    const y = Math.floor((e.clientY - rect.top) * (canvas.height / rect.height));

    const nx = (x / canvas.width) * 2 - 1;
    const ny = (y / canvas.height) * 2 - 1;

    // Approximate tissue & HU
    let tissue = 'Air';
    let hu = -1000;

    const bodyDist = (nx * nx) / (0.75 * 0.75) + (ny * ny) / (0.58 * 0.58);
    if (bodyDist <= 1.0) {
      tissue = 'Subcutaneous Fat';
      hu = -95;
      if (bodyDist <= 0.92) { tissue = 'Muscle / Soft Tissue'; hu = 42; }
      if (Math.hypot(nx, ny - 0.42) < 0.16) { tissue = 'Spine (Vertebra)'; hu = 860; }
      if (slicePos > 0.0) {
        if (Math.hypot(nx + 0.34, ny + 0.02) < 0.28 || Math.hypot(nx - 0.34, ny + 0.02) < 0.26) {
          tissue = 'Lung Parenchyma';
          hu = -620;
        }
        if (slicePos >= 0.15 && slicePos <= 0.65 && Math.hypot(nx - 0.08, ny + 0.12) < 0.24) {
          tissue = 'Cardiac Muscle / Blood';
          hu = 175;
        }
      } else {
        if (nx < 0.22 && nx > -0.65 && ny > -0.4 && ny < 0.3 && Math.hypot(nx + 0.25, ny) < 0.44) {
          tissue = 'Hepatic Parenchyma (Liver)';
          hu = 64;
        }
        if (Math.hypot(nx + 0.32, ny - 0.22) < 0.14 || Math.hypot(nx - 0.32, ny - 0.22) < 0.14) {
          tissue = 'Renal Parenchyma (Kidney)';
          hu = 48;
        }
      }
    }

    const info = { x, y, hu, tissue };
    setProbeInfo(info);
    if (onProbeUpdate) onProbeUpdate(info);
  };

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <canvas 
        ref={canvasRef} 
        width={420} 
        height={420} 
        onMouseMove={handleMouseMove}
        onMouseLeave={() => setProbeInfo(null)}
        style={{ 
          width: '100%', 
          maxWidth: '440px', 
          aspectRatio: '1/1', 
          borderRadius: '16px', 
          border: '1px solid rgba(56, 189, 248, 0.3)',
          boxShadow: '0 0 40px rgba(0,0,0,0.8), inset 0 0 20px rgba(0,0,0,0.9)',
          cursor: 'crosshair',
          background: '#000000'
        }}
      />

      {/* Crosshairs & Scale Grid overlay */}
      <div style={{ position: 'absolute', inset: '16px', pointerEvents: 'none', border: '1px dashed rgba(255,255,255,0.08)' }}>
        <span style={{ position: 'absolute', top: 4, left: 8, fontSize: '10px', color: '#64748b', fontWeight: 'bold' }}>ANTERIOR [A]</span>
        <span style={{ position: 'absolute', bottom: 4, left: 8, fontSize: '10px', color: '#64748b', fontWeight: 'bold' }}>POSTERIOR [P]</span>
        <span style={{ position: 'absolute', top: '50%', left: 4, transform: 'translateY(-50%)', fontSize: '10px', color: '#64748b', fontWeight: 'bold' }}>R</span>
        <span style={{ position: 'absolute', top: '50%', right: 4, transform: 'translateY(-50%)', fontSize: '10px', color: '#64748b', fontWeight: 'bold' }}>L</span>
      </div>

      {/* Live Hounsfield Inspector Tooltip */}
      {probeInfo && (
        <div style={{
          position: 'absolute',
          bottom: '24px',
          left: '24px',
          background: 'rgba(15, 23, 42, 0.92)',
          border: '1px solid #38bdf8',
          borderRadius: '8px',
          padding: '6px 12px',
          fontSize: '11px',
          color: '#e2e8f0',
          backdropFilter: 'blur(8px)',
          boxShadow: '0 4px 15px rgba(0,0,0,0.6)',
          pointerEvents: 'none',
          display: 'flex',
          gap: '12px',
          alignItems: 'center'
        }}>
          <div><span style={{ color: '#94a3b8' }}>XY:</span> {probeInfo.x}, {probeInfo.y}</div>
          <div style={{ width: '1px', height: '14px', background: 'rgba(255,255,255,0.2)' }} />
          <div><span style={{ color: '#38bdf8', fontWeight: 'bold' }}>HU:</span> {probeInfo.hu}</div>
          <div style={{ width: '1px', height: '14px', background: 'rgba(255,255,255,0.2)' }} />
          <div style={{ color: '#a7f3d0', fontWeight: '600' }}>{probeInfo.tissue}</div>
        </div>
      )}
    </div>
  );
}


// ============================================================================
// MAIN SYNCHRONIZED CT VIEWER COMPONENT
// ============================================================================
export default function SynchronizedCTViewer({ activePatient, patients = {}, onSelectPatient }) {
  // Navigation & Slicing State
  const [plane, setPlane] = useState('axial'); // 'axial' | 'coronal' | 'sagittal'
  const [sliceIndex, setSliceIndex] = useState(60); // 0 to 120
  const maxSlices = 120;
  const slicePos = useMemo(() => (sliceIndex / maxSlices) * 2 - 1, [sliceIndex, maxSlices]); // -1.0 to 1.0

  // Mobile Responsiveness & View Selection
  const [mobileTab, setMobileTab] = useState('3d'); // '3d' | '2d'
  const [isPatientDrawerOpen, setIsPatientDrawerOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(() => typeof window !== 'undefined' ? window.innerWidth <= 768 : false);

  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth <= 768);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const patientList = useMemo(() => {
    if (patients && Object.keys(patients).length > 0) {
      return Object.values(patients);
    }
    if (activePatient) {
      return [activePatient];
    }
    return [
      { id: 'P001', name: 'David Murphy', mrn: 'PACS-2024-X89', reason: 'Asthma Follow-up', dob: '1984-06-12' },
      { id: 'P002', name: 'Elena Rostova', mrn: 'PACS-2024-K41', reason: 'Right Knee ACL', dob: '1992-11-03' },
      { id: 'P003', name: 'Marcus Vance', mrn: 'PACS-2024-N12', reason: 'Migraine Assessment', dob: '1978-04-25' }
    ];
  }, [patients, activePatient]);

  // Radiology Contrast State
  const [windowPresetKey, setWindowPresetKey] = useState('softTissue');
  const [customWidth, setCustomWidth] = useState(null);
  const [customLevel, setCustomLevel] = useState(null);

  // Highlighting & Overlays
  const [selectedOrgan, setSelectedOrgan] = useState('lungs');
  const [showContours, setShowContours] = useState(true);
  const [enableClipping, setEnableClipping] = useState(false);

  // Cine Loop (Auto-play slices)
  const [isPlaying, setIsPlaying] = useState(false);
  const [cineFps, setCineFps] = useState(15);

  // Cine animation loop
  useEffect(() => {
    if (!isPlaying) return;
    const interval = setInterval(() => {
      setSliceIndex((prev) => {
        if (prev >= maxSlices) return 0;
        return prev + 1;
      });
    }, 1000 / cineFps);
    return () => clearInterval(interval);
  }, [isPlaying, cineFps, maxSlices]);

  const activePreset = WINDOW_PRESETS[windowPresetKey];
  const currentWidth = customWidth ?? activePreset.width;
  const currentLevel = customLevel ?? activePreset.level;

  // Real-world physical millimeter mapping (approx 3mm slice thickness)
  const mmDepth = ((sliceIndex - maxSlices / 2) * 3.2).toFixed(1);

  return (
    <div style={{ 
      display: 'flex', 
      flexDirection: 'column', 
      height: '100%', 
      gap: isMobile ? '10px' : '16px', 
      background: '#090d16',
      borderRadius: isMobile ? '16px' : '24px', 
      padding: isMobile ? '12px' : '20px', 
      color: '#f8fafc',
      fontFamily: 'Inter, system-ui, sans-serif',
      boxShadow: 'inset 0 0 50px rgba(0,0,0,0.8)',
      position: 'relative'
    }}>
      
      {/* ─── TOP METADATA & PACS HEADER ───────────────────────────────────── */}
      {isMobile ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {/* Row 1: Patient Menu Selector & 3D Cut Toggle */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px' }}>
            <button
              onClick={() => setIsPatientDrawerOpen(true)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                background: 'rgba(15, 23, 42, 0.95)',
                border: '1px solid rgba(56, 189, 248, 0.4)',
                padding: '8px 12px',
                borderRadius: '12px',
                color: '#ffffff',
                fontSize: '13px',
                fontWeight: '700',
                cursor: 'pointer',
                boxShadow: '0 2px 10px rgba(0,0,0,0.4)',
                flex: 1,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap'
              }}
            >
              <Menu size={16} color="#38bdf8" style={{ flexShrink: 0 }} />
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1, textAlign: 'left' }}>
                {activePatient?.name || 'Select Patient'}
              </span>
              <span style={{ fontSize: '10px', color: '#94a3b8', background: 'rgba(255,255,255,0.08)', padding: '2px 6px', borderRadius: '4px', flexShrink: 0 }}>
                MRN: {activePatient?.mrn || 'PACS'}
              </span>
              <ChevronDown size={14} color="#94a3b8" style={{ flexShrink: 0 }} />
            </button>

            {/* 3D Cut Toggle */}
            <button
              onClick={() => setEnableClipping(!enableClipping)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '5px',
                padding: '8px 12px',
                borderRadius: '12px',
                fontSize: '11px',
                fontWeight: '700',
                cursor: 'pointer',
                border: `1px solid ${enableClipping ? '#38bdf8' : 'rgba(255,255,255,0.15)'}`,
                background: enableClipping ? 'rgba(56, 189, 248, 0.25)' : 'rgba(15, 23, 42, 0.8)',
                color: enableClipping ? '#38bdf8' : '#94a3b8',
                flexShrink: 0
              }}
            >
              <Zap size={13} /> {enableClipping ? 'Cut: ON' : 'Cut: OFF'}
            </button>
          </div>

          {/* Row 2: View Switcher (Segmented Control between 3D Twin & 2D CT) */}
          <div style={{
            display: 'flex',
            background: 'rgba(0, 0, 0, 0.65)',
            padding: '3px',
            borderRadius: '12px',
            border: '1px solid rgba(56, 189, 248, 0.2)'
          }}>
            <button
              onClick={() => setMobileTab('3d')}
              style={{
                flex: 1,
                padding: '7px 10px',
                borderRadius: '9px',
                fontSize: '12px',
                fontWeight: '700',
                border: 'none',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '6px',
                background: mobileTab === '3d' ? 'linear-gradient(135deg, #0284c7, #06b6d4)' : 'transparent',
                color: mobileTab === '3d' ? '#ffffff' : '#94a3b8',
                boxShadow: mobileTab === '3d' ? '0 2px 8px rgba(6, 182, 212, 0.3)' : 'none',
                transition: 'all 0.2s'
              }}
            >
              <Sparkles size={14} /> 3D Digital Twin
            </button>
            <button
              onClick={() => setMobileTab('2d')}
              style={{
                flex: 1,
                padding: '7px 10px',
                borderRadius: '9px',
                fontSize: '12px',
                fontWeight: '700',
                border: 'none',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '6px',
                background: mobileTab === '2d' ? 'linear-gradient(135deg, #0284c7, #06b6d4)' : 'transparent',
                color: mobileTab === '2d' ? '#ffffff' : '#94a3b8',
                boxShadow: mobileTab === '2d' ? '0 2px 8px rgba(6, 182, 212, 0.3)' : 'none',
                transition: 'all 0.2s'
              }}
            >
              <Crosshair size={14} /> 2D CT MPR Scan
            </button>
          </div>

          {/* Row 3: Orthogonal Plane Switcher */}
          <div style={{ display: 'flex', gap: '6px' }}>
            {[
              { id: 'axial', label: 'Axial' },
              { id: 'coronal', label: 'Coronal' },
              { id: 'sagittal', label: 'Sagittal' }
            ].map(p => (
              <button
                key={p.id}
                onClick={() => setPlane(p.id)}
                style={{
                  flex: 1,
                  padding: '5px 8px',
                  borderRadius: '8px',
                  fontSize: '11px',
                  fontWeight: '700',
                  cursor: 'pointer',
                  border: `1px solid ${plane === p.id ? '#0284c7' : 'rgba(255,255,255,0.08)'}`,
                  background: plane === p.id ? 'rgba(2, 132, 199, 0.3)' : 'rgba(255,255,255,0.03)',
                  color: plane === p.id ? '#38bdf8' : '#94a3b8',
                  transition: 'all 0.15s'
                }}
              >
                {p.label}
              </button>
            ))}
          </div>
        </div>
      ) : (
        <div style={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          alignItems: 'center', 
          padding: '12px 20px', 
          background: 'rgba(15, 23, 42, 0.75)', 
          border: '1px solid rgba(56, 189, 248, 0.25)', 
          borderRadius: '16px',
          backdropFilter: 'blur(12px)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <div style={{ 
              background: 'linear-gradient(135deg, #0284c7, #06b6d4)', 
              padding: '8px 12px', 
              borderRadius: '10px', 
              fontWeight: '800', 
              fontSize: '13px',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}>
              <Sparkles size={16} /> SYNC 3D • CT MPR
            </div>
            <div>
              <div style={{ fontSize: '15px', fontWeight: '800', color: '#ffffff' }}>
                {activePatient?.name || 'Diagnostic CT Torso Volume'}
              </div>
              <div style={{ fontSize: '12px', color: '#94a3b8' }}>
                MRN: {activePatient?.mrn || 'PACS-2024-X89'} • Slice: {sliceIndex}/{maxSlices} ({mmDepth} mm) • FOV: 350mm
              </div>
            </div>
          </div>

          {/* Orthogonal Plane Switcher */}
          <div style={{ display: 'flex', background: 'rgba(0,0,0,0.5)', padding: '4px', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.1)' }}>
            {[
              { id: 'axial', label: 'Axial (Transverse)' },
              { id: 'coronal', label: 'Coronal (Front)' },
              { id: 'sagittal', label: 'Sagittal (Side)' }
            ].map(p => (
              <button
                key={p.id}
                onClick={() => setPlane(p.id)}
                style={{
                  padding: '6px 14px',
                  borderRadius: '8px',
                  fontSize: '12px',
                  fontWeight: '700',
                  cursor: 'pointer',
                  border: 'none',
                  background: plane === p.id ? '#0284c7' : 'transparent',
                  color: plane === p.id ? '#ffffff' : '#94a3b8',
                  transition: 'all 0.2s'
                }}
              >
                {p.label}
              </button>
            ))}
          </div>

          {/* 3D Model Slicing Toggle */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <button
              onClick={() => setEnableClipping(!enableClipping)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                padding: '8px 14px',
                borderRadius: '10px',
                fontSize: '12px',
                fontWeight: '700',
                cursor: 'pointer',
                border: `1px solid ${enableClipping ? '#38bdf8' : 'rgba(255,255,255,0.15)'}`,
                background: enableClipping ? 'rgba(56, 189, 248, 0.2)' : 'rgba(255,255,255,0.05)',
                color: enableClipping ? '#38bdf8' : '#cbd5e1'
              }}
            >
              <Zap size={14} /> {enableClipping ? '3D Cut: ACTIVE' : '3D Cut: MASKED'}
            </button>
          </div>
        </div>
      )}

      {/* ─── WORKSPACE (MOBILE: SINGLE CENTERED VIEWPORT | DESKTOP: DUAL VIEWPORT) ── */}
      {isMobile ? (
        <div style={{ 
          width: '100%', 
          height: '400px', 
          minHeight: '380px',
          position: 'relative', 
          borderRadius: '20px', 
          overflow: 'hidden',
          boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center'
        }}>
          {mobileTab === '3d' ? (
            <div style={{ 
              width: '100%', 
              height: '100%', 
              position: 'relative', 
              background: 'radial-gradient(circle at center, #0f172a 0%, #020617 100%)', 
              borderRadius: '20px', 
              border: '1px solid rgba(56, 189, 248, 0.3)',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column'
            }}>
              {/* Mobile Viewport Badges */}
              <div style={{ position: 'absolute', top: 10, left: 12, zIndex: 10, display: 'flex', alignItems: 'center', gap: '6px', pointerEvents: 'none' }}>
                <Compass size={14} color="#38bdf8" />
                <span style={{ fontSize: '10px', fontWeight: '800', letterSpacing: '0.5px', color: '#38bdf8', textTransform: 'uppercase' }}>
                  3D Holographic Twin
                </span>
              </div>
              <div style={{ position: 'absolute', top: 10, right: 12, zIndex: 10, fontSize: '10px', fontWeight: '700', color: '#94a3b8', background: 'rgba(0,0,0,0.6)', padding: '2px 8px', borderRadius: '6px', pointerEvents: 'none' }}>
                Z: {mmDepth} mm
              </div>

              <div style={{ position: 'absolute', bottom: 8, left: 12, right: 12, zIndex: 10, fontSize: '10px', color: '#64748b', textAlign: 'center', pointerEvents: 'none' }}>
                Drag to Rotate • Pinch to Zoom
              </div>

              {/* Canvas Render */}
              <Canvas camera={{ position: [0, 1.5, 11], fov: 42 }} style={{ touchAction: 'none' }}>
                <AnatomicalScene 
                  plane={plane} 
                  slicePos={slicePos} 
                  selectedOrgan={selectedOrgan}
                  onSelectOrgan={setSelectedOrgan}
                  enableClipping={enableClipping}
                  showContours={showContours}
                />
              </Canvas>
            </div>
          ) : (
            <div style={{ 
              width: '100%', 
              height: '100%', 
              position: 'relative', 
              background: '#05070d', 
              borderRadius: '20px', 
              border: '1px solid rgba(56, 189, 248, 0.3)',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '12px'
            }}>
              <div style={{ position: 'absolute', top: 10, left: 12, right: 12, zIndex: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'center', pointerEvents: 'none' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Crosshair size={14} color="#38bdf8" />
                  <span style={{ fontSize: '10px', fontWeight: '800', letterSpacing: '0.5px', color: '#38bdf8', textTransform: 'uppercase' }}>
                    2D CT MPR Cross-Section
                  </span>
                </div>
                <div style={{ fontSize: '10px', fontWeight: 'bold', color: '#94a3b8', background: 'rgba(0,0,0,0.6)', padding: '2px 6px', borderRadius: '6px' }}>
                  W:{currentWidth} L:{currentLevel}
                </div>
              </div>

              <CTScanViewport 
                plane={plane}
                slicePos={slicePos}
                windowPreset={activePreset}
                customWidth={customWidth}
                customLevel={customLevel}
                showContours={showContours}
                selectedOrgan={selectedOrgan}
              />
            </div>
          )}
        </div>
      ) : (
        <div style={{ display: 'flex', flex: 1, gap: '16px', minHeight: 0 }}>
          {/* VIEWPORT 1: Three.js 3D Interactive Anatomy */}
          <div style={{ 
            flex: 1.1, 
            position: 'relative', 
            background: 'radial-gradient(circle at center, #0f172a 0%, #020617 100%)', 
            borderRadius: '20px', 
            border: '1px solid rgba(56, 189, 248, 0.2)',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column'
          }}>
            {/* Viewport Header */}
            <div style={{ position: 'absolute', top: 12, left: 16, zIndex: 10, display: 'flex', alignItems: 'center', gap: '8px', pointerEvents: 'none' }}>
              <Compass size={16} color="#38bdf8" />
              <span style={{ fontSize: '11px', fontWeight: '800', letterSpacing: '1px', color: '#38bdf8', textTransform: 'uppercase' }}>
                3D Holographic Anatomy (Three.js WebGL)
              </span>
            </div>

            <div style={{ position: 'absolute', bottom: 12, left: 16, zIndex: 10, fontSize: '11px', color: '#64748b', pointerEvents: 'none' }}>
              Left Click: Rotate • Right Click: Pan • Scroll: Zoom
            </div>

            {/* Canvas Render */}
            <Canvas camera={{ position: [0, 1.5, 11], fov: 42 }}>
              <AnatomicalScene 
                plane={plane} 
                slicePos={slicePos} 
                selectedOrgan={selectedOrgan}
                onSelectOrgan={setSelectedOrgan}
                enableClipping={enableClipping}
                showContours={showContours}
              />
            </Canvas>
          </div>

          {/* VIEWPORT 2: Synchronized 2D CT Cross-Section */}
          <div style={{ 
            flex: 1, 
            position: 'relative', 
            background: '#05070d', 
            borderRadius: '20px', 
            border: '1px solid rgba(56, 189, 248, 0.2)',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '16px'
          }}>
            {/* Viewport Header */}
            <div style={{ position: 'absolute', top: 12, left: 16, right: 16, zIndex: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'center', pointerEvents: 'none' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Crosshair size={16} color="#38bdf8" />
                <span style={{ fontSize: '11px', fontWeight: '800', letterSpacing: '1px', color: '#38bdf8', textTransform: 'uppercase' }}>
                  Synchronized 2D CT Cross-Section
                </span>
              </div>
              <div style={{ fontSize: '11px', fontWeight: 'bold', color: '#94a3b8' }}>
                W: {currentWidth} L: {currentLevel} HU
              </div>
            </div>

            {/* Canvas Component */}
            <CTScanViewport 
              plane={plane}
              slicePos={slicePos}
              windowPreset={activePreset}
              customWidth={customWidth}
              customLevel={customLevel}
              showContours={showContours}
              selectedOrgan={selectedOrgan}
            />
          </div>
        </div>
      )}

      {/* ─── BOTTOM CONTROL DECK: SLICE SCRUBBER & RADIOLOGY TOOLS ───────── */}
      <div style={{ 
        display: 'flex', 
        flexDirection: 'column', 
        gap: isMobile ? '8px' : '12px', 
        padding: isMobile ? '12px 14px' : '16px 20px', 
        background: 'rgba(15, 23, 42, 0.85)', 
        border: '1px solid rgba(56, 189, 248, 0.25)', 
        borderRadius: '16px',
        backdropFilter: 'blur(12px)'
      }}>
        
        {/* Slice Scrubber & Cine Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: isMobile ? '8px' : '16px' }}>
          {/* Play / Pause Cine Loop */}
          <button
            onClick={() => setIsPlaying(!isPlaying)}
            style={{
              width: isMobile ? '36px' : '42px',
              height: isMobile ? '36px' : '42px',
              borderRadius: '50%',
              background: isPlaying ? '#ef4444' : '#0284c7',
              border: 'none',
              color: 'white',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              boxShadow: isPlaying ? '0 0 12px #ef4444' : '0 0 12px #0284c7',
              transition: 'all 0.2s',
              flexShrink: 0
            }}
            title={isPlaying ? 'Pause Cine Loop' : 'Play Cine Loop'}
          >
            {isPlaying ? <Pause size={isMobile ? 15 : 18} /> : <Play size={isMobile ? 15 : 18} style={{ marginLeft: 2 }} />}
          </button>

          {/* FPS Speed Toggle */}
          <button
            onClick={() => setCineFps(prev => prev === 10 ? 20 : (prev === 20 ? 30 : 10))}
            style={{
              padding: isMobile ? '4px 8px' : '6px 10px',
              borderRadius: '8px',
              background: 'rgba(255,255,255,0.08)',
              border: '1px solid rgba(255,255,255,0.15)',
              color: '#38bdf8',
              fontSize: '11px',
              fontWeight: 'bold',
              cursor: 'pointer',
              flexShrink: 0
            }}
            title="Cine Speed"
          >
            {cineFps} FPS
          </button>

          {/* Slider */}
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '3px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: isMobile ? '10px' : '11px', color: '#94a3b8', fontWeight: 'bold' }}>
              <span className="mobile-hide">SUPERIOR</span>
              <span style={{ color: '#38bdf8', margin: isMobile ? '0 auto' : '0' }}>Z: {mmDepth} mm ({sliceIndex}/{maxSlices})</span>
              <span className="mobile-hide">INFERIOR</span>
            </div>
            <input 
              type="range"
              min="0"
              max={maxSlices}
              value={sliceIndex}
              onChange={(e) => setSliceIndex(parseInt(e.target.value))}
              style={{
                width: '100%',
                accentColor: '#38bdf8',
                cursor: 'pointer',
                height: '6px',
                borderRadius: '3px'
              }}
            />
          </div>

          {/* Reset Slice Button */}
          <button
            onClick={() => setSliceIndex(Math.floor(maxSlices / 2))}
            style={{
              background: 'transparent',
              border: 'none',
              color: '#94a3b8',
              cursor: 'pointer',
              padding: '4px',
              flexShrink: 0
            }}
            title="Reset to Mid-slice"
          >
            <RotateCcw size={16} />
          </button>
        </div>

        {/* Presets & Organ Toggles */}
        <div style={{ 
          display: 'flex', 
          flexDirection: isMobile ? 'column' : 'row',
          justifyContent: 'space-between', 
          alignItems: isMobile ? 'stretch' : 'center', 
          gap: isMobile ? '8px' : '12px',
          paddingTop: '8px', 
          borderTop: '1px solid rgba(255,255,255,0.08)' 
        }}>
          
          {/* WW/WL Windowing Presets */}
          <div style={{ 
            display: 'flex', 
            alignItems: 'center', 
            gap: '6px',
            overflowX: 'auto',
            paddingBottom: isMobile ? '2px' : '0',
            scrollbarWidth: 'none'
          }}>
            <span style={{ fontSize: '10px', fontWeight: 'bold', color: '#64748b', textTransform: 'uppercase', flexShrink: 0 }}>Window:</span>
            {Object.entries(WINDOW_PRESETS).map(([key, val]) => (
              <button
                key={key}
                onClick={() => {
                  setWindowPresetKey(key);
                  setCustomWidth(null);
                  setCustomLevel(null);
                }}
                style={{
                  padding: '4px 9px',
                  borderRadius: '6px',
                  fontSize: '11px',
                  fontWeight: '700',
                  cursor: 'pointer',
                  whiteSpace: 'nowrap',
                  flexShrink: 0,
                  border: `1px solid ${windowPresetKey === key ? '#38bdf8' : 'rgba(255,255,255,0.1)'}`,
                  background: windowPresetKey === key ? 'rgba(56, 189, 248, 0.2)' : 'rgba(255,255,255,0.04)',
                  color: windowPresetKey === key ? '#38bdf8' : '#cbd5e1'
                }}
              >
                {val.name}
              </button>
            ))}
          </div>

          {/* Organ Segmentation Spotlight Buttons & Contours */}
          <div style={{ 
            display: 'flex', 
            alignItems: 'center', 
            gap: '6px',
            overflowX: 'auto',
            paddingBottom: isMobile ? '2px' : '0',
            scrollbarWidth: 'none'
          }}>
            <span style={{ fontSize: '10px', fontWeight: 'bold', color: '#64748b', textTransform: 'uppercase', flexShrink: 0 }}>Highlight:</span>
            {ORGANS.map((organ) => {
              const active = selectedOrgan === organ.id;
              return (
                <button
                  key={organ.id}
                  onClick={() => setSelectedOrgan(active ? null : organ.id)}
                  style={{
                    padding: '3px 8px',
                    borderRadius: '20px',
                    fontSize: '11px',
                    fontWeight: '700',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    whiteSpace: 'nowrap',
                    flexShrink: 0,
                    border: `1px solid ${active ? organ.color : 'rgba(255,255,255,0.1)'}`,
                    background: active ? `${organ.color}25` : 'transparent',
                    color: active ? organ.color : '#94a3b8'
                  }}
                >
                  <span>{organ.icon}</span>
                  {organ.name}
                </button>
              );
            })}

            {/* Contour Overlay Toggle */}
            <button
              onClick={() => setShowContours(!showContours)}
              style={{
                padding: '4px 10px',
                borderRadius: '8px',
                fontSize: '11px',
                fontWeight: '700',
                cursor: 'pointer',
                whiteSpace: 'nowrap',
                flexShrink: 0,
                border: `1px solid ${showContours ? '#10b981' : 'rgba(255,255,255,0.1)'}`,
                background: showContours ? 'rgba(16, 185, 129, 0.15)' : 'transparent',
                color: showContours ? '#10b981' : '#64748b',
                display: 'flex',
                alignItems: 'center',
                gap: '5px'
              }}
            >
              {showContours ? <Eye size={12} /> : <EyeOff size={12} />}
              Contours
            </button>
          </div>
        </div>

      </div>

      {/* ─── PATIENT SELECTION DRAWER MODAL ─────────────────────────────── */}
      {isPatientDrawerOpen && (
        <div 
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.75)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            zIndex: 9999,
            display: 'flex',
            alignItems: 'flex-end',
            justifyContent: 'center',
            animation: 'fadeIn 0.2s ease-out'
          }}
          onClick={() => setIsPatientDrawerOpen(false)}
        >
          <div 
            style={{
              background: '#0f172a',
              border: '1px solid rgba(56, 189, 248, 0.3)',
              borderTopLeftRadius: '24px',
              borderTopRightRadius: '24px',
              width: '100%',
              maxWidth: '520px',
              maxHeight: '80vh',
              overflowY: 'auto',
              padding: '20px 18px 36px 18px',
              boxShadow: '0 -10px 40px rgba(0,0,0,0.8)',
              display: 'flex',
              flexDirection: 'column',
              gap: '16px'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Drawer Drag Bar */}
            <div style={{ width: '40px', height: '4px', background: '#334155', borderRadius: '2px', alignSelf: 'center', marginBottom: '4px' }} />

            {/* Drawer Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <div style={{ fontSize: '17px', fontWeight: '800', color: '#f8fafc', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Users size={18} color="#38bdf8" /> Select Patient Twin
                </div>
                <div style={{ fontSize: '12px', color: '#94a3b8' }}>
                  Choose a patient to load their 3D digital twin
                </div>
              </div>
              <button 
                onClick={() => setIsPatientDrawerOpen(false)}
                style={{
                  background: 'rgba(255,255,255,0.08)',
                  border: 'none',
                  borderRadius: '50%',
                  width: '32px',
                  height: '32px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#cbd5e1',
                  cursor: 'pointer'
                }}
              >
                <X size={18} />
              </button>
            </div>

            {/* Patient Cards List */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {patientList.map((p) => {
                const isSelected = activePatient?.id === p.id || activePatient?.name === p.name;
                return (
                  <div 
                    key={p.id || p.name}
                    onClick={() => {
                      if (onSelectPatient) onSelectPatient(p.id);
                      setIsPatientDrawerOpen(false);
                    }}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '12px 14px',
                      borderRadius: '14px',
                      background: isSelected ? 'rgba(56, 189, 248, 0.15)' : 'rgba(30, 41, 59, 0.6)',
                      border: isSelected ? '1px solid #38bdf8' : '1px solid rgba(255, 255, 255, 0.08)',
                      cursor: 'pointer',
                      transition: 'all 0.15s'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      <div style={{
                        width: '38px',
                        height: '38px',
                        borderRadius: '50%',
                        background: isSelected ? '#0284c7' : '#334155',
                        color: '#ffffff',
                        fontWeight: '800',
                        fontSize: '15px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        {p.name ? p.name.charAt(0) : 'P'}
                      </div>
                      <div>
                        <div style={{ fontSize: '14px', fontWeight: '700', color: '#ffffff' }}>
                          {p.name}
                        </div>
                        <div style={{ fontSize: '11px', color: '#94a3b8' }}>
                          MRN: {p.mrn || p.id} {p.reason ? `• ${p.reason}` : ''}
                        </div>
                      </div>
                    </div>

                    {isSelected && (
                      <div style={{
                        background: '#0284c7',
                        color: 'white',
                        borderRadius: '50%',
                        width: '24px',
                        height: '24px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center'
                      }}>
                        <Check size={14} />
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
