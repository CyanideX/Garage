// What XU2 refuses, copied from SpecJson.cpp, Spec.cpp (Check) and Cloud.cpp so node --test works without a compiler.
// tests/host/verify_v3.cpp runs the real parsers.

const CURVES = ['linear', 'catmullRom', 'kb', 'natural', 'bspline'];
const ENDS = ['clamped', 'natural', 'reflect', 'extrapolate'];
const TIMINGS = ['distance', 'uniform', 'keys', 'smoothKeys'];
const LOOPS = ['once', 'wrap', 'pingpong', 'count'];
const ROTS = ['squad', 'slerp', 'lookAt'];
const FOVS = ['monotone', 'linear'];
const PASSES = ['auto', 'flow', 'stop', 'hold'];
const FAMILIES = ['sine', 'quad', 'cubic', 'quart', 'quint', 'expo', 'circ', 'smooth', 'smoother', 'smoothest', 'back', 'elastic', 'bounce'];
const DIRECTIONS = ['in', 'out', 'inOut', 'outIn'];

const isNum = (v) => typeof v === 'number' && Number.isFinite(v);
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

function validEase(id) {
    if (id === 'linear' || id === 'step' || /^bezier\(/.test(id))
        return true;
    const [family, direction, ...rest] = id.split('.');
    return rest.length === 0 && FAMILIES.includes(family) && DIRECTIONS.includes(direction);
}

export function pathErrors(doc) {
    const errors = [];
    const fail = (field, why) => errors.push(`${field}: ${why}`);
    if (!isObj(doc))
        return ['file: not a JSON object'];
    if (doc.version !== 3)
        fail('version', 'expected 3');
    if (isNum(doc.motion) && doc.motion > 1)
        fail('motion', 'newer than this XUtils reads');

    const name = (key, list) => {
        const v = doc[key];
        if (v == null)
            return;
        if (typeof v !== 'string')
            fail(key, 'expected a name');
        else if (!list.includes(v))
            fail(key, `unknown ${v}`);
    };
    name('curve', CURVES);
    name('ends', ENDS);
    name('timing', TIMINGS);
    name('loop', LOOPS);
    name('rotMode', ROTS);
    name('fovMode', FOVS);
    for (const key of ['alpha', 'duration', 'preroll', 'postroll', 'loopCount']) {
        if (doc[key] != null && typeof doc[key] !== 'number')
            fail(key, 'expected a number');
    }
    for (const key of ['closed', 'hasRot', 'hasFov']) {
        if (doc[key] != null && typeof doc[key] !== 'boolean')
            fail(key, 'expected true or false');
    }
    if (isNum(doc.loopCount) && !Number.isInteger(doc.loopCount))
        fail('loopCount', 'expected a whole number');
    if (doc.ease != null && (typeof doc.ease !== 'string' || !validEase(doc.ease)))
        fail('ease', `unknown ${doc.ease}`);
    if (typeof doc.stopAtKeys === 'string' && doc.stopAtKeys !== 'none' && !validEase(doc.stopAtKeys))
        fail('stopAtKeys', `unknown ${doc.stopAtKeys}`);

    // Check() also runs on these once the path builds, with its defaults for anything left out
    const alpha = doc.alpha ?? 0.5;
    if (!(alpha >= 0 && alpha <= 1))
        fail('alpha', 'expected 0..1');
    if (!((doc.duration ?? 10) > 0))
        fail('duration', 'expected more than 0');
    if (!((doc.preroll ?? 0) >= 0))
        fail('preroll', 'expected 0 or more');
    if (!((doc.postroll ?? 0) >= 0))
        fail('postroll', 'expected 0 or more');

    if (!Array.isArray(doc.keys))
        return [...errors, 'keys: expected a list'];
    if (doc.keys.length < 2)
        fail('count', 'needs at least 2 keys');
    const ids = new Set();
    doc.keys.forEach((k, i) => {
        const at = `keys[${i}]`;
        if (!isObj(k)) {
            fail(at, 'expected an object');
            return;
        }
        for (const key of ['id', 'x', 'y', 'z', 'yaw', 'pitch', 'roll', 'fov', 'turns', 'time', 'hold']) {
            if (k[key] != null && typeof k[key] !== 'number')
                fail(`${at}.${key}`, 'expected a number');
        }
        if (isNum(k.turns) && !Number.isInteger(k.turns))
            fail(`${at}.turns`, 'whole turns only');
        if (k.kb != null && (!Array.isArray(k.kb) || k.kb.length !== 3 || !k.kb.every(isNum)))
            fail(`${at}.kb`, 'expected [tension, continuity, bias]');
        if (typeof k.pass === 'string' && !PASSES.includes(k.pass))
            fail(`${at}.pass`, 'expected auto, flow, stop or hold');
        if (doc.hasFov !== false && !((k.fov ?? 70) > 0 && (k.fov ?? 70) < 180))
            fail(`${at}.fov`, 'outside 0..180');
        if (!((k.hold ?? 0) >= 0))
            fail(`${at}.hold`, 'expected 0 or more seconds');
        if (ids.has(k.id))
            fail(`${at}.id`, 'repeated, it would get a fresh one and break anything keyed by it');
        ids.add(k.id);
    });
    return errors;
}

export function cloudErrors(doc) {
    const errors = [];
    const fail = (field, why) => errors.push(`${field}: ${why}`);
    if (!isObj(doc))
        return ['file: not a JSON object'];
    if (doc.version !== 3)
        fail('version', 'expected 3');
    if ((isNum(doc.cloud) ? doc.cloud : 1) > 2)
        fail('cloud', 'newer than this XUtils reads');
    if (!Array.isArray(doc.points))
        return [...errors, 'points: expected a list'];
    doc.points.forEach((p, i) => {
        if (!isObj(p))
            fail(`points[${i}]`, 'expected an object');
    });
    // These read leniently: a bad one is silently off rather than refused, which is just as wrong to write
    const vec3 = (v) => Array.isArray(v) && v.length === 3 && v.every(isNum);
    if (doc.center !== undefined && !vec3(doc.center))
        fail('center', 'expected [x, y, z]');
    if (doc.box !== undefined && (!isObj(doc.box) || !vec3(doc.box.half)))
        fail('box.half', 'expected [x, y, z]');
    const ids = new Set();
    doc.points.forEach((p, i) => {
        if (!isObj(p))
            return;
        if (p.lookAt !== undefined && !vec3(p.lookAt))
            fail(`points[${i}].lookAt`, 'expected [x, y, z]');
        if (ids.has(p.id))
            fail(`points[${i}].id`, 'repeated');
        ids.add(p.id);
    });
    return errors;
}
