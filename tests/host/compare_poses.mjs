// Compares what verify_v3 --poses sampled from XU2 with XU1's formulas on the same keys.
//   node tests/host/compare_poses.mjs <poses.json>
import fs from 'node:fs';

import { angleDiff, legacyPose } from '../legacy_poses.mjs';

const POSITION_TOLERANCE = 0.01;
// XU2 blends FOV in tan(fov/2) even on fovMode linear
const FOV_TOLERANCE = 0.5;
// Past this a viewer would see it. XU2's slerp and XU1's per-axis lerp part ways at steep pitch
const ROTATION_TOLERANCE = 3;

function interpolationOf(spec) {
    if (spec.curve === 'catmullRom')
        return 'Hermite';
    return spec.stopAtKeys === 'none' ? 'Linear' : 'Cubic';
}

const rows = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const worst = { position: 0, rotation: 0, roll: 0, fov: 0 };
const worstFile = {};
let failed = 0;
for (const { file, spec, samples } of rows) {
    const interpolation = interpolationOf(spec);
    let rotation = 0;
    for (const [t, x, y, z, yaw, pitch, roll, fov] of samples) {
        const old = legacyPose(spec.keys, interpolation, spec.duration, t);
        const diffs = {
            position: Math.hypot(x - old.x, y - old.y, z - old.z),
            rotation: Math.max(angleDiff(yaw, old.yaw), angleDiff(pitch, old.pitch)),
            roll: angleDiff(roll, old.roll),
            fov: Math.abs(fov - old.fov),
        };
        rotation = Math.max(rotation, diffs.rotation);
        for (const [name, d] of Object.entries(diffs)) {
            if (d > worst[name]) {
                worst[name] = d;
                worstFile[name] = file;
            }
        }
        if (interpolation !== 'Hermite' && (diffs.position > POSITION_TOLERANCE || diffs.fov > FOV_TOLERANCE)) {
            console.log(`FAIL ${file} at ${t}: position ${diffs.position.toFixed(4)} fov ${diffs.fov.toFixed(4)}`);
            failed++;
        }
    }
    if (rotation > ROTATION_TOLERANCE) {
        console.log(`over ${ROTATION_TOLERANCE} deg: ${file} ${rotation.toFixed(2)}`);
        failed++;
    }
}
console.log(`${rows.length} paths. Worst: position ${worst.position.toFixed(4)} m, yaw or pitch ${worst.rotation.toFixed(3)} deg (${worstFile.rotation}), roll ${worst.roll.toFixed(3)} deg, fov ${worst.fov.toFixed(4)} deg`);
process.exitCode = failed > 0 ? 1 : 0;
