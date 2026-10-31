import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { describe, it, before, after } from 'node:test';
import { fileURLToPath } from 'node:url';

import { Report, convert, convertBBox, convertCloud, convertLocation, convertPath, convertPaths, pretty } from '../_tools/convert_garage_data.mjs';
import { cloudErrors, pathErrors } from './v3_rules.mjs';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const TOOL = path.join(REPO, '_tools', 'convert_garage_data.mjs');
const SHIPPED = path.join(REPO, 'r6', 'scripts', 'Garage', 'data');
const SDH0 = path.resolve(REPO, '..', 'SDH0');

const key = (x, extra = {}) => ({ x, y: 1, z: 2, yaw: 10, pitch: -5, roll: 0, fov: 60, ...extra });
const oldPath = (extra = {}) => ({ name: 'p', interpolation: 'Linear', easing: false, playbackDuration: 6, positions: [key(0), key(1)], ...extra });
const oldEntry = (extra = {}) => ({ name: 'G', filename: 'g', region: 'R', x: 1, y: 2, z: 3, yaw: 90, ...extra });
const levels = (report, level) => report.items.filter((i) => i.level === level).map((i) => i.message);

function walk(dir, out = []) {
    if (!fs.existsSync(dir))
        return out;
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory())
            walk(p, out);
        else if (p.endsWith('.json'))
            out.push(p);
    }
    return out;
}

describe('locations', () => {
    it('fills every omitted field with the old default', () => {
        const report = new Report();
        const loc = convertLocation(oldEntry(), report, 'f');
        assert.deepEqual(loc, {
            format: 'garage.location', version: 1, id: 'g', name: 'G', region: 'R',
            deck: { x: 1, y: 2, z: 3, yaw: 90 },
            zone: { enter: 30, exit: 15, service: 12, arrival: 2, events: true },
            door: { nodeRef: '', entityHash: '' },
            limits: { width: 0, length: 0, height: 0 },
            audio: {
                x: 1, y: 2, z: 3, type: 'auto', gain: 1, reverb: 'revb_interior_factory_medium__medium', reverbLevel: 0.35,
                lowPass: 0, highPass: 0, occlusion: true, occlusionHz: 1200, occlusionLevel: 0.9, playlist: 'pool',
            },
            economy: {
                tier: 'Standard', serviceMultiplier: 1, maxVehicleTier: '', maxPool: 0, cooldownMultiplier: 1,
                blockedClasses: [], surcharges: [], services: [], saleDelay: { min: 0, max: 0, multiplier: 1 },
            },
            camera: { idleShake: 'timeline', partViewShake: 'showroom', maxIdleSeconds: 6 },
            app: {},
        });
        assert.equal(report.items.length, 0);
    });

    it('moves every old field to its home', () => {
        const loc = convertLocation(oldEntry({
            proximityEnterRadius: 40, proximityExitRadius: 18, proximityServiceRadius: 9, arrivalDistance: 3, proximityEvents: false,
            doorEntityHash: '17263465343618105', doorNodeRef: '#ref', maxWidth: 4, maxLength: 7, maxHeight: 3,
            playerSpawn: { x: 5, y: 6, z: 7, yaw: 8 },
            audioEmitter: { x: 9, reverb: 'revb', reverbLevel: 0.9, occlusion: false, playlist: 'nfsu2' },
            garageTier: 'Premium', garageServiceMultiplier: 1.5, maxVehicleTier: 'Hyper', maxPoolOverride: 500, cooldownMultiplier: 2,
            blockedClasses: ['a'], surchargeClasses: [{ class: 'b', multiplier: 1.2 }], services: ['c'],
            saleDelayMin: 1, saleDelayMax: 2, saleDelayMultiplier: 3,
            idleShake: 'i', partViewShake: 'v', maxIdleDuration: 4,
        }), new Report(), 'f');
        assert.deepEqual(loc.zone, { enter: 40, exit: 18, service: 9, arrival: 3, events: false });
        assert.deepEqual(loc.door, { nodeRef: '#ref', entityHash: '17263465343618105' });
        assert.deepEqual(loc.limits, { width: 4, length: 7, height: 3 });
        assert.deepEqual(loc.playerSpawn, { x: 5, y: 6, z: 7, yaw: 8 });
        assert.equal(loc.audio.x, 9);
        assert.equal(loc.audio.y, 2);
        assert.equal(loc.audio.reverb, 'revb');
        assert.equal(loc.audio.occlusion, false);
        assert.equal(loc.audio.playlist, 'nfsu2');
        assert.deepEqual(loc.economy, {
            tier: 'Premium', serviceMultiplier: 1.5, maxVehicleTier: 'Hyper', maxPool: 500, cooldownMultiplier: 2,
            blockedClasses: ['a'], surcharges: [{ vehicleClass: 'b', multiplier: 1.2 }], services: ['c'],
            saleDelay: { min: 1, max: 2, multiplier: 3 },
        });
        assert.deepEqual(loc.camera, { idleShake: 'i', partViewShake: 'v', maxIdleSeconds: 4 });
    });

    it('keeps the entity hash a string past 2^53 and refuses one already lost as a number', () => {
        const report = new Report();
        assert.equal(convertLocation(oldEntry({ doorEntityHash: '15328338922303809626' }), report, 'f').door.entityHash, '15328338922303809626');
        assert.equal(report.errors, 0);
        assert.equal(convertLocation(oldEntry({ doorEntityHash: 15328338922303809626 }), report, 'f').door.entityHash, '');
        assert.equal(report.errors, 1);
    });

    it('clamps radii the way resolveRadii did and reports it', () => {
        const report = new Report();
        const loc = convertLocation(oldEntry({ proximityEnterRadius: 10, proximityExitRadius: 15, doorEntityHash: '1' }), report, 'f');
        assert.deepEqual([loc.zone.enter, loc.zone.exit, loc.zone.service], [10, 13, 12]);
        assert.equal(levels(report, 'changed').length, 1);
    });

    it('drops dead fields quietly, unknown ones loudly', () => {
        const report = new Report();
        const loc = convertLocation(oldEntry({ audioEmitter: { x: 1, y: 2, z: 3, minDistance: 1, maxDistance: 2 }, surprise: 1 }), report, 'f');
        assert.equal(JSON.stringify(loc).includes('Distance'), false);
        assert.equal(levels(report, 'note').length, 2);
        assert.match(levels(report, 'lossy')[0], /surprise/);
    });

    it('skips entries missing a required field, and a half playerSpawn', () => {
        const report = new Report();
        assert.equal(convertLocation({ name: 'x' }, report, 'f'), null);
        assert.equal(report.errors, 1);
        assert.equal(convertLocation(oldEntry({ playerSpawn: { x: 1 } }), report, 'f').playerSpawn, undefined);
    });
});

describe('paths', () => {
    it('Linear', () => {
        const doc = convertPath(oldPath(), new Report(), 'f');
        assert.deepEqual(pathErrors(doc), []);
        assert.equal(doc.version, 3);
        assert.equal(doc.motion, 1);
        assert.equal(doc.curve, 'linear');
        assert.equal(doc.timing, 'uniform');
        assert.equal(doc.loop, 'once');
        assert.equal(doc.ease, 'linear');
        assert.equal(doc.stopAtKeys, 'none');
        assert.equal(doc.rotMode, 'slerp');
        assert.equal(doc.fovMode, 'linear');
        assert.equal(doc.duration, 6);
        assert.deepEqual(doc.keys.map((k) => k.id), [1, 2]);
    });

    it('Hermite, also when interpolation is missing', () => {
        for (const interpolation of ['Hermite', undefined]) {
            const doc = convertPath(oldPath({ interpolation }), new Report(), 'f');
            assert.deepEqual(pathErrors(doc), []);
            assert.deepEqual([doc.curve, doc.alpha, doc.ends], ['catmullRom', 0, 'extrapolate']);
        }
    });

    it('Cubic stops at keys and says so', () => {
        const report = new Report();
        const doc = convertPath(oldPath({ interpolation: 'Cubic' }), report, 'f');
        assert.deepEqual(pathErrors(doc), []);
        assert.deepEqual([doc.curve, doc.stopAtKeys], ['linear', 'cubic.inOut']);
        assert.match(levels(report, 'changed')[0], /Cubic/);
    });

    it('easing true is linear and flagged', () => {
        const report = new Report();
        assert.equal(convertPath(oldPath({ easing: true }), report, 'f').ease, 'linear');
        assert.match(levels(report, 'changed')[0], /easing/);
    });

    it('a missing or useless duration becomes 6 and is flagged', () => {
        for (const playbackDuration of [undefined, 0, -1, 'x']) {
            const report = new Report();
            assert.equal(convertPath(oldPath({ playbackDuration }), report, 'f').duration, 6);
            assert.match(levels(report, 'changed')[0], /playbackDuration/);
        }
    });

    it('lookAt goes to focus, never v3 lookAt', () => {
        const point = convertPath(oldPath({ lookAt: { x: 1, y: 2, z: 3 } }), new Report(), 'f');
        assert.deepEqual(point.app.garage.focus, { point: [1, 2, 3] });
        assert.equal(point.lookAt, undefined);
        assert.equal(point.keyLookAt, undefined);

        const report = new Report();
        const keys = convertPath(oldPath({ lookAt: { x: 1, y: 2, z: 3 }, positions: [key(0, { lookAt: { x: 7, y: 8, z: 9 } }), key(1)] }), report, 'f');
        assert.deepEqual(keys.app.garage.focus, { keys: { 1: [7, 8, 9] } });
        assert.equal(keys.keyLookAt, undefined);
        assert.equal(levels(report, 'lossy').length, 1);
    });

    it('keeps title and shake in app.garage, frame only when given', () => {
        const doc = convertPath(oldPath({ title: true, shake: { intensity: 2, frequency: 3 } }), new Report(), 'f');
        assert.deepEqual(doc.app.garage, { title: true, adaptive: false, shake: { intensity: 2, frequency: 3 } });
        const frame = { center: [1, 2, 3], yaw: 4, halfHeight: 0.5 };
        assert.deepEqual(convertPath(oldPath(), new Report(), 'f', { frame, adaptive: true }).app.garage, { title: false, adaptive: true, frame });
    });

    it('never writes what Check refuses', () => {
        const report = new Report();
        assert.equal(convertPath(oldPath({ positions: [key(0)] }), report, 'f'), null);
        assert.equal(report.errors, 1);
        const doc = convertPath(oldPath({ positions: [key(0, { fov: 200 }), key(1, { fov: 0 })] }), new Report(), 'f');
        assert.deepEqual(pathErrors(doc), []);
    });

    it('first of a repeated name wins, on any case', () => {
        const report = new Report();
        const out = convertPaths([oldPath({ name: 'A' }), oldPath({ name: 'a', playbackDuration: 9 })], report, 'f', () => ({}));
        assert.equal(out.length, 1);
        assert.equal(out[0].doc.duration, 6);
        assert.equal(levels(report, 'lossy').length, 1);
    });

    it('says when a file loses its play order', () => {
        const report = new Report();
        convertPaths([oldPath({ name: 'b' }), oldPath({ name: 'a' })], report, 'f', () => ({}));
        assert.match(levels(report, 'lossy')[0], /play order/);
    });

    it('takes { paths: [...] } and names the nameless', () => {
        const out = convertPaths({ paths: [oldPath({ name: undefined })] }, new Report(), 'f', () => ({}));
        assert.equal(out[0].name, 'idle_1');
    });
});

describe('clouds', () => {
    const point = (name, x = 0) => ({ name, x, y: 0, z: 0, yaw: 1, pitch: 2, roll: 3, fov: 50 });

    it('maps box, center and frame', () => {
        const doc = convertCloud({
            vehicleId: 'car', orbitCenter: { x: 1, y: 2, z: 3 }, boundingBox: { halfWidth: 1.1, halfDepth: 2.2, halfHeight: 0.6, yaw: 90 },
            positions: [{ ...point('default'), lookAt: { x: 7, y: 8, z: 9 } }],
        }, new Report(), 'f', 'car');
        assert.deepEqual(cloudErrors(doc), []);
        assert.deepEqual(doc.center, [1, 2, 3]);
        assert.deepEqual(doc.box, { half: [1.1, 2.2, 0.6], yaw: 90, offset: [0, 0, 0] });
        assert.deepEqual(doc.points[0], { id: 1, x: 0, y: 0, z: 0, yaw: 1, pitch: 2, roll: 3, hasRotation: true, fov: 50, hasFov: true, name: 'default', lookAt: [7, 8, 9] });
        assert.deepEqual(doc.app.garage, { frame: { center: [1, 2, 3], yaw: 90, halfHeight: 0.6 }, vehicleId: 'car' });
    });

    it('computes the missing center and box like ensureMetadata', () => {
        const report = new Report();
        const doc = convertCloud({ positions: [point('a', 0), point('b', 4)] }, report, 'f', 'garage');
        assert.deepEqual(doc.center, [2, 0, 0]);
        assert.deepEqual(doc.box, { half: [1, 2.5, 0.8], yaw: 0, offset: [0, 0, 0] });
        assert.equal(levels(report, 'changed').length, 2);
    });

    it('lowercases names, the old lookup ignored case and Find does not', () => {
        const report = new Report();
        const doc = convertCloud({ positions: [point('Hood'), point('hood')] }, report, 'f', 'garage');
        assert.deepEqual(doc.points.map((p) => p.name), ['hood']);
        assert.equal(levels(report, 'lossy').length, 1);
    });

    it('slots only on garage clouds', () => {
        const slots = [{ id: 'hood', maps: ['Hood'] }];
        const positions = [point('a')];
        assert.deepEqual(convertCloud({ positions, slots }, new Report(), 'f', 'garage').app.garage.slots, slots);
        const report = new Report();
        assert.equal(convertCloud({ positions, slots }, report, 'f', 'car').app.garage.slots, undefined);
        assert.match(levels(report, 'lossy')[0], /slots/);
    });
});

describe('bbox', () => {
    it('half is width, depth, height. Offset is centerOffset', () => {
        const report = new Report();
        const out = convertBBox({
            'Vehicle.a': { halfWidth: 1, halfHeight: 3, halfDepth: 2, centerOffset: { x: 4, y: 5, z: 6 } },
            'Vehicle.b': { halfWidth: 1, halfHeight: 3, halfDepth: 2 },
            'Vehicle.v_sport2_quadra_type66*': { halfWidth: 1, halfHeight: 3, halfDepth: 2 },
        }, report, 'f');
        assert.deepEqual(out['Vehicle.a'], { half: [1, 2, 3], offset: [4, 5, 6] });
        assert.deepEqual(out['Vehicle.b'].offset, [0, 0, 0]);
        assert.deepEqual(out['model:Vehicle.Type66'].half, [1, 2, 3]);
        assert.equal(report.errors, 0);
    });

    it('any other prefix is an error, not a guess', () => {
        const report = new Report();
        assert.deepEqual(convertBBox({ 'Vehicle.foo*': { halfWidth: 1, halfHeight: 3, halfDepth: 2 } }, report, 'f'), {});
        assert.equal(report.errors, 1);
    });
});

describe('pretty', () => {
    it('stays JSON', () => {
        const doc = { a: 1, b: [1, 2], c: { x: 1 }, d: [{ x: 1, y: [2] }, { z: { deep: true } }], e: [], f: {}, g: 'q"uote', h: -843.80120849609 };
        assert.deepEqual(JSON.parse(pretty(doc)), doc);
    });
});

describe('whole folders', () => {
    let dir;
    before(() => { dir = fs.mkdtempSync(path.join(os.tmpdir(), 'garage-convert-')); });
    after(() => { fs.rmSync(dir, { recursive: true, force: true }); });

    const write = (rel, data) => {
        const full = path.join(dir, rel);
        fs.mkdirSync(path.dirname(full), { recursive: true });
        fs.writeFileSync(full, typeof data === 'string' ? data : JSON.stringify(data));
    };
    const read = (rel) => JSON.parse(fs.readFileSync(path.join(dir, rel), 'utf8'));
    const cloud = (extra) => ({ orbitCenter: { x: 10, y: 20, z: 30 }, boundingBox: { halfWidth: 1, halfDepth: 2, halfHeight: 0.7, yaw: 45 }, positions: [{ name: 'default', x: 0, y: 0, z: 0, yaw: 0, pitch: 0, roll: 0, fov: 60 }], ...extra });

    it('a mod tree: adaptive on the garage, static unframed, defaults on the default cloud', () => {
        const data = 'in/bin/x64/plugins/cyber_engine_tweaks/mods/GarageCore/data';
        write(`${data}/defaults/locations.json`, { garages: [] });
        write(`${data}/defaults/cameras.json`, cloud({}));
        write(`${data}/defaults/paths.json`, [oldPath({ name: 'def' })]);
        write(`${data}/defaults/bbox_overrides.json`, { 'Vehicle.a': { halfWidth: 1, halfHeight: 3, halfDepth: 2 } });
        write(`${data}/paint/vehicle_appearances.json`, '{ "keep": "these bytes" }');
        write(`${data}/garages/locations/pack.json`, { _comment: 'x', garages: [oldEntry({ filename: 'g1', x: 100, y: 200, z: 300, yaw: 90 }), oldEntry({ filename: 'g2', x: 1, y: 2, z: 3, yaw: 7 })] });
        write(`${data}/garages/cameras/g1.json`, cloud({ orbitCenter: { x: 100, y: 200, z: 301 } }));
        write(`${data}/garages/paths/g1.json`, [oldPath({ name: 'still' }), oldPath({ name: 'zoom', adaptive: true })]);
        write(`${data}/garages/paths/g2.json`, [oldPath({ name: 'zoom2', adaptive: true })]);
        write(`${data}/garages/paths/g1.json.bak`, 'not json');

        const { report } = convert(path.join(dir, 'in'), path.join(dir, 'out'));
        assert.equal(report.errors, 0, report.text());
        assert.equal(read('out/garages/locations/g1.json').deck.x, 100);
        assert.equal(read('out/garages/locations/g2.json').id, 'g2');
        assert.equal(read('out/garages/paths/g1/still.json').app.garage.frame, undefined);
        // z from the garage's cloud, x, y and yaw off the deck
        assert.deepEqual(read('out/garages/paths/g1/zoom.json').app.garage.frame, { center: [100, 200, 301], yaw: 90, halfHeight: 0.7 });
        assert.deepEqual(read('out/garages/paths/g2/zoom2.json').app.garage.frame, { center: [1, 2, 3], yaw: 7, halfHeight: 0.8 });
        assert.deepEqual(read('out/defaults/paths/def.json').app.garage.frame, { center: [10, 20, 30], yaw: 45, halfHeight: 0.7 });
        assert.equal(read('out/defaults/paths/def.json').app.garage.adaptive, true);
        assert.deepEqual(read('out/defaults/bbox.json')['Vehicle.a'].half, [1, 2, 3]);
        assert.equal(fs.readFileSync(path.join(dir, 'out/paint/appearances.json'), 'utf8'), '{ "keep": "these bytes" }');
        for (const file of walk(path.join(dir, 'out'))) {
            const rel = path.relative(path.join(dir, 'out'), file);
            if (rel.includes('paths'))
                assert.deepEqual(pathErrors(JSON.parse(fs.readFileSync(file, 'utf8'))), [], rel);
        }
    });

    it('an adaptive path with no location anywhere is an error, and a later run with the location fixes it', () => {
        write('in2/garages/paths/lost.json', [oldPath({ adaptive: true })]);
        const first = convert(path.join(dir, 'in2'), path.join(dir, 'out2'));
        assert.equal(first.report.errors, 1);
        assert.equal(first.written.length, 0);
        write('in3/garages/locations/l.json', { garages: [oldEntry({ filename: 'lost' })] });
        convert(path.join(dir, 'in3'), path.join(dir, 'out2'));
        assert.equal(convert(path.join(dir, 'in2'), path.join(dir, 'out2')).report.errors, 0);
    });

    it('a car folder: paths framed on its cloud', () => {
        write('car/pointCloud.json', cloud({ vehicleId: 'c' }));
        write('car/idlePaths.json', [oldPath({ name: 'sweep' })]);
        const { report, written } = convert(path.join(dir, 'car'), path.join(dir, 'carout'));
        assert.equal(report.errors, 0);
        assert.deepEqual(written.sort(), ['cloud.json', 'paths/sweep.json']);
        assert.deepEqual(read('carout/paths/sweep.json').app.garage.frame, read('carout/cloud.json').app.garage.frame);
        assert.equal(read('carout/cloud.json').app.garage.vehicleId, 'c');
    });

    it('--user: GLC exports land under vehicles, autosaves and old exports stay out, defaults skipped', () => {
        write('glc/pointclouds/c.json', cloud({ vehicleId: 'c' }));
        write('glc/pointclouds/c_1.json', cloud({ vehicleId: 'c', orbitCenter: { x: 1, y: 1, z: 1 } }));
        write('glc/pointclouds/c_autosave.json', cloud({}));
        write('glc/paths/c.json', [oldPath({ name: 'mine' })]);
        write('glc/paths/c_paths_autosave.json', [oldPath({ name: 'nope' })]);
        const { report, written } = convert(path.join(dir, 'glc'), path.join(dir, 'user'), { user: true });
        assert.equal(report.errors, 0, report.text());
        assert.deepEqual(written.sort(), ['vehicles/c/cloud.json', 'vehicles/c/paths/mine.json']);
        assert.deepEqual(read('user/vehicles/c/cloud.json').center, [1, 1, 1]);

        write('cet/defaults/cameras.json', cloud({}));
        write('cet/garages/locations/u.json', { garages: [oldEntry()] });
        const cet = convert(path.join(dir, 'cet'), path.join(dir, 'user2'), { user: true });
        assert.deepEqual(cet.written, ['garages/locations/g.json']);
        assert.equal(convert(path.join(dir, 'glc'), path.join(dir, 'user3')).report.errors, 1);
    });

    it('the CLI exits 0, 1 on an error, 2 on bad args', () => {
        const run = (...args) => spawnSync(process.execPath, [TOOL, ...args], { encoding: 'utf8' }).status;
        assert.equal(run(path.join(dir, 'car'), path.join(dir, 'cli')), 0);
        assert.equal(run(path.join(dir, 'in2'), path.join(dir, 'cli2')), 1);
        assert.equal(run('only one'), 2);
    });
});

describe('the data on disk', () => {
    const pass = (file) => {
        const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
        const rel = file.replaceAll('\\', '/');
        if (rel.endsWith('/cloud.json') || rel.includes('/clouds/'))
            assert.deepEqual(cloudErrors(doc), [], file);
        else if (rel.includes('/paths/'))
            assert.deepEqual(pathErrors(doc), [], file);
    };

    it('Garage data passes the v3 rules', { skip: !fs.existsSync(SHIPPED) }, () => {
        const files = walk(SHIPPED);
        assert.ok(files.length > 0);
        files.forEach(pass);
    });

    it('location files have every field a loader reads', { skip: !fs.existsSync(path.join(SHIPPED, 'garages', 'locations')) }, () => {
        for (const file of walk(path.join(SHIPPED, 'garages', 'locations'))) {
            const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
            assert.equal(doc.id, path.basename(file, '.json'));
            for (const field of ['format', 'version', 'name', 'region', 'deck', 'zone', 'door', 'limits', 'audio', 'economy', 'camera', 'app'])
                assert.ok(doc[field] !== undefined, `${file}: ${field}`);
            assert.equal(typeof doc.door.entityHash, 'string');
        }
    });

    it('SDH0 car data passes the v3 rules', { skip: !fs.existsSync(SDH0) }, () => {
        for (const car of fs.readdirSync(SDH0)) {
            const scripts = path.join(SDH0, car, 'r6', 'scripts');
            if (fs.existsSync(scripts))
                walk(scripts).forEach(pass);
        }
    });
});
