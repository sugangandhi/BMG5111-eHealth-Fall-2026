import React, { useRef, useMemo, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Stars, Html } from '@react-three/drei';
import * as THREE from 'three';

const PointCloudHuman = () => {
  const groupRef = useRef();

  // Generate an array of points forming a glowing medical skeleton
  const particles = useMemo(() => {
    const pts = [];

    // Helper to add points
    const addPt = (x, y, z, color) => pts.push({ p: [x, y, z], color });
    
    const CYAN = "#06b6d4";
    const BLUE = "#3b82f6";

    // 1. Head (Sphere)
    for(let i=0; i<150; i++) {
        const theta = Math.random() * Math.PI * 2;
        const phi = Math.acos((Math.random() * 2) - 1);
        const r = 1.2;
        addPt(r * Math.sin(phi) * Math.cos(theta), (r * Math.cos(phi)) + 7, r * Math.sin(phi) * Math.sin(theta), CYAN);
    }

    // 2. Spine (Dense vertical column)
    for(let i=0; i<200; i++) {
        const y = (Math.random() * 8) - 2; // from -2 to +6
        addPt((Math.random() - 0.5) * 0.4, y, (Math.random() - 0.5) * 0.4, BLUE);
    }

    // 3. Ribcage (Ellipses around spine)
    for(let r=0; r<10; r++) { // 10 ribs
        const y = 5 - (r * 0.5);
        const radiusX = 1.8 + Math.sin(r * 0.3) * 0.5; // wider at top, narrower at bottom
        const radiusZ = 1.2;
        for(let i=0; i<40; i++) {
            const t = Math.random() * Math.PI * 2;
            addPt(Math.cos(t) * radiusX, y, Math.sin(t) * radiusZ, CYAN);
        }
    }

    // 4. Shoulders & Arms
    const addArm = (side) => {
        // Shoulder
        const sx = side * 2.2;
        const sy = 5.2;
        for(let i=0; i<50; i++) addPt(sx + (Math.random()-0.5), sy + (Math.random()-0.5), (Math.random()-0.5), BLUE);
        
        // Arm line
        for(let i=0; i<100; i++) {
            const t = Math.random();
            const armY = sy - (t * 4); // goes down to y=1.2
            addPt(sx + (Math.random()-0.5)*0.3, armY, (Math.random()-0.5)*0.3, CYAN);
        }
    };
    addArm(-1); addArm(1);

    // 5. Pelvis
    for(let i=0; i<150; i++) {
        const t = Math.random() * Math.PI * 2;
        const rX = 1.5;
        const rZ = 0.8;
        addPt(Math.cos(t) * rX, -2.5 + (Math.random()*0.5), Math.sin(t) * rZ, BLUE);
    }

    // 6. Legs
    const addLeg = (side) => {
        const lx = side * 1.0;
        const ly = -2.5;
        for(let i=0; i<150; i++) {
            const t = Math.random();
            const legY = ly - (t * 6.5); // goes down to y=-9
            addPt(lx + (Math.random()-0.5)*0.4, legY, (Math.random()-0.5)*0.4, CYAN);
        }
    };
    addLeg(-1); addLeg(1);

    return pts;
  }, []);

  useFrame((state) => {
    groupRef.current.rotation.y = state.clock.elapsedTime * 0.5;
  });

  return (
    <group ref={groupRef} position={[0, -1, 0]} scale={[0.8, 0.8, 0.8]}>
      {particles.map((pt, i) => (
        <mesh key={i} position={pt.p}>
          <sphereGeometry args={[0.08, 4, 4]} />
          <meshBasicMaterial color={pt.color} />
        </mesh>
      ))}

      {/* Holographic Chest UI Hook */}
      <Html position={[1.5, 3, 1.5]} center distanceFactor={15}>
        <div style={{
          background: 'rgba(15, 23, 42, 0.85)',
          border: '1px solid rgba(6, 182, 212, 0.6)',
          color: '#06b6d4',
          padding: '8px 12px',
          borderRadius: '8px',
          backdropFilter: 'blur(8px)',
          fontSize: '11px',
          fontWeight: 'bold',
          whiteSpace: 'nowrap',
          boxShadow: '0 4px 20px rgba(6, 182, 212, 0.2)'
        }}>
          <div style={{ fontSize: '9px', color: 'var(--text-secondary)' }}>HOLOGRAPHIC SCAN</div>
          CARDIAC RHYTHM NORMAL
        </div>
      </Html>
    </group>
  );
};

export default function True3DTwin() {
  const [hovered, setHovered] = useState(false);

  return (
    <div 
      style={{ 
        width: '100%', height: '100%', 
        position: 'absolute', top: 0, left: 0, zIndex: 5, 
        background: 'radial-gradient(circle at center, #0a1128 0%, #000000 100%)',
        borderRadius: '16px', overflow: 'hidden'
      }}
      onPointerOver={() => setHovered(true)}
      onPointerOut={() => setHovered(false)}
    >
      <div style={{ position: 'absolute', top: '24px', left: '24px', zIndex: 10, color: 'rgba(255,255,255,0.7)' }}>
        <h3 style={{ margin: 0, color: '#3b82f6', display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ width: '8px', height: '8px', background: '#06b6d4', borderRadius: '50%', display: 'inline-block', boxShadow: '0 0 10px #06b6d4' }}></span>
          3D Point-Cloud Hologram
        </h3>
        <p style={{ margin: '4px 0 0 0', fontSize: '12px' }}>Drag to rotate 360° • Scroll to zoom</p>
      </div>

      <Canvas camera={{ position: [0, 0, 18], fov: 45 }}>
        <color attach="background" args={['#000000']} />
        <ambientLight intensity={1} />
        <Stars radius={100} depth={50} count={3000} factor={4} saturation={0} fade speed={1} />
        <PointCloudHuman />
        <OrbitControls enableZoom={true} autoRotate={!hovered} autoRotateSpeed={2.0} maxDistance={30} minDistance={5} />
      </Canvas>
    </div>
  );
}
