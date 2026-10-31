// XU1's XUtilsPlayback, position, rotation and FOV at a time, for checking XU2 plays converted paths the same.
// Timing is CameraScene's: no uniform motion and no ease, garagePresetLoader passes easing "None".

const wrap = (angle, ref) => {
    let diff = (angle - ref + 180) % 360;
    if (diff < 0)
        diff += 360;
    return ref + diff - 180;
};
const lerp = (a, b, t) => a + (b - a) * t;
const hermite = (p0, p1, m0, m1, t) => {
    const t2 = t * t;
    const t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * p0 + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * p1 + (t3 - t2) * m1;
};
const cubicInOut = (t) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2);

function segment(p, n) {
    const x = Math.min(Math.max(p, 0), 1) * (n - 1);
    const s = Math.min(Math.floor(x), n - 2);
    return { s, u: x - s };
}

function spline(values, s, u, unwrap) {
    const n = values.length;
    const a = values[s];
    const b = unwrap ? wrap(values[s + 1], a) : values[s + 1];
    const before = s > 0 ? values[s - 1] : 2 * a - b;
    const after = s + 2 < n ? values[s + 2] : 2 * b - a;
    const m0 = 0.5 * (b - (unwrap ? wrap(before, a) : before));
    const m1 = 0.5 * ((unwrap ? wrap(after, b) : after) - a);
    return hermite(a, b, m0, m1, u);
}

// keys: the old keyframes, interpolation: Linear, Cubic or Hermite. Returns x, y, z, yaw, pitch, roll, fov
export function legacyPose(keys, interpolation, duration, t) {
    const { s, u } = segment(t / duration, keys.length);
    const a = keys[s];
    const b = keys[s + 1];
    const channel = (field, angle) => {
        if (interpolation === 'Hermite')
            return spline(keys.map((k) => k[field]), s, u, angle);
        const to = angle ? wrap(b[field], a[field]) : b[field];
        return lerp(a[field], to, interpolation === 'Cubic' ? cubicInOut(u) : u);
    };
    return {
        x: channel('x'), y: channel('y'), z: channel('z'),
        yaw: channel('yaw', true), pitch: channel('pitch', true), roll: channel('roll', true),
        fov: channel('fov'),
    };
}

export function angleDiff(a, b) {
    return Math.abs(wrap(a, b) - b);
}
