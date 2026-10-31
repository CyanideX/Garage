#!/usr/bin/env node
// Old GarageCore and GLC data to Garage's XU2 v3 layout.
//
//   node _tools/convert_garage_data.mjs <input> <output> [--user] [--report <file>]
//
// <input> is any of: a GarageCore data folder (or a mod zip extracted, or a CET mods folder), a car's data folder
// holding pointCloud.json / idlePaths.json, or with --user a GLC data folder.
// <output> is the data root: r6/scripts/Garage/data, red4ext/plugins/XUtils/data/Garage with --user, or a car's data
// folder. Runs add up, so a garage's paths can come from one input and its location from another.
// Exits 1 if anything was left out on an error.

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const FILE_VERSION = 3;
const SPEC_VERSION = 1;
// Cloud.cpp's CloudVersion. API.md section 13 still says 1, the parser takes both
const CLOUD_VERSION = 2;
const DEFAULT_DURATION = 6;
const DEFAULT_BOX = { halfWidth: 1.0, halfDepth: 2.5, halfHeight: 0.8, yaw: 0 };

// The only prefix override there is. Nothing can match a record by name without CET, the model id survives
const PREFIX_TO_MODEL = { 'Vehicle.v_sport2_quadra_type66*': 'model:Vehicle.Type66' };

const LOCATION_KEYS = new Set([
    'name', 'filename', 'region', 'x', 'y', 'z', 'yaw',
    'proximityEnterRadius', 'proximityExitRadius', 'proximityLeaveRadius', 'proximityServiceRadius', 'arrivalDistance', 'proximityEvents',
    'doorNodeRef', 'doorEntityHash', 'maxWidth', 'maxLength', 'maxHeight', 'playerSpawn', 'audioEmitter',
    'garageTier', 'garageServiceMultiplier', 'maxVehicleTier', 'maxPoolOverride', 'cooldownMultiplier',
    'blockedClasses', 'surchargeClasses', 'services', 'saleDelayMin', 'saleDelayMax', 'saleDelayMultiplier',
    'partViewShake', 'idleShake', 'maxIdleDuration',
]);
const AUDIO_KEYS = new Set(['x', 'y', 'z', 'type', 'gain', 'reverb', 'reverbLevel', 'lowPass', 'highPass', 'occlusion', 'occlusionHz', 'occlusionLevel', 'playlist']);
const DEAD_KEYS = new Set(['minDistance', 'maxDistance', '_comment']);
const PATH_KEYS = new Set(['name', 'positions', 'playbackDuration', 'interpolation', 'easing', 'title', 'adaptive', 'lookAt', 'shake']);
const KEY_KEYS = new Set(['x', 'y', 'z', 'yaw', 'pitch', 'roll', 'fov', 'lookAt']);
const CLOUD_KEYS = new Set(['positions', 'orbitCenter', 'boundingBox', 'slots', 'vehicleId']);
const POINT_KEYS = new Set(['name', 'x', 'y', 'z', 'yaw', 'pitch', 'roll', 'fov', 'lookAt']);

const isNum = (v) => typeof v === 'number' && Number.isFinite(v);
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const vec = (o) => (isObj(o) && isNum(o.x) && isNum(o.y) && isNum(o.z) ? [o.x, o.y, o.z] : null);
const textOr = (v, d) => (typeof v === 'string' && v !== '' ? v : d);

export class Report {
    constructor() { this.items = []; }
    add(level, file, message) { this.items.push({ level, file, message }); }
    error(file, message) { this.add('error', file, message); }
    lossy(file, message) { this.add('lossy', file, message); }
    changed(file, message) { this.add('changed', file, message); }
    note(file, message) { this.add('note', file, message); }
    get errors() { return this.items.filter((i) => i.level === 'error').length; }
    text() {
        const counts = {};
        const lines = this.items.map((i) => {
            counts[i.level] = (counts[i.level] || 0) + 1;
            return `${i.level.padEnd(7)} ${i.file}: ${i.message}`;
        });
        lines.push(`-- ${Object.entries(counts).map(([k, v]) => `${v} ${k}`).join(', ') || 'nothing to report'}`);
        return lines.join('\n');
    }
}

function droppedKeys(report, file, where, obj, known) {
    for (const key of Object.keys(obj)) {
        if (known.has(key))
            continue;
        if (DEAD_KEYS.has(key))
            report.note(file, `${where}: dropped dead field ${key}`);
        else
            report.lossy(file, `${where}: dropped unknown field ${key}`);
    }
}

// Same rules as ProximityModule.resolveRadii, baked in so the loader has no clamps to port
function resolveZone(entry, hasDoor, report, file) {
    const enter = entry.proximityEnterRadius ?? 30;
    let exit = entry.proximityExitRadius ?? entry.proximityLeaveRadius ?? 15;
    let service = entry.proximityServiceRadius != null ? Math.max(entry.proximityServiceRadius, 2) : Math.max(exit * 0.8, 2);
    if (service >= exit) {
        const clamped = Math.max(exit - 1, 2);
        report.changed(file, `${entry.filename}: service radius ${service} clamped to ${clamped}, it was at or past the exit radius`);
        service = clamped;
    }
    if (hasDoor && exit >= enter) {
        const clamped = Math.max(enter - 1, service + 1);
        report.changed(file, `${entry.filename}: exit radius ${exit} clamped to ${clamped}, it was at or past the enter radius`);
        exit = clamped;
    }
    return { enter, exit, service, arrival: entry.arrivalDistance ?? 2, events: entry.proximityEvents !== false };
}

function limit(entry, field, report, file) {
    const value = entry[field];
    if (value == null)
        return 0;
    if (!isNum(value) || value <= 0) {
        if (value !== 0)
            report.lossy(file, `${entry.filename}: ${field} ${JSON.stringify(value)} was ignored by the old mod, now 0 (no limit)`);
        return 0;
    }
    return value;
}

function doorHash(entry, report, file) {
    const hash = entry.doorEntityHash;
    if (hash == null || hash === '')
        return '';
    if (typeof hash === 'number') {
        if (!Number.isSafeInteger(hash)) {
            report.error(file, `${entry.filename}: doorEntityHash ${hash} is a JSON number past 2^53, the digits are gone. Door left out`);
            return '';
        }
        report.changed(file, `${entry.filename}: doorEntityHash was a number, written as a string`);
    }
    return String(hash);
}

export function convertLocation(entry, report, file) {
    for (const field of ['name', 'filename', 'region', 'x', 'y', 'z', 'yaw']) {
        if (entry[field] == null) {
            report.error(file, `skipped ${entry.filename ?? entry.name ?? 'an entry'}: missing ${field}`);
            return null;
        }
    }
    if (typeof entry.filename !== 'string' || !/^[A-Za-z0-9_.-]+$/.test(entry.filename)) {
        report.error(file, `skipped ${JSON.stringify(entry.filename)}: filename can't be an id`);
        return null;
    }
    droppedKeys(report, file, entry.filename, entry, LOCATION_KEYS);

    const nodeRef = textOr(entry.doorNodeRef, '');
    const entityHash = doorHash(entry, report, file);
    const ae = isObj(entry.audioEmitter) ? entry.audioEmitter : {};
    droppedKeys(report, file, `${entry.filename}.audioEmitter`, ae, AUDIO_KEYS);

    const location = {
        format: 'garage.location',
        version: 1,
        id: entry.filename,
        name: entry.name,
        region: entry.region,
        deck: { x: entry.x, y: entry.y, z: entry.z, yaw: entry.yaw },
        zone: resolveZone(entry, nodeRef !== '' || entityHash !== '', report, file),
        door: { nodeRef, entityHash },
        limits: {
            width: limit(entry, 'maxWidth', report, file),
            length: limit(entry, 'maxLength', report, file),
            height: limit(entry, 'maxHeight', report, file),
        },
    };

    const ps = entry.playerSpawn;
    if (ps != null) {
        if (isNum(ps.x) && isNum(ps.y) && isNum(ps.z) && isNum(ps.yaw))
            location.playerSpawn = { x: ps.x, y: ps.y, z: ps.z, yaw: ps.yaw };
        else
            report.lossy(file, `${entry.filename}: playerSpawn needs all of x, y, z, yaw, the old mod ignored this one too`);
    }

    location.audio = {
        x: ae.x ?? entry.x,
        y: ae.y ?? entry.y,
        z: ae.z ?? entry.z,
        type: textOr(ae.type, 'auto'),
        gain: ae.gain ?? 1.0,
        reverb: textOr(ae.reverb, 'revb_interior_factory_medium__medium'),
        reverbLevel: ae.reverbLevel ?? 0.35,
        lowPass: ae.lowPass ?? 0,
        highPass: ae.highPass ?? 0,
        occlusion: ae.occlusion !== false,
        occlusionHz: ae.occlusionHz ?? 1200,
        occlusionLevel: ae.occlusionLevel ?? 0.9,
        playlist: textOr(ae.playlist, 'pool'),
    };

    const surcharges = [];
    for (const sc of Array.isArray(entry.surchargeClasses) ? entry.surchargeClasses : []) {
        // "class" is a redscript keyword, so ToObject couldn't map it to a field
        if (isObj(sc) && sc.class && sc.multiplier)
            surcharges.push({ vehicleClass: sc.class, multiplier: sc.multiplier });
        else
            report.lossy(file, `${entry.filename}: surcharge without class and multiplier dropped, the old mod skipped it too`);
    }
    location.economy = {
        tier: textOr(entry.garageTier, 'Standard'),
        serviceMultiplier: entry.garageServiceMultiplier ?? 1.0,
        maxVehicleTier: textOr(entry.maxVehicleTier, ''),
        maxPool: entry.maxPoolOverride ?? 0,
        cooldownMultiplier: entry.cooldownMultiplier ?? 1.0,
        blockedClasses: Array.isArray(entry.blockedClasses) ? entry.blockedClasses : [],
        surcharges,
        services: Array.isArray(entry.services) ? entry.services : [],
        saleDelay: {
            min: entry.saleDelayMin ?? 0,
            max: entry.saleDelayMax ?? 0,
            multiplier: entry.saleDelayMultiplier ?? 1.0,
        },
    };

    let partViewShake = entry.partViewShake ?? 'showroom';
    if (partViewShake === false) {
        report.changed(file, `${entry.filename}: partViewShake false written as "", meaning no shake`);
        partViewShake = '';
    }
    location.camera = {
        idleShake: textOr(entry.idleShake, 'timeline'),
        partViewShake,
        maxIdleSeconds: entry.maxIdleDuration ?? DEFAULT_DURATION,
    };
    location.app = {};
    return location;
}

function convertSlots(slots, report, file) {
    const out = [];
    for (const slot of slots) {
        if (isObj(slot) && typeof slot.id === 'string' && Array.isArray(slot.maps))
            out.push({ id: slot.id, maps: slot.maps });
        else
            report.lossy(file, 'dropped a slot without id and maps, the old mod skipped it too');
    }
    return out;
}

// kind: "garage", "default" or "car". Only garage clouds keep slots, car slots live in the schema
export function convertCloud(data, report, file, kind) {
    const old = Array.isArray(data) ? data[0] : data;
    if (!isObj(old) || !Array.isArray(old.positions) || old.positions.length === 0) {
        report.error(file, 'no positions, nothing to convert');
        return null;
    }
    droppedKeys(report, file, 'cloud', old, new Set([...CLOUD_KEYS, 'name']));
    if (old.name !== undefined)
        report.note(file, `dropped cloud name ${JSON.stringify(old.name)}, nothing read it`);

    const seen = new Set();
    const points = [];
    for (const p of old.positions) {
        if (!isObj(p) || !isNum(p.x) || !isNum(p.y) || !isNum(p.z) || typeof p.name !== 'string' || p.name === '') {
            report.error(file, `dropped point ${JSON.stringify(p?.name)}: needs a name and x, y, z`);
            continue;
        }
        droppedKeys(report, file, `point ${p.name}`, p, POINT_KEYS);
        const name = p.name.toLowerCase();
        // The old lookup ignored case and took the first. Cloud::Find doesn't ignore case, so slot ids go lowercase
        if (name !== p.name)
            report.changed(file, `point ${p.name} renamed ${name}`);
        if (seen.has(name)) {
            report.lossy(file, `point ${p.name} repeats a name, the first one wins`);
            continue;
        }
        seen.add(name);
        for (const field of ['yaw', 'pitch', 'roll']) {
            if (!isNum(p[field]))
                report.changed(file, `point ${p.name}: missing ${field}, now 0`);
        }
        const hasFov = isNum(p.fov) && p.fov > 0 && p.fov < 180;
        if (!hasFov)
            report.changed(file, `point ${p.name}: fov ${JSON.stringify(p.fov)} unusable, the point leaves FOV alone`);
        const point = {
            id: points.length + 1,
            x: p.x, y: p.y, z: p.z,
            yaw: isNum(p.yaw) ? p.yaw : 0,
            pitch: isNum(p.pitch) ? p.pitch : 0,
            roll: isNum(p.roll) ? p.roll : 0,
            hasRotation: true,
            fov: hasFov ? p.fov : 0,
            hasFov,
            name,
        };
        if (p.lookAt != null) {
            const at = vec(p.lookAt);
            if (at)
                point.lookAt = at;
            else
                report.lossy(file, `point ${p.name}: lookAt isn't x, y, z, dropped`);
        }
        points.push(point);
    }
    if (points.length === 0) {
        report.error(file, 'no usable positions');
        return null;
    }

    let center = vec(old.orbitCenter);
    if (!center) {
        center = [0, 1, 2].map((axis) => points.reduce((sum, p) => sum + [p.x, p.y, p.z][axis], 0) / points.length);
        report.changed(file, 'no orbitCenter, used the average of the points like the old loader');
    }
    let bb = old.boundingBox;
    if (!isObj(bb) || !isNum(bb.halfWidth)) {
        bb = DEFAULT_BOX;
        report.changed(file, 'no boundingBox, used the old loader\'s 1.0, 2.5, 0.8, yaw 0');
    } else if (!isNum(bb.halfDepth) || !isNum(bb.halfHeight) || !isNum(bb.yaw)) {
        report.changed(file, 'boundingBox incomplete, the gaps took the old loader\'s defaults');
        bb = { ...DEFAULT_BOX, ...Object.fromEntries(Object.entries(bb).filter(([, v]) => isNum(v))) };
    }

    const garage = { frame: { center, yaw: bb.yaw, halfHeight: bb.halfHeight } };
    if (Array.isArray(old.slots) && old.slots.length > 0) {
        if (kind === 'garage')
            garage.slots = convertSlots(old.slots, report, file);
        else
            report.lossy(file, `dropped ${old.slots.length} slots, car slots belong in the schema`);
    }
    if (typeof old.vehicleId === 'string' && old.vehicleId !== '')
        garage.vehicleId = old.vehicleId;
    else if (kind === 'car')
        report.note(file, 'no vehicleId in the old file');

    return {
        version: FILE_VERSION,
        cloud: CLOUD_VERSION,
        center,
        box: { half: [bb.halfWidth, bb.halfDepth, bb.halfHeight], yaw: bb.yaw, offset: [0, 0, 0] },
        points,
        app: { garage },
    };
}

function curveFields(interpolation, report, file, name) {
    const linear = { curve: 'linear', alpha: 0.5, ends: 'clamped', stopAtKeys: 'none', rotMode: 'slerp', fovMode: 'linear' };
    switch (interpolation ?? 'Hermite') {
    case 'Linear':
        return linear;
    case 'Cubic':
        report.changed(file, `${name}: Cubic becomes linear with stopAtKeys cubic.inOut, that's what it played`);
        return { ...linear, stopAtKeys: 'cubic.inOut' };
    case 'Hermite':
    case 'CatmullRom':
        return { curve: 'catmullRom', alpha: 0, ends: 'extrapolate', stopAtKeys: 'none', rotMode: 'squad', fovMode: 'monotone' };
    default:
        report.lossy(file, `${name}: unknown interpolation ${JSON.stringify(interpolation)} became linear`);
        return linear;
    }
}

function easeField(easing, report, file, name) {
    if (easing === false || easing == null || easing === 'None' || easing === 'Linear')
        return 'linear';
    if (easing === true) {
        report.changed(file, `${name}: easing true becomes linear, it was a no-op in XU1`);
        return 'linear';
    }
    if (easing === 'Smoothstep')
        return 'smooth.inOut';
    if (easing === 'Smootherstep' || easing === 'SmootherStep')
        return 'smoother.inOut';
    report.lossy(file, `${name}: unknown easing ${JSON.stringify(easing)} became linear`);
    return 'linear';
}

// frame: where the path is anchored, null for a static path. adaptive: scaled to fit the car
export function convertPath(old, report, file, { frame = null, adaptive = false } = {}) {
    const name = old.name;
    droppedKeys(report, file, name, old, PATH_KEYS);
    const positions = Array.isArray(old.positions) ? old.positions : [];
    // Check() refuses fewer than 2
    if (positions.length < 2) {
        report.error(file, `${name}: skipped, ${positions.length} keyframes and a path needs 2`);
        return null;
    }

    const keys = [];
    const keyFocus = {};
    for (const [i, k] of positions.entries()) {
        if (!isObj(k) || !isNum(k.x) || !isNum(k.y) || !isNum(k.z)) {
            report.error(file, `${name}: skipped, keyframe ${i + 1} has no x, y, z`);
            return null;
        }
        droppedKeys(report, file, `${name} keyframe ${i + 1}`, k, KEY_KEYS);
        for (const field of ['yaw', 'pitch', 'roll']) {
            if (!isNum(k[field]))
                report.changed(file, `${name} keyframe ${i + 1}: missing ${field}, now 0`);
        }
        let fov = k.fov;
        if (!isNum(fov) || fov <= 0 || fov >= 180) {
            report.changed(file, `${name} keyframe ${i + 1}: fov ${JSON.stringify(fov)} unusable, now 70`);
            fov = 70;
        }
        const id = i + 1;
        keys.push({
            id,
            x: k.x, y: k.y, z: k.z,
            yaw: isNum(k.yaw) ? k.yaw : 0,
            pitch: isNum(k.pitch) ? k.pitch : 0,
            roll: isNum(k.roll) ? k.roll : 0,
            fov,
            turns: 0,
            name: '',
            kb: [0, 0, 0],
            time: 0,
            pass: 'auto',
            hold: 0,
        });
        const at = vec(k.lookAt);
        if (at)
            keyFocus[id] = at;
        else if (k.lookAt != null)
            report.lossy(file, `${name} keyframe ${i + 1}: lookAt isn't x, y, z, dropped`);
    }

    let duration = old.playbackDuration;
    if (!isNum(duration) || duration <= 0) {
        report.changed(file, `${name}: playbackDuration ${JSON.stringify(duration)} becomes ${DEFAULT_DURATION} s`);
        duration = DEFAULT_DURATION;
    }

    const garage = { title: old.title === true, adaptive };
    if (isObj(old.shake)) {
        garage.shake = { intensity: old.shake.intensity ?? 1, frequency: old.shake.frequency ?? 1 };
    }
    // lookAt only ever steered focus. As v3 lookAt or keyLookAt it would aim the camera over the authored rotations
    const point = vec(old.lookAt);
    if (old.lookAt != null && !point)
        report.lossy(file, `${name}: lookAt isn't x, y, z, dropped`);
    if (Object.keys(keyFocus).length > 0) {
        garage.focus = { keys: keyFocus };
        if (point)
            report.lossy(file, `${name}: path lookAt dropped, the keyframe ones won in the old mod`);
    } else if (point) {
        garage.focus = { point };
    }
    if (frame)
        garage.frame = frame;

    return {
        version: FILE_VERSION,
        motion: SPEC_VERSION,
        ...curveFields(old.interpolation, report, file, name),
        closed: false,
        timing: 'uniform',
        duration,
        ease: easeField(old.easing, report, file, name),
        loop: 'once',
        loopCount: 2,
        preroll: 0,
        postroll: 0,
        hasRot: true,
        hasFov: true,
        keys,
        app: { garage },
    };
}

// The bare array GLC writes, or { paths: [...] } that car mods could use
function pathList(data) {
    if (Array.isArray(data))
        return data;
    return isObj(data) && Array.isArray(data.paths) ? data.paths : null;
}

export function convertPaths(data, report, file, frameFor) {
    const list = pathList(data);
    if (!list) {
        report.error(file, 'not a list of paths');
        return [];
    }
    const out = [];
    const seen = new Set();
    for (const [i, old] of list.entries()) {
        if (!isObj(old)) {
            report.error(file, `entry ${i + 1} isn't a path`);
            continue;
        }
        const named = typeof old.name === 'string' && old.name !== '' ? old : { ...old, name: `idle_${i + 1}` };
        if (named !== old)
            report.changed(file, `entry ${i + 1} has no name, called it ${named.name} like the old mod`);
        const fileName = named.name.replace(/[^A-Za-z0-9_.-]/g, '_').replace(/\.+$/, '_');
        if (fileName !== named.name)
            report.changed(file, `${named.name}: file name is ${fileName}.json`);
        // Lowercased: a clash has to count on Windows too
        const id = fileName.toLowerCase();
        if (seen.has(id)) {
            report.lossy(file, `${named.name}: repeats a name, the first one wins like the old mod`);
            continue;
        }
        const placed = frameFor(named);
        if (placed === undefined)
            continue;
        const doc = convertPath(named, report, file, placed);
        if (doc) {
            seen.add(id);
            out.push({ name: fileName, doc });
        }
    }
    if (out.length > 0)
        report.changed(file, `${out.length} paths: yaw and pitch slerp instead of blending per axis, FOV blends in tan(fov/2). Inherent to XU2`);
    const names = out.map((p) => p.name.toLowerCase());
    if (names.join('\n') !== [...names].sort().join('\n'))
        report.lossy(file, `play order was ${out.map((p) => p.name).join(', ')}. One file per path has no order but the names`);
    return out;
}

export function convertBBox(data, report, file) {
    const out = {};
    for (const [key, entry] of Object.entries(data)) {
        if (!isObj(entry) || !isNum(entry.halfWidth) || !isNum(entry.halfDepth) || !isNum(entry.halfHeight)) {
            report.error(file, `${key}: needs halfWidth, halfDepth and halfHeight, left out`);
            continue;
        }
        let target = key;
        if (key.endsWith('*')) {
            target = PREFIX_TO_MODEL[key];
            if (!target) {
                report.error(file, `${key}: no model id known for this prefix, left out`);
                continue;
            }
            report.changed(file, `${key} becomes ${target}: anything with that model matches now, not the record name`);
        }
        const offset = entry.centerOffset;
        // BBox.Measure: halfWidth is local X, halfDepth local Y, halfHeight local Z
        out[target] = {
            half: [entry.halfWidth, entry.halfDepth, entry.halfHeight],
            offset: [offset?.x ?? 0, offset?.y ?? 0, offset?.z ?? 0],
        };
    }
    return out;
}

const isScalar = (v) => v === null || typeof v !== 'object';
const isFlat = (v) => Object.values(v).every((x) => isScalar(x) || (Array.isArray(x) && x.every(isScalar)));

export function pretty(v, indent = '') {
    if (isScalar(v))
        return JSON.stringify(v);
    const inner = `${indent}    `;
    const inline = (o) => (Array.isArray(o)
        ? `[${o.map((x) => JSON.stringify(x)).join(', ')}]`
        : `{ ${Object.entries(o).map(([k, x]) => `${JSON.stringify(k)}: ${isScalar(x) ? JSON.stringify(x) : inline(x)}`).join(', ')} }`);
    if (Array.isArray(v)) {
        if (v.length === 0)
            return '[]';
        if (v.every(isScalar))
            return inline(v);
        return `[\n${v.map((x) => inner + (isObj(x) && isFlat(x) ? inline(x) : pretty(x, inner))).join(',\n')}\n${indent}]`;
    }
    const entries = Object.entries(v);
    if (entries.length === 0)
        return '{}';
    if (entries.length <= 6 && isFlat(v))
        return inline(v);
    return `{\n${entries.map(([k, x]) => `${inner}${JSON.stringify(k)}: ${pretty(x, inner)}`).join(',\n')}\n${indent}}`;
}

class Output {
    constructor(root, report) {
        this.root = root;
        this.report = report;
        this.written = [];
    }
    json(rel, doc, source) { this.text(rel, `${pretty(doc)}\n`, source); }
    text(rel, text, source) {
        const full = path.join(this.root, rel);
        if (fs.existsSync(full) && fs.readFileSync(full, 'utf8') !== text)
            this.report.changed(source, `overwrote ${rel} with different content`);
        fs.mkdirSync(path.dirname(full), { recursive: true });
        fs.writeFileSync(full, text);
        this.written.push(rel.replaceAll('\\', '/'));
    }
    read(rel) {
        const full = path.join(this.root, rel);
        return fs.existsSync(full) ? JSON.parse(fs.readFileSync(full, 'utf8')) : null;
    }
}

function readJson(file, report) {
    try {
        return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
    } catch (e) {
        report.error(file, `doesn't parse: ${e.message}`);
        return null;
    }
}

// .json only, so .json.bak stays out
function jsonFiles(dir, skip = () => false) {
    if (!fs.existsSync(dir))
        return [];
    return fs.readdirSync(dir).filter((f) => f.endsWith('.json') && !skip(f)).sort().map((f) => path.join(dir, f));
}

const stem = (file) => path.basename(file, '.json');

function writeLocations(data, source, out, report, run) {
    if (!isObj(data) || !Array.isArray(data.garages)) {
        report.error(source, "missing the 'garages' list");
        return;
    }
    droppedKeys(report, source, 'file', data, new Set(['garages']));
    for (const entry of data.garages) {
        const location = convertLocation(entry, report, source);
        if (!location)
            continue;
        if (run.locations.has(location.id))
            report.lossy(source, `${location.id}: repeats an id from this run, the later one wins like the old mod`);
        run.locations.set(location.id, location);
        out.json(`garages/locations/${location.id}.json`, location, source);
    }
}

function warnDuplicates(run, report, source) {
    const byName = new Map();
    const byDoor = new Map();
    for (const loc of run.locations.values()) {
        byName.set(loc.name, [...(byName.get(loc.name) ?? []), loc.id]);
        if (loc.door.entityHash)
            byDoor.set(loc.door.entityHash, [...(byDoor.get(loc.door.entityHash) ?? []), loc.id]);
    }
    for (const [name, ids] of byName) {
        if (ids.length > 1)
            report.note(source, `name "${name}" is on ${ids.join(', ')}. Everything's keyed by id now, so they don't collide`);
    }
    for (const [hash, ids] of byDoor) {
        if (ids.length > 1)
            report.lossy(source, `door ${hash} is on ${ids.join(', ')}, carried over as it was`);
    }
}

// Deck z is the car's origin, every other frame's z is the middle of its box. So z comes from the garage's cloud if it has one
function garageFrame(id, run, out) {
    const location = run.locations.get(id) ?? out.read(`garages/locations/${id}.json`);
    if (!location)
        return null;
    const cloud = run.clouds.get(id) ?? out.read(`garages/clouds/${id}.json`);
    const { x, y, z, yaw } = location.deck;
    if (cloud)
        return { center: [x, y, cloud.center[2]], yaw, halfHeight: cloud.box.half[2] };
    return { center: [x, y, z], yaw, halfHeight: DEFAULT_BOX.halfHeight };
}

function convertTree(root, out, report, run, user) {
    const defaults = path.join(root, 'defaults');
    if (user && fs.existsSync(defaults))
        report.note(defaults, 'skipped, the user root has no defaults');

    for (const file of [...(user ? [] : [path.join(defaults, 'locations.json')]), ...jsonFiles(path.join(root, 'garages', 'locations'))]) {
        if (!fs.existsSync(file))
            continue;
        const data = readJson(file, report);
        if (data)
            writeLocations(data, file, out, report, run);
    }
    warnDuplicates(run, report, path.join(root, 'garages', 'locations'));

    for (const file of jsonFiles(path.join(root, 'garages', 'cameras'))) {
        const data = readJson(file, report);
        const cloud = data && convertCloud(data, report, file, 'garage');
        if (!cloud)
            continue;
        run.clouds.set(stem(file), cloud);
        out.json(`garages/clouds/${stem(file)}.json`, cloud, file);
    }

    for (const file of jsonFiles(path.join(root, 'garages', 'paths'), (f) => f.includes('_autosave'))) {
        const id = stem(file);
        const data = readJson(file, report);
        if (!data)
            continue;
        const frameFor = (old) => {
            if (!old.adaptive)
                return {};
            const frame = garageFrame(id, run, out);
            if (!frame) {
                report.error(file, `${old.name}: adaptive path with no ${id} location to frame it on, left out`);
                return undefined;
            }
            report.changed(file, `${old.name}: adaptive, framed on garage ${id} (center ${frame.center.join(', ')}, yaw ${frame.yaw}), not the car's capture frame`);
            return { frame, adaptive: true };
        };
        for (const { name, doc } of convertPaths(data, report, file, frameFor))
            out.json(`garages/paths/${id}/${name}.json`, doc, file);
    }

    if (!user) {
        const cameras = path.join(defaults, 'cameras.json');
        let defaultFrame = out.read('defaults/cloud.json')?.app?.garage?.frame ?? null;
        if (fs.existsSync(cameras)) {
            const data = readJson(cameras, report);
            const cloud = data && convertCloud(data, report, cameras, 'default');
            if (cloud) {
                out.json('defaults/cloud.json', cloud, cameras);
                defaultFrame = cloud.app.garage.frame;
            }
        }
        const paths = path.join(defaults, 'paths.json');
        if (fs.existsSync(paths)) {
            const data = readJson(paths, report);
            if (data && !defaultFrame)
                report.error(paths, 'no default cloud to frame these on, left out');
            else if (data) {
                // The old loader scaled these to the car, same as adaptive ones
                for (const { name, doc } of convertPaths(data, report, paths, () => ({ frame: defaultFrame, adaptive: true })))
                    out.json(`defaults/paths/${name}.json`, doc, paths);
            }
        }
        const bbox = path.join(defaults, 'bbox_overrides.json');
        if (fs.existsSync(bbox)) {
            const data = readJson(bbox, report);
            if (data)
                out.json('defaults/bbox.json', convertBBox(data, report, bbox), bbox);
        }
    }

    const paint = path.join(root, 'paint', 'vehicle_appearances.json');
    if (fs.existsSync(paint)) {
        if (user)
            report.note(paint, 'skipped, the user root has no paint catalog');
        else if (readJson(paint, report))
            out.text('paint/appearances.json', fs.readFileSync(paint, 'utf8'), paint);
    }
}

// outPrefix is empty in a car's own data folder and vehicles/<id>/ under the user root
function writeCarPaths(file, frame, outPrefix, out, report) {
    const data = readJson(file, report);
    if (!data)
        return;
    if (!frame) {
        report.error(file, 'no cloud for this car to frame its paths on, left out');
        return;
    }
    const frameFor = (old) => {
        if (old.adaptive)
            report.note(file, `${old.name}: adaptive ignored, car paths always move with the car`);
        return { frame };
    };
    for (const { name, doc } of convertPaths(data, report, file, frameFor))
        out.json(`${outPrefix}paths/${name}.json`, doc, file);
}

function convertCar(dir, out, report) {
    const cloudFile = path.join(dir, 'pointCloud.json');
    let frame = out.read('cloud.json')?.app?.garage?.frame ?? null;
    if (fs.existsSync(cloudFile)) {
        const data = readJson(cloudFile, report);
        const cloud = data && convertCloud(data, report, cloudFile, 'car');
        if (cloud) {
            out.json('cloud.json', cloud, cloudFile);
            frame = cloud.app.garage.frame;
        }
    }
    const pathsFile = path.join(dir, 'idlePaths.json');
    if (fs.existsSync(pathsFile))
        writeCarPaths(pathsFile, frame, '', out, report);
}

function convertGlc(root, out, report) {
    const frames = new Map();
    const exports = new Map();
    for (const file of jsonFiles(path.join(root, 'pointclouds'), (f) => f.includes('_autosave'))) {
        const data = readJson(file, report);
        if (!data)
            continue;
        const match = /^(.*)_(\d+)$/.exec(stem(file));
        const id = (typeof data.vehicleId === 'string' && data.vehicleId) || (match ? match[1] : stem(file));
        const order = match ? Number(match[2]) : 0;
        const best = exports.get(id);
        if (best)
            report.lossy(order > best.order ? best.file : file, `an older export for ${id}, the highest number wins`);
        if (!best || order > best.order)
            exports.set(id, { file, data, order });
    }
    for (const [id, { file, data }] of exports) {
        const cloud = convertCloud(data, report, file, 'car');
        if (!cloud)
            continue;
        out.json(`vehicles/${id}/cloud.json`, cloud, file);
        frames.set(id, cloud.app.garage.frame);
    }
    for (const file of jsonFiles(path.join(root, 'paths'), (f) => f.includes('_autosave'))) {
        const id = stem(file);
        writeCarPaths(file, frames.get(id) ?? out.read(`vehicles/${id}/cloud.json`)?.app?.garage?.frame, `vehicles/${id}/`, out, report);
    }
}

const hasAny = (dir, names) => names.some((n) => fs.existsSync(path.join(dir, n)));

function findRoots(dir) {
    if (hasAny(dir, ['pointCloud.json', 'idlePaths.json']))
        return [{ type: 'car', dir }];
    if (hasAny(dir, ['defaults', 'garages', 'paint']))
        return [{ type: 'tree', dir }];
    if (hasAny(dir, ['pointclouds']))
        return [{ type: 'glc', dir }];
    const mods = ['GarageCore', 'GarageLocationCreator'].map((m) => path.join(dir, m, 'data')).filter((p) => fs.existsSync(p));
    if (mods.length > 0)
        return mods.flatMap(findRoots);
    for (const down of ['bin/x64/plugins/cyber_engine_tweaks/mods', 'data']) {
        const next = path.join(dir, down);
        if (fs.existsSync(next))
            return findRoots(next);
    }
    return [];
}

export function convert(input, output, { user = false } = {}) {
    const report = new Report();
    const out = new Output(output, report);
    const run = { locations: new Map(), clouds: new Map() };
    const roots = findRoots(input);
    if (roots.length === 0)
        report.error(input, 'nothing here looks like GarageCore, GLC or car data');
    for (const { type, dir } of roots) {
        if (type === 'car')
            convertCar(dir, out, report);
        else if (type === 'tree')
            convertTree(dir, out, report, run, user);
        else if (user)
            convertGlc(dir, out, report);
        else
            report.error(dir, 'GLC exports go to the user root, pass --user');
    }
    return { report, written: out.written };
}

function main(argv) {
    const args = [...argv];
    const user = args.includes('--user');
    if (user)
        args.splice(args.indexOf('--user'), 1);
    let reportFile = null;
    const at = args.indexOf('--report');
    if (at >= 0)
        [, reportFile] = args.splice(at, 2);
    if (args.length !== 2) {
        console.error('usage: convert_garage_data.mjs <input> <output> [--user] [--report <file>]');
        return 2;
    }
    const { report, written } = convert(args[0], args[1], { user });
    const text = `== ${args[0]} -> ${args[1]}\n${report.text()}\n-- ${written.length} files written\n`;
    process.stdout.write(text);
    if (reportFile)
        fs.appendFileSync(reportFile, text);
    return report.errors > 0 ? 1 : 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href)
    process.exitCode = main(process.argv.slice(2));
